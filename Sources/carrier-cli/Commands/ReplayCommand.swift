import ArgumentParser
import CarrierCore
import CarrierGen
import CarrierTerminal
import Foundation

/// `carrier replay <file>`: plays a recorded fight or contract again and
/// prints its log, so a playtest bug can be reproduced (kickoff §8,
/// "Replays").
struct ReplayCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "replay",
        abstract: "Play a recorded fight or contract again and print its log."
    )

    @Argument(help: "A replay file written by carrier fight --record or carrier play --record.")
    var file: String

    @OptionGroup var contentOptions: ContentOptions

    @Flag(name: .long, help: "Print a whole frame after every action.")
    var frames = false

    func run() throws {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: file))
        } catch {
            throw ValidationError("\(file): cannot read it (\(error.localizedDescription))")
        }
        if let probe = try? JSONDecoder().decode(ReplayKind.self, from: data), probe.kind == ContractReplay.kindName {
            try replayContract(data)
            return
        }
        let replay: FightReplay
        do {
            replay = try JSONDecoder().decode(FightReplay.self, from: data)
        } catch {
            throw ValidationError("\(file): not a replay file (\(error))")
        }
        guard replay.format == FightReplay.currentFormat else {
            throw ValidationError(
                "\(file): replay format \(replay.format); this build reads \(FightReplay.currentFormat)")
        }
        let content = try contentOptions.load()
        let style = Phosphor.forStandardOutput()
        var notes: [String] = []
        if replay.carrierVersion != CarrierVersion.current {
            notes.append("RECORDED BY \(replay.carrierVersion), THIS IS \(CarrierVersion.current). IT MAY DIVERGE.")
        }
        let setup = try SandboxFight.setup(
            seed: replay.seed, role: replay.role, payload: replay.payload, content: content)
        // A replay from before rule sets ran under the base rules.
        let rules = replay.rules ?? RuleSet.defaults(content: content, objective: nil)
        notes += RulesReadout.replayNotes(rules, defaults: RuleSet.defaults(content: content, objective: nil))
        var session = FightSession(
            engine: Engine(content: content), setup: setup, rules: rules,
            replay: FightReplay(
                carrierVersion: CarrierVersion.current, seed: replay.seed, role: replay.role, payload: replay.payload,
                rules: rules),
            recordURL: nil
        )
        for action in replay.actions {
            try session.perform(action)
            if frames {
                Output.write(
                    style.screen(FightScreen(session: session, style: style).lines(prompt: nil, hint: "")) + "\n")
            }
        }
        if !frames {
            let final = FightScreen(session: session, style: style).lines(prompt: nil, hint: "")
            Output.write(style.screen(notes + session.log + [""] + final) + "\n")
        } else if !notes.isEmpty {
            Output.write(style.screen(notes) + "\n")
        }
        Output.write(
            style.screen([
                "\(replay.actions.count) ACTIONS. OUTCOME: \(session.fight.outcome?.rawValue.uppercased() ?? "NONE")"
            ]) + "\n")
    }

    private func replayContract(_ data: Data) throws {
        let replay: ContractReplay
        do {
            replay = try JSONDecoder().decode(ContractReplay.self, from: data)
        } catch {
            throw ValidationError("\(file): not a contract replay (\(error))")
        }
        guard replay.format == ContractReplay.currentFormat else {
            throw ValidationError(
                "\(file): replay format \(replay.format); this build reads \(ContractReplay.currentFormat)")
        }
        let content = try contentOptions.load()
        let style = Phosphor.forStandardOutput()
        let network = try NetworkGenerator(content: content).generate(seed: replay.seed)
        let objective = try ObjectiveOption.find(replay.objective, in: content)
        // A replay from before rule sets ran under the objective's defaults.
        let defaults = RuleSet.defaults(content: content, objective: objective)
        let rules = replay.rules ?? defaults
        var session = PlaySession(
            engine: ContractEngine(content: content), seed: replay.seed, network: network, objective: objective,
            rules: rules, recordURL: nil)
        if replay.carrierVersion != CarrierVersion.current {
            session.note("RECORDED BY \(replay.carrierVersion), THIS IS \(CarrierVersion.current). IT MAY DIVERGE.")
        }
        for note in RulesReadout.replayNotes(rules, defaults: defaults) {
            session.note(note)
        }
        for action in replay.actions {
            try session.perform(action)
            if frames {
                Output.write(style.screen(session.screen(style: style, rows: 24, prompt: nil, hint: "")) + "\n")
            }
        }
        if !frames {
            Output.write(style.screen(session.log) + "\n")
        }
        Output.write(style.screen(session.banner + ["\(replay.actions.count) ACTIONS."]) + "\n")
    }
}

/// Reads only the `kind` field, to tell a contract replay from a fight one.
private struct ReplayKind: Decodable {
    let kind: String?
}
