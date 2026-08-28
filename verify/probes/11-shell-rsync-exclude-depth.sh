#!/usr/bin/env bash
# CLAIM  shell-shenanigans.md §4
#   --exclude=NAME/ drops every NAME/ at ANY depth; a leading slash anchors it
#   to the transfer root.
. "$(dirname "$0")/../lib.sh"
need rsync
probe_tmp; d=$PROBE_TMP

mkdir -p "$d/src/screenshots" "$d/src/docs/screenshots"
: > "$d/src/screenshots/adhoc.png"
: > "$d/src/docs/screenshots/readme.png"

run() {  # run <dest> <exclude-pattern>
  rm -rf "$d/$1"; mkdir -p "$d/$1"
  rsync -a --exclude="$2" "$d/src/" "$d/$1/" >/dev/null
  ( cd "$d/$1" && find . -name '*.png' | sort | tr '\n' ' ' )
}

expect "unanchored 'screenshots/' drops BOTH depths" '' \
       "$(run out_unanchored 'screenshots/' | tr -d ' ')"
expect "anchored '/screenshots/' keeps the nested one" './docs/screenshots/readme.png' \
       "$(run out_anchored '/screenshots/' | tr -d ' ')"
expect "no exclude copies both" './docs/screenshots/readme.png ./screenshots/adhoc.png' \
       "$(rm -rf "$d/out_all"; mkdir -p "$d/out_all"; rsync -a "$d/src/" "$d/out_all/" >/dev/null; cd "$d/out_all" && find . -name '*.png' | sort | tr '\n' ' ' | sed 's/ $//')"
verdict
