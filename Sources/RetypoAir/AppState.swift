import Foundation
import AppKit

private struct EditorSnapshot: Equatable {
    var inputText: String
    var correctedText: String
    var outputText: String
    var status: String
    var diffText: String
    var inlineHighlightRanges: [NSRange]
    var candidateResults: [CandidateResult]
    var showCandidateOverlay: Bool
    var selectedCandidateIndex: Int
    var wordsChangedLast: Int
    var lastAutoSubmittedHash: Int?
    var typingStartedAt: Date?
}

@MainActor
final class AppState: ObservableObject {
    private let footerFocusItemCount = 9
    private let editorUndoLimit = 50

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
    @Published private(set) var canUndoEditorChange = false
    @Published private(set) var canRedoEditorChange = false


    var onAlwaysOnTopChanged: ((Bool) -> Void)?
    var onHideRequested: (() -> Void)?
    var onShowRequested: (() -> Void)?
    var onSettingsRequested: (() -> Void)?
    var onCandidatesVisibilityChanged: ((Bool) -> Void)?
    var onImportConfirmationChanged: ((Bool) -> Void)?

    private let router = LLMRouter()
    private let debouncer = Debouncer()
    private let draftHistoryDebouncer = Debouncer()
    private var lastAutoSubmittedHash: Int?
    private var correctionGeneration = 0
    private var suppressNextInputChange = false
    private var typingStartedAt: Date?
    private var editorUndoStack: [EditorSnapshot] = []
    private var editorRedoStack: [EditorSnapshot] = []

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

    @discardableResult
    func receiveExternalImport(_ text: String, source: String) -> Bool {
        let trimmedIncoming = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIncoming.isEmpty, !text.hasPrefix("__RETYP_AIR_IMPORT_EMPTY_") else {
            status = "No selected text imported"
            return false
        }

        let existing = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !existing.isEmpty, inputText != text {
            pendingImport = PendingImport(text: text, source: source)
            status = "Confirm import from \(source)"
            return true
        }

        importExternalText(text, source: source)
        return false
    }

    func confirmPendingImport() {
        guard let pendingImport else { return }
        let text = pendingImport.text
        let source = pendingImport.source
        self.pendingImport = nil
        onImportConfirmationChanged?(false)
        importExternalText(text, source: source)
    }

    func cancelPendingImport() {
        pendingImport = nil
        onImportConfirmationChanged?(false)
        status = "Import cancelled"
    }

    private func importExternalText(_ text: String, source: String) {
        pushEditorUndoSnapshot()
        inputText = text
        outputText = ""
        correctedText = ""
        diffText = ""
        inlineHighlightRanges = []
        candidateResults = []
        showCandidateOverlay = false
        selectedCandidateIndex = 0
        footerFocusIndex = nil
        wordsChangedLast = 0
        lastAutoSubmittedHash = nil
        typingStartedAt = Date()
        DraftStore.save(inputText)
        status = "Imported selection from \(source)"
    }

    func cycleFooterFocus() {
        if let index = footerFocusIndex {
            let next = index + 1
            footerFocusIndex = next >= footerFocusItemCount ? nil : next
            status = footerFocusIndex == nil ? "Editor" : "Footer focus"
        } else {
            footerFocusIndex = 0
            status = "Footer focus"
        }
    }

    func nextFooterFocus() {
        cycleFooterFocus()
    }

    func previousFooterFocus() {
        if let index = footerFocusIndex {
            let previous = index - 1
            footerFocusIndex = previous < 0 ? nil : previous
            status = footerFocusIndex == nil ? "Editor" : "Footer focus"
        } else {
            footerFocusIndex = footerFocusItemCount - 1
            status = "Footer focus"
        }
    }

    func activateFooterFocus() {
        guard let index = footerFocusIndex else { return }
        switch index {
        case 0:
            if let currentIndex = enabledActions.firstIndex(where: { $0.id == currentAction.id }) {
                let next = enabledActions[(currentIndex + 1) % enabledActions.count]
                setCurrentAction(next.id)
            }
        case 1:
            selectAdjacentModel(direction: 1)
        case 2:
            settings.editorLayout = settings.editorLayout == .stacked ? .inline : .stacked
            saveSettings()
        case 3:
            settings.autoCorrect.toggle()
            saveSettings()
        case 4:
            requestSettings()
        case 5:
            _ = undoEditorChange()
        case 6:
            _ = redoEditorChange()
        case 7:
            toggleCandidateOverlay()
        case 8:
            status = "Last \(lastCostLabel) · Session \(sessionCostLabel) · Today \(dayCostLabel)"
        default:
            break
        }
    }

    func nextLauncherMode() {
        moveLauncherMode(direction: 1)
    }

    func previousLauncherMode() {
        moveLauncherMode(direction: -1)
    }

    private func moveLauncherMode(direction: Int) {
        guard !enabledActions.isEmpty else { return }
        selectedLauncherModeIndex = (selectedLauncherModeIndex + direction + enabledActions.count) % enabledActions.count
        settings.currentActionID = enabledActions[selectedLauncherModeIndex].id
        status = "Mode: \(currentAction.title)"
        saveSettings()
    }

    func runSelectedLauncherMode() async {
        guard enabledActions.indices.contains(selectedLauncherModeIndex) else { return }
        let action = enabledActions[selectedLauncherModeIndex]
        setCurrentAction(action.id)
        await runAction(action, source: "candidate")
        if !diffText.isEmpty {
            candidateResults = [CandidateResult(action: action, output: outputText, diff: diffText, usage: lastCost.usage, costUSD: lastCost.costUSD)]
            selectedCandidateIndex = 0
            setCandidateOverlayVisible(true)
        }
    }

    func nextCandidate() {
        moveCandidate(direction: 1)
    }

    func previousCandidate() {
        moveCandidate(direction: -1)
    }

    private func moveCandidate(direction: Int) {
        guard !candidateResults.isEmpty else { return }
        selectedCandidateIndex = (selectedCandidateIndex + direction + candidateResults.count) % candidateResults.count
        selectCandidate(at: selectedCandidateIndex)
    }

    func selectCandidate(at index: Int) {
        guard candidateResults.indices.contains(index) else { return }
        selectedCandidateIndex = index
        let candidate = candidateResults[index]
        outputText = candidate.output
        diffText = candidate.diff
        ClipboardService.copy(candidate.output)
        status = "Selected \(candidate.action.title)"
    }

    func restoreSelectedCandidateToEditor() {
        guard candidateResults.indices.contains(selectedCandidateIndex) else { return }
        pushEditorUndoSnapshot()
        inputText = candidateResults[selectedCandidateIndex].output
        DraftStore.save(inputText)
        setCandidateOverlayVisible(false)
        status = "Applied candidate"
    }

    func runAllEnabledModes() async {
        guard let model = selectedModel else {
            status = "Choose a model before running all"
            return
        }
        let original = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return }
        isCorrecting = true
        status = "Running \(enabledActions.count) modes"
        candidateResults = []
        setCandidateOverlayVisible(true)
        selectedCandidateIndex = 0
        for action in enabledActions {
            do {
                let response: LLMResponse
                if action.id == "correct" {
                    let request = LLMRequest(provider: settings.provider, model: model, system: PromptTemplates.correctionSystem, user: PromptTemplates.correctionUser(original), maxTokens: max(512, min(4_000, original.count * 2)), temperature: 0)
                    response = try await router.complete(request)
                    let parsed = parseCorrection(response.text) ?? (response.text.trimmingCharacters(in: .whitespacesAndNewlines), true, 0.5)
                    appendCandidate(output: parsed.corrected, original: original, response: response, action: action)
                } else {
                    let request = LLMRequest(provider: settings.provider, model: model, system: PromptTemplates.actionSystem(instruction: action.instruction), user: original, maxTokens: max(800, min(5_000, original.count * 2)), temperature: 0.2)
                    response = try await router.complete(request)
                    appendCandidate(output: response.text.trimmingCharacters(in: .whitespacesAndNewlines), original: original, response: response, action: action)
                }
            } catch {
                status = error.localizedDescription
            }
        }
        if !candidateResults.isEmpty { selectCandidate(at: 0) }
        isCorrecting = false
    }

    func onInputChanged() {
        if !suppressNextInputChange, !editorRedoStack.isEmpty {
            editorRedoStack.removeAll()
            publishUndoRedoAvailability()
        }
        if typingStartedAt == nil { typingStartedAt = Date() }
        updateTypingStats()
        DraftStore.save(inputText)
        scheduleDraftSnapshot()
        inlineHighlightRanges = []
        guard !suppressNextInputChange else {
            suppressNextInputChange = false
            return
        }
        guard settings.autoCorrect else { return }
        guard CorrectionPolicy.shouldAutoCorrect(inputText) else { return }
        let hash = inputText.hashValue
        guard hash != lastAutoSubmittedHash else { return }
        debouncer.schedule(milliseconds: settings.debounceMs) { [weak self] in
            guard let self else { return }
            await self.runCurrentAction(source: "auto")
        }
    }

    func refreshModelsIfPossible() async {
        await refreshModels(for: settings.provider)
    }

    func refreshModels(for provider: ProviderKind) async {
        isLoadingModels = true
        status = "Loading \(provider.displayName) models"
        do {
            let models = try await router.listModels(for: provider)
            modelsByProvider[provider] = models
            mergePricingDefaults(for: provider, models: models)
            status = models.isEmpty ? "No models returned" : "Loaded \(models.count) models"
        } catch {
            status = error.localizedDescription
        }
        isLoadingModels = false
    }

    func runCurrentAction(source: String = "manual") async {
        await runAction(currentAction, source: source)
    }

    func correctAndMaybeCopy(source: String = "manual") async {
        guard let model = selectedModel else {
            status = "Choose a model before correction"
            return
        }
        let original = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return }
        lastAutoSubmittedHash = inputText.hashValue
        correctionGeneration += 1
        let generation = correctionGeneration

        isCorrecting = true
        status = source == "auto" ? "Auto correcting" : "Correcting"
        do {
            let request = LLMRequest(
                provider: settings.provider,
                model: model,
                system: PromptTemplates.correctionSystem,
                user: PromptTemplates.correctionUser(original),
                maxTokens: max(512, min(4_000, original.count * 2)),
                temperature: 0
            )
            let response = try await router.complete(request)
            guard generation == correctionGeneration else { return }
            let parsed = parseCorrection(response.text) ?? (response.text.trimmingCharacters(in: .whitespacesAndNewlines), true, 0.5)
            applyResult(parsed.corrected, original: original, changed: parsed.changed, response: response, action: currentAction)
        } catch {
            guard generation == correctionGeneration else { return }
            status = error.localizedDescription
        }
        isCorrecting = false
    }

    func runAction(_ action: EditAction, source: String = "manual") async {
        if action.id == "correct" {
            await correctAndMaybeCopy(source: source)
            return
        }
        guard let model = selectedModel else {
            status = "Choose a model before editing"
            return
        }
        let original = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return }
        lastAutoSubmittedHash = inputText.hashValue
        correctionGeneration += 1
        let generation = correctionGeneration
        isCorrecting = true
        status = source == "auto" ? "Auto \(action.title.lowercased())" : "Running \(action.title)"
        do {
            let request = LLMRequest(
                provider: settings.provider,
                model: model,
                system: PromptTemplates.actionSystem(instruction: action.instruction),
                user: original,
                maxTokens: max(800, min(5_000, original.count * 2)),
                temperature: 0.2
            )
            let response = try await router.complete(request)
            guard generation == correctionGeneration else { return }
            let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            applyResult(text, original: original, changed: text != original, response: response, action: action)
        } catch {
            guard generation == correctionGeneration else { return }
            status = error.localizedDescription
        }
        isCorrecting = false
    }

    func copyOutput(_ text: String? = nil) {
        let value = (text ?? outputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        ClipboardService.copy(value)
        status = "Copied"
        if settings.hideAfterCopy { onHideRequested?() }
    }

    @discardableResult
    func undoEditorChange() -> Bool {
        guard let snapshot = editorUndoStack.popLast() else {
            status = "Nothing to undo"
            publishUndoRedoAvailability()
            return false
        }
        editorRedoStack.append(currentEditorSnapshot())
        restoreEditorSnapshot(snapshot)
        status = "Undone"
        publishUndoRedoAvailability()
        return true
    }

    @discardableResult
    func redoEditorChange() -> Bool {
        guard let snapshot = editorRedoStack.popLast() else {
            status = "Nothing to redo"
            publishUndoRedoAvailability()
            return false
        }
        editorUndoStack.append(currentEditorSnapshot())
        restoreEditorSnapshot(snapshot)
        status = "Redone"
        publishUndoRedoAvailability()
        return true
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

    func saveSettings() {
        SettingsStore.save(settings)
    }

    func saveModes() {
        EditActionStore.save(actions)
    }

    func savePricing() {
        PricingStore.save(pricing)
    }

    func mergePricingDefaults(for provider: ProviderKind, models: [ProviderModel]) {
        var changed = false
        for model in models {
            let key = PricingStore.key(provider: provider, model: model.id)
            if let value = model.pricing ?? DefaultPricing.pricing(provider: provider, modelID: model.id), pricing[key] != value {
                pricing[key] = value
                changed = true
            }
        }
        for (key, value) in DefaultPricing.exact where pricing[key] != value {
            pricing[key] = value
            changed = true
        }
        if changed { savePricing() }
    }

    func pricingBindingValue(for provider: ProviderKind, model: String) -> ModelPricing {
        pricing[PricingStore.key(provider: provider, model: model)] ?? .zero
    }

    func setPricing(_ value: ModelPricing, provider: ProviderKind, model: String) {
        pricing[PricingStore.key(provider: provider, model: model)] = value
        savePricing()
    }

    func updatePanelFrame(_ frame: NSRect) {
        settings.panelFrame = PanelFrame(frame)
        saveSettings()
    }

    private func applyResult(_ text: String, original: String, changed: Bool, response: LLMResponse, action: EditAction) {
        pushEditorUndoSnapshot()
        correctedText = text
        outputText = text
        diffText = DiffService.compactDiff(original: original, corrected: text)
        wordsChangedLast = InlineDiffService.changedWordCount(original: original, corrected: text)
        let cost = computeCost(provider: settings.provider, model: selectedModel ?? "", usage: response.usage)
        lastCost = CostSnapshot(usage: response.usage, costUSD: cost)
        if let cost {
            sessionCostUSD += cost
            dayCostUSD += cost
        }
        appendHistory(original: original, output: text, diff: diffText, action: action, usage: response.usage, costUSD: cost)
        appendUsage(model: selectedModel ?? "", usage: response.usage, costUSD: cost)
        if settings.editorLayout == .inline {
            inlineHighlightRanges = InlineDiffService.changedRanges(original: original, corrected: text)
            suppressNextInputChange = true
            inputText = text
            DraftStore.save(inputText)
            lastAutoSubmittedHash = inputText.hashValue
        }
        if settings.autoCopy {
            copyOutput(text)
        } else {
            status = changed ? "Done" : "No changes"
        }
    }

    private func appendCandidate(output: String, original: String, response: LLMResponse, action: EditAction) {
        let cost = computeCost(provider: settings.provider, model: selectedModel ?? "", usage: response.usage)
        let diff = DiffService.compactDiff(original: original, corrected: output)
        candidateResults.append(CandidateResult(action: action, output: output, diff: diff, usage: response.usage, costUSD: cost))
        appendHistory(original: original, output: output, diff: diff, action: action, usage: response.usage, costUSD: cost)
        appendUsage(model: selectedModel ?? "", usage: response.usage, costUSD: cost)
    }

    private func currentEditorSnapshot() -> EditorSnapshot {
        EditorSnapshot(
            inputText: inputText,
            correctedText: correctedText,
            outputText: outputText,
            status: status,
            diffText: diffText,
            inlineHighlightRanges: inlineHighlightRanges,
            candidateResults: candidateResults,
            showCandidateOverlay: showCandidateOverlay,
            selectedCandidateIndex: selectedCandidateIndex,
            wordsChangedLast: wordsChangedLast,
            lastAutoSubmittedHash: lastAutoSubmittedHash,
            typingStartedAt: typingStartedAt
        )
    }

    private func pushEditorUndoSnapshot() {
        let snapshot = currentEditorSnapshot()
        guard editorUndoStack.last != snapshot else { return }
        editorUndoStack.append(snapshot)
        if editorUndoStack.count > editorUndoLimit {
            editorUndoStack.removeFirst(editorUndoStack.count - editorUndoLimit)
        }
        editorRedoStack.removeAll()
        publishUndoRedoAvailability()
    }

    private func restoreEditorSnapshot(_ snapshot: EditorSnapshot) {
        inputText = snapshot.inputText
        correctedText = snapshot.correctedText
        outputText = snapshot.outputText
        diffText = snapshot.diffText
        inlineHighlightRanges = snapshot.inlineHighlightRanges
        candidateResults = snapshot.candidateResults
        showCandidateOverlay = snapshot.showCandidateOverlay
        selectedCandidateIndex = min(snapshot.selectedCandidateIndex, max(0, candidateResults.count - 1))
        wordsChangedLast = snapshot.wordsChangedLast
        lastAutoSubmittedHash = snapshot.lastAutoSubmittedHash
        typingStartedAt = snapshot.typingStartedAt ?? Date()
        DraftStore.save(inputText)
        onCandidatesVisibilityChanged?(showCandidateOverlay)
    }

    private func publishUndoRedoAvailability() {
        canUndoEditorChange = !editorUndoStack.isEmpty
        canRedoEditorChange = !editorRedoStack.isEmpty
    }

    private func appendHistory(original: String, output: String, diff: String, action: EditAction, usage: TokenUsage, costUSD: Double?) {
        guard let model = selectedModel else { return }
        let entry = HistoryEntry(
            provider: settings.provider,
            model: model,
            actionID: action.id,
            actionTitle: action.title,
            input: original,
            output: output,
            diff: diff,
            usage: usage,
            costUSD: costUSD
        )
        history.insert(entry, at: 0)
        history = Array(history.prefix(max(1, settings.historyLimit)))
        HistoryStore.save(history, limit: settings.historyLimit)
    }

    private func appendUsage(model: String, usage: TokenUsage, costUSD: Double?) {
        let entry = UsageLedgerEntry(provider: settings.provider, model: model, usage: usage, costUSD: costUSD)
        usageLedger.insert(entry, at: 0)
        usageLedger = Array(usageLedger.prefix(500))
        UsageLedgerStore.save(usageLedger)
    }

    private func computeCost(provider: ProviderKind, model: String, usage: TokenUsage) -> Double? {
        let key = PricingStore.key(provider: provider, model: model)
        guard let pricing = pricing[key] else { return nil }
        let inputCost = Double(usage.inputTokens) / 1_000_000 * pricing.inputPerMillion
        let outputCost = Double(usage.outputTokens) / 1_000_000 * pricing.outputPerMillion
        return inputCost + outputCost
    }

    private func formatCost(_ value: Double?) -> String {
        guard let value else { return "$—" }
        if value == 0 { return "$0.0000" }
        if value < 0.0001 { return String(format: "$%.6f", value) }
        return String(format: "$%.4f", value)
    }

    private static func costToday(from entries: [UsageLedgerEntry]) -> Double {
        let calendar = Calendar.current
        return entries.reduce(0) { total, entry in
            guard calendar.isDateInToday(entry.timestamp), let cost = entry.costUSD else { return total }
            return total + cost
        }
    }

    private func scheduleDraftSnapshot() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draftHistoryDebouncer.schedule(milliseconds: 1_500) { [weak self] in
            guard let self else { return }
            self.saveDraftSnapshotNow()
        }
    }

    private func saveDraftSnapshotNow() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 3 else { return }
        guard draftSnapshots.first?.text != text else { return }
        draftSnapshots.insert(DraftSnapshot(text: text), at: 0)
        draftSnapshots = Array(draftSnapshots.prefix(20))
        DraftSnapshotStore.save(draftSnapshots)
    }

    private func updateTypingStats() {
        let words = countWords(inputText)
        guard let started = typingStartedAt else { return }
        let minutes = max(Date().timeIntervalSince(started) / 60, 0.05)
        wordsPerMinute = Double(words) / minutes
    }

    private func countWords(_ text: String) -> Int {
        let ns = text as NSString
        var count = 0
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: [.byWords, .localized]) { _, _, _, _ in
            count += 1
        }
        return count
    }

    private func selectAdjacentModel(direction: Int) {
        let models = navigableModels
        guard !models.isEmpty else { return }
        let current = selectedModel
        let currentIndex = models.firstIndex { $0.id == current } ?? 0
        let nextIndex = (currentIndex + direction + models.count) % models.count
        setSelectedModel(models[nextIndex].id)
    }

    private func parseCorrection(_ text: String) -> (corrected: String, changed: Bool, confidence: Double)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonText: String
        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}"), start <= end {
            jsonText = String(trimmed[start...end])
        } else {
            jsonText = trimmed
        }
        guard let data = jsonText.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let corrected = obj["corrected"] as? String else { return nil }
        let changed = obj["changed"] as? Bool ?? (corrected != inputText)
        let confidence = obj["confidence"] as? Double ?? 0.5
        return (corrected, changed, confidence)
    }
}
