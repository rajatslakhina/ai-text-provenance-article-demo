import SwiftUI
import ProvenanceLedger

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

/// Launch arguments (used by Scripts/simulator-screenshots.sh):
///   -tab week|lookup     which tab opens
///   -item N              open the detail for sample item N (1-based) on the week tab
struct RootView: View {
    @State private var tab: String
    private let ledger = SampleWeek.ledger()
    private let openItem: Int?

    init() {
        let defaults = UserDefaults.standard
        _tab = State(initialValue: defaults.string(forKey: "tab") ?? "week")
        let item = defaults.integer(forKey: "item")
        openItem = item > 0 ? item : nil
    }

    var body: some View {
        TabView(selection: $tab) {
            WeekView(ledger: ledger, openItem: openItem)
                .tabItem { Label("Week", systemImage: "list.bullet.rectangle") }
                .tag("week")
            LookupView(ledger: ledger)
                .tabItem { Label("Lookup", systemImage: "magnifyingglass") }
                .tag("lookup")
        }
    }
}

// MARK: - Week

struct WeekView: View {
    let ledger: ProvenanceLedger
    @State private var path: [Int]

    init(ledger: ProvenanceLedger, openItem: Int?) {
        self.ledger = ledger
        let valid = openItem.flatMap { ledger.records.indices.contains($0 - 1) ? [$0 - 1] : nil } ?? []
        _path = State(initialValue: valid)
    }

    private var summary: (expected: Int, weak: Int, none: Int, withModel: Int) {
        var e = 0, w = 0, n = 0, m = 0
        for record in ledger.records where record.final.modelCharacterCount > 0 {
            m += 1
            switch record.expectation {
            case .expected: e += 1
            case .weak: w += 1
            case .notExpected: n += 1
            }
        }
        return (e, w, n, m)
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(summary.withModel) of \(ledger.records.count) shipped texts contain model-chosen words")
                            .font(.subheadline.weight(.semibold))
                        HStack(spacing: 8) {
                            CountPill(count: summary.expected, label: "mark expected", color: .blue)
                            CountPill(count: summary.weak, label: "unreliable", color: .orange)
                            CountPill(count: summary.none, label: "not expected", color: .gray)
                        }
                        Text("What a third-party detector would probably see. You probably don't have the detector; you do have this ledger.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Section("3–10 Nov 2026 (constructed)") {
                    ForEach(ledger.records) { record in
                        NavigationLink(value: record.id) { RecordRow(record: record, title: title(record)) }
                    }
                }
            }
            .navigationTitle("Provenance Ledger")
            .navigationDestination(for: Int.self) { id in
                if ledger.records.indices.contains(id) {
                    RecordDetail(record: ledger.records[id], title: title(ledger.records[id]))
                }
            }
        }
    }

    private func title(_ record: LedgerRecord) -> String {
        SampleWeek.items.indices.contains(record.id) ? SampleWeek.items[record.id].title : "Record \(record.id + 1)"
    }
}

struct CountPill: View {
    let count: Int, label: String, color: Color
    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)").font(.headline.monospacedDigit())
            Text(label).font(.caption)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundStyle(color)
    }
}

struct RecordRow: View {
    let record: LedgerRecord
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(record.id + 1). \(title)").font(.subheadline.weight(.medium))
            Text("\(record.stamp.model) · \(record.stamp.platform.rawValue) · \(record.surface.displayName)")
                .font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Badge(text: record.expectation.shortLabel, color: record.expectation.color)
                Badge(text: record.disclosure.label.badgeText, color: .purple)
                Spacer()
                Text("model \(percent(record.final.modelShare))").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct Badge: View {
    let text: String, color: Color
    var body: some View {
        Text(text).font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(color)
    }
}

// MARK: - Detail

struct RecordDetail: View {
    let record: LedgerRecord
    let title: String
    var body: some View {
        List {
            Section("Final text, by who chose the words") {
                Text(highlighted(record.final)).font(.callout)
                HStack(spacing: 12) {
                    Legend(color: .blue, label: "model")
                    Legend(color: .green, label: "person")
                    Legend(color: .gray, label: "quoted user text")
                }.font(.caption2)
            }
            Section("Recorded at generation time") {
                Fact("Model", record.stamp.model)
                Fact("Platform", record.stamp.platform.rawValue)
                Fact("Prompt", record.stamp.promptVersion)
                Fact("Sampling", samplingText(record.stamp.sampling))
                Fact("Generated", record.stamp.generatedAt.formatted(date: .abbreviated, time: .shortened))
                Fact("Signed off", record.signoff?.reviewer ?? "—")
            }
            Section("Measured") {
                Fact("Model share", percent(record.final.modelShare))
                Fact("Typed by a person", percent(record.final.humanShare))
                Fact("Model-majority sentences", "\(record.final.modelSentenceCount)")
            }
            Section("Watermark expectation") {
                Badge(text: record.expectation.shortLabel, color: record.expectation.color)
                ForEach(record.expectation.explanations, id: \.self) { Text($0).font(.footnote) }
            }
            Section("Disclosure shown to the user") {
                Text(record.disclosure.label.userFacingText ?? "No label").font(.body.weight(.semibold))
                Text(record.disclosure.reason).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func highlighted(_ text: AttributedText) -> AttributedString {
        var out = AttributedString()
        for span in text.spans {
            var piece = AttributedString(span.text)
            switch span.origin {
            case .model: piece.backgroundColor = .blue.opacity(0.18)
            case .human: piece.backgroundColor = .green.opacity(0.28)
            case .quoted: piece.foregroundColor = .secondary; piece.font = .callout.italic()
            }
            out += piece
        }
        return out
    }

}

struct Legend: View {
    let color: Color, label: String
    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.35)).frame(width: 12, height: 10)
            Text(label)
        }
    }
}

struct Fact: View {
    let key: String, value: String
    init(_ key: String, _ value: String) { self.key = key; self.value = value }
    var body: some View {
        HStack { Text(key).foregroundStyle(.secondary); Spacer(); Text(value).multilineTextAlignment(.trailing) }
            .font(.footnote)
    }
}

// MARK: - Lookup

struct LookupView: View {
    let ledger: ProvenanceLedger
    @State private var query: String
    @State private var answer: LedgerAnswer?

    init(ledger: ProvenanceLedger) {
        self.ledger = ledger
        _query = State(initialValue: LookupView.journalistQuote(ledger))
        _answer = State(initialValue: ledger.answer(for: LookupView.journalistQuote(ledger)))
    }

    /// A reporter pastes back reply 3, reflowed and upper-cased by their CMS.
    static func journalistQuote(_ ledger: ProvenanceLedger) -> String {
        guard ledger.records.indices.contains(2) else { return "" }
        return ledger.records[2].final.string.uppercased().replacingOccurrences(of: ". ", with: ".\n")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("A reporter says their detector flagged this support reply as Claude-written. What do you know about it?")
                        .font(.footnote)
                    TextEditor(text: $query).font(.caption.monospaced()).frame(minHeight: 150)
                    HStack {
                        Button("Check ledger") { answer = ledger.answer(for: query) }
                            .buttonStyle(.borderedProminent)
                        Spacer()
                        Button("Try a reworded quote") {
                            query = "Thanks for writing this up, Sam, sync is fixed."
                            answer = ledger.answer(for: query)
                        }.font(.caption)
                    }
                }
                if let answer {
                    switch answer {
                    case .notFound:
                        Section("Answer") {
                            Text("Not in the ledger.").font(.headline)
                            Text("Matching ignores case, whitespace and invisible characters, but not rewording. Say so; don't guess.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    case .found(let records):
                        ForEach(records) { record in
                            Section("Answer: record \(record.id + 1)") {
                                Fact("Model", record.stamp.model)
                                Fact("Prompt", record.stamp.promptVersion)
                                Fact("Sampling", samplingText(record.stamp.sampling))
                                Fact("Typed by a person", percent(record.final.humanShare))
                                Fact("Label user saw", record.disclosure.label.userFacingText ?? "No label")
                                Badge(text: record.expectation.shortLabel, color: record.expectation.color)
                                ForEach(record.expectation.explanations, id: \.self) { Text($0).font(.footnote) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Who wrote this?")
        }
    }
}

// MARK: - Helpers

func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }

func samplingText(_ s: SamplingOverrides) -> String {
    guard s.sentAny else { return "defaults (none sent)" }
    var parts: [String] = []
    if let t = s.temperature { parts.append("temperature \(t)") }
    if let p = s.topP { parts.append("top_p \(p)") }
    if let k = s.topK { parts.append("top_k \(k)") }
    return parts.joined(separator: ", ")
}

extension MarkExpectation {
    var color: Color {
        switch self {
        case .expected: return .blue
        case .weak: return .orange
        case .notExpected: return .gray
        }
    }

    var explanations: [String] {
        switch self {
        case .expected:
            return ["Covered model, long enough, lightly edited, and no documented caveat applies: a detector would probably find it."]
        case .weak(let reasons):
            return reasons.map { reason in
                switch reason {
                case .samplingOverride: return "Sonnet 4.6 with a non-default sampling value: Anthropic says the mark may be missing."
                case .shortText(let n): return "Only \(n) model-majority sentence(s): too short for a reliable mark."
                case .heavyHumanEdit(let share): return "\(percent(share)) typed by a person: rewriting thins the mark."
                case .platformRollout: return "Served on Bedrock during the 3–10 Nov rollout: may be unmarked."
                }
            }
        case .notExpected(let reason):
            switch reason {
            case .noModelText: return ["No model-chosen words survived the edit."]
            case .coverageNotDocumented: return ["No documented watermark start date for this model. Not 'unmarked': unknown."]
            case .generatedBeforeCoverage: return ["Generated before coverage started for this model."]
            }
        }
    }
}

extension DisclosureLabel {
    var badgeText: String {
        switch self {
        case .none: return "No label"
        case .aiAssisted: return "AI-assisted"
        case .aiGenerated: return "AI-generated"
        }
    }
}
