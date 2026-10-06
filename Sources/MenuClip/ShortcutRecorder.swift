import AppKit
import Carbon
import SwiftUI
import MenuClipCore

/// A button that records the next key combination typed as a global shortcut.
struct ShortcutRecorder: View {
    @Binding var hotKey: HotKey?
    @StateObject private var recorder = ShortcutRecorderModel()

    var body: some View {
        Button {
            if recorder.isRecording {
                recorder.stop()
            } else {
                recorder.start { hotKey = $0 }
            }
        } label: {
            Text(recorder.isRecording ? "Type shortcut…" : (hotKey?.displayString ?? "None"))
                .frame(minWidth: 110)
        }
        .onDisappear { recorder.stop() }
    }
}

final class ShortcutRecorderModel: ObservableObject {
    @Published private(set) var isRecording = false
    private var monitor: Any?
    private var onRecord: ((HotKey?) -> Void)?

    /// `onRecord` gets the new shortcut, or nil when the user pressed Delete.
    func start(onRecord: @escaping (HotKey?) -> Void) {
        stop()
        self.onRecord = onRecord
        isRecording = true
        NotificationCenter.default.post(name: .hotKeyRecordingStarted, object: nil)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
            return nil
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        onRecord = nil
        if isRecording {
            isRecording = false
            NotificationCenter.default.post(name: .hotKeyRecordingEnded, object: nil)
        }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func handle(_ event: NSEvent) {
        let keyCode = Int(event.keyCode)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if keyCode == kVK_Escape && flags.isEmpty {
            stop()
            return
        }
        if (keyCode == kVK_Delete || keyCode == kVK_ForwardDelete) && flags.isEmpty {
            onRecord?(nil)
            stop()
            return
        }
        // A global shortcut needs ⌘, ⌃ or ⌥, except for function keys.
        let isFunctionKey = KeyLabel.functionKeys[keyCode] != nil
        guard isFunctionKey || flags.contains(.command) || flags.contains(.control) || flags.contains(.option) else {
            NSSound.beep()
            return
        }
        onRecord?(HotKey(
            keyCode: UInt32(event.keyCode),
            command: flags.contains(.command),
            shift: flags.contains(.shift),
            option: flags.contains(.option),
            control: flags.contains(.control),
            keyLabel: KeyLabel.label(for: event)
        ))
        stop()
    }
}

enum KeyLabel {
    static let functionKeys: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17",
        kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    private static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋",
        kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
    ]

    static func label(for event: NSEvent) -> String {
        let keyCode = Int(event.keyCode)
        if let name = functionKeys[keyCode] ?? specialKeys[keyCode] {
            return name
        }
        let characters = event.charactersIgnoringModifiers?.uppercased() ?? ""
        return characters.isEmpty ? "Key \(keyCode)" : characters
    }
}
