/// The fight prompt in raw mode: one key at a time.
///
/// A digit on an empty line plays that card at once (number-key play). Any
/// other printable key builds a typed command, upper-cased as it echoes; Tab
/// completes it against the hand and the commands; Return submits it. Both
/// input modes are always on, so a playtest can compare them (kickoff §7).
struct LineEditor {
    enum Outcome: Equatable {
        case changed
        case submit(String)
        case playNow(handIndex: Int)
        case quit
        case ignored
    }

    private(set) var buffer = ""
    private(set) var hint = ""
    private var escapeBytesLeft = 0

    mutating func handle(_ byte: UInt8, parser: CommandParser) -> Outcome {
        if escapeBytesLeft > 0 {
            escapeBytesLeft -= 1
            if escapeBytesLeft == 1 && byte != UInt8(ascii: "[") && byte != UInt8(ascii: "O") {
                escapeBytesLeft = 0
            }
            return .ignored
        }
        switch byte {
        case 3, 4:
            return .quit
        case 27:
            escapeBytesLeft = 2
            return .ignored
        case 9:
            let (text, matches) = parser.complete(buffer)
            buffer = text
            hint = matches.count > 1 ? matches.joined(separator: " ") : (matches.isEmpty ? "?NO MATCH" : "")
            return .changed
        case 10, 13:
            let line = buffer
            buffer = ""
            hint = ""
            return .submit(line)
        case 8, 127:
            if !buffer.isEmpty { buffer.removeLast() }
            hint = ""
            return .changed
        case 21:
            buffer = ""
            hint = ""
            return .changed
        case UInt8(ascii: "0")...UInt8(ascii: "9") where buffer.isEmpty:
            let digit = Int(byte - UInt8(ascii: "0"))
            hint = ""
            return .playNow(handIndex: digit == 0 ? 9 : digit - 1)
        case 32...126:
            guard buffer.count < Columns.textWidth - 2 else { return .ignored }
            buffer += String(UnicodeScalar(byte)).uppercased()
            hint = ""
            return .changed
        default:
            return .ignored
        }
    }
}
