import Foundation

struct EditAction: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var instruction: String
    var isEnabled: Bool = true

    static let defaults: [EditAction] = [
        EditAction(id: "correct", title: "Correct", instruction: "Fix typos only. Preserve wording, tone, punctuation style, and language unless a typo requires a minimal correction."),
        EditAction(id: "typos-grammar", title: "Typos and Grammar", instruction: "Fix typos, grammar, punctuation, and awkward grammatical mistakes while preserving the original meaning, voice, and language."),
        EditAction(id: "improve", title: "Improve Writing", instruction: "Rewrite the text to improve clarity, flow, and grammar while preserving meaning and tone."),
        EditAction(id: "translate", title: "Translate", instruction: "Translate the text to English if it is not English; translate it to natural Brazilian Portuguese if it is already English."),
        EditAction(id: "simplify", title: "Simplify", instruction: "Simplify the text. Keep meaning. Use concise natural wording."),
        EditAction(id: "summarize", title: "Summarize", instruction: "Summarize the text in a compact paragraph."),
        EditAction(id: "bullets", title: "Bullets", instruction: "Convert the text into clear bullet points."),
        EditAction(id: "better-way", title: "Better way of saying", instruction: "Rewrite the text as a better, more natural way of saying the same thing. Keep it concise and preserve intent."),
        EditAction(id: "tweet-fit", title: "Make this Tweet Fit", instruction: "Rewrite the text to fit within 280 characters for X/Twitter. Preserve the core point and make it natural."),
        EditAction(id: "variations-3", title: "Generate 3 variations", instruction: "Generate three distinct polished variations of the text. Number them 1, 2, and 3."),
        EditAction(id: "respond-3-ways", title: "How to respond 3 ways", instruction: "Suggest three possible replies to the text: one concise, one friendly, and one direct. Number them 1, 2, and 3."),
        EditAction(id: "caveman", title: "Caveman", instruction: "Rewrite the text in an intentionally simple caveman style. Keep the meaning, use short blunt words, and avoid complex grammar.")
    ]
}

enum EditActionStore {
    static var fileURL: URL { SettingsStore.directory.appendingPathComponent("modes.json") }

    static func load() -> [EditAction] {
        do {
            let data = try Data(contentsOf: fileURL)
            let actions = try JSONDecoder().decode([EditAction].self, from: data)
            let merged = mergeDefaults(into: actions)
            if merged != actions { save(merged) }
            return merged.isEmpty ? EditAction.defaults : merged
        } catch {
            save(EditAction.defaults)
            return EditAction.defaults
        }
    }

    private static func mergeDefaults(into actions: [EditAction]) -> [EditAction] {
        guard !actions.isEmpty else { return EditAction.defaults }
        var result = actions
        let existingIDs = Set(actions.map(\.id))
        for action in EditAction.defaults where !existingIDs.contains(action.id) {
            result.append(action)
        }
        return result
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
