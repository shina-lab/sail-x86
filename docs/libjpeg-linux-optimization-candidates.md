# Optimization Candidates in libjpeg-turbo and the Linux Kernel

Survey date: 2026-09-10. Trees: `~/libjpeg-turbo` at d9b5af99 (2026-09-09),
`~/linux` at 50d05c7c76c9 (7.3-rc3, 2026-09-09).

This is the candidate list for extending the verified-optimization
experiment (FFmpeg, libvpx, BoringSSL) to two new corpora: libjpeg-turbo's
NASM SIMD (`simd/x86_64/*.asm`, ~14.7K lines) and the kernel's hand-written
x86-64 assembly (`arch/x86/crypto`, `lib/crypto/x86`, `lib/crc/x86`,
`arch/x86/lib`, ~38K lines). Every file was read in full; the "rejected"
sections record what was looked at and found tight.

Nothing here has been run through Isla/Z3 yet. "Checked" below means the
identity was confirmed by exhaustive enumeration over the stated input range
or by random testing in Python; those checks are evidence that the proposal
is worth proving, not proofs.

## The ISA rule

A rewrite is only a valid optimization if it uses no instruction above the
level the original file is dispatched at. Every corpus here dispatches by
CPUID feature, so an SSSE3 instruction in an `-sse2` file, or a BMI2 `rorx`
in a `-ssse3` file, is not an optimization but a different code path the
project already has (or deliberately does not have). Lowering the level is
fine and desirable, as in the FFmpeg SSE4.1-to-SSE2 cases.

This rule removes one existing result: the ABS16 proof in
`isla-equivalence-proof.md` replaces SSE2 code in `jquanti-sse2.asm` with
the SSSE3 `pabsw`, and `jquanti-avx2.asm` already uses `vpabsw`. It must not
be reported as an optimization.

Levels used below, taken from file names and the projects' dispatch code
(`jsimd_x86_64.c` for libjpeg-turbo; the `boot_cpu_has` / `cpu_has_*` checks
in the kernel glue):

| Corpus | File pattern | Level a rewrite may use |
|---|---|---|
| libjpeg-turbo | `*-sse2.asm` | SSE2 only (x86-64 baseline) |
| libjpeg-turbo | `*-avx2.asm` | up to AVX2 (so SSSE3/SSE4.1 forms are fine as `v` forms) |
| kernel | `chacha-ssse3`, `sha*-ssse3`, `blake2s-core` (SSSE3 path) | SSSE3 |
| kernel | `sha*-avx`, `sm3-avx`, `polyval-pclmul-avx`, `*-avx-*` | AVX (+AES-NI/PCLMUL where the file already uses them) |
| kernel | `chacha-avx2`, `sha*-avx2`, `*-avx2-*` | AVX2 (+BMI2 only where the file already uses `rorx`) |
| kernel | `ghash-pclmul`, `aes-aesni`, `aesni-intel_asm`, `serpent-sse2` | SSE2 (+PCLMUL / AES-NI as the file uses) |
| kernel | `aes-gcm-vaes-avx2` | AVX2 + VAES + VPCLMULQDQ |
| kernel | `arch/x86/lib/*.S`, `poly1305` scalar path | baseline x86-64 |

Enforcement: assemble every proposal under a GAS `.arch` directive derived
from the table (`.arch generic64` for SSE2, then `.arch .ssse3`, `.sse4.1`,
`.avx`, `.avx2`, `.aes`, `.pclmul`, `.bmi2` as allowed). Tested on binutils
2.42: `generic64` rejects `pabsw`; `generic64` + `.ssse3` rejects `vpabsw`;
`.sse4.1` rejects VEX forms; `.avx` rejects 256-bit integer ops. GAS has no
named Intel CPUs after `corei7` (AMD `znver1`..`znver5` exist), so a CPU such
as Sapphire Rapids is spelled as its list of extension flags. `llvm-mc
-mcpu=` does not reject anything and cannot be used for this.

A second, model-side gate: the specification's CPUID feature registers
(`has_ssse3`, `has_sse4_1`, `has_aesni`, `has_pclmulqdq`, `has_sha`,
`has_bmi1/2`, `has_avx512`, and AVX via XCR0) with the `enable_features_v1`
.. `v4` presets in `model/regs.sail` make the decoder raise #UD for
instructions above the configured level, so a proof run under the original
file's level fails on an out-of-level proposal. Today this gate is coarser
than GAS: the integer 0F38/0F3A maps are gated on SSSE3 as a whole (SSE4.1
integer ops pass under SSSE3), there is no AVX2 flag, and AVX-512 is one bit.
Tightening it (per-opcode SSE4.1/4.2 checks from the SDM's CPUID column, an
AVX2 flag, AVX-512 subset flags) is a model improvement worth doing
alongside this experiment.

## How to read an entry

Each entry gives the file and line range, the level the rewrite must respect,
the original sequence verbatim, what it computes, the proposal with counts,
and what the proof needs: which registers are outputs (scratch registers
that end up different must be excluded from the comparison), any
precondition on inputs, and constants that must be preloaded into registers.
Instruction counts exclude the loads and stores that frame the sequence.

Preconditions matter more here than in the FFmpeg cases. Several
libjpeg-turbo identities hold only because 16-bit lanes hold values that
came from bytes. For those, the proved sequence must start at the byte load
so the widening is inside it, or the proof must add the range assumption
explicitly; over fully symbolic int16 lanes they are false and Z3 will say
so.

---

# Tier 1: propose and prove first

## L1. h2v1 fancy upsampling entirely in bytes with `pavgb` (SSE2, 27 to 13)

**File:** `simd/x86_64/jdsample-sse2.asm` lines 122-151, the `.upsample`
loop body of `jsimd_h2v1_fancy_upsample_sse2`. Level: SSE2. AVX2 twin at
`jdsample-avx2.asm` 118-185 (30 to 12; the AVX2 version additionally spends
six `vperm2i128` reordering the unpacked words).

**Original** (after prev/next vectors are built at 110-117; xmm0 = 0):
```asm
    movdqa      xmm4, xmm1
    punpcklbw   xmm1, xmm0              ; xmm1 = ( 0  1  2  3  4  5  6  7)
    punpckhbw   xmm4, xmm0              ; xmm4 = ( 8  9 10 11 12 13 14 15)
    movdqa      xmm5, xmm2
    punpcklbw   xmm2, xmm0              ; xmm2 = (-1  0  1  2  3  4  5  6)
    punpckhbw   xmm5, xmm0              ; xmm5 = ( 7  8  9 10 11 12 13 14)
    movdqa      xmm6, xmm3
    punpcklbw   xmm3, xmm0              ; xmm3 = ( 1  2  3  4  5  6  7  8)
    punpckhbw   xmm6, xmm0              ; xmm6 = ( 9 10 11 12 13 14 15 16)

    pmullw      xmm1, [rel PW_THREE]
    pmullw      xmm4, [rel PW_THREE]
    paddw       xmm2, [rel PW_ONE]
    paddw       xmm5, [rel PW_ONE]
    paddw       xmm3, [rel PW_TWO]
    paddw       xmm6, [rel PW_TWO]

    paddw       xmm2, xmm1
    paddw       xmm5, xmm4
    psrlw       xmm2, 2              ; xmm2 = OutLE = ( 0  2  4  6  8 10 12 14)
    psrlw       xmm5, 2              ; xmm5 = OutHE = (16 18 20 22 24 26 28 30)
    paddw       xmm3, xmm1
    paddw       xmm6, xmm4
    psrlw       xmm3, 2              ; xmm3 = OutLO = ( 1  3  5  7  9 11 13 15)
    psrlw       xmm6, 2              ; xmm6 = OutHO = (17 19 21 23 25 27 29 31)

    psllw       xmm3, BYTE_BIT
    psllw       xmm6, BYTE_BIT
    por         xmm2, xmm3              ; xmm2 = OutL = ( 0  1  2 ... 13 14 15)
    por         xmm5, xmm6              ; xmm5 = OutH = (16 17 18 ... 29 30 31)
```

**Computes**, per byte with s = cur, p = prev, n = next:
`even = (3s + p + 1) >> 2`, `odd = (3s + n + 2) >> 2`, interleaved into 32
output bytes. Inputs xmm1 (cur), xmm2 (prev, shifted with carry), xmm3
(next); outputs xmm2 and xmm5 (stored). xmm7, the carry for the next
iteration, is computed at 119-120 and untouched.

**Identities** (checked exhaustively over all 65536 (s, p) pairs), with
`pavg(x,y) = (x+y+1)>>1` and `flooravg(x,y) = (x+y) - pavg(x,y)` computed
mod 256 (`paddb` then `psubb`; the true value is 0..255 so the wrap is
harmless):

    (3s+p+1)>>2 = flooravg(s, pavg(s,p))
    (3s+n+2)>>2 = pavg(s, flooravg(s,n))

**Proposal** (SSE2, 13; no PW_ONE/TWO/THREE constants, no zero register):
```asm
    pavgb       xmm2, xmm1          ; q = pavg(prev, cur)
    movdqa      xmm4, xmm1
    paddb       xmm4, xmm2          ; cur + q        (mod 256)
    pavgb       xmm2, xmm1          ; pavg(q, cur)
    psubb       xmm4, xmm2          ; even = flooravg(cur, q)
    movdqa      xmm5, xmm1
    paddb       xmm5, xmm3          ; cur + next     (mod 256)
    pavgb       xmm3, xmm1          ; pavg(cur, next)
    psubb       xmm5, xmm3          ; g = flooravg(cur, next)
    pavgb       xmm5, xmm1          ; odd = pavg(cur, g)
    movdqa      xmm6, xmm4
    punpcklbw   xmm4, xmm5          ; OutL
    punpckhbw   xmm6, xmm5          ; OutH
```
Outputs land in xmm4/xmm6 instead of xmm2/xmm5; the proof compares the two
output vectors, and the stores are renamed.

**Refutation to run alongside:** the obvious `pavgb(pavgb(s,p), s)` for
`(3s+p+1)>>2` (and likewise for the odd term) is wrong on 32768 of 65536
pairs (e.g. s=0, p=1 gives 1 instead of 0). Only the flooravg forms are
exact.

## L2. RGB to YCbCr, Cb/Cr finish in 16 bits (SSE2, 14 to 7, four blocks per file, seven colorspace variants)

**File:** `simd/x86_64/jccolext-sse2.asm` lines 353-368 (CbO), and the same
shape at 391-406 (CbE), 440-455 (CrO), 487-502 (CrE). Level: SSE2. AVX2 twin
at `jccolext-avx2.asm` 449-464, 487-502, 536-551, 583-598. The file is
`%include`d seven times (RGB, EXT_RGB, RGBX, BGR, BGRX, XBGR, XRGB).

**Original** (xmm7/xmm4 hold the `pmaddwd` partial sums of (R,G) with
`PW_MF016_MF033` from 343-346; xmm5 = BO, eight words 0..255):
```asm
    pxor        xmm1, xmm1
    pxor        xmm6, xmm6
    punpcklwd   xmm1, xmm5              ; xmm1 = BOL
    punpckhwd   xmm6, xmm5              ; xmm6 = BOH
    psrld       xmm1, 1                 ; xmm1 = BOL * FIX(0.500)
    psrld       xmm6, 1                 ; xmm6 = BOH * FIX(0.500)

    movdqa      xmm5, [rel PD_ONEHALFM1_CJ]  ; xmm5 = [PD_ONEHALFM1_CJ]

    paddd       xmm7, xmm1
    paddd       xmm4, xmm6
    paddd       xmm7, xmm5
    paddd       xmm4, xmm5
    psrld       xmm7, SCALEBITS         ; xmm7 = CbOL
    psrld       xmm4, SCALEBITS         ; xmm4 = CbOH
    packssdw    xmm7, xmm4              ; xmm7 = CbO
```
Constants: `PD_ONEHALFM1_CJ = 32767 + (128 << 16) = 8421375`; coefficient
pair (-11059, -21709); SCALEBITS = 16.

**Computes** `Cb = (P + (B << 15) + K) >> 16` with P = -11059 R - 21709 G
and K = 8421375. Since 11059 + 21709 = 32768 exactly, X = P + K lies in
[65535, 8421375], so `X >> 15` is in [1, 256] and fits a word without
`packssdw` saturation. Identity: `floor((X + B*2^15) / 2^16) =
floor((floor(X / 2^15) + B) / 2)`.

**Proposal** (SSE2, 7):
```asm
    paddd       xmm7, [rel PD_ONEHALFM1_CJ]
    paddd       xmm4, [rel PD_ONEHALFM1_CJ]
    psrad       xmm7, 15
    psrad       xmm4, 15
    packssdw    xmm7, xmm4              ; (X >> 15) as words, 1..256
    paddw       xmm7, xmm5              ; + BO
    psraw       xmm7, 1                 ; CbO
```
Checked exhaustively over all 2^24 (R, G, B). The Cr blocks use (-5329,
-27439), which also sum to 32768, plus `RO << 15`, so the same rewrite
applies.

**Precondition:** R, G, B are bytes. Start the proved sequence at the
`punpcklbw xmmA, xmmH` zero-extension (315-324) or assert the range; over
symbolic int16 lanes `packssdw` can saturate and the identity fails.

## L3. Huffman encoder zero test: pack first, then compare bytes (SSE2, 12 to 8 and 5 to 3)

**Files:** `simd/x86_64/jcphuff-sse2.asm` `REDUCE0` at 212-224 (used at 378
and 594); `jcphuff-sse2.asm` 476-479 and 514-517 (the `== ONE` test);
`jchuff-sse2.asm` 352-365, 381-382/405-408, 429-439/475-479, 500-511 (four
groups of `pxor/pcmpeqw/pxor/pcmpeqw/packsswb`). Level: SSE2. These are the
entropy encoder's hot loops.

**Original** (`REDUCE0`):
```asm
    pcmpeqw     xmm0, ZERO
    pcmpeqw     xmm1, ZERO
    pcmpeqw     xmm2, ZERO
    pcmpeqw     xmm3, ZERO
    pcmpeqw     xmm4, ZERO
    pcmpeqw     xmm5, ZERO
    pcmpeqw     xmm6, ZERO
    pcmpeqw     xmm7, ZERO

    packsswb    xmm0, xmm1
    packsswb    xmm2, xmm3
    packsswb    xmm4, xmm5
    packsswb    xmm6, xmm7
```
followed by `pmovmskb`. Computes a byte mask with bit i set iff word i is
zero.

**Proposal:** `packsswb` the eight registers into four first, then
`pcmpeqb x, ZERO` on the four: a word is zero iff its signed-saturated byte
is zero. 12 to 8. The `== ONE` test at 476-479 becomes `packsswb; pcmpeqb
PB_ONE` by the same argument (word == 1 iff saturated byte == 1). In
`jchuff-sse2.asm` each `pxor/pcmpeqw/pxor/pcmpeqw/packsswb` group becomes
`packsswb/pcmpeqb` (5 to 3 including the zeroing). Checked over all int16.

**Refutation to run alongside:** the same rewrite with `packuswb` is wrong: a
word of -32768 (possible when `Al = 0` in jcphuff) saturates to 0 and is
misreported as zero.

## L4. YCbCr to RGB, G path: fold the trailing `- Cr` into the `pmaddwd` (SSE2 and AVX2, 2 fewer per block)

**Files:** `simd/x86_64/jdcolext-sse2.asm` 147-174, `jdcolext-avx2.asm`
145-170, `jdmrgext-sse2.asm` 133-160, `jdmrgext-avx2.asm` 132-157. Level:
SSE2 / AVX2. Seven colorspace variants each.

**Original** (AVX2 file, abridged):
```asm
    vpunpckhwd  ymm4, ymm2, ymm6          ; (CbE, CrE) pairs
    vpunpcklwd  ymm2, ymm2, ymm6
    vpmaddwd    ymm2, ymm2, [rel PW_MF0344_F0285]
    vpmaddwd    ymm4, ymm4, [rel PW_MF0344_F0285]
    ...
    vpaddd      ymm2, ymm2, [rel PD_ONEHALF]
    vpsrad      ymm2, ymm2, SCALEBITS
    ...
    vpackssdw   ymm2, ymm2, ymm4
    vpsubw      ymm2, ymm2, ymm6          ; ... + CrE * -FIX(0.714) = (G - Y)E
```
Constants (-22554, 18734), PD_ONEHALF = 32768. Computes
`G - Y = ((-22554 Cb + 18734 Cr + 32768) >> 16) - Cr`.

**Proposal:** 18734 - 65536 = -46802 = 2 * (-23401). Interleave Cb with
**2 Cr** (already computed at 118-119 as `vpaddw ymm0, ymm6, ymm6` before it
is overwritten) and use the pair (-22554, -23401): the result is
`(-22554 Cb - 46802 Cr + 32768) >> 16`, the same value, with no `vpsubw`.
Removes two instructions per block, free in AVX2 (spare registers), costs a
copy in the SSE2 register allocation. Exact integer identity, checked over
all (Cb, Cr); the `packssdw` range is unchanged.

## L5. YCbCr to RGB chroma multiply with `vpmulhrsw` (AVX2 files only, 18 to 8)

**Files:** `simd/x86_64/jdcolext-avx2.asm` 116-140 and `jdmrgext-avx2.asm`
103-127. Level: AVX2 (`vpmulhrsw` is SSSE3-class, so this is **not** valid
for the `-sse2` twins at `jdcolext-sse2.asm` 114-142 and
`jdmrgext-sse2.asm` 100-128).

**Original** (SSE2 file shown for readability; the AVX2 file is the same
with `v` forms and no copies):
```asm
    movdqa      xmm2, xmm4              ; xmm2 = CbE
    movdqa      xmm3, xmm5              ; xmm3 = CbO
    paddw       xmm4, xmm4              ; xmm4 = 2 * CbE
    paddw       xmm5, xmm5              ; xmm5 = 2 * CbO
    movdqa      xmm6, xmm0              ; xmm6 = CrE
    movdqa      xmm7, xmm1              ; xmm7 = CrO
    paddw       xmm0, xmm0              ; xmm0 = 2 * CrE
    paddw       xmm1, xmm1              ; xmm1 = 2 * CrO

    pmulhw      xmm4, [rel PW_MF0228]   ; xmm4 = (2 * CbE * -FIX(0.22800))
    pmulhw      xmm5, [rel PW_MF0228]   ; xmm5 = (2 * CbO * -FIX(0.22800))
    pmulhw      xmm0, [rel PW_F0402]    ; xmm0 = (2 * CrE * FIX(0.40200))
    pmulhw      xmm1, [rel PW_F0402]    ; xmm1 = (2 * CrO * FIX(0.40200))

    paddw       xmm4, [rel PW_ONE]
    paddw       xmm5, [rel PW_ONE]
    psraw       xmm4, 1                 ; xmm4 = (CbE * -FIX(0.22800))
    psraw       xmm5, 1                 ; xmm5 = (CbO * -FIX(0.22800))
    paddw       xmm0, [rel PW_ONE]
    paddw       xmm1, [rel PW_ONE]
    psraw       xmm0, 1                 ; xmm0 = (CrE * FIX(0.40200))
    psraw       xmm1, 1                 ; xmm1 = (CrO * FIX(0.40200))

    paddw       xmm4, xmm2
    paddw       xmm5, xmm3
    paddw       xmm4, xmm2             ; xmm4 = (CbE * FIX(1.77200)) = (B - Y)E
    paddw       xmm5, xmm3             ; xmm5 = (CbO * FIX(1.77200)) = (B - Y)O
    paddw       xmm0, xmm6             ; xmm0 = (CrE * FIX(1.40200)) = (R - Y)E
    paddw       xmm1, xmm7             ; xmm1 = (CrO * FIX(1.40200)) = (R - Y)O
```
Constants: `PW_MF0228 = -14942`, `PW_F0402 = 26345`, `PW_ONE = 1`.

**Computes**, per lane with x = Cb - 128 or Cr - 128 in [-128, 127]:
`((((2x * C) >> 16) + 1) >> 1) = floor(x*C/65536 + 1/2)`, then
B - Y = that + 2x = round(x * 116130 / 65536) and R - Y = that + x =
round(x * 91881 / 65536).

**Proposal** (2 per register, 18 to 8 arithmetic instructions):
```asm
    vpaddw      ymm4, ymm4, ymm4
    vpmulhrsw   ymm4, ymm4, [rel PW_29033]    ; (B - Y) = round(Cb * 1.772)
    vpaddw      ymm0, ymm0, ymm0
    vpmulhrsw   ymm0, ymm0, [rel PW_22970]    ; (R - Y) = round(Cr * 1.402)
```
Checked exhaustively for x in [-128, 127]. The constant choice is
sharp: 29033 verifies and 29032 does not; 22970 and 22971 both verify.

**Precondition:** byte-origin lanes. Over arbitrary int16 the `paddw x, x`
wraps for |x| >= 16384 and the identity is false.

**Refutations to run alongside:** (a) the naive `round(1.772 * 16384) =
29032`; (b) the whole thing over unconstrained int16; (c) the G path via two
`pmulhrsw` (`pmulhrsw(Cb, -11277) + pmulhrsw(Cr, -23401)` in place of the
`pmaddwd` path), which double-rounds and differs on 16063 of 65536 pairs.

## L6. Downsampling pair sums with `vpmaddubsw` (AVX2 file only, 4 to 1 per register)

**File:** `simd/x86_64/jcsample-avx2.asm` 139-153 (h2v1) and 308-331
(h2v2). Level: AVX2. Not valid for `jcsample-sse2.asm` 120-136 / 269-295
(`pmaddubsw` is SSSE3).

**Original** (SSE2 file shown; xmm6 = 0x00FF words, xmm7 = alternating
(0,1) bias words):
```asm
    movdqa      xmm2, xmm0
    movdqa      xmm3, xmm1

    pand        xmm0, xmm6
    psrlw       xmm2, BYTE_BIT
    pand        xmm1, xmm6
    psrlw       xmm3, BYTE_BIT

    paddw       xmm0, xmm2
    paddw       xmm1, xmm3
    paddw       xmm0, xmm7
    paddw       xmm1, xmm7
    psrlw       xmm0, 1
    psrlw       xmm1, 1

    packuswb    xmm0, xmm1
```
Computes, per byte pair (a, b): `(a + b + bias) >> 1` with bias alternating
0/1; h2v2 adds two rows and uses bias (1, 2) with `>> 2`.

**Proposal:** `vpmaddubsw x, x, [rel PB_ONE]` (all-ones signed bytes) gives
a + b (at most 510, no saturation) per word directly from the bytes; the
copy and mask vanish. h2v1 block 13 to 7, h2v2 block 16 to 4 for the
summing part. No rounding subtlety; the bias, shift and pack stay.

## L7. h2v2 fancy upsampling, vertical stage with `vpmaddubsw` (AVX2 file only, 16 to 10)

**File:** `simd/x86_64/jdsample-avx2.asm` 295-332 and 373-410. Level: AVX2.
Not valid for `jdsample-sse2.asm` 253-273 / 314-331.

**Original** (SSE2 file shown; xmm3 = 0):
```asm
    movdqa      xmm4, xmm0
    punpcklbw   xmm0, xmm3            ; xmm0 = row[ 0]( 0  1  2  3  4  5  6  7)
    punpckhbw   xmm4, xmm3            ; xmm4 = row[ 0]( 8  9 10 11 12 13 14 15)
    movdqa      xmm5, xmm1
    punpcklbw   xmm1, xmm3            ; xmm1 = row[-1]( 0  1  2  3  4  5  6  7)
    punpckhbw   xmm5, xmm3            ; xmm5 = row[-1]( 8  9 10 11 12 13 14 15)
    movdqa      xmm6, xmm2
    punpcklbw   xmm2, xmm3            ; xmm2 = row[+1]( 0  1  2  3  4  5  6  7)
    punpckhbw   xmm6, xmm3            ; xmm6 = row[+1]( 8  9 10 11 12 13 14 15)

    pmullw      xmm0, [rel PW_THREE]
    pmullw      xmm4, [rel PW_THREE]

    paddw       xmm1, xmm0           ; xmm1 = Int0L = ( 0  1  2  3  4  5  6  7)
    paddw       xmm5, xmm4           ; xmm5 = Int0H = ( 8  9 10 11 12 13 14 15)
    paddw       xmm2, xmm0           ; xmm2 = Int1L = ( 0  1  2  3  4  5  6  7)
    paddw       xmm6, xmm4           ; xmm6 = Int1H = ( 8  9 10 11 12 13 14 15)
```
Computes `Int0 = 3 row0 + row[-1]`, `Int1 = 3 row0 + row[+1]` as words (at
most 1020).

**Proposal:** interleave row[-1] (resp. row[+1]) with row0 by `punpck`,
then one `vpmaddubsw` with the byte weights (1, 3) per pair: unsigned pixel
bytes times signed weights, no saturation. 16 to 10. The horizontal stage
that follows (348-397) works on these 16-bit sums, so L1's byte trick does
not extend to it.

## L8. Rounding-shift folds with `vpmulhrsw` in the upsamplers (AVX2 file only, 3 to 2)

**File:** `simd/x86_64/jdsample-avx2.asm` 474-475/481-483, 545-546/552-554,
163-164/172-176. Level: AVX2.

For v in [0, 32767], `(v + 8) >> 4 == pmulhrsw(v, 2048)` and
`(v + 2) >> 2 == pmulhrsw(v, 8192)`. So `vpaddw x, [PW_EIGHT]; vpaddw x, y;
vpsrlw x, 4` becomes `vpaddw x, y; vpmulhrsw x, [PW_2048]` (3 to 2, twice
per row). The `+7 >> 4` and `+1 >> 2` variants are round-half-down; they
equal `-pmulhrsw(v, -2048)` / `-pmulhrsw(v, -8192)`, which needs a negate
unless the sign is absorbed downstream (the final `psllw 8; por` could
become `psllw 8; psubw`, keeping the count equal). L1 supersedes this for
h2v1.

---

## K1. GHASH SSE multiply and reduce, 35 to 20 (same ISA)

**File:** `lib/crypto/x86/ghash-pclmul.S` `__clmul_gf128mul_ble` lines
47-87. Level: SSE2 + PCLMULQDQ. Called once per 16-byte block by
`ghash_blocks_pclmul` and once by `polyval_mul_pclmul`. The AVX file
`polyval-pclmul-avx.S` computes the same function (`gf128hash.h` 51-64
dispatches `polyval_mul_x86` to either) in 15 instructions using two
`pclmulqdq` against a precomputed constant; the SSE routine never got that
form.

**Original** (ACC = xmm0, KEY = xmm1, T1 = xmm2, T2 = xmm3, T3 = xmm4):
```asm
	movaps ACC, T1
	pshufd $0b01001110, ACC, T2
	pshufd $0b01001110, KEY, T3
	pxor ACC, T2
	pxor KEY, T3
	pclmulqdq $0x00, KEY, ACC	# ACC = a0 * b0
	pclmulqdq $0x11, KEY, T1	# T1 = a1 * b1
	pclmulqdq $0x00, T3, T2		# T2 = (a1 + a0) * (b1 + b0)
	pxor ACC, T2
	pxor T1, T2			# T2 = a0 * b1 + a1 * b0
	movaps T2, T3
	pslldq $8, T3
	psrldq $8, T2
	pxor T3, ACC
	pxor T2, T1			# <T1:ACC> is result of carry-less multiplication
	# first phase of the reduction
	movaps ACC, T3
	psllq $1, T3
	pxor ACC, T3
	psllq $5, T3
	pxor ACC, T3
	psllq $57, T3
	movaps T3, T2
	pslldq $8, T2
	psrldq $8, T3
	pxor T2, ACC
	pxor T3, T1
	# second phase of the reduction
	movaps ACC, T2
	psrlq $5, T2
	pxor ACC, T2
	psrlq $1, T2
	pxor ACC, T2
	psrlq $1, T2
	pxor T2, T1
	pxor T1, ACC
```

**Computes** the 256-bit Karatsuba product P3:P2:P1:P0 of ACC and KEY, then
with f(q) = q<<57 ^ q<<62 ^ q<<63 and g(q) = q>>1 ^ q>>2 ^ q>>7 (per qword,
truncated):

    hi = P3 ^ P1 ^ f(P0) ^ g(P1 ^ f(P0))
    lo = P2 ^ P0 ^ f(P1) ^ g(P0)

Inputs xmm0, xmm1; output xmm0; xmm2-4 clobbered.

**Proposal**, two independent pieces:

(a) Multiply, Karatsuba 15 to schoolbook 13, same ISA, no constants:
```asm
	movaps ACC, T1
	movaps ACC, T2
	movaps ACC, T3
	pclmulqdq $0x00, KEY, ACC
	pclmulqdq $0x11, KEY, T1
	pclmulqdq $0x10, KEY, T2
	pclmulqdq $0x01, KEY, T3
	pxor T3, T2
	movaps T2, T3
	pslldq $8, T3
	psrldq $8, T2
	pxor T3, ACC
	pxor T2, T1
```

(b) Reduction 20 to 7, with GSTAR = {0xc200000000000000, 0xc200000000000000}
preloaded in a free register (xmm7 and up are free in this file):
```asm
	movaps ACC, T2
	pclmulqdq $0x00, GSTAR, T2
	pshufd $0x4e, T2, T2
	pxor ACC, T2
	pxor T2, T1
	pclmulqdq $0x11, GSTAR, T2
	pxor T2, T1
```
Result in T1 (add `movaps T1, ACC` if xmm0 must hold it). Algebra:
`clmul(P0, g*) = (g(P0) : f(P0))` since g* = x^63 + x^62 + x^57, so the
two-multiply form yields hi = P3 ^ P1 ^ f(P0) ^ g(P1 ^ f(P0)) and
lo = P2 ^ P0 ^ g(P0) ^ f(P1) ^ f(f(P0)), and f(f(P0)) = 0 because both shifts
are at least 57. Checked on 2000 random 128-bit pairs plus the edge cases
(0, all-ones, top bit only).

**Subtlety for proposers:** the shift-chain phases act on both qwords of ACC
(`psllq`/`psrlq` are per lane) and route the halves with `pslldq`/`psrldq`,
so the tempting "phase 1 is one `pclmulqdq` of ACC.lo" is not equivalent;
only the two-multiply Montgomery mapping is.

## K2. ARIA byte diffusion `aria_diff_m`, 9 to 6 (AVX / AVX2 / AVX-512)

**Files:** `arch/x86/crypto/aria-aesni-avx-asm_64.S` 361-374,
`aria-aesni-avx2-asm_64.S` 403-416, `aria-gfni-avx512-asm_64.S` 366-379.
Used 17 times per crypt body in the AVX/AVX2 files (4 per `aria_fe` /
`aria_fo`), 9 in the AVX-512 file.

**Original** (AVX):
```asm
	vpxor x0, x3, t0;
	vpxor x1, x0, t1;
	vpxor x2, x1, t2;
	vpxor x3, x2, t3;
	vpxor t2, x0, x0;
	vpxor x1, t3, t3;
	vpxor t0, x2, x2;
	vpxor t1, x3, x1;
	vmovdqu t3, x3;
```
Computes the all-but-one map: `x0' = x0^x1^x2`, `x1' = x0^x1^x3`,
`x2' = x0^x2^x3`, `x3' = x1^x2^x3`, in place. t0..t3 scratch, dead after.

**Proposal** (6, in place, no copy):
```asm
	vpxor x3, x0, t0;   /* t0 = x0^x3 */
	vpxor x2, x1, t1;   /* t1 = x1^x2 */
	vpxor t0, x1, x1;   /* x1' */
	vpxor t0, x2, x2;   /* x2' */
	vpxor t1, x0, x0;   /* x0' */
	vpxor t1, x3, x3;   /* x3' */
```
The kernel's own `aria_diff_word` (376-414) is the same map on 4x4 registers
and already uses this schedule. Compare x0..x3 only (t2/t3 differ).

## K3. Camellia byte-sliced rotate `rol32_1_16` / `rol32_1_32`, 16 to 12 (AVX / AVX2)

**Files:** `arch/x86/crypto/camellia-aesni-avx-asm_64.S` 269-290 (xmm),
`camellia-aesni-avx2-asm_64.S` 301-322 (ymm). Used twice per `fls16/fls32`,
which is used 7 times per file.

**Original:**
```asm
	vpcmpgtb v0, zero, t0;  vpaddb v0, v0, v0;  vpabsb t0, t0;
	vpcmpgtb v1, zero, t1;  vpaddb v1, v1, v1;  vpabsb t1, t1;
	vpcmpgtb v2, zero, t2;  vpaddb v2, v2, v2;  vpabsb t2, t2;
	vpor t0, v1, v1;
	vpcmpgtb v3, zero, t0;  vpaddb v3, v3, v3;  vpabsb t0, t0;
	vpor t1, v2, v2;  vpor t2, v3, v3;  vpor t0, v0, v0;
```
Computes a 32-bit rotate-left-by-1 on byte-sliced words: per lane,
`v_i' = (v_i << 1) | msb(v_{i-1})` with plane order v0, v1, v2, v3, v0.

**Proposal** (12): drop every `vpabsb` and replace each `vpor tK, v, v` by
`vpsubb tK, v, v`. After `vpaddb` the doubled byte has bit 0 clear, so
subtracting the 0xff/0x00 compare mask adds exactly the carry bit with no
ripple. Compare v0..v3 only (t0..t2 end as 0xff instead of 0x01).

## K4. Poly1305 scalar block, final times-5 carry step, 9 to 7 (baseline x86-64)

**File:** `lib/crypto/x86/poly1305-x86_64-cryptogams.pl` lines 213-223,
inside `poly1305_iteration` (emitted into `.Loop` of
`poly1305_blocks_x86_64`, once per 16-byte block, and three times via
`__poly1305_block` in `__poly1305_init_avx`). Same idiom at 1588-1596.
Cryptogams code by Andy Polyakov.

**Original** ($d3 = %rdi, $h0 = %r14, $h1 = %rbx, $h2 = %r10):
```asm
	mov	\$-4,%rax		# mask value
	adc	$h2,$d3
	and	$d3,%rax		# last reduction step
	mov	$d3,$h2
	shr	\$2,$d3
	and	\$3,$h2
	add	$d3,%rax
	add	%rax,$h0
	adc	\$0,$h1
	adc	\$0,$h2
```
Computes, with c = d3 after the `adc`: h2 = c & 3, and (h2:h1:h0) += 5 (c
>> 2) as a 130-bit add (rax = (c & ~3) + (c >> 2) = 4 (c>>2) + (c>>2)).

**Proposal** (7 after the shared `adc`):
```asm
	adc	$h2,$d3
	mov	$d3,$h2
	and	\$3,$h2
	shr	\$2,$d3
	lea	($d3,$d3,4),%rax
	add	%rax,$h0
	adc	\$0,$h1
	adc	\$0,$h2
```
Bit-exact including the mod 2^64 wrap (checked on 100k random c). Flags:
the original's `add $d3,%rax` flags are immediately overwritten by
`add %rax,$h0`, and `lea` writes none, so the final flag state is identical.

## K5. ChaCha AVX2, redundant `vmovdqa` in every shift-based rotate, 6 to 5 (AVX2)

**File:** `lib/crypto/x86/chacha-avx2-x86_64.S` 77-82, 90-95, 110-115,
123-128 (2-block) and 282-294, 306-318, 340-352, 364-376 (4-block). Four
(2-block) or eight (4-block) occurrences per double round, ten double rounds
per call: 40 / 80 removable instructions per call.

**Original:**
```asm
	vpaddd		%ymm3,%ymm2,%ymm2
	vpxor		%ymm2,%ymm1,%ymm1
	vmovdqa		%ymm1,%ymm6
	vpslld		$12,%ymm6,%ymm6
	vpsrld		$20,%ymm1,%ymm1
	vpor		%ymm6,%ymm1,%ymm1
```
**Proposal:** `vpslld $12,%ymm1,%ymm6` directly, dropping the copy. This is
the form the same file already uses in its 8-block function (613-615). Even
the scratch register ends with the same value, so the proof holds whether or
not ymm6 is treated as an output. The SSSE3 file's 4-instruction
`movdqa/pslld/psrld/por` has no shorter two-operand form.

## K6. AES-GCM AVX2 GHASH reduction, one redundant `vpshufd` (8 to 7, author-acknowledged)

**File:** `arch/x86/crypto/aes-gcm-vaes-avx2.S` `_ghash_reduce` 187-196,
used at 988 and inlined as steps 7-8 of `_ghash_step_4x` (374-390, the main
loop) and in `aes_gcm_aad_update`. The comment at
`aes-gcm-aesni-x86_64.S` 470-472 says one `pshufd` could be saved by
shuffling MI and XORing LO into it but that it seemed to slightly hurt
performance. gfpoly = `.octa 0xc2000000000000000000000000000001` (g in the
high qword).

```
Original:                                     Proposed:
	vpclmulqdq $0x01, \lo, \gfpoly, \t0            vpclmulqdq $0x01, \lo, \gfpoly, \t0   // P = LO_L*g
	vpshufd    $0x4e, \lo, \lo                     vpxor      \t0, \mi, \mi              // U
	vpxor      \lo, \mi, \mi                       vpshufd    $0x4e, \mi, \mi            // swap(U)
	vpxor      \t0, \mi, \mi                       vpxor      \lo, \mi, \mi              // W = swap(MI')
	vpclmulqdq $0x01, \mi, \gfpoly, \t0            vpclmulqdq $0x11, \mi, \gfpoly, \t0   // W_H*g
	vpshufd    $0x4e, \mi, \mi                     vpxor      \mi, \hi, \hi
	vpxor      \mi, \hi, \hi                       vpxor      \t0, \hi, \hi
	vpxor      \t0, \hi, \hi
```
Math: fold1 `MI' = MI ^ swap(LO) ^ P` with `P = clmul(LO_L, g)`; fold2
`HI' = HI ^ swap(MI') ^ clmul(MI'_L, g)`. With `U = MI ^ P` and
`W = swap(U) ^ LO`, `W = swap(MI')` and `MI'_L = W_H`, so the second multiply
selects the high qword via the immediate. `\hi` and `\mi` end identical;
`\lo` differs (swap(LO) vs LO) and is dead at every call site.

Same rewrite: `_ghash_mul` 137-162 (14 to 13, used 12 times), `_ghash_square`
200-210 (9 to 8), and the `USE_AVX=1` instantiation of `_ghash_reduce` /
`_ghash_update_end_8x_step` in `aes-gcm-aesni-x86_64.S` 354-373 and 473-488
(10 to 9; there gfpoly is a `movq` so g is the low qword and the immediate
is `$0x01`). In the SSE build the two-operand `pclmulqdq` forces copies and
the rewrite is longer; the AVX-512 forms already fuse the xors into
`vpternlogd` and are count-neutral.

## K7. SHA-256 SSSE3 message schedule sigmas (SSE2 ops; 13 to 11 and 9 to 8)

**File:** `lib/crypto/x86/sha256-ssse3-asm.S`. Level: SSSE3. The AVX and
AVX2 files' three-operand forms (9 and 7) do not benefit; the SSE saving is
entirely in `movdqa` copies.

**sigma0**, vector instructions of `FOUR_ROUNDS_AND_SCHED` in program order,
lines 171-219 (XTMP1 = W[-15] from the `palignr` at 167):
```asm
	movdqa  XTMP1, XTMP2            # XTMP2 = W[-15]
	movdqa  XTMP1, XTMP3            # XTMP3 = W[-15]
	pslld   $(32-7), XTMP1
	psrld   $7, XTMP2
	por     XTMP2, XTMP1            # XTMP1 = W[-15] ror 7
	movdqa  XTMP3, XTMP2            # XTMP2 = W[-15]
	movdqa  XTMP3, XTMP4            # XTMP4 = W[-15]
	pslld   $(32-18), XTMP3
	psrld   $18, XTMP2
	pxor    XTMP3, XTMP1
	psrld   $3, XTMP4               # XTMP4 = W[-15] >> 3
	pxor    XTMP2, XTMP1            # ror 7 ^ ror 18
	pxor    XTMP4, XTMP1            # XTMP1 = s0
```
Computes sigma0(x) = ror7(x) ^ ror18(x) ^ (x >> 3) per lane. Proposal (11),
the nested-shift form `sha512-ssse3-asm.S` 174-246 already uses:
```asm
	movdqa  XTMP1, XTMP2
	psrld   $11, XTMP2
	pxor    XTMP1, XTMP2
	psrld   $4, XTMP2
	pxor    XTMP1, XTMP2
	psrld   $3, XTMP2               # x>>3 ^ x>>7 ^ x>>18
	movdqa  XTMP1, XTMP3
	pslld   $11, XTMP3
	pxor    XTMP1, XTMP3
	pslld   $14, XTMP3              # x<<14 ^ x<<25
	pxor    XTMP3, XTMP2            # s0 (now in XTMP2)
```

**sigma1** pair, lines 224-260 (and 268-301):
```asm
	pshufd  $0b11111010, X3, XTMP2   # XTMP2 = W[-2] {BBAA}
	movdqa  XTMP2, XTMP3
	movdqa  XTMP2, XTMP4
	psrlq   $17, XTMP2              # XTMP2 = W[-2] ror 17 {xBxA}
	psrlq   $19, XTMP3              # XTMP3 = W[-2] ror 19 {xBxA}
	psrld   $10, XTMP4              # XTMP4 = W[-2] >> 10 {BBAA}
	pxor    XTMP3, XTMP2
	pxor    XTMP2, XTMP4            # XTMP4 = s1 {xBxA}
	pshufb  SHUF_00BA, XTMP4        # XTMP4 = s1 {00BA}
```
Proposal (8):
```asm
	pshufd  $0b11111010, X3, XTMP2
	movdqa  XTMP2, XTMP3
	psrlq   $2, XTMP3               # lo dword: A ror 2 ; hi dword: A >> 2
	pxor    XTMP2, XTMP3            # lo: A ^ ror2(A) ; hi: A ^ (A>>2)
	psrlq   $17, XTMP3              # lo: ror17(A ^ ror2 A) = ror17(A) ^ ror19(A)
	psrld   $10, XTMP2              # lo: A >> 10
	pxor    XTMP3, XTMP2
	pshufb  SHUF_00BA, XTMP2
```
The second `psrlq $17` pulls in only the low 17 bits of the high dword, and
bits 0..16 of `A ^ (A >> 2)` equal bits 0..16 of `A ^ ror2(A)` because
16 + 2 < 32. This bound is exactly what the symbolic proof checks; it would
fail if the outer shift exceeded 30. `SHUF_00BA` selects the low dwords, so
the garbage in the high dwords is discarded.

## K8. Byte-granular rotates as `pshufb`: SHA-512 sigma0 and SM3 P1 (9 to 7)

**SHA-512 sigma0**, `lib/crypto/x86/sha512-avx2-asm.S` 175-179 and 221-226
(16 times per block), `sha512-avx-asm.S` (32 times), `sha512-ssse3-asm.S`.
Level AVX2 / AVX / SSSE3; `pshufb` is within level in all three.
```asm
	vpsrlq		$1, YTMP1, YTMP2
	vpsllq		$(64-1), YTMP1, YTMP3
	vpor		YTMP2, YTMP3, YTMP3		# YTMP3 = W[-15] ror 1
	vpsrlq		$7, YTMP1, YTMP4		# YTMP4 = W[-15] >> 7
	vpsrlq		$8, YTMP1, YTMP2
	vpsllq		$(64-8), YTMP1, YTMP1
	vpor		YTMP2, YTMP1, YTMP1		# YTMP1 = W[-15] ror 8
	vpxor		YTMP4, YTMP3, YTMP3		# YTMP3 = W[-15] ror 1 ^ W[-15] >> 7
	vpxor		YTMP1, YTMP3, YTMP1		# YTMP1 = s0
```
Computes sigma0(x) = ror1(x) ^ ror8(x) ^ (x >> 7) on 64-bit lanes. The
`ror 8` is a byte permutation within each qword: `vpshufb ROR8Q(%rip),
YTMP1, YTMP1` with ROR8Q = bytes 1,2,3,4,5,6,7,0, 9,...,15,8 per 128-bit lane
replaces three instructions. 9 to 7 in AVX/AVX2; SSE 11 to 10. Needs one new
16/32-byte constant. Only sigma0 of SHA-512 has a multiple-of-8 rotate.

**SM3 P1**, `lib/crypto/x86/sm3-avx-asm_64.S` `SCHED_W_1` 296-304 (18 times
per block). Level AVX.
```asm
	vpslld $15, XTMP0, XTMP5;
	vpsrld $(32-15), XTMP0, XTMP6;
	vpslld $23, XTMP0, XTMP2;
	vpsrld $(32-23), XTMP0, XTMP3;
	vpxor XTMP0, XTMP1, XTMP1;
	vpxor XTMP6, XTMP5, XTMP5;
	vpxor XTMP3, XTMP2, XTMP2;
	vpxor XTMP2, XTMP5, XTMP5;
	vpxor XTMP5, XTMP1, w0;
```
Computes w0 = XTMP1 ^ P1(XTMP0), P1(X) = X ^ rol15(X) ^ rol23(X). Since
rol15 ^ rol23 = rol15(X ^ rol8(X)):
```asm
	vpshufb ROL8D, XTMP0, XTMP2      # ROL8D = bytes 3,0,1,2, 7,4,5,6, 11,8,9,10, 15,12,13,14
	                                 # (PSHUFB indexes the whole register; a mask written with
	                                 # per-dword indices 3,0,1,2 x4 was refuted by Z3)
	vpxor XTMP0, XTMP2, XTMP2
	vpslld $15, XTMP2, XTMP5
	vpsrld $17, XTMP2, XTMP2
	vpxor XTMP5, XTMP2, XTMP2
	vpxor XTMP0, XTMP1, XTMP1
	vpxor XTMP2, XTMP1, w0
```
9 to 7, one constant in a free register (xmm13/xmm14 are unused).

## K9. SHA-2 scalar Maj with the (a^b) carried between rounds (24 to 18 per four rounds)

**Files:** every scalar SHA-2 round macro: `sha256-ssse3-asm.S` 176-187 and
`DO_ROUND` 336-344, `sha256-avx-asm.S`, `sha256-avx2-asm.S`
`FOUR_ROUNDS_AND_SCHED` 156-189 and `DO_4ROUNDS` 371-386, `sha512-avx2-asm.S`
181-208 and 418-432, `sha512-ssse3/avx-asm.S` `SHA512_Round` 128-136. 64 or
80 rounds per block. Level: baseline GPR ops in all files.

**Original** (`sha256-avx2-asm.S` 371-386, Maj lines):
```asm
	mov	a, y3		# y3 = a                                # MAJA
	or	c, y3		# y3 = a|c                              # MAJA
	mov	a, T1		# T1 = a                                # MAJB
	and	b, y3		# y3 = (a|c)&b                          # MAJA
	and	c, T1		# T1 = a&c                              # MAJB
	or	T1, y3		# y3 = MAJ = (a|c)&b)|(a&c)             # MAJ
```
**Proposal:** Maj = b ^ ((a^b) & (b^c)), and because `ROTATE_ARGS` maps a to
b and b to c, this round's (a^b) is the next round's (b^c). Per round
`mov a,Y; xor b,Y; and Y,X; xor b,X` (4), with an extra `mov b,X; xor c,X`
in the first round of each macro: 18 vs 24 per four rounds, about 96 fewer
per SHA-256 block. This is the OpenSSL `sha512-x86_64.pl` trick. Caveat:
register pressure (the AVX2 file uses every GPR but the frame pointer). The
proof is over a..h plus the four WK words in, a..h out, which is straight
line within the macro.

## K10. AES key expansion helpers (`aes-aesni.S`)

**File:** `lib/crypto/x86/aes-aesni.S` `_prefix_sum` 37-44 and
`_gen_round_key` 59-61; 10 (AES-128) or 13 (AES-256) times per key schedule.
Level: SSE2 + AES-NI.

```asm
	movdqa		\a, \tmp	// [a0, a1, a2, a3]
	pslldq		$4, \a		// [0, a0, a1, a2]
	pxor		\tmp, \a	// [a0, a0^a1, a1^a2, a2^a3]
	movdqa		\a, \tmp
	pslldq		$8, \a		// [0, 0, a0, a0^a1]
	pxor		\tmp, \a	// [a0, a0^a1, a0^a1^a2, a0^a1^a2^a3]
```
and
```asm
	movdqa		\b, %xmm2
	pshufb		MASK, %xmm2      // MASK = .Lmask = 13,14,15,12 x4
	aesenclast	RCON, %xmm2
```
Proposals: (a) the file's own comment at 33-36: `shufps $0x10,\a,\tmp; pxor
\tmp,\a; shufps $0x8c,\a,\tmp; pxor \tmp,\a`, 6 to 4, **conditional on \tmp
== 0 at entry** (5 unconditionally with a `pxor \tmp,\tmp`); `shufps` is an
SSE1 shuffle, so within level. (b) `aeskeygenassist $rcon, \b, %xmm2; pshufd
$0xff, %xmm2, %xmm2`, 3 to 2, valid per unrolled iteration because rcon must
be an immediate. Refutation target: (a) without the zero-temp precondition.

## K11. Camellia and ARIA round-key byte broadcasts

**Camellia AVX2** `camellia-aesni-avx2-asm_64.S` `roundsm32` 148-158,
166-170, 177-179, 196-198: `vpbroadcastq key, t0` + 7 `vpsrldq` + 8 `vpshufb`
= 16 to broadcast the eight key bytes; `vpbroadcastb k(%r9), tK` x8 = 8 at
the file's own level. `fls32` 338-346 etc.: `vpbroadcastd` + 3 `vpsrldq` + 4
`vpshufb` = 8 to 4.

**Camellia AVX** `camellia-aesni-avx-asm_64.S` `roundsm16` 112-130, 165-167
(every round): 17 (1 zero, 1 `vmovq`, 7 `vpsrldq`, 8 `vpshufb`) to 9 with
`vmovq key, t0` + 8 `vpshufb` against eight 16-byte constants 0xkk x16
(AVX level; `vpbroadcastb` is AVX2 and not allowed here). `fls16` 306-314
etc.: 8 to 5.

**ARIA AVX** `aria-aesni-avx-asm_64.S` `aria_ark_8way` 268-296 (17 times per
crypt): 24 to 18 with two `vbroadcastss` + six masked `vpshufb` + two
`vpshufb` by zero + eight `vpxor`. The AVX2 file already uses 8 `vpbroadcastb`
+ 8 `vpxor` = 16.

Pure data-movement identities. Constants must be preloaded.

## K12. Small same-ISA wins in `arch/x86/crypto`

- **Serpent SSE2 `transpose_4x4`** `serpent-sse2-x86_64-asm_64.S` 575-588,
  13 to 12 (8 `punpck` + 4 `movdqa` instead of 5), used 4 times per call:
  `movdqa x2,t1; punpckldq x3,x2; punpckhdq x3,t1; movdqa x0,x3; punpckhdq
  x1,x3; punpckldq x1,x0; movdqa x0,x1; punpcklqdq x2,x0; punpckhqdq x2,x1;
  movdqa x3,x2; punpcklqdq t1,x2; punpckhqdq t1,x3`.
- **AEGIS128 `encrypt_block`** `aegis128-aesni-asm.S` 285-300 and 397-402:
  `out = MSG ^ s1 ^ s4 ^ (s2 & s3)` preserving MSG, 6 ALU ops to 5 by
  accumulating into the `s2 & s3` temporary (`movdqa \s2,T1; pand \s3,T1;
  pxor \s1,T1; pxor \s4,T1; pxor MSG,T1`), which is how the file's own
  `decrypt_block` (419-433) does it.
- **GCM precompute H times x** `aes-gcm-aesni-x86_64.S` 524-531: `movdqa
  H_POW1,%xmm0; pshufd $0xd3,%xmm0,%xmm0` is `pshufd $0xd3,H_POW1,%xmm0`,
  7 to 6, once per key setup; the AVX2 file (261-265) already does this.

## G1-G4. General-purpose register sequences in `arch/x86/lib`

These are weaker paper material: G1 and G4 are inline asm plus compiler
output rather than hand-written, and G3 is in a fallback path. They are
cheap to prove and G1 has a good refutation.

**G1. `csum_fold`**, `arch/x86/include/asm/checksum_64.h` 25-33, inlined
into `ip_compute_csum`, `csum_tcpudp_magic`, `csum_ipv6_magic`. Compiled
form:
```asm
mov    %eax,%edx
xor    %ax,%ax            # eax &= 0xffff0000
shl    $0x10,%edx         # edx = sum << 16
add    %edx,%eax
adc    $0xffff,%eax
not    %eax
shr    $0x10,%eax
```
Computes `~(hi16 + lo16 + carry) & 0xffff`, zero-extended. Proposal (5):
`mov %eax,%edx; shr $16,%eax; add %dx,%ax; adc $0,%eax; xor $0xffff,%eax`.
The kernel's `ip_fast_csum` (65-69) already has this shape but with `notl`,
which is only correct for the low half. Refutation: folding first and
inverting the input (`not; mov; shr $16; add %dx,%ax; adc $0`) differs at
sum = 0x0000ffff and 0xffff0000 (0x0000 vs 0xffff), both "zero" in ones'
complement but distinguished by the UDP zero-checksum rule.

**G2. `copy_mc_fragile` leading-byte count**, `arch/x86/lib/copy_mc_64.S`
31-35: `movl %esi,%ecx; andl $7,%ecx; subl $8,%ecx; negl %ecx; subl
%ecx,%edx` computes ecx = 8 - (esi & 7), edx -= ecx. Proposal (4,
unconditional, same final flags): `leal 8(%rsi),%ecx; andl $-8,%ecx; subl
%esi,%ecx; subl %ecx,%edx`. A 4-instruction `movl; negl; andl $7; subl`
variant is equal only under the guard `esi & 7 != 0` that precedes it, and is
a refutation target without it (gives 0 instead of 8 on aligned input).

**G3. `memset_orig` re-alignment**, `arch/x86/lib/memset_64.S` 113-116:
`movq $8,%r8; subq %r9,%r8; addq %r8,%rdi; subq %r8,%rdx` with r9 = rdi & 7;
proposal (3): `leaq -8(%rdx,%r9),%rdx; addq $8,%rdi; subq %r9,%rdi`. r8 is
dead. This path only runs on CPUs without FSRS.

**G4. `csum_partial` trailing-bytes mask**, `arch/x86/lib/csum-partial_64.c`
100-110, compiled: `neg %ecx; shl $3,%ecx; and $0x3f,%ecx; shl %cl,%rax; shr
%cl,%rax`. The `and $0x3f` is redundant because the hardware masks a 64-bit
shift count to 6 bits (SDM). A direct test of the model's count masking.

---

# Refutation targets

Proposals an LLM will plausibly make that are not bit-exact. Each pairs
with a candidate above; a SAT result with a concrete counterexample is
evidence in its own right.

| Pairs with | Proposal | Why it fails |
|---|---|---|
| L1 | `pavgb(pavgb(s,p), s)` for `(3s+p+1)>>2` | 32768 of 65536 pairs differ |
| L3 | `packuswb` instead of `packsswb` before the byte compare | -32768 saturates to 0 |
| L5 | `pmulhrsw` constant 29032 (or 13171) | off by one on a few Cb values; 29033 works |
| L5 | L5 over unconstrained int16 lanes | `paddw x,x` wraps |
| L5 | G path as two `pmulhrsw` | double rounding, 16063 pairs differ |
| L6/L7 | h2v2 box `(a+b+c+d+2)>>2` as nested `pavgb` | rounding |
| jquanti | `psignw` for the sign restore with symbolic divisors | differs when the coefficient is 0 |
| jfdctfst | dropping the `psllw 2` pre-shift before `pmulhw` | constant does not fit, and 16-bit wrap |
| K1 | phase 1 as a single `pclmulqdq` of ACC.lo | shift chain acts on both qwords |
| K7 | `psrlq $10` for the `>> 10` in the {BBAA} trick | gives a rotate, not a shift |
| K10 | `shufps` prefix sum without `\tmp == 0` | garbage lanes |
| Poly1305 AVX2 | `vpmuludq` by 5 for the h4-to-h0 carry without `D4 < 2^32` | low-32-bit multiply |
| Poly1305 AVX2 | reordered carry chain | congruent mod 2^130-5, not bit-equal |
| Poly1305 scalar | dropping the final `adc $0,$h2` | carry out of h1 is possible |
| XTS `_next_tweakvec` | `vpmuludq` instead of `vpclmulqdq` for k >= 2 | integer vs carry-less product (equal for k = 1: a prove/refute pair) |
| XTS `_next_tweak` | dropping the lane swap before `vpmuludq` | wrong on about half the inputs |
| SM4 AVX2 counter | the no-carry `vpsubq [0:-2]` fast path without its guard | fails within 16 of 2^64 |
| NH | `pmuludq k, psrlq $32(k)` for the `pshufd $0x10/$0x32` pair | multiplies the wrong lanes |
| G1 | fold-then-invert `csum_fold` | 0x0000 vs 0xffff |
| G2 | `movl; negl; andl $7` without the alignment guard | 0 vs 8 |
| hweight | 4-instruction step 2 (`mov; shr $2; add; and`) | 2-bit fields overflow (input 0xf gives 0) |
| memset | `imulq %rsi` without `movzbl %sil` | high bits of the `int c` argument |
| `shld $k,r,r` vs `rol $k,r` | register-equal | flags differ (SF/ZF/PF) |

# Search targets (no proposal in hand)

**Serpent bit-sliced S-boxes**, `serpent-sse2-x86_64-asm_64.S` 41-371,
`serpent-avx-x86_64-asm_64.S` 52-366, `serpent-avx2-asm_64.S` 51-365. Osvik's
2000 circuits verbatim; each is 16-19 logic ops (SSE2 adds one `movdqa`),
instantiated 8 times per direction per file:

| box | logic | NOTs | box | logic | NOTs |
|---|---|---|---|---|---|
| S0 | 16 | 2 | SI0 | 16 | 1 |
| S1 | 17 | 2 | SI1 | 16 | 1 |
| S2 | 16 | 2 | SI2 | 16 | 1 |
| S3 | 18 | 0 | SI3 | 17 | 0 |
| S4 | 16 | 1 | SI4 | 17 | 1 |
| S5 | 16 | 1 | SI5 | 19 | 1 |
| S6 | 16 | 1 | SI6 | 16 | 1 |
| S7 | 18 | 2 | SI7 | 18 | 1 |

`pandn` absorbs a NOT before an AND for free, and S3, S7, SI5, SI7 at 18-19
ops are the likeliest to admit shorter circuits. This is a SAT/exhaustive
search problem rather than an LLM proposal, but Z3 decides each candidate
instantly (pure boolean), and a found circuit applies to all three files.
Proof details: compare only the four live outputs in the right permutation,
constrain RNOT = all ones, let the dead fifth register differ.

# Excluded by the ISA rule

- `pabsw`/`psignw` in `jquanti-sse2.asm` (SSSE3; `jquanti-avx2.asm` already
  uses them). This is the existing ABS16 proof.
- AVX three-operand forms to remove `movdqa` copies in any `-sse2.asm` file
  (about 26 sites in the DCT/IDCT and color files).
- `pmovsxwd`, `pblendw` (SSE4.1) in `jidctint-sse2.asm` / `jidctred-sse2.asm`.
- `rorx` (BMI2) for the `mov/ror/xor` Sigma chains and SHA-1 `mov/rol/add` in
  the SSSE3 and AVX SHA files; the AVX2 files already use it.
- `pinsrd` (SSE4.1) for the BLAKE2s SSSE3 message gather.
- `vpbroadcastb` (AVX2) in the Camellia/ARIA AVX files (K11 gives the AVX
  form instead).
- `vprold` (AVX-512) for the Serpent linear transform and ChaCha rotates;
  `vpternlogd`; GFNI for the nibble-LUT `filter_8bit`.

# Rejected after inspection

**libjpeg-turbo:** the h2v2 fancy horizontal stage (16-bit inputs, no byte
trick); Y computation in jccolext/jcgryext (three products, one rounding);
IDCT/FDCT descale sequences; the range-limit `psraw/packsswb/paddb`; the
8x8 transposes (AVX2 ones are at the known minimum for their lane layout);
zero-column broadcast paths; shifted prev/next vector construction in
jdsample (unaligned loads would read before the row); even/odd byte split and
re-interleave; jchuff `EMIT_QWORD` and the `tzcnt` loop (branchy); the
alternating 0/1 bias in jcsample (defeats `pavgb`); 3-byte RGB
interleave/deinterleave via `pshufb` (a plausible 35-to-24 rewrite in
`jdcolext-sse2.asm` 214-274 and 31-to-24 in `jccolext-sse2.asm` 148-208 but
`pshufb` is SSSE3, so only the AVX2 files qualify, and the mask sets are at
the top of the size budget).

**Kernel crypto:** ChaCha/BLAKE2s SSSE3 shift rotates (4 is minimal
two-operand) and diagonalization; ChaCha SSSE3 4-block and AVX2 8-block
bodies (state lives on the stack mid-sequence); SHA-1 `W_PRECALC` and
`F1`/`F3`; SHA-2 vector sigmas in three-operand form; SM3 GG2/FF2/P0; NH
`pmuludq` chains; Poly1305 AVX2 multiply block and input splat; polyval
`schoolbook2`/`montgomery_reduction` (already the K1 target form); CRC
`_fold_vec` and the partial-block shuffle (data-indexed); crc32c-3way combine;
SHA-NI round bodies (minimal, useful only as SHA-NI model tests); the GPR
table-lookup ciphers (blowfish, twofish, camellia-x86_64, cast5/6 lookups);
`byteslice_16x16b` (store/reload mid-sequence); Camellia P-function (16 XOR)
and ARIA `aria_diff_word` (24 XOR, already the K2 schedule); `filter_8bit`
(6 is minimal without GFNI); XTS `_next_tweak` (several 5-op equivalents,
none shorter at AVX2); `inc_le128` (4, no 3-op form found); AVX-512 files
(already fused).

**arch/x86/lib:** `getuser`/`mask_user_address`/`array_index_mask_nospec`
(2-3, minimal); `adc` chains in `csum-copy_64.S`; hweight (the `imul`+`shr`
finish already beats the add chain; no 4-op step 2); memcpy/memmove/
copy_user/clear_page (memory-bound); `cmpxchg16b_emu` (branchy RMW);
`retpoline`/`bhi` entry stubs.

# Harness notes

- Constants: preload into registers with `write_xmm` as in
  `hardmix_tests.sail`; `[rel PW_*]` operands become register operands in
  both original and proposal.
- Preconditions: for L2, L5, L6 and L7 either include the byte-widening
  `punpcklbw` in the proved sequence or assert the lane range on the inputs.
  For K10(a), Poly1305 AVX2, G2 and the SM4 counter path, state the
  precondition and also run the unconditional query for the refutation.
- Outputs: compare only the live registers (K1: xmm0; K2: x0..x3; K3:
  v0..v3; K6: hi and mi; L1: the two output vectors). Where the proposal
  renames the output register, rename the following stores.
- Flags: K4, G1, G2 and G3 have flag-dead continuations; K4's proposal
  matches flags anyway. K9's Maj chain and the `shld`/`rol` lemma are the
  places where a flag-inclusive proof would refute a register-equal
  proposal.
- Level per test: emit the `.arch` line from the table above into the
  assembler input of the proposal, and run the model with the matching
  `enable_features_v*` preset.
