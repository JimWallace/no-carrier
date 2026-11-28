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
        crack.servers[0].maxRepeats = 0
        let field = "crack.servers.\(crack.servers[0].id).maxRepeats"
        let errors = try BundledContent.load().validateCrack(crack)
        #expect(errors.contains { if case .invalidValue(field: field, _) = $0 { true } else { false } })
    }

    @Test func aDeckWithTooFewCopiesForMaxRepeatsIsReported() throws {
        var crack = try #require(try BundledContent.load().crack)
        crack.servers[0].maxRepeats = 4
        let id = crack.servers[0].id
        let errors = try BundledContent.load().validateCrack(crack)
        #expect(
            errors.contains(
                .invalidValue(field: "crack.starterDeck", reason: "has 3 A, fewer than \(id) maxRepeats (4)")))
    }

    @Test func aServerSymbolThatNoCardShowsIsReported() throws {
        var crack = try #require(try BundledContent.load().crack)
        crack.servers[0].symbols.append("Q")
        let errors = try BundledContent.load().validateCrack(crack)
        let field = "crack.servers.\(crack.servers[0].id).symbols"
        #expect(errors.contains(.invalidValue(field: field, reason: "\"Q\" is not a symbol")))
    }

    @Test func aProgramThatNeverActsIsReported() throws {
        var crack = try #require(try BundledContent.load().crack)
        crack.servers[0].interference = [CrackInterference(kind: .scramble, every: 0)]
        let errors = try BundledContent.load().validateCrack(crack)
        let field = "crack.servers.\(crack.servers[0].id).interference"
        #expect(errors.contains(.invalidValue(field: field, reason: "every must be at least 1")))
    }
}
