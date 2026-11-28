import CarrierCore
import SwiftGodot

/// Card or keyword text with its keywords in bold. Hovering a keyword shows
/// what it means (a BBCode `hint`).
enum RuleText {
    static func make(
        _ text: String, content: CrackContent, size: Int32 = 13, color: Color = Phosphor.green
    )
        -> RichTextLabel
    {
        let label = RichTextLabel()
        label.bbcodeEnabled = true
        label.fitContent = true
        label.scrollActive = false
        label.autowrapMode = .wordSmart
        label.selectionEnabled = false
        // PASS: the label shows the hint on hover, and a click still reaches
        // the card button behind it.
        label.mouseFilter = .pass
        label.addThemeFontSizeOverride(name: "normal_font_size", fontSize: size)
        label.addThemeFontSizeOverride(name: "bold_font_size", fontSize: size)
        label.addThemeColorOverride(name: "default_color", color: color)
        label.text = bbcode(text, content: content)
        return label
    }

    /// `text` as BBCode: each keyword bold and bright, with its meaning as a
    /// hover hint.
    static func bbcode(_ text: String, content: CrackContent) -> String {
        content.spans(text).map { span in
            switch span {
            case .plain(let plain):
                return escape(plain)
            case .keyword(let word, let shown):
                // Quoted: an explanation may hold an apostrophe or a bracket.
                let meaning = content.keyword(word).map { "\(word): \($0.text)" } ?? word
                let hint = escape(meaning).split(separator: "\"", omittingEmptySubsequences: false).joined(
                    separator: "'")
                let color = Phosphor.bright.toHtml(withAlpha: false)
                return "[b][color=#\(color)][hint=\"\(hint)\"]\(escape(shown))[/hint][/color][/b]"
            }
        }.joined()
    }

    /// BBCode treats `[` as a tag; `[lb]` writes one.
    private static func escape(_ text: String) -> String {
        text.split(separator: "[", omittingEmptySubsequences: false).joined(separator: "[lb]")
    }
}
