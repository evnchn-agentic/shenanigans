# claude-code-shenanigans — the gates that halt your AGENT, not your disk

Every other file here is about a tool destroying something. This one is the inverse failure: the harness
interferes with your agent and your disk is never touched. It comes in two flavours.

- **Loud (§0–§5): the command never runs.** An unattended agent stops dead at an approval prompt and nobody
  is awake to click it. The cost is a wasted night.
- **Quiet (§6): the instructions never arrive.** The harness silently drops most of a hook's payload, the
  agent runs to completion on rules it never received, and nothing anywhere reports a problem. The cost is
  every session after the one that broke it.

> **This is a cooperation guide, not a bypass guide.** The goal is to write commands a static analyzer can
> *prove* safe, and to not attempt genuinely destructive things unattended in the first place. Every "fix"
> below is a command that is easier to read and safer than what it replaces. If a gate stops you, the answer
> is a better command or a deferred task — never a workaround. Working around a safety gate is itself a
> blocked move.
>
> Unaffiliated with Anthropic. Behaviour described was read out of one shipped build (see Provenance);
> re-derive after upgrading.

**Golden rule: the analyzer is not asking "is this dangerous?" — it asks "can I PROVE this is safe by reading
the string?" So write literal, simple, one-verb commands, and let the dedicated file tools do the rest.**

---

## 0. Two gates — and the hard half of the first cannot be fixed in settings

| | **Gate A — static bash analyzer** | **Gate B — permission classifier** |
|---|---|---|
| What | Hardcoded tree-sitter AST check on the literal command string. Deterministic. Runs **before** B. | An LLM judging the call against prose rules |
| Verdict | `behavior:"ask"` + a `bashMissKind` | allow / deny |
| Fix | **rewrite the command** | permission config |

### Gate A has two subsets — don't conflate them
The binary carries a per-decision flag, **`bashAllowRuleOverridable`**, so a Gate A `ask` is *not* uniformly
unfixable:

- **Non-overridable.** Destructive/unanalyzable checks — the possibly-empty-`$VAR` rm, protected-directory
  rm, `find -exec` under a prefix rule. These ship the sentence *"This requires explicit approval and
  **cannot be auto-allowed by permission rules**."* literally. No allowlist entry, no instruction file, no
  amount of stated user intent clears them.
- **Overridable / `passthrough`.** Plain `no-rule-match` is emitted as `behavior:"passthrough"`, and some path
  checks set `bashAllowRuleOverridable` — these *are* fixable with a well-scoped allow rule.

**Operationally the advice is the same either way: rewrite the command rather than chase config** — an
allowlist entry only helps the second subset, and you rarely know which you hit until you've already halted.
But don't believe Gate A is universally unfixable; that version of the claim is false.

## 1. The reframe that makes every rule below predictable

Read the actual refusal reasons and they are almost all *unanalyzability* complaints, not danger claims:
`"cannot be statically analyzed"`, `"path is runtime-determined"`, `"parser dropped content that shell will
see"`, `"cannot model statically"`. So:

- **"Dangerous" in a denial message ≈ "opaque to the parser."** A totally harmless command gets asked.
  Arguing with it is pointless; making it legible works.
- **Runtime-determined = asked.** If the effective target isn't visible in the literal text — `$VAR`,
  `$(cmd)`, a glob, a brace, a redirect target built by expansion — the analyzer cannot prove it and stops.
- **So the dodge for *analyzability* misses is: paste literals.** Resolve the value in an *earlier* tool call,
  then emit a command containing the answer, not the expression that computes it.

⚠️ **But literalizing is NOT a universal key.** A second family fires on *content*, not opacity: a fully
literal, perfectly parseable path is still refused if it names a protected target (§4.1). Legibility clears
the analyzer; it does not make a destructive target approvable — nor should it.

## 2. 🥇 The highest-leverage dodge: don't use Bash at all

The dedicated file tools (`Read` / `Edit` / `Write` / `Glob` / `Grep`) **do not pass through Gate A**. Most
halts are self-inflicted by reaching for `cat`/`sed`/`find`/`echo >` when a dedicated tool exists. This is
also the harness's own standing advice, and it doubles as protection from the `sed -i` / `perl -i` self-match
recursion trap in [`shell-shenanigans.md`](shell-shenanigans.md).

**Second-best: write the messy pipeline to a file, then run one simple command.** Write the script, then
`bash /abs/path/job.sh` — one literal argv, trivially parseable, Gate A satisfied. ⚠️ Honest trade-off: an
opaque script is exactly what **Gate B** tends to default-deny, so this buys A at some cost in B. Keep the
script's purpose obvious from its name, and prefer it for *mechanical* work, not for anything destructive.

## 3. The halt taxonomy — every `bashMissKind`, and what to write instead

Identifiers are verbatim from the shipped binary; trigger text is quoted from its own reason strings. **13
appear as literal `bashMissKind:"…"` assignments; at least one more (`net-redirect`) is assigned dynamically
and is invisible to the obvious grep** — treat this list as well-covered, not provably complete.

| Kind | Fires on | Write instead |
|---|---|---|
| `shell-operators` | subshell, command group, or **more than one command** — "uses shell operators that require approval" | **One command per tool call.** Don't chain `&&` for convenience |
| `shell-expansion` | a path arg containing `$(cmd)` or an untracked variable — "path is runtime-determined" | Resolve it in a previous call; paste the literal path |
| `too-complex` | the AST parse gave up | Split it. Long ≠ complex — *nested* is complex |
| `multi-cd` | ≥2 directory changes (incl. `pushd`) — "require approval for clarity" | Absolute paths — see the cwd reset note below |
| `cd-compound-write` / `-redirect` / `-git-compound` / `-multi-positional` | any `cd` in a compound command that then writes/redirects — "cannot automatically determine the final working directory" | Never `cd X && <write>`. Absolute paths, always |
| `process-substitution` | `<(...)`, `>(...)` — "can execute arbitrary commands" | A real temp file |
| `flag-validation` | flags on path-taking commands, because `--target-directory=PATH` bypasses path validation | Positional literal paths, no flags, on `cp`/`mv`/`ln`-class commands |
| `sed-dangerous` | sed carrying "redirect-borne content that cannot be statically validated (swallowed arguments, unanalyzable heredoc, or expansion in a redirect target)"; also a hard `-e[wWe]` / `-w[eE]` "Dangerous flag combination" | **Use the `Edit` tool** |
| `semantics` / `no-rule-match` | ordinary "no allowlist rule matched" | The overridable kind — an allow rule genuinely fixes this one |

### Redirects — a whole family of asks, all avoidable by using a literal target
Each is its own hardcoded refusal: target contains `$(cmd)` ("runtime-determined"); starts with `-` (bash
reads it as close-fd and **passes the rest to the command as a hidden argument**); starts with `!` (zsh
clobber/history expansion); starts with `=` (zsh expands to a PATH binary); contains a newline ("potential
path traversal"); contains braces ("bash may brace-expand to paths outside the working directory"); uses `>&`
(applies a *second* word-expansion pass). → **Redirect to one literal absolute path, or use the `Write` tool.**

Plus the **kind the obvious grep misses**: `net-redirect`, assigned dynamically
(`c==="network_device"||c==="unc_path" ? "net-redirect" : "shell-expansion"`), fires on redirect targets that
are `/dev/tcp`, `/dev/udp`, or a Windows UNC path. Bash turns `> /dev/tcp/host/port` into a network socket —
so if you actually want the network, use a real network tool; otherwise keep redirect targets local literal
files.

### The cwd reset (observed live)
`cd /tmp && <cmd>` ran, but the tool result appended **"Shell cwd was reset to …"** — and the binary carries a
matching telemetry event, `tengu_bash_tool_reset_to_original_dir`. So "working directory persists between
calls" holds for a **standalone** `cd`; a *compound* `cd X && …` is silently reverted afterwards. Don't build
a multi-call sequence on a cwd you set inside a compound command — it will be gone, and the failure is
silent. Absolute paths sidestep this and `multi-cd` at once.

### Command-specific traps
- **`find`** — `-exec`/`-execdir`/`-delete`/`-ok` "cannot be auto-allowed by a `Bash(find:*)` prefix rule",
  and unquoted globs "could glob-expand to a dangerous action before find runs". Use the `Glob` tool, or
  `find` for *listing only* with quoted patterns.
- **`awk`** — program text from a variable/substitution, `-f`/extension flags, or unquoted globs → asked.
- **`jq`** — `include`/`import` can load arbitrary `.jq` files.
- **`IFS=`** — "changes word-splitting — cannot model statically". Never reassign IFS.
- **zsh-isms** — `print -P` with `$(…)`, `$+/$^/$=/$~` prefix flags, `$name[expr]`/`$name:mod`, `$[...]`
  arithmetic, and `&&`/`]]` inside `[[ ]]` patterns all trip *shell cond-lexer divergence* checks. Even when
  your Bash tool runs bash, the analyzer still checks for zsh-divergent shapes — so avoid them.

## 4. `rm` — the canonical case, verbatim

> "This target is a shell variable expansion that points at the filesystem root (or a top-level directory)
> when the variable is unset or empty — e.g. `` rm -rf $UNSET/* `` becomes `` rm -rf /* ``. This requires
> explicit approval and **cannot be auto-allowed by permission rules**."

Two variants ship: on a bare variable path, and **inside command substitution**. A third
(`tengu_bash_dangerous_rm_too_complex`) fires when the rm is too tangled to analyze at all.

### 4.1 Protected targets — literal paths do NOT help here
Two further rm checks fire on **what you named, not how you wrote it**, and both carry the non-overridable
sentence. Verbatim, an rm that:

- *"would remove a critical system directory"*, or
- *"would remove a workspace directory (the working directory, an additional working directory, or **one of
  their parent directories**)"*

…requires explicit approval, full stop. The parenthetical is the sharp edge: a cleanup script that resolves
to the cwd — or anything *above* it — is refused however literal and well-formed it is. This is the one place
where "make it legible" is the **wrong** instinct: an agent that keeps rewriting the command to get it
through is working around a guardrail. Leave it for a human and carry on with the rest of the run.

**Otherwise, the fix is not a guard flag — it's not doing it.** Delete with a **literal absolute path**, one
target per call. If a path must be computed, compute it in a prior call, *read the resolved value*, then emit
the literal. That's better practice regardless of any harness: look before you delete.
⚠️ Untested: whether `${VAR:?}` / `set -u` satisfies the analyzer. No evidence in the binary that it is
special-cased — **assume it does not help** rather than relying on it.

## 5. Standing rules for any unattended run

1. **Dedicated tools over Bash.** Gate A is skipped entirely.
2. **One command, one call, literal absolute paths, no flags on path commands.**
3. **Never compute-and-act in the same command.** Resolve → read → act on the literal.
4. **Complex work → write a script → run it by absolute path** (mind the Gate B trade-off, §2).
5. **A block is not a puzzle to solve.** Find the safer path, or defer the item and keep the run moving.
   Consecutive blocks can pause a session outright, so each avoided ask is real budget.
6. **Headless/print mode ABORTS on a block**, where interactive merely pauses — worth knowing before you
   automate one.

## 6. The quiet one: a hook output over ~10 000 chars is truncated to 2 000, with no error

Everything above halts loudly. This one does the opposite, and it is worse for exactly that reason.

A hook returning `hookSpecificOutput.additionalContext` larger than **~10 000 chars** is written to a file,
and **only its first 2 000 chars are injected**. The model sees a short note naming a path. There is no
error, no warning, and nothing in the hook's own exit status changes — the hook "succeeded". An agent then
runs the whole session on instructions it was never given, and behaves exactly like an agent ignoring them.

**Why it ambushes you specifically when you add the second thing.** One payload under the limit works
forever and teaches you the mechanism is sound. Add a second payload **to that same hook's output** and the
concatenation crosses the limit, so the new one never lands **and the one that worked for months is now
truncated too**. The regression presents as "the old feature broke when I added a new one", which is the
wrong place to look. (Two *separate* hooks do not combine this way — see the fix below.)

**The fix is to split, not to compress**: the limit applies **per hook output**, not to the merged context
for that event. Sibling hooks on the same event arrive intact alongside a truncated one. So give each
payload its own hook entry (a `--flag` on the same script is enough) and keep every single output under
budget.

**Cheap probe, no instrumentation:** if the harness persisted a hook output, it left the file behind. On the
builds below, a `hook-*additionalContext*` file under a session's `tool-results/` means that hook output was
persisted, i.e. truncated. **Absence is weaker evidence than presence** — zero files is consistent with
"every hook fit" *and* with "the hook never ran", a changed path layout, or a different naming scheme on
your build. Confirm the hooks actually fired before reading zero as all-clear.

If you write hooks that grow with content you do not control (injecting a file, a doc, a ruleset), four
habits keep this from ever being silent again:

1. **Split** so each invocation is independently under budget.
2. **Measure your own output** and prepend a loud `OVERSIZE` line when it would cross. The warning then
   lands *inside* the surviving 2 000 chars, which is the only real estate you are guaranteed.
3. **Check your own wiring.** If installing a payload takes two steps (a flag file *and* a settings entry),
   have the script detect the half-installed state and say so. Half-installed is silently inert.
4. **Make a malformed argument shout.** "Emits nothing" is indistinguishable from "correctly had nothing to
   say", and a hook that emits nothing is invisible.

**Confidence, honestly split.** The 2 000-char preview is a verbatim constant. The ~10 000 ceiling is an
*inference*: the persistence path takes a `Math.min` of a per-caller size and a ceiling, and `1e4` is the
only **discovered** candidate consistent with measurement — measurement brackets it, since a 6.8 KB output
was never persisted across months of sessions while a 19.3 KB one was persisted on its first. That does not
exclude a computed or aliased ceiling the grep below cannot see (several candidates are identifiers, not
literals). So treat 10 000 as a **working number, not a proved constant**, and leave real headroom rather
than tuning to it. Re-derive after any upgrade:

```bash
B=$(readlink -f ~/.local/bin/claude)
strings -n 8 "$B" | /usr/bin/grep -o 'Output too large.\{0,120\}' | sort -u   # the persist message
strings -n 8 "$B" | /usr/bin/grep -o 'maxResultSizeChars:.\{0,20\}' | sort -u  # candidate ceilings
```

Same mechanism governs oversized **tool results**, where it is far less silent — the model sees the note and
can read the file, though it will still act on a truncated result if it doesn't. A hook is the sharp case
because the note arrives with no agent watching for it.

## 7. Provenance & how to re-derive

Read out of the **running** binary (`readlink -f` your `claude` launcher → a bun-compiled Mach-O), build
**2.1.223**, macOS/arm64, 2026-08. Every quoted reason string and `bashMissKind` identifier is verbatim from
that build, not recalled.

**§6 is a later, separately-sourced addition**: constants read from **2.1.224**, behaviour measured live on
2.1.224, and both greps re-run against **2.1.226** with the same constants present. It is version-pinned the
same way everything else here is — re-derive after an upgrade rather than trusting the number.

```bash
B=$(readlink -f ~/.local/bin/claude)
# literal assignments AND the dynamic ternary ones (plain :"[a-z-]*" misses net-redirect)
strings -n 8 "$B" | /usr/bin/grep -o 'bashMissKind:.\{0,80\}' | sort -u
strings -n 8 "$B" | /usr/bin/grep -o '.\{0,200\}cannot be auto-allowed.\{0,60\}' | sort -u
```

**Three grep traps, all hit while writing this** (meta-shenanigans, and they cost real time):
- If `grep` on your PATH is **ugrep**, it errors (`error at position N`) on the wide `.{N}` windows these
  minified one-line bundles need. Use `/usr/bin/grep`. One ugrep error, `exceeds complexity limits`, reads
  exactly like a denial string and is **not** one — it's ugrep complaining about *your pattern*. It nearly
  got cited as a finding.
- `/usr/bin/grep` then caps repetition at **255** (`maximum repetition exceeds 255`) — keep each `.{0,N}`
  window ≤255 and widen in steps rather than one big grab.
- Long strings are **split across JS `+` concatenation**, so a message can exist while a single-window grep
  for its middle returns nothing. Search a distinctive fragment, then walk outward.

**Confidence split:** the *rules* (what trips, exact wording) are verbatim and high confidence. The
*rewrites* in the "write instead" column are inferred from the reason text and general shape, and are **not**
individually probed — deliberately, since probing a Gate A block means eating the halt this file exists to
prevent. Treat column 3 as well-grounded guidance, not measured fact.

**Fresh-lineage reviewed** (Codex, 2026-08-07): caught that the original draft generalised the
"cannot be auto-allowed" sentence from the destructive-`rm` checks to *all* kinds (§0 now splits overridable
vs not), that `net-redirect` was missing and the re-derive grep structurally couldn't find it, and that
"paste literals" was stated as a universal dodge — which would have misled a reader about protected
destructive targets (§4.1). All three were confirmed against the binary before being folded in. The drafting
model caught none of them itself.
