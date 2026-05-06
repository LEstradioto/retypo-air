import Foundation

struct TokenUsage: Codable, Hashable {
    var inputTokens: Int
    var outputTokens: Int
    var totalTokens: Int { inputTokens + outputTokens }

    static let zero = TokenUsage(inputTokens: 0, outputTokens: 0)
}

struct ModelPricing: Codable, Hashable {
    var inputPerMillion: Double
    var outputPerMillion: Double

    static let zero = ModelPricing(inputPerMillion: 0, outputPerMillion: 0)
}

struct CostSnapshot: Codable, Hashable {
    var usage: TokenUsage
    var costUSD: Double?
}

struct HistoryEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var provider: ProviderKind
    var model: String
    var actionID: String
    var actionTitle: String
    var input: String
    var output: String
    var diff: String
    var usage: TokenUsage
    var costUSD: Double?
}

enum PricingStore {
    static var fileURL: URL { SettingsStore.directory.appendingPathComponent("pricing.json") }

    static func load() -> [String: ModelPricing] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([String: ModelPricing].self, from: data)
        } catch {
            save([:])
            return [:]
        }
    }

    static func save(_ pricing: [String: ModelPricing]) {
        do {
            try FileManager.default.createDirectory(at: SettingsStore.directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(pricing)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            fputs("RetypoAir pricing save failed: \(error)\n", stderr)
        }
    }

    static func key(provider: ProviderKind, model: String) -> String { "\(provider.rawValue)::\(model)" }
}

enum HistoryStore {
    static var fileURL: URL { SettingsStore.directory.appendingPathComponent("history.json") }

    static func load() -> [HistoryEntry] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([HistoryEntry].self, from: data)
        } catch {
            return []
        }
    }

    static func save(_ entries: [HistoryEntry], limit: Int = 10) {
        do {
            try FileManager.default.createDirectory(at: SettingsStore.directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(Array(entries.prefix(max(1, limit))))
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            fputs("RetypoAir history save failed: \(error)\n", stderr)
        }
    }
}

struct UsageLedgerEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var provider: ProviderKind
    var model: String
    var usage: TokenUsage
    var costUSD: Double?
}

enum UsageLedgerStore {
    static var fileURL: URL { SettingsStore.directory.appendingPathComponent("usage-ledger.json") }

    static func load() -> [UsageLedgerEntry] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([UsageLedgerEntry].self, from: data)
        } catch {
            return []
        }
    }

    static func save(_ entries: [UsageLedgerEntry]) {
        do {
            try FileManager.default.createDirectory(at: SettingsStore.directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(Array(entries.prefix(500)))
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            fputs("RetypoAir usage ledger save failed: \(error)\n", stderr)
        }
    }
}

struct DraftSnapshot: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var text: String
}

enum DraftSnapshotStore {
    static var fileURL: URL { SettingsStore.directory.appendingPathComponent("draft-history.json") }

    static func load() -> [DraftSnapshot] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([DraftSnapshot].self, from: data)
        } catch {
            return []
        }
    }

    static func save(_ entries: [DraftSnapshot]) {
        do {
            try FileManager.default.createDirectory(at: SettingsStore.directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(Array(entries.prefix(20)))
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            fputs("RetypoAir draft history save failed: \(error)\n", stderr)
        }
    }
}

struct CandidateResult: Identifiable, Hashable {
    var id: UUID = UUID()
    var action: EditAction
    var output: String
    var diff: String
    var usage: TokenUsage
    var costUSD: Double?
}

enum DraftStore {
    static var fileURL: URL { SettingsStore.directory.appendingPathComponent("draft.txt") }

    static func load() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    static func save(_ text: String) {
        do {
            try FileManager.default.createDirectory(at: SettingsStore.directory, withIntermediateDirectories: true)
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            fputs("RetypoAir draft save failed: \(error)\n", stderr)
        }
    }
}
