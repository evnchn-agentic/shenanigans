# Shared helpers for shenanigans claim probes.
# A probe exits 0 = HOLDS, 1 = DRIFTED, 77 = SKIPPED.

set -uo pipefail

HOLDS=0; DRIFTED=1; SKIPPED=77
_fails=0

# Scratch dir on the *default boot volume* (see macos §3): probes that depend on
# case-insensitivity must not run inside a case-sensitive volume by accident.
# Sets $PROBE_TMP. NOT usable as `d=$(probe_tmp)` -- command substitution runs it
# in a subshell, whose EXIT trap fires immediately and deletes the dir you just got.
PROBE_TMP=""
probe_tmp() {
  PROBE_TMP=$(mktemp -d "${TMPDIR:-/tmp}/shen-probe.XXXXXX") || exit 1
  trap 'rm -rf "$PROBE_TMP"' EXIT
}

note() { printf '    %s\n' "$*"; }

# expect <label> <expected> <actual>
expect() {
  local label=$1 want=$2 got=$3
  if [ "$want" = "$got" ]; then
    printf '    ok   %-52s -> %s\n' "$label" "$got"
  else
    printf '    BAD  %-52s -> %s (expected: %s)\n' "$label" "$got" "$want"
    _fails=$((_fails + 1))
  fi
}

verdict() { [ "$_fails" -eq 0 ] && exit $HOLDS || exit $DRIFTED; }

need() {
  command -v "$1" >/dev/null 2>&1 || { printf '    skip: %s not installed\n' "$1"; exit $SKIPPED; }
}

# A claim scoped to one OS must SKIP elsewhere, never fail. Without this a Linux
# runner reports DRIFTED for macos §5 and §6 -- a red run that means nothing, which
# is worse for a verifier than no run at all.
need_macos() {
  [ "$(uname -s)" = Darwin ] && return 0
  printf '    skip: this claim is scoped to macOS (running on %s)\n' "$(uname -s)"
  exit $SKIPPED
}

# Refuse to run case-sensitivity probes on a case-sensitive volume.
need_case_insensitive_fs() {
  local d=$1
  : > "$d/_CaseProbe"
  if [ -e "$d/_caseprobe" ]; then rm -f "$d/_CaseProbe"; return 0; fi
  rm -f "$d/_CaseProbe"
  printf '    skip: %s is a case-SENSITIVE volume; this claim is scoped to the stock Mac default\n' "$d"
  exit $SKIPPED
}
