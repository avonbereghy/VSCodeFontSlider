# Phase 1: Foundation

Read plans/fontdial_final_plan.md for full context. Read FontDial/.claude/CLAUDE.md for conventions.

## Goal
Create the Xcode project skeleton, the JSONC scanner, and the settings read/write engine. By the end, the app appears in the menu bar and can programmatically change a VS Code setting.

## Tasks
1. Create Xcode project `FontDial.xcodeproj` configured as a macOS app
   - Bundle ID: `com.fontdial.app`
   - Set `LSUIElement = YES` in Info.plist (no Dock icon)
   - No SPM dependencies
   - Target macOS 14+

2. Create `FontDial/FontDialApp.swift`:
   - `@main` app with `@NSApplicationDelegateAdaptor`
   - AppDelegate sets up `NSStatusItem` with `textformat.size` SF Symbol
   - Left-click toggles an empty SwiftUI popover (`.transient` behavior)
   - Right-click shows context menu with "Quit FontDial"

3. Create `FontDial/JSONCScanner.swift`:
   - `static func strip(_ text: String) -> String` — state-aware removal of `//` line comments, `/* */` block comments, and trailing commas. Tracks `inString` state (handling escaped quotes) to avoid destroying URLs or string content containing `//`. Returns valid JSON.
   - `static func findValueRange(forKey key: String, in text: String) -> Range<String.Index>?` — walks the raw text tracking state (normal/inString/inLineComment/inBlockComment) and nesting depth. Finds the key at nesting depth 1 (top-level of the root object, not inside nested objects like `[python]`). Returns the character range of the value (number, string, boolean, or null).
   - `static func insertionPoint(in text: String) -> String.Index?` — finds the position just before the top-level closing `}` for inserting new keys.

4. Create `FontDial/SettingsManager.swift`:
   - `@Observable class SettingsManager`
   - `let settingsURL` pointing to `~/Library/Application Support/Code/User/settings.json`
   - `func load()` — reads file, strips via JSONCScanner, parses via JSONSerialization, extracts three keys with VS Code default fallbacks (14, 14, 0.0)
   - `func save()` — 200ms debounced. Reads fresh raw text, uses JSONCScanner.findValueRange to locate each changed key, replaces value in raw text, atomic write (temp file + rename). Stores SHA256 hash of written content. All operations wrapped in do/catch — errors set an `errorMessage` published property.
   - Published properties: `zoomLevel: Double`, `editorFontSize: Int`, `terminalFontSize: Int`, `errorMessage: String?`

5. Create `FontDial/FontSettings.swift`:
   - `FontSettings` struct with three properties
   - Static presets: `.compact`, `.standard`, `.relaxed`, `.vsCodeDefaults`

6. Create `build.sh`:
   - `xcodebuild -project FontDial.xcodeproj -scheme FontDial -configuration Release build`
   - Copy .app to `~/Applications/`
   - Make executable: `chmod +x build.sh`

## Files to create
- `FontDial/FontDial.xcodeproj/` (Xcode project)
- `FontDial/FontDial/FontDialApp.swift`
- `FontDial/FontDial/JSONCScanner.swift`
- `FontDial/FontDial/SettingsManager.swift`
- `FontDial/FontDial/FontSettings.swift`
- `FontDial/FontDial/Info.plist`
- `FontDial/FontDial/Assets.xcassets/`
- `FontDial/build.sh`

## Files NOT to touch
- plans/*
- Any file outside FontDial/

## Verification
1. Run `./build.sh` — builds successfully
2. Launch app — menu bar icon appears, no Dock icon
3. Click icon — empty popover appears
4. Right-click icon — "Quit FontDial" menu item works
5. In code: call `settingsManager.load()` then modify a value and `save()` — VS Code picks up the change
6. Verify: settings.json comments are preserved after a write
