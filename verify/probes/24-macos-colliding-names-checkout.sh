#!/usr/bin/env bash
# CLAIM  macos-shenanigans.md §3
#   A repo legitimately containing F.txt AND f.txt cannot be checked out on a
#   case-insensitive Mac: one survives, the twin is permanently `modified`, and
#   checkout / stash / reset --hard will not clear it.
. "$(dirname "$0")/../lib.sh"
need_macos
need git
probe_tmp; d=$PROBE_TMP
need_case_insensitive_fs "$d"

# Build the colliding commit with plumbing, so we never need a case-sensitive volume.
src="$d/src"; mkdir -p "$src"; git -C "$src" init -q -b main
git -C "$src" config user.email p@example.com; git -C "$src" config user.name probe
uc=$(printf 'UPPER\n' | git -C "$src" hash-object -w --stdin)
lc=$(printf 'lower\n' | git -C "$src" hash-object -w --stdin)
git -C "$src" update-index --add --cacheinfo 100644,"$uc",F.txt
git -C "$src" update-index --add --cacheinfo 100644,"$lc",f.txt
tree=$(git -C "$src" write-tree)
commit=$(git -C "$src" commit-tree "$tree" -m collide)
git -C "$src" update-ref refs/heads/main "$commit"
expect "the commit really holds both spellings" 'F.txt f.txt' \
       "$(git -C "$src" ls-tree --name-only "$tree" | sort | tr '\n' ' ' | sed 's/ $//')"

git clone -q "$src" "$d/work" 2>/dev/null
w="$d/work"
expect "only ONE file lands on disk"       '1'      "$(ls -A "$w" | grep -c '\.txt$')"
expect "the twin is left modified"         'dirty'  "$([ -n "$(git -C "$w" status --porcelain)" ] && echo dirty || echo clean)"
for cmd in "checkout -- ." "reset --hard" "stash"; do
  git -C "$w" $cmd -q >/dev/null 2>&1 || true
  expect "still dirty after: git $cmd"     'dirty'  "$([ -n "$(git -C "$w" status --porcelain)" ] && echo dirty || echo clean)"
done
verdict
