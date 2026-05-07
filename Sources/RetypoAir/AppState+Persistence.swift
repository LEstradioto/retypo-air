import Foundation
import AppKit

extension AppState {
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

    func scheduleDraftSnapshot() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draftHistoryDebouncer.schedule(milliseconds: 1_500) { [weak self] in
            guard let self else { return }
            self.saveDraftSnapshotNow()
        }
    }

    func saveDraftSnapshotNow() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 3 else { return }
        guard draftSnapshots.first?.text != text else { return }
        draftSnapshots.insert(DraftSnapshot(text: text), at: 0)
        draftSnapshots = Array(draftSnapshots.prefix(20))
        DraftSnapshotStore.save(draftSnapshots)
    }

    func updateTypingStats() {
        let words = countWords(inputText)
        guard let started = typingStartedAt else { return }
        let minutes = max(Date().timeIntervalSince(started) / 60, 0.05)
        wordsPerMinute = Double(words) / minutes
    }

    func countWords(_ text: String) -> Int {
        let ns = text as NSString
        var count = 0
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: [.byWords, .localized]) { _, _, _, _ in
            count += 1
        }
        return count
    }
}
