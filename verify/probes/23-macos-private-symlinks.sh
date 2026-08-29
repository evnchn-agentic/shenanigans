#!/usr/bin/env bash
# CLAIM  macos-shenanigans.md §6
#   /tmp, /var and /etc are symlinks into /private, so a resolved-vs-literal
#   prefix check fails on macOS only.
. "$(dirname "$0")/../lib.sh"
need_macos
need python3
for p in tmp var etc; do
  expect "/$p resolves into /private" "/private/$p" "$(python3 -c "import os,sys; print(os.path.realpath('/$p'))")"
done
expect "resolved-vs-literal prefix check FAILS" 'False' \
       "$(python3 -c "import os; print(os.path.realpath('/tmp/x').startswith('/tmp/'))")"
expect "resolved-vs-resolved check works"       'True' \
       "$(python3 -c "import os; print(os.path.realpath('/tmp/x').startswith(os.path.realpath('/tmp') + '/'))")"
verdict
