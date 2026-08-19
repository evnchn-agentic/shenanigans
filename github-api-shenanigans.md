# github-api-shenanigans — READ before any scripted GitHub mutation (`gh api`, GraphQL, Octokit)

> **The rule: address objects by identity you just fetched, never by position or by memory.** A
> GraphQL node id (`DC_kwDOFcVGh84BE-1D`) is opaque — no human and no model can eyeball it for
> correctness. Resolve it in the same command as the mutation, select it by a stable key (URL,
> number), and echo what matched before you mutate.
>
> **Catastrophic:** a node id that is **valid but stale** — carried across turns, or copied from an
> earlier query of a *different* object — resolves normally and mutates the wrong object. A
> `deleteDiscussionComment` / `deleteIssue` / `deleteRef` then destroys someone else's content
> **irreversibly and returns success.** A wrong id that 404s is the *lucky* failure; the dangerous
> one is the id that works.

| Doing… | Do | Not | Why |
|---|---|---|---|
| replying to a comment | fetch `{id, url}` for all candidates, `select(.url\|endswith("<id-from-the-notification>"))` | `comments(first:5).nodes[0].id` | array order is API-defined, shifts as comments arrive, and `first:N` truncates **silently** |
| any destructive mutation | fetch the id and mutate in **one** command; print the matched object's author/URL first | pasting an id you saw earlier in the session | opaque ids are unverifiable by eye — the echo is your only check |
| finding "the comment someone replied to" | read the **parent** from the API and print it | inferring the thread from timestamps or reply order | a reply's parent is data, not something you can deduce from ordering |
| listing threads to choose from | print each reply **with its parent** | printing author + timestamp + body only | a listing that omits the parent cannot be used to choose a parent |

**Silent (no error — the call succeeds, in the wrong place):** GitHub discussion replies are a
*separate* paginated connection under each top-level comment. Iterating `comments.nodes[*].replies`
and printing only author/timestamp/body produces output where every reply looks equivalent, so the
one you are answering is indistinguishable from the rest. Post with the wrong `replyToId` and the
answer lands under a stranger's thread while the question stays unanswered under yours — no error,
no warning, and it reads as a non-sequitur where it landed. *(Empirically reproduced.)*

**Pagination truncates without telling you.** `first:N` is a hard cap, not a page-one hint. Measured
on a live thread: `comments(first:1)` returned one node next to `totalCount: 2`, and the nested
`replies(first:1)` did the same — no error, no warning, no `pageInfo` unless you ask. "The newest
comment" computed from a truncated set is simply wrong. Request `totalCount` beside `nodes` and
compare the two.

**Deleting your own comment does NOT undo its side effects.** Cross-reference events and `@`-pings
already fired stay fired — see [`gfm-shenanigans.md`](gfm-shenanigans.md). Delete is a cleanup for
*placement*, never a retraction.

**The shape that works** — resolve, echo, then mutate:

```bash
PID=$(gh api graphql -f query='{repository(owner:"O",name:"R"){discussion(number:N){
  comments(first:50){totalCount nodes{id url author{login}}}}}}' \
  --jq '.data.repository.discussion.comments.nodes[] | select(.url|endswith("18082361")) | .id')
echo "parent=$PID"   # ← read this before running the mutation
```

**Status of the claims here:** the wrong-`replyToId` trap and the silent `first:N` cap are
empirically reproduced. The stale-but-valid-id deletion is **reasoned, not reproduced** — the
observed case used an id recalled from memory, which 404'd. It is listed because the failure is
irreversible and the safe outcome was luck, not design.
