import Foundation

extension AppState {
    struct ActionOutcome {
        let text: String
        let original: String
        let changed: Bool
        let response: LLMResponse
        let action: EditAction
    }

    struct HistoryDraft {
        let original: String
        let output: String
        let diff: String
        let action: EditAction
        let usage: TokenUsage
        let costUSD: Double?
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
            applyResult(ActionOutcome(text: parsed.corrected, original: original, changed: parsed.changed, response: response, action: currentAction))
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
            applyResult(ActionOutcome(text: text, original: original, changed: text != original, response: response, action: action))
        } catch {
            guard generation == correctionGeneration else { return }
            status = error.localizedDescription
        }
        isCorrecting = false
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
}
