import XCTest
@testable import MenuClipCore

final class SnippetXMLTests: XCTestCase {
    func testRoundTripKeepsTextExactly() throws {
        let folders = [
            SnippetFolder(title: "Code & <Tags>", snippets: [
                Snippet(title: "Indented", content: "  first line\n\tsecond line\n"),
                Snippet(title: "Quotes", content: "\"double\" 'single' – ✓ 🎉"),
            ]),
            SnippetFolder(title: "Empty"),
        ]
        let parsed = try SnippetXML.parse(SnippetXML.export(folders))
        XCTAssertEqual(parsed.map(\.title), ["Code & <Tags>", "Empty"])
        XCTAssertEqual(parsed[0].snippets.map(\.title), ["Indented", "Quotes"])
        XCTAssertEqual(parsed[0].snippets.map(\.content), folders[0].snippets.map(\.content))
        XCTAssertEqual(parsed[1].snippets, [])
    }

    func testParsesClipyStyleExport() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <folders>
            <folder>
                <title>Mail</title>
                <snippets>
                    <snippet>
                        <title>Thanks</title>
                        <content>Thank you!</content>
                    </snippet>
                </snippets>
            </folder>
        </folders>
        """
        let folders = try SnippetXML.parse(Data(xml.utf8))
        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders[0].title, "Mail")
        XCTAssertEqual(folders[0].snippets.first?.title, "Thanks")
        XCTAssertEqual(folders[0].snippets.first?.content, "Thank you!")
    }

    func testRejectsOtherXML() {
        XCTAssertThrowsError(try SnippetXML.parse(Data("<plist></plist>".utf8))) { error in
            XCTAssertEqual(error as? SnippetXML.ParseError, .notSnippetXML)
        }
    }
}
