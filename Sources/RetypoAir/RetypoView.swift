import SwiftUI

struct RetypoView: View {
    @EnvironmentObject private var state: AppState

    private var isLighter: Bool { state.settings.mainTheme == .lighter }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                Color.clear.frame(height: isLighter ? 6 : 8)
                if state.settings.editorLayout == .stacked {
                    stackedEditor
                } else {
                    inlineEditor
                }
                footerStatus
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: isLighter ? 16 : 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isLighter ? 18 : 24, style: .continuous)
                .strokeBorder(Color.white.opacity(isLighter ? 0.10 : 0.18), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var background: some View {
        if isLighter {
            Color.clear.ignoresSafeArea()
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .ignoresSafeArea()
        } else {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            LinearGradient(
                colors: [Color.white.opacity(0.13), Color.black.opacity(0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private var footerStatus: some View {
        HStack(spacing: 7) {
            Menu {
                ForEach(state.enabledActions) { action in
                    Button(action.title) { state.setCurrentAction(action.id) }
                }
            } label: {
                footerLink(state.currentAction.title, active: true, focused: state.footerFocusIndex == 0)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .background(Capsule(style: .continuous).fill(state.footerFocusIndex == 0 ? Color.accentColor.opacity(0.13) : Color.clear))
            .overlay(Capsule(style: .continuous).strokeBorder(state.footerFocusIndex == 0 ? Color.accentColor.opacity(0.42) : Color.clear, lineWidth: 1))

            Menu {
                let models = state.navigableModels.isEmpty ? (state.modelsByProvider[state.selectedProvider] ?? []) : state.navigableModels
                if models.isEmpty {
                    Button("Refresh models") { Task { await state.refreshModelsIfPossible() } }
                } else {
                    ForEach(models) { model in
                        Button(model.id) { state.setSelectedModel(model.id) }
                    }
                }
            } label: {
                footerLink(state.modelLabel, active: state.selectedModel != nil, focused: state.footerFocusIndex == 1, maxWidth: 170)
            }
            .menuStyle(.borderlessButton)
            .background(Capsule(style: .continuous).fill(state.footerFocusIndex == 1 ? Color.accentColor.opacity(0.13) : Color.clear))
            .overlay(Capsule(style: .continuous).strokeBorder(state.footerFocusIndex == 1 ? Color.accentColor.opacity(0.42) : Color.clear, lineWidth: 1))

            Button {
                state.settings.editorLayout = state.settings.editorLayout == .stacked ? .inline : .stacked
                state.saveSettings()
            } label: {
                footerLink(state.settings.editorLayout == .stacked ? "Stacked" : "Inline", active: state.settings.editorLayout == .inline, focused: state.footerFocusIndex == 2)
            }
            .buttonStyle(.plain)
            .pointingCursor()

            Button {
                state.settings.autoCorrect.toggle()
                state.saveSettings()
            } label: {
                footerLink(state.settings.autoCorrect ? "Auto" : "Manual", active: state.settings.autoCorrect, focused: state.footerFocusIndex == 3)
            }
            .buttonStyle(.plain)
            .pointingCursor()

            Button { state.requestSettings() } label: {
                footerSettingsIcon(focused: state.footerFocusIndex == 4)
            }
            .buttonStyle(.plain)
            .pointingCursor()

            Spacer(minLength: 6)
            if state.isCorrecting { ProgressView().controlSize(.small) }
            Button { state.undoEditorChange() } label: {
                footerIcon("arrow.uturn.backward", active: state.canUndoEditorChange, focused: state.footerFocusIndex == 5)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!state.canUndoEditorChange)
            .pointingCursor()

            Button { state.redoEditorChange() } label: {
                footerIcon("arrow.uturn.forward", active: state.canRedoEditorChange, focused: state.footerFocusIndex == 6)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("Z", modifiers: [.command, .shift])
            .disabled(!state.canRedoEditorChange)
            .pointingCursor()

            Button { state.toggleCandidateOverlay() } label: {
                footerLink("Diff", active: state.showCandidateOverlay, focused: state.footerFocusIndex == 7)
            }
            .buttonStyle(.plain)

            Menu {
                Text("Last: \(state.lastCostLabel) · \(state.lastCost.usage.totalTokens)t")
                Text("Session: \(state.sessionCostLabel)")
                Text("Today: \(state.dayCostLabel)")
            } label: {
                footerLink("Last \(state.lastCostLabel)", active: state.lastCost.costUSD != nil, focused: state.footerFocusIndex == 8, maxWidth: 92)
            }
            .menuStyle(.borderlessButton)
            Text("\(Int(state.wordsPerMinute))wpm")
                .foregroundStyle(statColor)
                .monospacedDigit()
            Text("Δ\(state.wordsChangedLast)")
                .foregroundStyle(state.wordsChangedLast == 0 ? statColor : Color.accentColor.opacity(isLighter ? 0.78 : 0.92))
                .monospacedDigit()
            Text(state.status)
                .lineLimit(1)
                .truncationMode(.tail)
            Text("\(state.inputText.count)")
                .monospacedDigit()
                .foregroundStyle(statColor)
        }
        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
        .foregroundStyle(.secondary.opacity(isLighter ? 0.62 : 0.92))
        .padding(.horizontal, isLighter ? 8 : 10)
        .padding(.top, isLighter ? 4 : 5)
        .padding(.bottom, isLighter ? 6 : 7)
    }

    private var statColor: Color {
        Color.secondary.opacity(isLighter ? 0.74 : 0.98)
    }

    private func footerLink(_ text: String, active: Bool, focused: Bool = false, maxWidth: CGFloat? = nil) -> some View {
        Text(text)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .foregroundStyle(active || focused ? Color.accentColor.opacity(isLighter ? 0.78 : 0.98) : Color.secondary.opacity(isLighter ? 0.62 : 0.88))
            .padding(.horizontal, focused ? 5 : 0)
            .padding(.vertical, focused ? 2 : 0)
            .background(Capsule(style: .continuous).fill(focused ? Color.accentColor.opacity(0.13) : Color.clear))
            .overlay(Capsule(style: .continuous).strokeBorder(focused ? Color.accentColor.opacity(0.42) : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
            .pointingCursor()
    }

    private func footerIcon(_ systemName: String, active: Bool, focused: Bool = false) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(active || focused ? Color.accentColor.opacity(isLighter ? 0.78 : 0.98) : Color.secondary.opacity(isLighter ? 0.42 : 0.72))
            .frame(width: focused ? 18 : 14, height: 14)
            .background(Capsule(style: .continuous).fill(focused ? Color.accentColor.opacity(0.13) : Color.clear))
            .overlay(Capsule(style: .continuous).strokeBorder(focused ? Color.accentColor.opacity(0.42) : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
            .pointingCursor()
    }

    private func footerSettingsIcon(focused: Bool = false) -> some View {
        Image(systemName: "gearshape.fill")
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(focused ? Color.accentColor.opacity(isLighter ? 0.84 : 1.0) : Color.secondary.opacity(isLighter ? 0.68 : 0.92))
            .frame(width: focused ? 25 : 23, height: 18)
            .background(Capsule(style: .continuous).fill(focused ? Color.accentColor.opacity(0.13) : Color.white.opacity(isLighter ? 0.025 : 0.045)))
            .overlay(Capsule(style: .continuous).strokeBorder(focused ? Color.accentColor.opacity(0.42) : Color.white.opacity(0.08), lineWidth: 1))
            .contentShape(Rectangle())
            .pointingCursor()
    }

    private var stackedEditor: some View {
        VStack(spacing: isLighter ? 6 : 8) {
            editorBox(minHeight: 44)
            outputBox
        }
        .padding(.horizontal, isLighter ? 6 : 8)
        .padding(.bottom, isLighter ? 1 : 2)
    }

    private var inlineEditor: some View {
        editorBox(minHeight: 72)
            .padding(.horizontal, isLighter ? 6 : 8)
            .padding(.bottom, isLighter ? 1 : 2)
    }

    private func editorBox(minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            NativeTextEditor(
                text: $state.inputText,
                nativeSpellcheck: state.settings.nativeSpellcheck,
                highlightRanges: state.inlineHighlightRanges,
                lighter: isLighter,
                onSubmit: { Task { await state.runCurrentAction(source: "enter") } },
                onRunAll: { Task { await state.runAllEnabledModes() } },
                onChange: { state.onInputChanged() },
                onCancel: { state.requestHide() },
                onTab: { if state.showCandidateOverlay { state.candidateResults.isEmpty ? state.nextLauncherMode() : state.nextCandidate(); return true }; if state.footerFocusIndex != nil { state.nextFooterFocus(); return true }; return false },
                onShiftTab: { if state.showCandidateOverlay { state.candidateResults.isEmpty ? state.previousLauncherMode() : state.previousCandidate(); return true }; if state.footerFocusIndex != nil { state.previousFooterFocus(); return true }; return false },
                onFocusCycle: { state.cycleFooterFocus() },
                onEnterInOverlay: { if state.footerFocusIndex != nil { state.activateFooterFocus(); return true }; if state.showCandidateOverlay, state.candidateResults.isEmpty { Task { await state.runSelectedLauncherMode() }; return true }; return false },
                onToggleOverlay: { state.toggleCandidateOverlay() },
                onSettings: { state.requestSettings() },
                onUndo: { state.undoEditorChange() },
                onRedo: { state.redoEditorChange() },
                onShortcut: { state.handleShortcut($0) }
            )
            .frame(minHeight: minHeight)
            .background(editorBackground)
            .overlay(editorStroke)
        }
    }

    private var editorBackground: some View {
        RoundedRectangle(cornerRadius: isLighter ? 12 : 15, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor).opacity(isLighter ? 0.14 : 0.54))
            .shadow(color: .black.opacity(isLighter ? 0.025 : 0.08), radius: isLighter ? 8 : 20, x: 0, y: isLighter ? 6 : 14)
    }

    private var editorStroke: some View {
        RoundedRectangle(cornerRadius: isLighter ? 12 : 15, style: .continuous)
            .strokeBorder(Color.white.opacity(isLighter ? 0.08 : 0.12), lineWidth: 1)
    }

    private var outputBox: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text("Result")
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Copy") { state.copyOutput() }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .disabled(state.outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ScrollView {
                Text(state.diffText.isEmpty ? "Set model in Settings. Type, Enter." : state.diffText)
                    .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(state.diffText.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
            }
            .frame(minHeight: 30, maxHeight: 76)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.black.opacity(0.065)))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settingsFocus: SettingsFocusCoordinator
    @State private var editingModeID: String?
    @State private var historyDisplayMode: HistoryDisplayMode = .input

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

    private var settingsFocusOrder: [String] {
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

    private func modeFocusID(_ actionID: String, _ field: String) -> String {
        "mode.\(actionID).\(field)"
    }

    private func modelFocusID(_ modelID: String, _ field: String) -> String {
        "model.\(field).\(modelID)"
    }

    private func historyFocusID(_ id: UUID) -> String {
        "history.restore.\(id.uuidString)"
    }

    private func draftFocusID(_ id: UUID) -> String {
        "draft.restore.\(id.uuidString)"
    }

    private func cycleProvider() -> Bool {
        guard let index = ProviderKind.allCases.firstIndex(of: state.selectedProvider) else { return false }
        state.selectedProvider = ProviderKind.allCases[(index + 1) % ProviderKind.allCases.count]
        return true
    }

    private func cycleModel() -> Bool {
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

    private func cycleTheme() -> Bool {
        guard let index = MainTheme.allCases.firstIndex(of: state.settings.mainTheme) else { return false }
        state.settings.mainTheme = MainTheme.allCases[(index + 1) % MainTheme.allCases.count]
        state.saveSettings()
        return true
    }

    private func cycleHistoryLimit() -> Bool {
        let values = [10, 50, 200]
        let index = values.firstIndex(of: state.settings.historyLimit) ?? 0
        state.settings.historyLimit = values[(index + 1) % values.count]
        state.saveSettings()
        return true
    }

    private func incrementDebounce() -> Bool {
        let next = state.settings.debounceMs >= 2000 ? 200 : state.settings.debounceMs + 100
        state.settings.debounceMs = next
        state.saveSettings()
        return true
    }

    private var settingsHeader: some View {
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

    private var modelSection: some View {
        SettingsCard(title: "Model") {
            HStack(spacing: 12) {
                Picker("Provider", selection: Binding(get: { state.selectedProvider }, set: { state.selectedProvider = $0 })) {
                    ForEach(ProviderKind.allCases) { Text($0.displayName).tag($0) }
                }
                .frame(width: 170)
                .settingsFocus("model.provider", radius: 8, keyboardFocusable: true, activate: cycleProvider)

                Picker("Model", selection: Binding(get: { state.selectedModel ?? "" }, set: { if !$0.isEmpty { state.setSelectedModel($0) } })) {
                    Text("Select model...").tag("")
                    ForEach(state.modelsByProvider[state.selectedProvider] ?? []) { Text($0.id).tag($0.id) }
                }
                .frame(maxWidth: .infinity)
                .settingsFocus("model.model", radius: 8, keyboardFocusable: true, activate: cycleModel)

                Button(state.isLoadingModels ? "Loading" : "Refresh") { Task { await state.refreshModelsIfPossible() } }
                    .buttonStyle(SettingsCapsuleButtonStyle(active: false))
                    .settingsFocus("model.refresh", radius: 14, keyboardFocusable: true, activate: {
                        Task { await state.refreshModelsIfPossible() }
                        return true
                    })
                    .disabled(state.isLoadingModels)
            }
            Text("Current: \(state.modelLabel)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var modeSection: some View {
        SettingsCard(title: "Modes") {
            HStack {
                Text("Enabled modes appear in the footer menu. Click pencil to edit prompt text.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { state.addMode(); editingModeID = state.currentAction.id } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(SettingsIconButtonStyle())
                .settingsFocus("modes.add", radius: 13, keyboardFocusable: true, activate: {
                    state.addMode()
                    editingModeID = state.currentAction.id
                    DispatchQueue.main.async {
                        settingsFocus.focus(modeFocusID(state.currentAction.id, "title"))
                    }
                    return true
                })
            }
            ForEach(state.actions) { action in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Toggle("", isOn: Binding(get: { action.isEnabled }, set: { _ in state.toggleModeEnabled(action.id) }))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .settingsFocus(modeFocusID(action.id, "enabled"), radius: 6, keyboardFocusable: true, activate: {
                                state.toggleModeEnabled(action.id)
                                return true
                            })
                        Button(action.title) { state.setCurrentAction(action.id) }
                            .buttonStyle(SettingsCapsuleButtonStyle(active: state.currentAction.id == action.id))
                            .settingsFocus(modeFocusID(action.id, "select"), radius: 12, keyboardFocusable: true, activate: {
                                state.setCurrentAction(action.id)
                                return true
                            })
                            .frame(width: 110, alignment: .leading)
                        Text(action.instruction)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text(state.settings.shortcutByAction[action.id] ?? "")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Button {
                            let willOpen = editingModeID != action.id
                            editingModeID = willOpen ? action.id : nil
                            if willOpen {
                                DispatchQueue.main.async {
                                    settingsFocus.focus(modeFocusID(action.id, "title"))
                                }
                            }
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(SettingsIconButtonStyle())
                        .settingsFocus(modeFocusID(action.id, "edit"), radius: 13, keyboardFocusable: true, activate: {
                            let willOpen = editingModeID != action.id
                            editingModeID = willOpen ? action.id : nil
                            if willOpen {
                                DispatchQueue.main.async {
                                    settingsFocus.focus(modeFocusID(action.id, "title"))
                                }
                            }
                            return true
                        })
                        Button { state.deleteMode(action) } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(SettingsIconButtonStyle(destructive: true))
                        .settingsFocus(modeFocusID(action.id, "delete"), radius: 13, keyboardFocusable: true, activate: {
                            state.deleteMode(action)
                            return true
                        })
                        .disabled(state.actions.count <= 1)
                    }
                    if editingModeID == action.id {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                TextField("Title", text: modeTitleBinding(action.id))
                                    .textFieldStyle(.roundedBorder)
                                    .settingsFocus(modeFocusID(action.id, "title"), radius: 6)
                                TextField("Shortcut", text: actionShortcutBinding(action.id))
                                    .textFieldStyle(.roundedBorder)
                                    .settingsFocus(modeFocusID(action.id, "shortcut"), radius: 6)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .frame(width: 120)
                            }
                            TextEditor(text: modeInstructionBinding(action.id))
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .frame(minHeight: 88, maxHeight: 120)
                                .scrollContentBackground(.hidden)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                                .settingsFocus(modeFocusID(action.id, "instruction"), radius: 10)
                        }
                        .padding(.leading, 26)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.045)))
            }
        }
    }

    private var editorSection: some View {
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

    private var shortcutSection: some View {
        SettingsCard(title: "Accepted models & shortcuts") {
            HStack(spacing: 12) {
                LabeledShortcutField(label: "Previous model", focusID: "shortcuts.previousModel", text: Binding(get: { state.settings.previousModelShortcut }, set: { state.settings.previousModelShortcut = $0; state.saveSettings() }))
                LabeledShortcutField(label: "Next model", focusID: "shortcuts.nextModel", text: Binding(get: { state.settings.nextModelShortcut }, set: { state.settings.nextModelShortcut = $0; state.saveSettings() }))
            }
            Text("Global show/hide is fixed for now: cmd+shift+space. Shortcuts below work while the editor is focused.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            let models = state.modelsByProvider[state.selectedProvider] ?? []
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

    private var pricingSection: some View {
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
                        HStack(spacing: 10) {
                            Text(model.id)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .lineLimit(1)
                            Spacer()
                            Text("in")
                                .foregroundStyle(.secondary)
                            TextField("0.00", value: pricingInputBinding(model.id), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .settingsFocus(modelFocusID(model.id, "pricing.input"), radius: 6)
                                .frame(width: 76)
                            Text("out")
                                .foregroundStyle(.secondary)
                            TextField("0.00", value: pricingOutputBinding(model.id), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .settingsFocus(modelFocusID(model.id, "pricing.output"), radius: 6)
                                .frame(width: 76)
                        }
                    }
                }
            }
        }
    }

    private var historySection: some View {
        SettingsCard(title: "History") {
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
            Text("Saved: \(state.history.count)/\(state.settings.historyLimit) LLM runs · \(state.draftSnapshots.count) draft backups")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.accentColor.opacity(0.85))
            if state.history.isEmpty && state.draftSnapshots.isEmpty {
                Text("No history yet.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(state.history) { entry in
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
                    if !state.draftSnapshots.isEmpty {
                        Divider().opacity(0.3)
                        ForEach(state.draftSnapshots.prefix(5)) { snapshot in
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
                                Button { state.inputText = snapshot.text; DraftStore.save(snapshot.text); state.status = "Draft restored" } label: {
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
                }
            }
        }
    }

    private func settingBool(_ keyPath: WritableKeyPath<RetypoSettings, Bool>) -> Binding<Bool> {
        Binding(get: { state.settings[keyPath: keyPath] }, set: { state.settings[keyPath: keyPath] = $0; state.saveSettings() })
    }

    private func actionShortcutBinding(_ actionID: String) -> Binding<String> {
        Binding(
            get: { state.settings.shortcutByAction[actionID] ?? "" },
            set: { state.settings.shortcutByAction[actionID] = $0; state.saveSettings() }
        )
    }

    private func modeTitleBinding(_ actionID: String) -> Binding<String> {
        Binding(
            get: { state.actions.first(where: { $0.id == actionID })?.title ?? "" },
            set: { newValue in
                guard var action = state.actions.first(where: { $0.id == actionID }) else { return }
                action.title = newValue
                state.updateMode(action)
            }
        )
    }

    private func modeInstructionBinding(_ actionID: String) -> Binding<String> {
        Binding(
            get: { state.actions.first(where: { $0.id == actionID })?.instruction ?? "" },
            set: { newValue in
                guard var action = state.actions.first(where: { $0.id == actionID }) else { return }
                action.instruction = newValue
                state.updateMode(action)
            }
        )
    }

    private func pricingInputBinding(_ modelID: String) -> Binding<Double> {
        Binding(
            get: { state.pricingBindingValue(for: state.selectedProvider, model: modelID).inputPerMillion },
            set: { newValue in
                var value = state.pricingBindingValue(for: state.selectedProvider, model: modelID)
                value.inputPerMillion = newValue
                state.setPricing(value, provider: state.selectedProvider, model: modelID)
            }
        )
    }

    private func pricingOutputBinding(_ modelID: String) -> Binding<Double> {
        Binding(
            get: { state.pricingBindingValue(for: state.selectedProvider, model: modelID).outputPerMillion },
            set: { newValue in
                var value = state.pricingBindingValue(for: state.selectedProvider, model: modelID)
                value.outputPerMillion = newValue
                state.setPricing(value, provider: state.selectedProvider, model: modelID)
            }
        )
    }

    private func modelShortcutBinding(_ modelID: String) -> Binding<String> {
        let key = state.settings.modelShortcutKey(provider: state.selectedProvider, modelID: modelID)
        return Binding(
            get: { state.settings.shortcutByModel[key] ?? "" },
            set: { state.settings.shortcutByModel[key] = $0; state.saveSettings() }
        )
    }
}

struct SettingsCard<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.13)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        .shadow(color: Color.accentColor.opacity(0.055), radius: 24, x: 0, y: 14)
    }
}

struct LabeledShortcutField: View {
    var label: String
    var focusID: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            TextField("cmd+opt+]", text: $text)
                .textFieldStyle(.roundedBorder)
                .settingsFocus(focusID, radius: 6)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
    }
}

struct SettingsCapsuleButtonStyle: ButtonStyle {
    var active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(active ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule(style: .continuous).fill(active ? Color.accentColor.opacity(configuration.isPressed ? 0.68 : 0.84) : Color.white.opacity(configuration.isPressed ? 0.12 : 0.08)))
            .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.13), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}

struct CandidateCard: View {
    var candidate: CandidateResult
    var selected: Bool
    var select: () -> Void
    var apply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(candidate.action.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Text(candidate.costUSD.map { String(format: "$%.4f", $0) } ?? "$—")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                Text(candidate.diff)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: 120)
            HStack {
                Button("Select") { select() }
                    .buttonStyle(.borderless)
                    .pointingCursor()
                Spacer()
                Button("Apply") { apply() }
                    .buttonStyle(.borderless)
                    .pointingCursor()
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(selected ? Color.accentColor.opacity(0.15) : Color.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(selected ? Color.accentColor.opacity(0.55) : Color.white.opacity(0.12), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture { select() }
        .pointingCursor()
    }
}

struct PointingCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { inside in
            if inside {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

extension View {
    func pointingCursor() -> some View {
        modifier(PointingCursorModifier())
    }
}

enum HistoryDisplayMode: String, CaseIterable {
    case input
    case output
    case diff

    var title: String {
        switch self {
        case .input: "Input"
        case .output: "Output"
        case .diff: "Diff"
        }
    }

    var next: HistoryDisplayMode {
        switch self {
        case .input: .output
        case .output: .diff
        case .diff: .input
        }
    }

    func text(for entry: HistoryEntry) -> String {
        switch self {
        case .input: entry.input
        case .output: entry.output
        case .diff: entry.diff
        }
    }
}

struct SettingsIconButtonStyle: ButtonStyle {
    var destructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(destructive ? Color.red.opacity(0.85) : Color.primary.opacity(0.80))
            .frame(width: 26, height: 24)
            .background(Circle().fill((destructive ? Color.red : Color.accentColor).opacity(configuration.isPressed ? 0.18 : 0.09)))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .pointingCursor()
    }
}
