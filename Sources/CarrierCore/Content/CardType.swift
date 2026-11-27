/// What a card is. The type decides the zone it goes to when played and
/// whether exploit modifiers (weakness, KEYLOGGER) apply to its damage.
public enum CardType: String, Codable, Sendable {
    case exploit
    case proxy
    case script
    case daemon
    case payload
    case malware

    public var label: String { rawValue.uppercased() }
}
