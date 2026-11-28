/// The 40-column layout (kickoff §7). Every line the game prints fits in
/// `width` columns, including the `] ` prompt.
package enum Columns {
    package static let width = 40
    package static let prompt = "] "
    package static var textWidth: Int { width - prompt.count }

    /// Word-wraps `text` to `width`, breaking a word only when it is longer
    /// than a whole line.
    package static func wrap(_ text: String, width: Int = textWidth, indent: String = "") -> [String] {
        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ", omittingEmptySubsequences: false).map(String.init) {
            var piece = word
            while piece.count > width - indent.count {
                if !current.isEmpty {
                    lines.append(current)
                    current = ""
                }
                let room = width - indent.count
                lines.append(indent + piece.prefix(room))
                piece = String(piece.dropFirst(room))
            }
            let candidate = current.isEmpty ? (lines.isEmpty ? piece : indent + piece) : current + " " + piece
            if candidate.count > width {
                lines.append(current)
                current = indent + piece
            } else {
                current = candidate
            }
        }
        if !current.isEmpty || lines.isEmpty {
            lines.append(current)
        }
        return lines
    }

    /// `left` and `right` on one line, `right` flush to the edge.
    package static func spread(_ left: String, _ right: String, width: Int = textWidth) -> String {
        let gap = width - left.count - right.count
        return gap >= 1 ? left + String(repeating: " ", count: gap) + right : left + " " + right
    }

    /// A bar of `#` and `.`, `cells` wide, filled in proportion.
    package static func bar(_ value: Int, of maximum: Int, cells: Int) -> String {
        guard maximum > 0, cells > 0 else { return "" }
        let clamped = min(max(value, 0), maximum)
        var filled = clamped * cells / maximum
        if clamped > 0 && filled == 0 { filled = 1 }
        return "[" + String(repeating: "#", count: filled) + String(repeating: ".", count: cells - filled) + "]"
    }
}
