#!/usr/bin/env bash
# CLAIM  shell-shenanigans.md §1 & §3
#   zsh does NOT word-split an unquoted $VAR (the whole string becomes ONE token),
#   while bash DOES split it. The scope box says the advice is wrong-for-bash.
. "$(dirname "$0")/../lib.sh"
need zsh; need bash

# `printf '<%s>\n'` prints one line per argv element -> argv count is the oracle.
prog='V="a b c"; printf "<%s>" $V'

zsh_out=$(zsh -c "$prog")
bash_out=$(bash -c "$prog")

expect "zsh: unquoted \$V arrives as ONE token"    '<a b c>'      "$zsh_out"
expect "bash: unquoted \$V arrives as THREE tokens" '<a><b><c>'   "$bash_out"

# The documented cures, both shells.
expect "zsh cure \${=V} force-splits"  '<a><b><c>'  "$(zsh -c 'V="a b c"; printf "<%s>" ${=V}')"
expect "zsh cure array"                '<a><b><c>'  "$(zsh -c 'v=(a b c); printf "<%s>" "${v[@]}"')"
expect "bash cure quoting keeps one"   '<a b c>'    "$(bash -c 'V="a b c"; printf "<%s>" "$V"')"

# The stated symptom. The message shape depends on whether the single token
# contains a "/": zsh then reports a PATH failure, not an unknown command.
slash=$(zsh -c 'CMD="notarealcmd -a src/ host:/dst/"; $CMD' 2>&1 || true)
plain=$(zsh -c 'CMD="notarealcmd -av --delete"; $CMD' 2>&1 || true)

case "$slash" in *"no such file or directory: notarealcmd -a src/ host:/dst/"*) a=path-error ;; *) a="other: $slash" ;; esac
case "$plain" in *"command not found: notarealcmd -av --delete"*)                b=cmd-not-found ;; *) b="other: $plain" ;; esac

expect "token WITH a slash  -> path error, whole string"  'path-error'    "$a"
expect "token WITHOUT slash -> command not found, whole string" 'cmd-not-found' "$b"
verdict
