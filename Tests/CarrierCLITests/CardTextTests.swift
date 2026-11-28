import CarrierCore
import CarrierTerminal
import TestSupport
import Testing

@Suite struct CardTextTests {
    @Test func everyHandLineFitsTheColumns() throws {
        let content = try BundledContent.load()
        let refusals: [RejectReason?] = [
            nil, .notEnoughCycles(cardID: "x", cost: 2, cycles: 0), .notEnoughRAM(cardID: "x", needed: 3, free: 0),
            .wrongLayer(cardID: "x", required: .kernel), .unplayable(cardID: "x"),
        ]
        for card in content.cards {
            for refusal in refusals {
                let line = CardText.handLine(number: 9, card: card, refusal: refusal)
                #expect(line.count <= Columns.textWidth, "\(line)")
            }
        }
    }

    @Test func aRefusedCardSaysWhy() throws {
        let content = try BundledContent.load()
        let smash = try #require(content.card("stack-smash"))
        let line = CardText.handLine(
            number: 0, card: smash, refusal: .notEnoughCycles(cardID: "stack-smash", cost: 2, cycles: 1))
        #expect(line == "1 STACK SMASH    2 NO CYC: ATK 13")
    }

    @Test func detailsShowWeaknessOnceProbed() throws {
        let content = try BundledContent.load()
        let overflow = try #require(content.card("overflow"))
        let lines = CardText.details(overflow, numbers: [0, 2], revealedWeak: [.overflow], revealedResist: [])
        #expect(lines.first?.hasPrefix("1,3 OVERFLOW") == true)
        #expect(lines.contains { $0.contains("WEAK HERE") })
        #expect(lines.allSatisfy { $0.count <= Columns.textWidth })
    }

    @Test func thePanelSitsBesideTheGameWithinEightyColumns() {
        let style = Phosphor(enabled: true)
        let left = [style.inverse("LEFT"), "A LINE"]
        let joined = Columns.beside(left, ["RIGHT", String(repeating: "X", count: Columns.panelWidth), "THIRD"])
        #expect(joined.count == 3)
        for line in joined {
            #expect(Columns.visibleWidth(Columns.prompt + line) <= Columns.panelNeeds - 1)
        }
        #expect(Columns.visibleWidth(joined[0]) == Columns.textWidth + 3 + 5)
    }
}
