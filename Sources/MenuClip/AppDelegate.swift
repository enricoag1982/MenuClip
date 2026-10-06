import AppKit
import SwiftUI
import MenuClipCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let prefs = Preferences.shared
    private let storage = Storage(directory: Storage.defaultDirectory)
    private let monitor = ClipboardMonitor()
    private var clipStore: ClipStore!
    private var snippetStore: SnippetStore!
    private var menuController: MenuController!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var snippetWindow: NSWindow?
    private var isRecordingHotKey = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()

        clipStore = ClipStore(storage: storage)
        snippetStore = SnippetStore(storage: storage)
        menuController = MenuController(clipStore: clipStore, snippetStore: snippetStore, monitor: monitor)
        menuController.openSettings = { [weak self] in self?.showSettings() }
        menuController.openSnippetEditor = { [weak self] in self?.showSnippetEditor() }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "MenuClip")
            image?.isTemplate = true
            button.image = image
        }
        let statusMenu = NSMenu(title: "MenuClip")
        statusMenu.delegate = menuController
        statusItem.menu = statusMenu

        monitor.onNewClip = { [weak self] clip in self?.clipStore.add(clip) }
        monitor.start()

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(hotKeysChanged), name: .hotKeysChanged, object: nil)
        center.addObserver(self, selector: #selector(historyPreferencesChanged), name: .historyPreferencesChanged, object: nil)
        center.addObserver(self, selector: #selector(hotKeyRecordingStarted), name: .hotKeyRecordingStarted, object: nil)
        center.addObserver(self, selector: #selector(hotKeyRecordingEnded), name: .hotKeyRecordingEnded, object: nil)
        registerHotKeys()

        if prefs.pasteAfterSelecting && !PasteService.isTrusted(prompt: false) {
            // Shows the system dialog that leads to Accessibility settings.
            _ = PasteService.isTrusted(prompt: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipStore.saveNow()
        snippetStore.saveNow()
    }

    /// Opening the app again (e.g. from Finder) shows Settings, since there is no Dock icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    // MARK: - Shortcuts

    private func registerHotKeys() {
        let center = HotKeyCenter.shared
        center.unregisterAll()
        if let key = prefs.mainHotKey {
            center.register(key) { [weak self] in self?.menuController.popUp(.main) }
        }
        if let key = prefs.historyHotKey {
            center.register(key) { [weak self] in self?.menuController.popUp(.history) }
        }
        if let key = prefs.snippetsHotKey {
            center.register(key) { [weak self] in self?.menuController.popUp(.snippets) }
        }
    }

    @objc private func hotKeysChanged() {
        if !isRecordingHotKey { registerHotKeys() }
    }

    // While a new shortcut is being typed, the current ones must not fire.
    @objc private func hotKeyRecordingStarted() {
        isRecordingHotKey = true
        HotKeyCenter.shared.unregisterAll()
    }

    @objc private func hotKeyRecordingEnded() {
        isRecordingHotKey = false
        registerHotKeys()
    }

    @objc private func historyPreferencesChanged() {
        clipStore.applyPreferences()
    }

    // MARK: - Windows

    private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(prefs: prefs)))
            window.title = "MenuClip Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        show(settingsWindow)
    }

    private func showSnippetEditor() {
        if snippetWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SnippetEditorView(store: snippetStore)))
            window.title = "MenuClip Snippets"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 820, height: 480))
            window.center()
            window.setFrameAutosaveName("SnippetEditor")
            snippetWindow = window
        }
        show(snippetWindow)
    }

    private func show(_ window: NSWindow?) {
        bringAppToFront()
        window?.makeKeyAndOrderFront(nil)
    }
}

/// Makes MenuClip the active app so its windows and alerts come to the front.
func bringAppToFront() {
    if #available(macOS 14.0, *) {
        NSApp.activate()
    } else {
        NSApp.activate(ignoringOtherApps: true)
    }
}
