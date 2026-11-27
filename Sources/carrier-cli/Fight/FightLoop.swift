import CarrierCore
import Foundation

/// Runs a fight session against the keyboard (raw mode) or against lines of
/// standard input (a pipe, or `--plain`).
enum FightLoop {
    /// Raw mode on the alternate screen, redrawn after every key.
    static func interactive(_ session: inout FightSession, terminal: RawTerminal) throws {
        let style = Phosphor(enabled: true)
        var editor = LineEditor()
        Output.write("\u{1B}[?1049h\u{1B}[?25l")
        defer {
            Output.write("\u{1B}[0m\u{1B}[?25h\u{1B}[?1049l")
            terminal.restore()
        }
        while !session.fight.isOver {
            let screen = FightScreen(session: session, style: style, screenRows: RawTerminal.rows() ?? 24)
                .lines(prompt: editor.buffer, hint: editor.hint)
            Output.write("\u{1B}[H" + style.screen(screen) + "\u{1B}[J")
            guard let byte = terminal.readByte() else { return }
            switch editor.handle(byte, completer: session.parser.complete) {
            case .digit(let digit):
                try session.perform(.play(handIndex: CommandParser.handIndex(forDigit: digit)))
            case .submit(let text):
                if try session.submit(text) == .quit { return }
            case .quit:
                return
            case .changed:
                if editor.hint == "?NO MATCH" { Output.write("\u{07}") }
            case .ignored:
                break
            }
        }
    }

    /// One command per line; a plain frame after each.
    static func lines(_ session: inout FightSession) throws {
        let style = Phosphor.forStandardOutput()
        Output.write(style.screen(FightScreen(session: session, style: style).lines(prompt: nil, hint: "")) + "\n")
        while !session.fight.isOver, let line = readLine() {
            Output.write("]>\(line.uppercased())\n")
            if try session.submit(line) == .quit { return }
            let frame = FightScreen(session: session, style: style).lines(prompt: nil, hint: "")
            Output.write(style.screen(frame) + "\n")
        }
    }

    /// The closing lines: how it ended, and how to play it again.
    static func banner(for session: FightSession, command: FightCommand) -> [String] {
        var lines: [String]
        switch session.fight.outcome {
        case .captured: lines = ["ACCESS GRANTED. NODE CAPTURED."]
        case .loggedOut: lines = ["LOGGED OUT. NODE UNCHANGED."]
        case .flatlined: lines = ["INTEGRITY 0. RUN OVER."]
        case .traced: lines = ["", "NO CARRIER", ""]
        case nil: lines = ["SESSION ABANDONED."]
        }
        let seed = Seed.display(session.state.seed)
        lines.append("TURNS \(session.fight.turn)  TRACE \(session.fight.trace)  INT \(session.fight.integrity)")
        if let record = command.record {
            lines += Columns.wrap("REPLAY: carrier replay \(record)")
        } else {
            lines += Columns.wrap("AGAIN: carrier fight --seed \(seed) --role \(session.replay.role.rawValue)")
        }
        return lines
    }
}
