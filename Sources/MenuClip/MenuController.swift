import AppKit
import ImageIO
import MenuClipCore

/// Builds the ClipMenu-style menus and handles what the user picks in them.
final class MenuController: NSObject, NSMenuDelegate {
    enum Kind {
        case main, history, snippets
    }

    var openSettings: () -> Void = {}
    var openSnippetEditor: () -> Void = {}

    private let clipStore: ClipStore
    private let snippetStore: SnippetStore
    private let monitor: ClipboardMonitor
    private let prefs = Preferences.shared

    private struct ImageInfo {
        var pixelSize: CGSize?
        var thumbnail: NSImage?
    }
    private var imageInfoCache: [UUID: ImageInfo] = [:]
    private var fileIconCache: [UUID: NSImage] = [:]

    init(clipStore: ClipStore, snippetStore: SnippetStore, monitor: ClipboardMonitor) {
        self.clipStore = clipStore
        self.snippetStore = snippetStore
        self.monitor = monitor
    }

    /// Shows a menu at the mouse pointer, as ClipMenu does for its shortcuts.
    func popUp(_ kind: Kind) {
        let menu = NSMenu(title: "MenuClip")
        populate(menu, kind: kind)
        _ = menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    // The menu bar icon's menu is rebuilt each time it opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        populate(menu, kind: .main)
    }

    // MARK: - Building

    private func populate(_ menu: NSMenu, kind: Kind) {
        menu.removeAllItems()
        menu.autoenablesItems = false
        pruneCaches()

        switch kind {
        case .main:
            addHistory(to: menu)
            menu.addItem(.separator())
            if addSnippets(to: menu) {
                menu.addItem(.separator())
            }
            addCommands(to: menu)
        case .history:
            addHistory(to: menu)
            menu.addItem(.separator())
            menu.addItem(commandItem("Clear History…", #selector(clearHistory(_:))))
        case .snippets:
            if !addSnippets(to: menu) {
                menu.addItem(disabledItem("No snippets yet"))
            }
            menu.addItem(.separator())
            menu.addItem(commandItem("Edit Snippets…", #selector(editSnippets(_:))))
        }
    }

    private func addHistory(to menu: NSMenu) {
        menu.addItem(headerItem("History"))
        let clips = clipStore.clips
        guard !clips.isEmpty else {
            menu.addItem(disabledItem("Nothing copied yet"))
            return
        }

        let inlineCount = min(max(prefs.inlineItemCount, 0), clips.count)
        for (offset, clip) in clips.prefix(inlineCount).enumerated() {
            menu.addItem(item(for: clip, index: offset, position: offset))
        }

        // The rest goes into submenus of `itemsPerFolder`, titled "1 - 10", "11 - 20", …
        let perFolder = max(prefs.itemsPerFolder, 1)
        var start = inlineCount
        while start < clips.count {
            let end = min(start + perFolder, clips.count)
            let folder = NSMenuItem(title: "\(start + 1) - \(end)", action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: folder.title)
            submenu.autoenablesItems = false
            for (offset, clip) in clips[start..<end].enumerated() {
                submenu.addItem(item(for: clip, index: start + offset, position: offset))
            }
            folder.submenu = submenu
            menu.addItem(folder)
            start = end
        }
    }

    /// Returns false when there are no snippets to show.
    @discardableResult
    private func addSnippets(to menu: NSMenu) -> Bool {
        let folders = snippetStore.folders.filter { !$0.snippets.isEmpty }
        guard !folders.isEmpty else { return false }

        menu.addItem(headerItem("Snippets"))
        for folder in folders {
            let folderItem = NSMenuItem(title: folder.title.isEmpty ? "Untitled" : folder.title, action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: folderItem.title)
            submenu.autoenablesItems = false
            for (offset, snippet) in folder.snippets.enumerated() {
                let title = snippet.title.isEmpty ? snippet.content : snippet.title
                let item = NSMenuItem(
                    title: TitleFormatter.menuTitle(for: title, maxLength: prefs.maxTitleLength),
                    action: #selector(selectSnippet(_:)),
                    keyEquivalent: keyEquivalent(forPosition: offset)
                )
                item.keyEquivalentModifierMask = []
                item.target = self
                item.representedObject = snippet.content
                if prefs.showToolTips {
                    item.toolTip = String(snippet.content.prefix(1000))
                }
                submenu.addItem(item)
            }
            folderItem.submenu = submenu
            menu.addItem(folderItem)
        }
        return true
    }

    private func addCommands(to menu: NSMenu) {
        menu.addItem(commandItem("Clear History…", #selector(clearHistory(_:))))
        menu.addItem(commandItem("Edit Snippets…", #selector(editSnippets(_:))))
        menu.addItem(commandItem("Settings…", #selector(showSettings(_:))))
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit MenuClip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    private func item(for clip: Clip, index: Int, position: Int) -> NSMenuItem {
        var itemTitle = title(for: clip)
        if prefs.showNumberPrefix {
            itemTitle = "\(index + 1). " + itemTitle
        }
        let item = NSMenuItem(title: itemTitle, action: #selector(selectClip(_:)), keyEquivalent: keyEquivalent(forPosition: position))
        item.keyEquivalentModifierMask = []
        item.target = self
        item.representedObject = clip.id
        if prefs.showToolTips {
            item.toolTip = toolTip(for: clip)
        }
        switch clip.kind {
        case .image where prefs.showImageThumbnails:
            item.image = imageInfo(for: clip).thumbnail
        case .files:
            item.image = fileIcon(for: clip)
        default:
            break
        }
        return item
    }

    /// The first ten items of a menu get the keys 1…9 and 0, like ClipMenu.
    private func keyEquivalent(forPosition position: Int) -> String {
        guard prefs.numericKeyEquivalents, position < 10 else { return "" }
        return String((position + 1) % 10)
    }

    private func title(for clip: Clip) -> String {
        let maxLength = prefs.maxTitleLength
        switch clip.kind {
        case .text, .richText:
            return TitleFormatter.menuTitle(for: clip.text ?? "(rich text)", maxLength: maxLength)
        case .files:
            let names = clip.fileURLs.map(\.lastPathComponent)
            let title = names.count == 1 ? names[0] : "\(names[0]) and \(names.count - 1) more"
            return TitleFormatter.truncate(title, maxLength: maxLength)
        case .image:
            if let size = imageInfo(for: clip).pixelSize {
                return "Image \(Int(size.width)) × \(Int(size.height))"
            }
            return "Image"
        case .pdf:
            return "PDF"
        }
    }

    private func toolTip(for clip: Clip) -> String? {
        switch clip.kind {
        case .files:
            return clip.fileURLs.map(\.path).joined(separator: "\n")
        case .text, .richText:
            return clip.text.map { String($0.prefix(1000)) }
        case .image, .pdf:
            return nil
        }
    }

    private func headerItem(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) {
            return NSMenuItem.sectionHeader(title: title)
        }
        return disabledItem(title)
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func commandItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    // MARK: - Images

    private func imageInfo(for clip: Clip) -> ImageInfo {
        if let cached = imageInfoCache[clip.id] { return cached }
        var info = ImageInfo()
        if let data = clip.image, let source = CGImageSourceCreateWithData(data as CFData, nil) {
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
               let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
               let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
                info.pixelSize = CGSize(width: width, height: height)
            }
            let options = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 200,
            ] as CFDictionary
            if let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options) {
                // Fit into 100 × 32 points, about what ClipMenu used.
                let width = CGFloat(thumbnail.width)
                let height = CGFloat(thumbnail.height)
                let scale = min(100 / width, 32 / height, 1)
                info.thumbnail = NSImage(cgImage: thumbnail, size: NSSize(width: width * scale, height: height * scale))
            }
        }
        imageInfoCache[clip.id] = info
        return info
    }

    private func fileIcon(for clip: Clip) -> NSImage? {
        if let cached = fileIconCache[clip.id] { return cached }
        guard let first = clip.fileURLs.first else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: first.path)
        icon.size = NSSize(width: 16, height: 16)
        fileIconCache[clip.id] = icon
        return icon
    }

    private func pruneCaches() {
        let ids = Set(clipStore.clips.map(\.id))
        imageInfoCache = imageInfoCache.filter { ids.contains($0.key) }
        fileIconCache = fileIconCache.filter { ids.contains($0.key) }
    }

    // MARK: - Actions

    @objc private func selectClip(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID, let clip = clipStore.clip(withID: id) else { return }
        // Holding ⌥ while choosing pastes plain text only.
        let plainText = NSEvent.modifierFlags.contains(.option)
        PasteService.write(clip, plainTextOnly: plainText)
        monitor.skipCurrentContents()
        if prefs.reorderAfterPaste {
            clipStore.moveToTop(id)
        }
        pasteIfEnabled()
    }

    @objc private func selectSnippet(_ sender: NSMenuItem) {
        guard let content = sender.representedObject as? String else { return }
        PasteService.write(text: content)
        monitor.skipCurrentContents()
        pasteIfEnabled()
    }

    private func pasteIfEnabled() {
        // Without Accessibility access the item is still on the clipboard,
        // ready for a manual ⌘V.
        guard prefs.pasteAfterSelecting, PasteService.isTrusted(prompt: false) else { return }
        // Give the menu a moment to close so ⌘V reaches the app underneath.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            PasteService.sendPasteKeystroke()
        }
    }

    @objc private func clearHistory(_ sender: Any?) {
        bringAppToFront()
        let alert = NSAlert()
        alert.messageText = "Clear the clipboard history?"
        alert.informativeText = "This removes all \(clipStore.clips.count) items. Snippets are kept."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            clipStore.clear()
        }
    }

    @objc private func editSnippets(_ sender: Any?) {
        openSnippetEditor()
    }

    @objc private func showSettings(_ sender: Any?) {
        openSettings()
    }
}
