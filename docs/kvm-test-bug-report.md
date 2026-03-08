# Bugs Found via KVM Differential Testing — SDM Verification Report

This report lists all bugs and missing features discovered in the sail-x86
formal specification through KVM differential testing, and verifies each
against the [Intel Software Developer's Manual (SDM)](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html).

## Semantic Bugs (incorrect behavior)

### 1. SHLD: Wrong CF computation (commit e418806)

**Bug:** CF was read from the wrong bit of the shifted value. Fixed to
correctly compute CF as the last bit shifted out of the destination.

**SDM (Flags Affected):** "If the count is 1 or greater, the CF flag is
filled with the last bit shifted out of the destination operand."

**SDM pseudocode:** `CF := BIT[DEST, SIZE - COUNT]` (last bit shifted out
on exit).

**Verdict:** SDM is clear and unambiguous. Our bug was purely an
implementation error. SDM correctly specifies CF.

---

### 2. INC/DEC: CF preservation lost (commit e418806)

**Bug:** CF was supposed to be preserved (INC/DEC don't modify CF), but a
Sail compiler optimization eliminated the save/restore pattern. Fixed by
adding dedicated `update_flags_add_no_cf` / `update_flags_sub_no_cf`
helpers.

**SDM (both INC and DEC, Flags Affected):** "The CF flag is not affected.
The OF, SF, ZF, AF, and PF flags are set according to the result."

**SDM (Description):** "Adds 1 to the destination operand, while preserving
the state of the CF flag. This instruction allows a loop counter to be
updated without disturbing the CF flag."

**Verdict:** SDM is crystal clear. This was a Sail compiler optimization
bug that broke a correctly-written implementation. No SDM ambiguity.

---

### 3a. 32-bit shift/rotate with count=0: Missing zero-extension (commit 0dcf209)

SDM reference: https://www.felixcloutier.com/x86/sal:sar:shl:shr

**Bug:** `SHL EAX, CL` with CL=0 should still write EAX (zero-extending
upper 32 bits per x86-64 semantics), but `exec_shift_rm` returned early
without writing. Fixed to read and write back the value for OS32 even when
masked count is 0.

**SDM (Operation):** When `(COUNT AND countMASK) = 0`, the pseudocode says
"All flags unchanged" — but this refers only to flags. The pseudocode does
NOT explicitly state whether the destination register is written or not
when count=0.

**SDM (Section 3.4.1.1, "General-Purpose Registers in 64-Bit Mode",
Vol. 1 p. 3-13):** "32-bit operands generate a 32-bit result, zero-extended
to a 64-bit result in the destination general-purpose register." This is
stated as an unconditional, general rule for all instructions with 32-bit
operand size in 64-bit mode.

**SDM (SHL/SHR/SAR pseudocode):** When `(COUNT AND countMASK) = 0`, the
pseudocode says "All flags unchanged" and does not write DEST. A mechanical
reading of the pseudocode implies no destination write occurs, and therefore
no zero-extension.

**Verdict: SDM inconsistency — the pseudocode contradicts the general rule.**
Section 3.4.1.1 says 32-bit operands always produce a zero-extended result.
But the shift pseudocode's early-exit path for count=0 never writes DEST,
so a reader mechanically following the pseudocode would conclude no
zero-extension happens. Real hardware follows the Section 3.4.1.1 rule:
`SHL EAX, 0` does write EAX and zero-extends. The whole point of pseudocode
is to be mechanically followable — it should be self-contained and correct
without requiring the reader to cross-reference a general rule from a
different chapter. The shift pseudocode should explicitly write DEST even
when count=0, or at minimum include a note referencing the 3.4.1.1 rule.

---

### 3b. 8/16-bit SHL/SHR with count > operand size: SF/ZF/PF flags (commit 0dcf209)

**Bug:** When shift count exceeded operand size, SF/ZF/PF were incorrectly
marked as undefined. Real hardware sets these flags from the result
regardless of count. Fixed to always call `update_SF_ZF_PF()`.

**SDM (Flags Affected):** "The SF, ZF, and PF flags are set according to
the result." This is unconditional for non-zero counts. Only CF is
described as "undefined for SHL and SHR instructions where the count is
greater than or equal to the size (in bits) of the destination operand."
OF is also "undefined" for counts != 1.

**Verdict:** SDM is clear. SF/ZF/PF should always be set from the result
for any non-zero count. Our implementation incorrectly applied CF's
"undefined" condition to SF/ZF/PF as well. No SDM ambiguity — this was a
misreading of the spec.

---

### 4. PMULLW/PMULHW: Opcodes swapped (commit 27ccb20)

**Bug:** The implementations of PMULLW (0F D5) and PMULHW (0F E5) were
swapped: the opcode 0xD5 match arm was computing high products, and the
0xE5 match arm was computing low products.

**SDM:**
- PMULLW = `66 0F D5 /r` — "store the low 16 bits of the results"
- PMULHW = `66 0F E5 /r` — "store the high 16 bits of the results"

**SDM pseudocode (PMULLW):**
```
TEMP0[31:0] := DEST[15:0] * SRC[15:0];
DEST[15:0]  := TEMP0[15:0];          <- LOW 16 bits
```

**SDM pseudocode (PMULHW):**
```
TEMP0[31:0] := DEST[15:0] * SRC[15:0];
DEST[15:0]  := TEMP0[31:16];         <- HIGH 16 bits
```

**Verdict:** SDM is completely unambiguous. This was a pure implementation
mistake — the two opcode match arms had swapped logic. No SDM issue.

---

### 5. PHSUBW/PHSUBD/PHSUBSW: Subtraction operand order reversed (commit 7ac45e2)

**Bug:** The Sail model computed `high - low` (e.g., `a[31..16] - a[15..0]`)
but the correct operation is `low - high` (e.g., `a[15..0] - a[31..16]`).

**SDM pseudocode (PHSUBW):**
```
DEST[15:0]  := SRC1[15:0]  - SRC1[31:16]    (low minus high)
DEST[31:16] := SRC1[47:32] - SRC1[63:48]
```

**SDM description:** "subtracting the most significant word from the least
significant word of each pair"

The same pattern applies to PHSUBD and PHSUBSW.

**Verdict:** SDM is unambiguous. The operation is low - high (least
significant minus most significant). Our implementation had it backwards.
No SDM issue.

---

### 6. CMPPS/CMPPD predicate 6 (NLE): Wrong NaN result (commit d9e737f)

**Bug:** The Sail model implemented predicate 6 (NLE_US, "not-less-than-or-
equal") as `result == FP_GT`, which returns false when either operand is
NaN. The correct behavior for an "unordered" predicate is to return true
when either operand is NaN. Fixed to `result != FP_LT & result != FP_EQ`.

**SDM (Table 3-1, CMPPD/CMPPS Comparison Predicate):**

| Predicate | imm8 | Description | A>B | A<B | A=B | Unordered |
|-----------|------|-------------|-----|-----|-----|-----------|
| NLE_US    | 6H   | Not-less-than-or-equal (unordered, signaling) | True | False | False | **True** |

**SDM (CMPPS Description):** "The unordered relationship is true when at
least one of the two source operands being compared is a NaN; the ordered
relationship is true when neither source operand is a NaN."

**Verdict:** SDM is completely unambiguous. Table 3-1 explicitly shows that
predicate 6 (NLE_US) returns True for the unordered case (NaN). The
"unordered" in the predicate name itself indicates NaN → true. Our
implementation only checked for the "greater-than" case, missing that
"not-less-than-or-equal" must also be true when unordered. No SDM issue.

---

### 7. LZCNT: Wrong count for sub-64-bit operand sizes (commit 1a8ce42)

**Bug:** The `lzcnt64` helper always counted leading zeros across all 64
bits, regardless of operand size. For `LZCNT r32, r/m32`, the helper
scanned from bit 63 instead of bit 31, producing an incorrect (too large)
count.

**SDM (LZCNT Operation):**
```
temp := OperandSize - 1
DEST := 0
WHILE (temp >= 0) AND (Bit(SRC, temp) = 0)
DO
    temp := temp - 1
    DEST := DEST + 1
OD
```

The pseudocode starts scanning from `OperandSize - 1`, not from bit 63.
For a 32-bit operand, scanning starts at bit 31; for 16-bit, at bit 15.

**SDM (LZCNT Description):** "Counts the number of leading most significant
zero bits in a source operand (second operand) returning the result into a
destination (first operand)." and "LZCNT will produce the operand size when
the input operand is zero."

**Verdict:** SDM is clear. The scan range depends on operand size. Our
helper unconditionally used 64-bit width. No SDM issue.

---

## C Emulator Bugs (external function implementations)

These bugs were in `c_emulator/x86_externals.cpp`, the C implementations of
floating-point operations called by the Sail model. The Sail specification
itself was correct — these are bugs in how the external FP functions were
implemented.

### 8. MINPS/MAXPS: Wrong operand returned for NaN inputs (commit cee48e2)

**Bug:** The C emulator's `_f32_min` / `_f32_max` (and f64 equivalents)
used standard C `fminf`/`fmaxf`, which return the non-NaN operand when one
input is NaN. The x86 MIN/MAX instructions have different semantics: when
either operand is NaN, they return the **second source operand** (SRC2),
regardless of which operand is the NaN.

The same bug affected the both-zeros case: `MIN(-0, +0)` should return +0
(SRC2), not -0.

**SDM (MINPS Description):** "If only one value is a NaN (SNaN or QNaN)
for this instruction, the second operand (source operand), either a NaN or
a valid floating-point value, is written to the result."

**SDM (MINPS Description, both zeros):** "If the values being compared are
both 0.0s (of either sign), the value in the second operand (source
operand) is returned."

**SDM (MINPS Operation):**
```
MIN(SRC1, SRC2)
{
    IF ((SRC1 = 0.0) and (SRC2 = 0.0)) THEN DEST := SRC2;
        ELSE IF (SRC1 = NaN) THEN DEST := SRC2; FI;
        ELSE IF (SRC2 = NaN) THEN DEST := SRC2; FI;
        ELSE IF (SRC1 < SRC2) THEN DEST := SRC1;
        ELSE DEST := SRC2;
    FI;
}
```

**Verdict:** SDM is completely unambiguous. The pseudocode explicitly
returns SRC2 for NaN and both-zero cases. Standard C library functions
follow IEEE 754-2008 `minNum`/`maxNum` semantics (return non-NaN), which
differs from x86 MIN/MAX. No SDM issue.

---

### 9. CVTPS2DQ/CVTTPS2DQ: Undefined behavior for NaN/Inf/overflow (commit cee48e2)

**Bug:** The C emulator's `_f32_to_int32` converted float→int using a bare
C cast `(i32)f`, which is undefined behavior in C/C++ when the float value
is NaN, Inf, or outside the range of `int32_t`. Real hardware returns the
"integer indefinite" value `0x80000000` for all these cases. Fixed by
adding explicit checks for NaN, Inf, and out-of-range values.

**SDM (CVTPS2DQ Description):** "When a conversion is inexact, the value
returned is rounded according to the rounding control bits in the MXCSR
register or the embedded rounding control bits. If a converted result
cannot be represented in the destination format, the floating-point invalid
exception is raised, and if this exception is masked, the indefinite
integer value (2^(w-1), where w represents the number of bits in the
destination format) is returned."

For 32-bit destination, 2^31 = 0x80000000, which is the bit pattern for
`INT32_MIN` in two's complement.

**Verdict:** SDM is clear. The indefinite integer value is well-specified.
Our C code relied on undefined behavior instead of implementing the
explicit overflow check. No SDM issue.

---

### 10. SSE arithmetic: MXCSR rounding mode not synced (commit 21bac43)

**Bug:** The C emulator's SSE arithmetic functions (add, sub, mul, div,
sqrt) did not call `fesetround()` to synchronize the C library's rounding
mode with the MXCSR.RC bits before performing operations. This meant all
SSE arithmetic always used the default round-to-nearest mode, ignoring
any MXCSR rounding mode changes made by `LDMXCSR`.

**SDM (ADDPS Operation, EVEX version):**
```
IF (VL = 512) AND (EVEX.b = 1)
    THEN SET_ROUNDING_MODE_FOR_THIS_INSTRUCTION(EVEX.RC);
    ELSE SET_ROUNDING_MODE_FOR_THIS_INSTRUCTION(MXCSR.RC);
FI;
```

**SDM (MXCSR, Section 10.2.3):** "Bits 14:13 — Rounding Control... These
two bits control how the results of floating-point instructions are
rounded."

**Verdict:** SDM is clear that SSE arithmetic uses MXCSR.RC for rounding.
Our C emulator simply failed to propagate this setting to the host FPU.
No SDM issue.

---

### 11. SSE arithmetic: NaN propagation order wrong (commit 21bac43)

**Bug:** When both operands to an SSE arithmetic operation (add, sub, mul,
div) are NaN, the C emulator returned whichever NaN the C compiler's code
generation happened to produce, which varied depending on the host
`fesetround()` state. The x86 architecture specifies that SRC1 (the first
operand / destination register) should be returned (with the quiet bit
set).

Fixed by adding explicit `f32_nan_prop` / `f64_nan_prop` checks before
performing the arithmetic: if either operand is NaN, return SRC1 with the
quiet bit set; only if SRC1 is not NaN but SRC2 is, return SRC2 with the
quiet bit set.

**SDM (Section 4.8.3.5, "Operating on NaNs"):** "If both SRC1 and SRC2 are
NaNs... then SRC1 is converted to a QNaN (if applicable) and written to
the destination."

This is Intel's NaN propagation rule: SRC1 takes priority over SRC2.

**Verdict:** SDM is clear on NaN propagation order. The bug was caused by
relying on C compiler behavior, which doesn't guarantee Intel's NaN
propagation semantics. No SDM issue.

---

### 12. Int→float conversions: MXCSR rounding mode ignored (commit 07facec)

**Bug:** The C emulator's integer-to-float conversion functions
(`int32_to_f32`, `int64_to_f32`, `int64_to_f64`, etc.) and `f64_to_f32`
did not call `fesetround()` before performing the conversion. Large integer
values that cannot be exactly represented in float require rounding, and
this rounding must respect MXCSR.RC. Without syncing, conversions always
used round-to-nearest.

**SDM (CVTDQ2PS Description):** "Converts four, eight or sixteen packed
signed doubleword integers in the source operand to four, eight or sixteen
packed single precision floating-point values in the destination operand."
The operation is implicitly subject to MXCSR rounding control for inexact
conversions.

**SDM (CVTSI2SS Operation):**
```
DEST[31:0] := Convert_Integer_To_Single_Precision_Floating_Point(SRC[31:0]);
```

The SDM's `Convert_Integer_To_Single_Precision_Floating_Point` function
implicitly uses the current rounding mode from MXCSR.RC.

**Verdict:** SDM implies rounding control applies to int→float conversions
(since they can be inexact), but does not explicitly call
`SET_ROUNDING_MODE` in the pseudocode the way ADDPS does. A more explicit
note about MXCSR.RC applicability would be helpful, though IEEE 754
mandates that rounding mode applies to all inexact operations. Minor SDM
clarity gap.

---

### 13. ADCX: Mandatory prefix treated as operand size override (commit 3c05739)

**Bug:** ADCX is encoded as `66 0F 38 F6 /r`, where the `66` prefix is a
mandatory prefix that distinguishes ADCX from ADOX (`F3 0F 38 F6 /r`).
The Sail model called `get_operand_size(pfx)`, which checked `pfx.has_opsize`
and returned OS16 (16-bit operand size) instead of the correct OS32. This
caused ADCX to read/write only the low 16 bits of the register, producing
wrong results and wrong CF flags.

Fixed by determining operand size from REX.W only: `if pfx.rex_w then OS64
else OS32`.

**SDM (ADCX Description):** "The operand size is always 32 bits if not in
64-bit mode." and "Using REX Prefix in the form of REX.W promotes operation
to 64 bits."

**SDM (ADCX Operation):**
```
IF OperandSize is 64-bit
    THEN CF:DEST[63:0] := DEST[63:0] + SRC[63:0] + CF;
    ELSE CF:DEST[31:0] := DEST[31:0] + SRC[31:0] + CF;
FI;
```

**SDM (ADCX Flags Affected):** "CF is updated based on result. OF, SF, ZF,
AF, and PF flags are unmodified."

**Verdict:** SDM is clear. The operand size is 32-bit or 64-bit (with
REX.W), never 16-bit. The `66` prefix is purely a mandatory opcode prefix.
No SDM issue — our decoder incorrectly reused generic operand size logic
for an instruction where the `66` prefix has a different role.

---

### 14. DAZ/FTZ: MXCSR denormal modes not implemented (commit 3c05739)

**Bug:** The C emulator did not implement the MXCSR DAZ (Denormals-Are-
Zeros, bit 6) or FTZ (Flush-To-Zero, bit 15) modes. When DAZ is set,
denormal input operands should be treated as ±0.0 (preserving sign).
When FTZ is set, denormal results should be flushed to ±0.0. Without
these, all FP operations processed denormals normally regardless of MXCSR.

Fixed by adding `f32_daz`/`f64_daz` (input flushing) and `f32_ftz`/`f64_ftz`
(output flushing) helpers to all SSE/AVX FP functions: arithmetic (add, sub,
mul, div), sqrt, min/max, comparison, conversions, round, rcp, rsqrt, and
all 8 FMA variants.

**SDM (Section 10.2.3.4, "Flush-To-Zero"):** "When the flush-to-zero flag
is set in the MXCSR register, an SSE/SSE2/SSE3 instruction will return a
result of zero (with the sign of the true result) when the true result is a
denormalized number."

**SDM (Section 10.2.3.3, "Denormals-Are-Zeros"):** "When the denormals-
are-zeros flag is set, the processor treats all denormalized source operands
as zeros with the sign of the original operand."

**Verdict:** SDM is clear on both DAZ and FTZ semantics. Our C emulator
simply failed to check these MXCSR bits. No SDM issue.

---

## Decoder Bug

### 15. LZCNT/TZCNT: F3 prefix not checked (commit e418806)

**Bug:** The decoder did not check for the F3 prefix, so LZCNT/TZCNT were
always decoded as BSR/BSF.

**SDM:**
- LZCNT = `F3 0F BD /r`; BSR = `0F BD /r` (no F3 prefix)
- TZCNT = `F3 0F BC /r`; BSF = `0F BC /r` (no F3 prefix)

**SDM (LZCNT description):** "on processors that do not support LZCNT, the
instruction byte encoding is executed as BSR."

**SDM (TZCNT description):** "TZCNT is an extension of the BSF instruction.
On processors that do not support TZCNT, the instruction byte encoding is
executed as BSF."

**Verdict:** SDM is clear. The F3 prefix distinguishes these instructions.
Our decoder simply failed to check for it. No SDM issue.

---

## Missing Instructions (discovered via KVM test coverage gaps)

The following instructions were not implemented in the Sail model and were
added after KVM testing revealed the gaps:

- CRC32 (all r32/r64 x r/m8/16/32/64 variants) — commit 29ecde4
- VUNPCKLPS/VUNPCKHPS/VUNPCKLPD/VUNPCKHPD — commit 57017c5
- VCMPPS/VCMPPD/VCMPSS/VCMPSD — commit 57017c5
- VCVTDQ2PS/VCVTPS2DQ/VCVTTPS2DQ — commit 57017c5
- VEX FMA3 (all 36 opcodes: 0F38 96-BF) — commit f6bdece
- VBROADCASTSS — commit fbf968d
- VPADDSB, VPADDUSB, VPSUBSB, VPSUBUSB, VUCOMISS, VUCOMISD — commit 8000fea
- BMI1: ANDN, BLSI, BLSMSK, BLSR, BEXTR — commit 4117d9e
- MOVBE (0F 38 F0/F1): byte-swap load/store, 16/32/64-bit

---

## Summary Table

| # | Bug | Component | SDM Clear? | SDM Issue? |
|---|-----|-----------|-----------|------------|
| 1 | SHLD CF wrong bit | Sail model | Yes | No |
| 2 | INC/DEC CF not preserved | Sail compiler | Yes | No |
| 3a | SHL r32,0 no zero-extend | Sail model | **Inconsistent** | **Yes — pseudocode contradicts §3.4.1.1** |
| 3b | SHL/SHR flags for large counts | Sail model | Yes | No |
| 4 | PMULLW/PMULHW swapped | Sail model | Yes | No |
| 5 | PHSUBW operand order | Sail model | Yes | No |
| 6 | CMPPS NLE NaN handling | Sail model | Yes | No |
| 7 | LZCNT sub-64-bit operand size | Sail model | Yes | No |
| 8 | MINPS/MAXPS NaN returns wrong operand | C emulator | Yes | No |
| 9 | CVTPS2DQ NaN/Inf/overflow UB | C emulator | Yes | No |
| 10 | SSE arithmetic ignores MXCSR rounding | C emulator | Yes | No |
| 11 | SSE NaN propagation order wrong | C emulator | Yes | No |
| 12 | Int→float ignores MXCSR rounding | C emulator | Yes | Minor gap |
| 13 | ADCX mandatory prefix as opsize | Sail model | Yes | No |
| 14 | DAZ/FTZ denormal modes missing | C emulator | Yes | No |
| 15 | LZCNT/TZCNT F3 prefix not checked | Decoder | Yes | No |

**One SDM inconsistency found:** Bug 3a reveals that the SHL/SHR/SAR
pseudocode contradicts the general rule in Section 3.4.1.1 ("General-Purpose
Registers in 64-Bit Mode", Vol. 1 p. 3-13). Section 3.4.1.1 unconditionally
states that "32-bit operands generate a 32-bit result, zero-extended to a
64-bit result in the destination general-purpose register." However, the
shift pseudocode's early-exit path for count=0 never writes DEST, so a
reader mechanically following the pseudocode would conclude no zero-extension
happens. Real hardware follows the Section 3.4.1.1 rule. The pseudocode
should be self-contained and mechanically correct — it should explicitly
write DEST even when count=0.

**One minor SDM clarity gap:** Bug 12 shows that the CVTDQ2PS/CVTSI2SS
pseudocode does not explicitly reference MXCSR.RC, unlike ADDPS which calls
`SET_ROUNDING_MODE_FOR_THIS_INSTRUCTION(MXCSR.RC)`. Since int→float
conversions can be inexact (e.g., large 32-bit integers lose precision in
float32), the rounding mode matters. IEEE 754 mandates that rounding mode
applies to all inexact operations, but the SDM pseudocode could be more
explicit about this.

---

## Test Coverage Summary

The KVM differential test suite currently runs **59,070 tests** across
**65 ctest categories**. Tests compare architectural state (GPRs, flags,
XMM registers, MXCSR, memory) between KVM execution on real hardware and
the Sail model.

### Instruction categories with dedicated tests

- **ALU**: ADD, OR, ADC, SBB, AND, SUB, XOR, CMP — all 8 ops × 4 sizes
  (8/16/32/64) × 30×30 boundary value matrix, plus ADC/SBB with CF=1
- **TEST reg,reg**: All sizes × boundary value matrix
- **Shifts**: SHL, SHR, SAR, ROL, ROR, RCL, RCR — 7 ops × 4 sizes ×
  11 shift counts × boundary values
- **Unary ops**: INC, DEC, NEG, NOT — all sizes × boundary values
- **MUL/IMUL, DIV/IDIV**: All sizes × boundary values
- **Register variation**: ADD r64,r64 for all 15×14 non-RSP register pairs
- **Random**: 1000 randomized ALU tests with biased boundary inputs
- **Baseline**: ALU corner cases, operand sizes, reg/imm forms, shift
  operations, multiply, divide, INC/DEC/NEG/NOT, SETcc/CMOVcc, branches,
  data movement, bit operations (BT/BTS/BTR/BTC/BSF/BSR), stack ops,
  LEA, memory operands, SHLD/SHRD, MOV reg/imm, XADD, CMPXCHG,
  multi-instruction, REX prefix, flag manipulation
- **SSE**: Packed/scalar float arithmetic, comparisons, conversions,
  shuffles, logical, data movement (MOVAPS/MOVUPS/MOVSS/MOVSD etc.)
- **SSE3/SSSE3/SSE4.1/SSE4.2**: HADDPS, PSHUFB, PALIGNR, PBLENDW,
  PMULDQ, PCMPGTQ, PCMPISTRI/PCMPISTRM/PCMPESTRI, CRC32
- **AES-NI**: AESENC, AESDEC, AESIMC, AESKEYGENASSIST
- **AVX**: VEX-encoded arithmetic, data movement, shuffles, conversions
- **AVX Edge**: VEX FP boundary-value matrix (f32: 24 pairs × 6 ops +
  8 VCMPPS predicates; f64: 20 pairs × 6 ops), VEX scalar FP edges
  (f32 + f64), upper-128 clearing verification, 256-bit arithmetic
  (PS/PD/integer), integer SIMD boundary values (10 pairs × 6 ops),
  conversion edge cases (NaN/Inf/overflow) — 831 tests
- **EVEX**: EVEX-encoded operations including VPADDD, VPXORD
- **x87**: Basic x87 FPU operations
- **String ops**: REP MOVS/STOS/LODS/CMPS/SCAS with direction flag,
  zero-length, forward/backward
- **SETcc/CMOVcc**: All 16 condition codes
- **Stack**: POP, PUSH, LEAVE, ENTER (nesting levels 0-2)
- **CMPXCHG8B/16B**: Compare-and-exchange
- **MOVNTI**: Non-temporal store
- **LDMXCSR/Fences/EMMS**: Control operations
- **LZCNT/TZCNT**: All sizes, zero input, flag semantics (CF, ZF)
- **POPCNT**: All sizes, flag clearing, boundary values
- **BSF/BSR**: All sizes, zero input, boundary bits
- **BSWAP**: 32/64-bit, zero-extension, extended registers
- **MOVBE**: Byte-swap load/store, 16/32/64-bit
- **XCHG**: Opcode register and ModRM forms, 8/16/32/64-bit
- **MOVSX/MOVSXD**: Sign-extension 8→32, 8→64, 16→32, 16→64, 32→64
- **BT/BTS/BTR/BTC**: Register and immediate forms, bit index wrapping
- **SSE4.2 string ops**: PCMPISTRI, PCMPISTRM, PCMPESTRI
- **NOP**: Multi-byte NOPs (1-9 bytes), chained sequences
- **Prefix**: 66+REX.W interaction, double 66, address-size override (67),
  REX byte register remapping
- **REX R/B/X**: REX.R/B/X register extension, SIB base/index, 32-bit
  zero-extension, opcode-register encoding, bare REX (0x40)
- **ADCX/ADOX**: Flag semantics, mandatory prefix, carry/overflow
- **DAZ/FTZ**: MXCSR denormal flush modes
- **OpSize Edge**: 16-bit operations, upper register preservation
- **FP Edge**: Rounding modes, NaN handling, denormals, precision

### Boundary value test set (30 values)

The ALU stratified tests use a 30-value boundary set generating 900 input
pairs per operation/size. Values include: zero, ±1, ±2, signed min/max at
8/16/32/64-bit widths, unsigned max at all widths, MAX-1 and MIN+1 for
off-by-one detection, size-boundary crossings (UINT8_MAX+1, UINT16_MAX+1),
alternating bit patterns, a 32/64-bit boundary value, sign-extension edge
(0xFFFFFFFF00000000), and a non-trivial mixed pattern.

### Known test coverage gaps

- **EVEX masking/zeroing**: Harness lacks k (opmask) register support
- **512-bit EVEX**: Requires host AVX-512 support
- **x87 transcendentals**: FSIN, FCOS, FPTAN precision matching is fragile
- **BT/BTS/BTR/BTC with memory**: Bit offset extending beyond addressed
  byte (requires memory-form tests with large bit indices)
- **LOCK prefix**: Atomic memory operations
- **Segment overrides**: Not applicable in 64-bit flat memory model
- **Exception/fault behavior**: No tests verify that instructions raise the
  correct exceptions — see test plan below

---

## Exception/Fault Test Plan

### Implementation status

**Harness infrastructure: DONE.** The KVM test harness now supports
fault-expecting tests. Changes made:

1. **IDT with exception handlers**: 32 exception handler stubs at
   `HANDLER_ADDR` (0x05000), each storing vector + error code + faulting
   RIP to `FAULT_INFO_ADDR` (0x12000), then HLTing.
2. **`FaultInfo` struct and `expect_fault` field** on `TestCase`.
3. **KVM fault capture**: After `KVM_EXIT_HLT`, checks if RIP is in the
   handler area and reads stored fault info from guest memory.
4. **Sail fault capture**: On `Kind_zFault`, extracts vector and error
   code instead of aborting.
5. **Comparison**: Verifies both sides produce the same exception vector
   and error code.

**Tests implemented: 30 tests across 3 exception categories.**

**Bugs found and fixed:**
- MOVAPS/MOVAPD (SSE): missing 16-byte alignment check → added #GP(0)
- VMOVAPS/VMOVAPD (VEX 128): missing 16-byte alignment check → added #GP(0)
- VMOVAPS/VMOVAPD (VEX 256): missing 32-byte alignment check → added #GP(0)
- VMOVAPS/VMOVAPD store (VEX): missing alignment checks → added #GP(0)
- LOCK prefix: model didn't check `has_lock` at all → added comprehensive
  LOCK validation for 1-byte and 2-byte opcodes (lockable opcode check +
  register-vs-memory check + CMP exclusion)
- avx_test `_start`: missing `force_align_arg_pointer` attribute

**Known gaps:**
- EVEX VMOVAPS/VMOVAPD alignment checks not yet added.
- #PF tests require page table changes (unmapped/read-only pages).
- #MF/#XM: Sail model doesn't check MXCSR exception masks.

### Remaining harness work

5. **Page table setup**: Add a second 2MB region that is either unmapped
   (not-present) or read-only in the guest page tables, so tests can
   point memory operands at inaccessible addresses.

### Exception categories to test

#### 1. Page Fault (#PF, vector 14)

Triggered when an instruction accesses an unmapped or protected page.
Error code encodes: P (present), W/R (write), U/S (user/supervisor).

**Memory read instructions** — point source operand at unmapped page:

| Instruction | Encoding example | Notes |
|-------------|-----------------|-------|
| `MOV RAX, [RDI]` | `48 8B 07` | Basic load |
| `MOVZX EAX, byte [RDI]` | `0F B6 07` | Zero-extending load |
| `MOVSX RAX, byte [RDI]` | `48 0F BE 07` | Sign-extending load |
| `ADD RAX, [RDI]` | `48 03 07` | ALU with memory source |
| `CMP RAX, [RDI]` | `48 3B 07` | Compare (read-only) |
| `TEST [RDI], RAX` | `48 85 07` | Test (read-only) |
| `MOVAPS XMM0, [RDI]` | `0F 28 07` | SSE aligned load |
| `MOVUPS XMM0, [RDI]` | `0F 10 07` | SSE unaligned load |
| `MOVDQU XMM0, [RDI]` | `F3 0F 6F 07` | SSE integer load |
| `VMOVAPS XMM0, [RDI]` | `C5 F8 28 07` | VEX load |
| `LEA RAX, [RDI]` | `48 8D 07` | Should NOT fault (no memory access) |
| `PUSH [RDI]` | `FF 37` | Stack push from memory |
| `POP [RDI]` | `8F 07` | Stack pop to memory (reads stack) |

**Memory write instructions** — point destination at unmapped page:

| Instruction | Encoding example | Notes |
|-------------|-----------------|-------|
| `MOV [RDI], RAX` | `48 89 07` | Basic store |
| `MOV [RDI], imm32` | `C7 07 ...` | Immediate store |
| `ADD [RDI], RAX` | `48 01 07` | Read-modify-write |
| `INC [RDI]` | `FF 07` | Read-modify-write |
| `XCHG [RDI], RAX` | `48 87 07` | Atomic exchange |
| `CMPXCHG [RDI], RAX` | `48 0F B1 07` | Conditional store |
| `MOVAPS [RDI], XMM0` | `0F 29 07` | SSE aligned store |
| `MOVNTI [RDI], RAX` | `0F C3 07` | Non-temporal store |

**String instructions** — source or destination at unmapped page:

| Instruction | Notes |
|-------------|-------|
| `REP MOVSB` | RSI or RDI at unmapped page |
| `REP STOSB` | RDI at unmapped page |
| `LODSB` | RSI at unmapped page |
| `CMPSB` | RSI or RDI at unmapped page |
| `SCASB` | RDI at unmapped page |

**Stack instructions** — RSP at unmapped page:

| Instruction | Notes |
|-------------|-------|
| `PUSH RAX` | RSP-8 at unmapped page |
| `POP RAX` | RSP at unmapped page |
| `CALL rel32` | RSP-8 at unmapped page |
| `RET` | RSP at unmapped page |
| `ENTER 0, 0` | RSP-16 at unmapped page |
| `LEAVE` | RBP at unmapped page |

**Additional #PF scenarios:**

- Write to a read-only page (error code has P=1, W=1)
- Instruction fetch from unmapped page (RIP points to unmapped memory)
- Multi-byte instruction spanning a page boundary where second page is
  unmapped (fault during instruction fetch)

#### 2. Division Error (#DE, vector 0) — DONE (18 tests)

Triggered by DIV/IDIV when the divisor is zero or the quotient overflows.

| Instruction | Setup | Notes |
|-------------|-------|-------|
| `DIV RCX` | RCX=0 | Divide by zero (64-bit) |
| `DIV ECX` | ECX=0 | Divide by zero (32-bit) |
| `DIV CX` | CX=0 | Divide by zero (16-bit) |
| `DIV CL` | CL=0 | Divide by zero (8-bit) |
| `IDIV RCX` | RCX=0 | Signed divide by zero |
| `IDIV ECX` | ECX=0 | Signed divide by zero |
| `IDIV CX` | CX=0 | Signed divide by zero |
| `IDIV CL` | CL=0 | Signed divide by zero |
| `DIV CL` | AX=0x100, CL=1 | Quotient overflow (256 > 255 for AL) |
| `IDIV CL` | AX=0x80, CL=1 | Signed quotient overflow (128 > 127 for AL) |
| `DIV ECX` | RDX:RAX large, ECX=1 | Quotient overflow (32-bit) |
| `IDIV ECX` | RDX:RAX large, ECX=1 | Signed quotient overflow (32-bit) |
| `DIV RCX` | RDX:RAX large, RCX=1 | Quotient overflow (64-bit) |

SDM: "#DE — If the source operand (divisor) is 0. If the quotient is too
large for the designated register."

#### 3. Invalid Opcode (#UD, vector 6) — DONE (6 tests)

Triggered by undefined or invalid instruction encodings.

| Test case | Notes | Status |
|-----------|-------|--------|
| `UD2` (`0F 0B`) | Explicit undefined instruction | DONE |
| `UD1` (`0F B9`) | Explicit undefined instruction | DONE |
| Invalid VEX prefix combinations | e.g., VEX.L=1 for 128-bit-only instructions | TODO |
| LOCK prefix on non-lockable instruction | e.g., `LOCK MOV`, `LOCK NOP` | DONE |
| LOCK with register dest on lockable op | e.g., `LOCK ADD RAX, RBX` | DONE |
| LOCK CMP with memory dest | CMP doesn't write, LOCK invalid | DONE |
| SSE instruction with mismatched prefix | | TODO |

#### 4. Alignment Check (#AC, vector 17)

Triggered when an unaligned memory access occurs with AC flag enabled
(CR0.AM=1, RFLAGS.AC=1, CPL=3).

| Instruction | Setup | Notes |
|-------------|-------|-------|
| `MOVAPS XMM0, [RDI]` | RDI not 16-aligned | SSE alignment requirement |
| `MOVAPD XMM0, [RDI]` | RDI not 16-aligned | SSE alignment requirement |
| `VMOVAPS YMM0, [RDI]` | RDI not 32-aligned | AVX alignment requirement |

Note: MOVAPS/MOVAPD always require alignment regardless of CR0.AM.
The #GP (not #AC) is raised for these — verify the correct exception
vector.

#### 5. General Protection Fault (#GP, vector 13) — DONE (7 tests)

| Test case | Notes | Status |
|-----------|-------|--------|
| `MOVAPS XMM0, [RDI]` | Unaligned load → #GP(0) | DONE |
| `MOVAPD XMM0, [RDI]` | Unaligned load → #GP(0) | DONE |
| `MOVAPS [RDI], XMM0` | Unaligned store → #GP(0) | DONE |
| `MOVAPD [RDI], XMM0` | Unaligned store → #GP(0) | DONE |
| `VMOVAPS XMM0, [RDI]` | VEX 128 unaligned → #GP(0) | DONE |
| `VMOVAPS [RDI], XMM0` | VEX 128 store unaligned → #GP(0) | DONE |
| `VMOVAPD XMM0, [RDI]` | VEX 128 unaligned → #GP(0) | DONE |
| `VMOVAPS YMM0, [RDI]` | VEX 256, 16-aligned not 32 → #GP(0) | DONE |
| Write to a read-only segment | (if segment limits are enforced) | N/A |

#### 6. Stack-Segment Fault (#SS, vector 12)

Rare in 64-bit mode with flat memory model, but could occur if RSP
points to a non-canonical address.

| Test case | Notes |
|-----------|-------|
| `PUSH RAX` | RSP = non-canonical address |
| `POP RAX` | RSP = non-canonical address |

#### 7. x87 Floating-Point Exception (#MF, vector 16)

Triggered when x87 instructions encounter unmasked FP exceptions.

| Test case | Notes |
|-----------|-------|
| `FDIV` with divisor=0 | If divide-by-zero exception unmasked |
| `FADD` with SNaN input | If invalid-operation exception unmasked |
| `WAIT`/`FWAIT` after pending x87 exception | Checks pending FPE |

#### 8. SIMD Floating-Point Exception (#XM, vector 19)

Triggered when SSE/AVX instructions encounter unmasked SIMD exceptions.

| Test case | Notes |
|-----------|-------|
| `DIVPS` with divisor=0 | If MXCSR divide-by-zero mask cleared |
| `ADDPS` with SNaN input | If MXCSR invalid-operation mask cleared |
| `CVTPS2DQ` with overflow | If MXCSR invalid-operation mask cleared |

### Test implementation priority

1. **#DE (division by zero)** — DONE (18 tests: div-by-zero all sizes,
   quotient overflow unsigned/signed all sizes, IDIV MIN/-1 overflow)
2. **#PF (page fault)** — Requires page table modification + Sail memory
   system changes. Essential for the munmap/SIGSEGV emulator changes.
3. **#UD (invalid opcode)** — DONE (6 tests: UD2, UD1, LOCK on reg dest,
   LOCK on non-lockable, LOCK CMP, LOCK NOP)
4. **#GP (alignment)** — DONE (7 tests; alignment checks added to
   MOVAPS/MOVAPD/VMOVAPS/VMOVAPD in Sail model)
5. **#MF/#XM (FP exceptions)** — BLOCKED. The Sail model does not check
   MXCSR exception mask bits or raise #XM. Requires touching all FP ops.
6. **#AC, #SS** — Edge cases, lowest priority.

### State to compare on fault

For fault-expecting tests, compare:

- Exception vector number (must match)
- Error code (must match; #PF encodes P/W/U/RSVD/I bits)
- RIP (should point at faulting instruction, not past it)
- For #PF: CR2 (faulting linear address) — requires reading CR2 from
  KVM vcpu state and from Sail model
