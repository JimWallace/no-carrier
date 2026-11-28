import CarrierCore
import SwiftGodot

/// The crack's component sheets: `-- --gallery crack-cards` and the rest.
extension Gallery {
    static let crackSheets = ["crack-cards", "crack-slots", "crack-guesses"]

    static func makeCrack(_ name: String, play: CrackPlay) -> Control {
        let content = play.content
        switch name {
        case "crack-cards":
            var items: [(String, Control)] = content.cards.map { card in
                let model = CrackCardView.Model(card: card, cost: play.rules.cost(of: card))
                return (card.id, CrackCardView.make(model, content: content) {})
            }
            if let probe = content.card("probe") {
                let selected = CrackCardView.Model(card: probe, cost: 1, selected: true)
                let broke = CrackCardView.Model(card: probe, cost: 1, refusal: "NO ENERGY")
                items.append(("selected", CrackCardView.make(selected, content: content) {}))
                items.append(("no energy", CrackCardView.make(broke, content: content) {}))
            }
            return sheet("CRACK CARD: EVERY CARD, PICKED, AND TOO DEAR", items)
        case "crack-slots":
            let models: [(String, SlotView.Model)] = [
                ("empty", SlotView.Model(number: 1)),
                ("symbol", SlotView.Model(number: 2, symbol: "K")),
                ("dial", SlotView.Model(number: 3, symbol: "R", isDial: true)),
                ("locked", SlotView.Model(number: 4, symbol: "A", isLocked: true)),
                ("probed", SlotView.Model(number: 5, symbol: "E", known: "X")),
                ("picked", SlotView.Model(number: 6, symbol: "Z", selected: true)),
                ("card picked", SlotView.Model(number: 7, target: true)),
            ]
            return sheet(
                "CRACK SLOT: EVERY STATE", models.map { ($0.0, SlotView.make($0.1, click: {}, turn: { _ in })) })
        case "crack-guesses":
            let code = ["A", "K", "E", "K"]
            let guesses: [[String?]] = [["A", "E", "K", nil], ["K", "K", "E", "A"], ["A", "K", "E", "K"]]
            func list(_ style: CrackFeedbackStyle) -> Control {
                let rows = guesses.map {
                    CrackGuess(
                        symbols: $0, feedback: CrackFeedback.score(guess: $0, code: code, style: style), style: style)
                }
                return GuessList.make(rows, legend: style.legend)
            }
            return sheet(
                "CRACK GUESSES: EACH FEEDBACK STYLE",
                [("counts", list(.counts)), ("hits", list(.hits)), ("slots", list(.slots))])
        default:
            return Phosphor.label(
                "NO GALLERY \(name.uppercased()). TRY: " + crackSheets.joined(separator: ", ").uppercased(),
                color: Phosphor.red)
        }
    }
}
