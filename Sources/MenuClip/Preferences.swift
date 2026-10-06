import Foundation
import MenuClipCore

extension Notification.Name {
    static let hotKeysChanged = Notification.Name("MenuClip.hotKeysChanged")
    static let historyPreferencesChanged = Notification.Name("MenuClip.historyPreferencesChanged")
    static let hotKeyRecordingStarted = Notification.Name("MenuClip.hotKeyRecordingStarted")
    static let hotKeyRecordingEnded = Notification.Name("MenuClip.hotKeyRecordingEnded")
}

/// User settings, backed by UserDefaults. SwiftUI views bind to it directly.
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private enum Key {
        static let maxHistorySize = "maxHistorySize"
        static let inlineItemCount = "inlineItemCount"
        static let itemsPerFolder = "itemsPerFolder"
        static let maxTitleLength = "maxTitleLength"
        static let numericKeyEquivalents = "numericKeyEquivalents"
        static let showNumberPrefix = "showNumberPrefix"
        static let showImageThumbnails = "showImageThumbnails"
        static let showToolTips = "showToolTips"
        static let pasteAfterSelecting = "pasteAfterSelecting"
        static let reorderAfterPaste = "reorderAfterPaste"
        static let saveHistory = "saveHistory"
        static let storeRichText = "storeRichText"
        static let storeImages = "storeImages"
        static let storePDF = "storePDF"
        static let storeFiles = "storeFiles"
        static let excludedBundleIDs = "excludedBundleIDs"
        static let mainHotKey = "mainHotKey"
        static let historyHotKey = "historyHotKey"
        static let snippetsHotKey = "snippetsHotKey"
    }

    private let defaults: UserDefaults

    // MARK: History

    @Published var maxHistorySize: Int {
        didSet { defaults.set(maxHistorySize, forKey: Key.maxHistorySize); post(.historyPreferencesChanged) }
    }
    @Published var saveHistory: Bool {
        didSet { defaults.set(saveHistory, forKey: Key.saveHistory); post(.historyPreferencesChanged) }
    }
    @Published var pasteAfterSelecting: Bool {
        didSet { defaults.set(pasteAfterSelecting, forKey: Key.pasteAfterSelecting) }
    }
    @Published var reorderAfterPaste: Bool {
        didSet { defaults.set(reorderAfterPaste, forKey: Key.reorderAfterPaste) }
    }

    // MARK: Menu

    @Published var inlineItemCount: Int {
        didSet { defaults.set(inlineItemCount, forKey: Key.inlineItemCount) }
    }
    @Published var itemsPerFolder: Int {
        didSet { defaults.set(itemsPerFolder, forKey: Key.itemsPerFolder) }
    }
    @Published var maxTitleLength: Int {
        didSet { defaults.set(maxTitleLength, forKey: Key.maxTitleLength) }
    }
    @Published var numericKeyEquivalents: Bool {
        didSet { defaults.set(numericKeyEquivalents, forKey: Key.numericKeyEquivalents) }
    }
    @Published var showNumberPrefix: Bool {
        didSet { defaults.set(showNumberPrefix, forKey: Key.showNumberPrefix) }
    }
    @Published var showImageThumbnails: Bool {
        didSet { defaults.set(showImageThumbnails, forKey: Key.showImageThumbnails) }
    }
    @Published var showToolTips: Bool {
        didSet { defaults.set(showToolTips, forKey: Key.showToolTips) }
    }

    // MARK: Recorded types

    @Published var storeRichText: Bool {
        didSet { defaults.set(storeRichText, forKey: Key.storeRichText) }
    }
    @Published var storeImages: Bool {
        didSet { defaults.set(storeImages, forKey: Key.storeImages) }
    }
    @Published var storePDF: Bool {
        didSet { defaults.set(storePDF, forKey: Key.storePDF) }
    }
    @Published var storeFiles: Bool {
        didSet { defaults.set(storeFiles, forKey: Key.storeFiles) }
    }
    @Published var excludedBundleIDs: [String] {
        didSet { defaults.set(excludedBundleIDs, forKey: Key.excludedBundleIDs) }
    }

    // MARK: Shortcuts (nil means turned off)

    @Published var mainHotKey: HotKey? {
        didSet { store(mainHotKey, forKey: Key.mainHotKey) }
    }
    @Published var historyHotKey: HotKey? {
        didSet { store(historyHotKey, forKey: Key.historyHotKey) }
    }
    @Published var snippetsHotKey: HotKey? {
        didSet { store(snippetsHotKey, forKey: Key.snippetsHotKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.maxHistorySize: 30,
            Key.inlineItemCount: 0,
            Key.itemsPerFolder: 10,
            Key.maxTitleLength: 40,
            Key.numericKeyEquivalents: true,
            Key.showNumberPrefix: false,
            Key.showImageThumbnails: true,
            Key.showToolTips: true,
            Key.pasteAfterSelecting: true,
            Key.reorderAfterPaste: true,
            Key.saveHistory: true,
            Key.storeRichText: true,
            Key.storeImages: true,
            Key.storePDF: true,
            Key.storeFiles: true,
            Key.excludedBundleIDs: ["com.apple.keychainaccess", "com.apple.Passwords"],
        ])
        maxHistorySize = defaults.integer(forKey: Key.maxHistorySize)
        saveHistory = defaults.bool(forKey: Key.saveHistory)
        pasteAfterSelecting = defaults.bool(forKey: Key.pasteAfterSelecting)
        reorderAfterPaste = defaults.bool(forKey: Key.reorderAfterPaste)
        inlineItemCount = defaults.integer(forKey: Key.inlineItemCount)
        itemsPerFolder = defaults.integer(forKey: Key.itemsPerFolder)
        maxTitleLength = defaults.integer(forKey: Key.maxTitleLength)
        numericKeyEquivalents = defaults.bool(forKey: Key.numericKeyEquivalents)
        showNumberPrefix = defaults.bool(forKey: Key.showNumberPrefix)
        showImageThumbnails = defaults.bool(forKey: Key.showImageThumbnails)
        showToolTips = defaults.bool(forKey: Key.showToolTips)
        storeRichText = defaults.bool(forKey: Key.storeRichText)
        storeImages = defaults.bool(forKey: Key.storeImages)
        storePDF = defaults.bool(forKey: Key.storePDF)
        storeFiles = defaults.bool(forKey: Key.storeFiles)
        excludedBundleIDs = defaults.stringArray(forKey: Key.excludedBundleIDs) ?? []
        mainHotKey = Self.loadHotKey(defaults, key: Key.mainHotKey, fallback: .defaultMain)
        historyHotKey = Self.loadHotKey(defaults, key: Key.historyHotKey, fallback: .defaultHistory)
        snippetsHotKey = Self.loadHotKey(defaults, key: Key.snippetsHotKey, fallback: .defaultSnippets)
    }

    // A wrapper so that "turned off" (nil) can be stored and told apart from "never set".
    private struct StoredHotKey: Codable {
        var hotKey: HotKey?
    }

    private static func loadHotKey(_ defaults: UserDefaults, key: String, fallback: HotKey) -> HotKey? {
        guard let data = defaults.data(forKey: key),
              let stored = try? JSONDecoder().decode(StoredHotKey.self, from: data)
        else { return fallback }
        return stored.hotKey
    }

    private func store(_ hotKey: HotKey?, forKey key: String) {
        if let data = try? JSONEncoder().encode(StoredHotKey(hotKey: hotKey)) {
            defaults.set(data, forKey: key)
        }
        post(.hotKeysChanged)
    }

    private func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: self)
    }
}
