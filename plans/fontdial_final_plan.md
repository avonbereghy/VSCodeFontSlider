# FontDial — Final Plan (Revised)

A macOS menu bar app that independently controls VS Code's three text-size dimensions via direct `settings.json` manipulation.

**Revised after adversarial review.** Key changes: state-aware JSONC scanner (not naive regex), directory-based file watching (not file descriptor), content-hash self-trigger guard (not timestamp), proper error handling, VS Code defaults corrected.

---

## 1. Product Vision

FontDial gives developers three physical dials for the three text-size decisions VS Code conflates: UI chrome/sidebar scale, editor font size, and terminal font size (where Claude Code lives). One click from the menu bar, three sliders, instant feedback. No VS Code extension, no cloud, no config.

**Core insight:** Text size is not one decision — it's three. FontDial gives each its own control.

---

## 2. Tech Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Language | Swift 5.9+ | Native performance, direct macOS APIs |
| UI | SwiftUI | Declarative, lightweight, perfect for popover UIs |
| JSON handling | State-aware JSONC scanner + targeted replacement | Preserves comments, formatting, key order |
| File watching | `DispatchSource` on **parent directory** | Survives atomic renames (inode changes) |
| Build system | Xcode project (no SPM) | Zero external dependencies |
| Deployment | `build.sh` → `~/Applications/` | Per user convention |
| Min target | macOS 14 (Sonoma) | Mature SwiftUI popover + menu bar APIs |

**Zero external dependencies.** Foundation + SwiftUI handle everything.

---

## 3. Architecture

```
┌──────────────────────────────────────────────────┐
│                   FontDial.app                    │
│                                                   │
│  ┌─────────────┐   ┌──────────────────────────┐  │
│  │ MenuBarIcon  │──▶│  PopoverView (SwiftUI)   │  │
│  │(NSStatusItem)│   │  ┌─────────────────────┐ │  │
│  └─────────────┘   │  │ SliderRow: Sidebar   │ │  │
│                     │  │ SliderRow: Editor    │ │  │
│                     │  │ SliderRow: Terminal  │ │  │
│                     │  │ PresetBar            │ │  │
│                     │  └─────────────────────┘ │  │
│                     └──────────┬───────────────┘  │
│                                │                  │
│                     ┌──────────▼───────────────┐  │
│                     │   SettingsManager         │  │
│                     │   - JSONC scanner/parser  │  │
│                     │   - Targeted key replace  │  │
│                     │   - Dir watch + hash guard│  │
│                     └──────────┬───────────────┘  │
│                                │                  │
│              ~/Library/Application Support/Code/   │
│                       User/settings.json           │
└──────────────────────────────────────────────────┘
```

### Key Components

1. **AppDelegate** — `NSStatusItem` with SF Symbol icon (`textformat.size`). Left-click opens SwiftUI popover. Right-click opens context menu (Quit). `LSUIElement = true` (no Dock icon).

2. **PopoverView** — Three `SliderRow` views + preset segmented control + reset button. ~280w × 240h points.

3. **SettingsManager** (`@Observable`) — The core engine:
   - **Read:** Loads raw file text. Uses a state-aware scanner to strip comments/trailing commas for parsing (tracks string context to avoid destroying URLs like `https://`). Keeps original raw text for writes.
   - **Write:** State-aware targeted replacement on the raw text — scanner walks the file tracking string/comment context, finds the target key at the top-level nesting depth only, replaces its value. Never re-serializes the full JSON.
   - **Insert:** If a key doesn't exist, finds the correct insertion point before the top-level closing `}`, handles comma placement.
   - **Watch:** `DispatchSource` on the **parent directory** (not the file itself — survives atomic renames that change the inode).
   - **Self-trigger guard:** Content hash comparison, not timestamp. After writing, store SHA256 of written content. When watcher fires, compare file content hash to last-written hash. If match → skip. If different → external change, reload.
   - **Debounce:** 200ms debounce on writes. Atomic writes (temp file + rename).

4. **FontSettings** — Simple model struct + three preset constants.

5. **JSONCScanner** — Minimal state-aware JSONC processor. Two modes:
   - **Strip mode:** Removes `//` line comments, `/* */` block comments, and trailing commas while tracking whether the cursor is inside a JSON string (to avoid destroying URLs or strings containing `//`). Returns clean JSON for `JSONSerialization` to parse.
   - **Find-and-replace mode:** Walks the raw text tracking string/comment/nesting context. Finds a key at nesting depth 0 (top-level only, ignoring keys inside `[python]` or other scoped blocks). Returns the character range of the value for replacement.

---

## 4. Target Settings

| Slider Label | VS Code Key | Type | Default | Range | Step |
|---|---|---|---|---|---|
| Sidebar (Zoom) | `window.zoomLevel` | Float | 0.0 | -1.0 to 3.0 | 0.25 |
| Editor | `editor.fontSize` | Int | 14 | 8 to 36 | 1 |
| Terminal (Claude Code) | `terminal.integrated.fontSize` | Int | 14 | 8 to 36 | 1 |

**Note:** VS Code's actual defaults are 14 for both font sizes and 0 for zoom level. The user's current file has 13 explicitly set — FontDial reads actual values from the file, falls back to VS Code defaults only when a key is absent.

---

## 5. V1 Feature Set

### 5.1 Menu Bar Presence
- `NSStatusItem` with `textformat.size` SF Symbol
- Left-click: popover. Right-click: context menu (Quit)
- No Dock icon (`LSUIElement = true`)

### 5.2 Three Independent Sliders
- Each row: label, slider, numeric value readout (monospaced digits)
- Dragging a slider writes to `settings.json` after 200ms debounce
- VS Code picks up changes in real-time

### 5.3 Three Presets
- **Compact:** zoom -0.5, editor 12, terminal 11
- **Default:** zoom 0.0, editor 14, terminal 14
- **Relaxed:** zoom 0.5, editor 16, terminal 15
- Displayed as a segmented control at the bottom of the popover

### 5.4 Reset Button
- Restores all three to VS Code defaults (zoom 0, editor 14, terminal 14)

### 5.5 Live Sync (Both Directions)
- **Write:** Slider change → 200ms debounce → read raw file → targeted key replacement → atomic write → store content hash
- **Read:** Directory watcher detects changes → read file → compute hash → if hash ≠ last-written hash, update sliders
- Content-hash guard eliminates false positives from self-triggered events

### 5.6 JSONC-Safe JSON Handling (Critical Path)

**Reading (for slider values):**
1. Load raw file text as String
2. Run through `JSONCScanner.strip()` — state-aware removal of `//` comments, `/* */` block comments, trailing commas. Tracks whether cursor is inside a `"string"` to avoid corrupting URLs or quoted content.
3. Parse the clean JSON string via `JSONSerialization` → `[String: Any]`
4. Extract the three managed keys with fallback to VS Code defaults

**Writing (when slider changes):**
1. Load current raw file text (always fresh read, never cached)
2. For each changed key, run `JSONCScanner.findValue(forKey:in:)`:
   - Walk the text character by character
   - Track state: `normal`, `inString`, `inLineComment`, `inBlockComment`
   - Track nesting depth (increment on `{`/`[`, decrement on `}`/`]` — only at depth 0 for top-level)
   - When the target key is found at depth 0 and outside any comment/string: return the character range of its value
3. Replace the value range with the new value string
4. If key not found: find the position just before the top-level closing `}`. Insert the key-value pair with proper comma handling.
5. Atomic write: write to `.settings.json.fontdial-tmp`, then `rename()`
6. Store SHA256 hash of written content

**Safety rules:**
- Always read immediately before writing
- If the scanner or parse fails, show inline warning in popover — never write
- Never modify keys FontDial doesn't own
- Never reformat or reorder anything

### 5.7 Popover Layout

```
┌──────────────────────────────────┐
│  FontDial                        │
├──────────────────────────────────┤
│                                  │
│  Sidebar (Zoom)                  │
│  ◀━━━━━━━━━●━━━━━━━━━━━▶   0.0  │
│                                  │
│  Editor                          │
│  ◀━━━━━━━━━━━━●━━━━━━━━▶    14  │
│                                  │
│  Terminal (Claude Code)          │
│  ◀━━━━━━━━━━━━━●━━━━━━━▶    14  │
│                                  │
│  [ Compact | Default | Relaxed ] │
│                                  │
│  [Reset]                   [✕]   │
└──────────────────────────────────┘
```

---

## 6. Data Model

```swift
struct FontSettings {
    var zoomLevel: Double       // window.zoomLevel
    var editorFontSize: Int     // editor.fontSize
    var terminalFontSize: Int   // terminal.integrated.fontSize
}

extension FontSettings {
    static let compact  = FontSettings(zoomLevel: -0.5, editorFontSize: 12, terminalFontSize: 11)
    static let standard = FontSettings(zoomLevel: 0.0,  editorFontSize: 14, terminalFontSize: 14)
    static let relaxed  = FontSettings(zoomLevel: 0.5,  editorFontSize: 16, terminalFontSize: 15)

    static let vsCodeDefaults = FontSettings(zoomLevel: 0.0, editorFontSize: 14, terminalFontSize: 14)
}
```

---

## 7. File Structure

```
FontDial/
├── FontDial.xcodeproj/
├── FontDial/
│   ├── FontDialApp.swift          # @main, AppDelegate, NSStatusItem, popover
│   ├── PopoverView.swift          # SwiftUI: sliders, presets, reset, quit
│   ├── SliderRow.swift            # Reusable slider row component
│   ├── SettingsManager.swift      # Read/write/watch settings.json, orchestration
│   ├── JSONCScanner.swift         # State-aware JSONC comment stripper + key finder
│   ├── FontSettings.swift         # Model + preset constants
│   ├── Assets.xcassets/           # App icon set
│   └── Info.plist                 # LSUIElement = YES
├── build.sh                       # xcodebuild + deploy to ~/Applications/
└── README.md
```

8 source files. `JSONCScanner` is extracted as its own file because it's the most complex and testable component.

---

## 8. Build Order

### Phase 0: Validate Assumptions (~15 min)
**Sequential. Must pass before any app code.**

Write a standalone Swift script that:
1. Reads `~/Library/Application Support/Code/User/settings.json`
2. Changes `editor.fontSize` to 20 → write → confirm VS Code updates live
3. Changes `terminal.integrated.fontSize` to 20 → write → confirm VS Code updates live
4. Adds `window.zoomLevel: 1` → write → **confirm VS Code updates live without window reload**
5. Restores all values

If `window.zoomLevel` does NOT hot-reload: the slider still works, but add a tooltip "(may require VS Code reload)" and proceed. This does not block V1.

**Files to create:** `validate.swift` (throwaway script)
**Verify:** All three settings update VS Code in real-time, or document which ones require reload.

### Phase 1: Foundation (~1.5 hours)
**Sequential. Core engine + skeleton app.**

- Create Xcode project configured as menu bar app (LSUIElement)
- `FontDialApp.swift`: NSStatusItem with SF Symbol, empty popover, right-click Quit menu
- `JSONCScanner.swift`: State-aware scanner with two methods:
  - `strip(_ text: String) -> String` — returns clean JSON
  - `findValueRange(forKey key: String, in text: String) -> Range<String.Index>?` — returns range of value at top-level depth
- `SettingsManager.swift`: Read (via scanner + JSONSerialization), write (via scanner find + replace), atomic save. Proper `do/catch` error handling — no force unwraps.
- `FontSettings.swift`: model struct + presets + VS Code defaults
- `build.sh`: xcodebuild + copy to ~/Applications/

**Files to create:** FontDialApp.swift, JSONCScanner.swift, SettingsManager.swift, FontSettings.swift, Info.plist, build.sh
**Verify:** Run build.sh, app appears in menu bar. SettingsManager can read current values and write a changed value that VS Code picks up. Comments in settings.json are preserved after write.

### Phase 2: Slider UI (~1 hour)
**Sequential. Wires UI to engine.**

- `PopoverView.swift`: Three SliderRow views bound to SettingsManager via `@Observable`
- `SliderRow.swift`: label + slider + monospaced value readout
- Preset segmented control (Compact / Default / Relaxed)
- Reset button (restores VS Code defaults)
- Quit button in footer
- Popover sizing (~280w × 240h), native materials

**Files to create:** PopoverView.swift, SliderRow.swift
**Files to modify:** FontDialApp.swift (wire popover to real view)
**Verify:** Build, open popover, drag sliders, see VS Code update in real-time. Presets work. Reset works.

### Phase 3: File Watching + Edge Cases (~45 min)
**Sequential. Closes the sync loop and hardens.**

- Add directory-based `DispatchSource` watcher to SettingsManager (watches parent dir, filters for settings.json changes)
- Content-hash self-trigger guard (SHA256)
- Handle edge cases:
  - File not found → inline warning in popover, sliders disabled
  - File unparseable → inline warning, sliders show last known values
  - File permissions → graceful error message
- Test with real settings.json containing `//` comments, `/* */` block comments, trailing commas, URLs with `//`, nested language-scoped blocks
- Final QA pass

**Files to modify:** SettingsManager.swift (add watcher + hash guard), PopoverView.swift (add error state UI)
**Verify:**
1. Change a setting in VS Code settings UI → FontDial sliders update
2. Drag a slider → VS Code updates
3. Comments in settings.json are preserved after multiple writes
4. Keys inside `[python]` blocks are not affected
5. URLs in string values are not corrupted

---

## 9. UX Details

- **Native feel:** System materials, vibrancy, auto dark/light mode, system accent color
- **Typography:** SF Pro for labels, `.monospacedDigit()` for value readouts
- **Popover behavior:** `.transient` — dismisses on outside click
- **Slider feedback:** Values update in real-time as slider drags
- **Error states:** Inline text in popover (not modal alerts). "Could not read VS Code settings" with path shown.
- **Reduced motion:** Respect `accessibilityDisplayShouldReduceMotion`
- **VoiceOver:** All sliders labeled with purpose and current value

---

## 10. V2 Features (Not in V1)

- Global keyboard shortcut to open popover
- Increment/decrement shortcuts per slider
- Custom/saveable presets
- VS Code Insiders / Cursor auto-detection
- Workspace-level settings override
- Scroll-wheel over sliders
- Double-click value label for direct numeric entry
- Launch at Login toggle (`SMAppService`)
- Preferences window (path override, range customization)
- Haptic feedback on slider detents
- [-]/[+] stepper buttons on each slider

---

## 11. Known Risks & Open Questions

| Risk | Severity | Status | Mitigation |
|------|----------|--------|------------|
| `window.zoomLevel` may not hot-reload | Critical | **Test in Phase 0** | If fails: add "(reload required)" tooltip, still include slider |
| JSONC scanner edge cases | Critical | Addressed | State-aware scanner tracks string/comment context, operates at depth 0 only |
| Atomic rename breaks file-descriptor watchers | Important | Addressed | Watch parent directory instead of file |
| Self-trigger false negatives | Important | Addressed | Content hash comparison instead of timestamp |
| `JSONSerialization` rejects JSONC | Important | Addressed | Strip comments via scanner before parsing |
| Naive `//` stripping destroys URLs | Important | Addressed | Scanner tracks string context |
| Nested/scoped keys (`[python].editor.*`) | Important | Addressed | Scanner only matches at nesting depth 0 |
| `try!` crashes on file errors | Important | Addressed | Proper `do/catch` throughout |
| VS Code Settings Sync overwrites | Low | Documented | Settings Sync propagates changes — this is expected behavior |
| Multiple VS Code variants (Insiders, Cursor) | Low | V2 | Hardcode standard VS Code path for V1 |

**Open question:** If Phase 0 reveals `window.zoomLevel` does not hot-reload, should we:
(a) Ship it anyway with a "reload required" note, or
(b) Add a button that runs `code --command workbench.action.reloadWindow`?
Decision deferred to Phase 0 results.
