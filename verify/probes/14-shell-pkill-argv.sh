#!/usr/bin/env bash
# CLAIM  shell-shenanigans.md §6
#   pkill -f matches a process's ACTUAL argv, so a pattern built from the path you
#   `cd`'d into matches nothing -- and `pkill ... ; echo stopped` says "stopped" anyway.
#
# SAFETY: every pattern is anchored to a per-run token that cannot appear elsewhere,
# and the probe reaps its own tree by PID (never by a broad pattern -- that is the
# "opposite failure" the section itself warns about).
. "$(dirname "$0")/../lib.sh"
need pkill; need pgrep; need ps
set +m                                   # no "Terminated: 15" job-control chatter
probe_tmp; d=$PROBE_TMP

# A sandbox that denies process inspection would make EVERY assertion below pass for
# the wrong reason: ps fails -> "relative", pkill fails -> the child survives ->
# "pkill matched nothing". Prove we can see processes at all before trusting any of it.
# (Found by a reviewer whose sandbox returned "ps: Operation not permitted".)
ps -o args= -p $$ >/dev/null 2>&1 || { echo "    skip: ps cannot inspect processes here"; exit $SKIPPED; }

tok="shenprobe$$"
mkdir -p "$d/svc"
# No `exec`: exec would replace argv with `sleep`, erasing the script name entirely --
# a stronger version of the same trap, but not the one this section describes.
# The fake service disarms ITSELF on TERM (shell-shenanigans §0, applied here):
# once the parent is killed its sleep is reparented to init and no longer findable
# via pgrep -P, so cleanup cannot be the caller's job.
printf '#!/bin/sh\ntrap %s TERM INT\nsleep 45 & c=$!\nwait $c\n' \
       "'kill \$c 2>/dev/null; exit 0'" > "$d/svc/$tok.sh"
chmod +x "$d/svc/$tok.sh"

# Detach ALL three fds. A background job that inherits the probe's stdout holds that
# pipe open for its whole lifetime, so whoever is reading the probe's output blocks
# until the fake service exits -- a hang that looks exactly like a broken probe.
start() { ( cd "$d/svc" && exec ./"$tok.sh" ) >/dev/null 2>&1 </dev/null & echo $!; }
alive() { kill -0 "$1" 2>/dev/null && echo up || echo down; }
reap()  { local p=$1 c; for c in $(pgrep -P "$p" 2>/dev/null); do kill "$c" 2>/dev/null; done
          kill "$p" 2>/dev/null; }
trap 'reap "${pid:-0}" 2>/dev/null; rm -rf "$PROBE_TMP"' EXIT

pid=$(start); sleep 0.4
expect "the process is running"                 'up'       "$(alive "$pid")"
expect "its argv holds NO absolute path"        'relative' \
       "$(ps -o args= -p "$pid" | grep -q "$d/svc" && echo absolute || echo relative)"
# Positive control: without it, "matched nothing" is indistinguishable from "pkill is broken".
expect "pgrep -f CAN see it by its real argv"   'visible'  \
       "$(pgrep -f "$tok.sh" >/dev/null 2>&1 && echo visible || echo invisible)"

# The trap: kill it by the path a human thinks of it by.
out=$(pkill -f "$d/svc/$tok.sh" ; echo stopped); sleep 0.3
expect "pkill -f <full path> matched nothing"   'up'       "$(alive "$pid")"
expect "...yet the composed command printed"    'stopped'  "$out"

# ...and pkill by the REAL argv does kill it, so the miss above was the pattern.
pkill -f "./$tok.sh" 2>/dev/null || true; sleep 0.3
expect "pkill -f <real argv> DOES kill it"      'down'     "$(alive "$pid")"
reap "$pid"

# The documented cure: kill the PID captured at launch, then verify the EFFECT.
pid=$(start); sleep 0.4
expect "a second instance is up"                'up'       "$(alive "$pid")"
reap "$pid"; sleep 0.3
expect "kill by captured PID actually works"    'down'     "$(alive "$pid")"

# Leak check: this probe must leave nothing behind.
expect "no process of ours survives the probe"  '0'        "$(pgrep -f "$tok" 2>/dev/null | wc -l | tr -d ' ')"
verdict
