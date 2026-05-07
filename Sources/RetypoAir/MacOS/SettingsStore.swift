import Foundation
import AppKit

struct PanelFrame: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var nsRect: NSRect { NSRect(x: x, y: y, width: width, height: height) }

    init(x: Double = 420, y: Double = 260, width: Double = 760, height: Double = 500) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(_ rect: NSRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }
}

enum EditorLayoutMode: String, CaseIterable, Identifiable, Codable {
    case stacked
    case inline

    var id: String { rawValue }
    var displayName: String { self == .stacked ? "Stacked" : "Inline diff" }
}

enum MainTheme: String, CaseIterable, Identifiable, Codable {
    case glass
    case lighter

    var id: String { rawValue }
    var displayName: String { self == .glass ? "Glass" : "Lighter" }
}

struct RetypoSettings: Codable, Equatable {
    var provider: ProviderKind = .anthropic
    var modelByProvider: [ProviderKind: String] = [
        .anthropic: "claude-haiku-4-5-20251001"
    ]
    var autoCorrect: Bool = false
    var autoCopy: Bool = true
    var debounceMs: Int = 500
    var alwaysOnTop: Bool = false
    var hideAfterCopy: Bool = false
    var enterToCorrect: Bool = true
    var nativeSpellcheck: Bool = true
    var panelFrame: PanelFrame = PanelFrame()
    var currentActionID: String = "correct"
    var editorLayout: EditorLayoutMode = .inline
    var mainTheme: MainTheme = .glass
    var shortcutByAction: [String: String] = [
        "correct": "cmd+1",
        "improve": "cmd+2",
        "translate": "cmd+3",
        "simplify": "cmd+4",
        "summarize": "cmd+5",
        "bullets": "cmd+6",
        "better-way": "cmd+7",
        "tweet-fit": "cmd+8",
        "variations-3": "cmd+9",
        "respond-3-ways": "cmd+0"
    ]
    var shortcutByModel: [String: String] = [:]
    var acceptedModelIDsByProvider: [ProviderKind: [String]] = [:]
    var nextModelShortcut: String = "cmd+opt+]"
    var previousModelShortcut: String = "cmd+opt+["
    var followActiveScreenOnShow: Bool = true
    var historyLimit: Int = 10

    init() {}

    func selectedModel(for provider: ProviderKind) -> String? {
        let value = modelByProvider[provider]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    func modelShortcutKey(provider: ProviderKind, modelID: String) -> String {
        "\(provider.rawValue)::\(modelID)"
    }

    enum CodingKeys: String, CodingKey {
        case provider, modelByProvider, autoCorrect, autoCopy, debounceMs, alwaysOnTop, hideAfterCopy, enterToCorrect, nativeSpellcheck, panelFrame, currentActionID, editorLayout, mainTheme, shortcutByAction, shortcutByModel, acceptedModelIDsByProvider, nextModelShortcut, previousModelShortcut, followActiveScreenOnShow, historyLimit
    }

    init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = try container.decodeIfPresent(ProviderKind.self, forKey: .provider) ?? provider
        modelByProvider = try container.decodeIfPresent([ProviderKind: String].self, forKey: .modelByProvider) ?? modelByProvider
        autoCorrect = try container.decodeIfPresent(Bool.self, forKey: .autoCorrect) ?? autoCorrect
        autoCopy = try container.decodeIfPresent(Bool.self, forKey: .autoCopy) ?? autoCopy
        debounceMs = try container.decodeIfPresent(Int.self, forKey: .debounceMs) ?? debounceMs
        alwaysOnTop = try container.decodeIfPresent(Bool.self, forKey: .alwaysOnTop) ?? alwaysOnTop
        hideAfterCopy = try container.decodeIfPresent(Bool.self, forKey: .hideAfterCopy) ?? hideAfterCopy
        enterToCorrect = try container.decodeIfPresent(Bool.self, forKey: .enterToCorrect) ?? enterToCorrect
        nativeSpellcheck = try container.decodeIfPresent(Bool.self, forKey: .nativeSpellcheck) ?? nativeSpellcheck
        panelFrame = try container.decodeIfPresent(PanelFrame.self, forKey: .panelFrame) ?? panelFrame
        currentActionID = try container.decodeIfPresent(String.self, forKey: .currentActionID) ?? currentActionID
        editorLayout = try container.decodeIfPresent(EditorLayoutMode.self, forKey: .editorLayout) ?? editorLayout
        mainTheme = try container.decodeIfPresent(MainTheme.self, forKey: .mainTheme) ?? mainTheme
        if let shortcuts = try container.decodeIfPresent([String: String].self, forKey: .shortcutByAction) {
            shortcutByAction.merge(shortcuts) { _, new in new }
        }
        shortcutByModel = try container.decodeIfPresent([String: String].self, forKey: .shortcutByModel) ?? shortcutByModel
        acceptedModelIDsByProvider = try container.decodeIfPresent([ProviderKind: [String]].self, forKey: .acceptedModelIDsByProvider) ?? acceptedModelIDsByProvider
        nextModelShortcut = try container.decodeIfPresent(String.self, forKey: .nextModelShortcut) ?? nextModelShortcut
        previousModelShortcut = try container.decodeIfPresent(String.self, forKey: .previousModelShortcut) ?? previousModelShortcut
        followActiveScreenOnShow = try container.decodeIfPresent(Bool.self, forKey: .followActiveScreenOnShow) ?? followActiveScreenOnShow
        historyLimit = try container.decodeIfPresent(Int.self, forKey: .historyLimit) ?? historyLimit
    }
}

enum SettingsStore {
    /// Back-compat alias; new code should use `AppFiles.directory`.
    static var directory: URL { AppFiles.directory }

    private static let file = PersistedFile<RetypoSettings>(
        url: AppFiles.url("settings.json"),
        fallback: RetypoSettings()
    )

    static func load() -> RetypoSettings { file.load() }
    static func save(_ settings: RetypoSettings) { file.save(settings) }
}
