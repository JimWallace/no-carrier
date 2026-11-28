import CarrierCore
import CarrierTerminal
import Testing

/// What the crack prompt makes of a typed line. Numbers on screen count
/// from 1; actions count from 0.
@Suite struct CrackInputTests {
    @Test(arguments: [
        ("1 3", CrackInput.action(.play(handIndex: 0, slot: 2))),
        ("13", .action(.play(handIndex: 0, slot: 2))),
        ("p 2 4", .action(.play(handIndex: 1, slot: 3))),
        ("PLACE 2 4", .action(.play(handIndex: 1, slot: 3))),
        ("s 1 2", .action(.swap(0, 1))),
        ("t 2 k", .action(.turn(slot: 1, symbol: "K"))),
        ("TURN 4 Z", .action(.turn(slot: 3, symbol: "Z"))),
        ("t 2 3", .unknown("T 2 3")),
        ("d 5", .action(.drop(handIndex: 4))),
        ("g", .action(.guess)),
        ("h", .action(.hold)),
        ("HOLD", .action(.hold)),
        ("2", .action(.use(handIndex: 1))),
        ("take 2", .reward(.take(1))),
        ("remove 12", .reward(.remove(11))),
        ("skip", .reward(.skip)),
        ("info", .info),
        ("deck", .deck),
        ("GUESS", .action(.guess)),
        ("logout", .action(.logout)),
        ("help", .help),
        ("?", .help),
        ("? alarm", .define("ALARM")),
        ("define slot", .define("SLOT")),
        ("quit", .quit),
        ("", .empty),
        ("g 1", .unknown("G 1")),
        ("s 1", .unknown("S 1")),
        ("frobnicate", .unknown("FROBNICATE")),
    ])
    func parses(text: String, expected: CrackInput) {
        #expect(CrackInput.parse(text) == expected)
    }
}
