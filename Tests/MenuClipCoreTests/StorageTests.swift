import XCTest
@testable import MenuClipCore

final class StorageTests: XCTestCase {
    private var directory: URL!
    private var storage: Storage!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MenuClipTests-\(UUID().uuidString)", isDirectory: true)
        storage = Storage(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testHistoryRoundTrip() throws {
        let clips = [
            Clip(text: "hello", rtf: Data([1, 2])),
            Clip(image: Data([3, 4, 5])),
            Clip(text: "a.txt", fileURLs: [URL(fileURLWithPath: "/tmp/a.txt")], sourceBundleID: "com.apple.finder"),
        ]
        try storage.saveHistory(clips)
        XCTAssertEqual(storage.loadHistory(), clips)
    }

    func testMissingHistoryIsEmpty() {
        XCTAssertEqual(storage.loadHistory(), [])
    }

    func testSnippetsRoundTrip() throws {
        XCTAssertNil(try storage.loadSnippets())
        let folders = [SnippetFolder(title: "Work", snippets: [Snippet(title: "Hi", content: "Hello\nthere")])]
        try storage.saveSnippets(folders)
        XCTAssertEqual(try storage.loadSnippets(), folders)
    }

    func testUnreadableSnippetsThrowAndCanBeBackedUp() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: storage.snippetsURL)
        XCTAssertThrowsError(try storage.loadSnippets())
        storage.backUpSnippetsFile()
        XCTAssertNil(try storage.loadSnippets())
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertTrue(files.contains { $0.hasPrefix("snippets-unreadable-") })
    }
}
