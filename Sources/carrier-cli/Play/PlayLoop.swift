import CarrierCore

/// Runs a contract against the keyboard (raw mode) or lines of input.
enum PlayLoop {
    static func interactive(_ session: inout PlaySession, terminal: RawTerminal) throws {
        let style = Phosphor(enabled: true)
        var editor = LineEditor()
        Output.write("\u{1B}[?1049h\u{1B}[?25l")
        defer {
            Output.write("\u{1B}[0m\u{1B}[?25h\u{1B}[?1049l")
            terminal.restore()
        }
        while session.state.outcome == nil {
            let screen = session.screen(
                style: style, rows: RawTerminal.rows() ?? 24, prompt: editor.buffer, hint: editor.hint)
            Output.write("\u{1B}[H" + style.screen(screen) + "\u{1B}[J")
            guard let byte = terminal.readByte() else { return }
            switch editor.handle(byte, completer: session.completer, immediateDigits: session.immediateDigits) {
            case .digit(let digit):
                try session.digit(digit)
            case .submit(let text):
                if try !session.submit(text) { return }
            case .quit:
                return
            case .changed:
                if editor.hint == "?NO MATCH" { Output.write("\u{07}") }
            case .ignored:
                break
            }
        }
    }

    static func lines(_ session: inout PlaySession) throws {
        let style = Phosphor.forStandardOutput()
        Output.write(style.screen(session.screen(style: style, rows: 24, prompt: nil, hint: "")) + "\n")
        while session.state.outcome == nil, let line = readLine() {
            Output.write("]>\(line.uppercased())\n")
            if try !session.submit(line) { return }
            Output.write(style.screen(session.screen(style: style, rows: 24, prompt: nil, hint: "")) + "\n")
        }
    }
}
