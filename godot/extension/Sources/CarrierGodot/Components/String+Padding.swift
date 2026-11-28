extension String {
    /// Pads with spaces to `width` characters, for the monospace columns.
    func padding(_ width: Int) -> String {
        count >= width ? self : self + String(repeating: " ", count: width - count)
    }
}
