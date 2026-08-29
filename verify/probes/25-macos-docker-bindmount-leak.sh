#!/usr/bin/env bash
# CLAIM  macos-shenanigans.md §4
#   A bind mount from APFS LEAKS case-insensitivity into a Linux container, so
#   "just run it in a container" is not a valid case check; copying onto the
#   container's own filesystem is.
. "$(dirname "$0")/../lib.sh"
need_macos
need docker
docker info >/dev/null 2>&1 || { echo "    skip: docker daemon not reachable"; exit $SKIPPED; }
probe_tmp; d=$PROBE_TMP
need_case_insensitive_fs "$d"

: > "$d/Logo.webp"
img=alpine:3
docker image inspect "$img" >/dev/null 2>&1 || docker pull -q "$img" >/dev/null 2>&1 || \
  { echo "    skip: cannot obtain $img"; exit $SKIPPED; }

expect "wrong case RESOLVES through the bind mount" 'EXISTS' \
  "$(docker run --rm -v "$d":/m "$img" sh -c 'test -e /m/logo.webp && echo EXISTS || echo ABSENT')"
expect "...after copying to the container FS it is ABSENT" 'ABSENT' \
  "$(docker run --rm -v "$d":/m "$img" sh -c 'mkdir /c && cp /m/Logo.webp /c/ && (test -e /c/logo.webp && echo EXISTS || echo ABSENT)')"
expect "the container rootfs really is case-sensitive" 'sensitive' \
  "$(docker run --rm "$img" sh -c 'touch /A; test -e /a && echo insensitive || echo sensitive')"
verdict
