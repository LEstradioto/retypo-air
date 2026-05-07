import SwiftUI

extension SettingsView {
    var modeSection: some View {
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
                modeRow(action)
            }
        }
    }

    private func modeRow(_ action: EditAction) -> some View {
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
                modeEditor(action)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.045)))
    }

    private func modeEditor(_ action: EditAction) -> some View {
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
