/// A file copy in a TARGET fight (addendum 01, §3.2). It starts once every
/// security layer is breached, then moves `rateMB` at the start of each
/// turn. The ICE grows stronger each turn it runs.
public struct TransferProgress: Codable, Sendable, Equatable {
    public var totalMB: Int
    public var doneMB: Int
    public var rateMB: Int
    public var started: Bool
    /// Turns the transfer has run, which sets the ICE escalation.
    public var turnsRunning: Int

    public init(totalMB: Int, rateMB: Int) {
        self.totalMB = totalMB
        doneMB = 0
        self.rateMB = rateMB
        started = false
        turnsRunning = 0
    }

    public var isComplete: Bool { doneMB >= totalMB }
}
