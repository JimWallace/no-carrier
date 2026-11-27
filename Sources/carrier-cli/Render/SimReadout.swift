import CarrierCore
import CarrierSim

/// A simulation report as `carrier sim` prints it, in 40 columns.
enum SimReadout {
    static func lines(_ report: SimulationReport, content: ContentPack) -> [String] {
        var lines = [
            "SIM \(report.runs) RUNS  BOT \(report.bot.uppercased())",
            "SEED \(Seed.display(report.seed))",
            "",
        ]
        for ending in SimulationReport.Ending.allCases {
            let count = report.count(ending)
            lines.append(row(label(ending), "\(count)", percent(count, of: report.runs)))
        }
        lines += [
            "",
            "AVG TRACE AT END  " + tenths(report.averageTenths(report.totalTraceAtEnd)),
            "AVG TICKS         " + tenths(report.averageTenths(report.totalTicks)),
            "AVG FIGHTS        " + tenths(report.averageTenths(report.fights)),
            "AVG LOGOUTS       " + tenths(report.averageTenths(report.logouts)),
            "ROOT ATTEMPTS     \(report.rootAttempts)",
            "RUNS LOST AT ROOT \(report.endedAtRoot)",
            "",
            "CAPTURES PER RUN BY NODE TYPE",
        ]
        for (index, type) in NodeType.allCases.enumerated() where type != .entry {
            lines.append(row(type.label, tenths(report.averageTenths(report.capturesByType[index])), ""))
        }
        lines += ["", "LOOT TAKEN/OFFERED"]
        let order = report.rewardPool.indices.sorted { lhs, rhs in
            let left = SimulationReport.perMille(report.taken[lhs], of: report.offered[lhs])
            let right = SimulationReport.perMille(report.taken[rhs], of: report.offered[rhs])
            return left == right ? lhs < rhs : left > right
        }
        for index in order {
            let name = content.card(report.rewardPool[index])?.name ?? report.rewardPool[index]
            lines.append(
                row(
                    name, "\(report.taken[index])/\(report.offered[index])",
                    percent(report.taken[index], of: report.offered[index])))
        }
        lines += ["", "DATA UPGRADES"]
        for (index, upgrade) in report.upgrades.enumerated() {
            lines.append(row(upgrade.label, "\(report.upgradePicks[index])", ""))
        }
        return lines
    }

    private static func label(_ ending: SimulationReport.Ending) -> String {
        switch ending {
        case .won: "WON"
        case .flatlined: "FLATLINED"
        case .traced: "TRACED"
        case .entryLost: "ENTRY LOST"
        case .stalled: "STALLED"
        }
    }

    /// Label, value and percent in columns: 22, 9 and 7 wide.
    private static func row(_ label: String, _ value: String, _ percent: String) -> String {
        let short = String(label.prefix(21))
        let left = short + String(repeating: " ", count: 22 - short.count)
        let middle = String(repeating: " ", count: max(0, 9 - value.count)) + value
        let right = String(repeating: " ", count: max(0, 7 - percent.count)) + percent
        return left + middle + right
    }

    private static func percent(_ part: Int, of whole: Int) -> String {
        guard whole > 0 else { return "-" }
        return tenths(SimulationReport.perMille(part, of: whole)) + "%"
    }

    private static func tenths(_ value: Int) -> String {
        "\(value / 10).\(value % 10)"
    }
}
