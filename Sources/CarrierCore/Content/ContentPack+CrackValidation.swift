extension ContentPack {
    /// `crack.json`: the code must be possible to make, and every card in
    /// the starter deck must exist and show a known symbol.
    public func validateCrack(_ crack: CrackContent) -> [ContentError] {
        var errors: [ContentError] = []
        if crack.symbols.isEmpty { errors.append(.emptyList(field: "crack.symbols")) }
        if crack.starterDeck.isEmpty { errors.append(.emptyList(field: "crack.starterDeck")) }
        errors += duplicates(crack.symbols, kind: "crack symbol")
        errors += duplicates(crack.cards.map(\.id), kind: "crack card")
        if crack.codeLength < 1 {
            errors.append(.invalidValue(field: "crack.codeLength", reason: "must be at least 1"))
        }
        if crack.maxRepeats < 1 || crack.maxRepeats * crack.symbols.count < crack.codeLength {
            errors.append(
                .invalidValue(field: "crack.maxRepeats", reason: "too low to fill a code of \(crack.codeLength)"))
        }
        if crack.alarm.max < 1 {
            errors.append(.invalidValue(field: "crack.alarm.max", reason: "must be at least 1"))
        }
        if crack.starterDeck.count < crack.handSize + crack.codeLength {
            errors.append(
                .invalidValue(field: "crack.starterDeck", reason: "needs at least handSize + codeLength cards"))
        }
        // A code may use a symbol maxRepeats times; the deck must hold that
        // many copies, or the code could be impossible to enter.
        for symbol in crack.symbols {
            let copies = crack.starterDeck.count { crack.card($0)?.symbol == symbol }
            if copies < crack.maxRepeats {
                errors.append(
                    .invalidValue(
                        field: "crack.starterDeck",
                        reason: "has \(copies) \(symbol), fewer than maxRepeats (\(crack.maxRepeats))"))
            }
        }
        if crack.handSize < 1 { errors.append(.invalidValue(field: "crack.handSize", reason: "must be at least 1")) }
        if crack.alarm.perGuess < 1 {
            errors.append(.invalidValue(field: "crack.alarm.perGuess", reason: "must be at least 1"))
        }
        let costs = [crack.costs.place, crack.costs.swap, crack.costs.drop]
        if crack.energy < 0 || costs.contains(where: { $0 < 0 }) {
            errors.append(.invalidValue(field: "crack.costs", reason: "energy and costs cannot be negative"))
        }
        for card in crack.cards where !crack.symbols.contains(card.symbol) {
            errors.append(.invalidValue(field: "crack.cards.\(card.id)", reason: "\"\(card.symbol)\" is not a symbol"))
        }
        for id in crack.starterDeck where crack.card(id) == nil {
            errors.append(.unknownCard(id: id, referencedBy: "crack.starterDeck"))
        }
        return errors
    }
}
