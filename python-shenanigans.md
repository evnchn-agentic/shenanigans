# python-shenanigans — READ before writing/installing Python

> **Python looks friendly and forgiving — that's exactly how it bites.** The items below are
> empirically burned. Skip this and the friendliness becomes a silent `exit 0` that did nothing, or
> an infinite-recursing process.

## §1 — `pip install` hits the PEP 668 "externally-managed-environment" wall → use a venv, NEVER `--break-system-packages`

Modern system Pythons (Debian/Ubuntu, Homebrew) refuse `pip install` outside a venv with
`error: externally-managed-environment`. The tempting one-liner `--break-system-packages` corrupts
the system Python the OS depends on — don't. Always:
```bash
python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt
```

## §2 — top-level `Pool()` / `Process()` / `Queue()` / native-GUI `run()` with NO `__main__` guard → bootstrap-recurse

`fork` doesn't re-import the parent module; `spawn` and `forkserver` DO. **CPython 3.14 changed the
POSIX default `fork` → `forkserver`**, so code that worked on 3.10–3.13 now infinite-recurses with:
```
RuntimeError: An attempt has been made to start a new process before
the current process has finished its bootstrapping phase.
```
Universal fix: wrap the entry point in `if __name__ == '__main__':`. Bites native-window GUI
frameworks (e.g. NiceGUI `ui.run(native=True)`) at top level, any worker pool, anything
multiprocessing outside `__main__`.

## §3 — `pip install -e .` silently installs NOTHING when `.git` is missing/excluded

Packages with a VCS/dynamic-version backend (setuptools-scm / hatch-vcs / poetry-dynamic-versioning)
need `.git` to build. Copy/rsync a repo with `.git` excluded, `pip install -e .` → **exits 0,
installs nothing** (`pip list` shows only pip; `import pkg` → ModuleNotFoundError). Workaround:
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
