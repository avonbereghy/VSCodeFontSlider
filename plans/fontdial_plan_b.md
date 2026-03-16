# FontDial — Implementation Plan

## Concept

Menu bar app with a popover containing three sliders that independently control VS Code text sizes by writing directly to `~/Library/Application Support/Code/User/settings.json`.

**Target keys:**

| Slider label | settings.json key | Type | Range | Default |
|---|---|---|---|---|
| Sidebar / UI | `window.zoomLevel` | Float | -1.0 to 3.0 (step 0.25) | 0.0 |
| Editor | `editor.fontSize` | Int | 8 to 36 (step 1) | 13 |
| Terminal / Claude | `terminal.integrated.fontSize` | Int | 8 to 36 (step 1) | 13 |

Current user values: `editor.fontSize: 13`, `terminal.integrated.fontSize: 13`, `window.zoomLevel`: absent (defaults to 0).

---

## Tech Stack

| Decision | Choice | Why | Alternative considered |
|---|---|---|---|
| Language | Swift 5.9+ | Native perf, direct macOS APIs | — |
| UI | SwiftUI | Fastest path for popover UI | AppKit (more control, not needed) |
| JSON handling | Foundation `JSONSerialization` | Preserves key order + comments better than Codable | `Codable` with custom struct (loses unknown keys) |
| Build system | Xcode project (no SPM deps) | Zero dependencies, nothing to manage | swift-argument-parser (overkill) |
| File watching | `DispatchSource.makeFileSystemObjectSource` | Lightweight, no dependency | FSEvents (heavier), polling (wasteful) |
| Deployment | `build.sh` → `~/Applications/` | Per user convention | — |

**Zero external dependencies.** Foundation + SwiftUI handle everything.

---

## Build Phases

### Phase 1 — Validate (MVP, ~2 hours)

- [x] Menu bar icon (NSStatusItem) with popover
- [x] Three labeled sliders with current-value readout
- [x] Read settings.json on launch, populate sliders
- [x] Write settings.json on slider change (debounced 200ms)
- [x] File watching: reload sliders if settings.json changes externally
- [x] `build.sh` deploying to `~/Applications/`

### Phase 2 — Polish (~1 hour)

- [ ] Preset buttons: "Compact" / "Default" / "Relaxed" (three tuples)
- [ ] Keyboard shortcut to open popover (global hotkey via `NSEvent.addGlobalMonitorForEvents`)
- [ ] "Quit" button in popover footer
- [ ] Launch at login toggle (via `SMAppService` on macOS 13+)

### Phase 3 — Nice-to-have

- [ ] Profiles (save/restore named tuples)
- [ ] Menu bar icon changes to show current "vibe" (compact/default/large)
- [ ] Support workspace-level settings.json override

---

## Data Model

```swift
struct FontSettings {
    var zoomLevel: Double    // window.zoomLevel
    var editorFontSize: Int  // editor.fontSize
    var terminalFontSize: Int // terminal.integrated.fontSize
}

// Presets
static let compact  = FontSettings(zoomLevel: -0.5, editorFontSize: 12, terminalFontSize: 11)
static let standard = FontSettings(zoomLevel: 0.0,  editorFontSize: 13, terminalFontSize: 13)
static let relaxed  = FontSettings(zoomLevel: 0.5,  editorFontSize: 16, terminalFontSize: 15)
```

---

## UI Vibe

**Minimal, utilitarian, native-feeling.** Think: the macOS volume/brightness slider but for fonts.

- Popover width: ~280pt, compact vertical stack
- Each slider: label left, value badge right, slider below
- Muted SF Symbols icon in menu bar (`textformat.size`)
- Subtle section dividers between the three controls
- Preset buttons at bottom as a segmented control
- No window chrome, no dock icon (LSUIElement = YES)

---

## Hardest Challenges & Mitigations

### 1. Preserving settings.json formatting and unknown keys

**Risk:** Codable round-trip drops unknown keys or reorders JSON.

**Mitigation:** Use `JSONSerialization` to parse into `[String: Any]`, mutate only the three known keys, re-serialize with `.sortedKeys` + `.prettyPrinted`. This preserves all other settings. Test with the actual 63-line settings file on first build.

### 2. Race condition: app writes while VS Code writes

**Risk:** Simultaneous writes corrupt the file.

**Mitigation:**
- Debounce slider changes (200ms) so rapid dragging produces one write.
- Use atomic write (`Data.write(to:options:.atomic)`) — writes to temp file then renames.
- File watcher ignores events within 300ms of our own writes (self-trigger guard).

### 3. JSON with trailing commas or comments (JSONC)

**Risk:** VS Code's settings.json is technically JSONC. If user has comments, `JSONSerialization` fails.

**Mitigation:** Strip `//` line comments and trailing commas with a simple regex pass before parsing. Write back without comments (acceptable tradeoff; note in README). Alternatively, warn user on first launch if comments are detected.

---

## Validation-First Build Order

**Build this first to prove the approach in 30 minutes:**

1. Create a single-file Swift script that reads `settings.json`, changes `editor.fontSize` to 18, writes it back, and confirms VS Code picks it up in real-time.
2. If that works, the entire app is viable. Proceed to menu bar scaffolding.

---

## File Structure

```
FontDial/
├── FontDial.xcodeproj/
├── FontDial/
│   ├── FontDialApp.swift          # @main, NSStatusItem setup, LSUIElement
│   ├── PopoverView.swift          # SwiftUI: three sliders, presets, quit
│   ├── SettingsManager.swift      # Read/write/watch settings.json
│   ├── FontSettings.swift         # Model + presets
│   ├── Assets.xcassets/           # Menu bar icon (SF Symbol fallback)
│   └── Info.plist                 # LSUIElement = YES
├── build.sh                       # xcodebuild + cp to ~/Applications/
└── README.md
```

**6 source files.** That's it.

---

## Key Code Patterns

### Menu bar + popover (FontDialApp.swift)

```swift
@main
struct FontDialApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "textformat.size", accessibilityDescription: "FontDial")
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self

        popover.contentViewController = NSHostingController(rootView: PopoverView())
        popover.behavior = .transient  // dismiss on outside click
    }

    @objc func togglePopover() {
        if popover.isShown { popover.performClose(nil) }
        else { popover.show(relativeTo: statusItem.button!.bounds, of: statusItem.button!, preferredEdge: .minY) }
    }
}
```

### Settings read/write (SettingsManager.swift)

```swift
class SettingsManager: ObservableObject {
    @Published var settings = FontSettings()
    private let url = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Application Support/Code/User/settings.json")
    private var debounceTask: Task<Void, Never>?
    private var lastWriteTime = Date.distantPast

    func load() {
        let data = try! Data(contentsOf: url)
        let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        settings.zoomLevel = json["window.zoomLevel"] as? Double ?? 0.0
        settings.editorFontSize = json["editor.fontSize"] as? Int ?? 13
        settings.terminalFontSize = json["terminal.integrated.fontSize"] as? Int ?? 13
    }

    func save() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            var data = try! Data(contentsOf: url)
            var json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
            json["window.zoomLevel"] = settings.zoomLevel
            json["editor.fontSize"] = settings.editorFontSize
            json["terminal.integrated.fontSize"] = settings.terminalFontSize
            let out = try! JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            lastWriteTime = Date()
            try! out.write(to: url, options: .atomic)
        }
    }
}
```

### Slider pattern (PopoverView.swift)

```swift
struct FontSlider: View {
    let label: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String  // "%.0f" for ints, "%.2f" for zoom

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(String(format: format, value)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}
```

---

## build.sh

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
xcodebuild -project FontDial.xcodeproj -scheme FontDial -configuration Release -derivedDataPath build/ build
cp -R build/Build/Products/Release/FontDial.app ~/Applications/
echo "Deployed to ~/Applications/FontDial.app"
```

---

## Open Questions (decide during build)

1. **JSONC handling:** Strip comments or bail with error? Leaning toward: strip on read, don't re-add on write.
2. **Window.zoomLevel granularity:** 0.25 steps feel right, but test if 0.1 is noticeably better.
3. **Multiple VS Code installs:** Ignore for now (Insiders, Cursor). Add later as a settings path picker.
