import AppKit
import SwiftUI
import UniformTypeIdentifiers
import MenuClipCore

/// Three columns: folders, the snippets in the selected folder, and the selected snippet.
struct SnippetEditorView: View {
    @ObservedObject var store: SnippetStore
    @State private var folderID: SnippetFolder.ID?
    @State private var snippetID: Snippet.ID?
    @State private var confirmingFolderDeletion = false

    var body: some View {
        HSplitView {
            folderColumn
                .frame(minWidth: 170, idealWidth: 190, maxWidth: 280)
            snippetColumn
                .frame(minWidth: 190, idealWidth: 230, maxWidth: 340)
            editorColumn
                .frame(minWidth: 320, maxWidth: .infinity)
        }
        .frame(minWidth: 720, minHeight: 380)
        .onChange(of: folderID) { _ in snippetID = nil }
        .alert("Delete this folder and its snippets?", isPresented: $confirmingFolderDeletion) {
            Button("Delete", role: .destructive) { deleteSelectedFolder() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Columns

    private var folderColumn: some View {
        VStack(spacing: 0) {
            List(selection: $folderID) {
                ForEach(store.folders) { folder in
                    Label(folder.title.isEmpty ? "Untitled" : folder.title, systemImage: "folder")
                }
                .onMove { store.folders.move(fromOffsets: $0, toOffset: $1) }
            }
            bottomBar {
                Button { addFolder() } label: { Image(systemName: "plus") }
                    .help("New folder")
                Button {
                    if selectedFolder?.snippets.isEmpty ?? true {
                        deleteSelectedFolder()
                    } else {
                        confirmingFolderDeletion = true
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .help("Delete folder")
                .disabled(folderID == nil)
                Spacer()
                Menu {
                    Button("Import…") { importSnippets() }
                    Button("Export…") { exportSnippets() }
                } label: {
                    Image(systemName: "square.and.arrow.up.on.square")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Import or export snippets as XML")
            }
        }
    }

    @ViewBuilder
    private var snippetColumn: some View {
        if let folder = selectedFolder {
            VStack(spacing: 0) {
                TextField("Folder name", text: folderTitleBinding(folder.id))
                    .textFieldStyle(.roundedBorder)
                    .padding(8)
                List(selection: $snippetID) {
                    ForEach(folder.snippets) { snippet in
                        Text(snippet.title.isEmpty ? "Untitled" : snippet.title)
                            .lineLimit(1)
                    }
                    .onMove { offsets, destination in
                        updateFolder(folder.id) { $0.snippets.move(fromOffsets: offsets, toOffset: destination) }
                    }
                }
                bottomBar {
                    Button { addSnippet(to: folder.id) } label: { Image(systemName: "plus") }
                        .help("New snippet")
                    Button { deleteSelectedSnippet() } label: { Image(systemName: "minus") }
                        .help("Delete snippet")
                        .disabled(snippetID == nil)
                    Spacer()
                }
            }
        } else {
            placeholder("Select or add a folder")
        }
    }

    @ViewBuilder
    private var editorColumn: some View {
        if let folderID, let snippetID, selectedSnippet != nil {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Title", text: snippetBinding(folderID, snippetID, \.title))
                    .textFieldStyle(.roundedBorder)
                PlainTextEditor(text: snippetBinding(folderID, snippetID, \.content))
                    .id(snippetID)
                    .border(Color(nsColor: .separatorColor))
                Text("Choosing a snippet from the menu pastes this text.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(8)
        } else {
            placeholder("Select or add a snippet")
        }
    }

    private func bottomBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 4) { content() }
            .buttonStyle(.borderless)
            .padding(6)
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Selection and bindings
    //
    // Bindings look items up by id each time, so a deleted item can't be
    // reached through a stale index.

    private var selectedFolder: SnippetFolder? {
        store.folders.first { $0.id == folderID }
    }

    private var selectedSnippet: Snippet? {
        selectedFolder?.snippets.first { $0.id == snippetID }
    }

    private func updateFolder(_ id: SnippetFolder.ID, _ change: (inout SnippetFolder) -> Void) {
        guard let index = store.folders.firstIndex(where: { $0.id == id }) else { return }
        change(&store.folders[index])
    }

    private func folderTitleBinding(_ id: SnippetFolder.ID) -> Binding<String> {
        Binding(
            get: { store.folders.first { $0.id == id }?.title ?? "" },
            set: { newValue in updateFolder(id) { $0.title = newValue } }
        )
    }

    private func snippetBinding(
        _ folderID: SnippetFolder.ID,
        _ snippetID: Snippet.ID,
        _ field: WritableKeyPath<Snippet, String>
    ) -> Binding<String> {
        Binding(
            get: {
                store.folders.first { $0.id == folderID }?
                    .snippets.first { $0.id == snippetID }?[keyPath: field] ?? ""
            },
            set: { newValue in
                updateFolder(folderID) { folder in
                    if let index = folder.snippets.firstIndex(where: { $0.id == snippetID }) {
                        folder.snippets[index][keyPath: field] = newValue
                    }
                }
            }
        )
    }

    // MARK: Actions

    private func addFolder() {
        let folder = SnippetFolder(title: "New Folder")
        store.folders.append(folder)
        folderID = folder.id
    }

    private func deleteSelectedFolder() {
        store.folders.removeAll { $0.id == folderID }
        folderID = nil
    }

    private func addSnippet(to folderID: SnippetFolder.ID) {
        let snippet = Snippet(title: "New Snippet", content: "")
        updateFolder(folderID) { $0.snippets.append(snippet) }
        snippetID = snippet.id
    }

    private func deleteSelectedSnippet() {
        guard let folderID, let snippetID else { return }
        updateFolder(folderID) { folder in folder.snippets.removeAll { $0.id == snippetID } }
        self.snippetID = nil
    }

    private func importSnippets() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.xml]
        panel.message = "Choose a snippets XML file exported from MenuClip, Clipy or ClipMenu."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let imported = try SnippetXML.parse(Data(contentsOf: url))
            store.folders.append(contentsOf: imported)
        } catch {
            showError("Could not import snippets", error)
        }
    }

    private func exportSnippets() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.xml]
        panel.nameFieldStringValue = "snippets.xml"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try SnippetXML.export(store.folders).write(to: url, options: .atomic)
        } catch {
            showError("Could not export snippets", error)
        }
    }

    private func showError(_ message: String, _ error: Error) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}

/// A plain-text editor with smart quotes, dashes and autocorrect turned off,
/// so snippets of code or commands are kept exactly as typed.
struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.string = text
        textView.delegate = context.coordinator
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        guard let textView = scrollView.documentView as? NSTextView, textView.string != text else { return }
        textView.string = text
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}
