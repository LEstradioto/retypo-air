import Foundation
import AppKit

@MainActor
final class AppState: ObservableObject {
    @Published var settings: RetypoSettings
    @Published var inputText: String = ""
    @Published var correctedText: String = ""
    @Published var outputText: String = ""
    @Published var status: String = "Ready"
    @Published var diffText: String = ""
    @Published var modelsByProvider: [ProviderKind: [ProviderModel]] = [:]
    @Published var isLoadingModels = false
    @Published var isCorrecting = false
    @Published var showSettings = false

    let actions = EditAction.defaults
    var onAlwaysOnTopChanged: ((Bool) -> Void)?
    var onHideRequested: (() -> Void)?
    var onShowRequested: (() -> Void)?

    private let router = LLMRouter()
    private let debouncer = Debouncer()
    private var lastAutoSubmittedHash: Int?
    private var correctionGeneration = 0

    init(settings: RetypoSettings) {
        self.settings = settings
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

    func setSelectedModel(_ model: String) {
        settings.modelByProvider[settings.provider] = model
        saveSettings()
        status = "Model selected"
    }

    func onInputChanged() {
        guard settings.autoCorrect else { return }
        guard CorrectionPolicy.shouldAutoCorrect(inputText) else { return }
        let hash = inputText.hashValue
        guard hash != lastAutoSubmittedHash else { return }
        debouncer.schedule(milliseconds: settings.debounceMs) { [weak self] in
            guard let self else { return }
            await self.correctAndMaybeCopy(source: "auto")
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
            status = models.isEmpty ? "No models returned" : "Loaded \(models.count) models"
        } catch {
            status = error.localizedDescription
        }
        isLoadingModels = false
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
            correctedText = parsed.corrected
            outputText = parsed.corrected
            diffText = DiffService.compactDiff(original: original, corrected: parsed.corrected)
            if settings.autoCopy { copyOutput(parsed.corrected) } else { status = parsed.changed ? "Corrected" : "No changes" }
        } catch {
            guard generation == correctionGeneration else { return }
            status = error.localizedDescription
        }
        isCorrecting = false
    }

    func runAction(_ action: EditAction) async {
        if action.id == "correct" {
            await correctAndMaybeCopy(source: "manual")
            return
        }
        guard let model = selectedModel else {
            status = "Choose a model before editing"
            return
        }
        let original = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return }
        isCorrecting = true
        status = "Running \(action.title)"
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
            let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            outputText = text
            correctedText = text
            diffText = DiffService.compactDiff(original: original, corrected: text)
            if settings.autoCopy { copyOutput(text) } else { status = "Done" }
        } catch {
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

    func toggleAlwaysOnTop() {
        settings.alwaysOnTop.toggle()
        onAlwaysOnTopChanged?(settings.alwaysOnTop)
        saveSettings()
    }

    func saveSettings() {
        SettingsStore.save(settings)
    }

    func updatePanelFrame(_ frame: NSRect) {
        settings.panelFrame = PanelFrame(frame)
        saveSettings()
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
