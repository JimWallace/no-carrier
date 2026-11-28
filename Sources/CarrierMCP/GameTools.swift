package import CarrierCore
import CarrierGen
import CarrierTerminal
import Foundation

/// The game tools and the games they run. Games live in memory, keyed by an
/// id (`g1`, `g2`, ...) given in order, so a scripted session gets the same
/// ids every time.
package struct GameTools {
    private enum Game {
        case contract(ContractGame)
        case fight(FightGame)
    }

    package let content: ContentPack
    private let newSeed: () -> UInt64
    private var games: [String: Game] = [:]
    /// The ids in the order the games started.
    private var order: [String] = []
    private var nextNumber = 1

    package init(content: ContentPack, newSeed: @escaping () -> UInt64) {
        self.content = content
        self.newSeed = newSeed
    }

    package mutating func call(_ name: String, arguments: [String: JSONValue]) -> ToolResult {
        switch name {
        case "new_contract": newContract(arguments)
        case "new_fight": newFight(arguments)
        case "view": view(arguments)
        case "act": act(arguments)
        case "log": log(arguments)
        case "save_replay": saveReplay(arguments)
        case "list_games": .ok(["games": .array(order.compactMap(summary))])
        case "end_game": endGame(arguments)
        default: .error("unknown tool: \(name)")
        }
    }

    // MARK: - Starting a game

    private mutating func newContract(_ arguments: [String: JSONValue]) -> ToolResult {
        let objective: ObjectiveDefinition
        if let id = arguments["objective"]?.stringValue {
            guard let found = content.objective(id.lowercased()) else {
                return .error(
                    "objective \"\(id)\" is not one of \(content.objectives.map(\.id).joined(separator: ", "))")
            }
            objective = found
        } else {
            guard let first = content.defaultObjective else { return .error("the content has no objectives") }
            objective = first
        }
        let seed: UInt64
        switch Self.seed(arguments["seed"]) {
        case .success(let value): seed = value ?? newSeed()
        case .failure(let failure): return failure.result
        }
        let game: ContractGame
        do {
            game = try ContractGame(seed: seed, objective: objective, content: content)
        } catch {
            return .error("cannot generate the network: \(error)")
        }
        let id = add(.contract(game))
        return started(id, seed: seed, view: game.view(Self.detail(arguments["view"], default: .full)))
    }

    private mutating func newFight(_ arguments: [String: JSONValue]) -> ToolResult {
        let roleName = arguments["role"]?.stringValue ?? "neutral"
        guard let role = NodeRole(rawValue: roleName.lowercased()) else {
            return .error("role \"\(roleName)\" is not neutral, sysop or root")
        }
        var payload: Int?
        if let value = arguments["payload"], value != .null {
            guard let count = value.intValue, (0...99).contains(count) else {
                return .error("payload must be a whole number from 0 to 99")
            }
            payload = count
        }
        let seed: UInt64
        switch Self.seed(arguments["seed"]) {
        case .success(let value): seed = value ?? newSeed()
        case .failure(let failure): return failure.result
        }
        let game: FightGame
        do {
            game = try FightGame(seed: seed, role: role, payload: payload, content: content)
        } catch {
            return .error("cannot generate the machine: \(error)")
        }
        let id = add(.fight(game))
        return started(id, seed: seed, view: game.view(Self.detail(arguments["view"], default: .full)))
    }

    private mutating func add(_ game: Game) -> String {
        let id = "g\(nextNumber)"
        nextNumber += 1
        games[id] = game
        order.append(id)
        return id
    }

    private func started(_ id: String, seed: UInt64, view: JSONValue) -> ToolResult {
        .ok(["game_id": .string(id), "seed": .string(Seed.display(seed)), "view": view])
    }

    // MARK: - Playing

    private func view(_ arguments: [String: JSONValue]) -> ToolResult {
        switch game(arguments) {
        case .failure(let failure): return failure.result
        case .success(let (id, game)):
            let detail = Self.detail(arguments["detail"], default: .full)
            return .ok(["game_id": .string(id), "view": Self.view(of: game, detail)])
        }
    }

    private mutating func act(_ arguments: [String: JSONValue]) -> ToolResult {
        let found: (String, Game)
        switch game(arguments) {
        case .failure(let failure): return failure.result
        case .success(let value): found = value
        }
        guard let input = arguments["action"]?.stringValue else {
            return .error("act needs an action: an id from legal_actions, or a typed command")
        }
        let (id, game) = found
        let outcome: ActOutcome
        let next: Game
        switch game {
        case .contract(var contract):
            outcome = contract.act(input)
            next = .contract(contract)
        case .fight(var fight):
            outcome = fight.act(input)
            next = .fight(fight)
        }
        games[id] = next
        var fields: [String: JSONValue] = [
            "game_id": .string(id),
            "status": .string(outcome.status.rawValue),
            "lines": .strings(outcome.lines),
        ]
        let detail = Self.detail(arguments["view"], default: .compact)
        if detail != .none { fields["view"] = Self.view(of: next, detail) }
        return ToolResult(value: .object(fields), isError: outcome.status == .rejected)
    }

    private func log(_ arguments: [String: JSONValue]) -> ToolResult {
        switch game(arguments) {
        case .failure(let failure): return failure.result
        case .success(let (id, game)):
            let lines: [String]
            switch game {
            case .contract(let contract): lines = contract.session.log
            case .fight(let fight): lines = fight.session.log
            }
            let last = max(0, arguments["last"]?.intValue ?? 40)
            return .ok(["game_id": .string(id), "total": .int(lines.count), "lines": .strings(lines.suffix(last))])
        }
    }

    private func saveReplay(_ arguments: [String: JSONValue]) -> ToolResult {
        switch game(arguments) {
        case .failure(let failure): return failure.result
        case .success(let (id, game)):
            let data: Data
            let name: String
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            do {
                switch game {
                case .contract(let contract):
                    let replay = contract.session.replay
                    data = try encoder.encode(replay)
                    name = "contract-\(replay.objective ?? "takeover")-\(Seed.display(replay.seed)).json"
                case .fight(let fight):
                    let replay = fight.session.replay
                    data = try encoder.encode(replay)
                    name = "fight-\(replay.role.rawValue)-\(Seed.display(replay.seed)).json"
                }
            } catch {
                return .error("cannot encode the replay: \(error)")
            }
            let url = URL(fileURLWithPath: arguments["path"]?.stringValue ?? name)
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url)
            } catch {
                return .error("cannot write \(url.path): \(error.localizedDescription)")
            }
            return .ok([
                "game_id": .string(id),
                "path": .string(url.path),
                "replay_command": .string("carrier replay \(url.path)"),
            ])
        }
    }

    private mutating func endGame(_ arguments: [String: JSONValue]) -> ToolResult {
        switch game(arguments) {
        case .failure(let failure): return failure.result
        case .success(let (id, _)):
            games[id] = nil
            order.removeAll { $0 == id }
            return .ok(["game_id": .string(id), "ended": true])
        }
    }

    /// The rule state of a contract, for tests that compare the server with
    /// the engine. No tool returns it: it holds what the fog hides.
    package func contractState(_ id: String) -> ContractState? {
        if case .contract(let contract)? = games[id] { return contract.state }
        return nil
    }

    /// The rule state of a sandbox fight, for tests.
    package func fightState(_ id: String) -> GameState? {
        if case .fight(let fight)? = games[id] { return fight.session.state }
        return nil
    }

    // MARK: - Helpers

    private func game(_ arguments: [String: JSONValue]) -> Result<(String, Game), ToolFailure> {
        guard let id = arguments["game_id"]?.stringValue else { return .failure(ToolFailure("game_id is missing")) }
        guard let game = games[id] else {
            let known = order.isEmpty ? "none" : order.joined(separator: ", ")
            return .failure(ToolFailure("no game \(id). Games: \(known)"))
        }
        return .success((id, game))
    }

    private func summary(_ id: String) -> JSONValue? {
        guard let game = games[id] else { return nil }
        switch game {
        case .contract(let contract):
            return [
                "game_id": .string(id), "kind": "contract",
                "objective": .string(contract.state.objective.id),
                "seed": .string(Seed.display(contract.state.seed)),
                "phase": .string(contract.phaseName),
                "actions": .int(contract.session.replay.actions.count),
            ]
        case .fight(let fight):
            return [
                "game_id": .string(id), "kind": "fight",
                "role": .string(fight.session.replay.role.rawValue),
                "seed": .string(Seed.display(fight.session.replay.seed)),
                "phase": .string(fight.session.fight.isOver ? "over" : "fight"),
                "actions": .int(fight.session.replay.actions.count),
            ]
        }
    }

    private static func view(of game: Game, _ detail: ViewDetail) -> JSONValue {
        switch game {
        case .contract(let contract): contract.view(detail)
        case .fight(let fight): fight.view(detail)
        }
    }

    private static func detail(_ value: JSONValue?, default fallback: ViewDetail) -> ViewDetail {
        value?.stringValue.flatMap { ViewDetail(rawValue: $0.lowercased()) } ?? fallback
    }

    /// A seed as a decimal or `0x` hex string, or a JSON integer. Nil when
    /// none was given.
    private static func seed(_ value: JSONValue?) -> Result<UInt64?, ToolFailure> {
        switch value {
        case nil, .null: return .success(nil)
        case .string(let text):
            guard let seed = Seed.parse(text) else {
                return .failure(ToolFailure("seed \"\(text)\" is not decimal or 0x hex"))
            }
            return .success(seed)
        case .int(let number) where number >= 0:
            return .success(UInt64(number))
        default:
            return .failure(ToolFailure("seed must be a string (decimal or 0x hex) or a whole number"))
        }
    }
}

/// A tool call that failed before it reached a game.
struct ToolFailure: Error {
    let result: ToolResult
    init(_ message: String) { result = .error(message) }
}
