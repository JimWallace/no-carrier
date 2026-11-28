/// Noise and Alert (addendum 01, §2.1).
public struct AlertTuning: Codable, Sendable, Equatable {
    /// Alert at or above this is SUSPICIOUS.
    public var suspicious: Int
    /// Alert at or above this is ACTIVE. ACTIVE then stays for the contract.
    public var active: Int
    public var max: Int
    /// Trace drift per tick in each state.
    public var dormantDrift: Int
    public var suspiciousDrift: Int
    public var activeDrift: Int
    /// Alert lost per quiet tick below ACTIVE.
    public var decay: Int
    /// Alert from capturing a node, gaining access, and a network SCAN.
    public var capture: Int
    public var access: Int
    public var scan: Int
}
