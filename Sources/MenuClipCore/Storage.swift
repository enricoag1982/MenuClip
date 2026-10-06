import Foundation

/// Reads and writes the history and snippets in Application Support.
public struct Storage {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("MenuClip", isDirectory: true)
    }

    public var historyURL: URL { directory.appendingPathComponent("history.plist") }
    public var snippetsURL: URL { directory.appendingPathComponent("snippets.json") }

    // MARK: History

    /// Returns an empty history if the file is missing or unreadable.
    public func loadHistory() -> [Clip] {
        guard let data = try? Data(contentsOf: historyURL) else { return [] }
        return (try? PropertyListDecoder().decode([Clip].self, from: data)) ?? []
    }

    public func saveHistory(_ clips: [Clip]) throws {
        try createDirectory()
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try encoder.encode(clips).write(to: historyURL, options: .atomic)
    }

    public func deleteHistory() {
        try? FileManager.default.removeItem(at: historyURL)
    }

    // MARK: Snippets

    /// Returns nil when there is no snippets file yet, and throws when the
    /// file exists but can't be read, so the caller can keep it safe.
    public func loadSnippets() throws -> [SnippetFolder]? {
        guard FileManager.default.fileExists(atPath: snippetsURL.path) else { return nil }
        let data = try Data(contentsOf: snippetsURL)
        return try JSONDecoder().decode([SnippetFolder].self, from: data)
    }

    public func saveSnippets(_ folders: [SnippetFolder]) throws {
        try createDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(folders).write(to: snippetsURL, options: .atomic)
    }

    /// Renames an unreadable snippets file so it isn't overwritten.
    public func backUpSnippetsFile() {
        let backup = directory.appendingPathComponent("snippets-unreadable-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: snippetsURL, to: backup)
    }

    private func createDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
