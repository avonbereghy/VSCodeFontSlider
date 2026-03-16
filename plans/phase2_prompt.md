# Phase 2: Slider UI

Read plans/fontdial_final_plan.md for full context. Read FontDial/.claude/CLAUDE.md for conventions.

## Goal
Wire up the three sliders, preset bar, and reset button. By the end, dragging a slider changes VS Code text size in real-time.

## Tasks
1. Create `FontDial/FontDial/SliderRow.swift`:
   - Reusable SwiftUI view: label, SF Symbol icon, slider, monospaced value readout
   - Parameters: label (String), icon (String), binding to Double, range (ClosedRange<Double>), step (Double), format string ("%.0f" for ints, "%.2f" for zoom)
   - Compact vertical layout: icon + label + value on top line, slider below

2. Create `FontDial/FontDial/PopoverView.swift`:
   - Takes `SettingsManager` as environment or init parameter
   - Three `SliderRow` instances:
     - "Sidebar (Zoom)" / icon `sidebar.left` / binding to zoomLevel / range -1.0...3.0 / step 0.25
     - "Editor" / icon `doc.text` / binding to editorFontSize (as Double) / range 8...36 / step 1
     - "Terminal (Claude Code)" / icon `terminal` / binding to terminalFontSize (as Double) / range 8...36 / step 1
   - Each slider's onChange triggers `settingsManager.save()`
   - Segmented control with three presets: Compact / Default / Relaxed
     - Selecting a preset applies all three values and saves
   - Reset button: restores `.vsCodeDefaults` and saves
   - Quit button (or "✕") that calls `NSApplication.shared.terminate(nil)`
   - Popover size: ~280w × 240h, using `.frame()` modifier
   - Native materials: `.background(.regularMaterial)`

3. Modify `FontDial/FontDial/FontDialApp.swift`:
   - Wire the popover to display `PopoverView` with the real `SettingsManager`
   - Call `settingsManager.load()` on app launch
   - Pass settingsManager to PopoverView

## Files to create
- `FontDial/FontDial/PopoverView.swift`
- `FontDial/FontDial/SliderRow.swift`

## Files to modify
- `FontDial/FontDial/FontDialApp.swift` — wire popover to PopoverView, load settings on launch

## Files NOT to touch
- JSONCScanner.swift, SettingsManager.swift, FontSettings.swift (already done in Phase 1)
- plans/*
- build.sh

## Verification
1. `./build.sh` succeeds
2. Click menu bar icon — popover shows three labeled sliders with current VS Code values
3. Drag Editor slider — VS Code editor text size changes in real-time
4. Drag Terminal slider — VS Code terminal text size changes in real-time
5. Drag Sidebar slider — VS Code UI scale changes (or note if reload required)
6. Click "Compact" preset — all three values change, VS Code updates
7. Click "Reset" — values return to defaults
8. Click Quit — app terminates
