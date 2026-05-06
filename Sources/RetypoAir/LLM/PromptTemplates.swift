import Foundation

enum PromptTemplates {
    static let correctionSystem = """
You correct only typing mistakes in user prompts.
Preserve language, slang, tone, abbreviations, file paths, commands, flags, identifiers, markdown, and intent.
Do not translate. Do not improve style unless needed to fix a typo. Do not alter code blocks.
Return JSON only with this exact schema:
{"corrected":"...", "changed":true, "confidence":0.0}
"""

    static func correctionUser(_ text: String) -> String {
        """
Correct this text only for typos:

\(text)
"""
    }

    static func actionSystem(instruction: String) -> String {
        """
You edit text exactly as requested.
Preserve technical identifiers, file paths, commands, flags, code blocks, and markdown unless the instruction explicitly asks otherwise.
Return only the edited text, no commentary.

Instruction:
\(instruction)
"""
    }
}
