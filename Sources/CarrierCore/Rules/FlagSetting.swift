/// One flag set to on or off by a rule layer.
public struct FlagSetting: Codable, Sendable, Equatable {
    public var flag: MechanicFlag
    public var isOn: Bool

    public init(_ flag: MechanicFlag, _ isOn: Bool) {
        self.flag = flag
        self.isOn = isOn
    }

    /// Reads `name=on` or `name=off`, as `--flag` takes it. Nil when the
    /// text is not one of those forms or names no flag.
    public static func parse(_ text: String) -> Self? {
        let parts = text.split(separator: "=", omittingEmptySubsequences: false)
        guard parts.count == 2, let flag = MechanicFlag.named(String(parts[0])) else { return nil }
        switch parts[1].lowercased() {
        case "on": return Self(flag, true)
        case "off": return Self(flag, false)
        default: return nil
        }
    }
}

extension MechanicFlag {
    /// The flag with this name, ignoring case.
    public static func named(_ name: String) -> Self? {
        allCases.first { $0.rawValue.lowercased() == name.lowercased() }
    }
}
