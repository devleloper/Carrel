import Foundation

/// Names the user types for notebooks and folders.
public enum Title {
    /// Trims surrounding whitespace. Returns `nil` when nothing is left.
    public static func normalized(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
