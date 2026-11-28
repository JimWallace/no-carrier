import CarrierCore
import TestSupport
import Testing

/// Keywords in card text (addendum 03, §7): which words are bold, and that
/// each explains itself as briefly as a card does.
@Suite struct CrackKeywordTests {
    let content: CrackContent

    init() throws {
        content = try #require(try BundledContent.load().crack)
    }

    @Test func aKeywordIsFoundThroughPunctuationPossessivesAndPlurals() {
        let spans = content.spans("IS THIS SLOT'S SYMBOL IN THE CODE? TWO SLOTS.")
        #expect(
            spans == [
                .plain("IS THIS "), .keyword(word: "SLOT", shown: "SLOT"), .plain("'S SYMBOL IN THE "),
                .keyword(word: "CODE", shown: "CODE"), .plain("? TWO "), .keyword(word: "SLOT", shown: "SLOTS"),
                .plain("."),
            ])
    }

    @Test(arguments: ["SHOWS A.", "IS THIS SLOT'S SYMBOL ANYWHERE IN THE CODE?", "  ALARM  ", ""])
    func theSpansJoinBackIntoTheText(text: String) {
        #expect(content.spans(text).map(\.shown).joined() == text)
    }

    @Test func keywordsInTextAreListedOnceInOrder() {
        let words = content.keywords(in: "NEXT GUESS COSTS 50% ALARM. ANOTHER GUESS.").map(\.word)
        #expect(words == ["GUESS", "ALARM"])
    }

    @Test func aWordThatOnlyStartsLikeAKeywordIsPlain() {
        #expect(content.keywords(in: "SLOTTED CODEX").isEmpty)
    }

    @Test func everyKeywordExplainsItselfInTenWords() {
        for keyword in content.keywords {
            #expect(keyword.text.split(separator: " ").count <= CrackCard.maxRuleWords, "\(keyword.word)")
        }
    }

    @Test func everyCardsTextUsesAtLeastOneKeywordOrNone() {
        // A guard that the keyword list reaches card text at all.
        let used = content.cards.flatMap { content.keywords(in: $0.rules) }
        #expect(!used.isEmpty)
    }

    @Test func aKeywordThatIsNotOneUpperCaseWordIsReported() throws {
        var crack = content
        crack.keywords.append(CrackKeyword(word: "Two words", text: "BAD."))
        let errors = try BundledContent.load().validateCrack(crack)
        #expect(
            errors.contains(
                .invalidValue(field: "crack.keywords.Two words", reason: "a keyword is one upper-case word")))
    }
}
