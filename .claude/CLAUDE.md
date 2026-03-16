# FontDial

## Architecture
A macOS menu bar utility (LSUIElement) that independently controls three VS Code text-size settings by reading/writing `~/Library/Application Support/Code/User/settings.json`. SwiftUI popover attached to NSStatusItem. JSONC-safe writes via a state-aware scanner that preserves comments, formatting, and key order.

## Tech Stack
- Language: Swift 5.9+
- Framework: SwiftUI + AppKit (NSStatusItem, NSPopover)
- JSON: Custom JSONCScanner + Foundation JSONSerialization
- Build: Xcode project, no external dependencies
- Target: macOS 14+

## Build & Run
- Build + deploy: `./build.sh` (xcodebuild → ~/Applications/FontDial.app)
- Run: Open ~/Applications/FontDial.app (menu bar icon appears)

## Key Files
- `JSONCScanner.swift` — State-aware JSONC processor. Tracks string/comment/nesting context. Two modes: strip (for parsing) and find-value-range (for targeted replacement). Most complex and testable component.
- `SettingsManager.swift` — Orchestrates read/write/watch. Uses JSONCScanner for all JSON operations. Directory-based file watcher with content-hash self-trigger guard.
- `PopoverView.swift` + `SliderRow.swift` — SwiftUI UI.
- `FontDialApp.swift` — App entry, NSStatusItem, popover lifecycle.

## Conventions
- No force unwraps (`try!`, `!`). Use `do/catch` and optional chaining throughout.
- No external dependencies. Foundation + SwiftUI only.
- Atomic writes: temp file + rename. Never write partial files.
- JSONC safety: never re-serialize the full JSON. Only replace targeted values.
- Watch the parent directory, not the file (survives inode changes from atomic renames).
- Content hash (SHA256) for self-trigger guard, not timestamps.

## Rules
- Do not modify files outside the current phase's scope
- Never strip comments or reformat settings.json — only modify the three managed key values
- All error states show inline UI warnings, never modal alerts, never crashes
- VS Code default values: editor.fontSize=14, terminal.integrated.fontSize=14, window.zoomLevel=0
- Test with real settings.json containing comments, URLs with //, and nested language-scoped blocks
