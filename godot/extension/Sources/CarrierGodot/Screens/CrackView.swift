import CarrierCore
import SwiftGodot

/// A crack: the server and the alarm across the top, your guesses on the
/// left, the board in the middle with what the server will do, the log, and
/// your hand along the bottom with the turn's buttons.
enum CrackView {
    /// What a screen asks the game to do: a rule action, or a click the
    /// game turns into one (`CrackPlay` keeps the selection).
    enum Input {
        case send(CrackRunAction)
        case card(Int)
        case slot(Int)
        case turn(slot: Int, step: Int)
        case drop
    }

    static func make(_ play: CrackPlay, crack: CrackState, input: @escaping (Input) -> Void) -> Control {
        let root = Phosphor.vbox(separation: 10)
        root.addChild(node: header(play, crack: crack))
        let middle = Phosphor.hbox(separation: 16)
        middle.sizeFlagsVertical = .expandFill
        middle.addChild(node: GuessList.make(crack.guesses, legend: crack.server.feedback.legend))
        middle.addChild(node: board(play, crack: crack, input: input))
        root.addChild(node: middle)
        root.addChild(node: LogPanel.make(play.log, lines: 4))
        root.addChild(node: hand(play, crack: crack, input: input))
        return root
    }

    private static func header(_ play: CrackPlay, crack: CrackState) -> Control {
        let server = crack.server
        let row = Phosphor.hbox(separation: 24)
        row.addChild(node: Phosphor.label(server.name, color: Phosphor.bright, size: 22))
        let total = play.content.run.servers.count
        if total > 1 {
            row.addChild(node: Phosphor.label("SERVER \(min(play.state.round + 1, total))/\(total)"))
        }
        row.addChild(node: Phosphor.label("TURN \(crack.turn)"))
        row.addChild(node: Phosphor.spacer())
        row.addChild(node: Phosphor.bar("ALARM", value: crack.alarm, of: play.content.alarm.max, color: Phosphor.red))
        row.addChild(node: Phosphor.label("NEXT GUESS +\(play.rules.nextGuessCost(crack))", color: Phosphor.amber))
        row.addChild(node: energy(crack.energy, of: play.content.energy, content: play.content))
        return Phosphor.panel(row)
    }

    /// ENERGY and a pip for each point.
    private static func energy(_ value: Int, of max: Int, content: CrackContent) -> Control {
        let row = Phosphor.hbox(separation: 4)
        let label = RuleText.make("ENERGY", content: content, size: 16)
        label.customMinimumSize = Vector2(x: 70, y: 0)
        row.addChild(node: label)
        for index in 0..<Swift.max(value, max) {
            let pip = ColorRect()
            pip.color = index < value ? Phosphor.bright : Phosphor.dim
            pip.customMinimumSize = Vector2(x: 14, y: 14)
            pip.sizeFlagsVertical = .shrinkCenter
            row.addChild(node: pip)
        }
        return row
    }

    /// The board, centered, with the server's programs and what you have
    /// learned above it and the prompt below.
    private static func board(_ play: CrackPlay, crack: CrackState, input: @escaping (Input) -> Void) -> Control {
        let column = Phosphor.vbox(separation: 12)
        column.sizeFlagsHorizontal = .expandFill
        column.alignment = .center

        var notes: [String] = []
        for program in crack.server.interference {
            let wait = play.rules.turnsUntil(program, in: crack)
            let when =
                switch wait {
                case 0: " AFTER THIS TURN"
                case 1: " AFTER NEXT TURN"
                default: " IN \(wait + 1) TURNS"
                }
            notes.append(program.kind.label + when)
        }
        let serverLine = notes.isEmpty ? "THE SERVER ONLY WATCHES." : "SERVER: " + notes.joined(separator: ", ")
        let top = RuleText.make(serverLine, content: play.content, size: 16, color: Phosphor.amber)
        top.horizontalAlignment = .center
        column.addChild(node: top)

        var learned = crack.facts.map(\.text)
        if crack.debugAlarm != nil { learned.append(CrackEvent.debugArmed.line) }
        if let percent = crack.spoofPercent { learned.append(CrackEvent.spoofArmed(percent: percent).line) }
        if !learned.isEmpty {
            let line = RuleText.make(learned.joined(separator: "   "), content: play.content, size: 14)
            line.horizontalAlignment = .center
            column.addChild(node: line)
        }

        let slots = Phosphor.hbox(separation: 14)
        slots.alignment = .center
        for (index, slot) in crack.board.enumerated() {
            let model = SlotView.Model(
                number: index + 1, symbol: slot?.symbol,
                isDial: slot.map { play.rules.kind($0.card) == .dial } ?? false, isLocked: crack.locked[index],
                known: crack.revealed[index], selected: play.selectedSlot == index, target: play.selectedCard != nil)
            slots.addChild(
                node: SlotView.make(
                    model, click: { input(.slot(index)) }, turn: { input(.turn(slot: index, step: $0)) }))
        }
        column.addChild(node: slots)
        let prompt = Phosphor.label(play.prompt, color: Phosphor.dim, size: 14)
        prompt.horizontalAlignment = .center
        column.addChild(node: prompt)
        let symbols = Phosphor.label("SYMBOLS: " + crack.server.symbols.joined(separator: " "), color: Phosphor.green)
        symbols.horizontalAlignment = .center
        column.addChild(node: symbols)
        return column
    }

    private static func hand(_ play: CrackPlay, crack: CrackState, input: @escaping (Input) -> Void) -> Control {
        let row = Phosphor.hbox(separation: 10)
        row.addChild(node: PileView.make("DRAW", count: crack.drawPile.count))
        let cards = Phosphor.hbox(separation: 10)
        cards.sizeFlagsHorizontal = .expandFill
        cards.alignment = .center
        for (index, instance) in crack.hand.enumerated() {
            guard let card = play.content.card(instance.cardID) else { continue }
            let model = CrackCardView.Model(
                card: card, cost: play.rules.playCost(instance), selected: play.selectedCard == index,
                refusal: play.rules.refusal(forCard: index, in: crack)?.label)
            cards.addChild(node: CrackCardView.make(model, content: play.content) { input(.card(index)) })
        }
        if crack.hand.isEmpty { cards.addChild(node: Phosphor.label("NO CARDS IN HAND")) }
        row.addChild(node: cards)
        row.addChild(node: PileView.make("DISCARD", count: crack.discardPile.count))

        let buttons = Phosphor.vbox(separation: 6)
        let guess = Phosphor.button("GUESS  +\(play.rules.nextGuessCost(crack))") { input(.send(.crack(.guess))) }
        guess.customMinimumSize = Vector2(x: 170, y: 56)
        guess.addThemeFontSizeOverride(name: "font_size", fontSize: 20)
        guess.tooltipText = "SUBMIT THE BOARD. THE SERVER SAYS HOW CLOSE."
        buttons.addChild(node: guess)
        let hold = Phosphor.button("HOLD  +\(play.content.alarm.hold)") { input(.send(.crack(.hold))) }
        hold.tooltipText = "END THE TURN WITHOUT A GUESS. DRAW AGAIN."
        buttons.addChild(node: hold)
        let drop = Phosphor.button("DROP CARD  \(play.content.costs.drop)") { input(.drop) }
        drop.disabled =
            play.selectedCard.map { play.rules.rejection(of: .drop(handIndex: $0), in: crack) != nil } ?? true
        drop.tooltipText = "PICK A CARD, THEN DROP IT TO THE DISCARD PILE."
        buttons.addChild(node: drop)
        buttons.addChild(node: Phosphor.button("LOGOUT") { input(.send(.crack(.logout))) })
        row.addChild(node: buttons)
        return row
    }
}
