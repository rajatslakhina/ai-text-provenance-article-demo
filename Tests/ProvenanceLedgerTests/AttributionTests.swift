import XCTest
@testable import ProvenanceLedger

final class AttributionTests: XCTestCase {
    let gen = GenerationID("g1")

    func testUneditedDraftIsAllModel() {
        let text = AttributedText.model("Thanks for the report.", generation: gen)
        XCTAssertEqual(text.modelShare, 1)
        XCTAssertEqual(text.humanShare, 0)
        XCTAssertEqual(text.edited(to: text.string, by: "p"), text)
    }

    func testChangedWordIsAttributedToEditorAsWholeWord() {
        let draft = AttributedText.model("Thanks for writing this up, Sam. The fix ships this week.", generation: gen)
        let final = draft.edited(to: "Thanks for writing this up, Sasha. The fix ships this week.", by: "priya")
        XCTAssertEqual(final.string, "Thanks for writing this up, Sasha. The fix ships this week.")
        XCTAssertEqual(final.humanCharacterCount, "Sasha".count)
        XCTAssertTrue(final.spans.contains(Span(.human(author: "priya"), "Sasha")))
    }

    func testFullRewriteKeepsNoModelText() {
        let draft = AttributedText.model(
            "Thank you for reporting the crash. Our team is investigating the issue as a priority.", generation: gen)
        let final = draft.edited(to: "Found it: big photos hit a memory limit. 4.12.1 fixes the crash, update and you are good.", by: "marco")
        // Common words ("the", "crash") line up in a character or word diff, but a
        // rewrite has not kept the model's choices.
        XCTAssertEqual(final.modelCharacterCount, 0)
        XCTAssertEqual(final.humanShare, 1)
    }

    func testInsertedSentenceIsHumanAndRestSurvives() {
        let draft = AttributedText.model("No data was lost. We added monitoring for expiry.", generation: gen)
        let final = draft.edited(to: "No data was lost. The renewal owner had moved teams. We added monitoring for expiry.", by: "dana")
        XCTAssertEqual(final.survivingModelText, "No data was lost. We added monitoring for expiry.")
        XCTAssertGreaterThan(final.humanShare, 0.3)
        XCTAssertLessThan(final.humanShare, 0.5)
    }

    func testDeletingEverythingGivesEmptyText() {
        let draft = AttributedText.model("Delete me entirely.", generation: gen)
        let final = draft.edited(to: "", by: "p")
        XCTAssertEqual(final.string, "")
        XCTAssertEqual(final.modelShare, 0)
        XCTAssertEqual(final.humanShare, 0)
    }

    func testEditingEmptyDraftIsAllHuman() {
        let final = AttributedText(spans: []).edited(to: "Written by hand.", by: "p")
        XCTAssertEqual(final.humanShare, 1)
    }

    func testQuotedTextCountsForNeitherSide() {
        let text = AttributedText(spans: [
            Span(.model(gen), "You wrote: "),
            Span(.quoted, "it logs me out every morning"),
            Span(.human(author: "p"), ". Fixed in 4.12.1."),
        ])
        XCTAssertEqual(text.quotedCharacterCount, "it logs me out every morning".count)
        XCTAssertEqual(text.modelShare + text.humanShare, 1, accuracy: 1e-9)
        XCTAssertEqual(text.modelCharacterCount, "You wrote: ".count)
    }

    func testShortModelRunFramedByQuotesSurvivesAnUnrelatedEdit() {
        let text = AttributedText(spans: [
            Span(.quoted, "\"Crashes on launch.\""),
            Span(.model(gen), " Got it. "),
            Span(.quoted, "\"Five stars after.\""),
            Span(.model(gen), " We shipped the fix in version 4.12.1 this morning."),
        ])
        let final = text.edited(to: text.string + " Thanks!", by: "p")
        XCTAssertTrue(final.spans.contains(Span(.model(gen), " Got it. ")))
    }

    func testAdjacentSpansWithSameOriginAreMerged() {
        let text = AttributedText(spans: [Span(.model(gen), "a"), Span(.model(gen), "b"), Span(.quoted, "")])
        XCTAssertEqual(text.spans, [Span(.model(gen), "ab")])
    }

    func testOversizedMiddleFallsBackToEditorWithoutCrashing() {
        let big = String(repeating: "alpha beta gamma. ", count: 1200)
        let draft = AttributedText.model("Start. " + big + "End.", generation: gen)
        let replaced = String(repeating: "delta epsilon zeta. ", count: 1200)
        let final = draft.edited(to: "Start. " + replaced + "End.", by: "p")
        XCTAssertEqual(final.string, "Start. " + replaced + "End.")
        // 8,400 × 8,400 tokens is over the cell limit, so the changed middle goes to
        // the editor wholesale (under-counting the model, never over-counting it).
        XCTAssertGreaterThan(final.humanShare, 0.99)
    }
}
