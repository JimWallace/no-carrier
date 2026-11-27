/// One running ICE program and how far through its pattern it is.
public struct ICEInstance: Codable, Sendable, Equatable {
    public let iceID: String
    /// The index of the next pattern step, before wrapping.
    public var step: Int

    public init(iceID: String, step: Int = 0) {
        self.iceID = iceID
        self.step = step
    }
}
