#!/usr/bin/env bash
# CLAIM  python-shenanigans.md §1
#   A package-manager-managed Python refuses `pip install` outside a venv with
#   "externally-managed-environment"; a venv is the cure.
# Nothing is installed anywhere: the trap arm uses --dry-run, the cure arm
# installs a wheel that ships with the venv itself.
. "$(dirname "$0")/../lib.sh"
need python3
probe_tmp; d=$PROBE_TMP

marker=$(python3 -c 'import sysconfig,os;p=os.path.join(sysconfig.get_path("stdlib"),"EXTERNALLY-MANAGED");print("yes" if os.path.exists(p) else "no")')
if [ "$marker" != yes ]; then
  echo "    skip: this python3 ships no EXTERNALLY-MANAGED marker (not PEP 668 managed)"
  exit $SKIPPED
fi
expect "the interpreter is PEP 668 managed" 'yes' "$marker"

out=$(python3 -m pip install --dry-run --no-input requests 2>&1 || true)
case "$out" in *externally-managed-environment*) got=blocked ;; *) got="other" ;; esac
expect "pip install outside a venv is blocked" 'blocked' "$got"
case "$out" in *--break-system-packages*) got=suggested ;; *) got=absent ;; esac
expect "pip itself dangles --break-system-packages" 'suggested' "$got"

python3 -m venv "$d/venv" >/dev/null 2>&1 || { echo "    skip: venv creation failed"; exit $SKIPPED; }
# Offline on purpose: --no-index means the resolver must fail. What matters is
# WHICH failure -- PEP 668 refuses before resolving, a venv gets as far as
# "no matching distribution".
vout=$("$d/venv/bin/python" -m pip install --dry-run --no-input --no-index requests 2>&1 || true)
case "$vout" in *externally-managed-environment*) got=still-blocked ;; *) got=past-the-wall ;; esac
expect "inside a venv the PEP 668 wall is gone" 'past-the-wall' "$got"
case "$vout" in *"No matching distribution"*|*"Could not find a version"*) got=resolver ;; *) got="other" ;; esac
expect "...it fails at the RESOLVER instead" 'resolver' "$got"
verdict
