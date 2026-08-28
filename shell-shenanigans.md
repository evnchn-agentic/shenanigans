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
Symptoms: the **whole string** is reported back at you as if it were one command name — but the
*wording* depends on whether that string contains a `/`, which is easy to grep past:

```console
$ zsh -c 'CMD="rsync -av --delete";        $CMD'
zsh:1: command not found: rsync -av --delete
$ zsh -c 'CMD="rsync -a src/ host:/dst/";  $CMD'
zsh:1: no such file or directory: rsync -a src/ host:/dst/     # a slash makes it a PATH lookup
```

Also `File name too long` (a giant single token handed to a tool). Tell: a loop that
**"succeeds (exit 0) but does nothing"** — the 0 came from a trailing `echo`.

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

## §6 — `pkill -f "dir/name.py"` silently matches NOTHING after a `cd`, and `; echo stopped` lies about it

`pkill -f` matches a process's **actual argv**, not the path you think of it by. `cd /some/dir &&
nohup python demo.py &` yields argv `python demo.py` — so `pkill -f "some/dir/demo.py"` matches
nothing and exits 1, while the server keeps listening (observed: a dev server still up **5 days**
after being reported stopped).
- The lie is in the composition, not the kill: `pkill -f "…" ; echo stopped` prints `stopped`
  unconditionally, and `pkill -f "…" && echo killed; echo done` reports the *last* command's status.
  A cleanup command's exit code is never evidence of cleanup.
- **Kill by PID captured at launch** — `nohup cmd & echo $!` — or run `pgrep -fl <coarse>` FIRST and
  read the real argv before choosing a pattern.
- **Verify the effect, not the command**, as a separate step: `lsof -nP -iTCP:<port> -sTCP:LISTEN`,
  or a re-`pgrep`. "The kill command ran" and "the process is gone" are different claims.
- Opposite failure, worse: `pkill -f` matches the pattern **anywhere in the full command line**, so a
  broad pattern (`pkill -f python`) can kill unrelated processes — including the agent harness or the
  shell issuing the command. Narrow the pattern, or use the PID.

## §7 — `rg -r` is `--replace`, NOT "recursive" — `rg -rn` silently rewrites every match

Muscle memory from `grep -rn` types `-rn` at ripgrep. But **rg recurses by default**, and `-r` takes
an argument: `-r REPLACEMENT` / `--replace=REPLACEMENT`. So `rg -rn 'pat' path` parses as *"replace
each match with the string `n`"* — the `-n` you meant is eaten as the replacement value.

MRE:

```console
$ printf 'alpha beta\n' | rg -rn 'alpha'
n beta                     # match rewritten to "n"; no line number
$ printf 'alpha beta\n' | rg -n 'alpha'
1:alpha beta               # what you wanted
```

**Why this is worse than a normal typo: it does not error, and the output still looks like results.**
You get real file paths and real surrounding line content — only the matched substring is replaced.
Searching source for API calls with `rg -rn 'mermaid\.[a-zA-Z]+'` returns lines reading `n()` and
`n.org`, which parse as plausible identifiers. An agent (or human) can read that output and conclude
the code calls a different API than it does. Observed 2026-08-08 while auditing which mermaid
functions a project used; the real calls were `mermaid.initialize()` / `mermaid.render()`.

- **The tell: your line numbers vanished.** If you asked for `-n` and got no `N:` prefixes, `-n` was
  consumed as an argument. Same tell for `rg -rl`, `rg -ri`, etc.
- **Fix: just drop the `-r`.** `rg -n 'pat' path` — recursion is already the default.
- If you genuinely want replacement, write it unambiguously: `rg --replace='X' 'pat'`, never bundled
  into a short-flag cluster.
- Same family as a sweep returning **all zeros**: output shaped like data, produced by a wrong flag
  rather than by the corpus. Sanity-check any search whose result would change a conclusion — grep
  for a string you *know* is present and confirm it comes back verbatim.
