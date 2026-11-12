import Foundation

extension WatermarkCoverage {
    /// A snapshot of Anthropic's *documented* text-watermark coverage for the models
    /// in this demo, as reported on 4 November 2026 (release notes, help center and
    /// developer docs, via the sources in the README). Model strings are the ones the
    /// demo sends; replace them with the exact IDs your account uses.
    ///
    /// - Mythos 5, Opus 4.7, Sonnet 4.6: marked from 3 Nov 2026 on the Anthropic API.
    ///   Bedrock rollout for those three completes by 10 Nov 2026.
    /// - Sonnet 4.6: non-default `temperature`, `top_p` or `top_k` may leave the mark out.
    /// - Opus 4.6, Haiku 4.5 and older: no documented start date, so not in the table.
    ///   An unlisted model is reported as "coverage not documented", never as "unmarked".
    public static let documentedNov2026: WatermarkCoverage = {
        let nov3 = Calendar.utcDate(2026, 11, 3)
        let nov10 = Calendar.utcDate(2026, 11, 10)
        return WatermarkCoverage(
            entries: [
                "claude-mythos-5": CoverageEntry(markedFrom: [.anthropicAPI: nov3, .bedrock: nov3]),
                "claude-opus-4-7": CoverageEntry(markedFrom: [.anthropicAPI: nov3, .bedrock: nov3]),
                "claude-sonnet-4-6": CoverageEntry(markedFrom: [.anthropicAPI: nov3, .bedrock: nov3],
                                                   samplingSensitive: true),
            ],
            rolloutWindows: [.bedrock: (start: nov3, end: nov10)]
        )
    }()
}

extension Calendar {
    /// Midnight UTC on the given day. Falls back to the reference date only if the
    /// components are invalid, which the hard-coded call sites never are.
    static func utcDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = DateComponents(year: year, month: month, day: day, hour: hour)
        return calendar.date(from: components) ?? Date(timeIntervalSinceReferenceDate: 0)
    }
}
