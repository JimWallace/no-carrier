import CarrierCore

/// One frame of a crack run in 40 columns. In a crack: the alarm, the
/// guesses so far, the log, the board and the hand. At a reward: the offer,
/// the next server and the deck.
package struct CrackScreen {
    package let session: CrackSession
    package let style: Phosphor
    package let screenRows: Int
    package static let minimumLogRows = 3

    private var content: CrackContent { session.engine.content }
    private var engine: CrackEngine { session.crackEngine }
    private let rule = String(repeating: "-", count: Columns.textWidth)

    package init(session: CrackSession, style: Phosphor, screenRows: Int = 24) {
        self.session = session
        self.style = style
        self.screenRows = screenRows
    }

    package func lines(prompt: String?, hint: String) -> [String] {
        var top: [String]
        var bottom: [String]
        if case .reward(let cards, let next) = session.state.phase {
            top = reward(cards: cards, next: next) + [rule]
            bottom = [rule]
        } else if let crack = session.crack {
            top = header(crack) + [rule] + guesses(crack) + [rule]
            bottom = [rule] + board(crack)
        } else {
            top = []
            bottom = []
        }
        if let prompt {
            bottom.append(">" + prompt + style.blink("_"))
            bottom.append(hint)
        }
        let logRows = max(Self.minimumLogRows, screenRows - top.count - bottom.count)
        let shown = session.log.suffix(logRows)
        return top + shown + Array(repeating: "", count: max(0, logRows - shown.count)) + bottom
    }

    private func runTitle() -> String {
        let total = content.run.servers.count
        return total > 1 ? "SERVER \(min(session.state.round + 1, total))/\(total)" : ""
    }

    private func reward(cards: [String], next: String) -> [String] {
        var lines = [style.inverse(Columns.spread("CRACKED. CHOOSE ONE", runTitle()))]
        for (index, id) in cards.enumerated() {
            guard let card = content.card(id) else { continue }
            let cost = engine.cost(of: card)
            lines += Columns.wrap("TAKE \(index + 1): \(card.label) (\(cost) EN) \(card.rules)", indent: "        ")
        }
        lines.append("OR REMOVE N FROM YOUR DECK, OR SKIP.")
        if let server = content.server(next) {
            lines.append(rule)
            lines.append("NEXT: \(server.name)")
            lines += Columns.wrap(Self.profile(server), indent: "  ")
        }
        lines.append(rule)
        lines += Columns.wrap(session.deckLine(), indent: "  ")
        return lines
    }

    /// One line on what a server is like, for choosing a reward.
    static func profile(_ server: CrackServer) -> String {
        let feedback =
            switch server.feedback {
            case .counts: "HIT+NEAR"
            case .hits: "HITS ONLY"
            case .slots: "MARK PER SLOT"
            }
        var parts = ["\(server.codeLength) SLOTS", "\(server.symbols.count) SYMBOLS", feedback]
        parts += server.interference.map { "\($0.kind.label)/\($0.every)" }
        if server.escalation > 0 { parts.append("ALARM RISES") }
        return parts.joined(separator: ", ")
    }

    private func header(_ crack: CrackState) -> [String] {
        let server = crack.server
        let title = Columns.spread(
            server.name, [runTitle(), "TURN \(crack.turn)"].filter { !$0.isEmpty }.joined(separator: " "))
        let alarm = "ALARM " + Columns.bar(crack.alarm, of: content.alarm.max, cells: 20) + " \(crack.alarm)"
        let loud = crack.alarm * 4 >= content.alarm.max * 3
        var lines = [
            style.inverse(title),
            loud ? style.blink(alarm) : alarm,
            "SYMBOLS " + server.symbols.joined(separator: " ") + "  NEXT GUESS +\(engine.nextGuessCost(crack))",
        ]
        var notes = server.interference.map { program in
            let wait = engine.turnsUntil(program, in: crack)
            return program.kind.label + (wait == 0 ? " THIS TURN" : " IN \(wait)")
        }
        if !notes.isEmpty {
            lines += Columns.wrap("SERVER: " + notes.joined(separator: ", "), indent: "        ")
        }
        notes = []
        if crack.debugAlarm != nil { notes.append("DEBUG") }
        if let percent = crack.spoofPercent { notes.append("SPOOF \(percent)%") }
        notes += crack.facts.map(\.text)
        if !notes.isEmpty {
            lines += Columns.wrap("YOU: " + notes.joined(separator: ", "), indent: "     ")
        }
        return lines
    }

    /// Every guess so far, numbered, with its feedback.
    private func guesses(_ crack: CrackState) -> [String] {
        if crack.guesses.isEmpty { return ["NO GUESSES YET"] }
        return crack.guesses.enumerated().map { index, guess in
            let number = index + 1 < 10 ? " \(index + 1)" : "\(index + 1)"
            let symbols = guess.symbols.map { $0 ?? "." }.joined(separator: " ")
            return "\(number)  \(symbols)   \(guess.feedback.text)"
        }
    }

    private func board(_ crack: CrackState) -> [String] {
        let slots = crack.board.enumerated().map { index, slot in
            guard let slot else { return "\(index + 1):." }
            let dial = engine.kind(slot.card) == .dial ? "~" : ""
            let lock = crack.locked[index] ? "#" : ""
            return "\(index + 1):" + slot.symbol + dial + lock
        }
        var lines = Columns.wrap("BOARD  " + slots.joined(separator: " "), indent: "       ")
        if crack.revealed.contains(where: { $0 != nil }) {
            let known = crack.revealed.enumerated().map { "\($0.offset + 1):" + ($0.element ?? ".") }
            lines.append("KNOWN  " + known.joined(separator: "  "))
        }
        if crack.isOver {
            lines.append(style.bright("CODE   " + crack.code.joined(separator: " ")))
        } else {
            lines.append(
                "ENERGY \(crack.energy)/\(content.energy)  DRAW \(crack.drawPile.count)  DISCARD \(crack.discardPile.count)"
            )
        }
        let hand = crack.hand.enumerated().map { "\($0.offset + 1):" + engine.label($0.element) }
        lines += Columns.wrap("HAND   " + (hand.isEmpty ? "(EMPTY)" : hand.joined(separator: "  ")), indent: "       ")
        return lines
    }
}
