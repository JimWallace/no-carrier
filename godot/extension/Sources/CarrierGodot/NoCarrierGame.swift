import CarrierContent
import CarrierCore
import Foundation
import SwiftGodot

/// The root of `main.tscn`. It loads the content from the project and starts
/// a crack run (addendum 03), or with `--mode contract` a contract. It draws
/// the screen for the phase: the crack with its reward and end dialogs, or
/// the map or a battle with theirs. Each action redraws the whole screen
/// from the state; the screens hold no state of their own.
///
/// Command-line options after `--` (for testing and screenshots):
/// `--mode crack|contract`, `--crack-actions play:0:1,use:2,swap:0:1,turn:0:K,
/// drop:0,guess,hold,take:0,remove:0,skip,logout`, `--server ID` (one crack
/// instead of the run),
/// `--hover X,Y` (moves the mouse there, for a tooltip screenshot),
/// `--seed N`, `--actions attack:1,play:0,end`, `--click X,Y` (repeatable;
/// a mouse click through Godot's input, to test the wiring) and
/// `--screenshot out.png` (saves the window after the clicks, then quits)
/// `--quit` (quits after the first frame, for a headless check) and
/// `--gallery NAME` (shows one component sheet instead of the game; see
/// `Gallery`).
@Godot
final class NoCarrierGame: Control {
    private var content: ContentPack?
    private var session: ContractSession?
    private var crack: CrackPlay?
    private var crackServer: String?
    private var screen: Control?
    private var screenshotPath: String?
    private var framesUntilShot = 0
    private var clicks: [Vector2] = []
    private var hover: Vector2?
    private var quitWhenDrawn = false

    override func _ready() {
        theme = Phosphor.theme()
        setAnchorsAndOffsetsPreset(.fullRect)
        let options = LaunchOptions(arguments: OS.getCmdlineUserArgs().map { String($0) })
        screenshotPath = options.screenshot
        quitWhenDrawn = options.quit
        clicks = options.clicks.map { Vector2(x: $0.x, y: $0.y) }
        hover = options.hover.map { Vector2(x: $0.x, y: $0.y) }
        // A tooltip waits for the mouse to rest, so a hover shot waits too.
        framesUntilShot = hover == nil ? 5 : 90
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
        if options.mode == "crack" {
            crackServer = options.server
            newCrack(seed: options.seed)
            for action in options.crackActions { crack?.send(action) }
            if let gallery = options.gallery, let crack {
                replace(with: Gallery.makeCrack(gallery, play: crack))
                return
            }
            redraw()
            if let crack {
                // One line for the CI smoke test, as for a contract below.
                let server = crack.crack?.server.name ?? "-"
                GD.print(
                    "NO CARRIER: CRACK \(server) TURN \(crack.crack?.turn ?? 0) PHASE \(Self.phaseName(crack.state.phase))"
                )
            }
            return
        }
        newContract(seed: options.seed)
        for action in options.actions { session?.send(action) }
        if let gallery = options.gallery, let session {
            replace(with: Gallery.make(gallery, session: session))
            return
        }
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
        if let position = hover {
            hover = nil
            let event = InputEventMouseMotion()
            event.position = position
            event.globalPosition = position
            Input.parseInputEvent(event)
            Input.flushBufferedEvents()
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

    private func newCrack(seed: UInt64?) {
        guard var crackContent = content?.crack else {
            show(message: "CONTENT ERROR\nCRACK.JSON IS MISSING")
            return
        }
        if let crackServer, crackContent.server(crackServer) != nil {
            crackContent.run.servers = [crackServer]
        }
        let seed = seed ?? UInt64(GD.randi()) << 32 | UInt64(GD.randi())
        crack = CrackPlay(content: crackContent, seed: seed)
    }

    private func handle(_ input: CrackView.Input) {
        switch input {
        case .send(let action): crack?.send(action)
        case .card(let index): crack?.clickCard(index)
        case .slot(let index): crack?.clickSlot(index)
        case .turn(let slot, let step): crack?.turnDial(slot, step: step)
        case .drop:
            if let card = crack?.selectedCard { crack?.send(.crack(.drop(handIndex: card))) }
        }
        redraw()
    }

    private func redrawCrack(_ play: CrackPlay) {
        let input: (CrackView.Input) -> Void = { [weak self] input in self?.handle(input) }
        let board: Control =
            play.crack.map { CrackView.make(play, crack: $0, input: input) } ?? Phosphor.label("NO CRACK")
        switch play.state.phase {
        case .cracking:
            replace(with: board)
        case .reward(let cards, let next):
            replace(with: Overlay.over(board, CrackOverlay.reward(play, cards: cards, next: next) { input(.send($0)) }))
        case .won, .lost:
            replace(
                with: Overlay.over(
                    board,
                    CrackOverlay.ended(play) { [weak self] in
                        self?.newCrack(seed: nil)
                        self?.redraw()
                    }))
        }
    }

    private func redraw() {
        if let crack {
            redrawCrack(crack)
            return
        }
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

    static func phaseName(_ phase: CrackRunPhase) -> String {
        switch phase {
        case .cracking: "CRACKING"
        case .reward: "REWARD"
        case .won: "WON"
        case .lost: "LOST"
        }
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
    /// Moves the mouse here after the clicks, for a tooltip screenshot.
    var hover: (x: Float, y: Float)?
    var quit = false
    var gallery: String?
    /// `crack` (the default) or `contract`.
    var mode = "crack"
    var crackActions: [CrackRunAction] = []
    var server: String?

    init(arguments: [String]) {
        var rest = arguments[...]
        while let flag = rest.popFirst() {
            switch flag {
            case "--seed": seed = rest.popFirst().flatMap { UInt64($0) }
            case "--screenshot": screenshot = rest.popFirst()
            case "--quit": quit = true
            case "--gallery": gallery = rest.popFirst()
            case "--actions": actions = rest.popFirst().map(Self.parse) ?? []
            case "--mode":
                let value = rest.popFirst() ?? mode
                if value == "crack" || value == "contract" {
                    mode = value
                } else {
                    GD.printErr("NO CARRIER: --mode \(value) is not crack or contract; playing crack")
                }
            case "--server": server = rest.popFirst()
            case "--crack-actions": crackActions = rest.popFirst().map(Self.parseCrack) ?? []
            case "--hover":
                let parts = (rest.popFirst() ?? "").split(separator: ",").compactMap { Float($0) }
                if parts.count == 2 { hover = (parts[0], parts[1]) }
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

    /// `play:0:1,use:2,swap:0:1,turn:0:K,drop:0,guess,hold,take:0,remove:0,
    /// skip,logout`. Numbers count from 0.
    static func parseCrack(_ text: String) -> [CrackRunAction] {
        text.split(separator: ",").compactMap { word in
            let parts = word.split(separator: ":").map(String.init)
            let numbers = parts.dropFirst().compactMap { Int($0) }
            switch (parts.first, numbers.count) {
            case ("play", 2): return .crack(.play(handIndex: numbers[0], slot: numbers[1]))
            case ("use", 1): return .crack(.use(handIndex: numbers[0]))
            case ("swap", 2): return .crack(.swap(numbers[0], numbers[1]))
            case ("drop", 1): return .crack(.drop(handIndex: numbers[0]))
            case ("turn", 1) where parts.count == 3: return .crack(.turn(slot: numbers[0], symbol: parts[2]))
            case ("guess", 0): return .crack(.guess)
            case ("hold", 0): return .crack(.hold)
            case ("logout", 0): return .crack(.logout)
            case ("take", 1): return .take(numbers[0])
            case ("remove", 1): return .remove(numbers[0])
            case ("skip", 0): return .skip
            default: return nil
            }
        }
    }
}
