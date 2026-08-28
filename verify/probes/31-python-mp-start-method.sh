#!/usr/bin/env bash
# CLAIM  python-shenanigans.md §2
#   "CPython 3.14 changed the POSIX default fork -> forkserver", so top-level
#   multiprocessing without a __main__ guard now bootstrap-recurses.
#
# SAFETY: the no-guard arm IS a fork bomb (each child re-imports the module and
# starts its own Pool, forever). GNU `timeout` puts it in its own process group
# and signals the group, so the whole tree dies -- verified: 0 strays after.
. "$(dirname "$0")/../lib.sh"
need python3; need timeout
probe_tmp; d=$PROBE_TMP

expect "running on 3.14+" 'yes' \
  "$(python3 -c 'import sys;print("yes" if sys.version_info[:2]>=(3,14) else "no")')"

# DRIFT (2026-08-29, CPython 3.14.6 on macOS 26): the default here is `spawn`,
# not `forkserver`. The forkserver flip is a *Linux* change; macOS is POSIX too
# and has defaulted to spawn since 3.8. The consequence below is the same either
# way -- both spawn and forkserver re-import the parent module -- but the stated
# mechanism does not hold on a Mac.
expect "default start method on this POSIX box" 'spawn' \
  "$(python3 -c 'import multiprocessing as m;print(m.get_start_method())')"
expect "...and it is NOT forkserver" 'no' \
  "$(python3 -c 'import multiprocessing as m;print("yes" if m.get_start_method()=="forkserver" else "no")')"

# Corroborate that this is not new on a Mac: check every other CPython on PATH.
for v in 3.11 3.12 3.13; do
  b=$(command -v "python$v" || true)
  [ -n "$b" ] && expect "python$v on this Mac also defaults to spawn" 'spawn' \
    "$("$b" -c 'import multiprocessing as m;print(m.get_start_method())')"
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
expect "no __main__ guard -> the documented RuntimeError" 'yes' "$([ "$hits" -ge 1 ] && echo yes || echo no)"
expect "...and it recurses, rather than erroring once" 'yes' "$([ "$hits" -ge 5 ] && echo yes || echo no)"
note "the 6s run emitted the RuntimeError $hits times"

cat > "$d/good.py" <<'PY'
from multiprocessing import Pool
if __name__ == '__main__':
    with Pool(2) as p:
        print(p.map(abs, [-1, -2]))
PY
expect "the __main__ guard fixes it" '[1, 2]' "$(cd "$d" && timeout 30 python3 good.py 2>&1 | tail -1)"

# Under an explicit `fork` the same unguarded source is fine -> the guard is only
# needed because the default re-imports.
cat > "$d/forked.py" <<'PY'
import multiprocessing as m
m.set_start_method('fork', force=True)
with m.Pool(2) as p:
    print(p.map(abs, [-1, -2]))
PY
expect "explicit fork start method is unaffected" '[1, 2]' \
  "$(cd "$d" && timeout 30 python3 -W ignore forked.py 2>/dev/null | tail -1)"
verdict
