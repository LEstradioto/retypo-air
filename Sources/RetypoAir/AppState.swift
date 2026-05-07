import Foundation
import AppKit

@MainActor
final class AppState: ObservableObject {
    let footerFocusItemCount = 9
    let editorUndoLimit = 50

    @Published var settings: RetypoSettings
    @Published var inputText: String = ""
    @Published var correctedText: String = ""
    @Published var outputText: String = ""
    @Published var status: String = "Ready"
    @Published var diffText: String = ""
    @Published var inlineHighlightRanges: [NSRange] = []
    @Published var modelsByProvider: [ProviderKind: [ProviderModel]] = [:]
    @Published var isLoadingModels = false
    @Published var isCorrecting = false
    @Published var showSettings = false
    @Published var selectedLauncherModeIndex = 0
    @Published var actions: [EditAction]
    @Published var history: [HistoryEntry]
    @Published var usageLedger: [UsageLedgerEntry]
    @Published var pricing: [String: ModelPricing]
    @Published var lastCost: CostSnapshot = CostSnapshot(usage: .zero, costUSD: nil)
    @Published var sessionCostUSD: Double = 0
    @Published var dayCostUSD: Double = 0
    @Published var draftSnapshots: [DraftSnapshot]
    @Published var candidateResults: [CandidateResult] = []
    @Published var showCandidateOverlay = false
    @Published var selectedCandidateIndex = 0
    @Published var wordsPerMinute: Double = 0
    @Published var wordsChangedLast = 0
    @Published var footerFocusIndex: Int? = nil
    @Published var pendingImport: PendingImport?
    @Published var canUndoEditorChange = false
    @Published var canRedoEditorChange = false


    var onAlwaysOnTopChanged: ((Bool) -> Void)?
    var onHideRequested: (() -> Void)?
    var onShowRequested: (() -> Void)?
    var onSettingsRequested: (() -> Void)?
    var onCandidatesVisibilityChanged: ((Bool) -> Void)?
    var onImportConfirmationChanged: ((Bool) -> Void)?

    let router = LLMRouter()
    let debouncer = Debouncer()
    let draftHistoryDebouncer = Debouncer()
    var lastAutoSubmittedHash: Int?
    var correctionGeneration = 0
    var suppressNextInputChange = false
    var typingStartedAt: Date?
    var editorUndoStack: [EditorSnapshot] = []
    var editorRedoStack: [EditorSnapshot] = []

    init(settings: RetypoSettings) {
        self.settings = settings
        self.actions = EditActionStore.load()
        self.history = HistoryStore.load()
        self.usageLedger = UsageLedgerStore.load()
        var loadedPricing = PricingStore.load()
        var pricingChanged = false
        for (key, value) in DefaultPricing.exact where loadedPricing[key] != value {
            loadedPricing[key] = value
            pricingChanged = true
        }
        self.pricing = loadedPricing
        self.draftSnapshots = DraftSnapshotStore.load()
        self.inputText = DraftStore.load()
        self.dayCostUSD = Self.costToday(from: self.usageLedger)
        if pricingChanged { PricingStore.save(loadedPricing) }
    }

    var selectedProvider: ProviderKind {
        get { settings.provider }
        set {
            settings.provider = newValue
            saveSettings()
            Task { await refreshModelsIfPossible() }
        }
    }

    var selectedModel: String? {
        settings.selectedModel(for: settings.provider)
    }

    var enabledActions: [EditAction] {
        let enabled = actions.filter(\.isEnabled)
        return enabled.isEmpty ? actions : enabled
    }

    var currentAction: EditAction {
        enabledActions.first { $0.id == settings.currentActionID } ?? enabledActions.first ?? EditAction.defaults[0]
    }

    var modelLabel: String {
        selectedModel ?? "No model"
    }

    var navigableModels: [ProviderModel] {
        let models = modelsByProvider[settings.provider] ?? []
        let accepted = Set(settings.acceptedModelIDsByProvider[settings.provider] ?? [])
        guard !accepted.isEmpty else { return models }
        return models.filter { accepted.contains($0.id) }
    }

    var statusLine: String {
        "Mode: \(currentAction.title) · Model: \(modelLabel) · \(settings.editorLayout.displayName)"
    }

    var lastCostLabel: String { formatCost(lastCost.costUSD) }
    var sessionCostLabel: String { formatCost(sessionCostUSD) }
    var dayCostLabel: String { formatCost(dayCostUSD) }

    func setSelectedModel(_ model: String, provider: ProviderKind? = nil) {
        if let provider { settings.provider = provider }
        settings.modelByProvider[settings.provider] = model
        status = "Model: \(model)"
        saveSettings()
    }

    func setCurrentAction(_ actionID: String) {
        guard enabledActions.contains(where: { $0.id == actionID }) || actions.contains(where: { $0.id == actionID }) else { return }
        settings.currentActionID = actionID
        status = "Mode: \(currentAction.title)"
        saveSettings()
    }

    func addMode() {
        let action = EditAction(id: UUID().uuidString, title: "New mode", instruction: "Edit the text according to this instruction.", isEnabled: true)
        actions.append(action)
        setCurrentAction(action.id)
        saveModes()
    }

    func deleteMode(_ action: EditAction) {
        guard actions.count > 1 else { return }
        actions.removeAll { $0.id == action.id }
        if settings.currentActionID == action.id { settings.currentActionID = enabledActions.first?.id ?? actions.first?.id ?? "correct" }
        saveModes()
        saveSettings()
    }

    func updateMode(_ action: EditAction) {
        guard let index = actions.firstIndex(where: { $0.id == action.id }) else { return }
        actions[index] = action
        saveModes()
    }

    func toggleModeEnabled(_ actionID: String) {
        guard let index = actions.firstIndex(where: { $0.id == actionID }) else { return }
        actions[index].isEnabled.toggle()
        if !actions[index].isEnabled, settings.currentActionID == actionID {
            settings.currentActionID = enabledActions.first?.id ?? actions[index].id
            saveSettings()
        }
        saveModes()
    }

    func restoreHistory(_ entry: HistoryEntry, useOutput: Bool = false) {
        pushEditorUndoSnapshot()
        inputText = useOutput ? entry.output : entry.input
        outputText = entry.output
        diffText = entry.diff
        settings.provider = entry.provider
        settings.modelByProvider[entry.provider] = entry.model
        settings.currentActionID = entry.actionID
        status = "Restored"
        DraftStore.save(inputText)
        saveSettings()
    }

    func isAcceptedModel(_ modelID: String, provider: ProviderKind? = nil) -> Bool {
        let provider = provider ?? settings.provider
        return Set(settings.acceptedModelIDsByProvider[provider] ?? []).contains(modelID)
    }

    func toggleAcceptedModel(_ modelID: String, provider: ProviderKind? = nil) {
        let provider = provider ?? settings.provider
        var values = settings.acceptedModelIDsByProvider[provider] ?? []
        if values.contains(modelID) {
            values.removeAll { $0 == modelID }
        } else {
            values.append(modelID)
        }
        settings.acceptedModelIDsByProvider[provider] = values
        status = values.isEmpty ? "Browsing all models" : "Browsing \(values.count) accepted models"
        saveSettings()
    }

    func requestHide() {
        onHideRequested?()
    }

    func toggleCandidateOverlay() {
        if candidateResults.isEmpty, !diffText.isEmpty {
            candidateResults = [CandidateResult(action: currentAction, output: outputText, diff: diffText, usage: lastCost.usage, costUSD: lastCost.costUSD)]
            selectedCandidateIndex = 0
        }
        setCandidateOverlayVisible(!showCandidateOverlay)
    }

    func setCandidateOverlayVisible(_ visible: Bool) {
        showCandidateOverlay = visible
        onCandidatesVisibilityChanged?(visible)
    }

    func requestSettings() {
        onSettingsRequested?()
    }

    func copyOutput(_ text: String? = nil) {
        let value = (text ?? outputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        ClipboardService.copy(value)
        status = "Copied"
        if settings.hideAfterCopy { onHideRequested?() }
    }

    func handleShortcut(_ rawShortcut: String) -> Bool {
        let shortcut = ShortcutFormatter.normalize(rawShortcut)
        guard !shortcut.isEmpty else { return false }

        for action in enabledActions {
            if ShortcutFormatter.normalize(settings.shortcutByAction[action.id] ?? "") == shortcut {
                setCurrentAction(action.id)
                return true
            }
        }

        if ShortcutFormatter.normalize(settings.nextModelShortcut) == shortcut {
            selectAdjacentModel(direction: 1)
            return true
        }
        if ShortcutFormatter.normalize(settings.previousModelShortcut) == shortcut {
            selectAdjacentModel(direction: -1)
            return true
        }

        for provider in ProviderKind.allCases {
            for model in modelsByProvider[provider] ?? [] {
                let key = settings.modelShortcutKey(provider: provider, modelID: model.id)
                if ShortcutFormatter.normalize(settings.shortcutByModel[key] ?? "") == shortcut {
                    setSelectedModel(model.id, provider: provider)
                    return true
                }
            }
        }
        return false
    }

    func toggleAlwaysOnTop() {
        settings.alwaysOnTop.toggle()
        onAlwaysOnTopChanged?(settings.alwaysOnTop)
        saveSettings()
    }
}
