#!/usr/bin/env bash
# CLAIM  macos-shenanigans.md §2
#   With core.ignorecase=true, a case-only rename is invisible: status is clean,
#   add -A stages nothing, and `checkout --` is a no-op. `reset --hard` restores the
#   stored casing only when the path is otherwise DIRTY (content or mode); on a pure
#   case-only rename it does nothing, so it is not the reliable undo the file claimed.
. "$(dirname "$0")/../lib.sh"
need git
probe_tmp; d=$PROBE_TMP
need_case_insensitive_fs "$d"

r="$d/repo"; mkdir -p "$r"
git -C "$r" init -q
git -C "$r" config user.email p@example.com; git -C "$r" config user.name probe
: > "$r/Logo.webp"; git -C "$r" add -A; git -C "$r" commit -qm init

expect "core.ignorecase is the macOS default" 'true' "$(git -C "$r" config core.ignorecase)"

mv "$r/Logo.webp" "$r/logo.webp"
expect "status --porcelain reports CLEAN"     ''            "$(git -C "$r" status --porcelain)"
expect "ls-files still shows the OLD name"    'Logo.webp'   "$(git -C "$r" ls-files)"
expect "the disk really has the NEW name"     'logo.webp'   "$(cd "$r" && ls *.webp)"
git -C "$r" add -A
expect "add -A stages nothing"                ''            "$(git -C "$r" diff --cached --name-only)"
git -C "$r" checkout -- . 2>/dev/null
expect "checkout -- . is a no-op on disk"     'logo.webp'   "$(cd "$r" && ls *.webp)"
# DRIFT (2026-08-29, git 2.51.0): the shipped text calls `reset --hard` "the
# reliable undo". It is not -- a case-ONLY rename leaves the index clean, so
# reset has nothing to write and the wrong spelling survives.
git -C "$r" reset --hard -q
expect "reset --hard does NOT restore a case-only rename" 'logo.webp' "$(cd "$r" && ls *.webp)"

# ...but any dirtiness makes reset rewrite the path, and the write lands back on the
# STORED spelling. Content and mode both count -- the mode arm was contributed by a
# reviewer who refuted the first, content-only wording of this rule.
printf 'changed\n' > "$r/logo.webp"
expect "content churn makes the path visibly dirty" ' M Logo.webp' "$(git -C "$r" status --porcelain)"
git -C "$r" reset --hard -q
expect "reset --hard DOES restore it when content differs" 'Logo.webp' "$(cd "$r" && ls *.webp)"

mv "$r/Logo.webp" "$r/logo.webp"; chmod +x "$r/logo.webp"
expect "a MODE-only change is dirty too"           ' M Logo.webp' "$(git -C "$r" status --porcelain)"
git -C "$r" reset --hard -q
expect "reset --hard restores it on mode dirt too" 'Logo.webp'    "$(cd "$r" && ls *.webp)"

# The cure that works unconditionally: remove the wrongly-cased file first.
mv "$r/Logo.webp" "$r/logo.webp"
rm -f "$r/logo.webp"; git -C "$r" checkout -- .
expect "rm + checkout -- . always restores the name" 'Logo.webp' "$(cd "$r" && ls *.webp)"

# Cure: git mv handles it even without -f.
git -C "$r" mv Logo.webp logo.webp
expect "git mv stages a real rename"          'R'           "$(git -C "$r" diff --cached --name-status | cut -c1)"

# Cure: core.ignorecase=false makes git see it.
git -C "$r" reset --hard -q
git -C "$r" config core.ignorecase false
mv "$r/Logo.webp" "$r/logo.webp"
expect "ignorecase=false surfaces the rename" 'dirty'       "$([ -n "$(git -C "$r" status --porcelain)" ] && echo dirty || echo clean)"
verdict
