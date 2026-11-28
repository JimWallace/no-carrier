public import CarrierCore

/// Builds a fight in a chosen position, for rule tests: a machine with the
/// given layers and tags, and a hand of the given cards.
public struct FightFixture {
    public var layers: [SecurityLayer] = [SecurityLayer(kind: .firewall, hp: 20), SecurityLayer(kind: .auth, hp: 20)]
    public var weak: [ExploitTag] = []
    public var resist: [ExploitTag] = []
    public var ice: [String] = []
    public var cpuTier = 1
    public var tracePercent = 100
    public var hand: [String] = []
    public var drawPile: [String] = []
    public var discardPile: [String] = []
    public var daemons: [String] = []
    public var cycles = 3
    public var integrity = 40
    public var trace = 0
    public var proxy = 0
    public var transfer: TransferProgress?

    public init() {}

    public func machine() -> Machine {
        Machine(
            seed: 0,
            role: layers.contains { $0.kind == .kernel } ? .sysop : .neutral,
            orgName: "TEST ORG",
            orgKind: "CORP",
            hostname: "test.example.com",
            osFamilyID: "test",
            osName: "TESTOS",
            osVersion: "1",
            cpu: CPUModel(name: "TEST CPU", tier: cpuTier),
            ramMB: 8,
            modem: ModemModel(name: "TEST MODEM", tracePercent: tracePercent),
            weak: weak,
            resist: resist,
            layers: layers,
            ice: ice,
            users: [],
            filesystem: []
        )
    }

    public func state(content: ContentPack) -> GameState {
        var uid = 0
        func cards(_ ids: [String]) -> [CardInstance] {
            ids.map { id in
                defer { uid += 1 }
                return CardInstance(uid: uid, cardID: id)
            }
        }
        let rig = Rig(tuning: content.tuning.rig)
        let fight = FightState(
            machine: machine(),
            ice: ice.map { ICEInstance(iceID: $0) },
            drawPile: cards(drawPile),
            hand: cards(hand),
            discardPile: cards(discardPile),
            daemons: cards(daemons),
            rig: rig,
            cycles: cycles,
            proxy: proxy,
            integrity: integrity,
            trace: trace,
            rng: Xoshiro256StarStar(seed: 1),
            nextUID: uid,
            transfer: transfer
        )
        return GameState(seed: 0, fight: fight, rules: RuleSet.defaults(content: content, objective: nil))
    }
}

extension GameState {
    /// The HP of each layer, outermost first.
    public var layerHP: [Int] { fight.machine.layers.map(\.hp) }

    /// The ids of the cards in hand.
    public var handIDs: [String] { fight.hand.map(\.cardID) }
}
