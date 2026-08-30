# macos-shenanigans — READ before trusting any filename check on a Mac

> **The golden rule: on a stock Mac a path *lookup* is fuzzy, but a directory *listing* is exact.**
> `exists()` / `open()` / `[ -f ]` will happily resolve a name whose case — or Unicode
> normalization — does not match what is on disk. `readdir()` returns the bytes as stored.
> So the dev Mac says "the file is there", the Linux server 404s, and nothing warns you.
> Everything below is empirically reproduced on APFS (macOS 26, git 2.5x).
>
> **Scope:** macOS ships **case-insensitive APFS** as the default boot format, which is why this
> bites every stock Mac — but a case-**sensitive** APFS volume is a supported option (§3), so
> none of this is a property of "APFS" as such. Check the volume you are actually on:
> ```console
> $ touch ./_A; [ -e ./_a ] && echo "INSENSITIVE (this file applies)" || echo "sensitive"; rm ./_A
> ```

## §1 — `Path.exists()` is case-insensitive; it CANNOT guard a filename

```python
Path('logo.webp').exists()          # True
Path('Logo.webp').exists()          # True   <-- only this one is real
{p.name for p in Path('.').iterdir()}    # {'Logo.webp'}  <-- the truth
```

A default-format Mac volume is case-**insensitive** but case-**preserving**. Any code that derives a path from a key
(`f'/static/{key}.webp'`, an import, an asset manifest, a URL route) and validates it with
`exists()` is unguarded: it renders fine locally and 404s on the case-sensitive server.

**Cure — compare against a directory listing, never a stat:**
```python
if name not in {p.name for p in dir.iterdir()}:
    raise SystemExit(f'{name} missing (case matters on the server)')
```
`iterdir()` returns names exactly as stored, so the string compare is case-sensitive on
*every* platform — the guard **fails on the Mac**, reproducing the Linux-only bug locally.

**Same trap, different axis:** APFS is also normalization-**insensitive**. A filename written
as NFC `café.txt` is stored NFC, but `exists()` returns True for the NFD spelling too (older
HFS+ went further and *stored* names in a decomposed form — Apple's own Unicode-3.2-based
decomposition, close to but not byte-identical with NFD). Identical cure — compare listed names, and compare
them normalized if you accept user-supplied filenames.

## §2 — git is BLIND to a case-only rename: a clean `git status` does not mean the tree matches HEAD

With `core.ignorecase=true` (the macOS default), after `mv Logo.webp logo.webp`:

| command | result |
|---|---|
| `git status --porcelain` | *(empty — reports clean)* |
| `git ls-files` | `Logo.webp` |
| `ls` | `logo.webp` |
| `git add -A` | stages nothing |
| `git checkout -- .` | no-op, disk keeps the new name |

So you can neither commit the rename nor undo it with the usual commands, and every "is my
tree clean?" check lies. **This is the trap that hides a half-finished rename during a
review** — you believe you reverted, and you did not.

**Cures**, in order of preference:
- `git mv old new` — handles case-only renames correctly even without `-f`.
- `git config core.ignorecase false` in that repo — git then sees the rename as add+delete.
- To undo it: **`rm` the wrongly-cased file, then `git checkout -- .`** This is the one that
  always works, because the path is genuinely absent when checkout runs.
- **`git reset --hard` is NOT a reliable undo here**, despite looking like the obvious one. It
  restores the stored spelling only when git already considers the path **dirty** — because then it
  rewrites the file, and the write resolves back onto the stored name. A case-*only* rename is
  **clean**, so there is nothing to rewrite and the wrong spelling survives. Content changes and
  mode changes both count as dirty; the casing alone does not:

  ```console
  $ mv Logo.webp logo.webp && git reset --hard -q && ls *.webp
  logo.webp                      # clean -> reset did nothing
  $ echo x >> logo.webp   && git reset --hard -q && ls *.webp
  Logo.webp                      # content dirty -> rewritten, correctly cased
  $ mv Logo.webp logo.webp && chmod +x logo.webp && git reset --hard -q && ls *.webp
  Logo.webp                      # mode dirty -> same
  ```

  Which is worse than a rule you can rely on either way: the *same command* silently does or does
  not undo the rename depending on whether you also happened to touch the file.

  So "I reset --hard, so I'm back to HEAD" is exactly the false-clean belief this section warns
  about, one level up. (git 2.51.0, macOS 26.5.2.)

## §3 — a repo that legitimately contains `F.txt` **and** `f.txt` cannot be checked out on macOS

`git clone` warns once, then writes **one** of the two, and the survivor's twin is left
permanently `modified` in `git status`. You cannot reach a clean tree; `checkout`, `stash`
and `reset --hard` will not clear it.

In the run above (git 2.5x) nothing was lost: `git commit -a` and even an explicit
`git add F.txt` staged nothing, because the alias resolved to the survivor whose content
already matched the index. **Do not lean on that** — git's alias handling here is a guard,
not a documented guarantee, and the survivor's spelling is what an explicit path resolves to.
Treat the state as unsafe to commit from, not as safe-by-construction. Either way CI is green
on Linux while the Mac dev is permanently dirty and cannot bisect or `stash` cleanly.

**Cure:** put that checkout on a case-sensitive volume —
`diskutil apfs addVolume disk1 "Case-sensitive APFS" code` — and work there.

## §4 — proving it on Linux: a bind mount from APFS LEAKS the case-insensitivity

The obvious "just run it in a container" check is invalid if the files come in over `-v`:

```console
$ docker run --rm -v "$PWD":/m alpine test -e /m/logo.webp && echo EXISTS
EXISTS          # wrong case, and the container's own rootfs IS case-sensitive
```

The host filesystem resolves the path, so the mount inherits macOS semantics. **Copy the
files onto the container's own filesystem first** (`cp /m/* /c/`, or `COPY` in a Dockerfile)
— then the wrong case is genuinely absent and the test means something.

## §5 — BSD `sed -i` takes a mandatory backup suffix; `sed -i -e` silently litters `file-e`

GNU `sed -i 's/x/y/' f` is a syntax error on macOS (`-i` eats `s/x/y/` as the suffix, then
tries to run `f` as the script). The muscle-memory fix — adding `-e` — *works* but writes a
backup you did not ask for:

```console
$ sed -i -e 's/a/b/' s.txt
$ ls s.txt*
s.txt   s.txt-e          # committed by accident more often than anyone admits
```

Use `sed -i '' 's/x/y/' f` on macOS, or better: for surgical edits prefer an exact
old→new editor over in-place regex (see `shell-shenanigans.md` §5 — `sed -i`/`perl -i` are
irreversible without a backup, and can self-match).

## §6 — `/tmp`, `/var` and `/etc` are symlinks into `/private`

`os.path.realpath('/tmp')` → `/private/tmp`. Any code comparing a resolved path against a
literal `/tmp/...` prefix — sandbox allowlists, "is this file inside my temp dir?" checks —
fails on macOS only. Compare resolved-against-resolved, never resolved-against-literal.
