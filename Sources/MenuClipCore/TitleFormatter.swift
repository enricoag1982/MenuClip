import Foundation

/// Turns clip text into short, single-line menu titles.
public enum TitleFormatter {
    /// Only this much of a long text is looked at when building a title.
    private static let scanLimit = 1000

    /// Collapses every run of whitespace and line breaks into one space.
    public static func singleLine(_ text: some StringProtocol) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Shortens `text` to `maxLength` characters, ending with "…" when cut.
    public static func truncate(_ text: String, maxLength: Int) -> String {
        let limit = max(maxLength, 1)
        guard text.count > limit else { return text }
        return String(text.prefix(limit - 1)) + "…"
    }

    public static func menuTitle(for text: String, maxLength: Int) -> String {
        let head = text.drop(while: \.isWhitespace).prefix(scanLimit)
        let line = singleLine(head)
        return line.isEmpty ? "(whitespace)" : truncate(line, maxLength: maxLength)
    }
}
