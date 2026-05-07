import Foundation
import AppKit

extension AppState {
    func saveSettings() {
        SettingsStore.save(settings)
    }

    func saveModes() {
        EditActionStore.save(actions)
    }

    // Pricing forwarding (CostTracker owns the data; views observe AppState).
    func mergePricingDefaults(for provider: ProviderKind, models: [ProviderModel]) {
        cost.mergePricingDefaults(for: provider, models: models)
    }

    func pricingBindingValue(for provider: ProviderKind, model: String) -> ModelPricing {
        cost.pricingBindingValue(for: provider, model: model)
    }

    func setPricing(_ value: ModelPricing, provider: ProviderKind, model: String) {
        cost.setPricing(value, provider: provider, model: model)
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

    /// Monkeytype-style WPM: hide for the first ~5s warm-up window, reset
    /// the session if the user paused longer than 15s, otherwise the simple
    /// `words / elapsed_minutes` average since session start.
    func updateTypingStats() {
        let now = Date()
        if let last = lastTypingUpdate, now.timeIntervalSince(last) > Self.typingPauseResetSeconds {
            typingStartedAt = now
        }
        if typingStartedAt == nil { typingStartedAt = now }
        lastTypingUpdate = now
        guard let started = typingStartedAt else { return }
        let elapsed = now.timeIntervalSince(started)
        if elapsed < Self.typingWarmupSeconds {
            wordsPerMinute = 0
            return
        }
        wordsPerMinute = Double(countWords(inputText)) / (elapsed / 60)
    }

    static let typingWarmupSeconds: TimeInterval = 5
    static let typingPauseResetSeconds: TimeInterval = 15

    func countWords(_ text: String) -> Int {
        let ns = text as NSString
        var count = 0
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: [.byWords, .localized]) { _, _, _, _ in
            count += 1
        }
        return count
    }
}
