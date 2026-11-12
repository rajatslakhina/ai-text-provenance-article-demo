import Foundation

/// Where the text ends up. Only `statusPost` informs the public on a matter of
/// public interest, which is the case EU AI Act Article 50(4) puts disclosure on.
public enum Surface: String, Codable, Sendable, CaseIterable {
    case reviewReply
    case supportReply
    case notification
    case statusPost

    public var informsThePublic: Bool { self == .statusPost }

    public var displayName: String {
        switch self {
        case .reviewReply: return "App Store review reply"
        case .supportReply: return "Support reply"
        case .notification: return "Push notification"
        case .statusPost: return "Public status post"
        }
    }
}

/// A named person who took editorial responsibility for the text.
public struct EditorialSignoff: Hashable, Codable, Sendable {
    public let reviewer: String
    public let at: Date
    public init(reviewer: String, at: Date) {
        self.reviewer = reviewer
        self.at = at
    }
}

public enum DisclosureLabel: String, Codable, Sendable, CaseIterable {
    case none
    case aiAssisted
    case aiGenerated

    public var userFacingText: String? {
        switch self {
        case .none: return nil
        case .aiAssisted: return "Drafted with AI, edited by our team"
        case .aiGenerated: return "Written with AI"
        }
    }
}

public struct DisclosureDecision: Hashable, Sendable {
    public let label: DisclosureLabel
    public let reason: String
}

/// The team's disclosure policy, written down as code so it is reviewable.
///
/// The stance: if model-chosen words survive, say so. A text watermark means a third
/// party may later be able to show that Claude was involved, so "we never said" stops
/// being a neutral position. What the label can honestly claim depends on how much a
/// person actually changed, which `AttributedText` measures instead of assuming.
public struct DisclosurePolicy: Sendable {
    /// Below this model share, surviving model text is treated as incidental.
    public var incidentalModelShare: Double
    /// A person must have typed at least this share for an edit to count as more than
    /// a formal check (spelling, grammar), which the Commission's FAQ says does not
    /// count as human review.
    public var substantiveEditShare: Double

    public init(incidentalModelShare: Double = 0.10, substantiveEditShare: Double = 0.20) {
        self.incidentalModelShare = incidentalModelShare
        self.substantiveEditShare = substantiveEditShare
    }

    public func decide(_ text: AttributedText, surface: Surface, signoff: EditorialSignoff?) -> DisclosureDecision {
        let model = text.modelShare
        let human = text.humanShare
        if text.modelCharacterCount == 0 {
            return DisclosureDecision(label: .none, reason: "No model-chosen words in the final text.")
        }
        if model < incidentalModelShare {
            return DisclosureDecision(label: .none, reason: "Surviving model text is \(percent(model)), below the \(percent(incidentalModelShare)) floor.")
        }
        let substantive = human >= substantiveEditShare
        if surface.informsThePublic {
            if substantive, let signoff {
                return DisclosureDecision(label: .aiAssisted, reason: "Public post: \(percent(human)) rewritten and signed off by \(signoff.reviewer).")
            }
            let why = signoff == nil ? "no named editor signed off" : "only \(percent(human)) was rewritten"
            return DisclosureDecision(label: .aiGenerated, reason: "Public post: \(why).")
        }
        if substantive {
            return DisclosureDecision(label: .aiAssisted, reason: "\(percent(human)) of the text was typed by a person.")
        }
        return DisclosureDecision(label: .aiGenerated, reason: "Only \(percent(human)) was changed by a person; that is a formal check, not an edit.")
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
