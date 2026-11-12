import Foundation

/// A constructed week (3–10 Nov 2026) of model-assisted text from a fictional iOS
/// app's support and comms team. Every number in the README and the article comes
/// from running this through the real ledger, rules and policy.
public enum SampleWeek {
    public struct Item: Sendable {
        public let title: String
        public let stamp: GenerationStamp
        public let surface: Surface
        public let draft: AttributedText
        public let final: AttributedText
        public let signoff: EditorialSignoff?
    }

    public static func ledger() -> ProvenanceLedger {
        var ledger = ProvenanceLedger(rules: MarkExpectationRules(coverage: .documentedNov2026))
        for item in items {
            ledger.record(stamp: item.stamp, surface: item.surface, draft: item.draft,
                          final: item.final, signoff: item.signoff)
        }
        return ledger
    }

    public static let items: [Item] = [
        make("Sync bug reply, name fixed", model: "claude-opus-4-7", day: 4, surface: .reviewReply,
             draft: """
             Thanks for taking the time to write this up, Sam. You're right that sync stopped working after the 4.12 update. \
             We traced it to a change in how we refresh tokens in the background. A fix is in review now and should ship this week. \
             In the meantime, signing out and back in will restore sync. We're sorry for the hassle and appreciate your patience.
             """,
             final: """
             Thanks for taking the time to write this up, Sasha. You're right that sync stopped working after the 4.12 update. \
             We traced it to a change in how we refresh tokens in the background. A fix is in review now and should ship this week. \
             In the meantime, signing out and back in will restore sync. We're sorry for the hassle and appreciate your patience.
             """,
             editor: "Priya"),

        make("Pricing reply, rewritten by support lead", model: "claude-opus-4-7", day: 4, surface: .reviewReply,
             draft: """
             We hear you on the price change, and we understand why it stings. The new tier pays for the offline maps you asked for last year. \
             Everyone who subscribed before October keeps their old price for twelve months. \
             If that doesn't apply to you, our support team can look at your account. \
             We read every review, and this feedback is going straight to the product team. Thank you for sticking with us.
             """,
             final: """
             Fair criticism, and I'd rather be straight with you than spin it. The new tier pays for the offline maps you asked for last year. \
             Everyone who subscribed before October keeps their old price for twelve months. \
             You signed up in August, so you qualify: reply to the email we sent on the 2nd and we'll switch you back today. \
             We read every review, and this feedback is going straight to the product team. Thank you for sticking with us.
             """,
             editor: "Priya"),

        make("Refund reply, low temperature", model: "claude-sonnet-4-6", day: 5, surface: .supportReply,
             sampling: SamplingOverrides(temperature: 0.2),
             draft: """
             Hi Jordan, thanks for reaching out about the double charge. I can see two payments for the annual plan on 3 November. \
             Apple handles all App Store billing, so we can't issue the refund from our side. \
             You can request it at reportaproblem.apple.com by choosing the duplicate purchase. \
             Most requests are reviewed within 48 hours. If anything gets stuck, reply here and we'll help you follow up.
             """,
             final: """
             Hi Jordan, thanks for reaching out about the double charge. I can see two payments for the annual plan on 3 November. \
             Apple handles all App Store billing, so we can't issue the refund from our side. \
             You can request it at reportaproblem.apple.com by choosing the duplicate purchase. \
             Most requests are reviewed within 48 hours. If anything gets stuck, just reply here and we'll help you follow up.
             """,
             editor: "Priya"),

        make("Streak reminder notification", model: "claude-sonnet-4-6", day: 5, surface: .notification,
             draft: "Your 30-day streak ends at midnight, and one five-minute session keeps it alive.",
             final: "Your 30-day streak ends at midnight, and one five-minute session keeps it alive.",
             editor: "Marco"),

        make("Export bug reply via Bedrock, mid-rollout", model: "claude-mythos-5", day: 6, platform: .bedrock,
             surface: .supportReply,
             draft: """
             Thanks for the detailed report, Ana. The PDF export cutting off the last page is a bug on our side, not anything you did. \
             It happens when a note ends with a table, and we've reproduced it on iOS 27.2. \
             The fix is part of version 4.13, which is with App Review now. \
             Until then, adding an empty line after the table works around it. We'll email you as soon as the update is live.
             """,
             final: """
             Thanks for the detailed report, Ana. The PDF export cutting off the last page is a bug on our side, not anything you did. \
             It happens when a note ends with a table, and we've reproduced it on iOS 27.2. \
             The fix is part of version 4.13, which is with App Review now. \
             Until then, adding an empty line after the table works around it. We'll email you as soon as the update is live.
             """,
             editor: "Priya"),

        make("Widget question via Bedrock, after rollout", model: "claude-mythos-5", day: 10, platform: .bedrock,
             surface: .supportReply,
             draft: """
             Good question, Lee. The large widget only shows three tasks because iOS limits how often widgets refresh. \
             We pick the three that are due soonest. You can pin a project in the widget settings to show that project instead. \
             Long-press the widget, choose Edit Widget, and pick the project. \
             We're exploring an interactive version for iOS 28, and your note is now part of that discussion.
             """,
             final: """
             Good question, Lee. The large widget only shows three tasks because iOS limits how often widgets refresh. \
             We pick the three that are due soonest. You can pin a project in the widget settings to show that project instead. \
             Long-press the widget, choose Edit Widget, and pick the project. \
             We're exploring an interactive version for iOS 28, and your note is now part of that discussion.
             """,
             editor: "Priya"),

        make("Dark mode reply on Opus 4.6", model: "claude-opus-4-6", day: 6, surface: .reviewReply,
             draft: """
             Thanks for the five stars, and for the nudge on dark mode. You're right that the calendar view still flashes white at night. \
             That screen uses an older rendering path that we're replacing. \
             The new version follows your system appearance and lands in the next release. \
             We appreciate you taking the time to tell us what isn't working yet.
             """,
             final: """
             Thanks for the five stars, and for the nudge on dark mode. You're right that the calendar view still flashes white at night. \
             That screen uses an older rendering path that we're replacing. \
             The new version follows your system appearance and lands in the next release. \
             We appreciate you taking the time to tell us what isn't working yet.
             """,
             editor: "Priya"),

        make("Onboarding reply drafted the day before coverage", model: "claude-opus-4-7", day: 2, surface: .reviewReply,
             draft: """
             Sorry the sign-up flow felt long, Chris. You're right that we asked for too much before showing the app. \
             We've cut the onboarding from six screens to two in version 4.12. \
             Calendar access is now optional and only requested when you open the calendar. \
             If you give it another try, we'd love to hear whether it feels better.
             """,
             final: """
             Sorry the sign-up flow felt long, Chris. You're right that we asked for too much before showing the app. \
             We've cut the onboarding from six screens to two in version 4.12. \
             Calendar access is now optional and only requested when you open the calendar. \
             If you give it another try, we'd love to hear whether it feels better.
             """,
             editor: "Priya"),

        make("Outage post, rewritten and signed off", model: "claude-opus-4-7", day: 7, surface: .statusPost,
             draft: """
             On 7 November, some users could not sync between 09:10 and 10:25 UTC. \
             The cause was an expired certificate on one of our sync servers. \
             No data was lost, and changes made offline synced once service returned. \
             We have added monitoring for certificate expiry across all servers. \
             We apologise for the disruption and thank you for your patience.
             """,
             final: """
             On 7 November, some users could not sync between 09:10 and 10:25 UTC. \
             The cause was an expired certificate on one of our sync servers. \
             No data was lost, and changes made offline synced once service returned. \
             Certificate renewal was a manual calendar reminder, and the person who owned it had moved teams. \
             Renewal is now automated, alerts page on-call 30 days out, and we are auditing every other manual reminder this month. \
             We're sorry: this one was avoidable.
             """,
             editor: "Dana", signedOffBy: "Dana"),

        make("Feature post, light copy edit, no sign-off", model: "claude-opus-4-7", day: 8, surface: .statusPost,
             draft: """
             Offline maps are now available to every subscriber. \
             You can download any region up to 2 GB and use it without a connection. \
             Maps update automatically when you're on Wi-Fi. \
             Downloads are stored on your device and never leave it. \
             We built this because it was the most requested feature of the past year.
             """,
             final: """
             Offline maps are now available to every subscriber! \
             You can download any region up to 2 GB and use it without a connection. \
             Maps update automatically whenever you're on Wi-Fi. \
             Downloads are stored on your device and never leave it. \
             We built this because it was the most requested feature of the past year.
             """,
             editor: "Dana"),

        make("Bug reply rewritten from scratch", model: "claude-opus-4-7", day: 9, surface: .supportReply,
             draft: """
             Thank you for reporting the crash when attaching photos. We're sorry for the inconvenience this has caused. \
             Our engineering team is investigating the issue as a priority. \
             We'll update you as soon as we have more information. Thank you for your patience and understanding.
             """,
             final: """
             Found it: photos over 48 megapixels from the iPhone 18 Pro hit a memory limit in our thumbnailer. \
             4.12.1 fixes it and is live now. Update and you're good. If it still crashes, send me the photo and I'll look personally.
             """,
             editor: "Marco"),
    ] + [structuredQuoteItem]

    /// The prompt-contract technique: the customer's own words are quoted verbatim and
    /// recorded as `.quoted`, so they never count as model text or human text.
    public static let structuredReviewInput = "The app keeps logging me out every single morning. Five stars once you fix that."

    static let structuredQuoteItem: Item = {
        let generation = GenerationID("gen-2026-11-09-12")
        let draft = StructuredDraft(segments: [
            .init(kind: .generated, text: "You wrote: \""),
            .init(kind: .quoted, text: "The app keeps logging me out every single morning."),
            .init(kind: .generated, text: """
            " That's on us. Version 4.12 shortened how long a session stays valid, and the overnight refresh fails when Low Power Mode is on. \
            Version 4.12.1 restores the old session length and retries the refresh when the phone wakes. \
            It's live in the App Store now. If you still get logged out after updating, reply here and we'll dig in. \
            Thanks for giving us a clear target for that fifth star.
            """),
        ])
        let attributed = (try? draft.attributed(generation: generation, userInput: structuredReviewInput))
            ?? AttributedText.model(draft.segments.map(\.text).joined(), generation: generation)
        return Item(
            title: "Logout reply with the review quoted",
            stamp: GenerationStamp(id: generation, model: "claude-opus-4-7", platform: .anthropicAPI,
                                   promptVersion: "review-reply@v7", generatedAt: Calendar.utcDate(2026, 11, 9, hour: 15)),
            surface: .reviewReply, draft: attributed, final: attributed, signoff: nil)
    }()

    private static func make(_ title: String, model: String, day: Int, platform: ServingPlatform = .anthropicAPI,
                             surface: Surface, sampling: SamplingOverrides = .none,
                             draft: String, final: String, editor: String, signedOffBy: String? = nil) -> Item {
        let generation = GenerationID("gen-2026-11-\(String(format: "%02d", day))-\(abs(title.hashValueStable) % 1000)")
        let generatedAt = Calendar.utcDate(2026, 11, day, hour: 14)
        let stamp = GenerationStamp(id: generation, model: model, platform: platform,
                                    promptVersion: surface == .statusPost ? "status-post@v3" : "support-reply@v12",
                                    sampling: sampling, generatedAt: generatedAt)
        let draftText = AttributedText.model(draft, generation: generation)
        let signoff = signedOffBy.map { EditorialSignoff(reviewer: $0, at: generatedAt.addingTimeInterval(3600)) }
        return Item(title: title, stamp: stamp, surface: surface, draft: draftText,
                    final: draftText.edited(to: final, by: editor), signoff: signoff)
    }
}

private extension String {
    /// A deterministic hash for readable demo IDs (Swift's `hashValue` is seeded per run).
    var hashValueStable: Int {
        Int(truncatingIfNeeded: ProvenanceLedger.fingerprint(self) & 0x7fff_ffff)
    }
}
