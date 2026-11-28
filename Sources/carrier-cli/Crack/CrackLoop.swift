import CarrierCore
import CarrierTerminal

/// Runs a crack session against the keyboard (raw mode) or against lines of
/// standard input (a pipe, or `--plain`).
enum CrackLoop {
    /// Raw mode on the alternate screen, redrawn after every key. Digits
    /// are ordinary keys here: a command is typed, then Return.
    static func interactive(_ session: inout CrackSession, terminal: RawTerminal) {
        let style = Phosphor(enabled: true)
        var editor = LineEditor()
        Output.write("\u{1B}[?1049h\u{1B}[?25l")
        defer {
            Output.write("\u{1B}[0m\u{1B}[?25h\u{1B}[?1049l")
            terminal.restore()
        }
        while !session.state.isOver {
            let screen = CrackScreen(session: session, style: style, screenRows: RawTerminal.rows() ?? 24)
                .lines(prompt: editor.buffer, hint: editor.hint)
            Output.write("\u{1B}[H" + style.screen(screen) + "\u{1B}[J")
            guard let byte = terminal.readByte() else { return }
            switch editor.handle(byte, completer: { ($0, []) }, immediateDigits: false) {
            case .submit(let text):
                if session.submit(text) == .quit { return }
            case .quit:
                return
            case .digit, .changed, .ignored:
                break
            }
        }
    }

    /// One command per line; a plain frame after each.
    static func lines(_ session: inout CrackSession) {
        let style = Phosphor.forStandardOutput()
        Output.write(style.screen(CrackScreen(session: session, style: style).lines(prompt: nil, hint: "")) + "\n")
        while !session.state.isOver, let line = readLine() {
            Output.write("]>\(line.uppercased())\n")
            if session.submit(line) == .quit { return }
            Output.write(style.screen(CrackScreen(session: session, style: style).lines(prompt: nil, hint: "")) + "\n")
        }
    }

    /// The closing lines: how it ended, the code, and how to play it again.
    static func banner(for session: CrackSession) -> [String] {
        let state = session.state
        var lines: [String]
        switch state.outcome {
        case .cracked: lines = ["ACCESS GRANTED. CODE CRACKED."]
        case .traced: lines = ["", "NO CARRIER", ""]
        case .loggedOut: lines = ["LOGGED OUT."]
        case nil: lines = ["SESSION ABANDONED."]
        }
        lines.append("CODE \(state.code.joined(separator: " "))  GUESSES \(state.guesses.count)  ALARM \(state.alarm)")
        lines += Columns.wrap("AGAIN: carrier crack --seed \(Seed.display(state.seed)) --server \(state.server.id)")
        return lines
    }
}
