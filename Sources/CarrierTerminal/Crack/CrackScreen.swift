import CarrierCore

/// One frame of the crack prototype in 40 columns: the alarm, the guesses
/// so far with their feedback, the log, the board and the hand.
package struct CrackScreen {
    package let session: CrackSession
    package let style: Phosphor
    package let screenRows: Int
    package static let minimumLogRows = 3

    private var state: CrackState { session.state }
    private var content: CrackContent { session.engine.content }
    private let rule = String(repeating: "-", count: Columns.textWidth)

    package init(session: CrackSession, style: Phosphor, screenRows: Int = 24) {
        self.session = session
        self.style = style
        self.screenRows = screenRows
    }

    package func lines(prompt: String?, hint: String) -> [String] {
        let top = header() + [rule] + guesses() + [rule]
        var bottom = [rule] + board()
        if let prompt {
            bottom.append(">" + prompt + style.blink("_"))
            bottom.append(hint)
        }
        let logRows = max(Self.minimumLogRows, screenRows - top.count - bottom.count)
        let shown = session.log.suffix(logRows)
        return top + shown + Array(repeating: "", count: max(0, logRows - shown.count)) + bottom
    }

    private func header() -> [String] {
        let title = Columns.spread("CRACK \(Seed.display(state.seed))", "TURN \(state.turn)")
        let alarm = "ALARM " + Columns.bar(state.alarm, of: content.alarm.max, cells: 20) + " \(state.alarm)"
        let loud = state.alarm * 4 >= content.alarm.max * 3
        return [
            style.inverse(title),
            loud ? style.blink(alarm) : alarm,
            "SYMBOLS " + content.symbols.joined(separator: " "),
        ]
    }

    /// Every guess so far, numbered, with its hits and nears.
    private func guesses() -> [String] {
        if state.guesses.isEmpty { return ["NO GUESSES YET"] }
        return state.guesses.enumerated().map { index, guess in
            let number = index + 1 < 10 ? " \(index + 1)" : "\(index + 1)"
            let symbols = guess.symbols.map { $0 ?? "." }.joined(separator: " ")
            return "\(number)  \(symbols)   \(guess.feedback.hits) HIT \(guess.feedback.near) NEAR"
        }
    }

    private func board() -> [String] {
        let slots = state.board.enumerated().map { index, card in
            "\(index + 1):" + (card.map(session.engine.symbol) ?? ".")
        }
        var lines = ["BOARD  " + slots.joined(separator: "  ")]
        if state.isOver {
            lines.append(style.bright("CODE   " + state.code.joined(separator: " ")))
        } else {
            lines.append(
                "ENERGY \(state.energy)/\(content.energy)  DRAW \(state.drawPile.count)  DISCARD \(state.discardPile.count)"
            )
        }
        let hand = state.hand.enumerated().map { "\($0.offset + 1):" + session.engine.symbol($0.element) }
        lines += Columns.wrap("HAND   " + (hand.isEmpty ? "(EMPTY)" : hand.joined(separator: "  ")), indent: "       ")
        return lines
    }
}
