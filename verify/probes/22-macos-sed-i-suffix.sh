#!/usr/bin/env bash
# CLAIM  macos-shenanigans.md §5
#   BSD sed -i takes a MANDATORY suffix; `sed -i -e` works but litters file-e;
#   `sed -i ''` is the correct form.
. "$(dirname "$0")/../lib.sh"
need_macos
probe_tmp; d=$PROBE_TMP

printf 'a\n' > "$d/s.txt"
gnu_rc=$(cd "$d" && sed -i 's/a/b/' s.txt >/dev/null 2>&1; echo $?)
expect "GNU-style 'sed -i EXPR f' fails on BSD sed" 'fail' "$([ "$gnu_rc" -ne 0 ] && echo fail || echo ok)"

printf 'a\n' > "$d/s.txt"; rm -f "$d"/s.txt-*
( cd "$d" && sed -i -e 's/a/b/' s.txt )
expect "sed -i -e edits the file"          'b'      "$(cat "$d/s.txt")"
expect "...and leaves an unasked-for s.txt-e" 'yes'  "$([ -f "$d/s.txt-e" ] && echo yes || echo no)"

printf 'a\n' > "$d/t.txt"
( cd "$d" && sed -i '' 's/a/b/' t.txt )
expect "sed -i '' edits cleanly"           'b'      "$(cat "$d/t.txt")"
expect "...leaving no backup"              'no'     "$(ls "$d"/t.txt-* >/dev/null 2>&1 && echo yes || echo no)"
verdict
