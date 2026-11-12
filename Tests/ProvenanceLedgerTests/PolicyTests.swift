import XCTest
@testable import ProvenanceLedger

final class PolicyTests: XCTestCase {
    let gen = GenerationID("g")
    let rules = MarkExpectationRules(coverage: .documentedNov2026)
    let sixSentences = "One is here. Two is here. Three is here. Four is here. Five is here. Six is here."

    func stamp(_ model: String, day: Int, platform: ServingPlatform = .anthropicAPI,
               sampling: SamplingOverrides = .none) -> GenerationStamp {
        GenerationStamp(id: gen, model: model, platform: platform, promptVersion: "v1",
                        sampling: sampling, generatedAt: Calendar.utcDate(2026, 11, day, hour: 12))
    }

    // MARK: Sentences

    func testSentenceCounterIgnoresVersionNumbersAndRepeatedTerminators() {
        XCTAssertEqual(SentenceCounter.count("Update to 4.12.1 now. Really?! Yes..."), 3)
        XCTAssertEqual(SentenceCounter.count("No terminator here"), 1)
        XCTAssertEqual(SentenceCounter.count(""), 0)
        XCTAssertEqual(SentenceCounter.count("... !!"), 0)
    }

    // MARK: Mark expectation

    func testLongUneditedOpus47TextExpectsMark() {
        let text = AttributedText.model(sixSentences, generation: gen)
        XCTAssertEqual(rules.expectation(for: stamp("claude-opus-4-7", day: 4), final: text), .expected)
    }

    func testSonnet46WithTemperatureIsWeakButOpus47IsNot() {
        let text = AttributedText.model(sixSentences, generation: gen)
        let low = SamplingOverrides(temperature: 0.2)
        XCTAssertEqual(rules.expectation(for: stamp("claude-sonnet-4-6", day: 4, sampling: low), final: text),
                       .weak([.samplingOverride]))
        XCTAssertEqual(rules.expectation(for: stamp("claude-opus-4-7", day: 4, sampling: low), final: text), .expected)
    }

    func testTopKAloneCountsAsAnOverride() {
        XCTAssertTrue(SamplingOverrides(topK: 40).sentAny)
        XCTAssertFalse(SamplingOverrides.none.sentAny)
    }

    func testBedrockRolloutWindowIsWeakAndEndIsExclusive() {
        let text = AttributedText.model(sixSentences, generation: gen)
        XCTAssertEqual(rules.expectation(for: stamp("claude-mythos-5", day: 9, platform: .bedrock), final: text),
                       .weak([.platformRollout]))
        XCTAssertEqual(rules.expectation(for: stamp("claude-mythos-5", day: 10, platform: .bedrock), final: text),
                       .expected)
    }

    func testUnlistedModelIsNotDocumentedRatherThanUnmarked() {
        let text = AttributedText.model(sixSentences, generation: gen)
        XCTAssertEqual(rules.expectation(for: stamp("claude-opus-4-6", day: 4), final: text),
                       .notExpected(.coverageNotDocumented))
    }

    func testGeneratedBeforeCoverageStart() {
        let text = AttributedText.model(sixSentences, generation: gen)
        XCTAssertEqual(rules.expectation(for: stamp("claude-opus-4-7", day: 2), final: text),
                       .notExpected(.generatedBeforeCoverage))
    }

    func testShortTextAndHeavyEditAreBothReported() {
        let draft = AttributedText.model("We are looking into the crash right now.", generation: gen)
        let final = draft.edited(to: "We are looking into the crash right now. I reproduced it on an iPhone 18 Pro with a huge photo library.", by: "m")
        guard case .weak(let reasons) = rules.expectation(for: stamp("claude-opus-4-7", day: 4), final: final) else {
            return XCTFail("expected weak")
        }
        XCTAssertTrue(reasons.contains(.shortText(sentences: 1)))
        XCTAssertTrue(reasons.contains { if case .heavyHumanEdit = $0 { return true } else { return false } })
    }

    func testNoModelTextExpectsNoMark() {
        let text = AttributedText.human("Typed by a person.", author: "p")
        XCTAssertEqual(rules.expectation(for: stamp("claude-opus-4-7", day: 4), final: text),
                       .notExpected(.noModelText))
    }

    // MARK: Disclosure

    let policy = DisclosurePolicy()

    func testTypoFixIsAFormalCheckNotAnEdit() {
        let draft = AttributedText.model(sixSentences, generation: gen)
        let final = draft.edited(to: sixSentences.replacingOccurrences(of: "Six", with: "Sixx"), by: "p")
        XCTAssertEqual(policy.decide(final, surface: .supportReply, signoff: nil).label, .aiGenerated)
    }

    func testSubstantiveEditIsAssisted() {
        let text = AttributedText(spans: [Span(.model(gen), String(repeating: "m", count: 70)),
                                          Span(.human(author: "p"), String(repeating: "h", count: 30))])
        XCTAssertEqual(policy.decide(text, surface: .reviewReply, signoff: nil).label, .aiAssisted)
    }

    func testPublicPostNeedsNamedSignoffToBeAssisted() {
        let text = AttributedText(spans: [Span(.model(gen), String(repeating: "m", count: 60)),
                                          Span(.human(author: "d"), String(repeating: "h", count: 40))])
        let signoff = EditorialSignoff(reviewer: "Dana", at: .distantPast)
        XCTAssertEqual(policy.decide(text, surface: .statusPost, signoff: nil).label, .aiGenerated)
        XCTAssertEqual(policy.decide(text, surface: .statusPost, signoff: signoff).label, .aiAssisted)
    }

    func testSignoffDoesNotLaunderAFormalCheckOnAPublicPost() {
        let text = AttributedText(spans: [Span(.model(gen), String(repeating: "m", count: 95)),
                                          Span(.human(author: "d"), String(repeating: "h", count: 5))])
        let signoff = EditorialSignoff(reviewer: "Dana", at: .distantPast)
        XCTAssertEqual(policy.decide(text, surface: .statusPost, signoff: signoff).label, .aiGenerated)
    }

    func testIncidentalModelTextNeedsNoLabel() {
        let text = AttributedText(spans: [Span(.model(gen), String(repeating: "m", count: 5)),
                                          Span(.human(author: "p"), String(repeating: "h", count: 95))])
        XCTAssertEqual(policy.decide(text, surface: .reviewReply, signoff: nil).label, .none)
    }

    func testThresholdBoundariesAreInclusive() {
        let atFloor = AttributedText(spans: [Span(.model(gen), String(repeating: "m", count: 80)),
                                             Span(.human(author: "p"), String(repeating: "h", count: 20))])
        XCTAssertEqual(policy.decide(atFloor, surface: .reviewReply, signoff: nil).label, .aiAssisted)
        let incidentalEdge = AttributedText(spans: [Span(.model(gen), String(repeating: "m", count: 10)),
                                                    Span(.human(author: "p"), String(repeating: "h", count: 90))])
        XCTAssertEqual(policy.decide(incidentalEdge, surface: .reviewReply, signoff: nil).label, .aiAssisted)
    }
}
