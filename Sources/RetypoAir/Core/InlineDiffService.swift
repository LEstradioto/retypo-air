import Foundation

enum InlineDiffService {
    static func changedRanges(original: String, corrected: String) -> [NSRange] {
        guard original != corrected, !corrected.isEmpty else { return [] }
        let oldTokens = significantTokens(original)
        let newTokens = significantTokens(corrected)
        guard !newTokens.isEmpty else { return [] }

        let keepPairs = lcsPairs(oldTokens.map(\.text), newTokens.map(\.text))
        let keptNewIndexes = Set(keepPairs.map(\.newIndex))
        let changed = newTokens.enumerated().compactMap { index, token -> NSRange? in
            keptNewIndexes.contains(index) ? nil : token.range
        }
        return mergeNearby(changed)
    }

    static func changedWordCount(original: String, corrected: String) -> Int {
        changedRanges(original: original, corrected: corrected).count
    }

    private static func significantTokens(_ text: String) -> [(text: String, range: NSRange)] {
        let ns = text as NSString
        var tokens: [(String, NSRange)] = []
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: [.byWords, .localized]) { substring, range, _, _ in
            guard let substring else { return }
            tokens.append((substring.lowercased(), range))
        }
        if tokens.isEmpty, !text.isEmpty {
            tokens.append((text.lowercased(), NSRange(location: 0, length: ns.length)))
        }
        return tokens
    }

    private static func lcsPairs(_ old: [String], _ new: [String]) -> [(oldIndex: Int, newIndex: Int)] {
        guard !old.isEmpty, !new.isEmpty else { return [] }
        let dp = lcsTable(old: old, new: new)
        return walkLCS(old: old, new: new, dp: dp)
    }

    private static func lcsTable(old: [String], new: [String]) -> [[Int]] {
        var dp = Array(repeating: Array(repeating: 0, count: new.count + 1), count: old.count + 1)
        for i in stride(from: old.count - 1, through: 0, by: -1) {
            for j in stride(from: new.count - 1, through: 0, by: -1) {
                dp[i][j] = old[i] == new[j] ? dp[i + 1][j + 1] + 1 : max(dp[i + 1][j], dp[i][j + 1])
            }
        }
        return dp
    }

    private static func walkLCS(old: [String], new: [String], dp: [[Int]]) -> [(oldIndex: Int, newIndex: Int)] {
        var pairs: [(Int, Int)] = []
        var i = 0
        var j = 0
        while i < old.count, j < new.count {
            if old[i] == new[j] { pairs.append((i, j)); i += 1; j += 1 }
            else if dp[i + 1][j] >= dp[i][j + 1] { i += 1 }
            else { j += 1 }
        }
        return pairs
    }

    private static func mergeNearby(_ ranges: [NSRange]) -> [NSRange] {
        guard var current = ranges.sorted(by: { $0.location < $1.location }).first else { return [] }
        var merged: [NSRange] = []
        for range in ranges.sorted(by: { $0.location < $1.location }).dropFirst() {
            if range.location <= current.location + current.length + 2 {
                let end = max(current.location + current.length, range.location + range.length)
                current.length = end - current.location
            } else {
                merged.append(current)
                current = range
            }
        }
        merged.append(current)
        return merged
    }
}
