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

Probes take the world as ground truth. When a probe and a note disagree, the note gets corrected;
the three corrections in this branch were found exactly that way.

Exit codes: `0` holds · `1` drifted · `77` skipped (prerequisite missing, e.g. no docker, or a
case-sensitive volume for a claim scoped to the stock Mac default).

## Coverage

| Probe | Claim | Notes |
|---|---|---|
| `10-shell-word-split` | shell §1 §3 | zsh one-token vs bash split, `${=V}`, arrays |
| `11-shell-rsync-exclude-depth` | shell §4 | unanchored vs `/`-anchored `--exclude` |
| `12-shell-inplace-self-match` | shell §5 | `perl -i` rewrites the helper's own definition |
| `13-shell-rg-replace-flag` | shell §7 | `rg -rn` is `--replace=n` |
| `14-shell-pkill-argv` | shell §6 | path pattern misses; `; echo stopped` lies |
| `20-macos-path-exists-case` | macos §1 | case *and* NFC/NFD; `iterdir()` as the cure |
| `21-macos-git-case-rename` | macos §2 | the whole clean-status table, plus the undo |
| `22-macos-sed-i-suffix` | macos §5 | `sed -i -e` litters `file-e` |
| `23-macos-private-symlinks` | macos §6 | `/tmp` → `/private/tmp` |
| `24-macos-colliding-names-checkout` | macos §3 | `F.txt` + `f.txt`, permanently dirty |
| `25-macos-docker-bindmount-leak` | macos §4 | bind mount leaks case-insensitivity |
| `30-python-pep668-wall` | python §1 | externally-managed-environment; venv clears it |
| `31-python-mp-start-method` | python §2 | start method + the bootstrap recursion |
| `40-cpp-uninitialized-read` | cpp §1 | `-O2` folds it; pattern-init exposes it |

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

## Last full run

macOS 26.5.2 (arm64) · bash 5.3.15 · zsh 5.9 · git 2.51.0 · rsync 3.4.4 · ripgrep 15.1.0 ·
Python 3.14.6 (Homebrew) · Apple clang 21.0.0 · Docker 29.4.0 — **14 held, 0 drifted, 0 skipped**,
after the three corrections in this branch. Before them: 11 held, 3 drifted.
