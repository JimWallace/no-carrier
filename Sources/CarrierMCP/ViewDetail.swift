/// How much of the view a tool returns.
package enum ViewDetail: String, Sendable {
    /// Everything: the screen, the status, the map, the hand with rules
    /// text, the deck and the legal actions.
    case full
    /// The screen and the legal actions only, to keep a long session short.
    case compact
    /// No view.
    case none
}
