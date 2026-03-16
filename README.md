# VSCodeFontSlider (FontDial)

![Swift](https://img.shields.io/badge/Swift-5.9+-F05138?logo=swift&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-14.0+-000000?logo=apple&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Framework-0071E3?logo=swift&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)
![Dependencies](https://img.shields.io/badge/Dependencies-None-brightgreen)

A lightweight macOS menu bar app that gives you independent control over VS Code's three text-size dimensions — something `Cmd +/-` can't do.

<p align="center">
  <img src="https://img.shields.io/badge/UI_Scale-window.zoomLevel-blue" />
  <img src="https://img.shields.io/badge/Editor-editor.fontSize-blue" />
  <img src="https://img.shields.io/badge/Terminal-terminal.integrated.fontSize-blue" />
</p>

## The Problem

VS Code's `Cmd +/-` zooms everything uniformly. But your sidebar, editor, and terminal have different readability needs. FontDial gives each its own slider.

## Features

- **Three independent sliders** — UI Scale, Editor font size, Terminal font size
- **Real-time updates** — drag a slider, VS Code changes instantly
- **Presets** — Compact / Default / Relaxed with one click
- **Bidirectional sync** — changes made in VS Code settings are reflected in FontDial
- **JSONC-safe** — preserves comments, formatting, and key order in `settings.json`
- **Zero dependencies** — pure Swift + SwiftUI, no external packages
- **Menu bar + Dock** — lives in the menu bar, optionally shows in Dock
- **Start at login** — optional auto-launch

## Install

### Option 1: Build from source

**Requirements:** macOS 14+, Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
# Clone
git clone https://github.com/avonbereghy/VSCodeFontSlider.git
cd VSCodeFontSlider

# Build and install to ~/Applications
chmod +x build.sh
./build.sh
```

The app will be installed to `~/Applications/FontDial.app` and launched automatically.

### Option 2: Download release

Download the latest `.app` from [Releases](https://github.com/avonbereghy/VSCodeFontSlider/releases), then drag to your Applications folder.

### Installing XcodeGen (if needed)

```bash
brew install xcodegen
```

## Usage

1. Click the **Aa** icon in your menu bar
2. Drag sliders to adjust:
   - **UI Scale** — controls `window.zoomLevel` (sidebar, Claude Code panel, all UI chrome)
   - **Editor** — controls `editor.fontSize`
   - **Terminal** — controls `terminal.integrated.fontSize`
3. Use presets for quick switching between configurations
4. Right-click the menu bar icon for Settings and Quit

## How It Works

FontDial reads and writes directly to VS Code's `settings.json` at:

```
~/Library/Application Support/Code/User/settings.json
```

It uses a state-aware JSONC scanner for targeted key-value replacement — only the three managed values are modified. Comments, formatting, key order, and all other settings are preserved byte-for-byte.

Changes are debounced (200ms) and written atomically. A directory-based file watcher with content-hash comparison detects external changes without false positives.

## Project Structure

```
FontDial/
├── FontDialApp.swift          # App entry, NSStatusItem, popover
├── PopoverView.swift          # Three sliders, presets, settings toggles
├── SliderRow.swift            # Reusable slider component
├── SettingsManager.swift      # Read/write/watch settings.json
├── JSONCScanner.swift         # JSONC-safe comment stripper + key finder
├── FontSettings.swift         # Model + preset definitions
├── SettingsView.swift         # Settings window (dock, login)
├── Resources/
│   ├── AppIcon.icns
│   └── Info.plist
├── build.sh                   # Build + deploy script
└── project.yml                # XcodeGen project definition
```

## Tech Details

| Component | Implementation |
|-----------|---------------|
| JSON writes | State-aware scanner tracks string/comment/nesting context; replaces values at top-level depth only |
| File watching | `DispatchSource` on parent directory (survives atomic renames) |
| Self-trigger guard | SHA256 content hash comparison |
| Write strategy | 200ms debounce → fresh read → targeted replace → atomic write |
| Persistence | UserDefaults for app settings, VS Code's settings.json for font values |

## Contributing

Pull requests welcome. The codebase is intentionally small (~8 source files) and has zero dependencies.

## License

MIT
