import SwiftUI

struct RetypoView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            LinearGradient(
                colors: [Color.white.opacity(0.10), Color.black.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().opacity(0.25)
                editor
                actions
                output
                footer
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
        .sheet(isPresented: $state.showSettings) {
            SettingsView()
                .environmentObject(state)
                .frame(width: 520, height: 520)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Retypo Air")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(state.status)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Picker("Provider", selection: Binding(get: { state.selectedProvider }, set: { state.selectedProvider = $0 })) {
                ForEach(ProviderKind.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .labelsHidden()
            .frame(width: 132)

            modelPicker

            Button("Refresh") { Task { await state.refreshModelsIfPossible() } }
                .buttonStyle(.borderless)
                .disabled(state.isLoadingModels)

            Toggle("Auto", isOn: Binding(
                get: { state.settings.autoCorrect },
                set: { state.settings.autoCorrect = $0; state.saveSettings() }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)

            Toggle("Top", isOn: Binding(
                get: { state.settings.alwaysOnTop },
                set: { _ in state.toggleAlwaysOnTop() }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)

            Button {
                state.showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var modelPicker: some View {
        let models = state.modelsByProvider[state.selectedProvider] ?? []
        return Picker("Model", selection: Binding(
            get: { state.selectedModel ?? "" },
            set: { if !$0.isEmpty { state.setSelectedModel($0) } }
        )) {
            Text(models.isEmpty ? "No models" : "Select model...").tag("")
            ForEach(models) { model in
                Text(model.id).tag(model.id)
            }
        }
        .labelsHidden()
        .frame(minWidth: 190, maxWidth: 280)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Draft")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Enter corrects · Shift+Enter new line")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            NativeTextEditor(
                text: $state.inputText,
                nativeSpellcheck: state.settings.nativeSpellcheck,
                onSubmit: { Task { await state.correctAndMaybeCopy(source: "enter") } },
                onChange: { state.onInputChanged() }
            )
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.56))
                    .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 18)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    private var actions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(state.actions) { action in
                    Button {
                        Task { await state.runAction(action) }
                    } label: {
                        Text(action.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(PillButtonStyle(active: action.id == "correct"))
                    .disabled(state.isCorrecting || state.selectedModel == nil)
                }
                Button("Copy Output") { state.copyOutput() }
                    .buttonStyle(PillButtonStyle(active: false))
                    .disabled(state.outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 18)
        }
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var output: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Result")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                if state.isCorrecting {
                    ProgressView().controlSize(.small)
                }
            }
            ScrollView {
                Text(state.diffText.isEmpty ? "Choose a model, type text, then press Enter. Auto mode corrects after 500ms." : state.diffText)
                    .font(.system(size: 12.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(state.diffText.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(14)
            }
            .frame(minHeight: 96, maxHeight: 150)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.08))
            )
        }
        .padding(.horizontal, 18)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("\(state.inputText.count) chars")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Text("API key: \(state.selectedProvider.apiKeyEnvironmentName)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text("Stored at ~/.retypo-air/settings.json")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { state.showSettings = false }
            }

            Form {
                Picker("Provider", selection: Binding(get: { state.selectedProvider }, set: { state.selectedProvider = $0 })) {
                    ForEach(ProviderKind.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("Model", selection: Binding(get: { state.selectedModel ?? "" }, set: { if !$0.isEmpty { state.setSelectedModel($0) } })) {
                    Text("Select model...").tag("")
                    ForEach(state.modelsByProvider[state.selectedProvider] ?? []) { Text($0.id).tag($0.id) }
                }
                Button("Refresh models") { Task { await state.refreshModelsIfPossible() } }

                Toggle("Auto correct after pause", isOn: settingBool(\.autoCorrect))
                Toggle("Auto copy result", isOn: settingBool(\.autoCopy))
                Toggle("Hide after copy", isOn: settingBool(\.hideAfterCopy))
                Toggle("Always on top", isOn: Binding(
                    get: { state.settings.alwaysOnTop },
                    set: { _ in state.toggleAlwaysOnTop() }
                ))
                Toggle("Native macOS spellcheck", isOn: settingBool(\.nativeSpellcheck))
                Stepper("Debounce: \(state.settings.debounceMs)ms", value: Binding(
                    get: { state.settings.debounceMs },
                    set: { state.settings.debounceMs = $0; state.saveSettings() }
                ), in: 200...2000, step: 100)
            }
            Spacer()
        }
        .padding(24)
    }

    private func settingBool(_ keyPath: WritableKeyPath<RetypoSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { state.settings[keyPath: keyPath] },
            set: { state.settings[keyPath: keyPath] = $0; state.saveSettings() }
        )
    }
}

struct PillButtonStyle: ButtonStyle {
    var active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(active ? Color.white : Color.primary)
            .background(
                Capsule(style: .continuous)
                    .fill(active ? Color.accentColor.opacity(configuration.isPressed ? 0.68 : 0.82) : Color.white.opacity(configuration.isPressed ? 0.12 : 0.08))
            )
            .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
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
