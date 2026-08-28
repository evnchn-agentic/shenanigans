#!/usr/bin/env bash
# CLAIM  macos-shenanigans.md §1
#   Path.exists() resolves the wrong case (and the wrong Unicode normalization);
#   iterdir() returns the bytes as stored, so a listing compare reproduces the
#   Linux-only bug locally.
. "$(dirname "$0")/../lib.sh"
need python3
probe_tmp; d=$PROBE_TMP
need_case_insensitive_fs "$d"

: > "$d/Logo.webp"
python3 - "$d" <<'PY' > "$d/out"
import sys, unicodedata
from pathlib import Path
d = Path(sys.argv[1])
print('exists_exact',  (d / 'Logo.webp').exists())
print('exists_wrong',  (d / 'logo.webp').exists())
print('listing',       sorted(p.name for p in d.iterdir() if p.suffix == '.webp'))
print('guard_catches', 'logo.webp' not in {p.name for p in d.iterdir()})

nfc = unicodedata.normalize('NFC', 'café.txt')
nfd = unicodedata.normalize('NFD', 'café.txt')
(d / nfc).write_text('x')
print('nfd_exists',   (d / nfd).exists())
print('stored_is_nfc', any(p.name == nfc for p in d.iterdir()))
PY
g() { grep "^$1 " "$d/out" | cut -d' ' -f2-; }

expect "exists() True for the real spelling"        'True'              "$(g exists_exact)"
expect "exists() ALSO True for the wrong case"      'True'              "$(g exists_wrong)"
expect "iterdir() reports only the stored spelling" "['Logo.webp']"     "$(g listing)"
expect "listing-compare guard catches it locally"   'True'              "$(g guard_catches)"
expect "exists() True for the NFD spelling too"     'True'              "$(g nfd_exists)"
expect "...while the stored name is the NFC one"    'True'              "$(g stored_is_nfc)"
verdict
