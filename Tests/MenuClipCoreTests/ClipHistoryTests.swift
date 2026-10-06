import XCTest
@testable import MenuClipCore

final class ClipHistoryTests: XCTestCase {
    func testNewClipsGoOnTop() {
        var history = ClipHistory()
        history.add(Clip(text: "first"), limit: 10)
        history.add(Clip(text: "second"), limit: 10)
        XCTAssertEqual(history.clips.map(\.text), ["second", "first"])
    }

    func testCopyingSameTextAgainMovesItUpWithoutDuplicating() {
        var history = ClipHistory()
        history.add(Clip(text: "a"), limit: 10)
        history.add(Clip(text: "b"), limit: 10)
        history.add(Clip(text: "a", rtf: Data([1])), limit: 10)
        XCTAssertEqual(history.clips.map(\.text), ["a", "b"])
        XCTAssertEqual(history.clips.first?.rtf, Data([1]), "the newer copy should win")
    }

    func testLimitDropsOldest() {
        var history = ClipHistory()
        for i in 1...5 {
            history.add(Clip(text: "\(i)"), limit: 3)
        }
        XCTAssertEqual(history.clips.map(\.text), ["5", "4", "3"])
        history.trim(to: 1)
        XCTAssertEqual(history.clips.map(\.text), ["5"])
    }

    func testMoveToTop() {
        var history = ClipHistory()
        let old = Clip(text: "old")
        history.add(old, limit: 10)
        history.add(Clip(text: "new"), limit: 10)
        history.moveToTop(id: old.id)
        XCTAssertEqual(history.clips.map(\.text), ["old", "new"])
    }

    func testImagesAreComparedByData() {
        let a = Clip(image: Data([1, 2, 3]))
        XCTAssertTrue(a.hasSameContent(as: Clip(image: Data([1, 2, 3]))))
        XCTAssertFalse(a.hasSameContent(as: Clip(image: Data([9]))))
        XCTAssertFalse(a.hasSameContent(as: Clip(text: "x", image: Data([1, 2, 3]))))
    }

    func testFilesAreComparedByURL() {
        let a = Clip(text: "a.txt", fileURLs: [URL(fileURLWithPath: "/tmp/a.txt")])
        XCTAssertTrue(a.hasSameContent(as: Clip(fileURLs: [URL(fileURLWithPath: "/tmp/a.txt")])))
        XCTAssertFalse(a.hasSameContent(as: Clip(text: "a.txt")))
    }

    func testKind() {
        XCTAssertEqual(Clip(text: "x").kind, .text)
        XCTAssertEqual(Clip(text: "x", rtf: Data()).kind, .richText)
        XCTAssertEqual(Clip(text: "  ", image: Data([1])).kind, .image)
        XCTAssertEqual(Clip(pdf: Data([1])).kind, .pdf)
        XCTAssertEqual(Clip(text: "a", fileURLs: [URL(fileURLWithPath: "/a")]).kind, .files)
        XCTAssertTrue(Clip().isEmpty)
    }
}

final class TitleFormatterTests: XCTestCase {
    func testCollapsesWhitespaceAndLineBreaks() {
        XCTAssertEqual(TitleFormatter.menuTitle(for: "  hello\n\n\tworld  ", maxLength: 40), "hello world")
    }

    func testTruncatesWithEllipsis() {
        XCTAssertEqual(TitleFormatter.menuTitle(for: "abcdefghij", maxLength: 5), "abcd…")
        XCTAssertEqual(TitleFormatter.menuTitle(for: "abcde", maxLength: 5), "abcde")
    }

    func testBlankText() {
        XCTAssertEqual(TitleFormatter.menuTitle(for: " \n ", maxLength: 40), "(whitespace)")
    }
}

final class HotKeyTests: XCTestCase {
    func testDisplayStringUsesMacOrder() {
        let key = HotKey(keyCode: 9, command: true, shift: true, option: true, control: true, keyLabel: "V")
        XCTAssertEqual(key.displayString, "⌃⌥⇧⌘V")
        XCTAssertEqual(HotKey.defaultMain.displayString, "⇧⌘V")
    }

    func testCarbonModifiers() {
        XCTAssertEqual(HotKey.defaultMain.carbonModifiers, 0x0100 | 0x0200)
        XCTAssertEqual(HotKey.defaultHistory.carbonModifiers, 0x0100 | 0x1000)
    }
}
