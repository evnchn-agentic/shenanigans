# cpp-shenanigans — READ before writing/reviewing C or C++

> **C and C++ will happily compile — and often *run correctly* — code that is undefined behavior (UB).
> "It worked when I tested it" is not evidence of correctness:** the compiler is allowed to make UB do
> whatever is fastest, including silently *deleting your bug* at `-O2` and resurrecting it on another
> target, another optimization level, or the next compiler release. The traps below fail **silently**.

## §1 — using an uninitialized value is UB → a passing `-O2` host build can HIDE the bug

Evaluating an object whose value is indeterminate — an uninitialized variable, or one only *partially*
written — is undefined behavior. (Narrow exception: you may inspect the raw *bytes* through
`unsigned char` / `std::byte`; the UB is *using the typed value*, e.g. as an `int`.) It is **not** a
guarantee of "leftover garbage." Because it is UB, the optimizer may assume it never happens, so the
*same source* can:

- print the **correct** value on your dev box at `-O2` — the optimizer folded the read into a clean
  value — **and**
- print **garbage** on the target: another/older compiler, `-O0`/`-Os`, or different stack contents.

**A green host run therefore proves nothing for a UB bug.** Classic concrete instance — copying fewer
bytes than the destination's width leaves the upper bytes uninitialized:

```cpp
int x;                        // 4-byte object, uninitialized
std::memcpy(&x, src, 1);      // only the LOW byte is written; x is now INDETERMINATE
use(x);                       // evaluating x as int  -> UB
```

On a little-endian target this can surface as e.g. `-1121283064`, whose low byte is the correct value
and whose upper 3 bytes are stack garbage. Yet at `-O2` a compiler **may** fold the read into a single
zero-extending byte load, making *this particular symptom* vanish (the UB doesn't go away — only one
manifestation does) — so it hides from a naive host test and only bites on-target. **Fix — read the
exact width; leave no uninitialized object:**

```cpp
const uint8_t x = src[0];     // or value-initialize:  int x{};  /  int x = 0;
```

**Force a UB bug to reveal itself — do not trust the default build:**

- build the repro at **`-O0`** — the optimizer is far less likely to fold the bad read away;
- **`-ftrivial-auto-var-init=pattern`** (Clang & GCC ≥12) fills uninitialized locals with a fixed
  pattern so "sometimes garbage" becomes *deterministic* garbage you can see — but the **pattern byte
  differs by compiler**: Clang uses `0xAA` (the `int x` above then reads `0xAAAAAA08`, not a lucky
  `8`), GCC currently uses `0xFE` (and documents that it may change);
- **`-fsanitize=memory`** (MSan — **Clang/LLVM only; GCC has no MSan**) *reports* the uninitialized
  read directly, given sufficiently instrumented code;
- the manifestation is **optimization-level, compiler, and ABI dependent — not something you can pin
  on the instruction set**: swapping x86 ↔ ARM ↔ MIPS won't reliably surface it (the readable
  `store-1-byte / load-4-bytes` shape is the same on every ISA), though ISA/ABI can affect *how* it
  shows. Changing `-O`, the compiler, or the sanitizer is what surfaces it.

**"Green build ≠ correct" generalizes to the other classic UB**, but the tools don't overlap — pick
the right one:

- **signed-integer overflow, alignment, bad shifts** → `-fsanitize=undefined` (UBSan);
- **out-of-bounds / use-after-free** → `-fsanitize=address` (ASan);
- **uninitialized reads** → MSan (above);
- **strict-aliasing violations (type-punning through pointers)** → caught *reliably by none* of the
  sanitizers. Keep `-Wstrict-aliasing` on, prefer `memcpy` over pointer casts, and don't assume a
  clean sanitizer run means clean.
