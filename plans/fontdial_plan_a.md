# FontDial -- Product & Technical Plan

## 1. Core Product Idea

**FontDial** is a macOS menu bar utility that gives you three independent dials for the three text-size dimensions inside VS Code: sidebar/chrome, editor, and integrated terminal (where Claude Code lives). Instead of hunting through VS Code settings or memorizing keyboard shortcuts, you click a menu bar icon, see three sliders, and drag.

### The Problem

VS Code conflates UI chrome scaling (`window.zoomLevel`) with editor font size (`editor.fontSize`) and terminal font size (`terminal.integrated.fontSize`). Adjusting one often means the others feel wrong. People who pair Claude Code in the integrated terminal with normal editing constantly toggle between "I need the terminal text bigger to read Claude's output" and "I need the editor text bigger for code review" -- but bumping zoom to fix one breaks the other.

### Use Case

A developer working with Claude Code in VS Code's integrated terminal wants:
- A compact sidebar (zoom level slightly negative or zero) so file trees don't eat horizontal space
- A comfortable editor font (14-16px) for writing code
- A larger terminal font (15-18px) so Claude Code responses are easy to scan

Today this requires opening Settings, finding three separate keys, and typing numbers. FontDial makes it three sliders accessible in one click from the menu bar.

### Product Vision

A single-purpose, zero-config tool that does one thing perfectly: control VS Code's three text-size axes from the menu bar. No login, no cloud, no bloat.

---

## 2. Tech Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Language | Swift 5.9+ | Native performance, direct macOS API access |
| UI framework | SwiftUI | Declarative, lightweight, perfect for popover UIs |
| Settings I/O | Foundation `JSONSerialization` | VS Code settings.json is JSON; no external dependencies needed |
| File watching | `DispatchSource.makeFileSystemObjectSource` (GCD) or `FileManager` polling | Detect external settings.json changes without third-party libs |
| Build system | Xcode project via `project.yml` (XcodeGen) or raw xcodeproj | Standard macOS toolchain |
| Deployment | `build.sh` -> `~/Applications/FontDial.app` | Per user convention |
| Min target | macOS 14 (Sonoma) | SwiftUI popover + menu bar APIs are mature here |

**Zero external dependencies.** Everything ships in the standard macOS SDK.

---

## 3. Architecture

```
┌──────────────────────────────────────────────────┐
│                   FontDial.app                    │
│                                                   │
│  ┌─────────────┐   ┌──────────────────────────┐  │
│  │ MenuBarIcon  │──▶│  PopoverView (SwiftUI)   │  │
│  │ (NSStatusItem)│  │  ┌─────────────────────┐ │  │
│  └─────────────┘   │  │ SliderRow: Sidebar   │ │  │
│                     │  │ SliderRow: Editor    │ │  │
│                     │  │ SliderRow: Terminal  │ │  │
│                     │  └─────────────────────┘ │  │
│                     └──────────┬───────────────┘  │
│                                │                  │
│                     ┌──────────▼───────────────┐  │
│                     │   SettingsManager         │  │
│                     │   (read/write/watch       │  │
│                     │    settings.json)          │  │
│                     └──────────┬───────────────┘  │
│                                │                  │
│                     ┌──────────▼───────────────┐  │
│                     │   PreferencesStore        │  │
│                     │   (UserDefaults for       │  │
│                     │    FontDial's own state)  │  │
│                     └──────────────────────────┘  │
└──────────────────────────────────────────────────┘
                         │
                         ▼  reads/writes
   ~/Library/Application Support/Code/User/settings.json
                         │
                         ▼  VS Code watches this file
                    ┌─────────┐
                    │ VS Code │  (picks up changes in real-time)
                    └─────────┘
```

### Key Components

1. **AppDelegate / App Entry** -- Configures the `NSStatusItem` (menu bar icon) and attaches the SwiftUI popover. The app has no Dock icon (`LSUIElement = true`).

2. **PopoverView** -- SwiftUI view containing three labeled slider rows, a reset button, and a gear icon for preferences. Compact layout, roughly 280pt wide x 220pt tall.

3. **SettingsManager** -- The core engine:
   - Reads `settings.json`, parses it, extracts the three keys.
   - Writes individual key changes back, preserving all other keys, comments (via raw string manipulation or ordered JSON handling), and formatting.
   - Watches the file for external changes (user edits settings in VS Code directly) and syncs slider positions.
   - Debounces writes (100ms) so rapid slider dragging doesn't thrash disk I/O.

4. **PreferencesStore** -- `UserDefaults`-backed storage for FontDial's own preferences: keyboard shortcut bindings, slider min/max ranges, last-known values, launch-at-login flag.

---

## 4. V1 Feature Set

### 4.1 Menu Bar Presence

- Persistent `NSStatusItem` with a small icon (a stylized "A" with a dial, or an SF Symbol like `textformat.size`).
- Left-click opens the popover. Right-click (or Option-click) opens a minimal context menu: Preferences, Quit.
- No Dock icon. Pure menu bar citizen.

### 4.2 Three Independent Sliders

Each slider row contains:

| Slider | VS Code Key | Type | Default | Range (V1) | Step |
|--------|------------|------|---------|-------------|------|
| Sidebar / UI Chrome | `window.zoomLevel` | Float | 0 | -2.0 to 3.0 | 0.1 |
| Editor Font | `editor.fontSize` | Int | 13 | 8 to 36 | 1 |
| Terminal / Claude Code | `terminal.integrated.fontSize` | Int | 13 | 8 to 36 | 1 |

Each row shows:
- A label (e.g., "Editor")
- A slider track
- A numeric readout to the right of the slider showing the current value
- Tap the numeric readout to type an exact value

### 4.3 Live Settings Sync

- **Write path:** Slider change -> 100ms debounce -> read `settings.json` -> merge changed key -> write `settings.json`. VS Code detects the file change and applies immediately.
- **Read path:** File watcher on `settings.json` -> on external change, re-read and update slider positions. Handles the case where the user (or another tool) edits settings.json directly.
- **Conflict handling:** Last write wins. FontDial reads before every write to avoid clobbering unrelated keys.

### 4.4 JSON Preservation Strategy

VS Code's `settings.json` supports trailing commas and `//` comments (JSONC format). Strategy:

1. **Read:** Use a lenient JSONC parser (strip comments and trailing commas before parsing, or use a simple custom scanner). Store the raw file text alongside the parsed dictionary.
2. **Write:** Rather than re-serializing the entire JSON, perform targeted key replacement using string operations on the raw text. Find the key, replace only its value. This preserves comments, formatting, and key ordering.
3. **Fallback:** If targeted replacement fails (key doesn't exist yet), insert the key-value pair at the end of the top-level object using standard formatting.

### 4.5 Keyboard Shortcuts

Global hotkeys (configurable in Preferences):

| Action | Default Shortcut |
|--------|-----------------|
| Open/close popover | `Ctrl+Opt+F` |
| Editor font +1 | `Ctrl+Opt+]` |
| Editor font -1 | `Ctrl+Opt+[` |
| Terminal font +1 | `Ctrl+Opt+Shift+]` |
| Terminal font -1 | `Ctrl+Opt+Shift+[` |

Implemented via `NSEvent.addGlobalMonitorForEvents` (requires Accessibility permission) or `CGEvent` taps.

### 4.6 Reset to Defaults

A "Reset" button at the bottom of the popover that restores all three values to user-configurable defaults (initially: zoomLevel 0, editor 13, terminal 13). The defaults are stored in FontDial's own preferences and can be changed in a Preferences panel.

### 4.7 Preferences Window

A small standard `NSWindow` (or SwiftUI `.sheet`) with:
- Custom default values for each slider
- Slider range overrides (min/max)
- Launch at Login toggle (`SMAppService` on macOS 13+)
- Keyboard shortcut configuration
- VS Code settings.json path override (for non-standard installs, e.g., VS Code Insiders at `~/Library/Application Support/Code - Insiders/User/settings.json`)

---

## 5. Data Model

### 5.1 VS Code Settings (external, JSON file)

FontDial manages exactly three keys inside `settings.json`:

```json
{
    "window.zoomLevel": 0,
    "editor.fontSize": 13,
    "terminal.integrated.fontSize": 13
}
```

All other keys are read-only pass-through. FontDial never deletes or modifies keys it doesn't own.

### 5.2 FontDial Preferences (UserDefaults)

```swift
struct FontDialPreferences {
    // Current slider values (cached for startup before file read)
    var lastZoomLevel: Double = 0.0
    var lastEditorFontSize: Int = 13
    var lastTerminalFontSize: Int = 13

    // User-defined defaults (for reset button)
    var defaultZoomLevel: Double = 0.0
    var defaultEditorFontSize: Int = 13
    var defaultTerminalFontSize: Int = 13

    // Slider ranges
    var zoomLevelRange: ClosedRange<Double> = -2.0...3.0
    var editorFontSizeRange: ClosedRange<Int> = 8...36
    var terminalFontSizeRange: ClosedRange<Int> = 8...36

    // App behavior
    var launchAtLogin: Bool = false
    var settingsJsonPath: String = "~/Library/Application Support/Code/User/settings.json"

    // Keyboard shortcuts (stored as key-code + modifier mask)
    var shortcuts: [String: KeyCombo] = [:]
}
```

### 5.3 Presets (V1 stretch goal)

```swift
struct Preset: Codable, Identifiable {
    let id: UUID
    var name: String          // e.g., "Presenting", "Focus Mode", "Pair Programming"
    var zoomLevel: Double
    var editorFontSize: Int
    var terminalFontSize: Int
}
```

Stored as a JSON array in UserDefaults or a small plist in Application Support.

---

## 6. Design Direction

### Visual Style

- **Native macOS feel.** Use system materials, vibrancy, and standard controls. The popover should look like it belongs next to Control Center or the Wi-Fi popover.
- **Dark/light mode:** Fully adaptive via SwiftUI's automatic appearance handling.
- **Compact.** Target popover size: ~280w x 200h points. No wasted space.

### UI Layout (Popover)

```
┌──────────────────────────────────┐
│  FontDial                    ⚙   │  <- Title + gear icon for prefs
├──────────────────────────────────┤
│                                  │
│  Sidebar                         │
│  ◀━━━━━━━━━━●━━━━━━━━━━━▶   0.0 │  <- Slider + value readout
│                                  │
│  Editor                          │
│  ◀━━━━━━━━━━━━●━━━━━━━━━▶    13 │
│                                  │
│  Terminal                        │
│  ◀━━━━━━━━━━━━━●━━━━━━━━▶    14 │
│                                  │
├──────────────────────────────────┤
│  [Reset]                         │  <- Reset to defaults
└──────────────────────────────────┘
```

### Typography & Color

- System font (SF Pro) at standard small/caption sizes for labels.
- Slider accent color: system accent (follows user's macOS accent color preference).
- Numeric readouts in a monospaced variant (`Font.system(.body, design: .monospaced)`) so they don't jump as values change.

### Menu Bar Icon

Use SF Symbol `textformat.size` or a custom 18x18 template image. Template images automatically adapt to light/dark menu bars.

---

## 7. MVP Build Order

### Phase 1: Skeleton (Day 1)

- [x] Create Xcode project, configure as menu bar app (`LSUIElement`)
- [x] `NSStatusItem` with SF Symbol icon
- [x] Empty SwiftUI popover opens on click
- [x] `build.sh` that builds and copies to `~/Applications/`

### Phase 2: Settings Engine (Day 1-2)

- [x] `SettingsManager` class: read `settings.json`, parse JSONC
- [x] Extract the three managed keys with fallback defaults
- [x] Write back a single key change using targeted string replacement
- [x] Unit tests for read/write round-trip (preserves comments, formatting, unknown keys)
- [x] Debounced write (100ms `DispatchWorkItem`)

### Phase 3: Slider UI (Day 2)

- [x] Three `SliderRow` views wired to `SettingsManager` via `@Observable`
- [x] Numeric readout, tappable for direct input
- [x] Reset button
- [x] Popover sizing and layout polish

### Phase 4: File Watching (Day 2-3)

- [x] `DispatchSource` file watcher on `settings.json`
- [x] On external change, re-read values and update sliders
- [x] Handle file-not-found gracefully (show inline warning)

### Phase 5: Keyboard Shortcuts (Day 3)

- [x] Global hotkey for popover toggle
- [x] Increment/decrement shortcuts for editor and terminal sizes
- [x] Accessibility permission prompt handling

### Phase 6: Preferences & Polish (Day 3-4)

- [x] Preferences window (defaults, ranges, path override, launch at login)
- [x] Launch at Login via `SMAppService`
- [x] Context menu on right-click (Preferences, Quit)
- [x] Edge cases: file permissions, missing file creation, corrupt JSON recovery

### Phase 7: Ship (Day 4)

- [x] Final QA pass
- [x] `build.sh` finalized
- [x] App icon (simple, clean, 1024x1024 icon set)

---

## 8. V2 / Expansion Features

| Feature | Description |
|---------|-------------|
| **Presets** | Named configurations (e.g., "Presenting", "Late Night", "Pair Programming") with one-click switching. Accessible from the popover and via keyboard shortcuts. |
| **Profile support** | Detect and support VS Code profiles, each with their own `settings.json`. Dropdown in the popover to select which profile to control. |
| **Cursor / Windsurf support** | Add settings.json paths for Cursor (`~/Library/Application Support/Cursor/User/settings.json`) and other VS Code forks. Auto-detect which editors are installed. |
| **Scroll-to-adjust** | Hover over a slider label, scroll the trackpad/mouse wheel to adjust value. Faster than dragging. |
| **Menu bar value display** | Optionally show the current editor font size in the menu bar next to the icon (e.g., "A 14"). |
| **Sync indicator** | Subtle pulse or checkmark animation when a setting is successfully applied. |
| **Touch Bar support** | Sliders on the Touch Bar for MacBooks that have one (legacy but nice). |
| **Additional VS Code settings** | Line height, letter spacing, font family quick-switcher. |
| **Workspace-level overrides** | Detect `.vscode/settings.json` in the frontmost VS Code workspace and offer to modify that instead of user-level settings. |

---

## 9. Engineering Principles

1. **No dependencies.** The app uses only Apple frameworks. No Swift Package Manager, no CocoaPods, no Homebrew. This keeps the binary small (~2-3 MB), build fast, and maintenance trivial.

2. **Defensive JSON handling.** VS Code's settings.json is JSONC (comments, trailing commas). FontDial must never corrupt this file. The targeted string-replacement strategy avoids full re-serialization. Every write is preceded by a read. A backup copy is written before modification (`settings.json.fontdial-backup`), rotated to keep only the last 3.

3. **Debounce everything.** Slider drags can fire dozens of events per second. Writes are debounced at 100ms. File watcher callbacks are debounced at 200ms (VS Code may write the file in multiple passes).

4. **Fail silently, surface clearly.** If `settings.json` is missing or unreadable, sliders show default values and a small warning icon appears. No modal alerts. No crashes. The app remains functional and retries on the next interaction.

5. **Respect the file.** FontDial modifies only the three keys it owns. It never reformats, reorders, or strips comments from the rest of the file. If a key doesn't exist, it inserts it; it never rebuilds the file from scratch.

6. **Minimal footprint.** No background timers except the file watcher (which is event-driven, not polling). Memory target: under 15 MB. CPU: 0% when idle.

7. **Testable core.** `SettingsManager` is a pure Swift class with no UI dependencies. It takes a file path as input and can be tested with fixture files. JSON read/write/merge logic has dedicated unit tests.

---

## 10. Product Risks and Advantages

### Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| **VS Code changes settings.json format or location** | Low | The format has been stable for years. The path is configurable in FontDial preferences. |
| **JSONC parsing edge cases** | Medium | Implement a minimal JSONC stripper (remove `//` and `/* */` comments, trailing commas) before parsing. Test against real-world settings files with heavy commenting. |
| **Race condition: FontDial and VS Code write simultaneously** | Medium | Read-modify-write with debounce. FontDial writes are atomic (write to temp file, then `rename`). VS Code's own file watcher handles conflicts gracefully. |
| **File permissions** | Low | `settings.json` is user-owned. FontDial runs as the same user. Sandboxing could be an issue -- ship unsigned or with a provisioning profile that allows file access. |
| **Accessibility permission for global shortcuts** | Low | Gracefully degrade: shortcuts are optional. Show a clear prompt directing users to System Settings > Privacy > Accessibility. |
| **User confusion about "Sidebar" vs zoom** | Medium | `window.zoomLevel` affects more than just the sidebar (it scales the entire UI). Label it clearly: "UI Scale" or "Chrome & Sidebar" with a tooltip explaining the effect. Consider renaming to "UI Zoom" in the slider label. |
| **VS Code Insiders / forks use different paths** | Low | Configurable path in preferences. V2 adds auto-detection. |

### Advantages

| Advantage | Impact |
|-----------|--------|
| **Solves a real daily friction** | Anyone using Claude Code in VS Code's terminal has felt the "terminal text is too small but zoom makes the sidebar huge" problem. |
| **Zero config** | Works immediately. No extension to install in VS Code, no CLI tool, no server. Just a menu bar icon. |
| **Native performance** | SwiftUI popover opens instantly. Slider changes propagate to VS Code in ~100ms. Feels like a system feature. |
| **Tiny scope** | Three sliders and a JSON file. The entire app can be built, tested, and shipped in days. Small surface area means few bugs. |
| **No VS Code extension needed** | Extensions require marketplace publishing, version compatibility, and add to VS Code's memory footprint. Direct file manipulation bypasses all of this. |
| **Transferable pattern** | The same architecture works for Cursor, Windsurf, or any editor that uses a JSON config file. V2 becomes a universal editor font controller. |
