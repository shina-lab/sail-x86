# Formal Equivalence Verification of x86 SIMD Optimizations Using Sail and Isla

## Overview

We built an automated pipeline that formally proves the equivalence of x86-64
SIMD instruction sequences using our Sail formal specification, the Isla
symbolic execution engine, and the Z3 SMT solver. The pipeline has verified
**5 real-world optimizations** from FFmpeg and libjpeg-turbo, proving
equivalence for all possible 128-bit inputs — not just tested samples.

This is, to our knowledge, the first time a custom x86-64 Sail model has been
integrated with Isla to perform instruction-sequence equivalence checking at
this scale.

## Motivation

Hand-optimized SIMD assembly is common in performance-critical codebases like
FFmpeg, which contains 164 hand-written NASM assembly files covering SSE2,
SSSE3, AVX2, and AVX-512 code paths. These optimizations are notoriously
error-prone: the programmer must ensure that a new instruction sequence
computes exactly the same function as the one it replaces, across all possible
inputs.

Traditional testing can only cover a finite number of inputs. Symbolic
execution with SMT solving can prove equivalence for *all* inputs — a
qualitative leap in assurance.

## Architecture

The verification pipeline has four stages:

```
  Sail x86 Model + Test Functions
       │
       ▼
  Isla IR (generate_equiv_ir.sh)
       │
       ▼
  Symbolic Traces (run_equiv_proofs.sh → isla-execute-function)
       │
       ▼
  SMT Equivalence Query (prove_equiv.py → Z3)
```

### Stage 1: Sail Model Compilation (`generate_equiv_ir.sh`)

Our Sail x86-64 model (~40 source files, covering integer ALU, control flow,
SSE/AVX integer SIMD, and partial x87/FP) is compiled to Isla's intermediate
representation using the `isla-sail` OCaml plugin. The resulting IR file is
~13 MB and contains ~1,700 functions.

Test functions encoding concrete instruction sequences are spliced in via
`ffmpeg_tests.sail`. Each test function is preserved from Isla's inlining pass
using `--isla-preserve`.

Key challenge: Isla's symbolic execution cannot use the model's normal
memory-based instruction fetch (it would make the instruction bytes symbolic,
causing the decoder to branch on every possible opcode). We solve this with a
*splice file* (`splice_ours.sail`) that:

- Replaces `ifetch_read8()` with a version that reads from a 120-bit
  `insn_buf` register instead of memory
- Replaces the paging/translation layer with identity mapping
- Provides a `setup_and_exec(bits(120))` helper that loads concrete
  instruction bytes and executes one instruction cycle
- Provides a simplified `step()` without try/catch or interrupt handling

This means instruction bytes are concrete (no decoder explosion) while
register values remain fully symbolic.

### Stage 2: Symbolic Execution (`run_equiv_proofs.sh`)

We use `isla-execute-function` to symbolically execute Sail test functions
that encode specific instruction sequences. For example, the DIFFERENCE
optimized path:

```sail
val test_difference_opt : unit -> bits(128)
function test_difference_opt() = {
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4d06f0f66);  // movdqa xmm2, xmm0
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1d80f66);  // psubusb xmm0, xmm1
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4cad80f66);  // psubusb xmm1, xmm2
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4c1eb0f66);  // por xmm0, xmm1
  read_xmm(0)
}
```

Each `setup_and_exec` call executes one instruction through the full Sail
decode-execute path. The XMM register contents are symbolic bitvectors. Isla
produces a trace containing the complete SMT formula relating inputs to
outputs. Traces are cached and only regenerated when the IR file changes.

### Stage 3: SMT Equivalence Proof (`prove_equiv.py`)

The Python script:

1. Parses each pair of Isla traces (original and optimized)
2. Extracts `declare-const` and `define-const` SMT-LIB statements
3. Parses `read-reg |ZMM|` lines to determine variable-to-register mapping
4. Renames variables in the optimized trace to share input variables with the
   original trace (since Isla assigns different variable numbers per function)
5. Constructs an SMT query asserting `(not (= orig_result opt_result))`
6. Runs Z3: **UNSAT** = equivalent for all inputs, **SAT** = counterexample exists

## Proved Optimizations

### 1. DIFFERENCE (FFmpeg `vf_blend.asm`): 18 → 4 instructions

Computes `|a - b|` per byte lane (unsigned absolute difference).

**Original (SSE2):** Widen bytes to words via `punpcklbw`/`punpckhbw`, subtract
with `psubw`, compute absolute value via `pcmpgtw`/`pxor`/`psubw`, pack back
with `packuswb`. 18 instructions.

**Optimized:** `psubusb(a,b) | psubusb(b,a)` — saturating subtract in both
directions and OR the results. 4 instructions.

**Result:** UNSAT (equivalent for all 2^256 input combinations).

### 2. PHOENIX (FFmpeg `vf_blend.asm`): 6 → 5 instructions

Computes `0xFF - max(a,b) + min(a,b)` per byte lane.

**Original:** Uses `pminub`/`pmaxub`/`psubusb`/`paddusb` with a constant
`0xFF` register.

**Optimized:** Rewrites as `absdiff(a,b) ^ 0xFF` using
`psubusb`/`psubusb`/`por`/`pxor`.

**Result:** UNSAT (equivalent for all inputs).

### 3. EXTREMITY (FFmpeg `vf_blend.asm`): 21 → 6 instructions

Computes `|255 - top - bottom|` per byte lane.

**Original (SSE2):** Widen to words, subtract from 255, subtract bottom,
absolute value via `pcmpgtw`/`pxor`/`psubw`, pack back. 21 instructions
across both halves.

**Optimized:** `absdiff(~top, bottom)` using `pcmpeqb`/`pxor`/`psubusb`
/`psubusb`/`por`. 6 instructions.

**Result:** UNSAT (equivalent for all inputs).

### 4. NEGATION (FFmpeg `vf_blend.asm`): 25 → 7 instructions

Computes `255 - |255 - top - bottom|` per byte lane.

**Original (SSE2):** Same as EXTREMITY but adds a final `255 - result` step.
25 instructions.

**Optimized:** `~absdiff(~top, bottom)` — same as EXTREMITY with a final
`pxor 0xFF`. 7 instructions.

**Result:** UNSAT (equivalent for all inputs).

### 5. ABS16 (libjpeg-turbo `jquanti-sse2.asm`): 4 → 1 instruction

Computes absolute value of signed 16-bit words.

**Original (SSE2):** `movdqa`/`psraw 15`/`pxor`/`psubw` — the classic
branchless abs via arithmetic shift.

**Optimized (SSSE3):** Single `pabsw` instruction.

**Result:** UNSAT (equivalent for all inputs).

### Non-Equivalent: MULTIPLY (FFmpeg `vf_blend.asm`)

Two div-by-255 approximations for byte products:

- **Original:** `(x+1+((x+1)>>8))>>8`
- **Optimized:** `((x+128)*257)>>16`

**Unconstrained (full 16-bit words):** SAT — counterexamples exist for
arbitrary word inputs.

**Byte-constrained (inputs in [0,255]):** SAT — the approximations still
differ for some byte products. Example: `0xCF × 0x11 = 3519`, original
yields 13, optimized yields 14. This is a genuine mathematical difference,
not a bug in the pipeline.

## Isla Workarounds

### Extract-over-bvsub inlining bug

When a wide (N+1-bit) intermediate variable has only **one** extraction
reference, Isla's simplifier inlines it and incorrectly distributes the
extraction over arithmetic:

```
extract(8, 8, sub(A, B))  →  sub(extract(8, 8, A), extract(8, 8, B))  ✗
```

This is mathematically wrong — the borrow bit from the lower 8 bits is lost.

**Workaround:** Ensure all wide intermediates have **two** extraction
references. For example, in `sat_sub_u8`:

```sail
function sat_sub_u8(a, b) = {
  let wide : bits(9) = (0b0 @ a) - (0b0 @ b);
  let mask : byte = sign_extend(~(wide[8..8]));
  wide[7..0] & mask    // second reference prevents inlining
}
```

Both `wide[8..8]` and `wide[7..0]` reference `wide`, so Isla keeps it as a
named variable and the subtraction is computed correctly before extraction.

This pattern was applied to all comparison and saturating arithmetic helpers:
`sat_sub_u8/16/32`, `cmp_eq8/16/32`, `cmp_gt8/16/32`.

### Input variable mapping

Isla assigns sequential variable numbers starting from the function's
parameter count. Different test functions may start ZMM register variables at
different offsets (e.g., `v0` for ZMM[0] in one trace, `v5` in another).

**Fix:** Parse `read-reg |ZMM| nil (_ vec v0 v1 ...)` lines in each trace to
build the actual variable-to-register mapping, then rename variables in the
optimized trace to match the original trace's input variables.

## Branchless SIMD Helper Design

The Sail model's SIMD comparison and min/max helpers must be branchless for
Isla symbolic execution to produce manageable traces. The key building blocks:

- **Saturating subtract:** `sat_sub_u(a,b) = (a-b) & mask(no_borrow)`
- **Unsigned min/max:** `min_u(a,b) = a - sat_sub_u(a,b)`,
  `max_u(a,b) = a + sat_sub_u(b,a)`
- **Signed min/max:** Convert to unsigned via XOR with sign bit, apply
  unsigned min/max, convert back: `min_s(a,b) = min_u(a^0x80, b^0x80) ^ 0x80`
- **Equality compare:** `cmp_eq(a,b) = low_bits(xor(a,b) - 1) & sign_extend(borrow_bit)`
- **Greater-than compare:** Convert to unsigned, saturating subtract,
  probe for nonzero via the borrow trick

## File Inventory

| File | Description |
|------|-------------|
| `verify/generate_equiv_ir.sh` | Compiles Sail model + test functions to Isla IR |
| `verify/run_equiv_proofs.sh` | Generates symbolic traces and runs Z3 proofs |
| `verify/prove_equiv.py` | Parses traces, builds SMT queries, invokes Z3 |
| `verify/ffmpeg_tests.sail` | Test function pairs for all optimization candidates |
| `verify/splice_ours.sail` | Memory/paging/ifetch overrides for Isla |
| `verify/x86_config_ours.toml` | Isla configuration for x86-64 mode |
| `verify/ir/sail_x86_equiv.ir` | Compiled Isla IR (~13 MB) |
| `model/insn_sse_int.sail` | Branchless SIMD helpers (sat_sub, cmp, min/max) |

## Future Work

1. **More programs:** Extend to other SIMD-heavy codebases (x264, dav1d,
   OpenSSL) to build a corpus of verified optimizations.

2. **AVX/AVX2 widening:** Verify that 128-bit SSE proofs extend to 256-bit
   AVX2 variants (same lane operations, doubled width).

3. **Superoptimization:** Use the pipeline in reverse — given a sequence,
   search for shorter equivalent sequences and prove them correct.

4. **Regression proofing:** When modifying the Sail model (e.g., fixing an
   instruction's semantics), re-run equivalence proofs to ensure no
   regressions.
