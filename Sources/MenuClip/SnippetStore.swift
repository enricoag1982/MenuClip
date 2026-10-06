import Foundation
import MenuClipCore

/// Holds the snippet folders and saves them shortly after each change.
final class SnippetStore: ObservableObject {
    @Published var folders: [SnippetFolder] {
        didSet { scheduleSave() }
    }

    private let storage: Storage
    private var pendingSave: DispatchWorkItem?

    init(storage: Storage) {
        self.storage = storage
        do {
            folders = try storage.loadSnippets() ?? Self.examples
        } catch {
            NSLog("MenuClip: snippets file unreadable, keeping a copy: \(error)")
            storage.backUpSnippetsFile()
            folders = []
        }
    }

    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        do {
            try storage.saveSnippets(folders)
        } catch {
            NSLog("MenuClip: could not save snippets: \(error)")
        }
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private static let examples = [
        SnippetFolder(title: "Examples", snippets: [
            Snippet(title: "Signature", content: "Best regards,\n\nYour Name"),
        ]),
    ]
}
