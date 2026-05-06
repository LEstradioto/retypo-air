import Foundation

struct EditAction: Identifiable, Hashable {
    var id: String
    var title: String
    var instruction: String

    static let defaults: [EditAction] = [
        EditAction(id: "correct", title: "Correct", instruction: "Correct typos only."),
        EditAction(id: "improve", title: "Improve", instruction: "Rewrite the text to be grammatically improved while preserving meaning and tone."),
        EditAction(id: "translate", title: "Translate", instruction: "Translate the text to English if it is not English; translate it to natural Brazilian Portuguese if it is already English."),
        EditAction(id: "simplify", title: "Simplify", instruction: "Simplify the text. Keep meaning. Use concise natural wording."),
        EditAction(id: "summarize", title: "Summarize", instruction: "Summarize the text in a compact paragraph."),
        EditAction(id: "bullets", title: "Bullets", instruction: "Convert the text into clear bullet points.")
    ]
}
