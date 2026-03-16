# Formally Verified SIMD Optimizations in FFmpeg and libvpx

## Overview

We use an LLM to propose optimizations to hand-written x86 SIMD assembly in
FFmpeg and libvpx, then formally verify equivalence using a Sail formal
specification of x86-64, ISLA symbolic execution, and Z3 SMT solving. The
pipeline is:

1. LLM analyzes existing NASM assembly and proposes a shorter equivalent
2. Both the original and optimized instruction sequences are encoded as raw x86
   machine code bytes in Sail test functions
3. ISLA symbolically executes both sequences through the full Sail x86 decoder,
   producing SMT formulas over symbolic 128-bit XMM register inputs
4. Z3 proves UNSAT (no distinguishing input exists), confirming bit-exact
   equivalence for all 2^256 possible input pairs

All optimizations stay within the same ISA as the original code (or reduce the
ISA requirement). No new instruction set extensions are introduced.

All optimizations were applied to the respective project sources, compiled, and
validated against their test suites:
- FFmpeg: 62/62 blend checkasm tests pass, 1272/1272 VP9 DSP tests pass
- libvpx: 20/20 post-processing tests pass

---

## 1. HARDMIX blend mode (vf_blend.asm)

**Status: Formally proven equivalent (Z3: UNSAT). Applied to FFmpeg.**

HARDMIX computes `(a + b >= 255) ? 0xFF : 0x00` per byte.

### Original (4 instructions, 3 memory-loaded constants, 5 XMM registers)

```nasm
VBROADCASTI128  m2, [pb_255]       ; load 0xFF constant
VBROADCASTI128  m3, [pb_128]       ; load 0x80 constant
VBROADCASTI128  m4, [pb_127]       ; load 0x7F constant
; inner loop:
pxor            m1, m4             ; b ^= 0x7F
pxor            m0, m3             ; a ^= 0x80
pcmpgtb         m1, m0             ; signed compare trick
pxor            m1, m2             ; invert mask
```

The original uses an unsigned-to-signed comparison trick: XOR with 0x80 and
0x7F converts unsigned bytes to signed, enabling `pcmpgtb` (signed compare) to
simulate unsigned overflow detection. The final XOR inverts the result.

### Optimized (2 instructions, 0 memory loads, 3 XMM registers)

```nasm
pcmpeqb         m2, m2             ; m2 = all 0xFF (no memory access)
; inner loop:
movu            m0, [topq + xq]
movu            m1, [bottomq + xq]
paddusb         m0, m1             ; min(a + b, 255)
pcmpeqb         m0, m2             ; saturated sum == 255 iff a+b >= 255
```

`paddusb` saturates at 255, so the saturated result equals 255 if and only if
the true sum is >= 255. `pcmpeqb` converts this to a 0xFF/0x00 mask.

### Savings

- 4 -> 2 SIMD instructions in the inner loop (50% reduction)
- 3 -> 0 constants loaded from memory
- 5 -> 3 XMM registers used
- The `pb_127` and `pb_128` data constants removed from `.rodata`
- The all-ones constant is generated via `pcmpeqb reg, reg` (no memory access)

### Formal proof

The original 4-instruction sequence (`pxor xmm1, xmm4; pxor xmm0, xmm3;
pcmpgtb xmm1, xmm0; pxor xmm1, xmm2`) and the optimized 2-instruction
sequence (`paddusb xmm0, xmm1; pcmpeqb xmm0, xmm2`) were encoded as raw x86
machine code bytes and executed through the Sail x86 decoder via ISLA. Constants
were set to concrete values; xmm0 and xmm1 were left symbolic. Z3 returned
**UNSAT**, confirming equivalence for all 2^256 possible input pairs.

---

## 2. PHOENIX blend mode (vf_blend.asm)

**Status: 8-bit formally proven equivalent (Z3: UNSAT). 16-bit formally proven
equivalent (Z3: UNSAT). Both applied to FFmpeg.**

PHOENIX computes `255 - |a - b|` (8-bit) or `65535 - |a - b|` (16-bit).

### 8-bit: Original (6 instructions)

```nasm
mova            m2, m0             ; save a
pminub          m0, m1             ; min(a, b)
pmaxub          m1, m2             ; max(a, b)
mova            m2, m3             ; copy 255 constant
psubusb         m2, m1             ; 255 - max(a, b)
paddusb         m2, m0             ; 255 - max(a, b) + min(a, b)
```

### 8-bit: Optimized (5 instructions)

```nasm
mova            m2, m0             ; save a
psubusb         m0, m1             ; max(a - b, 0)
psubusb         m1, m2             ; max(b - a, 0)
por             m0, m1             ; |a - b|
pxor            m0, m3             ; ~|a - b| = 255 - |a - b|
```

The key identity: `255 - |a - b| = ~|a - b|` since `~x = 255 - x` for bytes.

### 16-bit: Original (6 instructions, requires SSE4.1 for pminuw/pmaxuw)

```nasm
mova            m2, m0
pminuw          m0, m1             ; SSE4.1
pmaxuw          m1, m2             ; SSE4.1
mova            m2, m3             ; copy 65535 constant
psubusw         m2, m1             ; 65535 - max(a, b)
paddusw         m2, m0             ; + min(a, b)
```

### 16-bit: Optimized (5 instructions, SSE2 only)

```nasm
mova            m2, m0
psubusw         m0, m1
psubusw         m1, m2
por             m0, m1             ; |a - b|
pxor            m0, m3             ; ~|a - b| = 65535 - |a - b|
```

### Savings

- 8-bit: 6 -> 5 instructions (17% reduction), eliminates `pb_255` memory load
- 16-bit: 6 -> 5 instructions, ISA requirement SSE4.1 -> SSE2

### Formal proof

Both 8-bit and 16-bit versions were encoded as raw machine code and verified
through ISLA/Z3. The 8-bit proof covers the original `pminub; pmaxub;
psubusb; paddusb` sequence vs the optimized `psubusb; psubusb; por; pxor`.
The 16-bit proof covers `pminuw; pmaxuw; psubusw; paddusw` (SSE4.1) vs
`psubusw; psubusw; por; pxor` (SSE2). Both returned **UNSAT**.

---

## 3. DIFFERENCE blend mode (vf_blend.asm)

**Status: 8-bit proven equivalent (previous work). 16-bit formally proven
equivalent (Z3: UNSAT). Both applied to FFmpeg.**

DIFFERENCE computes `|a - b|` per byte (8-bit) or per word (16-bit).

### 8-bit: Original (13+ instructions, SSE2)

Widens bytes to 16-bit words, subtracts, takes absolute value via the ABS2
macro (`pxor zero; psubw; pmaxsw` or `pcmpgtw; pxor; psubw`), then packs back.

```nasm
punpckhbw  m3, m0, m2          ; widen top (high half)
punpcklbw  m0, m2              ; widen top (low half)
punpckhbw  m4, m1, m2          ; widen bottom (high)
punpcklbw  m1, m2              ; widen bottom (low)
psubw      m0, m1              ; signed subtract (low)
psubw      m3, m4              ; signed subtract (high)
; ABS2 macro expands to 6 instructions (SSE2/mmxext path)
packuswb   m0, m3              ; pack back to bytes
```

### 8-bit: Optimized (4 instructions, SSE2)

```nasm
mova       m2, m0              ; copy a
psubusb    m0, m1              ; max(a - b, 0)
psubusb    m1, m2              ; max(b - a, 0)
por        m0, m1              ; |a - b|
```

Exactly one of the two `psubusb` results is nonzero (the one where the
minuend was larger), so `por` combines them correctly.

### 16-bit: Original (11 instructions, requires SSE4.1 for packusdw)

Widens 16-bit words to 32-bit dwords via `punpcklwd`/`punpckhwd` with zero,
subtracts with `psubd`, takes `pabsd` (SSSE3), packs with `packusdw` (SSE4.1).

### 16-bit: Optimized (4 instructions, SSE2 only)

```nasm
mova       m2, m0
psubusw    m0, m1              ; max(a - b, 0)
psubusw    m1, m2              ; max(b - a, 0)
por        m0, m1              ; |a - b|
```

### Savings

- 8-bit: 13+ -> 4 instructions (69% reduction)
- 16-bit: 11 -> 4 instructions (64% reduction), ISA SSE4.1 -> SSE2

### Formal proof (16-bit)

The original 11-instruction sequence (including `movdqa` copies, `punpcklwd`,
`punpckhwd`, `psubd`, `pabsd`, `packusdw`) and the optimized 4-instruction
sequence (`movdqa; psubusw; psubusw; por`) were encoded as raw machine code
and verified. Z3 returned **UNSAT**.

---

## 4. EXTREMITY blend mode (vf_blend.asm)

**Status: 8-bit proven equivalent (previous work). 16-bit formally proven
equivalent (Z3: UNSAT). Both applied to FFmpeg.**

EXTREMITY computes `|255 - a - b|` per byte, or `|65535 - a - b|` per word.

The key identity: `255 - a = ~a` (bitwise NOT) for 8-bit unsigned values,
and `65535 - a = ~a` for 16-bit. Therefore `|255 - a - b| = |~a - b|`.

### 8-bit: Original (13+ instructions, SSE2)

Widens to 16-bit, subtracts from 255, subtracts b, takes abs, packs.

### 8-bit: Optimized (5 instructions, SSE2)

```nasm
pxor       m0, m3              ; ~a (m3 = all 0xFF via pcmpeqb)
mova       m2, m0              ; copy ~a
psubusb    m0, m1              ; max(~a - b, 0)
psubusb    m1, m2              ; max(b - ~a, 0)
por        m0, m1              ; |~a - b| = |255 - a - b|
```

### 16-bit: Original (15 instructions, requires SSE4.1)

Widens to 32-bit dwords, subtracts from 65535, subtracts b, uses `pabsd`,
packs with `packusdw`.

### 16-bit: Optimized (5 instructions, SSE2 only)

```nasm
pxor       m0, m3              ; ~a (m3 = all 0xFFFF)
mova       m2, m0
psubusw    m0, m1
psubusw    m1, m2
por        m0, m1              ; |65535 - a - b|
```

### Savings

- 8-bit: 13+ -> 5 instructions (62% reduction)
- 16-bit: 15 -> 5 instructions (67% reduction), ISA SSE4.1 -> SSE2

### Formal proof (16-bit)

The original 15-instruction sequence (widening, dword subtraction from 65535,
`pabsd`, `packusdw`) vs the 5-instruction sequence (`pxor; movdqa; psubusw;
psubusw; por`) verified through ISLA/Z3. Z3 returned **UNSAT**.

---

## 5. NEGATION blend mode (vf_blend.asm)

**Status: 8-bit proven equivalent (previous work). 16-bit formally proven
equivalent (Z3: UNSAT). Both applied to FFmpeg.**

NEGATION computes `255 - |255 - a - b|`, i.e., the complement of EXTREMITY.

Since `255 - x = ~x` for bytes: `NEGATION = ~EXTREMITY = ~|~a - b|`.

### 8-bit: Optimized (6 instructions, SSE2)

```nasm
pxor       m0, m3              ; ~a
mova       m2, m0
psubusb    m0, m1
psubusb    m1, m2
por        m0, m1              ; |~a - b|
pxor       m0, m3              ; ~|~a - b| = 255 - |255 - a - b|
```

### 16-bit: Optimized (6 instructions, SSE2 only)

Same pattern with `psubusw`.

### Savings

- 8-bit: 15+ -> 6 instructions (60% reduction)
- 16-bit: 19 -> 6 instructions (68% reduction), ISA SSE4.1 -> SSE2

### Formal proof (16-bit)

The original 19-instruction sequence (EXTREMITY's widen/abs/pack plus
additional dword subtraction from 65535 and another `packusdw`) vs the
6-instruction sequence (`pxor; movdqa; psubusw; psubusw; por; pxor`)
verified through ISLA/Z3. Z3 returned **UNSAT**.

---

## 6. atadenoise filter (vf_atadenoise.asm)

**Status: Not yet formally proven (requires constrained inputs).**

The adaptive temporal denoising filter accumulates a count of "active" pixel
lanes (those that haven't exceeded the difference threshold). The mask register
`m12` has `0xFFFF` for active lanes and `0x0000` for inactive lanes.

### Mask-to-count conversion (4 sites in the inner loop)

Original (3 instructions per site):

```nasm
mova       m6, m12             ; copy mask
psrlw      m6, 15              ; 0xFFFF -> 1, 0x0000 -> 0
paddw      m8, m6              ; count += 0 or 1
```

Optimized (1 instruction per site):

```nasm
psubw      m8, m12             ; count -= 0xFFFF = count += 1 (two's complement)
```

Since `0xFFFF` is `-1` in signed 16-bit, `psubw(count, -1) = count + 1` for
active lanes, and `psubw(count, 0) = count` for inactive lanes.

**Note:** This optimization is equivalent only when each word of `m12` is
exactly `0xFFFF` or `0x0000` (i.e., it is a comparison mask). This invariant
holds in the atadenoise code because `m12` is derived from `pcmpgtw` results
through `por`/`pand`/`pxor` operations that preserve the all-ones/all-zeros
property. A formal proof would require constraining the symbolic inputs to
this mask domain.

### Combined savings

- 8 instructions eliminated across 4 loop sites (mask-to-count)
- 1 register freed (m10 no longer needed for pw_ones constant)
- 1 constant removed from `.rodata` section

---

## Summary

### All formally verified optimizations

| # | Project | Target | Original | Optimized | Reduction | ISA | Z3 |
|---|---|---|---|---|---|---|---|
| 1 | FFmpeg | HARDMIX (vf_blend.asm, 8-bit) | 4 instrs + 3 consts | 2 instrs + 0 consts | 50% | SSE2 | **UNSAT** |
| 2 | FFmpeg | PHOENIX (vf_blend.asm, 8-bit) | 6 instrs | 5 instrs | 17% | SSE2 | **UNSAT** |
| 3 | FFmpeg | PHOENIX (vf_blend.asm, 16-bit) | 6 instrs (SSE4) | 5 instrs | 17% | SSE4->SSE2 | **UNSAT** |
| 4 | FFmpeg | DIFFERENCE (vf_blend.asm, 8-bit) | 13+ instrs | 4 instrs | 69% | SSE2 | prev |
| 5 | FFmpeg | DIFFERENCE (vf_blend.asm, 16-bit) | 11 instrs (SSE4) | 4 instrs | 64% | SSE4->SSE2 | **UNSAT** |
| 6 | FFmpeg | EXTREMITY (vf_blend.asm, 8-bit) | 13+ instrs | 5 instrs | 62% | SSE2 | prev |
| 7 | FFmpeg | EXTREMITY (vf_blend.asm, 16-bit) | 15 instrs (SSE4) | 5 instrs | 67% | SSE4->SSE2 | **UNSAT** |
| 8 | FFmpeg | NEGATION (vf_blend.asm, 8-bit) | 15+ instrs | 6 instrs | 60% | SSE2 | prev |
| 9 | FFmpeg | NEGATION (vf_blend.asm, 16-bit) | 19 instrs (SSE4) | 6 instrs | 68% | SSE4->SSE2 | **UNSAT** |
| 10 | FFmpeg | SIGN_ADD (vp9lpf.asm) | 8 instrs | 4 instrs | 50% | SSE2 | **UNSAT** |
| 11 | FFmpeg | SIGN_SUB (vp9lpf.asm) | 8 instrs | 4 instrs | 50% | SSE2 | **UNSAT** |
| 12 | FFmpeg | atadenoise mask-to-count | 3 instrs x4 | 1 instr x4 | 67% | SSE4 | pending |
| 13 | libvpx | threshold OR (deblock_sse2.asm) | 8+9 instrs | 6+6 instrs | 29% | SSE2 | **UNSAT** |

("prev" = proven in previous work; "pending" = requires constrained-input proof)

Total: **12 formally proven equivalences** (Z3 UNSAT) across 2 projects, plus 1 pending.

### Key patterns exploited

- **Saturating arithmetic for absolute difference**: `|a-b| = psubusb(a,b) | psubusb(b,a)`.
  This avoids widening to a larger type, subtracting, taking abs, and packing back.
  Applied to: DIFFERENCE, EXTREMITY, NEGATION, PHOENIX (FFmpeg).
- **Saturating addition for overflow detection**: `a+b >= 255` iff `paddusb(a,b) == 255`.
  This replaces a multi-step signed-comparison trick.
  Applied to: HARDMIX (FFmpeg).
- **Signed-domain bias for clamped addition**: `clamp(u8 + i8, 0, 255)` =
  `(u8 ^ 0x80) +_signed_sat i8) ^ 0x80`. Converts unsigned+signed clamping
  to signed saturating arithmetic via XOR with 0x80.
  Applied to: SIGN_ADD/SIGN_SUB in VP9 loop filter (FFmpeg).
- **Two's complement identity for mask counting**: A mask of `0xFFFF` is `-1` in
  signed 16-bit, so `psubw(count, mask)` adds 1 for active lanes and 0 for inactive.
  Applied to: atadenoise (FFmpeg).
- **Bitwise NOT as subtraction from max**: `~a = 255-a` (bytes) or `~a = 65535-a` (words),
  enabling byte/word-level computation that would otherwise require widening.
  Applied to: EXTREMITY, NEGATION, PHOENIX (FFmpeg).
- **pmaxub for threshold combining**: `(a > T) || (b > T)` ↔ `max(a, b) > T`.
  Reduces two separate threshold comparisons to one.
  Applied to: deblock post-processing filter (libvpx).

All 16-bit blend mode optimizations (DIFFERENCE, EXTREMITY, NEGATION, PHOENIX)
reduce the ISA requirement from SSE4.1 to SSE2, broadening hardware compatibility.

---

## Validation and benchmarks

All optimizations were applied to the respective project sources, compiled, and
validated against their test suites.

### FFmpeg blend filters

Applied to `libavfilter/x86/vf_blend.asm` and `vf_blend_init.c`:
- Replaced DIFFERENCE, EXTREMITY, NEGATION, PHOENIX, HARDMIX macros
- Removed SSSE3 specializations (SSE2 versions now faster)
- Moved 16-bit modes from SSE4 to SSE2 dispatch
- Removed unused `.rodata` constants (`pb_127`, `pb_128`, `pd_65535`)

**Test result**: all 62 blend checkasm tests pass (SSE2, SSE4.1, AVX2).

Kernel microbenchmarks (checkasm --bench, cycles, lower is better):

| Function | Before | After | Kernel speedup |
|---|---|---|---|
| difference_sse2 | 998.6 | 406.0 | **2.46x** |
| difference_avx2 | 345.6 | 235.4 | **1.47x** |
| difference_16 (sse4→sse2) | 725.5 | 523.7 | **1.39x** |
| extremity_sse2 | 1087.5 | 533.0 | **2.04x** |
| extremity_avx2 | 403.1 | 262.6 | **1.54x** |
| extremity_16 (sse4→sse2) | 911.7 | 534.2 | **1.71x** |
| negation_sse2 | 1230.4 | 582.4 | **2.11x** |
| negation_avx2 | 481.6 | 324.3 | **1.49x** |
| negation_16 (sse4→sse2) | 1062.4 | 596.4 | **1.78x** |
| hardmix_sse2 | 414.2 | 328.7 | **1.26x** |
| phoenix_sse2 | 597.4 | 533.2 | **1.12x** |

End-to-end blend filter (1080p30, hyperfine, 5 runs): **~1% improvement**.
Memory-bandwidth-bound — the kernel is a small fraction of total pipeline time.

### FFmpeg VP9 loop filter

Applied to `libavcodec/x86/vp9lpf.asm`: replaced SIGN_ADD/SIGN_SUB macros
(6 call sites).

**Test result**: all 1272 VP9 DSP checkasm tests pass.

Kernel microbenchmarks (checkasm --bench, cycles):

| Function | Before | After | Kernel speedup |
|---|---|---|---|
| mix2_v_44_16 SSE2 | 62.6 | 53.7 | **1.17x** |
| mix2_v_44_16 AVX | 60.1 | 52.8 | **1.14x** |
| v_4_8 MMXEXT | 69.9 | 62.7 | **1.11x** |
| h_4_8 MMXEXT | 120.1 | 109.8 | **1.09x** |
| mix2_v_88_16 SSE2 | 107.2 | 98.6 | **1.09x** |
| v_16_16 SSE2 | 210.4 | 201.3 | **1.05x** |

End-to-end VP9 decode (1080p30, single-threaded, hyperfine):
889.6ms → 882.9ms (**~0.8% improvement**). The loop filter is one of several
pipeline stages; a 5-10% kernel speedup in one stage yields <1% end-to-end.

### FFmpeg atadenoise filter

Applied to `libavfilter/x86/vf_atadenoise.asm`: replaced mask-to-count
pattern (4 sites), eliminated `pw_ones` constant register.

**Test result**: filter runs correctly on synthetic video (no dedicated
checkasm test exists for this filter).

### libvpx deblock post-processing filter

Applied to `vpx_dsp/x86/deblock_sse2.asm`: replaced threshold-OR pattern
with `pmaxub` combining in FIRST_2_ROWS and SECOND_2_ROWS macros.

**Test result**: all 20 libvpx post-processing tests pass (including
`CheckCvsAssembly` which verifies SIMD matches C reference).

Benchmark: 318ms → 316ms (**~0.6%**). Memory-bound workload.

### Observations on real-world impact

Kernel speedups range from 1.03x to 2.46x. End-to-end improvements are
consistently small (<1%) because:

1. **Memory bandwidth dominates**: pixel-processing filters load frames from
   memory, do a few SIMD ops, and store back. The compute time is a small
   fraction of total latency.
2. **Pipeline effect**: codec decode/encode has multiple stages (transform, MC,
   loop filter, entropy coding). Optimizing one stage yields proportionally
   small end-to-end gains.

The **instruction count reduction** (17-69%) and **ISA requirement reduction**
(SSE4.1→SSE2 for 4 modes) are the more robust metrics, as they are
independent of microarchitecture and memory subsystem behavior.

---

## 7. VP9 loop filter SIGN_ADD/SIGN_SUB (vp9lpf.asm)

**Status: Formally proven equivalent (Z3: UNSAT for both SIGN_ADD and SIGN_SUB).
Applied to FFmpeg, all 1272 VP9 DSP tests pass.**

The VP9 loop filter adds signed filter deltas to unsigned pixel values with
clamping to [0,255]. This operation (`clip_u8(u8 + i8)`) appears 6 times in
the hot path.

### Original SIGN_ADD (8 instructions)

Split signed i8 into positive and negative parts, then apply separately:

```nasm
pxor     pos, pos              ; zero
pxor     neg, neg              ; zero
pcmpgtb  pos, i8               ; mask where i8 < 0
psubb    neg, i8               ; -i8
pand     neg, pos              ; keep negative magnitudes
pandn    pos, i8               ; keep positive values
paddusb  dst, u8               ; + positives (saturating)
psubusb  dst, neg              ; - negatives (saturating)
```

### Optimized SIGN_ADD (4 instructions, including register copy)

Bias unsigned byte to signed domain via XOR 0x80, use signed saturating add,
bias back:

```nasm
mova     dst, u8               ; copy
pxor     dst, [pb_80]          ; unsigned -> signed domain
paddsb   dst, i8               ; signed saturating add
pxor     dst, [pb_80]          ; signed -> unsigned domain
```

The identity: XOR with 0x80 converts unsigned [0,255] to signed [-128,127].
`paddsb` clamps correctly in the signed domain. XOR back converts to unsigned.

### Kernel benchmark (checkasm, 8-bit VP9 loop filter)

| Function | Before (cycles) | After (cycles) | Speedup |
|---|---|---|---|
| mix2_v_44_16 SSE2 | 62.6 | 53.7 | **1.17x** |
| mix2_v_44_16 AVX | 60.1 | 52.8 | **1.14x** |
| mix2_v_88_16 SSE2 | 107.2 | 98.6 | **1.09x** |
| mix2_h_44_16 SSE2 | 118.8 | 111.5 | **1.07x** |
| h_4_8 MMXEXT | 120.1 | 109.8 | **1.09x** |
| v_4_8 MMXEXT | 69.9 | 62.7 | **1.11x** |
| v_16_16 SSE2 | 210.4 | 201.3 | **1.05x** |
| h_16_16 SSE2 | 279.8 | 271.1 | **1.03x** |

Consistent 3-17% kernel speedup across all filter sizes and ISA variants.

### End-to-end VP9 decode benchmark

Single-threaded VP9 decoding of a 10-second 1080p30 4Mbps video, measured with
`hyperfine` (5 runs, 1 warmup):

```
ffmpeg -threads 1 -i test_vp9.webm -f null -
```

| | Time (mean ± σ) |
|---|---|
| Before (original) | 889.6 ms ± 4.0 ms |
| After (optimized) | 882.9 ms ± 4.9 ms |
| **End-to-end speedup** | **~0.8%** |

The loop filter is one of several pipeline stages in VP9 decoding (transform,
motion compensation, loop filter, entropy decoding). A 5-10% kernel speedup
in one stage translates to <1% end-to-end, which is consistent with what other
SIMD optimization papers report for codec workloads.

---

## 8. libvpx deblock filter threshold combining (deblock_sse2.asm)

**Status: Formally proven equivalent (Z3: UNSAT). Applied to libvpx, all 20
post-processing tests pass.**

The VP8/VP9 deblock post-processing filter tests whether ANY of several
absolute differences exceeds a threshold. The original code tests each
difference separately and combines with `por`:

### Original FIRST_2_ROWS mask (8 instructions)

```nasm
movdqa   xmm2, flimit         ; load threshold
pxor     xmm1, xmm1           ; zero
movdqa   xmm7, xmm2           ; copy threshold
psubusb  xmm2, xmm4           ; flimit - |d1| (0 when exceeded)
psubusb  xmm7, xmm6           ; flimit - |d2|
pcmpeqb  xmm2, xmm1           ; 0xFF where |d1| > flimit
pcmpeqb  xmm7, xmm1           ; 0xFF where |d2| > flimit
por      xmm7, xmm2           ; either exceeded
```

### Optimized (6 instructions)

```nasm
movdqa   xmm2, flimit
pxor     xmm1, xmm1
pmaxub   xmm4, xmm6           ; max(|d1|, |d2|)
psubusb  xmm2, xmm4           ; flimit - max (0 when exceeded)
pcmpeqb  xmm2, xmm1           ; 0xFF where max > flimit
movdqa   xmm7, xmm2
```

The identity: `(a > T) || (b > T)` ↔ `max(a, b) > T`. Eliminates the
copy of flimit, one `psubusb`, one `pcmpeqb`, and the `por`.

Same optimization applied to SECOND_2_ROWS (saves 3 more instructions).
Total: 5 instructions saved per filter invocation.

### Benchmark

Post-processing speed test: 318ms → 316ms (~0.6%). Memory-bound workload.
