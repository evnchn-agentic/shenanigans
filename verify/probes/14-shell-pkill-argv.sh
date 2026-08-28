#!/usr/bin/env bash
# CLAIM  shell-shenanigans.md §6
#   pkill -f matches a process's ACTUAL argv, so a pattern built from the path you
#   `cd`'d into matches nothing -- and `pkill ... ; echo stopped` says "stopped" anyway.
# SAFETY: every pattern here is anchored to a unique per-run token; nothing broad.
. "$(dirname "$0")/../lib.sh"
need pkill; need pgrep
probe_tmp; d=$PROBE_TMP

tok="shenprobe$$"
mkdir -p "$d/svc"
printf '#!/bin/sh\nexec sleep 120\n' > "$d/svc/$tok.sh"
chmod +x "$d/svc/$tok.sh"

# The launch shape from the file: cd into the dir, then run by BARE name.
( cd "$d/svc" && nohup ./"$tok.sh" >/dev/null 2>&1 & echo $! > "$d/pid" )
sleep 0.4
pid=$(cat "$d/pid")

expect "the process is running"          'up' "$(kill -0 "$pid" 2>/dev/null && echo up || echo down)"
expect "its argv holds NO absolute path" 'relative' \
       "$(ps -o args= -p "$pid" | grep -q "$d/svc" && echo absolute || echo relative)"

# The trap: kill it by the path a human thinks of it by.
out=$(pkill -f "$d/svc/$tok.sh" ; echo stopped)
sleep 0.3
expect "pkill -f <full path> matched nothing"      'up'      "$(kill -0 "$pid" 2>/dev/null && echo up || echo down)"
expect "...yet the composed command printed"       'stopped' "$out"

# The documented cure: kill the PID captured at launch, then verify the EFFECT.
kill "$pid" 2>/dev/null
sleep 0.3
expect "kill by captured PID actually works" 'down' "$(kill -0 "$pid" 2>/dev/null && echo up || echo down)"
pkill -f "$tok" 2>/dev/null || true
verdict
