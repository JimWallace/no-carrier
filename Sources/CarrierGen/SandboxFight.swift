public import CarrierCore

/// The `carrier fight` sandbox (M2): one generated machine against the
/// starter deck and the starting rig. `fight`, `replay` and the golden
/// transcripts all build their setup here, so they cannot drift apart.
public enum SandboxFight {
    /// `payload` PAYLOAD cards join the starter deck. Nil means the tuning
    /// default: `sandbox.payloadVersusKernel` against a machine with a KERNEL
    /// layer, none otherwise.
    public static func setup(
        seed: UInt64, role: NodeRole, payload: Int? = nil, content: ContentPack
    ) throws(GenerationError) -> FightSetup {
        let machine = try MachineGenerator(content: content)
            .generate(seed: Seed.derive(seed, "machine"), role: role)
        let rig = Rig(tuning: content.tuning.rig)
        let hasKernel = machine.layers.contains { $0.kind == .kernel }
        let payloadCount = payload ?? (hasKernel ? content.tuning.sandbox.payloadVersusKernel : 0)
        return FightSetup(
            seed: seed,
            machine: machine,
            deck: content.tuning.starterDeck
                + Array(repeating: content.tuning.sandbox.payloadCard, count: max(0, payloadCount)),
            rig: rig,
            integrity: rig.maxIntegrity,
            trace: 0
        )
    }
}
