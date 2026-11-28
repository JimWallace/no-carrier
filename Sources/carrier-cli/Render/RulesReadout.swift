import CarrierCore
import CarrierTerminal

/// A composed RuleSet as `carrier rules` prints it, in 40 columns.
enum RulesReadout {
    static func lines(
        _ rules: RuleSet, layers: [RuleLayer], objective: ObjectiveDefinition, ascension: Int, content: ContentPack
    ) -> [String] {
        var lines = [
            "RULES  OBJECTIVE \(objective.name)",
            "ASCENSION \(ascension)",
            "",
            row("FLAG", "", "CATEGORY", "SET BY"),
        ]
        for flag in MechanicFlag.allCases {
            let category = content.flags.first { $0.flag == flag }?.category.rawValue.uppercased() ?? "?"
            let source = RuleSet.source(of: flag, in: layers)?.label ?? "-"
            lines.append(row(flag.rawValue.uppercased(), rules.isOn(flag) ? "ON" : "OFF", category, source))
        }
        lines += ["", "CONTRACT LAYER"]
        lines += Columns.wrap("START ALERT \(rules.isOn(.alert) ? "\(objective.startAlert)" : "OFF")", indent: " ")
        lines += Columns.wrap("FOG \(rules.fog(for: objective).rawValue.uppercased())", indent: " ")
        if let target = objective.target, rules.isOn(.transfer) {
            lines += Columns.wrap(
                "TARGET \(target.nodeType.label), \(target.fileMB.min)-\(target.fileMB.max) MB,"
                    + " \(target.minDistance)+ HOPS",
                indent: " ")
        }
        if rules.isOn(.objectiveLoot) && !objective.extraRewards.isEmpty {
            let names = objective.extraRewards.map { content.card($0)?.name ?? $0 }
            lines += Columns.wrap("EXTRA LOOT " + names.joined(separator: ", "), indent: " ")
        }
        let tuning = rules.tuning
        lines += ["", "TUNING"]
        lines += Columns.wrap(
            "RIG CYC \(tuning.rig.cycles) RAM \(tuning.rig.ram) STORAGE \(tuning.rig.storage)"
                + " BW \(tuning.rig.bandwidth) INT \(tuning.rig.integrity)",
            indent: " ")
        lines += Columns.wrap("TRACE MAX \(tuning.trace.max) LOGOUT \(tuning.trace.logout)", indent: " ")
        lines += Columns.wrap(
            "WEAK \(tuning.weakPercent)% RESIST \(tuning.resistPercent)%", indent: " ")
        lines += Columns.wrap("NO LAYER CHANGES TUNING YET. --JSON PRINTS EVERY NUMBER.", indent: " ")
        lines += ["", "FLAGS"]
        for definition in content.flags {
            var text = definition.name.uppercased() + ": " + definition.description.uppercased()
            if !definition.requires.isEmpty {
                text += " REQUIRES " + definition.requires.map { $0.uppercased() }.joined(separator: ", ") + "."
            }
            lines += Columns.wrap(text, indent: " ")
        }
        return lines
    }

    /// How recorded rules differ from this build's defaults: the flags,
    /// then the tuning. Empty when they are the same.
    static func replayNotes(_ recorded: RuleSet, defaults: RuleSet) -> [String] {
        var notes: [String] = []
        let flags = changedFlags(recorded, from: defaults)
        if !flags.isEmpty { notes.append("RECORDED WITH OTHER FLAGS: \(flags). REPLAYING THEM.") }
        if recorded.tuning != defaults.tuning { notes.append("RECORDED WITH OTHER TUNING. REPLAYING IT.") }
        return notes
    }

    /// The flags that differ from `defaults`, as `NAME=ON`, or empty.
    static func changedFlags(_ rules: RuleSet, from defaults: RuleSet) -> String {
        MechanicFlag.allCases.filter { rules.isOn($0) != defaults.isOn($0) }
            .map { "\($0.rawValue.uppercased())=\(rules.isOn($0) ? "ON" : "OFF")" }
            .joined(separator: " ")
    }

    /// Flag, value, category and layer in columns 14, 4, 11 and 9 wide.
    private static func row(_ flag: String, _ value: String, _ category: String, _ source: String) -> String {
        pad(flag, 14) + pad(value, 4) + pad(category, 11) + String(source.prefix(9))
    }

    private static func pad(_ text: String, _ width: Int) -> String {
        let short = String(text.prefix(width - 1))
        return short + String(repeating: " ", count: width - short.count)
    }
}
