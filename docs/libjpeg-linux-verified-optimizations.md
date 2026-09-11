# Verified Rewrites of Hand-Written Assembly in libjpeg-turbo and Linux

Results of running the candidates in
[libjpeg-linux-optimization-candidates.md](libjpeg-linux-optimization-candidates.md)
through the equivalence-proof pipeline, 2026-09-10.  Trees: libjpeg-turbo
d9b5af99, Linux 50d05c7c76c9 (7.3-rc3).  Driver: `verify/prove_candidates.py`;
applied changes: `docs/linux-verified-rewrites.patch` (18 files, +168/-216)
and `docs/libjpeg-turbo-verified-rewrites.patch` (10 files, +150/-224), both
also present as uncommitted changes in `~/linux` and `~/libjpeg-turbo`.

## Summary

| | proved | of which already known and declined by the authors | refuted | undecided |
|---|---|---|---|---|
| libjpeg-turbo | 7 rewrites (+2 exact-instance proofs) | 0 | 5 | 0 |
| Linux `arch/x86/crypto` | 8 rewrites (+3 instances) | 1 | 1 | 0 |
| Linux `lib/crypto/x86` | 11 rewrites (+12 instances) | 2 | 3 | 0 |
| Linux `arch/x86/lib` | 4 rewrites | 0 | 2 | 0 |
| **total** | **30 rewrites, 17 further instances** | **3** | **11** | **0** |

"Proved" is a Z3 (or Bitwuzla) UNSAT on the unsimplified Isla traces of the
two sequences over fully symbolic register inputs; "refuted" is a SAT with a
concrete distinguishing input.  Every proposal was assembled under the ISA
level of the file it came from (GAS `.arch`, see the candidates document), so
no proof involves an instruction the original file avoids.  Where an
identity holds only for values that came from bytes, the proved sequence
starts at the byte widening; no SMT-side range assumptions were used.

Three proved rewrites are not optimizations the authors missed: the file's
own comments describe the shorter form and give the reason for not using
it (AES `_prefix_sum`, AES `aeskeygenassist`, AES-GCM `pshufd`).  They are
kept in the tables as proofs but must not be counted or applied; a rewrite
that contradicts a documented author decision is out of scope regardless
of its proof.  Of the remaining 27, 24 were applied: the XTS tweak form
has equal count, the SHA-256 rounds need a register the kernel reserves,
and the shift mask lives in C.  The GHASH multiply half was the last to
be decided (Bitwuzla, 1 h 56 min, after the final run) and was applied
after that; the routine is now 34 → 21 instructions.

libjpeg-turbo builds and passes its full test suite, 664 of 664
tests, with the rewrites in.  The kernel files all assemble with the
kernel's own include paths and configuration, and a user-space differential
test (`verify/kernel-difftest/`) runs every patched routine, original
against rewritten, on the same random inputs on this machine (a Zen 4 with
AVX-512, GFNI, VAES, VPCLMULQDQ): 96,000 comparisons, no differences.

## Pipeline

1. Assemble original and proposal with `as` under the file's `.arch` gate;
   `objdump --insn-width=15` gives the bytes.
2. Emit a Sail test function per side: `enable_features_all()`, constants
   into registers (or into the 256-byte symbolic memory window at 0x7000
   for memory operands), then `setup_and_exec` per instruction, returning
   the concatenation of the live output registers (and `read_rflags()`
   where flags matter).
3. Compile model + tests to Isla IR once per run (20 to 40 minutes),
   symbolic execution per function (about 10 seconds each), one SMT query
   per pair unifying the symbolic *input* registers of the two traces.
4. Z3 with a timeout; on timeout, Bitwuzla.

## Results by site

Instruction counts are for the sequence as proved; where the proved
sequence includes a shared byte-widening prefix the site's own count is
given in the candidates document.  Times are Z3 wall-clock on the final
runs (batch 4 for the main candidates, batch 5 for the applied instances).

### libjpeg-turbo

| site | level | before → after | verdict | time |
|---|---|---|---|---|
| h2v1 fancy upsampling, `jdsample-sse2.asm` | SSE2 | 27 → 13 | proved | 26.7 s |
| same, nested `pavgb` proposal | SSE2 | | refuted | 14.5 s |
| RGB→YCbCr Cb finish, `jccolext-sse2.asm` (from the byte widening) | SSE2 | 14 → 7 | proved | 9.5 s |
| same, Cr finish (exact instance) | SSE2 | 14 → 7 | proved | 8.5 s |
| same, over unconstrained lanes | SSE2 | | refuted | 6.1 s |
| Huffman zero test `REDUCE0`, `jcphuff-sse2.asm` | SSE2 | 12 → 8 | proved | 1.1 s |
| same with `packuswb` | SSE2 | | refuted | 46.4 s |
| Huffman zero test pair, `jchuff-sse2.asm` (exact instance) | SSE2 | 5 → 3 | proved | 0.4 s |
| YCbCr→RGB G path, `jdcolext-avx2.asm` (from the byte split) | AVX2 | 20 → 18 | proved | 296 s |
| YCbCr→RGB chroma multiply, `jdcolext-avx2.asm` (from the byte split) | AVX2 | 22 → 8 | proved | 94.8 s |
| same with constant 29032 | AVX2 | | refuted | 340 s |
| same over unconstrained lanes | AVX2 | | refuted | 47.0 s |
| h2v1 downsampling, `jcsample-avx2.asm` | AVX2 | 12 → 8 | proved | 0.8 s |
| h2v2 vertical stage, `jdsample-avx2.asm` | AVX2 | 18 → 12 | proved | 0.6 s |

### Linux `arch/x86/crypto`

| site | level | before → after | verdict | time |
|---|---|---|---|---|
| ARIA `aria_diff_m` (xmm; ymm and zmm instances also proved) | AVX / AVX2 / AVX-512 | 9 → 6 | proved | 0.3 s |
| Camellia `rol32_1_16` (`rol32_1_32` ymm instance also proved) | AVX / AVX2 | 16 → 12 | proved | 0.7 s |
| Camellia AVX2 round-key byte broadcasts (loads from the memory window) | AVX2 | 17 → 8 | proved | 0.7 s |
| Serpent SSE2 `transpose_4x4` | SSE2 | 13 → 12 | proved | 0.2 s |
| AEGIS128 `encrypt_block` | SSE2 | 6 → 5 | proved | 0.1 s |
| AES-GCM precompute H·x | SSE2 | 6 → 5 | proved | 0.1 s |
| AES-GCM `_ghash_reduce`, one `pshufd` saved, 128-bit form | AVX+PCLMUL | 8 → 7 | proved, not applied | 0.6 s |
| XTS `_next_tweak` via `vpmuludq` | AVX | 5 = 5 | proved (equal count) | 0.3 s |
| same without the lane swap | AVX | | refuted | 1.1 s |

### Linux `lib/crypto/x86`

| site | level | before → after | verdict | time |
|---|---|---|---|---|
| GHASH reduction, shift chain → two `pclmulqdq` (register and memory-operand forms) | SSE2+PCLMUL | 19 → 8 | proved | 0.4 s |
| GHASH multiply, Karatsuba → schoolbook | SSE2+PCLMUL | 15 → 13 | proved by Bitwuzla in 6968 s (1 h 56 min); Z3 >1 h, cvc5 >1 h | see text |
| GHASH routine as one query | SSE2+PCLMUL | 34 → 21 | not attempted beyond Z3 (>1 h); both halves are proved separately | |
| Poly1305 ×5 step, both sites | x86-64 | 10 → 8 | proved, flags included | 0.5 s |
| ChaCha AVX2 rotate copies, all six register layouts | AVX2 | 6 → 5 | proved | 0.1 to 0.4 s |
| SHA-256 SSSE3 sigma0 | SSSE3 | 13 → 11 | proved | 0.2 s |
| SHA-256 SSSE3 sigma1, low and high blocks | SSSE3 | 9 → 8 | proved | 0.1 to 0.7 s |
| SHA-256 AVX2 four rounds with carried Maj | AVX2+BMI2 | 108 → 102 | proved by Bitwuzla in 4 s after Z3 timed out (30 min); cvc5 4.6 s | not applied |
| SHA-512 AVX2 sigma0 `ror 8` as `vpshufb` (register and memory mask) | AVX2 | 9 → 7 | proved | 0.3 s |
| SM3 P1 byte rotate | AVX | 9 → 7 | proved | 0.6 s |
| same with a per-dword `pshufb` mask (my transcription error) | AVX | | refuted | 3.8 s |
| AES `_prefix_sum` via `shufps` (with tmp = 0; with its own `pxor`) | SSSE3+AES | 6 → 4 (6 → 5) | proved; author-declined, not applied | 0.6 s |
| same without the zero precondition | | | refuted | 1.0 s |
| AES round-key head via `aeskeygenassist` | SSSE3+AES | 3 → 2 | proved; author-declined, not applied | 5.6 s |

### Linux `arch/x86/lib`

| site | level | before → after | verdict | time |
|---|---|---|---|---|
| `csum_fold` (compiled form of the inline asm) | x86-64 | 7 → 5 | proved | 0.3 s |
| same, fold then invert | | | refuted | 2.1 s |
| `copy_mc_fragile` leading-byte count | x86-64 | 5 → 4 | proved, flags included | 0.5 s |
| same without the alignment guard | | | refuted | 0.7 s |
| `memset_orig` re-alignment | x86-64 | 4 → 3 | proved | 0.2 s |
| `csum_partial` shift-count mask | x86-64 | 5 → 4 | proved | 0.6 s |

## Not applied

- **AES `_prefix_sum` via `shufps`**: the comment above the macro says the
  four-instruction shufps form was known and rejected for readability and
  because the copies are free.  It was applied by mistake at first and
  reverted; a proof does not override a documented decision.
- **AES `aeskeygenassist`**: same situation; the comment lists three reasons
  for not using the instruction (microcoded on Intel, needs an immediate,
  little gain).
- **AES-GCM `pshufd` saving**: the comment says the saving was tried and
  seemed to slightly hurt performance.  Also, the 256-bit `vpclmulqdq` the
  AVX2 file uses is not implemented in the model (VEX.256 raises #UD), and
  in the AES-NI file the macro is shared with the two-operand SSE build.
- **SHA-256 AVX2 carried Maj**: proved, but the rewrite needs one more live
  register and the only free one is the frame pointer, which the kernel
  preserves (see the 2017 rbp fix in that file).
- **`csum_partial` shift mask**: proved at the instruction level, but the
  `& 63` is in C and removing it would make the C shift undefined.

## Findings about the tools

- **Isla's trace simplifier is unsound on this model.**  With `-s`, the
  extract of the 9-bit sum in `avg` (PAVGB) was distributed over the
  addition, dropping the carry, and the h2v1 upsampling rewrite came back
  SAT with a counterexample on which the model's own semantics agree with
  the proposal.  Without `-s` it is UNSAT in 27 s.  All results here use
  unsimplified traces; this also removes the model-side workaround the
  earlier FFmpeg proofs relied on.
- **Input unification must ignore reads-after-write.**  The shared proof
  script unified the two traces on the first read of every register; a
  flag read after an `add` is a computed value, and unifying it renamed one
  trace's intermediate onto the other's.  Fixed in the driver (declared
  variables only), which is what made the flag-including proofs possible.
- **Solver choice matters.**  Z3 4.8.12 did not finish the four-round
  SHA-256 query in 30 minutes; Bitwuzla and cvc5 finish it in 4 s.  The
  64×64 carry-less Karatsuba identity took Bitwuzla 1 h 56 min; Z3 and cvc5
  did not finish it in an hour.
- **Model gaps found**: VEX.256 VPCLMULQDQ (VPCLMULQDQ extension) is not
  implemented.  The CPUID gating is coarser than the assembler's (no AVX2
  flag; the integer 0F38/0F3A maps are gated on SSSE3 as a whole).
- **A wrong constant was caught by the proof**: the SM3 `pshufb` mask
  written with per-dword byte indices (PSHUFB indexes the whole register)
  was refuted; the corrected mask proves.

## Final run

A last run of all 59 pairs from one compiled model (118 test functions,
Z3 timeout 600 s, Bitwuzla fallback) reproduced every verdict above,
including the SM3 memory-mask form added last; its table is in
[libjpeg-linux-verified-optimizations-run.txt](libjpeg-linux-verified-optimizations-run.txt).
The only entries without a verdict are the two GHASH multiply queries
(Z3 timeout, Bitwuzla did not finish either) and the 256-bit AVX2 GHASH
reduce, whose trace ends in the model's #UD for VEX.256 `vpclmulqdq`.

## Reproducing

```
cd verify && python3 prove_candidates.py --jobs 48 --z3-timeout 600
```
with `ALT_SOLVER_PY` pointing at a python that has the `bitwuzla` package
and `ALT_SOLVER_SCRIPT` at a runner (see the driver).  Kernel differential
test: `verify/kernel-difftest/run.sh`.  libjpeg-turbo: `ninja && ctest` in
its build directory.
