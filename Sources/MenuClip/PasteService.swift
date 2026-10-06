import AppKit
import MenuClipCore

/// Puts clips back on the pasteboard and sends ⌘V to the frontmost app.
enum PasteService {
    static func write(_ clip: Clip, plainTextOnly: Bool, to pasteboard: NSPasteboard = .general) {
        if plainTextOnly, let text = clip.text {
            write(text: text, to: pasteboard)
            return
        }

        pasteboard.clearContents()
        if !clip.fileURLs.isEmpty {
            pasteboard.writeObjects(clip.fileURLs as [NSURL])
            return
        }

        // Richest formats first: apps generally take the first type they understand.
        let item = NSPasteboardItem()
        if let rtfd = clip.rtfd { item.setData(rtfd, forType: .rtfd) }
        if let rtf = clip.rtf { item.setData(rtf, forType: .rtf) }
        if let html = clip.html { item.setData(html, forType: .html) }
        if let text = clip.text { item.setString(text, forType: .string) }
        if let pdf = clip.pdf { item.setData(pdf, forType: .pdf) }
        if let png = clip.image {
            item.setData(png, forType: .png)
            // Some older apps only read TIFF.
            if let tiff = NSBitmapImageRep(data: png)?.tiffRepresentation {
                item.setData(tiff, forType: .tiff)
            }
        }
        pasteboard.writeObjects([item])
    }

    static func write(text: String, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Whether MenuClip may send keystrokes (System Settings → Privacy &
    /// Security → Accessibility). With `prompt`, macOS asks the user.
    static func isTrusted(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Sends ⌘V. Key code 9 is the V key on ANSI and ISO (e.g. Italian) keyboards.
    static func sendPasteKeystroke() {
        let source = CGEventSource(stateID: .combinedSessionState)
        // Keep keys the user is still holding from mixing into the ⌘V.
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        let vKey: CGKeyCode = 9
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
