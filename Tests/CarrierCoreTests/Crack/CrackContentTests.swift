import CarrierCore
import TestSupport
import Testing

/// `crack.json` and its checks (addendum 03).
@Suite struct CrackContentTests {
    @Test func theBundledCrackContentValidates() throws {
        let pack = try BundledContent.load()
        let crack = try #require(pack.crack)
        #expect(pack.validateCrack(crack).isEmpty)
    }

    @Test func aStarterCardThatDoesNotExistIsReported() throws {
        var crack = try #require(try BundledContent.load().crack)
        crack.starterDeck.append("glyph-q")
        let errors = try BundledContent.load().validateCrack(crack)
        #expect(errors == [.unknownCard(id: "glyph-q", referencedBy: "crack.starterDeck")])
    }

    @Test func aCodeThatCannotBeFilledIsReported() throws {
        var crack = try #require(try BundledContent.load().crack)
        crack.maxRepeats = 0
        let errors = try BundledContent.load().validateCrack(crack)
        #expect(errors.contains { if case .invalidValue(field: "crack.maxRepeats", _) = $0 { true } else { false } })
    }

    @Test func aDeckWithTooFewCopiesForMaxRepeatsIsReported() throws {
        var crack = try #require(try BundledContent.load().crack)
        crack.maxRepeats = 4
        let errors = try BundledContent.load().validateCrack(crack)
        #expect(
            errors.contains(.invalidValue(field: "crack.starterDeck", reason: "has 3 A, fewer than maxRepeats (4)")))
    }
}
