/// Every flag's value. Kept in an array in `MechanicFlag.allCases` order, so that
/// no dictionary order can reach a rule or a replay file.
public struct FlagSet: Sendable, Equatable {
    private var values: [Bool]

    /// Every flag off.
    public init() {
        values = Array(repeating: false, count: MechanicFlag.allCases.count)
    }

    public subscript(flag: MechanicFlag) -> Bool {
        get { index(flag).map { values[$0] } ?? false }
        set {
            if let index = index(flag) { values[index] = newValue }
        }
    }

    /// The flags that are on, in `MechanicFlag.allCases` order.
    public var on: [MechanicFlag] {
        MechanicFlag.allCases.filter { self[$0] }
    }

    public mutating func apply(_ setting: FlagSetting) {
        self[setting.flag] = setting.isOn
    }

    private func index(_ flag: MechanicFlag) -> Int? {
        MechanicFlag.allCases.firstIndex(of: flag)
    }
}

extension FlagSet: Codable {
    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            nil
        }
    }

    /// A JSON object of every flag, `"name": true|false`. A flag the file
    /// does not name is off; a name this build does not know is an error.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        self.init()
        for key in container.allKeys {
            guard let flag = MechanicFlag(rawValue: key.stringValue) else {
                throw DecodingError.dataCorruptedError(
                    forKey: key, in: container, debugDescription: "no flag \"\(key.stringValue)\" in this build")
            }
            self[flag] = try container.decode(Bool.self, forKey: key)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        for flag in MechanicFlag.allCases {
            try container.encode(self[flag], forKey: Key(stringValue: flag.rawValue))
        }
    }
}
