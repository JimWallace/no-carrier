import CarrierCore
import CarrierTerminal
import Testing

/// What the crack prompt makes of a typed line. Numbers on screen count
/// from 1; actions count from 0.
@Suite struct CrackInputTests {
    @Test(arguments: [
        ("1 3", CrackInput.action(.place(handIndex: 0, slot: 2))),
        ("13", .action(.place(handIndex: 0, slot: 2))),
        ("p 2 4", .action(.place(handIndex: 1, slot: 3))),
        ("PLACE 2 4", .action(.place(handIndex: 1, slot: 3))),
        ("s 1 2", .action(.swap(0, 1))),
        ("d 5", .action(.drop(handIndex: 4))),
        ("g", .action(.guess)),
        ("GUESS", .action(.guess)),
        ("logout", .action(.logout)),
        ("help", .help),
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
