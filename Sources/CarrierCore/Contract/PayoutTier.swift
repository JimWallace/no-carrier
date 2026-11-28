/// How well a stealth contract paid, by the Alert state at JACK OUT
/// (addendum 01, §3.2). Cash arrives with runs (M8); until then the tier is
/// reported.
public enum PayoutTier: String, Codable, Sendable, CaseIterable {
    /// DORMANT: full pay and the clean bonus.
    case clean
    /// SUSPICIOUS: full pay.
    case full
    /// ACTIVE: half pay, and the job leaves logs.
    case half

    public var label: String {
        switch self {
        case .clean: "CLEAN (FULL PAY + BONUS)"
        case .full: "FULL PAY"
        case .half: "HALF PAY, LOGS LEFT"
        }
    }

    public static func at(_ alert: AlertState) -> Self {
        switch alert {
        case .dormant: .clean
        case .suspicious: .full
        case .active: .half
        }
    }
}
