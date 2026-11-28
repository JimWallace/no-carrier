package import CarrierCore

/// How the terminal shows a card: one hand line in 40 columns, the full
/// rules for `INFO` and the side panel, and the keyword key. All of it comes
/// from `CardDefinition.abilities`, so the words match what the card does.
package enum CardText {
    /// Room for a hand line: `1 BRUTE.EXE      1 ATK 6`.
    static let nameWidth = 14

    /// One hand line, in `width` columns. A card that cannot run now says
    /// why first (`NO CYC: ATK 13`).
    package static func handLine(
        number: Int, card: CardDefinition, refusal: RejectReason?, width: Int = Columns.textWidth
    ) -> String {
        let label = number == 9 ? "0" : "\(number + 1)"
        let lead = "\(label) \(pad(card.name, nameWidth)) \(card.cost.label) "
        let what = refusal.map { "\(short($0)): \(card.headline)" } ?? card.headline
        return clip(lead + what, width)
    }

    /// Why a card cannot run, in a few letters.
    package static func short(_ reason: RejectReason) -> String {
        switch reason {
        case .notEnoughCycles: "NO CYC"
        case .notEnoughRAM: "NO RAM"
        case .wrongLayer(_, let layer): "\(layer.label) ONLY"
        case .unplayable: "DEAD"
        case .fightOver: "OVER"
        case .noSuchCard, .unknownCard: "?"
        }
    }

    /// The full rules of one card, wrapped to `width`: what `INFO` prints and
    /// the side panel shows.
    package static func details(
        _ card: CardDefinition, numbers: [Int], revealedWeak: [ExploitTag]?, revealedResist: [ExploitTag]?,
        width: Int = Columns.textWidth
    ) -> [String] {
        let labels = numbers.map { $0 == 9 ? "0" : "\($0 + 1)" }
        var title = labels.isEmpty ? "" : labels.joined(separator: ",") + " "
        title += "\(card.name)  COST \(card.cost.label)  \(card.type.label)"
        var lines = Columns.wrap(title, width: width)
        for ability in card.abilities {
            lines += Columns.wrap("- " + ability.long, width: width, indent: "  ")
        }
        if !card.tags.isEmpty {
            let tags = card.tags.map { tag in
                if revealedWeak?.contains(tag) == true { return "\(tag.label) (WEAK HERE: X1.5)" }
                if revealedResist?.contains(tag) == true { return "\(tag.label) (RESISTED: X0.5)" }
                return tag.label
            }
            lines += Columns.wrap("- TAG: " + tags.joined(separator: ", "), width: width, indent: "  ")
        }
        return lines
    }

    /// The keyword key, two to a line where they fit.
    package static func glossary(width: Int = Columns.textWidth) -> [String] {
        AbilityGlossary.entries.flatMap { entry in
            Columns.wrap("\(entry.keyword): \(entry.meaning)", width: width, indent: "  ")
        }
    }

    /// The deck, grouped by card in deck order: `4x BRUTE.EXE ATK 6`.
    package static func deck(_ ids: [String], content: ContentPack, width: Int = Columns.textWidth) -> [String] {
        var counts: [(id: String, count: Int)] = []
        for id in ids {
            if let index = counts.firstIndex(where: { $0.id == id }) {
                counts[index].count += 1
            } else {
                counts.append((id, 1))
            }
        }
        return counts.map { entry in
            guard let card = content.card(entry.id) else { return entry.id }
            return clip("\(entry.count)x \(pad(card.name, nameWidth)) \(card.cost.label) \(card.headline)", width)
        }
    }

    static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
    }

    /// Cuts a line to `width`, ending in `+` when something was cut.
    static func clip(_ text: String, _ width: Int) -> String {
        text.count <= width ? text : String(text.prefix(width - 1)) + "+"
    }
}
