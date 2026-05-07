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
}
