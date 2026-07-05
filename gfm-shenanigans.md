# gfm-shenanigans — READ before writing GitHub markdown (comment / PR / review / commit msg)

> **The rule: backticks turn GitHub autolinking OFF** (issue refs, SHAs, emoji, emphasis). Never
> backtick a *live* ref (ticket `#N` or commit SHA) you want linked; for a number that's just a
> *label*, write prose — never `#N`.
>
> **Catastrophic:** a bare `#N` in a GitHub conversation autolinks to issue/PR N **and posts a
> cross-reference into that ticket's timeline. Treat it as irreversible** — editing/deleting your
> comment does NOT retract it (a deleted comment still leaves its backlinks; there is no API to remove
> a cross-reference event). Fires on even a one-line reply → prose/escape **before the first post**.
> - `@name` is a *different* trap: it **pings** that user (no take-backs) — don't `@` a stranger.
> - `Fixes` / `Closes` / `Resolves #N` in a PR body **auto-closes issue N on merge** (when the PR
>   targets the repo's default branch) — don't use those verbs unless you mean it.

| Writing… | Do | Not | Why |
|---|---|---|---|
| a **label** ("finding 6", point/item N) | prose **"Finding 6"** | `#6` (spams a backlink) · `` `#6` `` (dead text, reads as a mislabeled ticket) | no link *or* backlink wanted |
| a **real ticket ref** to link | bare **`#123`** | `` `#123` `` (backticks kill the link) | you *want* the autolink |
| a **commit SHA** | bare **`a1b2c3d`** (resolvable 7+/40-char SHA → autolinks, hover) | `` `a1b2c3d` `` (dead text) | backticks kill the useful link |
| a ticket you must name but NOT link | escape **`\#6`** (renders "#6", no link) | bare `#6` | suppression fallback when prose won't do |

**Cosmetic (visible, reversible — backtick the literal):** `<T>` / `Vector<int>` can be parsed as HTML and vanish · inside a table escape `|` as `\|` · at line start `1.` / `-` / `>` / 4-space → stray list/quote/code (ordered lists auto-renumber) · intraword `*` emphasizes (`a*b*c`), `_` usually doesn't · `:100:` → 💯 · single newline in an issue/PR/discussion comment → visible break (not in `.md` files).

> Note: bare `#N` / `@name` autolink and backlink in **conversations** (issues, PRs, comments) — not
> inside repo files like this one. The examples above are safe *here*; the danger is when you paste
> them into a comment box.
