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

struct RetypoSettings: Codable, Equatable {
    var provider: ProviderKind = .groq
    var modelByProvider: [ProviderKind: String] = [:]
    var autoCorrect: Bool = true
    var autoCopy: Bool = true
    var debounceMs: Int = 500
    var alwaysOnTop: Bool = true
    var hideAfterCopy: Bool = false
    var enterToCorrect: Bool = true
    var nativeSpellcheck: Bool = true
    var panelFrame: PanelFrame = PanelFrame()

    func selectedModel(for provider: ProviderKind) -> String? {
        let value = modelByProvider[provider]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}

enum SettingsStore {
    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".retypo-air", isDirectory: true)
    }

    static var fileURL: URL { directory.appendingPathComponent("settings.json") }

    static func load() -> RetypoSettings {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(RetypoSettings.self, from: data)
        } catch {
            return RetypoSettings()
        }
    }

    static func save(_ settings: RetypoSettings) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            fputs("RetypoAir settings save failed: \(error)\n", stderr)
        }
    }
}
