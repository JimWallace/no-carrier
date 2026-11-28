import CarrierCore
import CarrierSim

/// `carrier sim --compare` as it prints: the same seeds with a flag on and
/// off, side by side, in 40 columns.
enum ComparisonReadout {
    static func lines(_ comparison: FlagComparison) -> [String] {
        let on = comparison.on
        let off = comparison.off
        var lines = [
            "COMPARE \(comparison.flag.rawValue.uppercased())  \(on.runs) RUNS",
            "BOT \(on.bot.uppercased())  OBJECTIVE \(on.objective.uppercased())",
            "SEED \(Seed.display(on.seed))",
            "",
            row("", "ON", "OFF", "DIFF"),
        ]
        for ending in SimulationReport.Ending.allCases {
            lines.append(count(label(ending), on.count(ending), off.count(ending)))
        }
        lines.append("")
        lines.append(average("AVG TRACE", on.averageTenths(on.totalTraceAtEnd), off.averageTenths(off.totalTraceAtEnd)))
        lines.append(average("AVG TICKS", on.averageTenths(on.totalTicks), off.averageTenths(off.totalTicks)))
        lines.append(average("AVG FIGHTS", on.averageTenths(on.fights), off.averageTenths(off.fights)))
        lines.append(average("AVG LOGOUTS", on.averageTenths(on.logouts), off.averageTenths(off.logouts)))
        lines.append(count("ROOT ATTEMPTS", on.rootAttempts, off.rootAttempts))
        lines.append(count("LOST AT ROOT", on.endedAtRoot, off.endedAtRoot))
        lines += ["", "HIGHEST ALERT STATE"]
        for (index, alert) in AlertState.allCases.enumerated() {
            lines.append(count(alert.label, on.highestAlert[index], off.highestAlert[index]))
        }
        if on.payouts.contains(where: { $0 > 0 }) || off.payouts.contains(where: { $0 > 0 }) {
            lines += ["", "PAYOUTS"]
            for (index, tier) in PayoutTier.allCases.enumerated() {
                lines.append(count(tier.rawValue.uppercased(), on.payouts[index], off.payouts[index]))
            }
        }
        lines += ["", "CAPTURES PER RUN BY NODE TYPE"]
        for (index, type) in NodeType.allCases.enumerated() where type != .entry {
            lines.append(
                average(
                    type.label, on.averageTenths(on.capturesByType[index]), off.averageTenths(off.capturesByType[index])
                ))
        }
        return lines
    }

    private static func label(_ ending: SimulationReport.Ending) -> String {
        switch ending {
        case .won: "WON"
        case .flatlined: "FLATLINED"
        case .traced: "TRACED"
        case .entryLost: "ENTRY LOST"
        case .jackedOut: "JACKED OUT"
        case .stalled: "STALLED"
        }
    }

    private static func count(_ label: String, _ on: Int, _ off: Int) -> String {
        row(label, "\(on)", "\(off)", signed(on - off))
    }

    /// Averages in tenths.
    private static func average(_ label: String, _ on: Int, _ off: Int) -> String {
        row(label, tenths(on), tenths(off), signedTenths(on - off))
    }

    /// Label and three values in columns 14, 8, 8 and 8 wide.
    private static func row(_ label: String, _ on: String, _ off: String, _ diff: String) -> String {
        let short = String(label.prefix(13))
        return short + String(repeating: " ", count: 14 - short.count) + right(on) + right(off) + right(diff)
    }

    private static func right(_ text: String) -> String {
        String(repeating: " ", count: max(0, 8 - text.count)) + text
    }

    private static func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private static func tenths(_ value: Int) -> String {
        "\(value / 10).\(value % 10)"
    }

    private static func signedTenths(_ value: Int) -> String {
        let magnitude = value < 0 ? -value : value
        let sign = value > 0 ? "+" : value < 0 ? "-" : ""
        return sign + tenths(magnitude)
    }
}
