#!/usr/bin/env bash
# CLAIM  cpp-shenanigans.md §1
#   A partial memcpy leaves an int indeterminate. At -O2 the optimizer can fold
#   the read and print the "correct" value, so a green host build hides the bug;
#   -O0 and -ftrivial-auto-var-init=pattern force it into the open.
. "$(dirname "$0")/../lib.sh"
need cc
probe_tmp; d=$PROBE_TMP

cat > "$d/ub.c" <<'C'
#include <stdio.h>
#include <string.h>
int main(void) {
    unsigned char src[4] = {8, 1, 2, 3};
    int x;                      /* 4-byte object, uninitialized */
    memcpy(&x, src, 1);         /* only the LOW byte is written */
    printf("%d\n", x);          /* using the typed value -> UB */
    return 0;
}
C
build() { cc $1 -o "$d/a.out" "$d/ub.c" 2>/dev/null && "$d/a.out"; }

expect "it compiles clean at -O2 (no diagnostic)" '0' \
  "$(cc -O2 -Wall -Wextra -o "$d/a.out" "$d/ub.c" 2>"$d/w"; echo $?)"
expect "...and -Wall -Wextra says nothing about it" '' "$(grep -c uninitial "$d/w" | sed 's/^0$//')"

o2=$(build -O2); o0=$(build -O0)
note "-O2 printed $o2 ; -O0 printed $o0"
expect "-O2 folds the read into the 'correct' 8" '8' "$o2"

pat=$(cc -O0 -ftrivial-auto-var-init=pattern -o "$d/a.out" "$d/ub.c" 2>/dev/null && "$d/a.out")
expect "-ftrivial-auto-var-init=pattern makes it deterministic garbage" 'yes' \
  "$([ -n "$pat" ] && [ "$pat" != 8 ] && echo yes || echo no)"
note "pattern-init printed $pat (clang fills 0xAA -> 0xAAAAAA08 = $((0xAAAAAA08 - 0x100000000)))"

# The documented fix: read the exact width, leave nothing indeterminate.
cat > "$d/ok.c" <<'C'
#include <stdio.h>
int main(void) { unsigned char src[4] = {8,1,2,3}; const unsigned char x = src[0]; printf("%d\n", x); return 0; }
C
for opt in -O0 -O2 "-O0 -ftrivial-auto-var-init=pattern"; do
  expect "the fix prints 8 at $opt" '8' "$(cc $opt -o "$d/b.out" "$d/ok.c" 2>/dev/null && "$d/b.out")"
done
verdict
