import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers
import MenuClipCore

struct SettingsView: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        TabView {
            GeneralPane(prefs: prefs)
                .tabItem { Label("General", systemImage: "gearshape") }
            MenuPane(prefs: prefs)
                .tabItem { Label("Menu", systemImage: "list.bullet") }
            TypesPane(prefs: prefs)
                .tabItem { Label("Types", systemImage: "doc.on.doc") }
            ExcludedAppsPane(prefs: prefs)
                .tabItem { Label("Excluded Apps", systemImage: "hand.raised") }
            ShortcutsPane(prefs: prefs)
                .tabItem { Label("Shortcuts", systemImage: "command") }
        }
        .padding()
        .frame(width: 560, height: 400)
    }
}

// MARK: - General

private struct GeneralPane: View {
    @ObservedObject var prefs: Preferences
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var accessibilityGranted = PasteService.isTrusted(prompt: false)
    private let accessibilityCheck = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Toggle("Launch MenuClip at login", isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in
                    LaunchAtLogin.setEnabled(newValue)
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
            ))

            Section {
                Toggle("Paste right away after choosing an item", isOn: $prefs.pasteAfterSelecting)
                if prefs.pasteAfterSelecting && !accessibilityGranted {
                    HStack {
                        Text("Pasting for you needs Accessibility access.")
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Grant Access…") {
                            _ = PasteService.isTrusted(prompt: true)
                            PasteService.openAccessibilitySettings()
                        }
                    }
                }
                Toggle("Move a pasted item to the top of the history", isOn: $prefs.reorderAfterPaste)
            } footer: {
                Text("Hold ⌥ Option while choosing an item to paste it as plain text.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section {
                Stepper("Keep \(prefs.maxHistorySize) items", value: $prefs.maxHistorySize, in: 5...500, step: 5)
                Toggle("Remember history after quitting", isOn: $prefs.saveHistory)
            } header: {
                Text("History")
            }
        }
        .formStyle(.grouped)
        .onReceive(accessibilityCheck) { _ in
            accessibilityGranted = PasteService.isTrusted(prompt: false)
        }
    }
}

// MARK: - Menu

private struct MenuPane: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Section {
                Stepper("Items shown directly in the menu: \(prefs.inlineItemCount)", value: $prefs.inlineItemCount, in: 0...50)
                Stepper("Items per submenu: \(prefs.itemsPerFolder)", value: $prefs.itemsPerFolder, in: 5...50)
                Stepper("Longest title: \(prefs.maxTitleLength) characters", value: $prefs.maxTitleLength, in: 10...200, step: 5)
            }
            Section {
                Toggle("Number keys 1–9 and 0 choose items", isOn: $prefs.numericKeyEquivalents)
                Toggle("Show numbers in front of items", isOn: $prefs.showNumberPrefix)
                Toggle("Show image thumbnails", isOn: $prefs.showImageThumbnails)
                Toggle("Show the full text as a tooltip", isOn: $prefs.showToolTips)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Types

private struct TypesPane: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Section {
                Toggle("Rich text (RTF and HTML formatting)", isOn: $prefs.storeRichText)
                Toggle("Images", isOn: $prefs.storeImages)
                Toggle("PDF", isOn: $prefs.storePDF)
                Toggle("Files copied in Finder", isOn: $prefs.storeFiles)
            } header: {
                Text("Besides plain text, record:")
            } footer: {
                Text("Copies that password managers mark as concealed are never recorded.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Excluded apps

private struct ExcludedAppsPane: View {
    @ObservedObject var prefs: Preferences
    @State private var selection: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing copied while one of these apps is in front is recorded.")
                .foregroundColor(.secondary)
            List(selection: $selection) {
                ForEach(prefs.excludedBundleIDs, id: \.self) { bundleID in
                    HStack {
                        Image(nsImage: AppInfo.icon(for: bundleID))
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text(AppInfo.name(for: bundleID))
                        Spacer()
                        Text(bundleID)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(bundleID)
                }
            }
            .border(Color(nsColor: .separatorColor))
            HStack(spacing: 4) {
                Button { addApp() } label: { Image(systemName: "plus") }
                Button {
                    prefs.excludedBundleIDs.removeAll { $0 == selection }
                    selection = nil
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection == nil)
            }
        }
        .padding()
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Exclude"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let bundleID = Bundle(url: url)?.bundleIdentifier, !prefs.excludedBundleIDs.contains(bundleID) {
                prefs.excludedBundleIDs.append(bundleID)
            }
        }
    }
}

private enum AppInfo {
    static func name(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
    }

    static func icon(for bundleID: String) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .application)
    }
}

// MARK: - Shortcuts

private struct ShortcutsPane: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Section {
                LabeledContent("Full menu") { ShortcutRecorder(hotKey: $prefs.mainHotKey) }
                LabeledContent("History only") { ShortcutRecorder(hotKey: $prefs.historyHotKey) }
                LabeledContent("Snippets only") { ShortcutRecorder(hotKey: $prefs.snippetsHotKey) }
            } footer: {
                Text("Click a shortcut, then press the new keys. Press Delete to turn it off, or Esc to cancel.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
