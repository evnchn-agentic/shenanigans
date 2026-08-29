#!/usr/bin/env bash
# CLAIM  python-shenanigans.md §2
#   The default multiprocessing start method is PER-PLATFORM -- macOS spawn,
#   Linux fork until CPython 3.14 then forkserver -- and any method that
#   re-imports the parent module bootstrap-recurses without a __main__ guard.
#
# SAFETY: the no-guard arm IS a fork bomb (each child re-imports the module and
# starts its own Pool, forever). GNU `timeout` puts it in its own process group and
# signals the group, so the whole tree dies. That is a claim, so the probe ASSERTS
# it below rather than asserting it in a comment -- and refuses to run at all
# without GNU coreutils `timeout`, whose group-kill is the thing being relied on.
. "$(dirname "$0")/../lib.sh"
need python3; need timeout
timeout --version 2>/dev/null | grep -qi coreutils || {
  echo "    skip: need GNU coreutils timeout (process-group kill) to bound the fork bomb"
  exit $SKIPPED
}
probe_tmp; d=$PROBE_TMP

os=$(uname -s)
ver=$(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])')
new=$(python3 -c 'import sys;print("yes" if sys.version_info[:2]>=(3,14) else "no")')
method=$(python3 -c 'import multiprocessing as m;print(m.get_start_method())')

# The table in the .md, as an assertion. The point of §2 is that you cannot read
# the default off the Python version alone -- so neither does this probe.
case "$os:$new" in
  Darwin:*)  want=spawn      ;;   # macOS: spawn since 3.8, the 3.14 flip is not its story
  Linux:yes) want=forkserver ;;   # the CPython 3.14 change
  Linux:no)  want=fork       ;;
  *)         echo "    skip: no documented expectation for $os"; exit $SKIPPED ;;
esac
expect "$os / python $ver defaults to the documented method" "$want" "$method"

# Corroborate across every other CPython on PATH: the default tracks platform and
# version, not one lucky interpreter.
for v in 3.11 3.12 3.13 3.14; do
  b=$(command -v "python$v" || true); [ -z "$b" ] && continue
  w=$(case "$os:$v" in Darwin:*) echo spawn;; Linux:3.14) echo forkserver;; Linux:*) echo fork;; esac)
  expect "  python$v on $os -> $w" "$w" "$("$b" -c 'import multiprocessing as m;print(m.get_start_method())')"
done

cat > "$d/bad.py" <<'PY'
from multiprocessing import Pool
with Pool(2) as p:
    print(p.map(abs, [-1, -2]))
PY
( cd "$d" && timeout -k 2 6 python3 bad.py ) > "$d/bad.out" 2>&1 || true
# Grep a SHORT fragment: Python wraps the RuntimeError text across lines, so the
# full sentence matches nothing and the sweep silently reports zero.
hits=$(grep -ac "bootstrapping phase" "$d/bad.out" || true)

if [ "$method" = fork ]; then
  # fork does NOT re-import the parent, so the unguarded module is fine. This is
  # the arm that shows the guard is needed BECAUSE of the start method.
  expect "fork does not re-import -> no guard needed" '[1, 2]' "$(tail -1 "$d/bad.out")"
  expect "...and no bootstrap error at all"           '0'      "$hits"
else
  expect "$method re-imports -> the documented RuntimeError" 'yes' "$([ "$hits" -ge 1 ] && echo yes || echo no)"
  # The blast radius differs by method, and only one of them is a runaway:
  # spawn re-execs a fresh interpreter per child, each of which re-imports and
  # spawns more; forkserver imports once in a single server process that then
  # dies. Measured 266 vs a stable 1 in 6 seconds.
  if [ "$method" = spawn ]; then
    expect "spawn RUNS AWAY (many errors, not one)"  'yes' "$([ "$hits" -ge 5 ] && echo yes || echo no)"
  else
    expect "forkserver is BOUNDED (a handful, not a storm)" 'yes' "$([ "$hits" -lt 5 ] && echo yes || echo no)"
  fi
  note "$method: the 6s run emitted the RuntimeError $hits times"
fi

# Enforce the safety claim in the header: nothing from that tree may survive.
# $d is a fresh mktemp path, so this pattern cannot match anything else on the box.
sleep 1
strays=$(pgrep -f "$d" 2>/dev/null | wc -l | tr -d " ")
[ "$strays" -ne 0 ] && for s_pid in $(pgrep -f "$d"); do kill -9 "$s_pid" 2>/dev/null; done
expect "timeout killed the whole process group (no strays)" '0' "$strays"

cat > "$d/good.py" <<'PY'
from multiprocessing import Pool
if __name__ == '__main__':
    with Pool(2) as p:
        print(p.map(abs, [-1, -2]))
PY
expect "the __main__ guard works everywhere" '[1, 2]' "$(cd "$d" && timeout 30 python3 good.py 2>&1 | tail -1)"
verdict
