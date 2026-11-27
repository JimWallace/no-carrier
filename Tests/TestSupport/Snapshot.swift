import Foundation

/// Golden-snapshot comparison for the transcript and procgen tests.
///
/// A snapshot is a text file in the test target's `Snapshots/` folder. When
/// the file is missing, `compare` writes it and reports a mismatch, so the
/// first run of a new snapshot fails and the second passes. To regenerate
/// after a deliberate rule or content change, delete the file and run the
/// test twice. Read the diff of the snapshot before committing it.
public enum Snapshot {
    public enum Outcome: Equatable, Sendable {
        case matches
        case recorded(path: String)
        case differs(line: Int, expected: String, actual: String)

        public var message: String {
            switch self {
            case .matches:
                "matches"
            case .recorded(let path):
                "recorded a new snapshot at \(path); run the test again"
            case .differs(let line, let expected, let actual):
                "line \(line) differs\n  expected: \(expected)\n  actual:   \(actual)"
            }
        }
    }

    /// Compares `actual` with `Snapshots/<name>.txt` beside `filePath`.
    public static func compare(
        _ actual: String, named name: String, filePath: String = #filePath
    ) throws -> Outcome {
        let directory = URL(fileURLWithPath: filePath).deletingLastPathComponent()
            .appendingPathComponent("Snapshots", isDirectory: true)
        let url = directory.appendingPathComponent("\(name).txt")
        let text = actual.hasSuffix("\n") ? actual : actual + "\n"
        guard FileManager.default.fileExists(atPath: url.path) else {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url)
            return .recorded(path: url.path)
        }
        let expected = String(bytes: try Data(contentsOf: url), encoding: .utf8) ?? ""
        if expected == text {
            return .matches
        }
        let expectedLines = expected.split(separator: "\n", omittingEmptySubsequences: false)
        let actualLines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for index in 0..<max(expectedLines.count, actualLines.count) {
            let left = index < expectedLines.count ? String(expectedLines[index]) : "<end of file>"
            let right = index < actualLines.count ? String(actualLines[index]) : "<end of file>"
            if left != right {
                return .differs(line: index + 1, expected: left, actual: right)
            }
        }
        return .matches
    }
}
