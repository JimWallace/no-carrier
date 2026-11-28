/// Where a flag is meant to live (addendum 02, §1 and §4).
public enum FlagCategory: String, Codable, Sendable, CaseIterable {
    /// Part of the game wherever it applies.
    case core
    /// Held back for higher ascensions. Only this category may be.
    case difficulty
    /// Off by default; switched on to test an idea.
    case experiment
    /// Set by the contract layer: the objective (and, later, modifiers).
    case contract
}
