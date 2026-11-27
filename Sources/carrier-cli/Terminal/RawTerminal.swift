#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// Puts standard input into raw mode (no echo, no line buffering, no
/// signals) so the fight prompt reads one key at a time, and restores it.
///
/// termios has no safe Swift API: `tcgetattr`, `tcsetattr` and `read` take
/// pointers, and `c_cc` is a C array imported as a tuple. Each such call is
/// marked `unsafe`; every pointer is to a local that outlives the call.
final class RawTerminal {
    private let original: termios

    /// Nil when standard input is not a terminal.
    init?() {
        guard isatty(STDIN_FILENO) == 1 else { return nil }
        var settings = termios()
        guard unsafe tcgetattr(STDIN_FILENO, &settings) == 0 else { return nil }
        original = settings
        var raw = settings
        raw.c_lflag &= ~tcflag_t(ECHO | ICANON | ISIG | IEXTEN)
        raw.c_iflag &= ~tcflag_t(IXON | ICRNL)
        withUnsafeMutableBytes(of: &raw.c_cc) { bytes in
            unsafe bytes[Int(VMIN)] = 1
            unsafe bytes[Int(VTIME)] = 0
        }
        guard unsafe tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == 0 else { return nil }
    }

    deinit {
        restore()
    }

    func restore() {
        var settings = original
        _ = unsafe tcsetattr(STDIN_FILENO, TCSAFLUSH, &settings)
    }

    /// The terminal's height in rows, or nil when it cannot be read.
    static func rows() -> Int? {
        var size = winsize()
        guard unsafe ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &size) == 0, size.ws_row > 0 else { return nil }
        return Int(size.ws_row)
    }

    /// Blocks for one byte. Nil at end of input or on an error.
    func readByte() -> UInt8? {
        var byte: UInt8 = 0
        let count = unsafe read(STDIN_FILENO, &byte, 1)
        return count == 1 ? byte : nil
    }
}
