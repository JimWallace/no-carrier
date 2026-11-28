import CarrierContent
import CarrierCore
import Foundation
import SwiftGodot

/// The root of `main.tscn`. It loads the content from the project, starts a
/// contract, and draws the screen for the contract's phase: the map, or a
/// battle, with the choice screens over them. Each action redraws the whole
/// screen from the state; the screens hold no state of their own.
///
/// Command-line options after `--` (for testing and screenshots):
/// `--seed N`, `--actions attack:1,play:0,end`, `--click X,Y` (repeatable;
/// a mouse click through Godot's input, to test the wiring) and
/// `--screenshot out.png` (saves the window after the clicks, then quits)
/// and `--quit` (quits after the first frame, for a headless check).
@Godot
final class NoCarrierGame: Control {
    private var content: ContentPack?
    private var session: ContractSession?
    private var screen: Control?
    private var screenshotPath: String?
    private var framesUntilShot = 0
    private var clicks: [Vector2] = []
    private var quitWhenDrawn = false

    override func _ready() {
        theme = Phosphor.theme()
        setAnchorsAndOffsetsPreset(.fullRect)
        let options = LaunchOptions(arguments: OS.getCmdlineUserArgs().map { String($0) })
        screenshotPath = options.screenshot
        quitWhenDrawn = options.quit
        clicks = options.clicks.map { Vector2(x: $0.x, y: $0.y) }
        framesUntilShot = 5
        do throws(ContentLoadError) {
            content = try ContentLoader.load(source: "res://content") { name throws(ContentLoadError) in
                let path = "res://content/\(name)"
                guard FileAccess.fileExists(path: path) else { return nil }
                return Data(FileAccess.getFileAsString(path: path).utf8)
            }
        } catch {
            GD.printErr("NO CARRIER: CONTENT ERROR \(error.description)")
            show(message: "CONTENT ERROR\n\(error.description.uppercased())")
            return
        }
        newContract(seed: options.seed)
        for action in options.actions { session?.send(action) }
        redraw()
        if let session {
            // One line for the CI smoke test: the extension loaded, the
            // content validated and the actions reached the engine.
            GD.print("NO CARRIER: \(session.state.network.orgName) PHASE \(Self.phaseName(session.state.phase))")
        }
    }

    override func _process(delta: Double) {
        if !clicks.isEmpty {
            click(at: clicks.removeFirst())
            return
        }
        if quitWhenDrawn {
            getTree()?.quit()
            return
        }
        guard let path = screenshotPath else { return }
        framesUntilShot -= 1
        guard framesUntilShot <= 0 else { return }
        screenshotPath = nil
        if let image = getViewport()?.getTexture()?.getImage() {
            _ = image.savePng(path: path)
            GD.print("SCREENSHOT \(path)")
        }
        getTree()?.quit()
    }

    /// A left click, pressed and released, as if from the mouse.
    private func click(at position: Vector2) {
        for pressed in [true, false] {
            let event = InputEventMouseButton()
            event.buttonIndex = .left
            event.pressed = pressed
            event.position = position
            event.globalPosition = position
            Input.parseInputEvent(event)
        }
        Input.flushBufferedEvents()
    }

    private func newContract(seed: UInt64?) {
        guard let content else { return }
        let seed = seed ?? UInt64(GD.randi()) << 32 | UInt64(GD.randi())
        do throws(SessionError) {
            session = try ContractSession(content: content, seed: seed, objectiveID: "takeover")
        } catch {
            show(message: error.description)
        }
    }

    private func send(_ action: ContractAction) {
        session?.send(action)
        redraw()
    }

    private func redraw() {
        guard let session else { return }
        let send: (ContractAction) -> Void = { [weak self] action in self?.send(action) }
        let page: Control
        switch session.state.phase {
        case .map:
            page = MapView.make(session, send: send)
        case .fight(let node, let fight, _):
            page = BattleView.make(session, node: node, fight: fight, send: send)
        case .accessChoice(let node, let fight, _):
            page = Overlay.over(
                BattleView.make(session, node: node, fight: fight, send: send),
                Overlay.accessChoice(node: node, send: send))
        case .reward(_, let choices):
            page = Overlay.over(
                MapView.make(session, send: send), Overlay.reward(session, choices: choices, send: send))
        case .upgrade(_, let choices, _):
            page = Overlay.over(MapView.make(session, send: send), Overlay.upgrade(choices, send: send))
        case .over(let outcome):
            page = Overlay.over(
                MapView.make(session, send: send),
                Overlay.ended(session, outcome: outcome) { [weak self] in
                    self?.newContract(seed: nil)
                    self?.redraw()
                })
        }
        replace(with: page)
    }

    static func phaseName(_ phase: ContractPhase) -> String {
        switch phase {
        case .map: "MAP"
        case .fight: "FIGHT"
        case .accessChoice: "ACCESS CHOICE"
        case .reward: "REWARD"
        case .upgrade: "UPGRADE"
        case .over(let outcome): "OVER \(outcome.rawValue.uppercased())"
        }
    }

    private func show(message: String) {
        let label = Phosphor.label(message, color: Phosphor.red, size: 20)
        label.autowrapMode = .wordSmart
        replace(with: label)
    }

    private func replace(with page: Control) {
        if let screen {
            removeChild(node: screen)
            screen.queueFree()
        }
        let margin = MarginContainer()
        margin.setAnchorsAndOffsetsPreset(.fullRect)
        for side in ["left", "right", "top", "bottom"] {
            margin.addThemeConstantOverride(name: StringName("margin_\(side)"), constant: 16)
        }
        let background = ColorRect()
        background.color = Phosphor.background
        background.setAnchorsAndOffsetsPreset(.fullRect)
        background.mouseFilter = .ignore
        let holder = Control()
        holder.setAnchorsAndOffsetsPreset(.fullRect)
        holder.addChild(node: background)
        margin.addChild(node: page)
        holder.addChild(node: margin)
        addChild(node: holder)
        screen = holder
    }
}

/// The options after `--` on the Godot command line.
struct LaunchOptions {
    var seed: UInt64?
    var actions: [ContractAction] = []
    var screenshot: String?
    var clicks: [(x: Float, y: Float)] = []
    var quit = false

    init(arguments: [String]) {
        var rest = arguments[...]
        while let flag = rest.popFirst() {
            switch flag {
            case "--seed": seed = rest.popFirst().flatMap { UInt64($0) }
            case "--screenshot": screenshot = rest.popFirst()
            case "--quit": quit = true
            case "--actions": actions = rest.popFirst().map(Self.parse) ?? []
            case "--click":
                let parts = (rest.popFirst() ?? "").split(separator: ",").compactMap { Float($0) }
                if parts.count == 2 { clicks.append((parts[0], parts[1])) }
            default: GD.print("NO CARRIER: ignored option \(flag)")
            }
        }
    }

    /// `attack:1,play:0,end,claim,ghost,wait,skip,take:0,upgrade:0`.
    static func parse(_ text: String) -> [ContractAction] {
        text.split(separator: ",").compactMap { word in
            let parts = word.split(separator: ":")
            let number = parts.count > 1 ? Int(parts[1]) : nil
            switch (parts.first.map(String.init), number) {
            case ("attack", let node?): return .attack(node: node)
            case ("scan", let node?): return .scan(node: node)
            case ("play", let index?): return .fight(.play(handIndex: index))
            case ("take", let choice?): return .takeReward(choice: choice, replacing: nil)
            case ("upgrade", let choice?): return .chooseUpgrade(choice: choice)
            case ("end", nil): return .fight(.endTurn)
            case ("logout", nil): return .fight(.logout)
            case ("claim", nil): return .claim
            case ("ghost", nil): return .ghost
            case ("wait", nil): return .wait
            case ("skip", nil): return .skipReward
            default: return nil
            }
        }
    }
}
