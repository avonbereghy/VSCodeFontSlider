# Phase 0: Validate Assumptions

Read plans/fontdial_final_plan.md for full context.

## Goal
Prove that all three VS Code settings hot-reload when settings.json is modified externally. This MUST pass before building any app code.

## Tasks
1. Create a standalone Swift script `FontDial/validate.swift` that:
   - Reads `~/Library/Application Support/Code/User/settings.json`
   - Stores the original values of `editor.fontSize`, `terminal.integrated.fontSize`, and `window.zoomLevel`
   - Changes `editor.fontSize` to 20, writes atomically, waits 2 seconds
   - Changes `terminal.integrated.fontSize` to 20, writes atomically, waits 2 seconds
   - Inserts or changes `window.zoomLevel` to 1.0, writes atomically, waits 2 seconds
   - Restores all original values and writes atomically
   - Uses JSONSerialization for this throwaway script (JSONC safety not required here — this is validation only)
   - Prints each step so the user can visually confirm VS Code updates

2. Run the script with `swift FontDial/validate.swift`

3. Have VS Code open and visible during the test. Observe:
   - Does editor text size change immediately? (Expected: yes)
   - Does terminal text size change immediately? (Expected: yes)
   - Does the UI chrome/sidebar scale change immediately? (This is the risky one)

## Files to create
- `FontDial/validate.swift`

## Files NOT to touch
- Everything else

## Verification
User visually confirms all three settings update VS Code in real-time. Document results.
If `window.zoomLevel` does NOT hot-reload: note this, proceed anyway — add "(reload may be required)" tooltip in Phase 2.
