# git-shenanigans — READ before any irreversible git op (branch -D, mass-delete, history rewrite)

> **Skip this and you silently close live PRs or lose recoverable work.** Empirically burned. The
> golden rule: **`git bundle` (or note the SHAs) BEFORE any mass branch deletion / force-push /
> history rewrite — it's the only recovery path.**

## §1 — deleting a branch closes EVERY open PR that references it (head OR base, fork AND upstream)

A branch can be referenced by an open PR in **multiple ways across two repos**, and deleting it
closes/breaks all of them, **silently**, the moment the `push --delete` lands:
- **fork PR head** (`head_ref_deleted`) · **fork PR base** of a stacked PR (`base_ref_deleted`)
- **UPSTREAM PR head** — a fork branch *is* the head of an upstream PR created from `your-fork:branch`.

A fork-only / head-only safety check misses the upstream-head case. **The branch whose work was
"moved upstream" is exactly the one with a live upstream PR head — highest-value, yet reads as
deletable in a fork-only view.**

Pre-delete exclusion set MUST union both repos, heads+bases:
```bash
gh pr list --repo YOUR-FORK/repo --state open --limit 300 --json headRefName,baseRefName \
  --jq '.[].headRefName, .[].baseRefName' > /tmp/pr_refs.txt
gh pr list --repo UPSTREAM/repo --author YOUR-USER --state open --limit 300 --json headRefName \
  --jq '.[].headRefName' >> /tmp/pr_refs.txt
sort -u -o /tmp/pr_refs.txt /tmp/pr_refs.txt
comm -12 <(sort -u kill-list.txt) /tmp/pr_refs.txt    # MUST be empty before deleting
```

## §2 — recovery if it already happened

`git bundle` backup → restore the branch to its **original SHA** (verify SHA == backup, not a stale
re-push) → `gh pr reopen N`. Both head and base must exist on the remote for reopen to stick. Tell
for "which closures were mine": `closedAt == deletion-second`.

## §3 — always bundle before mass-delete / force-push / rebase

```bash
git bundle create ~/backup-$(git rev-parse --short HEAD).bundle --all   # before the dangerous op
```
Force-push to a branch with an open PR **can dismiss existing approvals** (if the repo enables "dismiss
stale reviews"). Default to add-commit-on-top, not force-push, on PRs under review.

## §4 — a fork PR can cross-reference upstream, and escaping its prose does not prevent it

**Escaping the PR body is not enough.** A fork branch built on top of an upstream branch carries
that branch's commits. In one observed case, a fork PR whose commit messages named an upstream issue
left a cross-reference on that upstream issue's timeline. Nobody commented upstream. The PR body also
named that issue as `` `owner/repo`\#N ``, and that escaped form still renders as a live link (see
gfm), so this case does not show which of the two caused it. A later comment on the same PR named a
second upstream issue only in the escaped form, and that issue got a cross-reference one second after
the comment was posted. So the escaped prose is enough on its own; whether commit messages alone are
is not isolated. Treat both as risks. Closing the PR did not remove the timeline entries.

So a fence written as "don't post outward" has to cover outward **effects**, not only outward
**actions**. Before the first push of any branch whose commits are not all yours:

```bash
BASE=upstream/main   # or the upstream branch this branch sits on
git log --format=%s%n%b "$BASE"..HEAD | grep -nE '#[0-9]+|[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+|github\.com/[^ ]+/(issues|pull)/[0-9]+'
```

- Any hit: a commit message names another repo's issue or PR. Reword it before the first push if the
  reference is unwanted (`git rebase -i` in a real terminal, or `git filter-branch -f --msg-filter` on the
  local branch only). Once pushed, a reference may not be retractable.
- A bare `#[0-9]+` check misses issue/PR URLs. Use the full pattern above.
- The check covers commit messages only. Prose in the PR body is a separate surface (see gfm).
