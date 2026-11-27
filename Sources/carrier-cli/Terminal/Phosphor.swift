import Foundation

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// The green-phosphor look: green text, inverse video for highlights. Off
/// when the output is not a terminal, so a pipe or a test reads plain text.
struct Phosphor: Sendable {
    let enabled: Bool

    static func forStandardOutput() -> Self {
        Self(enabled: isatty(STDOUT_FILENO) == 1)
    }

    static let plain = Self(enabled: false)

    func green(_ text: String) -> String {
        enabled ? "\u{1B}[32m" + text + "\u{1B}[0m" : text
    }

    func bright(_ text: String) -> String {
        enabled ? "\u{1B}[1;32m" + text + "\u{1B}[0;32m" : text
    }

    func inverse(_ text: String) -> String {
        enabled ? "\u{1B}[7m" + text + "\u{1B}[27m" : text
    }

    /// Flashing text, for alerts (kickoff §7).
    func blink(_ text: String) -> String {
        enabled ? "\u{1B}[5m" + text + "\u{1B}[25m" : text
    }

    func dim(_ text: String) -> String {
        enabled ? "\u{1B}[2m" + text + "\u{1B}[22m" : text
    }

    /// `lines`, each behind the `] ` prompt, in green.
    func screen(_ lines: [String]) -> String {
        let body = lines.map { Columns.prompt + $0 }.joined(separator: "\n")
        return enabled ? "\u{1B}[32m" + body + "\u{1B}[0m" : body
    }
}
