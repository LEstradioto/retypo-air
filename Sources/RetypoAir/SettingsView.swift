import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var settingsFocus: SettingsFocusCoordinator
    @State var editingModeID: String?
    @State var historyDisplayMode: HistoryDisplayMode = .input

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .behindWindow)
                    .ignoresSafeArea()
                LinearGradient(colors: [Color.white.opacity(0.18), Color.accentColor.opacity(0.035), Color.black.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    settingsHeader
                    ScrollView {
                        VStack(spacing: 14) {
                            modelSection
                            modeSection
                            editorSection
                            shortcutSection
                            pricingSection
                            historySection
                        }
                        .padding(18)
                    }
                }
            }
            .onAppear {
                settingsFocus.setOrder(settingsFocusOrder)
                settingsFocus.focusFirst()
            }
            .onChange(of: settingsFocusOrder) { order in
                settingsFocus.setOrder(order)
            }
            .onChange(of: settingsFocus.focusedID) { focusedID in
                guard let focusedID else { return }
                withAnimation(.easeOut(duration: 0.16)) {
                    proxy.scrollTo(focusedID, anchor: .center)
                }
            }
        }
    }

    var settingsFocusOrder: [String] {
        var ids: [String] = [
            "settings.done",
            "model.provider",
            "model.model",
            "model.refresh",
            "modes.add"
        ]

        for action in state.actions {
            ids.append(modeFocusID(action.id, "enabled"))
            ids.append(modeFocusID(action.id, "select"))
            ids.append(modeFocusID(action.id, "edit"))
            if editingModeID == action.id {
                ids.append(modeFocusID(action.id, "title"))
                ids.append(modeFocusID(action.id, "shortcut"))
                ids.append(modeFocusID(action.id, "instruction"))
            }
            if state.actions.count > 1 {
                ids.append(modeFocusID(action.id, "delete"))
            }
        }

        ids.append(contentsOf: [
            "editor.layout",
            "editor.theme",
            "editor.autoRun",
            "editor.autoCopy",
            "editor.hideAfterCopy",
            "editor.alwaysOnTop",
            "editor.followScreen",
            "editor.nativeSpellcheck",
            "editor.debounce",
            "shortcuts.previousModel",
            "shortcuts.nextModel"
        ])

        for model in (state.modelsByProvider[state.selectedProvider] ?? []).prefix(24) {
            ids.append(modelFocusID(model.id, "accepted"))
            ids.append(modelFocusID(model.id, "shortcut"))
        }

        for model in (state.modelsByProvider[state.selectedProvider] ?? []).prefix(12) {
            ids.append(modelFocusID(model.id, "pricing.input"))
            ids.append(modelFocusID(model.id, "pricing.output"))
        }

        ids.append("history.limit")
        ids.append("history.display")
        ids.append(contentsOf: state.history.map { historyFocusID($0.id) })
        ids.append(contentsOf: state.draftSnapshots.prefix(5).map { draftFocusID($0.id) })
        return ids
    }

    func modeFocusID(_ actionID: String, _ field: String) -> String {
        "mode.\(actionID).\(field)"
    }

    func modelFocusID(_ modelID: String, _ field: String) -> String {
        "model.\(field).\(modelID)"
    }

    func historyFocusID(_ id: UUID) -> String {
        "history.restore.\(id.uuidString)"
    }

    func draftFocusID(_ id: UUID) -> String {
        "draft.restore.\(id.uuidString)"
    }

    func cycleProvider() -> Bool {
        guard let index = ProviderKind.allCases.firstIndex(of: state.selectedProvider) else { return false }
        state.selectedProvider = ProviderKind.allCases[(index + 1) % ProviderKind.allCases.count]
        return true
    }

    func cycleModel() -> Bool {
        let models = state.modelsByProvider[state.selectedProvider] ?? []
        guard !models.isEmpty else {
            Task { await state.refreshModelsIfPossible() }
            return true
        }
        let current = state.selectedModel
        let index = models.firstIndex { $0.id == current } ?? -1
        state.setSelectedModel(models[(index + 1 + models.count) % models.count].id)
        return true
    }

    func cycleTheme() -> Bool {
        guard let index = MainTheme.allCases.firstIndex(of: state.settings.mainTheme) else { return false }
        state.settings.mainTheme = MainTheme.allCases[(index + 1) % MainTheme.allCases.count]
        state.saveSettings()
        return true
    }

    func cycleHistoryLimit() -> Bool {
        let values = [10, 50, 200]
        let index = values.firstIndex(of: state.settings.historyLimit) ?? 0
        state.settings.historyLimit = values[(index + 1) % values.count]
        state.saveSettings()
        return true
    }

    func incrementDebounce() -> Bool {
        let next = state.settings.debounceMs >= 2000 ? 200 : state.settings.debounceMs + 100
        state.settings.debounceMs = next
        state.saveSettings()
        return true
    }

    var settingsHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                Text("Configure provider, modes, shortcuts, and the main panel.")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") { state.requestSettings() }
                .buttonStyle(SettingsCapsuleButtonStyle(active: true))
                .settingsFocus("settings.done", radius: 16, keyboardFocusable: true, activate: {
                    state.requestSettings()
                    return true
                })
        }
        .padding(22)
    }
}
