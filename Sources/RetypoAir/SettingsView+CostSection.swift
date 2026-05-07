import SwiftUI

extension SettingsView {
    var pricingSection: some View {
        SettingsCard(title: "Cost tracking") {
            Text("Token usage is read from provider responses. Costs require per-model prices in USD per 1M input/output tokens, saved to ~/.retypo-air/pricing.json.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Text("Last \(state.lastCostLabel)")
                Text("Session \(state.sessionCostLabel)")
                Text("Today \(state.dayCostLabel)")
                Text("Tokens \(state.lastCost.usage.totalTokens)")
            }
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            let models = state.modelsByProvider[state.selectedProvider] ?? []
            if models.isEmpty {
                Text("Refresh models to edit pricing for this provider.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(models.prefix(12)) { model in
                        pricingRow(modelID: model.id)
                    }
                }
            }
        }
    }

    private func pricingRow(modelID: String) -> some View {
        HStack(spacing: 10) {
            Text(modelID)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .lineLimit(1)
            Spacer()
            Text("in").foregroundStyle(.secondary)
            TextField("0.00", value: pricingInputBinding(modelID), format: .number)
                .textFieldStyle(.roundedBorder)
                .settingsFocus(modelFocusID(modelID, "pricing.input"), radius: 6)
                .frame(width: 76)
            Text("out").foregroundStyle(.secondary)
            TextField("0.00", value: pricingOutputBinding(modelID), format: .number)
                .textFieldStyle(.roundedBorder)
                .settingsFocus(modelFocusID(modelID, "pricing.output"), radius: 6)
                .frame(width: 76)
        }
    }

    var historySection: some View {
        SettingsCard(title: "History") {
            historySectionHeader
            Text("Saved: \(state.history.count)/\(state.settings.historyLimit) LLM runs · \(state.draftSnapshots.count) draft backups")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.accentColor.opacity(0.85))
            if state.history.isEmpty && state.draftSnapshots.isEmpty {
                Text("No history yet.").foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(state.history) { entry in historyRow(entry) }
                    if !state.draftSnapshots.isEmpty {
                        Divider().opacity(0.3)
                        ForEach(state.draftSnapshots.prefix(5)) { snapshot in draftRow(snapshot) }
                    }
                }
            }
        }
    }

    private var historySectionHeader: some View {
        HStack {
            Text("LLM runs + realtime draft backups. Showing latest entries only; full file lives at ~/.retypo-air/history.json.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Picker("Save", selection: Binding(get: { state.settings.historyLimit }, set: { state.settings.historyLimit = $0; state.saveSettings() })) {
                Text("10").tag(10)
                Text("50").tag(50)
                Text("200").tag(200)
            }
            .pickerStyle(.segmented)
            .settingsFocus("history.limit", radius: 8, keyboardFocusable: true, activate: cycleHistoryLimit)
            .frame(width: 160)
            Button(historyDisplayMode.title) { historyDisplayMode = historyDisplayMode.next }
                .buttonStyle(SettingsCapsuleButtonStyle(active: false))
                .settingsFocus("history.display", radius: 14, keyboardFocusable: true, activate: {
                    historyDisplayMode = historyDisplayMode.next
                    return true
                })
        }
    }

    private func historyRow(_ entry: HistoryEntry) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.actionTitle) · \(entry.model)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                Text(historyDisplayMode.text(for: entry))
                    .font(.system(size: 12, weight: .regular, design: historyDisplayMode == .diff ? .monospaced : .default))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button { state.restoreHistory(entry, useOutput: historyDisplayMode == .output) } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(SettingsIconButtonStyle())
            .settingsFocus(historyFocusID(entry.id), radius: 13, keyboardFocusable: true, activate: {
                state.restoreHistory(entry, useOutput: historyDisplayMode == .output)
                return true
            })
        }
    }

    private func draftRow(_ snapshot: DraftSnapshot) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Draft backup")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                Text(snapshot.text)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                state.inputText = snapshot.text
                DraftStore.save(snapshot.text)
                state.status = "Draft restored"
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(SettingsIconButtonStyle())
            .settingsFocus(draftFocusID(snapshot.id), radius: 13, keyboardFocusable: true, activate: {
                state.inputText = snapshot.text
                DraftStore.save(snapshot.text)
                state.status = "Draft restored"
                return true
            })
        }
    }
}
