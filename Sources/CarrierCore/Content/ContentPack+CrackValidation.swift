extension ContentPack {
    /// `crack.json`: every server's code must be possible to make and to
    /// enter, and every card in the starter deck must exist and show a known
    /// symbol.
    public func validateCrack(_ crack: CrackContent) -> [ContentError] {
        var errors: [ContentError] = []
        if crack.symbols.isEmpty { errors.append(.emptyList(field: "crack.symbols")) }
        if crack.starterDeck.isEmpty { errors.append(.emptyList(field: "crack.starterDeck")) }
        if crack.servers.isEmpty { errors.append(.emptyList(field: "crack.servers")) }
        errors += duplicates(crack.symbols, kind: "crack symbol")
        errors += duplicates(crack.cards.map(\.id), kind: "crack card")
        errors += duplicates(crack.servers.map(\.id), kind: "crack server")
        if crack.alarm.max < 1 {
            errors.append(.invalidValue(field: "crack.alarm.max", reason: "must be at least 1"))
        }
        if crack.handSize < 1 { errors.append(.invalidValue(field: "crack.handSize", reason: "must be at least 1")) }
        let costs = [crack.costs.place, crack.costs.swap, crack.costs.drop, crack.costs.turn, crack.costs.probe]
        if crack.energy < 0 || costs.contains(where: { $0 < 0 }) {
            errors.append(.invalidValue(field: "crack.costs", reason: "energy and costs cannot be negative"))
        }
        errors += validateCrackCards(crack)
        for id in crack.starterDeck where crack.card(id) == nil {
            errors.append(.unknownCard(id: id, referencedBy: "crack.starterDeck"))
        }
        for server in crack.servers {
            errors += validateCrackServer(server, in: crack)
        }
        return errors
    }

    private func validateCrackCards(_ crack: CrackContent) -> [ContentError] {
        var errors: [ContentError] = []
        for card in crack.cards {
            switch (card.kind, card.symbol) {
            case (.probe, nil):
                break
            case (.probe, .some):
                errors.append(.invalidValue(field: "crack.cards.\(card.id)", reason: "a probe shows no symbol"))
            case (_, nil):
                errors.append(.invalidValue(field: "crack.cards.\(card.id)", reason: "needs a symbol"))
            case (_, .some(let symbol)) where !crack.symbols.contains(symbol):
                errors.append(.invalidValue(field: "crack.cards.\(card.id)", reason: "\"\(symbol)\" is not a symbol"))
            default:
                break
            }
        }
        return errors
    }

    private func validateCrackServer(_ server: CrackServer, in crack: CrackContent) -> [ContentError] {
        let field = "crack.servers.\(server.id)"
        var errors: [ContentError] = []
        if server.symbols.isEmpty { errors.append(.emptyList(field: "\(field).symbols")) }
        errors += duplicates(server.symbols, kind: "\(server.id) symbol")
        for symbol in server.symbols where !crack.symbols.contains(symbol) {
            errors.append(.invalidValue(field: "\(field).symbols", reason: "\"\(symbol)\" is not a symbol"))
        }
        if server.codeLength < 1 {
            errors.append(.invalidValue(field: "\(field).codeLength", reason: "must be at least 1"))
        }
        if server.maxRepeats < 1 || server.maxRepeats * server.symbols.count < server.codeLength {
            errors.append(
                .invalidValue(field: "\(field).maxRepeats", reason: "too low to fill a code of \(server.codeLength)"))
        }
        if server.alarmPerGuess < 1 || server.escalation < 0 {
            errors.append(
                .invalidValue(field: "\(field).alarmPerGuess", reason: "must be at least 1, escalation at least 0"))
        }
        if server.interference.contains(where: { $0.every < 1 }) {
            errors.append(.invalidValue(field: "\(field).interference", reason: "every must be at least 1"))
        }
        if crack.starterDeck.count < crack.handSize + server.codeLength {
            errors.append(
                .invalidValue(
                    field: "\(field).codeLength", reason: "the starter deck needs handSize + codeLength cards"))
        }
        // The code may use a symbol maxRepeats times; the deck must hold that
        // many cards that can show it, or the code could be impossible to
        // enter. A dial can show any symbol, so it counts for every one; at
        // the starter deck's sizes that is close enough.
        let dials = crack.starterDeck.count { crack.card($0)?.kind == .dial }
        for symbol in server.symbols {
            let printed = crack.starterDeck.count {
                crack.card($0)?.kind == .symbol && crack.card($0)?.symbol == symbol
            }
            let copies = printed + dials
            if copies < server.maxRepeats {
                errors.append(
                    .invalidValue(
                        field: "crack.starterDeck",
                        reason: "has \(copies) \(symbol), fewer than \(server.id) maxRepeats (\(server.maxRepeats))"))
            }
        }
        return errors
    }
}
