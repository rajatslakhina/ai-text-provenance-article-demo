import XCTest
@testable import ProvenanceLedger

final class LedgerTests: XCTestCase {
    func testFingerprintIgnoresCaseWhitespaceAndInvisibleCharacters() {
        let original = "Thanks for reaching out about the double charge."
        let quoted = "  thanks for\u{200B} reaching   out about\nthe double charge. "
        XCTAssertEqual(ProvenanceLedger.fingerprint(original), ProvenanceLedger.fingerprint(quoted))
        XCTAssertNotEqual(ProvenanceLedger.fingerprint(original),
                          ProvenanceLedger.fingerprint("Thanks for reaching out about the duplicate charge."))
    }

    func testJournalistQuoteIsAnsweredFromTheLedger() throws {
        let ledger = SampleWeek.ledger()
        let refund = try XCTUnwrap(ledger.records.first { $0.stamp.model == "claude-sonnet-4-6" && $0.surface == .supportReply })
        let reformatted = refund.final.string.uppercased().replacingOccurrences(of: ". ", with: ".\n\n")
        let answer = ledger.answer(for: reformatted)
        XCTAssertEqual(answer.records.map(\.id), [refund.id])
        XCTAssertEqual(answer.records.first?.stamp.sampling.temperature, 0.2)
        XCTAssertEqual(answer.records.first?.stamp.promptVersion, "support-reply@v12")
    }

    func testRewordedQuoteIsNotFound() {
        let ledger = SampleWeek.ledger()
        XCTAssertEqual(ledger.answer(for: "Thanks for writing this up, Sam, sync is fixed."), .notFound)
    }

    func testIdenticalTextRecordedTwiceReturnsBoth() {
        var ledger = ProvenanceLedger(rules: MarkExpectationRules(coverage: .documentedNov2026))
        let text = AttributedText.model("Your streak ends at midnight.", generation: GenerationID("a"))
        let stamp = GenerationStamp(id: GenerationID("a"), model: "claude-sonnet-4-6", platform: .anthropicAPI,
                                    promptVersion: "n@1", generatedAt: Calendar.utcDate(2026, 11, 5))
        ledger.record(stamp: stamp, surface: .notification, draft: text, final: text, signoff: nil)
        ledger.record(stamp: stamp, surface: .notification, draft: text, final: text, signoff: nil)
        XCTAssertEqual(ledger.answer(for: text.string).records.map(\.id), [0, 1])
    }

    // MARK: Structured output contract

    func testStructuredDraftAttributesVerifiedQuote() throws {
        let input = "The app logs me out every morning."
        let draft = StructuredDraft(segments: [
            .init(kind: .generated, text: "You wrote: "),
            .init(kind: .quoted, text: "The app logs me out every morning."),
            .init(kind: .generated, text: " Fixed in 4.12.1."),
        ])
        let text = try draft.attributed(generation: GenerationID("g"), userInput: input)
        XCTAssertEqual(text.quotedCharacterCount, input.count)
        XCTAssertEqual(text.modelShare, 1)
    }

    func testStructuredDraftRejectsInventedQuote() {
        let draft = StructuredDraft(segments: [
            .init(kind: .quoted, text: "We take your privacy seriously."),
        ])
        XCTAssertThrowsError(try draft.attributed(generation: GenerationID("g"), userInput: "It crashes.")) { error in
            XCTAssertEqual(error as? StructuredDraft.ValidationError, .unverifiedQuote("We take your privacy seriously."))
        }
    }

    func testStructuredDraftRejectsEmptyAndDecodesFromJSON() throws {
        XCTAssertThrowsError(try StructuredDraft(segments: []).attributed(generation: GenerationID("g"), userInput: ""))
        let json = #"{"segments":[{"kind":"generated","text":"Hi."},{"kind":"quoted","text":"crash"}]}"#
        let decoded = try JSONDecoder().decode(StructuredDraft.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.segments.count, 2)
        XCTAssertEqual(decoded.segments.last?.kind, .quoted)
    }
}
