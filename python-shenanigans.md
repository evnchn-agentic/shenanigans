# python-shenanigans — READ before writing/installing Python

> **Python looks friendly and forgiving — that's exactly how it bites.** The items below are
> empirically burned. Skip this and the friendliness becomes a silent `exit 0` that did nothing, or
> an infinite-recursing process.

## §1 — `pip install` hits the PEP 668 "externally-managed-environment" wall → use a venv, NEVER `--break-system-packages`

Modern system Pythons (Debian/Ubuntu, Homebrew) refuse `pip install` outside a venv with
`error: externally-managed-environment`. The tempting one-liner `--break-system-packages` can break a
package-manager-managed Python — on Debian/Ubuntu, the system Python that OS tools depend on — so
don't. Always:
```bash
python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt
```

## §2 — top-level `Pool()` / `Process()` / `Queue()` / native-GUI `run()` with NO `__main__` guard → bootstrap-recurse

`fork` doesn't re-import the parent module; `spawn` and `forkserver` DO — and the default start
method is **per-platform**:

| platform | default | re-imports the parent module? |
|---|---|---|
| macOS | `spawn` (since 3.8) | **yes** — this has always bitten |
| Linux | `fork` → **`forkserver` in CPython 3.14** | **yes**, newly, on 3.14+ |
| Windows | `spawn` | **yes** |

So the 3.14 change is the *Linux* one; a Mac has been in the trap for years. Either way the
unguarded module re-imports itself and raises:
```
RuntimeError: An attempt has been made to start a new process before
the current process has finished its bootstrapping phase.
```
The **blast radius** differs, though, and only one of them runs away: `spawn` re-execs a fresh
interpreter per child, each of which re-imports and spawns more (measured: 262–282 of that
traceback in 6 seconds on macOS, across six runs), while `forkserver`, with its default preload of
`__main__`, imports once in the single server process, trips the same check, and that process exits
(a stable 1). So the 3.14 Linux change makes this failure *louder*, not unbounded — the runaway is
the macOS/Windows shape.

Check yours with `python3 -c 'import multiprocessing as m; print(m.get_start_method())'` — do not
assume it from the Python version alone. Universal fix: wrap the entry point in
`if __name__ == '__main__':`. Bites native-window GUI
frameworks (e.g. NiceGUI `ui.run(native=True)`) at top level, any worker pool, anything
multiprocessing outside `__main__`.

## §3 — `pip install -e .` silently installs NOTHING when `.git` is missing/excluded

Packages with a VCS/dynamic-version backend (setuptools-scm / hatch-vcs / poetry-dynamic-versioning)
need `.git` to build. Copy/rsync a repo with `.git` excluded and `pip install -e .` can **silently
misbehave** — depending on the backend, it may exit 0 with **nothing installed** or install a **bogus
fallback version** (e.g. `0.0.0`). Always verify with `pip show <pkg>` + the import path. Workaround:
install deps from PyPI, then shadow with the source tree via `PYTHONPATH`:
```bash
venv/bin/pip install <pkg> <extra-deps>              # full dep tree from wheels
PYTHONPATH=/path/to/repo venv/bin/python script.py   # source tree shadows installed
python -c "import <pkg>; print(<pkg>.__file__)"       # verify it's the repo path
```

## §4 — verify it actually ran, not that it exited 0

A Python script that imports a missing module, or whose multiprocessing child died, can still leave
exit 0 on the parent / a benign-looking log. Run it, read the actual output / check the artifact —
don't trust the absence of an error.

## §5 — `\"` inside an f-string in an inline `python3 -c` → SyntaxError; `2>/dev/null` turns it into a silent empty string

Parsing one field out of JSON in a poll loop, you reach for:

```bash
curl -s "$URL" | python3 -c 'import sys,json
d=json.load(sys.stdin); print(f"{d.get(\"state\")}|{d.get(\"detailed_merge_status\")}")' 2>/dev/null
```

The `\"` is **self-inflicted**: the `-c` argument is already single-quoted, so inner double quotes need
no escaping (see (a) below). Passed through anyway, the backslash lands *inside an f-string replacement
field*, where it is not a string escape but a **line continuation**, and modern CPython rejects it:

```
SyntaxError: unexpected character after line continuation character
```

Alone that's loud. The kill is the `2>/dev/null` stapled on to keep the loop quiet: the command now
prints **nothing** and exits 1, so `x=$(…)` is `""` and a test like `[ "$state" = merged ]` can never
match. An empty status reads as "not done" — so a monitor loop **stalls silently until its timeout**
while the thing it was watching already succeeded. (Burned exactly this way in a merge-train poll loop:
the MR merged; the loop kept reading the empty string.)

Three ways out, increasing in robustness:

```bash
# (a) drop the escaping — inner " are fine inside a single-quoted -c (CPython 3.12+ / PEP 701)
python3 -c 'import sys,json; d=json.load(sys.stdin); print(f"{d.get("state")}|{d.get("detailed_merge_status")}")'

# (b) portable, no nesting at all — %-format
python3 -c 'import sys,json; d=json.load(sys.stdin); print("%s|%s" % (d["state"], d.get("detailed_merge_status")))'

# (c) best — put the parser in a real file; pipe JSON to it
cat > /tmp/mrinfo.py <<'PY'
import sys, json
d = json.load(sys.stdin)
print("%s|%s" % (d.get("state"), d.get("detailed_merge_status")))
PY
curl -s "$URL" | python3 /tmp/mrinfo.py
```

Measured on CPython **3.14.7** — this is the tokenizer, not the old ≤3.11 "no backslash in f-strings"
restriction, so a recent Python does *not* save you.

**General rule (this is a special case): never `2>/dev/null` a parser whose output drives control
flow.** If you must quiet it, preserve the exit status (`… || echo PARSE_FAIL`, or `${PIPESTATUS[1]}`)
so a broken parse is a *distinct* value instead of masquerading as valid empty output. Same family as
§4 — "it exited 0 / printed nothing" is not "it worked".
