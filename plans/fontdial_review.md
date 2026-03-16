# FontDial Plan Review -- Adversarial Findings

Reviewed: `fontdial_plan_a.md`, `fontdial_plan_b.md`, `fontdial_plan_c.md`
Reviewer focus: contradictions, scope, timeline, technical risks.

---

## Critical

### 1. The plans contradict each other on the JSON write strategy, and the safe one is infeasible

Plan A (the product/technical plan) commits to **targeted string replacement** that preserves comments, formatting, and ordering byte-for-byte (Section 4.4, Section 9 principle 5: "Never reformat... preserve everything else byte-for-byte if possible"). Plan B (the implementation plan) uses `JSONSerialization` to **round-trip the entire dictionary** (Section "Key Code Patterns," `save()` method: parse to `[String: Any]`, mutate, re-serialize with `.prettyPrinted, .sortedKeys`).

These are opposite strategies. `JSONSerialization` with `.sortedKeys` will **reorder every key alphabetically** and **strip all comments and trailing commas**. It directly violates the promise in Plans A and C to never reformat or strip comments. Meanwhile, targeted regex replacement (Plan A's real strategy) is hard to implement correctly -- see finding #2.

You must pick one strategy before building. If you pick `JSONSerialization` round-trip, own the consequence: the file gets reformatted on first write. If you pick targeted string replacement, budget significantly more time for it.

**Severity: Critical.** This is the core of the app and the plans disagree on how to do it.

### 2. Regex-based JSON value replacement will break on real files

The plan proposes finding a key with regex and replacing only its value. This fails in multiple real-world scenarios present in your actual `settings.json`:

- **Nested objects with similar key names.** Your file has `"[python]": { "editor.formatOnType": true }`. A naive regex for `editor.` keys would match inside this block. The key `editor.fontSize` at the top level looks identical to one that could appear inside a language-scoped override like `"[markdown]": { "editor.fontSize": 16 }`.

- **Keys inside string values.** Your file has `"{git,gitlens}:/**/*.{md,csv}"` as a key. A settings file could contain `editor.fontSize` inside a string value (e.g., in a documentation comment or a task definition).

- **Block comments.** JSONC supports `/* ... */` which can span multiple lines and contain anything, including what looks like key-value pairs. A regex operating line-by-line will not handle this.

- **Values that are objects or arrays.** What if someone has `"editor.fontSize": /* big */ 14 /* px */`? Unlikely but legal JSONC. The regex needs to handle comments between key and value.

- **Key insertion.** Your file does not have `window.zoomLevel` at all. The plan says "insert at the end of the top-level object" but your file ends with a `]` (closing an array value) followed by a blank line and `}`. Inserting a new key after the array's closing bracket requires adding a comma, which requires knowing whether there is already a trailing comma. This is another parsing problem.

**Severity: Critical.** This is the hardest engineering problem in the project and it is underestimated in every plan.

### 3. `window.zoomLevel` hot-reload behavior is unreliable

`editor.fontSize` and `terminal.integrated.fontSize` hot-reload when `settings.json` changes on disk. `window.zoomLevel` behavior is less consistent: some VS Code versions apply it immediately, others require a window reload, and the behavior has changed across versions. The UX plan (Plan C, Section 9) correctly flags this as the #1 riskiest assumption, but Plan B's "validation-first build order" (Section: "Validation-First Build Order") only tests `editor.fontSize`, not `window.zoomLevel`.

If `window.zoomLevel` does not hot-reload, one of your three sliders is broken. The app's value proposition drops by a third.

**Severity: Critical.** Test this first, before writing any app code. If it does not hot-reload, you need a fallback (e.g., executing `workbench.action.reloadWindow` via a VS Code CLI command, or documenting the limitation).

---

## Important

### 4. The DispatchSource + self-trigger guard has a race condition

The plan uses a timestamp-based guard: ignore file watcher events within 300ms of our own write. This fails in at least two scenarios:

- **Slow disk.** If the atomic rename takes longer than expected (e.g., the disk is busy), the watcher event may arrive after the 300ms window. FontDial re-reads the file it just wrote, which is harmless but wasteful.

- **VS Code writes within the guard window.** If VS Code writes settings.json within 300ms of FontDial's write (e.g., user saves a setting in the VS Code UI at the same moment), FontDial will **ignore the VS Code change**, silently dropping the external update. The slider will show stale values until the next external change.

- **Rapid back-and-forth.** User drags a slider, VS Code applies it, VS Code Settings Sync writes back a synced value, FontDial ignores it because it is within the guard window. Now the slider and file are out of sync.

A more robust approach: after your own write, compute a hash/checksum of what you wrote. When the watcher fires, compare the file content to your last-written content. If they match, skip. If they differ, an external change happened.

**Severity: Important.** The timestamp guard will work 95% of the time but will cause confusing bugs in the other 5%.

### 5. `JSONSerialization` does not parse JSONC

Plan B uses `JSONSerialization` (Foundation) to parse `settings.json`. Foundation's `JSONSerialization` does **not** support JSONC. It will throw on:
- `//` line comments
- `/* */` block comments
- Trailing commas (e.g., `"key": "value",` before `}`)

Your current `settings.json` happens to be valid JSON (no comments, and the trailing comma situation on line 61 is actually valid -- the array closes, then the object closes). But many VS Code users have comments in their settings files, and VS Code itself sometimes generates trailing commas. The plan acknowledges this risk but hand-waves the mitigation: "strip // line comments and trailing commas with a simple regex."

Stripping `//` is not simple. Consider: `"path": "https://example.com"` -- a naive regex stripping everything after `//` would destroy this URL. You need to track whether you are inside a string or not, which is effectively writing a partial parser.

**Severity: Important.** This will crash the app for any user with comments in their settings.

### 6. Scope is wildly inconsistent across the three plans

| Feature | Plan A | Plan B | Plan C |
|---------|--------|--------|--------|
| Keyboard shortcuts (global hotkeys) | Phase 5 (Day 3) | Phase 2 (stretch) | Core feature |
| Preferences window | Phase 6 (Day 3-4) | Not mentioned | Core feature |
| Presets | V2 feature | Phase 2 (1 hour) | Core feature |
| Onboarding tooltip | Not mentioned | Not mentioned | Yes, detailed |
| Backup file rotation | Section 9 | Not mentioned | Section 10 |
| Settings Sync detection | Not mentioned | Not mentioned | Section 10 |
| [-]/[+] stepper buttons | Not mentioned | Not mentioned | Core UI element |
| Haptic feedback | Not mentioned | Not mentioned | Detailed spec |
| Tappable value for direct input | Not mentioned | Phase 3 | Core feature |
| Unit tests | Phase 2 | Not mentioned | Not mentioned |

Plan A scopes a 4-day build with preferences, shortcuts, and polish. Plan B scopes a 3-hour build with presets. Plan C describes a feature-rich product with haptics, onboarding, direct input, scroll-to-adjust, and accessibility features that would take a week.

You need one V1 feature list, not three.

**Severity: Important.** Without a single agreed scope, the 3-hour estimate is meaningless.

### 7. No error handling in the code patterns

Plan B's code patterns use `try!` for every file operation: `try! Data(contentsOf: url)`, `try! JSONSerialization.jsonObject(...)`, `try! out.write(...)`. In production, any of these will crash the app:
- File deleted or moved while app is running
- File locked by another process
- Disk full (atomic write fails)
- File contains JSONC that `JSONSerialization` rejects
- File permissions changed

Plan A (Section 9, principle 4) says "Fail silently, surface clearly. No crashes." The code patterns do the opposite.

**Severity: Important.** The code patterns are illustrative, but if they are used as the starting point for implementation, the app will crash on edge cases.

### 8. Atomic writes may not trigger VS Code's file watcher reliably

The plan uses atomic writes (write temp file, then rename). `DispatchSource.makeFileSystemObjectSource` watches a specific file descriptor. After an atomic rename, the old file descriptor points to the deleted file, not the new one. This means:

- FontDial's own file watcher will stop working after FontDial's first write (the fd now points to the old inode).
- VS Code uses its own file watching (likely `fs.watch` or a native equivalent), which handles renames correctly, so VS Code will still pick up changes.

FontDial needs to re-establish its `DispatchSource` watcher after every atomic write, or watch the directory instead of the file.

**Severity: Important.** The file watcher will silently stop working after the first write, and external changes will no longer update the sliders.

---

## Minor

### 9. Default values are inconsistent

Plan B says `editor.fontSize` defaults to 13. Plan C's onboarding section says "VS Code's defaults (editor.fontSize: 14)." VS Code's actual default is 14 for `editor.fontSize`. Your file has it set to 13 explicitly. The app should use VS Code's true defaults (14, 14, 0) when a key is absent, not the values from your personal file.

**Severity: Minor.** Wrong defaults are confusing but not harmful.

### 10. The debounce timing is inconsistent

Plan A says 100ms debounce for writes, 200ms for file watcher. Plan B says 200ms debounce for writes, 300ms self-trigger guard. These should be nailed down. The write debounce and the self-trigger guard interact: if write debounce is 200ms and the self-trigger guard is 300ms, there is only a 100ms margin for the write to complete and the watcher event to arrive.

**Severity: Minor.** Get the numbers right before building, not during.

### 11. `SMAppService` requires macOS 13+, but app targets macOS 14+

Plan B mentions `SMAppService on macOS 13+` as if it might be a compatibility concern. Since the app targets macOS 14+, this is not an issue. Remove the conditional framing -- just use it.

**Severity: Minor.** Misleading comment, no actual risk.

### 12. The Xcode project creation is unbudgeted time

Plan B estimates 2 hours for Phase 1 and 1 hour for Phase 2. But creating and configuring an Xcode project (bundle ID, signing, Info.plist with LSUIElement, build settings, scheme configuration) and writing `build.sh` typically takes 20-30 minutes. This is not explicitly called out and eats into the 2-hour Phase 1 budget that also includes the entire settings read/write engine.

**Severity: Minor.** Small but contributes to timeline pressure.

---

## Timeline Assessment

The 3-hour estimate (Plan B) is plausible **only if**:

1. You abandon JSONC preservation and accept that `JSONSerialization` will reformat the file on first write.
2. You skip keyboard shortcuts, preferences window, onboarding, haptics, direct input, and stepper buttons.
3. You accept the file watcher race conditions and fix them later.
4. You already know how to set up an `NSStatusItem` + `NSPopover` + SwiftUI without trial and error.
5. `window.zoomLevel` hot-reloads without issues.

If any of those assumptions break -- especially #1 or #5 -- add 2-4 hours. A realistic estimate for a solid V1 (three sliders, presets, file watching that works correctly, JSONC-safe writes) is **5-8 hours**.

---

## Recommended V1 Cut List

Cut from V1 to hit 3 hours:
- Keyboard shortcuts and global hotkeys (requires Accessibility permission flow)
- Preferences window
- Onboarding tooltip
- Direct text input on value labels
- Haptic feedback
- [-]/[+] stepper buttons
- Backup file rotation
- Settings Sync detection
- `window.zoomLevel` slider (defer until hot-reload is verified; ship with 2 sliders)

Keep in V1:
- Menu bar icon + popover
- Two or three sliders (editor + terminal, plus zoom if hot-reload works)
- Hardcoded presets as segmented control
- `JSONSerialization` round-trip (accept reformatting)
- Basic file watching with content-hash guard
- Quit button
- `build.sh`
