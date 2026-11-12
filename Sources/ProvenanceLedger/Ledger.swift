import Foundation

public struct LedgerRecord: Hashable, Sendable, Identifiable {
    public let id: Int
    public let fingerprint: UInt64
    public let stamp: GenerationStamp
    public let surface: Surface
    public let draft: AttributedText
    public let final: AttributedText
    public let signoff: EditorialSignoff?
    public let expectation: MarkExpectation
    public let disclosure: DisclosureDecision
}

public enum LedgerAnswer: Hashable, Sendable {
    case found([LedgerRecord])
    case notFound

    public var records: [LedgerRecord] {
        if case .found(let records) = self { return records }
        return []
    }
}

/// An append-only record of every model-assisted text your product shipped, so that
/// when someone with a detector says "Claude wrote this", your team answers first:
/// which model, which prompt version, how much a person changed, who signed off and
/// what label the user saw.
public struct ProvenanceLedger: Sendable {
    public private(set) var records: [LedgerRecord] = []
    private var index: [UInt64: [Int]] = [:]
    public let rules: MarkExpectationRules
    public let policy: DisclosurePolicy

    public init(rules: MarkExpectationRules, policy: DisclosurePolicy = DisclosurePolicy()) {
        self.rules = rules
        self.policy = policy
    }

    @discardableResult
    public mutating func record(stamp: GenerationStamp, surface: Surface, draft: AttributedText,
                                final: AttributedText, signoff: EditorialSignoff?) -> LedgerRecord {
        let fingerprint = ProvenanceLedger.fingerprint(final.string)
        let record = LedgerRecord(
            id: records.count,
            fingerprint: fingerprint,
            stamp: stamp,
            surface: surface,
            draft: draft,
            final: final,
            signoff: signoff,
            expectation: rules.expectation(for: stamp, final: final),
            disclosure: policy.decide(final, surface: surface, signoff: signoff)
        )
        records.append(record)
        index[fingerprint, default: []].append(record.id)
        return record
    }

    /// Looks up text someone quoted back at you. Matching is on a normalized
    /// fingerprint, so case, whitespace and invisible format characters (zero-width
    /// spaces, joiners) do not hide a match. Wording changes do.
    public func answer(for quotedText: String) -> LedgerAnswer {
        let ids = index[ProvenanceLedger.fingerprint(quotedText)] ?? []
        let found = ids.compactMap { id in records.indices.contains(id) ? records[id] : nil }
        return found.isEmpty ? .notFound : .found(found)
    }

    /// FNV-1a 64 over a normalized form: lowercased, Unicode format characters
    /// removed, runs of whitespace collapsed to one space, ends trimmed.
    public static func fingerprint(_ text: String) -> UInt64 {
        var normalized = String.UnicodeScalarView()
        var pendingSpace = false
        for scalar in text.lowercased().unicodeScalars {
            if scalar.properties.generalCategory == .format { continue }
            if scalar.properties.isWhitespace {
                pendingSpace = !normalized.isEmpty
                continue
            }
            if pendingSpace { normalized.append(" "); pendingSpace = false }
            normalized.append(scalar)
        }
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in String(normalized).utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
