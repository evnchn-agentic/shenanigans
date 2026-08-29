# verify/ — do these claims still reproduce?

Every note in this repo says its traps are **empirically burned**. That authority has a silent
failure mode: a trap that was real in June and has been fixed, or was never quite stated right, still
reads exactly as convincing. Nothing in the repo could tell you which.

`./verify/run.sh` re-runs the mechanically testable claims against the machine you are on.

```console
$ ./verify/run.sh              # everything
$ ./verify/run.sh macos        # just the macos probes
```

Exit 0 = every claim that could run still holds. Exit 1 = a claim drifted, and **the `.md` is now
wrong**, not the probe.

## How a probe is built

Each probe asserts **both directions**: the trap shape misbehaves *and* the documented cure behaves.
A probe that only checked the trap could pass for the wrong reason — it would still pass on a machine
where the cure had quietly stopped working, which is half the advice.

A probe that **cannot observe** must skip, never pass. A reviewer ran this branch in a sandbox where
`ps` returned *Operation not permitted*, and `14-shell-pkill-argv` went green: `ps` failing read as
"the argv has no path", and `pkill` failing to see any process read as "the pattern matched nothing".
Both are the expected answers, reached by being blind. Probes whose evidence comes from inspecting
the machine now prove they can inspect it first.

Probes take the world as ground truth. When a probe and a note disagree, the note gets corrected;
the three corrections in this branch were found exactly that way.

Exit codes: `0` holds · `1` drifted · `77` skipped (prerequisite missing, e.g. no docker, or a
claim scoped to an OS you are not on).

**A claim scoped to one OS must SKIP elsewhere, never fail.** Before this guard existed, a Linux run
reported `DRIFTED` for macos §5 (BSD `sed -i`) and §6 (`/private` symlinks) — a red run that meant
nothing, which is worse for a verifier than no run at all.

## When this actually runs

These claims go stale because the **world** changes — a new git, a new CPython, a new macOS — not
because the repo changes. So `.github/workflows/verify.yml` runs weekly on a schedule across
`macos-latest` and `ubuntu-latest`, and on a pull request only when `verify/` itself is touched.
A per-commit gate would be the wrong instrument for this failure mode.

## Coverage

| Probe | Claim | Notes |
|---|---|---|
| `10-shell-word-split` | shell §1 §3 | zsh one-token vs bash split, `${=V}`, arrays |
| `11-shell-rsync-exclude-depth` | shell §4 | unanchored vs `/`-anchored `--exclude` |
| `12-shell-inplace-self-match` | shell §5 | `perl -i` rewrites the helper's own definition |
| `13-shell-rg-replace-flag` | shell §7 | `rg -rn` is `--replace=n` |
| `14-shell-pkill-argv` | shell §6 | path pattern misses; `; echo stopped` lies |
| `20-macos-path-exists-case` | macos §1 | case *and* NFC/NFD; `iterdir()` as the cure |
| `21-macos-git-case-rename` | macos §2 | the whole clean-status table; `reset --hard` on clean / content-dirty / mode-dirty |
| `22-macos-sed-i-suffix` | macos §5 | `sed -i -e` litters `file-e` |
| `23-macos-private-symlinks` | macos §6 | `/tmp` → `/private/tmp` |
| `24-macos-colliding-names-checkout` | macos §3 | `F.txt` + `f.txt`, permanently dirty |
| `25-macos-docker-bindmount-leak` | macos §4 | bind mount leaks case-insensitivity |
| `30-python-pep668-wall` | python §1 | externally-managed-environment; venv clears it |
| `31-python-mp-start-method` | python §2 | the whole per-platform table + the bootstrap recursion; portable |
| `40-cpp-uninitialized-read` | cpp §1 | symptom only: `-O2` *and* `-O0` print the lucky value; pattern-init exposes it |

## What is deliberately NOT probed

Naming these matters as much as the table above: an unprobed claim is **unchecked**, not confirmed.

- **`gfm-` / `github-api-` / `git-shenanigans.md`** — the evidence is a permanent cross-reference, a
  closed PR, or a deleted branch on someone's live timeline. Verifying these costs the exact damage
  they warn about. They stay hand-verified.
- **`applescript-shenanigans.md`** — drives the user's real Chrome and needs the app frontmost;
  destructive and not reproducible unattended.
- **`claude-code-shenanigans.md`** — describes a harness's permission classifier, which is not a
  local, versioned artifact.
- **shell §0 (hardware) and §2 (SSH hops)** — §0 is doctrine about physical actuators; §2 needs a
  second host.
- **python §3 (`pip install -e .` without `.git`)** — needs the network and a VCS-version build
  backend, and the outcome is backend-specific by the note's own admission.
- **python §4 / cpp's generalizations** — stated as method, not as a single reproducible behavior.

One probe is weaker than it looks and says so: `40-cpp-uninitialized-read` shows the *symptom* (a
green build printing the right answer) but cannot show the *mechanism* (whether `-O2` folded the read
or the stack slot was simply zero). It is evidence that the advice is needed, not evidence for the
compiler's reasoning.

## Last full run

macOS 26.5.2 (arm64) · bash 5.3.15 · zsh 5.9 · git 2.51.0 · rsync 3.4.4 · ripgrep 15.1.0 ·
Python 3.14.6 (Homebrew) · Apple clang 21.0.0 · Docker 29.4.0 — **14 held, 0 drifted, 0 skipped**,
after the corrections in this branch. Before them: 11 held, 3 drifted.

Also green on Linux: `python:3.14-slim` (**4 held, 0 drifted, 10 skipped**) and `python:3.13-slim`,
which is where the `forkserver` half of the python §2 table was measured.

Probes skip rather than fail when a prerequisite is absent, so a Linux run reports far fewer than 14
held. That is the honest answer, not a pass — and it is why the schedule runs both platforms.
