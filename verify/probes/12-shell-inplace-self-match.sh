#!/usr/bin/env bash
# CLAIM  shell-shenanigans.md §5
#   A global in-place replace rewrites the helper's own DEFINITION too, producing
#   silent infinite recursion; the file still parses.
. "$(dirname "$0")/../lib.sh"
need perl; need python3
probe_tmp; d=$PROBE_TMP

cat > "$d/m.py" <<'PY'
def slug(s):
    return s.lower().replace(' ', '-')
a = slug('One Two')
b = slug('Three Four')
PY

perl -i -pe "s/s\.lower\(\)\.replace\(' ', '-'\)/slug(s)/g" "$d/m.py"

grep -q 'return slug(s)' "$d/m.py" && got=self-matched || got=survived
expect "perl -i rewrote the definition into 'return slug(s)'" 'self-matched' "$got"
expect "the file still compiles (failure is silent)" '0' \
       "$(python3 -m py_compile "$d/m.py" >/dev/null 2>&1; echo $?)"
expect "it only explodes at runtime" 'RecursionError' \
       "$(python3 "$d/m.py" 2>&1 | tail -1 | cut -d: -f1)"

# Cure: an exact old->new editor keyed on the call site only.
cat > "$d/n.py" <<'PY'
def slug(s):
    return s.lower().replace(' ', '-')
a = s.lower().replace(' ', '-')
PY
python3 - "$d/n.py" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text()
call = "a = s.lower().replace(' ', '-')"
p.write_text(t.replace(call, "a = slug(s)"))
PY
grep -q 'return s.lower()' "$d/n.py" && got=definition-intact || got=clobbered
expect "exact old->new edit leaves the definition intact" 'definition-intact' "$got"
verdict
