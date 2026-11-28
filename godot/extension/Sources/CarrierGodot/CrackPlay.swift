import CarrierCore

/// A crack run as the Godot screens play it: the run engine and state, the
/// log, the last crack (kept when the run moves past it), and what the
/// player has selected. The selection is the UI's, not the rules': the
/// engine never sees it.
struct CrackPlay {
    let engine: CrackRunEngine
    private(set) var state: CrackRunState
    private(set) var log: [String] = []
    /// The crack under way, or the last one once the run is past it.
    var crack: CrackState? { state.currentOrLastCrack }
    /// A hand card picked, waiting for a slot.
    var selectedCard: Int?
    /// A board slot picked, waiting for a second slot to swap with.
    var selectedSlot: Int?

    var content: CrackContent { engine.content }
    var rules: CrackEngine { engine.crack }

    init(content: CrackContent, seed: UInt64) {
        engine = CrackRunEngine(content: content)
        let (state, events) = engine.start(seed: seed)
        self.state = state
        append(events)
    }

    mutating func send(_ action: CrackRunAction) {
        let (next, events) = engine.apply(action, to: state)
        state = next
        append(events)
        selectedCard = nil
        selectedSlot = nil
    }

    /// A click on hand card `index`: a card played on its own runs now; a
    /// card played on a slot is picked (or unpicked).
    mutating func clickCard(_ index: Int) {
        guard let crack, crack.hand.indices.contains(index) else { return }
        if rules.kind(crack.hand[index]).needsSlot {
            selectedCard = selectedCard == index ? nil : index
            selectedSlot = nil
        } else {
            send(.crack(.use(handIndex: index)))
        }
    }

    /// A click on slot `slot`: plays the picked card there, or picks the
    /// slot, or swaps it with the slot picked before.
    mutating func clickSlot(_ slot: Int) {
        if let card = selectedCard {
            send(.crack(.play(handIndex: card, slot: slot)))
        } else if let first = selectedSlot {
            if first == slot {
                selectedSlot = nil
            } else {
                send(.crack(.swap(first, slot)))
            }
        } else {
            selectedSlot = slot
        }
    }

    /// Turns the dial in `slot` one step along the symbol list, `step` +1
    /// or -1, wrapping.
    mutating func turnDial(_ slot: Int, step: Int) {
        guard let symbol = crack?.board[slot]?.symbol,
            let index = content.symbols.firstIndex(of: symbol), !content.symbols.isEmpty
        else { return }
        let count = content.symbols.count
        send(.crack(.turn(slot: slot, symbol: content.symbols[(index + step + count) % count])))
    }

    /// The line under the board that says what a click will do next.
    var prompt: String {
        guard let crack else { return "" }
        if let card = selectedCard, crack.hand.indices.contains(card) {
            return "CLICK A SLOT FOR \(rules.label(crack.hand[card])). OR DROP IT."
        }
        if let slot = selectedSlot {
            return "CLICK ANOTHER SLOT TO SWAP WITH SLOT \(slot + 1)."
        }
        return "CLICK A CARD, THEN A SLOT. CLICK TWO SLOTS TO SWAP."
    }

    private mutating func append(_ events: [CrackRunEvent]) {
        let content = engine.content
        for event in events {
            log.append(event.line { content.card($0)?.label ?? $0 })
        }
    }
}
