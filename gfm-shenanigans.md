# gfm-shenanigans — READ before writing GitHub markdown (comment / PR / review / commit msg)

> **The rule: backticks turn GitHub autolinking OFF** (issue refs, SHAs, emoji, emphasis). Never
> backtick a *live* ref (ticket `#N` or commit SHA) you want linked; for a number that's just a
> *label*, write prose — never `#N`.
>
> **Catastrophic:** a bare `#N` in a GitHub conversation autolinks to issue/PR N **and posts a
> cross-reference into that ticket's timeline. Treat it as irreversible** — editing/deleting your
> comment does NOT retract it (a deleted comment still leaves its backlinks; there is no API to remove
> a cross-reference event). Fires on even a one-line reply → prose, backticks or `#<span></span>N` **before the first post**.
> **A backslash does not help:** in a comment, `\#N` and `owner/repo\#N` still render as live links
> and still cross-reference (see the suppression row below).
> - `@name` is a *different* trap: it **pings** that user (no take-backs) — don't `@` a stranger.
>   `\@name` still renders as a mention link too.
> - `Fixes` / `Closes` / `Resolves #N` in a PR body **auto-closes issue N on merge** (when the PR
>   targets the repo's default branch) — don't use those verbs unless you mean it.

| Writing… | Do | Not | Why |
|---|---|---|---|
| a **label** ("finding 6", point/item N) | prose **"Finding 6"** | `#6` (spams a backlink) · `` `#6` `` (dead text, reads as a mislabeled ticket) | no link *or* backlink wanted |
| a **real ticket ref** to link | bare **`#123`** | `` `#123` `` (backticks kill the link) | you *want* the autolink |
| a **commit SHA** | bare **`a1b2c3d`** (resolvable 7+/40-char SHA → autolinks, hover) | `` `a1b2c3d` `` (dead text) | backticks kill the useful link |
| a ticket you must name but NOT link | **`#<span></span>6`** (renders "#6", no link; `@<span></span>name` likewise) | bare `#6` · `\#6` · `&#35;6` (all still link) · `#<!-- -->6` (plain in a paragraph, **links inside a table cell**) | a `.md` file autolinks nothing, so `\#6` only looks safe there; in issues, PRs and comments it is a live link and posts a cross-reference |
| anything appended **after an HTML block** (`</details>` fold, `</div>`) | **blank line**, then its own paragraph | `</details> [x](url)` *and* `</details>`⏎`[x](url)` → both emit the literal `[x](url)` | an HTML block runs until a **blank line**, so a newline alone leaves you still inside it |

**Silent (no error, no warning — the link just becomes text):** markdown that follows an HTML block without a **blank line** is not parsed. Note the near-miss: moving the link off the closing line onto the next line **still fails** — only a blank line closes the block. Code fences are *not* affected (verified), so this is an HTML-block rule, not a general "after a block" rule. A table has its own version: the line right after it, with no blank line, becomes one more table row. The link renders, but inside the table. It bites hardest when a comment's last element is a `<details>` fold *and* some convention tells you to append something "at the very end, after the final punctuation" — AI-authorship sigils, footers, badges, shields. The two collide, the appended link dies silently, and a convention that says "one space before" is actively steering you into it.

**Check the render, not the source** — round-trip a draft through GitHub's own renderer before posting:

```bash
gh api /markdown --input <(jq -n --arg t "$BODY" '{text:$t,mode:"gfm"}')
```

An already-posted body is fixable in place (`PATCH`/`PUT` the comment or review, and say so in a changelog line) — but the check is free and the edit is not.

**Cosmetic (visible, reversible — backtick the literal):** `<T>` / `Vector<int>` can be parsed as HTML and vanish · inside a table escape `|` as `\|` · at line start `1.` / `-` / `>` / 4-space → stray list/quote/code (ordered lists auto-renumber) · intraword `*` emphasizes (`a*b*c`), `_` usually doesn't · `:100:` → 💯 · single newline in an issue/PR/discussion comment → visible break (not in `.md` files).

> Note: bare `#N` / `@name` autolink and backlink in **conversations** (issues, PRs, comments) — not
> inside repo files like this one. The examples above are safe *here*; the danger is when you paste
> them into a comment box.
