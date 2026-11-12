import XCTest
@testable import ProvenanceLedger

/// Prints the sample-week table the README and article quote, and pins its totals.
final class SampleWeekReportTests: XCTestCase {
    func testPrintReport() {
        let ledger = SampleWeek.ledger()
        for (record, item) in zip(ledger.records, SampleWeek.items) {
            let line = [
                String(record.id + 1),
                item.title,
                record.stamp.model,
                record.stamp.platform.rawValue,
                record.surface.rawValue,
                "model \(Int((record.final.modelShare * 100).rounded()))%",
                "human \(Int((record.final.humanShare * 100).rounded()))%",
                "quoted \(record.final.quotedCharacterCount)",
                "sentences \(record.final.modelSentenceCount)",
                String(describing: record.expectation),
                record.disclosure.label.rawValue,
                record.disclosure.reason,
            ].joined(separator: " | ")
            print("REPORT " + line)
        }
    }

    /// The totals the article quotes. If a rule changes, this fails before the prose lies.
    func testSampleWeekTotals() {
        let records = SampleWeek.ledger().records
        XCTAssertEqual(records.count, 12)

        let withModelText = records.filter { $0.final.modelCharacterCount > 0 }
        XCTAssertEqual(withModelText.count, 11)

        var expected = 0, weak = 0, notExpected = 0
        for record in withModelText {
            switch record.expectation {
            case .expected: expected += 1
            case .weak: weak += 1
            case .notExpected: notExpected += 1
            }
        }
        XCTAssertEqual([expected, weak, notExpected], [4, 5, 2])

        let labels = records.map(\.disclosure.label)
        XCTAssertEqual(labels.filter { $0 == .aiGenerated }.count, 9)
        XCTAssertEqual(labels.filter { $0 == .aiAssisted }.count, 2)
        XCTAssertEqual(labels.filter { $0 == .none }.count, 1)

        // Same model string, same week, three different answers: the model name alone
        // does not tell you whether a third party will find a mark.
        let opus47 = Set(records.filter { $0.stamp.model == "claude-opus-4-7" }.map(\.expectation.shortLabel))
        XCTAssertEqual(opus47, ["Mark expected", "Mark unreliable", "No mark expected"])

        // Per-row values the article and README quote.
        let modelShares = records.map { Int(($0.final.modelShare * 100).rounded()) }
        XCTAssertEqual(modelShares, [99, 60, 99, 100, 100, 100, 100, 100, 45, 97, 0, 100])
        XCTAssertEqual(records[1].expectation, .weak([.shortText(sentences: 4)]))
        XCTAssertEqual(records[1].final.modelSentenceCount, 4)
        XCTAssertEqual(Int((records[1].final.humanShare * 100).rounded()), 40)
        XCTAssertEqual(records[2].stamp.sampling.temperature, 0.2)
        XCTAssertEqual(records[2].expectation, .weak([.samplingOverride]))
        XCTAssertEqual(Int((records[2].final.humanShare * 100).rounded()), 1)
        XCTAssertEqual(Int((records[8].final.humanShare * 100).rounded()), 55)
        XCTAssertEqual(records[11].final.quotedCharacterCount, 50)
    }
}
