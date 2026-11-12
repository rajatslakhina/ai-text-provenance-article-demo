import Foundation

public enum ServingPlatform: String, Codable, Sendable, CaseIterable {
    case anthropicAPI
    case bedrock
}

/// Sampling values your code (or your framework) sent. `nil` means "not sent".
public struct SamplingOverrides: Hashable, Codable, Sendable {
    public var temperature: Double?
    public var topP: Double?
    public var topK: Int?

    public init(temperature: Double? = nil, topP: Double? = nil, topK: Int? = nil) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
    }

    public static let none = SamplingOverrides()
    public var sentAny: Bool { temperature != nil || topP != nil || topK != nil }
}

/// Everything you knew at the moment of the call. Record it then; you cannot
/// reconstruct it later, and the vendor's detector will not tell you.
public struct GenerationStamp: Hashable, Codable, Sendable {
    public let id: GenerationID
    public let model: String
    public let platform: ServingPlatform
    public let promptVersion: String
    public let sampling: SamplingOverrides
    public let generatedAt: Date

    public init(id: GenerationID, model: String, platform: ServingPlatform,
                promptVersion: String, sampling: SamplingOverrides = .none, generatedAt: Date) {
        self.id = id
        self.model = model
        self.platform = platform
        self.promptVersion = promptVersion
        self.sampling = sampling
        self.generatedAt = generatedAt
    }
}

/// One row of a vendor's documented watermark coverage.
public struct CoverageEntry: Hashable, Codable, Sendable {
    public let markedFrom: [ServingPlatform: Date]
    /// The vendor says non-default sampling values may leave the mark out.
    public let samplingSensitive: Bool

    public init(markedFrom: [ServingPlatform: Date], samplingSensitive: Bool = false) {
        self.markedFrom = markedFrom
        self.samplingSensitive = samplingSensitive
    }
}

/// A coverage table you own and update, keyed by the model string you send.
public struct WatermarkCoverage: Sendable {
    public var entries: [String: CoverageEntry]
    /// Rollout windows during which a platform may serve a mix of marked and
    /// unmarked text. Dates inside `[start, end)` count as weak.
    public var rolloutWindows: [ServingPlatform: (start: Date, end: Date)]

    public init(entries: [String: CoverageEntry],
                rolloutWindows: [ServingPlatform: (start: Date, end: Date)] = [:]) {
        self.entries = entries
        self.rolloutWindows = rolloutWindows
    }
}

public enum WeakReason: Hashable, Sendable {
    case samplingOverride
    case shortText(sentences: Int)
    case heavyHumanEdit(humanShare: Double)
    case platformRollout
}

public enum UnmarkedReason: Hashable, Sendable {
    case noModelText
    case coverageNotDocumented
    case generatedBeforeCoverage
}

/// What a third-party detector would *probably* see. It is an expectation from
/// documented caveats, not a detection result: you do not have the detector.
public enum MarkExpectation: Hashable, Sendable {
    case expected
    case weak([WeakReason])
    case notExpected(UnmarkedReason)

    public var shortLabel: String {
        switch self {
        case .expected: return "Mark expected"
        case .weak: return "Mark unreliable"
        case .notExpected: return "No mark expected"
        }
    }
}

public struct MarkExpectationRules: Sendable {
    public var coverage: WatermarkCoverage
    /// Below this many sentences of surviving model text the mark is treated as weak.
    public var minimumSentences: Int
    /// Above this human share the mark is treated as weak.
    public var heavyEditShare: Double

    public init(coverage: WatermarkCoverage, minimumSentences: Int = 5, heavyEditShare: Double = 0.5) {
        self.coverage = coverage
        self.minimumSentences = minimumSentences
        self.heavyEditShare = heavyEditShare
    }

    public func expectation(for stamp: GenerationStamp, final text: AttributedText) -> MarkExpectation {
        guard text.modelCharacterCount > 0 else { return .notExpected(.noModelText) }
        guard let entry = coverage.entries[stamp.model],
              let from = entry.markedFrom[stamp.platform] else {
            return .notExpected(.coverageNotDocumented)
        }
        guard stamp.generatedAt >= from else { return .notExpected(.generatedBeforeCoverage) }

        var reasons: [WeakReason] = []
        if let window = coverage.rolloutWindows[stamp.platform],
           stamp.generatedAt >= window.start, stamp.generatedAt < window.end {
            reasons.append(.platformRollout)
        }
        if entry.samplingSensitive, stamp.sampling.sentAny {
            reasons.append(.samplingOverride)
        }
        let sentences = text.modelSentenceCount
        if sentences < minimumSentences {
            reasons.append(.shortText(sentences: sentences))
        }
        if text.humanShare > heavyEditShare {
            reasons.append(.heavyHumanEdit(humanShare: text.humanShare))
        }
        return reasons.isEmpty ? .expected : .weak(reasons)
    }
}

public enum SentenceCounter {
    /// Splits text into sentences. A sentence ends at `.`, `!` or `?` followed by
    /// whitespace or the end of the text, so "4.12" and "e.g.x" do not split. Repeated
    /// terminators ("?!", "...") end one sentence. Trailing text with letters but no
    /// terminator is one more sentence.
    static func sentenceRanges(_ characters: [Character]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var start = 0
        var sawLetter = false
        var i = 0
        while i < characters.count {
            let c = characters[i]
            if c.isLetter || c.isNumber { sawLetter = true }
            if ".!?".contains(c), sawLetter {
                var end = i + 1
                while end < characters.count, ".!?\"\u{201D})".contains(characters[end]) { end += 1 }
                if end == characters.count || characters[end].isWhitespace {
                    ranges.append(start..<end)
                    start = end
                    sawLetter = false
                    i = end
                    continue
                }
            }
            i += 1
        }
        if sawLetter { ranges.append(start..<characters.count) }
        return ranges
    }

    public static func count(_ text: String) -> Int {
        sentenceRanges(Array(text)).count
    }
}

extension AttributedText {
    /// Sentences in which the model chose at least half of the authored characters.
    /// Quoted text counts for neither side. This is the length signal that matters
    /// for a watermark, which needs runs of the model's own word choices.
    public var modelSentenceCount: Int {
        let characters = spans.flatMap { span in span.text.map { ($0, span.origin) } }
        let ranges = SentenceCounter.sentenceRanges(characters.map(\.0))
        return ranges.filter { range in
            var model = 0, authored = 0
            for k in range {
                switch characters[k].1 {
                case .model: model += 1; authored += 1
                case .human: authored += 1
                case .quoted: break
                }
            }
            return authored > 0 && model * 2 >= authored
        }.count
    }
}
