import CarrierCore
import SwiftGodot

/// Sheets that show one UI component in every state, side by side, for
/// designing the components one at a time from screenshots. Start Godot
/// with `-- --gallery NAME`; `godot/scripts/gallery.sh` saves them all.
enum Gallery {
    static let sheets = ["cards", "card-states", "nodes", "ice", "fight-panels", "bars", "dialogs"]

    static func make(_ name: String, session: ContractSession) -> Control {
        let content = session.content
        switch name {
        case "cards":
            return sheet(
                "CARD: EVERY CARD IN THE CONTENT",
                content.cards.map { ($0.id, CardView.make($0, refusal: nil) {}) })
        case "card-states":
            return sheet("CARD: PLAYABLE, AND EACH REFUSAL", cardStates(content))
        case "nodes":
            return sheet("NODE: EVERY STATE ON THE MAP", nodes())
        case "ice":
            return sheet(
                "ICE: EACH PROGRAM WITH ITS FIRST MOVES",
                content.ice.map { ice in
                    (ice.id, ICEView.make(name: ice.name, intents: (ice.pattern.first ?? []).map(\.label)))
                })
        case "fight-panels":
            return sheet("FIGHT PANELS: YOUR RIG, THE MACHINE, CYCLES, PILES", fightPanels())
        case "bars":
            return sheet("BARS: STATUS, LOG, BUTTONS", bars(session))
        case "dialogs":
            return sheet("DIALOGS", dialogs(session))
        default:
            return Phosphor.label(
                "NO GALLERY \(name.uppercased()). TRY: " + sheets.joined(separator: ", ").uppercased(),
                color: Phosphor.red)
        }
    }

    /// A title, then each item over its caption, wrapping across the page.
    static func sheet(_ title: String, _ items: [(String, Control)]) -> Control {
        let page = Phosphor.vbox(separation: 16)
        page.addChild(node: Phosphor.label("GALLERY / " + title, color: Phosphor.bright, size: 22))
        let flow = HFlowContainer()
        flow.sizeFlagsHorizontal = .expandFill
        flow.addThemeConstantOverride(name: "h_separation", constant: 24)
        flow.addThemeConstantOverride(name: "v_separation", constant: 24)
        for (caption, control) in items {
            let column = Phosphor.vbox(separation: 6)
            column.addChild(node: control)
            column.addChild(node: Phosphor.label(caption.uppercased(), color: Phosphor.dim, size: 12))
            flow.addChild(node: column)
        }
        page.addChild(node: flow)
        return page
    }

    private static func cardStates(_ content: ContentPack) -> [(String, Control)] {
        var items: [(String, Control)] = []
        let samples: [(String, String, RejectReason?)] = [
            ("brute", "playable", nil),
            ("brute", "no cycles", .notEnoughCycles(cardID: "brute", cost: 1, cycles: 0)),
            ("sniffer", "no ram", .notEnoughRAM(cardID: "sniffer", needed: 2, free: 0)),
            ("payload", "kernel only", .wrongLayer(cardID: "payload", required: .kernel)),
            ("brute", "dead", .unplayable(cardID: "brute")),
        ]
        for (id, caption, refusal) in samples {
            guard let card = content.card(id) else { continue }
            items.append((caption, CardView.make(card, refusal: refusal) {}))
        }
        return items
    }

    private static func nodes() -> [(String, Control)] {
        typealias Model = NodeView.Model
        let models: [(String, Model)] = [
            ("your entry", Model(index: 0, letter: "E", name: "ENTRY", owner: .player)),
            ("yours", Model(index: 1, letter: "H", name: "REPAIR", owner: .player)),
            ("yours, contested", Model(index: 2, letter: "V", name: "VIRUS", owner: .player, contested: true)),
            ("free", Model(index: 3, letter: "R", name: "RELAY", owner: .neutral)),
            ("free, attackable", Model(index: 4, letter: "H", name: "REPAIR", owner: .neutral, attackable: true)),
            ("not scanned", Model(index: 5, letter: "?", name: "UNKNOWN", owner: .neutral)),
            (
                "not scanned, attackable",
                Model(index: 6, letter: "?", name: "UNKNOWN", owner: .neutral, attackable: true)
            ),
            ("accessed (ghosted)", Model(index: 7, letter: "D", name: "DATA", owner: .neutral, accessed: true)),
            ("sysop", Model(index: 8, letter: "R", name: "RELAY", owner: .sysop)),
            ("sysop, attackable", Model(index: 9, letter: "D", name: "DATA", owner: .sysop, attackable: true)),
            ("sysop root", Model(index: 10, letter: "X", name: "ROOT", owner: .sysop)),
            ("the file", Model(index: 11, letter: "$", name: "DATA", owner: .neutral, attackable: true)),
        ]
        return models.map { ($0.0, NodeView.make($0.1)) }
    }

    private static func fightPanels() -> [(String, Control)] {
        let fresh = RigPanel.Model(
            integrity: 40, maxIntegrity: 40, proxy: 0, cycles: 3, maxCycles: 3, ramUsed: 0, ram: 6)
        let hurt = RigPanel.Model(
            integrity: 9, maxIntegrity: 40, proxy: 12, cycles: 1, maxCycles: 4, ramUsed: 4, ram: 6, thorns: 3,
            daemons: [("SNIFFER.DMN", "ATK 3/TURN"), ("FIREWALL.DMN", "DEF 4/TURN")])
        var damaged = [
            SecurityLayer(kind: .firewall, hp: 21), SecurityLayer(kind: .auth, hp: 17),
            SecurityLayer(kind: .kernel, hp: 24),
        ]
        let full = damaged
        damaged[0].hp = 0
        damaged[1].hp = 6
        var transfer = TransferProgress(totalMB: 24, rateMB: 4)
        transfer.doneMB = 8
        return [
            ("rig: fresh", RigPanel.make(fresh)),
            ("rig: hurt, with daemons", RigPanel.make(hurt)),
            (
                "machine: untouched, not probed",
                LayerStack.make(layers: full, current: 0, transfer: nil, weak: nil, resist: nil)
            ),
            (
                "machine: auth under attack, probed, transfer",
                LayerStack.make(layers: damaged, current: 1, transfer: transfer, weak: [.overflow], resist: [])
            ),
            ("cycles: 2 of 3", CyclePips.make(left: 2, total: 3)),
            ("cycles: 5 of 3 (bonus)", CyclePips.make(left: 5, total: 3)),
            ("pile", PileView.make("DRAW", count: 12)),
        ]
    }

    private static func bars(_ session: ContractSession) -> [(String, Control)] {
        let wide = StatusBar.make(session.state)
        wide.customMinimumSize = Vector2(x: 1360, y: 0)
        let log = LogPanel.make(session.log + ["AUTH -6", "ACCESS GRANTED"], lines: 4)
        log.customMinimumSize = Vector2(x: 700, y: 0)
        let disabled = Phosphor.button("END TURN") {}
        disabled.disabled = true
        return [
            ("status bar (map)", wide),
            ("log", log),
            ("button", Phosphor.button("WAIT") {}),
            ("button, disabled", disabled),
        ]
    }

    private static func dialogs(_ session: ContractSession) -> [(String, Control)] {
        let upgrades = session.state.rules.tuning.network.dataUpgrades
        let loot = session.content.cards.prefix(3).map(\.id)
        return [
            ("ghost or claim", Phosphor.panel(Overlay.accessChoice(node: 1) { _ in })),
            ("upgrade", Phosphor.panel(Overlay.upgrade(Array(upgrades.prefix(3))) { _ in })),
            ("loot", Phosphor.panel(Overlay.reward(session, choices: Array(loot)) { _ in })),
            ("won", Phosphor.panel(Overlay.ended(session, outcome: .won) {})),
            ("traced", Phosphor.panel(Overlay.ended(session, outcome: .traced) {})),
        ]
    }
}
