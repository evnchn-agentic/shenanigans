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
