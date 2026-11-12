import Foundation

/// Identifies one model call. Store it next to the request you sent.
public struct GenerationID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: String
    public init(_ raw: String) { self.raw = raw }
    public var description: String { raw }
}

/// Who chose the words in a span.
public enum SpanOrigin: Hashable, Codable, Sendable {
    /// Words the model picked. These are the words a text watermark lives in.
    case model(GenerationID)
    /// Words a person on your team typed.
    case human(author: String)
    /// Text a user supplied that the model was asked to carry verbatim (for example,
    /// the customer review a reply quotes). Neither your model nor your team wrote it.
    case quoted

    public var isModel: Bool { if case .model = self { return true } else { return false } }
    public var isHuman: Bool { if case .human = self { return true } else { return false } }
}

public struct Span: Hashable, Codable, Sendable {
    public let origin: SpanOrigin
    public let text: String
    public init(_ origin: SpanOrigin, _ text: String) {
        self.origin = origin
        self.text = text
    }
}

/// Text that remembers, character by character, who wrote it.
///
/// The point of this type is that provenance is recorded when text is created and
/// carried through every edit, instead of being guessed afterwards.
public struct AttributedText: Hashable, Codable, Sendable {
    public private(set) var spans: [Span]

    public init(spans: [Span]) {
        self.spans = AttributedText.normalized(spans)
    }

    public static func model(_ text: String, generation: GenerationID) -> AttributedText {
        AttributedText(spans: [Span(.model(generation), text)])
    }

    public static func human(_ text: String, author: String) -> AttributedText {
        AttributedText(spans: [Span(.human(author: author), text)])
    }

    public var string: String { spans.map(\.text).joined() }

    public var modelCharacterCount: Int { count { $0.isModel } }
    public var humanCharacterCount: Int { count { $0.isHuman } }
    public var quotedCharacterCount: Int { count { $0 == .quoted } }

    /// Share of *authored* characters the model chose. Quoted user text is excluded
    /// from both sides, because neither party wrote it. Returns 0 for empty text.
    public var modelShare: Double {
        let authored = modelCharacterCount + humanCharacterCount
        guard authored > 0 else { return 0 }
        return Double(modelCharacterCount) / Double(authored)
    }

    /// Share of authored characters a person typed. `modelShare + humanShare == 1`
    /// whenever the text contains any authored characters.
    public var humanShare: Double {
        let authored = modelCharacterCount + humanCharacterCount
        guard authored > 0 else { return 0 }
        return Double(humanCharacterCount) / Double(authored)
    }

    /// Only the characters the model chose that survived editing, in order.
    public var survivingModelText: String {
        spans.filter { $0.origin.isModel }.map(\.text).joined()
    }

    private func count(_ predicate: (SpanOrigin) -> Bool) -> Int {
        spans.reduce(0) { $0 + (predicate($1.origin) ? $1.text.count : 0) }
    }

    private static func normalized(_ spans: [Span]) -> [Span] {
        var out: [Span] = []
        for span in spans where !span.text.isEmpty {
            if let last = out.last, last.origin == span.origin {
                out[out.count - 1] = Span(last.origin, last.text + span.text)
            } else {
                out.append(span)
            }
        }
        return out
    }
}
