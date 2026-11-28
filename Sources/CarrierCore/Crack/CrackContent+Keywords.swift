extension CrackContent {
    public func keyword(_ word: String) -> CrackKeyword? {
        let upper = word.uppercased()
        return keywords.first { $0.word == upper }
    }

    /// `text` split into plain runs and keywords. A word counts as a
    /// keyword with trailing punctuation, a possessive `'S` or a plural `S`
    /// taken off, so `SLOT'S`, `SLOTS` and `CODE.` all find theirs. Derived from the text, so it
    /// cannot disagree with it; joining every span's `shown` gives `text`
    /// back.
    public func spans(_ text: String) -> [CrackTextSpan] {
        var spans: [CrackTextSpan] = []
        var plain = ""
        let words = text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        for (index, word) in words.enumerated() {
            let separator = index < words.count - 1 ? " " : ""
            guard let (found, length) = matchKeyword(word) else {
                plain += word + separator
                continue
            }
            if !plain.isEmpty { spans.append(.plain(plain)) }
            spans.append(.keyword(word: found, shown: String(word.prefix(length))))
            plain = String(word.dropFirst(length)) + separator
        }
        if !plain.isEmpty { spans.append(.plain(plain)) }
        return spans
    }

    /// The keywords `text` uses, in the order it first uses them.
    public func keywords(in text: String) -> [CrackKeyword] {
        var found: [CrackKeyword] = []
        for case .keyword(let word, _) in spans(text) where !found.contains(where: { $0.word == word }) {
            if let keyword = keyword(word) { found.append(keyword) }
        }
        return found
    }

    /// The keyword `word` names, and how many of its characters to show in
    /// bold: a plural's S is bold, a possessive's 'S and punctuation are not.
    private func matchKeyword(_ word: String) -> (String, Int)? {
        var base = Substring(word)
        while let last = base.last, ".,:;?!".contains(last) {
            base = base.dropLast()
        }
        if base.hasSuffix("'S") { base = base.dropLast(2) }
        if keyword(String(base)) != nil, !base.isEmpty { return (String(base), base.count) }
        if base.hasSuffix("S"), keyword(String(base.dropLast())) != nil {
            return (String(base.dropLast()), base.count)
        }
        return nil
    }
}
