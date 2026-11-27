import CarrierCore
import CarrierGen
import Foundation
import TestSupport
import Testing

@Suite struct MachineGeneratorTests {
    @Test(arguments: NodeRole.allCases)
    func sameSeedSameMachine(role: NodeRole) throws {
        let generator = MachineGenerator(content: try BundledContent.load())
        let first = try generator.generate(seed: 1994, role: role)
        let second = try generator.generate(seed: 1994, role: role)
        #expect(first == second)
    }

    @Test func differentSeedsDiffer() throws {
        let generator = MachineGenerator(content: try BundledContent.load())
        let machines = try (0..<20).map { try generator.generate(seed: UInt64($0), role: .neutral) }
        #expect(Set(machines.map(\.hostname)).count > 10)
    }

    @Test func neutralMachinesHaveNoKernel() throws {
        let generator = MachineGenerator(content: try BundledContent.load())
        for seed in 0..<50 {
            let machine = try generator.generate(seed: UInt64(seed), role: .neutral)
            #expect(machine.layers.map(\.kind) == [.firewall, .auth])
        }
    }

    @Test func sysopMachinesHaveAKernel() throws {
        let generator = MachineGenerator(content: try BundledContent.load())
        for seed in 0..<50 {
            let machine = try generator.generate(seed: UInt64(seed), role: .sysop)
            #expect(machine.layers.map(\.kind) == [.firewall, .auth, .kernel])
        }
    }

    /// Kickoff §4: ROOT is FIREWALL 30, AUTH 30, KERNEL 24, on OpenVAULT.
    @Test func rootMatchesTheBrief() throws {
        let generator = MachineGenerator(content: try BundledContent.load())
        let machine = try generator.generate(seed: 3, role: .root)
        #expect(machine.layers.map(\.hp) == [30, 30, 24])
        #expect(machine.osName == "OPENVAULT")
        #expect(machine.weak == [.social])
        #expect(machine.resist == [.overflow, .privesc])
    }

    /// Kickoff §6: 1 + RAM / 24 ICE programs, at most 3.
    @Test func iceCountFollowsRAM() throws {
        let generator = MachineGenerator(content: try BundledContent.load())
        for seed in 0..<100 {
            for role in NodeRole.allCases {
                let machine = try generator.generate(seed: UInt64(seed), role: role)
                #expect(machine.ice.count == min(3, 1 + machine.ramMB / 24))
            }
        }
    }

    @Test func layerHPStaysInRange() throws {
        let content = try BundledContent.load()
        let generator = MachineGenerator(content: content)
        for seed in 0..<100 {
            let machine = try generator.generate(seed: UInt64(seed), role: .sysop)
            let bonus = machine.ramMB / content.tuning.ice.ramPerLayerHP
            let roleTuning = content.tuning.roles.sysop
            #expect((roleTuning.firewall.min + bonus...roleTuning.firewall.max + bonus).contains(machine.layers[0].hp))
        }
    }

    @Test func filesystemHoldsTheFixedPathsAndHomes() throws {
        let content = try BundledContent.load()
        let generator = MachineGenerator(content: content)
        let machine = try generator.generate(seed: 12, role: .neutral)
        let family = try #require(content.osFamily(machine.osFamilyID))
        #expect(Array(machine.filesystem.prefix(family.filesystem.fixed.count)) == family.filesystem.fixed)
        #expect((2...4).contains(machine.users.count))
    }

    @Test func dosNamesAreEightDotThree() {
        #expect(FilesystemGenerator.dosName("thesis_final.tex") == "THESIS~1.TEX")
        #expect(FilesystemGenerator.dosName("ledger.dat") == "LEDGER.DAT")
        #expect(FilesystemGenerator.dosName("newsfeeds") == "NEWSFE~1")
    }

    /// The procgen snapshot: a change to the generator, the PRNG or the
    /// content changes these machines, and the change must be deliberate.
    @Test func machinesMatchTheSnapshot() throws {
        let generator = MachineGenerator(content: try BundledContent.load())
        var machines: [Machine] = []
        for (index, role) in NodeRole.allCases.enumerated() {
            machines.append(try generator.generate(seed: Seed.derive(1994, "snapshot/\(index)"), role: role))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let text = try #require(String(bytes: try encoder.encode(machines), encoding: .utf8))
        let outcome = try Snapshot.compare(text, named: "machines")
        #expect(outcome == .matches, "\(outcome.message)")
    }
}
