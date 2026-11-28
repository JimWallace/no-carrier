/// The network layer's numbers (kickoff §3 and §5).
public struct NetworkTuning: Codable, Sendable, Equatable {
    /// Noise and Alert, which also set the Trace drift per tick.
    public var alert: AlertTuning
    /// What the sysop's SWEEP adds to Trace.
    public var sweepTrace: Int
    /// What the sysop's HARDEN adds to one layer.
    public var hardenAmount: Int
    /// Integrity each REPAIR node restores per tick.
    public var repairIntegrity: Int
    /// Starting Proxy in every fight, per RELAY owned.
    public var relayProxy: Int
    /// PAYLOAD cards each VIRUS node adds per tick, while Storage has room.
    public var virusPayload: Int
    /// The card a VIRUS node produces.
    public var payloadCard: String
    /// The most ICE programs a sysop SPAWN ICE can raise a node to.
    public var maxICE: Int
    /// How likely each sysop intent is, as weights.
    public var sysopIntents: SysopIntentWeights
    /// How likely each type is for a node the template leaves open.
    public var nodeTypes: NodeTypeWeights
    /// Card rewards offered after a capture.
    public var rewardChoices: Int
    public var rewardPool: [String]
    /// The DATA node's choice of hardware upgrades (kickoff §5).
    public var dataUpgrades: [RigUpgrade]
}

public struct SysopIntentWeights: Codable, Sendable, Equatable {
    public var contest: Int
    public var harden: Int
    public var spawnICE: Int
    public var sweep: Int
    public var revoke: Int
}

public struct NodeTypeWeights: Codable, Sendable, Equatable {
    public var relay: Int
    public var repair: Int
    public var virus: Int
    public var data: Int

    /// The weighted types, in a fixed order.
    public var table: [(NodeType, Int)] {
        [(.relay, relay), (.repair, repair), (.virus, virus), (.data, data)]
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.relay == rhs.relay && lhs.repair == rhs.repair && lhs.virus == rhs.virus && lhs.data == rhs.data
    }
}

/// One hardware upgrade a DATA node can give.
public struct RigUpgrade: Codable, Sendable, Equatable {
    public enum Component: String, Codable, Sendable {
        case cpu
        case ram
        case storage
        case chassis
    }

    public var component: Component
    public var amount: Int

    public init(component: Component, amount: Int) {
        self.component = component
        self.amount = amount
    }

    public var label: String {
        switch component {
        case .cpu: "+\(amount) CPU (CYCLES)"
        case .ram: "+\(amount) RAM"
        case .storage: "+\(amount) STORAGE"
        case .chassis: "+\(amount) MAX INTEGRITY"
        }
    }
}
