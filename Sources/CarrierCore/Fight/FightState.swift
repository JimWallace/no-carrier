/// The whole state of one node fight. Value type: the engine returns a new
/// one for every action.
public struct FightState: Codable, Sendable, Equatable {
    /// The machine, whose `layers` take the damage.
    public var machine: Machine
    public var ice: [ICEInstance]
    /// PROBE has shown the weak and resist tags.
    public var revealed: Bool

    public var drawPile: [CardInstance]
    public var hand: [CardInstance]
    public var discardPile: [CardInstance]
    /// Played with `exhaust` (PROBE): out until the fight ends.
    public var exhaustPile: [CardInstance]
    /// Running daemons, in the order they started.
    public var daemons: [CardInstance]
    /// Played with `consumed` (PAYLOAD): gone from the deck for good.
    public var consumedCards: [CardInstance]

    public var rig: Rig
    public var cycles: Int
    public var bonusCyclesNextTurn: Int
    public var proxy: Int
    /// HONEYPOT damage waiting for the next ICE attack this turn.
    public var retaliation: Int
    public var integrity: Int
    /// Global Trace, carried in and out of the fight.
    public var trace: Int
    public var turn: Int
    public var outcome: FightOutcome?

    public var rng: Xoshiro256StarStar
    public var nextUID: Int
    /// A file copy, when this is a TARGET fight. Then breaching every layer
    /// starts the copy instead of capturing the node.
    public var transfer: TransferProgress?
    /// NULL ROUTE's cut to ICE TRACE intents, until the next turn.
    public var turnTraceShield: Int

    public init(
        machine: Machine,
        ice: [ICEInstance],
        revealed: Bool = false,
        drawPile: [CardInstance] = [],
        hand: [CardInstance] = [],
        discardPile: [CardInstance] = [],
        exhaustPile: [CardInstance] = [],
        daemons: [CardInstance] = [],
        consumedCards: [CardInstance] = [],
        rig: Rig,
        cycles: Int,
        bonusCyclesNextTurn: Int = 0,
        proxy: Int = 0,
        retaliation: Int = 0,
        integrity: Int,
        trace: Int,
        turn: Int = 1,
        outcome: FightOutcome? = nil,
        rng: Xoshiro256StarStar,
        nextUID: Int,
        transfer: TransferProgress? = nil
    ) {
        self.machine = machine
        self.ice = ice
        self.revealed = revealed
        self.drawPile = drawPile
        self.hand = hand
        self.discardPile = discardPile
        self.exhaustPile = exhaustPile
        self.daemons = daemons
        self.consumedCards = consumedCards
        self.rig = rig
        self.cycles = cycles
        self.bonusCyclesNextTurn = bonusCyclesNextTurn
        self.proxy = proxy
        self.retaliation = retaliation
        self.integrity = integrity
        self.trace = trace
        self.turn = turn
        self.outcome = outcome
        self.rng = rng
        self.nextUID = nextUID
        self.transfer = transfer
        turnTraceShield = 0
    }

    /// The outermost layer that still has HP, or nil when every layer is
    /// breached.
    public var currentLayerIndex: Int? {
        machine.layers.firstIndex { !$0.isBreached }
    }

    public var currentLayer: LayerKind? {
        currentLayerIndex.map { machine.layers[$0].kind }
    }

    public var isOver: Bool { outcome != nil }

    /// Every card that belongs to the deck, wherever it is in the fight.
    public var allCards: [CardInstance] {
        drawPile + hand + discardPile + exhaustPile + daemons
    }
}
