#!/usr/bin/env bash
# CLAIM  shell-shenanigans.md §7
#   `rg -rn PAT` parses as --replace=n: matches are rewritten to "n", line numbers
#   vanish, and nothing errors.
. "$(dirname "$0")/../lib.sh"
need rg

expect "rg -rn rewrites the match to 'n'"     'n beta'       "$(printf 'alpha beta\n' | rg -rn 'alpha')"
expect "rg -rn exits 0 (no error at all)"     '0'            "$(printf 'alpha beta\n' | rg -rn 'alpha' >/dev/null; echo $?)"
expect "rg -n is what you meant"              '1:alpha beta' "$(printf 'alpha beta\n' | rg -n 'alpha')"
expect "rg recurses without -r"               '2'            "$(d=$(mktemp -d); mkdir -p "$d/a/b"; printf 'hit\n' > "$d/a/x.txt"; printf 'hit\n' > "$d/a/b/y.txt"; rg -c hit "$d" | wc -l | tr -d ' '; rm -rf "$d")"
# The tell named in the file: the N: prefix disappears.
expect "the tell: no 'N:' prefix survives -rn" 'no-prefix' \
       "$(printf 'alpha beta\n' | rg -rn 'alpha' | grep -qE '^[0-9]+:' && echo has-prefix || echo no-prefix)"
verdict
