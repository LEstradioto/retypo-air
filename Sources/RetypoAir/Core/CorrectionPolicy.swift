import Foundation

enum CorrectionPolicy {
    static func shouldAutoCorrect(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8 else { return false }
        guard trimmed.count <= 6_000 else { return false }
        if trimmed.contains("```") { return false }
        if looksLikeShellCommand(trimmed) { return false }
        if symbolRatio(trimmed) > 0.34 { return false }
        return true
    }

    static func looksLikeShellCommand(_ text: String) -> Bool {
        let firstLine = text.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? text
        let commandPrefixes = [
            "git ", "npm ", "pnpm ", "yarn ", "bun ", "swift ", "xcodebuild ", "docker ",
            "kubectl ", "rails ", "bundle ", "bin/", "./", "cd ", "rm ", "mv ", "cp ", "cat ",
            "sed ", "awk ", "grep ", "curl ", "ssh ", "gh ", "codex ", "claude "
        ]
        let lower = firstLine.lowercased().trimmingCharacters(in: .whitespaces)
        return commandPrefixes.contains { lower.hasPrefix($0) }
    }

    private static func symbolRatio(_ text: String) -> Double {
        let chars = Array(text)
        guard !chars.isEmpty else { return 0 }
        let symbolCount = chars.filter { ch in
            guard let scalar = ch.unicodeScalars.first else { return false }
            return CharacterSet.punctuationCharacters.contains(scalar) || CharacterSet.symbols.contains(scalar)
        }.count
        return Double(symbolCount) / Double(chars.count)
    }
}
