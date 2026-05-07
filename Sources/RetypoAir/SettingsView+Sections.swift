import SwiftUI

extension SettingsView {
    var modelSection: some View {
        SettingsCard(title: "Model") {
            HStack(spacing: 12) {
                Picker("Provider", selection: Binding(get: { state.selectedProvider }, set: { state.selectedProvider = $0 })) {
                    ForEach(ProviderKind.allCases) { Text($0.displayName).tag($0) }
                }
                .frame(width: 170)
                .settingsFocus("model.provider", radius: 8, keyboardFocusable: true, activate: cycleProvider)

                Picker("Model", selection: Binding(get: { state.selectedModel ?? "" }, set: { if !$0.isEmpty { state.setSelectedModel($0) } })) {
                    Text("Select model...").tag("")
                    ForEach(state.llm.modelsByProvider[state.selectedProvider] ?? []) { Text($0.id).tag($0.id) }
                }
                .frame(maxWidth: .infinity)
                .settingsFocus("model.model", radius: 8, keyboardFocusable: true, activate: cycleModel)

                Button(state.llm.isLoadingModels ? "Loading" : "Refresh") { Task { await state.refreshModelsIfPossible() } }
                    .buttonStyle(SettingsCapsuleButtonStyle(active: false))
                    .settingsFocus("model.refresh", radius: 14, keyboardFocusable: true, activate: {
                        Task { await state.refreshModelsIfPossible() }
                        return true
                    })
                    .disabled(state.llm.isLoadingModels)
            }
            Text("Current: \(state.modelLabel)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    var editorSection: some View {
        SettingsCard(title: "Editor") {
            HStack(spacing: 12) {
                Picker("Layout", selection: Binding(get: { state.settings.editorLayout }, set: { state.settings.editorLayout = $0; state.saveSettings() })) {
                    ForEach(EditorLayoutMode.allCases) { Text($0.displayName).tag($0) }
                }
                .settingsFocus("editor.layout", radius: 8, keyboardFocusable: true, activate: {
                    state.settings.editorLayout = state.settings.editorLayout == .stacked ? .inline : .stacked
                    state.saveSettings()
                    return true
                })
                Picker("Theme", selection: Binding(get: { state.settings.mainTheme }, set: { state.settings.mainTheme = $0; state.saveSettings() })) {
                    ForEach(MainTheme.allCases) { Text($0.displayName).tag($0) }
                }
                .settingsFocus("editor.theme", radius: 8, keyboardFocusable: true, activate: cycleTheme)
            }
            Toggle("Auto run after pause", isOn: settingBool(\.autoCorrect))
                .settingsFocus("editor.autoRun", radius: 8, keyboardFocusable: true, activate: {
                    state.settings.autoCorrect.toggle()
                    state.saveSettings()
                    return true
                })
            Toggle("Auto copy result", isOn: settingBool(\.autoCopy))
                .settingsFocus("editor.autoCopy", radius: 8, keyboardFocusable: true, activate: {
                    state.settings.autoCopy.toggle()
                    state.saveSettings()
                    return true
                })
            Toggle("Hide after copy", isOn: settingBool(\.hideAfterCopy))
                .settingsFocus("editor.hideAfterCopy", radius: 8, keyboardFocusable: true, activate: {
                    state.settings.hideAfterCopy.toggle()
                    state.saveSettings()
                    return true
                })
            Toggle("Always on top", isOn: Binding(get: { state.settings.alwaysOnTop }, set: { _ in state.toggleAlwaysOnTop() }))
                .settingsFocus("editor.alwaysOnTop", radius: 8, keyboardFocusable: true, activate: {
                    state.toggleAlwaysOnTop()
                    return true
                })
            Toggle("Show on active screen bottom", isOn: settingBool(\.followActiveScreenOnShow))
                .settingsFocus("editor.followScreen", radius: 8, keyboardFocusable: true, activate: {
                    state.settings.followActiveScreenOnShow.toggle()
                    state.saveSettings()
                    return true
                })
            Toggle("Native macOS spellcheck", isOn: settingBool(\.nativeSpellcheck))
                .settingsFocus("editor.nativeSpellcheck", radius: 8, keyboardFocusable: true, activate: {
                    state.settings.nativeSpellcheck.toggle()
                    state.saveSettings()
                    return true
                })
            Stepper("Debounce: \(state.settings.debounceMs)ms", value: Binding(get: { state.settings.debounceMs }, set: { state.settings.debounceMs = $0; state.saveSettings() }), in: 200...2000, step: 100)
                .settingsFocus("editor.debounce", radius: 8, keyboardFocusable: true, activate: incrementDebounce)
        }
    }

    var shortcutSection: some View {
        SettingsCard(title: "Accepted models & shortcuts") {
            HStack(spacing: 12) {
                LabeledShortcutField(label: "Previous model", focusID: "shortcuts.previousModel", text: Binding(get: { state.settings.previousModelShortcut }, set: { state.settings.previousModelShortcut = $0; state.saveSettings() }))
                LabeledShortcutField(label: "Next model", focusID: "shortcuts.nextModel", text: Binding(get: { state.settings.nextModelShortcut }, set: { state.settings.nextModelShortcut = $0; state.saveSettings() }))
            }
            Text("Global show/hide is fixed for now: cmd+shift+space. Shortcuts below work while the editor is focused.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            let models = state.llm.modelsByProvider[state.selectedProvider] ?? []
            let acceptedCount = state.settings.acceptedModelIDsByProvider[state.selectedProvider]?.count ?? 0
            Text(acceptedCount == 0 ? "Next/previous model browses all loaded models." : "Next/previous model browses only the \(acceptedCount) checked models.")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
            if models.isEmpty {
                Text("Refresh models to choose accepted models and assign direct model shortcuts.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(models.prefix(24)) { model in
                        HStack(spacing: 10) {
                            Toggle("", isOn: Binding(
                                get: { state.isAcceptedModel(model.id) },
                                set: { _ in state.toggleAcceptedModel(model.id) }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .settingsFocus(modelFocusID(model.id, "accepted"), radius: 6, keyboardFocusable: true, activate: {
                                state.toggleAcceptedModel(model.id)
                                return true
                            })
                            Text(model.id)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .lineLimit(1)
                            Spacer()
                            TextField("cmd+opt+1", text: modelShortcutBinding(model.id))
                                .textFieldStyle(.roundedBorder)
                                .settingsFocus(modelFocusID(model.id, "shortcut"), radius: 6)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .frame(width: 120)
                        }
                    }
                }
            }
        }
    }
}
