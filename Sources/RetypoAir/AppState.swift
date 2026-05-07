import Foundation
import Combine
import AppKit

@MainActor
final class AppState: ObservableObject {
    let footerFocusItemCount = 9

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

    let cost: CostTracker

    weak var host: PanelHost?

    let router = LLMRouter()
    let debouncer = Debouncer()
    let draftHistoryDebouncer = Debouncer()
    var lastAutoSubmittedHash: Int?
    var correctionGeneration = 0
    var suppressNextInputChange = false
    var typingStartedAt: Date?
    var editor = EditorEngine(limit: 50)
    private var cancellables = Set<AnyCancellable>()

    init(settings: RetypoSettings) {
        self.settings = settings
        self.actions = EditActionStore.load()
        self.history = HistoryStore.load()
        let (loadedPricing, pricingChanged) = Self.loadedPricing()
        self.cost = CostTracker(initialPricing: loadedPricing, initialUsageLedger: UsageLedgerStore.load())
        self.draftSnapshots = DraftSnapshotStore.load()
        self.inputText = DraftStore.load()
        if pricingChanged { PricingStore.save(loadedPricing) }
        rebroadcastCostChanges()
    }

    private static func loadedPricing() -> (pricing: [String: ModelPricing], changed: Bool) {
        var loaded = PricingStore.load()
        var changed = false
        for (key, value) in DefaultPricing.exact where loaded[key] != value {
            loaded[key] = value
            changed = true
        }
        return (loaded, changed)
    }

    private func rebroadcastCostChanges() {
        cost.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    // Forwarding to CostTracker so views observing AppState don't need to change.
    var lastCost: CostSnapshot { cost.lastCost }
    var lastCostLabel: String { cost.lastCostLabel }
    var sessionCostLabel: String { cost.sessionCostLabel }
    var dayCostLabel: String { cost.dayCostLabel }

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
        host?.requestHide()
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
        host?.setCandidatesVisible(visible)
    }

    func requestSettings() {
        host?.requestSettings()
    }
}
