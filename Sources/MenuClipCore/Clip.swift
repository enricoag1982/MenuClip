import Foundation

/// One entry in the clipboard history.
///
/// It keeps every representation that was captured, so pasting it back
/// offers the target app the same choices the original copy did.
public struct Clip: Codable, Identifiable, Equatable {
    public enum Kind: String, Codable {
        case text, richText, image, pdf, files
    }

    public var id: UUID
    public var date: Date
    public var text: String?
    public var rtf: Data?
    public var rtfd: Data?
    public var html: Data?
    public var pdf: Data?
    /// PNG data.
    public var image: Data?
    public var fileURLs: [URL]
    /// Bundle identifier of the app that was in front when the copy happened.
    public var sourceBundleID: String?

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        text: String? = nil,
        rtf: Data? = nil,
        rtfd: Data? = nil,
        html: Data? = nil,
        pdf: Data? = nil,
        image: Data? = nil,
        fileURLs: [URL] = [],
        sourceBundleID: String? = nil
    ) {
        self.id = id
        self.date = date
        self.text = text
        self.rtf = rtf
        self.rtfd = rtfd
        self.html = html
        self.pdf = pdf
        self.image = image
        self.fileURLs = fileURLs
        self.sourceBundleID = sourceBundleID
    }

    public var isEmpty: Bool {
        text == nil && rtf == nil && rtfd == nil && html == nil
            && pdf == nil && image == nil && fileURLs.isEmpty
    }

    private var hasRichText: Bool { rtf != nil || rtfd != nil || html != nil }

    /// What the clip mainly is, which decides how it is shown in the menu.
    public var kind: Kind {
        if !fileURLs.isEmpty { return .files }
        if let text, !text.allSatisfy(\.isWhitespace) { return hasRichText ? .richText : .text }
        if image != nil { return .image }
        if pdf != nil { return .pdf }
        return hasRichText ? .richText : .text
    }

    /// Whether two clips hold the same thing, so the history can avoid duplicates.
    /// Clips with text are compared by their text alone: the same words copied
    /// from two apps count as one entry, and the newer copy wins.
    public func hasSameContent(as other: Clip) -> Bool {
        if !fileURLs.isEmpty || !other.fileURLs.isEmpty {
            return fileURLs == other.fileURLs
        }
        switch (text, other.text) {
        case let (a?, b?):
            return a == b
        case (nil, nil):
            return image == other.image && pdf == other.pdf
                && rtfd == other.rtfd && rtf == other.rtf && html == other.html
        default:
            return false
        }
    }
}
