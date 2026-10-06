import Foundation

public struct Snippet: Codable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var title: String
    public var content: String

    public init(id: UUID = UUID(), title: String, content: String) {
        self.id = id
        self.title = title
        self.content = content
    }
}

public struct SnippetFolder: Codable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var title: String
    public var snippets: [Snippet]

    public init(id: UUID = UUID(), title: String, snippets: [Snippet] = []) {
        self.id = id
        self.title = title
        self.snippets = snippets
    }
}
