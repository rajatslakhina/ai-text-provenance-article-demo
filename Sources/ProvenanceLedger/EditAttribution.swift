import Foundation

extension AttributedText {
    /// The largest middle section (old × new tokens) the exact diff will handle.
    /// Above this, the changed middle is attributed wholesale to the editor, which can
    /// only *under*-count surviving model text, never over-count it.
    public static let exactDiffCellLimit = 4_000_000

    /// Applies a human edit and returns text whose words keep their original origin
    /// if they survived, and are attributed to `author` if they were typed.
    ///
    /// The diff runs on tokens (words, and each space or punctuation mark on its own)
    /// with a longest-common-subsequence match after trimming the shared prefix and
    /// suffix. A changed word is attributed to the editor as a whole word.
    ///
    /// Surviving model runs of fewer than `minimumSurvivingWords` words are handed to
    /// the editor. A rewrite that happens to reuse "the" and "you" has not kept the
    /// model's words, and a watermark lives in runs of the model's choices, not in
    /// isolated common words.
    public func edited(
        to newText: String, by author: String, minimumSurvivingWords: Int = 3
    ) -> AttributedText {
        let editor = SpanOrigin.human(author: author)
        let old = Token.tokenize(spans.flatMap { span in span.text.map { ($0, span.origin) } })
        let new = Token.tokenize(newText.map { ($0, editor) })

        var prefix = 0
        while prefix < old.count, prefix < new.count, old[prefix].text == new[prefix].text {
            prefix += 1
        }
        var suffix = 0
        while suffix < old.count - prefix, suffix < new.count - prefix,
              old[old.count - 1 - suffix].text == new[new.count - 1 - suffix].text {
            suffix += 1
        }

        var result: [Token] = Array(old[0..<prefix])
        result.append(contentsOf: Token.attributeMiddle(
            old: Array(old[prefix..<(old.count - suffix)]),
            new: Array(new[prefix..<(new.count - suffix)])))
        result.append(contentsOf: old[(old.count - suffix)..<old.count])

        Token.demoteShortModelRuns(&result, to: editor, minimumWords: minimumSurvivingWords)

        let built = result.flatMap { token in
            zip(token.text, token.origins).map { Span($1, String($0)) }
        }
        return AttributedText(spans: built)
    }
}

/// A word, or a single non-word character, carrying the origin of each character.
struct Token {
    let text: String
    var origins: [SpanOrigin]
    let isWord: Bool

    var isAllModel: Bool { origins.allSatisfy(\.isModel) }

    static func isWordCharacter(_ c: Character) -> Bool {
        c.isLetter || c.isNumber || c == "'" || c == "\u{2019}"
    }

    static func tokenize(_ characters: [(Character, SpanOrigin)]) -> [Token] {
        var tokens: [Token] = []
        var word = "", wordOrigins: [SpanOrigin] = []
        func flush() {
            if !word.isEmpty { tokens.append(Token(text: word, origins: wordOrigins, isWord: true)) }
            word = ""; wordOrigins = []
        }
        for (character, origin) in characters {
            if isWordCharacter(character) {
                word.append(character); wordOrigins.append(origin)
            } else {
                flush()
                tokens.append(Token(text: String(character), origins: [origin], isWord: false))
            }
        }
        flush()
        return tokens
    }

    /// LCS over token text. Matched new tokens keep the old token's origins;
    /// unmatched new tokens keep the editor origin they were tokenized with.
    static func attributeMiddle(old: [Token], new: [Token]) -> [Token] {
        let n = old.count, m = new.count
        guard m > 0 else { return [] }
        guard n > 0, n * m <= AttributedText.exactDiffCellLimit else { return new }
        let width = m + 1
        var lcs = [Int32](repeating: 0, count: (n + 1) * width)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                lcs[i * width + j] = old[i].text == new[j].text
                    ? lcs[(i + 1) * width + j + 1] + 1
                    : max(lcs[(i + 1) * width + j], lcs[i * width + j + 1])
            }
        }
        var result: [Token] = []
        result.reserveCapacity(m)
        var i = 0, j = 0
        while j < m {
            if i < n, old[i].text == new[j].text {
                result.append(old[i]); i += 1; j += 1
            } else if i < n, lcs[(i + 1) * width + j] >= lcs[i * width + j + 1] {
                i += 1 // deleted token
            } else {
                result.append(new[j]); j += 1 // typed token
            }
        }
        return result
    }

    /// Finds maximal runs of all-model tokens and hands any run with fewer than
    /// `minimumWords` words to the editor.
    static func demoteShortModelRuns(_ tokens: inout [Token], to editor: SpanOrigin, minimumWords: Int) {
        var start = 0
        while start < tokens.count {
            guard tokens[start].isAllModel else { start += 1; continue }
            var end = start, words = 0
            while end < tokens.count, tokens[end].isAllModel {
                if tokens[end].isWord { words += 1 }
                end += 1
            }
            // Only a run that touches typed text is a candidate coincidence. A short
            // model run framed by quoted text or the ends of an untouched draft is not.
            let touchesEdit = (start > 0 && tokens[start - 1].origins.contains(editor))
                || (end < tokens.count && tokens[end].origins.contains(editor))
            if words < minimumWords, touchesEdit {
                for k in start..<end {
                    tokens[k].origins = Array(repeating: editor, count: tokens[k].origins.count)
                }
            }
            start = end
        }
    }
}
