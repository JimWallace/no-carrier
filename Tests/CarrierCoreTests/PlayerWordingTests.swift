import CarrierCore
import TestSupport
import Testing

/// The words that both frontends show the player live in CarrierCore. These
/// pin them, so the terminal and Godot cannot drift apart.
@Suite struct PlayerWordingTests {
    @Test(arguments: [
        (RejectReason.notEnoughCycles(cardID: "x", cost: 2, cycles: 0), "NO CYC"),
        (.notEnoughRAM(cardID: "x", needed: 3, free: 0), "NO RAM"),
        (.wrongLayer(cardID: "x", required: .kernel), "KERNEL ONLY"),
        (.unplayable(cardID: "x"), "DEAD"),
        (.fightOver, "OVER"),
        (.noSuchCard(handIndex: 9), "?"),
        (.unknownCard(cardID: "x"), "?"),
    ])
    func refusalLabels(reason: RejectReason, label: String) {
        #expect(reason.shortLabel == label)
    }

    @Test func outcomeTitles() {
        #expect(ContractOutcome.won.title(win: .exfiltrate) == "FILE DELIVERED. CONTRACT COMPLETE.")
        #expect(ContractOutcome.won.title(win: .captureRoot) == "ROOT ACCESS. CONTRACT COMPLETE.")
        #expect(ContractOutcome.traced.title(win: .exfiltrate) == "NO CARRIER")
        #expect(ContractOutcome.jackedOut.title(win: .exfiltrate) == "JACKED OUT. OBJECTIVE NOT MET.")
    }

    @Test func nodeMeaningsTakeTheirNumbersFromTheTuning() throws {
        var tuning = try BundledContent.load().tuning.network
        tuning.repairIntegrity = 7
        tuning.virusPayload = 2
        #expect(NodeType.repair.meaning(tuning: tuning, payloadName: "PAYLOAD") == "REPAIR: +7 INT EACH TICK")
        #expect(NodeType.virus.meaning(tuning: tuning, payloadName: "WORM") == "VIRUS: +2 WORM EACH TICK")
    }
}
