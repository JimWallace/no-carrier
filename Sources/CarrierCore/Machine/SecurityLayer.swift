/// One security layer of a machine, with its current and starting HP.
public struct SecurityLayer: Codable, Sendable, Equatable {
    public var kind: LayerKind
    public var hp: Int
    /// HP at the start of the fight, plus any HARDEN; the bar's full width.
    public var maxHP: Int

    public init(kind: LayerKind, hp: Int) {
        self.kind = kind
        self.hp = hp
        maxHP = hp
    }

    public var isBreached: Bool { hp <= 0 }
}
