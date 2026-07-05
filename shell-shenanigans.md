# shell-shenanigans — READ before writing any shell loop (zsh or bash)

> **Skip this and you WILL be bitten.** These are empirically burned, not theoretical. A shell
> shenanigan that runs a script *halfway* is the single most dangerous failure mode here — see §0.

> ### ⚠️ SCOPE — most of this is shell-AGNOSTIC; only §1 & §3 are ZSH-specific
> - **ALWAYS apply, any shell:** §0 (hardware atomic/self-disarm — catastrophic-tier), §2 (SSH
>   quoting), §4 (rsync exclude anchoring), §5 (sed/perl self-match).
> - **ZSH-ONLY:** §1 & §3 (`$VAR` no word-split). Under **bash** the behaviour is the OPPOSITE
>   (`$VAR` DOES split → **quote it**), so that advice is wrong-for-bash and must not fire there.
> - **Which shell am I in?** Run `echo "${ZSH_VERSION:+ZSH}${BASH_VERSION:+BASH}"`. Don't trust the
>   terminal's advertised login shell — the shell your tool/automation actually runs commands in can differ.

## §0 — Irreversible / hardware scripts must be ATOMIC and SELF-DISARMING (highest stakes)

A script that arms hardware (a motor driver, relay, actuator, smart plug — anything physical) **must
not depend on a *second* invocation to disarm it.** Between two automation steps there is a round-trip
— and a network blip, a server hiccup, or a shell shenanigan halting the first script can make
"energize for 3 s" become 30 s, or **never disarm at all**.

Rules:
- **One script does arm → wait → disarm**, never split across calls. Put the disarm in a `trap`
  (fires on error / Ctrl-C / SIGTERM — **not** on SIGKILL / `kill -9`, which cannot be trapped), and
  bound the whole run with `timeout` from the caller so even a hang disarms.
  ```bash
  trap 'disarm' EXIT INT TERM      # normal exit, Ctrl-C, SIGTERM, AND script error — but NOT kill -9
  arm; sleep 3; disarm             # disarm also runs explicitly; the trap is the safety net
  # caller bounds it:   timeout 10 ./arm-and-run.sh
  ```
- Prefer a **hardware-side watchdog / dead-man timer** (firmware disarms itself if not pinged) over
  any host-side timing. The host is the unreliable party.
- A physical power cut (e.g. a smart plug) is the real e-stop — **never assume the next step lands.**
- `set -euo pipefail` so a mid-script failure *stops* rather than silently continuing past a bad step.

## §1 — zsh does NOT word-split an unquoted `$VAR` (the classic "loop did nothing") [ZSH-ONLY]

> Fires only when your shell is zsh. Under **bash** the opposite is true — unquoted `$VAR` DOES
> word-split — so the fix there is the normal one: **quote it** (`"$VAR"`) / use arrays for lists.

zsh (unlike bash) does **not** split an unquoted parameter expansion into words. So storing a
multi-word command in a scalar and running it unquoted fails:

```zsh
CMD="rsync -a -e 'ssh -o StrictHostKeyChecking=no' src/ host:/dst/"
$CMD          # -> zsh: command not found: rsync -a -e ...  (the WHOLE string is ONE token)
```
Symptoms: `command not found: <the whole string>` / `<first arg>` / `File name too long` (a giant
single token handed to a tool). Tell: a loop that **"succeeds (exit 0) but does nothing"** — the 0
came from a trailing `echo`.

**Fixes (root-first):**
- **Inline the full command every call** — most robust. Shell state doesn't persist between separate
  automation calls anyway, so a var buys you nothing but this trap.
- Array: `cmd=(rsync -a src/ host:/dst/); "${cmd[@]}"`
- Force-split: `${=VAR}` or `${(z)VAR}`
- File lists: `find … -print0 | xargs -0 tool`  (not `tool $files`)

## §2 — quoting across SSH hops eats your inner quotes

Multi-hop SSH silently runs the wrong/empty command when nested quotes collapse. base64 the inner
script so it survives every quote layer; `setsid … </dev/null` to detach.

## §3 — `$VAR` storing a multi-word cmd is the recurring offender [ZSH-ONLY]

This class recurs across many sessions even after you "know" it. If you're about to write
`CMD="… many words …"; $CMD` under zsh — stop, inline it (or use an array).

## §4 — `rsync --exclude=NAME/` matches NAME/ at ANY depth (destructive)

`--exclude=screenshots/` drops **every** `screenshots/` in the tree, not just the top-level one — e.g.
wanting to drop root `/screenshots/` (ad-hoc captures) but keep `docs/screenshots/` (README images),
an unanchored exclude wipes BOTH → broken image links shipped.
- **Anchor to the source root with a leading slash:** `--exclude=/screenshots/`.
- Leave unanchored only for match-anywhere dirs (`node_modules/`, `.git/`, `.DS_Store`).
- After any zip/rsync with same-named dirs at different depths, run a dead-link audit on the artifact
  (extract → grep README/HTML/CSS for asset paths → `[ -f "$p" ]` each).

## §5 — `perl -i -pe 's/X/helper()/g'` / `sed -i` matches INSIDE the helper definition → infinite recursion

A global text replace doesn't know a call-site from the definition, so extracting a helper for a
repeated literal turns the helper body into `helper() => helper()`. Silent: syntax-checks pass, the
recursion only fires at first runtime call.
- **Prefer a targeted editor** (exact old/new) over `perl -i`/`sed -i` for surgical swaps — it won't
  self-match.
- If regex is unavoidable: anchor on the call-site-only form, or define the helper in a sentinel
  shape the regex won't match, then re-edit. **Always run the full test suite / E2E after the replace.**
- Note `perl -i`/`sed -i` edit in place = irreversible without a backup — copy or `git bundle` first (see git-shenanigans §3).
