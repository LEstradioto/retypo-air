import SwiftUI

@MainActor
final class SettingsFocusCoordinator: ObservableObject {
    @Published var focusedID: String?
    private var order: [String] = []
    private var actions: [String: () -> Bool] = [:]

    func setOrder(_ ids: [String]) {
        var seen = Set<String>()
        order = ids.filter { seen.insert($0).inserted }
        if let focusedID, order.contains(focusedID) {
            return
        }
        focusedID = order.first
    }

    func focusFirst() {
        focusedID = order.first
    }

    func focus(_ id: String) {
        if order.contains(id) {
            focusedID = id
        }
    }

    func advance(reverse: Bool) {
        guard !order.isEmpty else { return }
        guard let focusedID, let index = order.firstIndex(of: focusedID) else {
            self.focusedID = reverse ? order.last : order.first
            return
        }
        let delta = reverse ? -1 : 1
        self.focusedID = order[(index + delta + order.count) % order.count]
    }

    func registerAction(_ id: String, action: @escaping () -> Bool) {
        actions[id] = action
    }

    func unregisterAction(_ id: String) {
        actions[id] = nil
    }

    func activateFocused() -> Bool {
        guard let focusedID, let action = actions[focusedID] else { return false }
        return action()
    }
}

struct FocusRingStyle: ViewModifier {
    @FocusState private var isFocused: Bool
    var radius: CGFloat = 8
    var keyboardFocusable: Bool = false

    func body(content: Content) -> some View {
        if keyboardFocusable {
            content
                .focusable(true)
                .focused($isFocused)
                .overlay(focusOverlay)
        } else {
            content
                .focused($isFocused)
                .overlay(focusOverlay)
        }
    }

    private var focusOverlay: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(isFocused ? Color.accentColor.opacity(0.72) : Color.clear, lineWidth: 1.5)
    }
}

struct SettingsFocusStyle: ViewModifier {
    @EnvironmentObject private var coordinator: SettingsFocusCoordinator
    @FocusState private var isNativeFocused: Bool
    var id: String
    var radius: CGFloat = 8
    var keyboardFocusable: Bool = false
    var activate: (() -> Bool)?

    func body(content: Content) -> some View {
        let isVisuallyFocused = coordinator.focusedID == id || isNativeFocused
        let view = content
            .id(id)
            .focused($isNativeFocused)
            .onAppear {
                isNativeFocused = coordinator.focusedID == id
                if let activate {
                    coordinator.registerAction(id, action: activate)
                }
            }
            .onDisappear {
                coordinator.unregisterAction(id)
            }
            .onChange(of: coordinator.focusedID) { nextID in
                isNativeFocused = nextID == id
                if nextID == id, let activate {
                    coordinator.registerAction(id, action: activate)
                }
            }
            .onChange(of: isNativeFocused) { focused in
                if focused, coordinator.focusedID != id {
                    coordinator.focusedID = id
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(isVisuallyFocused ? Color.accentColor.opacity(0.86) : Color.clear, lineWidth: 1.6)
            )

        if keyboardFocusable {
            view.focusable(true)
        } else {
            view
        }
    }
}

extension View {
    func focusRing(radius: CGFloat = 8, keyboardFocusable: Bool = false) -> some View {
        modifier(FocusRingStyle(radius: radius, keyboardFocusable: keyboardFocusable))
    }

    func settingsFocus(_ id: String, radius: CGFloat = 8, keyboardFocusable: Bool = false, activate: (() -> Bool)? = nil) -> some View {
        modifier(SettingsFocusStyle(id: id, radius: radius, keyboardFocusable: keyboardFocusable, activate: activate))
    }
}
