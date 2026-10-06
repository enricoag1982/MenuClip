# MenuClip

A small menu bar clipboard manager for Apple Silicon Macs that works the way **ClipMenu** did. It is written from scratch in Swift and runs natively on arm64, with no Rosetta.

## What it does

- **Clipboard history in the menu bar.** Every copy is recorded: plain text, rich text (RTF/HTML), images, PDF and files copied in Finder. The newest item is on top, and older items are grouped into submenus: `1 - 10`, `11 - 20`, …
- **ClipMenu's shortcuts:**

  | Shortcut | Opens |
  |---|---|
  | ⇧⌘V | the full menu (history, snippets and commands) |
  | ⌃⌘V | history only |
  | ⇧⌘B | snippets only |

  Each menu opens at the mouse pointer. All three shortcuts can be changed or turned off in Settings.
- **Keyboard first.** In any menu, keys `1`…`9` and `0` pick the first ten items. You can also use the arrow keys and Return, or type the start of an item to jump to it.
- **Pastes for you.** Choosing an item puts it on the clipboard and sends ⌘V to the app you were using. Hold **⌥ Option** while choosing to paste plain text only.
- **Snippets.** Reusable text in folders, with a three-column editor. You can import and export them as XML in the format Clipy uses. Clipy is ClipMenu's open-source successor, and its import also reads ClipMenu exports.
- **Privacy.** Copies that password managers mark as concealed (the nspasteboard.org convention used by 1Password and others) are never recorded. Keychain Access and Passwords are excluded by default, and you can add any other app.
- **Settings** for history size, how many items appear before submenus start, title length, number keys, thumbnails, tooltips, recorded types, excluded apps, shortcuts and launch at login.

It needs macOS 13 Ventura or later.

## Install

### Option A: build it on your Mac (recommended)

You need the Xcode Command Line Tools (`xcode-select --install`). Full Xcode is not required.

```bash
git clone https://github.com/enricoag1982/MenuClip.git
cd MenuClip
./build.sh
cp -R build/MenuClip.app /Applications/
open /Applications/MenuClip.app
```

### Option B: download a build

Every build runs on GitHub's Apple Silicon runner.

- **Releases:** if the [Releases page](https://github.com/enricoag1982/MenuClip/releases) has a version, download `MenuClip.zip` and unzip it.
- **Latest build:** while signed in to GitHub, open the **Actions** tab, then **Build**, then the latest green run. Download the **MenuClip-arm64** artifact and unzip it twice (GitHub wraps the zip in another zip).

Then move `MenuClip.app` to `/Applications`.

The app is not notarized, so macOS blocks it the first time. Clear the download flag once:

```bash
xattr -dr com.apple.quarantine /Applications/MenuClip.app
```

Or try to open it, then go to **System Settings → Privacy & Security** and click **Open Anyway**.

## First run

1. A clipboard icon appears in the menu bar. There is no Dock icon, just like ClipMenu.
2. macOS asks for **Accessibility** access. This lets MenuClip press ⌘V for you. Turn MenuClip on under **System Settings → Privacy & Security → Accessibility**.
   - Without it, everything still works except the automatic paste. The chosen item is on the clipboard, so you press ⌘V yourself.
   - The build is signed ad hoc, so macOS treats each rebuild as a new app. After rebuilding, remove MenuClip from the Accessibility list with **−** and add it again.
3. Newer macOS versions may ask whether MenuClip can read what other apps copy ("Paste from Other Apps"). Choose **Allow**: a clipboard manager can't record history without it.
4. Optional: in **Settings → General**, turn on **Launch MenuClip at login**.

To open Settings, use the menu (**Settings…**), or open the app again from Finder or Spotlight while it is running.

## Moving over from ClipMenu

- **Snippets:** in ClipMenu, export your snippets to XML. In MenuClip, open **Edit Snippets…**, click the import/export button under the folder list and choose **Import…**. If the file doesn't import, the format differs from what Clipy reads; please open an issue with a sample.
- **History** is not imported. It starts fresh.
- **Not included:** ClipMenu's JavaScript "actions" (text transforms) and the option to pop the menu up at the text cursor instead of the mouse pointer.

## Where things are stored

| What | Where |
|---|---|
| History | `~/Library/Application Support/MenuClip/history.plist` (turn off **Remember history after quitting** to keep it only in memory) |
| Snippets | `~/Library/Application Support/MenuClip/snippets.json` |
| Settings | `~/Library/Preferences/io.github.enricoag1982.MenuClip.plist` |

Nothing leaves your Mac. The app makes no network connections.

To uninstall, quit MenuClip, delete the app and the files above, and remove it from **Accessibility** and **Login Items**.

## Development

```bash
swift test          # unit tests for history, titles, storage and snippet XML
swift run MenuClip  # run without making a bundle (paste needs the bundled app for Accessibility)
./build.sh          # build/MenuClip.app (arm64); ./build.sh universal for arm64 + Intel with full Xcode
```

| Part | Where |
|---|---|
| History logic, models, storage, snippet XML (no AppKit, unit-tested) | `Sources/MenuClipCore/` |
| Menu bar app: menus (`MenuController`), pasteboard polling (`ClipboardMonitor`), ⌘V (`PasteService`), global shortcuts via Carbon `RegisterEventHotKey` (`HotKeyCenter`), SwiftUI settings and snippet editor | `Sources/MenuClip/` |
| CI on an Apple Silicon runner: tests, builds, launches and uploads the app | `.github/workflows/build.yml` |

To publish a version, set `CFBundleShortVersionString` in `Resources/Info.plist`, then on GitHub choose **Releases → Draft a new release** and create a tag such as `v0.2.0`. When you publish it, CI builds the app and attaches `MenuClip.zip` to the release within a couple of minutes.

Shortcuts and paste use fixed key codes (V is key code 9). That is correct for QWERTY layouts such as US and Italian. On Dvorak or AZERTY, the default shortcuts sit on a different physical key; re-record them in Settings.

## License

[MIT](LICENSE). MenuClip is an independent project. It is not affiliated with ClipMenu or Clipy and shares no code with them.
