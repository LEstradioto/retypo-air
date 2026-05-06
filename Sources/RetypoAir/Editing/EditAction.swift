import Foundation

struct EditAction: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var instruction: String
    var isEnabled: Bool = true

    static let defaults: [EditAction] = [
        EditAction(id: "correct", title: "Correct", instruction: "Correct typos only."),
        EditAction(id: "improve", title: "Improve", instruction: "Rewrite the text to be grammatically improved while preserving meaning and tone."),
        EditAction(id: "translate", title: "Translate", instruction: "Translate the text to English if it is not English; translate it to natural Brazilian Portuguese if it is already English."),
        EditAction(id: "simplify", title: "Simplify", instruction: "Simplify the text. Keep meaning. Use concise natural wording."),
        EditAction(id: "summarize", title: "Summarize", instruction: "Summarize the text in a compact paragraph."),
        EditAction(id: "bullets", title: "Bullets", instruction: "Convert the text into clear bullet points.")
    ]
}

enum EditActionStore {
    static var fileURL: URL { SettingsStore.directory.appendingPathComponent("modes.json") }

    static func load() -> [EditAction] {
        do {
            let data = try Data(contentsOf: fileURL)
            let actions = try JSONDecoder().decode([EditAction].self, from: data)
            return actions.isEmpty ? EditAction.defaults : actions
        } catch {
            save(EditAction.defaults)
            return EditAction.defaults
        }
    }

    static func save(_ actions: [EditAction]) {
        do {
            try FileManager.default.createDirectory(at: SettingsStore.directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(actions)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            fputs("RetypoAir modes save failed: \(error)\n", stderr)
        }
    }
}
