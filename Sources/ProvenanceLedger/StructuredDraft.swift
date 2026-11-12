import Foundation

/// The output contract you ask the model for: generated words and carried-over user
/// words in separate segments, so provenance is a field, not a guess.
public struct StructuredDraft: Codable, Hashable, Sendable {
    public struct Segment: Codable, Hashable, Sendable {
        public enum Kind: String, Codable, Sendable {
            case generated
            case quoted
        }
        public let kind: Kind
        public let text: String
        public init(kind: Kind, text: String) {
            self.kind = kind
            self.text = text
        }
    }

    public let segments: [Segment]
    public init(segments: [Segment]) { self.segments = segments }

    /// Put this in the system prompt alongside a JSON schema for `StructuredDraft`.
    public static let promptContract = """
    Return JSON matching the schema. Split your reply into segments in reading order.
    Use kind "quoted" ONLY for text copied character-for-character from the user input \
    between <user_input> tags. Everything you wrote yourself is kind "generated". \
    Never paraphrase inside a "quoted" segment.
    """

    public enum ValidationError: Error, Hashable, Sendable {
        /// The model labelled text as quoted that is not in the user input. Treat it
        /// as generated, or reject the draft; never trust the label.
        case unverifiedQuote(String)
        case empty
    }

    /// Converts the draft to `AttributedText`. A "quoted" segment is accepted only if
    /// it appears verbatim in `userInput`; otherwise the model could launder its own
    /// words out of the provenance record by calling them quotes.
    public func attributed(generation: GenerationID, userInput: String) throws -> AttributedText {
        guard !segments.isEmpty else { throw ValidationError.empty }
        var spans: [Span] = []
        for segment in segments {
            switch segment.kind {
            case .generated:
                spans.append(Span(.model(generation), segment.text))
            case .quoted:
                guard !segment.text.isEmpty, userInput.contains(segment.text) else {
                    throw ValidationError.unverifiedQuote(segment.text)
                }
                spans.append(Span(.quoted, segment.text))
            }
        }
        return AttributedText(spans: spans)
    }
}
