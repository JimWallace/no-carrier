package import CarrierCore

/// A generated machine as `carrier gen` prints it.
package enum MachineReadout {
    package static func lines(for machine: Machine, content: ContentPack) -> [String] {
        var lines: [String] = []
        lines += Columns.wrap("\(machine.osName) \(machine.osVersion) // \(machine.orgName)")
        lines += Columns.wrap(machine.hostname)
        lines += Columns.wrap("\(machine.cpu.name)  \(machine.ramMB)MB  \(machine.modem.name)")
        let iceNames = machine.ice.map { content.iceDefinition($0)?.name ?? $0 }
        lines += Columns.wrap("\(machine.role.label) \(machine.orgKind)  ICE: \(iceNames.joined(separator: ", "))")
        lines += Columns.wrap(machine.layers.map { "\($0.kind.label) \($0.hp)" }.joined(separator: "  "))
        lines += Columns.wrap("WEAK: \(tags(machine.weak))  RESIST: \(tags(machine.resist))")
        lines.append(">DIR")
        for path in machine.filesystem {
            lines += Columns.wrap(path, indent: "  ")
        }
        return lines
    }

    package static func tags(_ tags: [ExploitTag]) -> String {
        tags.isEmpty ? "-" : tags.map(\.label).joined(separator: ", ")
    }
}
