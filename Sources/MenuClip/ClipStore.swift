import Foundation
import MenuClipCore

/// Holds the clipboard history and saves it to disk in the background.
final class ClipStore {
    private(set) var history: ClipHistory
    private let storage: Storage
    private let prefs = Preferences.shared
    private let ioQueue = DispatchQueue(label: "MenuClip.history-io", qos: .utility)
    private var pendingSave: DispatchWorkItem?

    var clips: [Clip] { history.clips }

    init(storage: Storage) {
        self.storage = storage
        let saved = Preferences.shared.saveHistory ? storage.loadHistory() : []
        history = ClipHistory(clips: saved)
        history.trim(to: Preferences.shared.maxHistorySize)
    }

    func clip(withID id: UUID) -> Clip? {
        history.clip(withID: id)
    }

    func add(_ clip: Clip) {
        history.add(clip, limit: prefs.maxHistorySize)
        scheduleSave()
    }

    func moveToTop(_ id: UUID) {
        history.moveToTop(id: id)
        scheduleSave()
    }

    func clear() {
        history.removeAll()
        scheduleSave()
    }

    /// Re-applies the history size and the "remember history" setting.
    func applyPreferences() {
        history.trim(to: prefs.maxHistorySize)
        scheduleSave()
    }

    /// Writes immediately. Called when the app quits.
    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        let clips = history.clips
        let storage = storage
        let persist = prefs.saveHistory
        ioQueue.sync {
            if persist {
                try? storage.saveHistory(clips)
            } else {
                storage.deleteHistory()
            }
        }
    }

    /// Waits a moment so a burst of copies leads to one write.
    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveInBackground() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    private func saveInBackground() {
        pendingSave = nil
        let clips = history.clips
        let storage = storage
        let persist = prefs.saveHistory
        ioQueue.async {
            if persist {
                do {
                    try storage.saveHistory(clips)
                } catch {
                    NSLog("MenuClip: could not save history: \(error)")
                }
            } else {
                storage.deleteHistory()
            }
        }
    }
}
