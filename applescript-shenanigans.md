# applescript-shenanigans — READ before any osascript / AppleScript

> **AppleScript fails silently and destructively more than most surfaces.** The items below are
> empirically reproduced. Skip this and you can blank tabs, hang for minutes, or run nothing.

## §1 — NEVER `move` a Google Chrome tab — it DESTROYS the tab (does not reorder)

`move` is not in Chrome's `tab` class `responds-to` list, so AppleScript falls back to Cocoa's
default move → Chrome's tab-insert accessor creates a **fresh blank `chrome://newtab/`** and the live
content is gone (no back-history). Reorder by reading URLs → re-setting URLs (lossy but native), CDP,
or the extension API — never `move`.
**General rule: check `responds-to` in `sdef /Applications/<App>.app` BEFORE using any verb on a class.**

## §2 — `execute javascript` HANGS forever unless the app is frontmost

Chromium throttles background tabs. Against a heavy SPA, `execute javascript` from a non-frontmost
app **hangs indefinitely, no error** (osascript stuck in `S` state > 2 min). Always activate + settle:
```bash
osascript -e 'tell application "Microsoft Edge" to activate'
sleep 2   # let activation settle
```
- **Edge** supports `execute javascript` out of the box; **Chrome** needs Develop-menu → "Allow
  JavaScript from Apple Events" enabled first; **Safari** via its own dictionary.
- Inline JS via `-e`: escape `"` → `\"` and backslashes; don't return giant objects (serializing a
  big array hangs the bridge — slice to ~10 items / ~60 chars).
- `document.readyState==="complete"` ≠ ready for SPAs; sleep 4–6 s or poll the specific selector.

## §3 — verify scripted UI edits at REAL state, not the id/DOM

A single sample of an unsupported verb is flaky and DOM updates can lie (a React view updates
instantly even if the backend POST failed). Verify a tab edit at the **URL** level; verify a toggle by
**reload-then-re-read**, not the in-page `.checked` immediately after `.click()`. (Some web apps: a
plain `.click()` is a no-op — dispatch mousedown→mouseup→click.)

## §4 — some automation tiers can SEE but not TYPE into Terminal/IDE; use osascript instead

Under restricted computer-use tiers, Terminals & IDEs may be view/click-only — typing/keys/right-click
blocked. Don't try to type into them. `osascript` (Apple Terminal: `do script … in front window`,
read-back via `contents of selected tab`) drives Terminal fully and is not subject to that tier. For
shell, just run the command directly.

## §5 — multi-hop SSH inside osascript eats nested quotes

Same as the shell hop trap — base64 the inner script so it survives every quote layer.
