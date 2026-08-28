#!/usr/bin/env bash
# Re-check every mechanically testable claim in this repo against the machine
# you are on right now.
#
#   ./verify/run.sh            # all probes
#   ./verify/run.sh macos      # only probes whose filename matches "macos"
#
# Exit 0 = every claim that could run still HOLDS.
# Exit 1 = at least one claim DRIFTED -- the file is now wrong about something.
set -uo pipefail
cd "$(dirname "$0")/.."
filter=${1:-}
held=0; drifted=0; skipped=0; bad=()

for p in verify/probes/*.sh; do
  [ -n "$filter" ] && case "$p" in *"$filter"*) ;; *) continue ;; esac
  name=$(basename "$p" .sh)
  claim=$(sed -n '2s/^# CLAIM  //p' "$p")
  printf '\n\033[1m%s\033[0m  (%s)\n' "$name" "$claim"
  bash "$p"; rc=$?
  case $rc in
    0)  printf '  \033[32mHOLDS\033[0m\n';   held=$((held+1)) ;;
    77) printf '  \033[33mSKIPPED\033[0m\n'; skipped=$((skipped+1)) ;;
    *)  printf '  \033[31mDRIFTED\033[0m\n'; drifted=$((drifted+1)); bad+=("$name") ;;
  esac
done

printf '\n----\n%d held, %d drifted, %d skipped\n' "$held" "$drifted" "$skipped"
if [ "$drifted" -gt 0 ]; then
  printf 'drifted: %s\n' "${bad[*]}"
  printf 'A drifted probe means the .md is now WRONG, not that the probe is broken.\n'
  exit 1
fi
