# FontDial -- UX Plan

A macOS menu bar app for independently controlling VS Code's sidebar, editor, and terminal text sizes.

---

## 1. Target User Personas

### Primary: The Multi-Context Developer

**Profile:** Software engineer who spends 6-8 hours/day in VS Code. Uses an external monitor at a desk and a laptop screen on the couch or at a cafe. Runs Claude Code in the integrated terminal alongside their editor.

**Current frustrations:**
- `Cmd +/-` zooms *everything* uniformly. The sidebar becomes comically large just to make terminal text readable. Or the sidebar shrinks to unreadable just because the editor font is comfortable.
- Switching between a 27" monitor and a 14" laptop means manually editing `settings.json` every time -- or living with the wrong sizes on one display.
- The terminal and editor have fundamentally different readability needs. Monospaced terminal output at 13px is fine; prose-heavy Claude Code responses need 15px to scan comfortably. VS Code gives you one knob for each, buried in settings.

**Emotional state today:** Low-grade annoyance that never rises to "I need to solve this" but accumulates into a vague sense that VS Code is always slightly wrong.

### Secondary: The Accessibility-Conscious User

**Profile:** Developer with mild presbyopia, migraines, or light sensitivity. Needs larger text in some contexts but not others. May pair-program or screen-share and need to bump sizes quickly for an audience.

**Current frustrations:**
- Accessibility zoom tools are all-or-nothing.
- Explaining to a pair partner "hold on, let me go change my font size" breaks flow.
- Different text densities (sidebar labels vs. code vs. terminal output) have different legibility thresholds, but the tooling treats them as one.

### Tertiary: The Presenter / Streamer

**Profile:** Does live coding demos, streams, or records tutorials. Needs to make code readable on a 1080p stream while keeping their own terminal usable.

**Current frustrations:**
- Has a separate "presentation" settings profile that requires a full reload.
- Can never get terminal and editor balanced for both their screen and the audience.

---

## 2. Core User Problems and Jobs-to-Be-Done

| Job | Current Solution | Why It Fails |
|-----|-----------------|--------------|
| "Make my terminal text bigger without affecting anything else" | Edit `settings.json`, find the right key, save, hope it hot-reloads | Too many steps, breaks flow, easy to typo |
| "Adjust all three text contexts when I switch displays" | `Cmd +/-` or manually edit settings | Uniform zoom is the wrong abstraction; manual editing is slow |
| "Quickly bump sizes for a screen-share, then revert" | Remember old values, change, remember to change back | Cognitive load; people forget to revert |
| "Find a comfortable baseline and never think about it again" | Trial and error in settings.json | No quick feedback loop; changes feel high-friction |

**The core insight:** Text size is not one decision. It is three decisions that happen to live in the same application. FontDial gives each decision its own physical control.

---

## 3. End-to-End User Journeys

### Journey 1: "I just plugged into my monitor"

1. **Trigger:** User sits down at desk, connects external display. VS Code is open. Text sizes feel wrong -- everything is too small or too large for this screen distance.
2. **Action:** Glances at menu bar. Clicks the FontDial icon (a small "Aa" glyph).
3. **Sees:** A compact popover with three labeled sliders, each showing the current value. The layout is immediately legible -- no hunting.
4. **Drags:** The "Editor" slider from 13 to 15. The change appears in VS Code within ~200ms. They see the text reflow in real time.
5. **Drags:** The "Terminal" slider from 13 to 16. Claude Code output becomes more comfortable.
6. **Leaves sidebar alone** -- it looked fine.
7. **Closes popover** by clicking anywhere outside it, or just starts typing in VS Code. The popover dismisses gracefully.
8. **Emotional arc:** Mild annoyance -> instant recognition of what the UI offers -> satisfaction at the direct manipulation -> relief that it "just worked" -> forgets the app exists (best outcome).

**Total time: 4-6 seconds.** This must be faster than opening VS Code settings.

### Journey 2: "Quick, I'm sharing my screen"

1. **Trigger:** Colleague says "can you share your screen?" on a call.
2. **Action:** Clicks FontDial icon. Sees current values: Editor 14, Terminal 14, Sidebar (zoom) 0.
3. **Bumps all three up:** Editor to 18, Terminal to 18, Sidebar zoom to 1. Three quick drags. Each change is confirmed visually in VS Code as they drag.
4. **Presents.** Twenty minutes pass.
5. **Call ends.** Clicks FontDial. Clicks "Reset" (or a saved preset -- see below). All three snap back to their previous values.
6. **Emotional arc:** Brief urgency -> confidence that they can adjust fast -> pride that their screen looks good for the audience -> relief that reverting is one click.

### Journey 3: First-time setup after install

1. **Trigger:** User installs FontDial (drag to Applications, or Homebrew).
2. **First launch:** A brief, non-modal onboarding tooltip appears anchored to the new menu bar icon: *"FontDial controls your VS Code text sizes. Click to adjust."* One sentence. One button: "Got it."
3. **Clicks the icon.** Sees three sliders pre-populated with their current VS Code settings. Immediately understands the mapping because labels say "Editor", "Terminal (Claude Code)", and "Sidebar (Zoom)".
4. **Experiments.** Drags a slider. Sees VS Code change. The feedback loop teaches faster than any tutorial.
5. **Optional:** If `settings.json` is not found, a gentle inline message says: *"VS Code settings not found. Is VS Code installed?"* with a "Locate manually..." link. No modal. No panic.
6. **Emotional arc:** Curiosity -> "oh, that's it?" -> delight at simplicity -> trust.

---

## 4. Key Moments That Determine Retention vs. Uninstall

| Moment | Keep | Uninstall |
|--------|------|-----------|
| First slider drag | Change appears in VS Code in <300ms | Nothing happens, or VS Code needs restart |
| Popover layout | Immediately understand all three controls | Confused by labels, don't know what maps to what |
| After closing popover | Settings persist; VS Code stays updated | Settings revert, or file gets corrupted |
| Edge case hit | Graceful handling with clear message | Silent failure, broken settings.json |
| Second day | Remember the app exists; reach for it naturally | Forget it's there, go back to `Cmd +/-` |
| System resource usage | Invisible in Activity Monitor | Battery drain, CPU spikes, fans spin up |

**The single most important moment:** The first slider drag producing a visible change in VS Code. If that feedback loop is broken or slow, nothing else matters.

---

## 5. First-Time Experience / Onboarding

### Principles
- **No setup wizard.** The app works immediately.
- **No account creation.** Ever.
- **No permissions dialog unless macOS requires it.** (File access to `~/Library/Application Support/Code/User/settings.json` should not require special permissions.)
- **Teach through interaction, not explanation.**

### Sequence
1. App launches. Icon appears in menu bar.
2. A single tooltip appears: *"FontDial -- click to adjust VS Code text sizes."* Auto-dismisses after 5 seconds or on any click.
3. First popover open: sliders are pre-filled with current values read from `settings.json`. If a setting is absent (user has never set it), use VS Code's defaults (editor.fontSize: 14, terminal.integrated.fontSize: 14, window.zoomLevel: 0).
4. Each slider has a subtle label beneath it on first open only: a one-line explanation like "Controls `editor.fontSize` in VS Code." These labels fade out after the third popover open (user has learned).

### What if VS Code is not installed?
- Popover shows a single centered message: *"Could not find VS Code settings."*
- Below: "FontDial edits VS Code's settings.json. [Locate file...] [Learn more]"
- "Locate file..." opens a file picker.
- "Learn more" opens a short webpage explaining compatible editors (VS Code, VS Code Insiders, Cursor, etc.).
- Tone: helpful, not alarming. The app is not broken; it just needs to know where to look.

---

## 6. Information Architecture

### Menu Bar Icon
- A small, sharp **"Aa"** glyph that matches macOS system icon weight. Not a font icon -- a proper template image that adapts to light/dark menu bar.
- No badge, no color, no animation in steady state. It should be invisible until needed.

### Popover Layout (top to bottom)

```
+----------------------------------+
|  FontDial                    [?] |
|                                  |
|  Sidebar (Zoom)                  |
|  [-]  ====O===============  [+]  |
|         -1          0    2    3  |
|                                  |
|  Editor                          |
|  [-]  ============O=========  [+]|
|     10    12   14   16   18   22 |
|                                  |
|  Terminal (Claude Code)          |
|  [-]  ============O=========  [+]|
|     10    12   14   16   18   22 |
|                                  |
|  [Presets v]           [Reset]   |
+----------------------------------+
```

**Why this order:**
- Sidebar (Zoom) is first because `window.zoomLevel` affects everything, including the other two. Users should understand the "base layer" first.
- Editor second because it's the primary workspace.
- Terminal third because it's the most niche control and the reason this app exists for power users.

**Control details:**
- **Sliders** are continuous, not stepped, but snap to common values (integers for font size, 0.25 increments for zoom). Users can override snapping by holding Option while dragging for fine control.
- **[-] and [+] buttons** at each end for keyboard/accessibility users and for precise single-unit adjustments. Each click adjusts by 1px (font size) or 0.25 (zoom).
- **Current value** displayed as a number next to the slider thumb or in a small read-out.
- **"Presets" dropdown:** Save/load named presets (e.g., "Laptop", "Monitor", "Presenting"). First-time: dropdown shows "Save current as preset..." only.
- **"Reset" button:** Returns all three values to whatever they were when FontDial first read the file (the "before FontDial" baseline), or to the last-saved preset. Requires confirmation if values have diverged significantly.

### Keyboard Shortcuts
- **Global hotkey** to open/close the popover (user-configurable, default: `Ctrl+Option+F`). This is critical for the "I'm sharing my screen" journey.
- **Arrow keys** navigate between sliders when popover is focused.
- **Left/Right arrows** adjust the focused slider.
- **Number keys** for direct entry: focus a slider, type "16", press Enter.
- **Esc** closes the popover.

---

## 7. Accessibility Considerations

- **Full VoiceOver support.** Each slider is labeled with its purpose and current value. "Editor font size: 15 pixels. Adjustable."
- **Keyboard-only operation.** Tab order follows visual order. All controls are reachable without a mouse.
- **High contrast mode.** Slider tracks and thumbs must be visible in macOS increased-contrast mode.
- **Reduced motion.** If the user has "Reduce motion" enabled in System Settings, skip any slider animations. Instant jumps instead.
- **Large text in the popover itself.** The popover's own labels should respect the system text size setting, or at minimum be no smaller than 13pt.
- **No color-only signaling.** Don't rely on color alone to indicate state (e.g., "active preset" should have a checkmark, not just a highlight color).

---

## 8. What Must Be True for Users to Love This Tool

1. **It must be faster than the alternative.** If opening the popover and dragging a slider takes longer than `Cmd+Shift+P > "settings" > typing "editor.fontSize" > changing the value`, the app has no reason to exist. Target: 2-3 seconds from intent to result.

2. **Changes must appear in VS Code in real time.** Not after saving. Not after a reload. As the slider moves, VS Code must update. This is the "magic moment." (VS Code watches `settings.json` for changes and hot-reloads most settings. This must be verified and must work reliably.)

3. **It must never corrupt `settings.json`.** This file is precious. Users have custom keybindings, snippets paths, extension configs. A single parse error and the user loses trust forever. The app must handle JSONC (comments, trailing commas) flawlessly.

4. **It must be invisible when not in use.** No CPU usage, no background processes polling, no notifications, no update nags. It should feel like a system utility, not an app.

5. **It must not conflict with VS Code's own controls.** If the user changes `editor.fontSize` inside VS Code's settings UI, FontDial should pick up the new value the next time it opens. No "which one is the source of truth?" confusion.

6. **Presets must enable the "context switch" use case.** Switching from laptop to monitor must be one click, not three slider drags.

---

## 9. Riskiest Assumptions and Validation

| Assumption | Risk | Validation |
|-----------|------|------------|
| VS Code hot-reloads `settings.json` changes for all three settings | If any of these require a window reload, the real-time feedback loop breaks | **Test immediately:** Write a script that modifies each setting and observe VS Code behavior. `editor.fontSize` and `terminal.integrated.fontSize` hot-reload. `window.zoomLevel` may require a reload in some versions. |
| Users want three independent controls, not just "make everything bigger" | If most users just want uniform scaling, three sliders is over-engineering | **Validate:** Ask 10 developers "Do you want your terminal and editor text at different sizes?" If <6 say yes, reconsider. |
| A menu bar app is the right surface | Users might prefer a VS Code extension, a keyboard shortcut, or a CLI tool | **Validate:** Prototype the menu bar version and a VS Code extension. A/B test with 5 users each. The menu bar app wins if users value *speed of access* and *independence from VS Code's UI*. |
| Users can find and will remember the menu bar icon | Menu bar clutter is real; users hide icons aggressively | **Validate:** The global hotkey must be discoverable and reliable. The app must work even if the icon is hidden by Bartender/Hidden Bar. |
| Editing `settings.json` directly is safe and sufficient | VS Code might change its settings storage mechanism, or settings sync might overwrite local changes | **Validate:** Test with Settings Sync enabled. Test with the Settings UI open simultaneously. Test with multiple VS Code windows. |

---

## 10. Edge Cases

### VS Code is not installed
- Detected by absence of `settings.json` at the expected path.
- Show a friendly inline message in the popover (see Section 5).
- Also check for: VS Code Insiders (`~/Library/Application Support/Code - Insiders/User/settings.json`), Cursor (`~/Library/Application Support/Cursor/User/settings.json`), and VSCodium.
- Let the user pick which editor to control, or auto-detect all installed variants and show a dropdown.

### `settings.json` contains JSONC (comments and trailing commas)
- This is the **default state** for many users. VS Code's `settings.json` is JSONC, not strict JSON.
- The app **must** use a JSONC parser for reading and a JSONC-aware writer for modifications.
- **Critical rule:** Never strip comments. Never reformat the file. Only modify the specific key-value pairs FontDial controls. Preserve everything else byte-for-byte if possible, or at minimum preserve structure, comments, and ordering.

### Multiple VS Code windows open
- VS Code uses a single `settings.json` for all windows. Changes apply to all windows simultaneously. This is actually fine -- it's the same behavior as editing settings manually.
- FontDial does not need to be window-aware.

### VS Code Insiders / Cursor / other forks
- On first launch, if multiple compatible editors are detected, show a one-time picker: "Which editor should FontDial control?" with icons for each detected editor.
- Store the choice. Allow changing it later via a small gear icon in the popover.
- Advanced: allow controlling multiple editors simultaneously (separate slider banks, tabbed UI). **But not in v1.** Keep it simple.

### Settings Sync is enabled
- VS Code Settings Sync will propagate FontDial's changes to other machines. This is probably desirable (the user wants their sizes everywhere) but could surprise users.
- **Mitigation:** On first launch, if Settings Sync is detected (check for `settingsSync` keys in settings.json or the presence of `~/.vscode/sync`), show a one-time note: *"VS Code Settings Sync is active. Changes you make here will sync to your other machines."*

### The user changes font size via VS Code while FontDial is open
- FontDial should poll or watch `settings.json` (via FSEvents) and update its sliders if the file changes externally.
- No conflict resolution needed -- the file is the source of truth. Last write wins, which matches VS Code's own behavior.

### `settings.json` doesn't exist yet
- Create it with `{}` and then write the relevant keys. Ensure the parent directory exists.

### The user has workspace-level settings that override global settings
- FontDial v1 operates on global `settings.json` only. If a workspace overrides `editor.fontSize`, FontDial's change will have no visible effect.
- **Mitigation:** If the active VS Code workspace has a `.vscode/settings.json` with conflicting keys, show a subtle warning icon next to the affected slider: "This may be overridden by workspace settings."
- **How to detect:** This is hard without VS Code API access. Consider this a v2 problem. For v1, document the limitation.

### File write conflicts / corruption
- Always read the file before writing.
- Use atomic writes (write to a temp file, then rename).
- Keep a backup of the last known good `settings.json` (in FontDial's own Application Support directory).
- If a parse error is encountered on read, show: *"VS Code settings file could not be read. It may contain a syntax error. [Open in VS Code] [Open in Finder]"*. Do **not** attempt to fix it.

---

## 11. UX Polish Details

### Visual Feedback
- **Slider thumb glow:** When dragging, the slider thumb gets a subtle blue glow (matching the system accent color) to confirm interactivity.
- **Value label animation:** The numeric value next to each slider should count up/down smoothly (not jump) as the slider moves.
- **Popover entrance:** Fade in + slight downward slide (4px) over 150ms. Matches macOS system popover behavior.
- **Popover exit:** Fade out over 100ms. Snappy. Never make the user wait to get back to work.
- **Preset applied:** Brief checkmark animation next to the preset name. 300ms, then fades.

### Haptic Feedback (Force Touch trackpad)
- **Slider snap points:** A light haptic tap (`.alignment` feedback) when the slider crosses an integer boundary. This makes it feel like a physical dial with detents.
- **[-] and [+] buttons:** A light tap on press.
- **Reset button:** A medium tap (`.levelChange`) to confirm the action.
- **Preset applied:** A medium tap.

### Sound Feedback
- **None by default.** A menu bar utility should be silent.
- Optional: allow users to enable a subtle "tick" sound on slider snap points in preferences. Off by default.

### Animation with Reduced Motion
- All animations collapse to instant transitions if `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` is true.
- Haptics are unaffected by the Reduce Motion setting (they are tactile, not visual).

### Dark Mode / Light Mode
- Popover background: system material (`.popover` material), which automatically adapts.
- Slider tracks: slightly darker/lighter than background, following system conventions.
- Text: system primary and secondary label colors. No custom colors needed.
- The app should feel like it was made by Apple, not by a startup.

### Icon Design
- Menu bar icon: "Aa" in SF Pro, rendered as a template image.
- When the popover is open, the icon inverts (standard macOS menu bar behavior for active items).
- No app icon needed in the Dock (LSUIElement = true). The app is menu-bar-only.

### Micro-interactions
- **Double-click a slider value label** to enter direct text input mode. A small text field appears inline. Type a number, press Enter. The slider jumps to that value.
- **Right-click the menu bar icon** for a context menu: "Presets > ...", "Quit FontDial".
- **Scroll wheel over a slider** adjusts it. Natural scrolling direction applies.
- **Option-click the menu bar icon** to cycle through presets without opening the popover. A brief HUD-style overlay shows the preset name (like the macOS volume/brightness OSD, but smaller and less intrusive).

---

## 12. Summary of Design Principles

1. **Three seconds or it failed.** Every interaction must complete in under three seconds.
2. **The file is the truth.** FontDial reads from and writes to `settings.json`. It never caches, never assumes.
3. **Do no harm.** Never corrupt, never reformat, never lose comments.
4. **Invisible until needed.** No CPU at rest. No dock icon. No notifications.
5. **Teach by doing.** The slider-to-VS-Code feedback loop is the entire onboarding.
6. **Feel native.** Use system materials, system colors, system haptics. If someone thinks this shipped with macOS, we won.
