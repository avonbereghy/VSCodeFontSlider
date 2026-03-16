# Phase 3: File Watching + Edge Cases

Read plans/fontdial_final_plan.md for full context. Read FontDial/.claude/CLAUDE.md for conventions.

## Goal
Add bidirectional sync (detect external changes to settings.json) and harden edge cases. After this phase, V1 is complete.

## Tasks
1. Modify `FontDial/FontDial/SettingsManager.swift` — add file watching:
   - Watch the **parent directory** (`~/Library/Application Support/Code/User/`) using `DispatchSource.makeFileSystemObjectSource` with `.write` event mask
   - When the watcher fires: read settings.json, compute SHA256 hash, compare to `lastWrittenHash`
   - If hashes differ → external change detected → reload values and update published properties
   - If hashes match → self-triggered event → ignore
   - Start watcher on init, stop on deinit
   - Re-open the directory file descriptor if needed (directory watchers should be stable across file renames)

2. Modify `FontDial/FontDial/SettingsManager.swift` — add error handling:
   - `@Published var errorMessage: String?` (if not already present)
   - If file not found: set errorMessage = "VS Code settings not found at [path]"
   - If file unparseable: set errorMessage = "Could not parse VS Code settings"
   - If write fails: set errorMessage = "Could not save settings"
   - Clear errorMessage on successful load

3. Modify `FontDial/FontDial/PopoverView.swift` — add error state:
   - If `settingsManager.errorMessage` is non-nil, show it as a subtle warning text at the top of the popover (secondary color, small font)
   - Sliders remain visible but show last known values

4. Test the following scenarios manually:
   - Open VS Code Settings UI, change editor.fontSize → FontDial sliders update
   - Drag FontDial slider → VS Code updates, then check settings.json has preserved comments
   - Add `// this is a comment` to settings.json → drag a slider → comment is still there
   - Add a `[python]` block with `editor.formatOnType` → drag Editor slider → the nested key is untouched
   - Ensure a URL like `"path": "https://example.com"` in settings.json is not corrupted

## Files to modify
- `FontDial/FontDial/SettingsManager.swift` — add directory watcher, hash guard, error handling
- `FontDial/FontDial/PopoverView.swift` — add error state display

## Files NOT to touch
- JSONCScanner.swift, SliderRow.swift, FontSettings.swift, FontDialApp.swift
- plans/*

## Verification
1. `./build.sh` succeeds
2. Change a setting in VS Code → FontDial sliders update within ~500ms
3. Drag a FontDial slider → VS Code updates → settings.json comments are preserved
4. Delete settings.json → popover shows error message, no crash
5. Restore settings.json → error clears, sliders populate
6. Rapid slider dragging → no file corruption, debounce works
7. Activity Monitor: FontDial uses <15MB memory, 0% CPU when idle

## Post-Phase 3: V1 Complete
After verification, run `./build.sh` one final time. FontDial.app is ready at ~/Applications/.
