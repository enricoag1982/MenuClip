import Foundation

/// A global keyboard shortcut, stored as a virtual key code plus modifiers.
public struct HotKey: Codable, Equatable {
    public var keyCode: UInt32
    public var command: Bool
    public var shift: Bool
    public var option: Bool
    public var control: Bool
    /// What to show for the key itself, e.g. "V" or "F5".
    public var keyLabel: String

    public init(
        keyCode: UInt32,
        command: Bool = false,
        shift: Bool = false,
        option: Bool = false,
        control: Bool = false,
        keyLabel: String
    ) {
        self.keyCode = keyCode
        self.command = command
        self.shift = shift
        self.option = option
        self.control = control
        self.keyLabel = keyLabel
    }

    /// The shortcut written the way macOS menus show it, e.g. "⇧⌘V".
    public var displayString: String {
        (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "") + keyLabel
    }

    /// Modifier mask for Carbon's RegisterEventHotKey
    /// (cmdKey, shiftKey, optionKey and controlKey from Carbon.HIToolbox).
    public var carbonModifiers: UInt32 {
        var mask: UInt32 = 0
        if command { mask |= 0x0100 }
        if shift { mask |= 0x0200 }
        if option { mask |= 0x0800 }
        if control { mask |= 0x1000 }
        return mask
    }

    // The same defaults as ClipMenu. Key code 9 is V and 11 is B.
    public static let defaultMain = HotKey(keyCode: 9, command: true, shift: true, keyLabel: "V")
    public static let defaultHistory = HotKey(keyCode: 9, command: true, control: true, keyLabel: "V")
    public static let defaultSnippets = HotKey(keyCode: 11, command: true, shift: true, keyLabel: "B")
}
