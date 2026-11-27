/// One running ICE program and how far through its pattern it is.
public struct ICEInstance: Codable, Sendable, Equatable {
    public let iceID: String
    /// The index of the next pattern step, before wrapping.
    public var step: Int
    /// A boss that has switched to its `phaseTwo` pattern.
    public var inPhaseTwo: Bool

    public init(iceID: String, step: Int = 0, inPhaseTwo: Bool = false) {
        self.iceID = iceID
        self.step = step
        self.inPhaseTwo = inPhaseTwo
    }
}
