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

These bugs were in `usermode-emu/x86_externals.cpp`, the C implementations of
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

### 14. FXSAVE: MXCSR_MASK missing DAZ bit

**Bug:** The FXSAVE/XSAVE implementation wrote MXCSR_MASK as 0x0000FFFF,
which omits bit 17 (DAZ support). Real hardware reports 0x0002FFFF,
indicating that the DAZ bit in MXCSR is supported. Fixed by changing the
mask to 0x0002FFFF.

**SDM (Section 10.2.3, Table 10-3):** MXCSR_MASK indicates which MXCSR
bits are supported. Bit 6 (DAZ) is architecturally optional and its
support is indicated by bit 6 of MXCSR_MASK being set. Our emulator
already supports DAZ (bug 14 below), so the mask should reflect that.

**Verdict:** SDM is clear. MXCSR_MASK must accurately reflect supported
MXCSR bits. No SDM issue.

---

### 15. DAZ/FTZ: MXCSR denormal modes not implemented (commit 3c05739)

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

## Decoder Bugs

### 16. LZCNT/TZCNT: F3 prefix not checked (commit e418806)

**Bug:** The decoder did not check for the F3 prefix, so LZCNT/TZCNT were
always decoded as BSR/BSF.

**SDM:**
- LZCNT = `F3 0F BD /r`; BSR = `0F BD /r` (no F3 prefix)
- TZCNT = `F3 0F BC /r`; BSF = `0F BC /r` (no F3 prefix)

**Verdict:** SDM is clear. No SDM issue.

---

### 17. LOCK prefix not validated (commit 78ae1f1, ae40ee3)

**Bug:** The Sail model did not check the LOCK prefix (`has_lock`) at all.
Any instruction could be prefixed with LOCK without raising #UD. Fixed by
adding comprehensive LOCK validation:

- 1-byte opcodes: check `is_lockable_1byte` (ADD/OR/ADC/SBB/AND/SUB/XOR
  in Groups 1/3/4/5, but NOT CMP/TEST/MUL/DIV/PUSH)
- 2-byte opcodes: check `is_lockable_2byte` (BTS/BTR/BTC/CMPXCHG/XADD,
  but NOT BT)
- Both require memory destination (`check_lock_rm`)

**SDM:** "The LOCK prefix can be prepended only to the following
instructions and only to those forms of the instructions where the
destination operand is a memory operand."

**Verdict:** SDM is clear. No SDM issue.

---

### 18. MOVAPS/VMOVAPS: Missing alignment checks (commit 78ae1f1)

**Bug:** The Sail model did not check alignment for MOVAPS/MOVAPD (SSE,
16-byte) or VMOVAPS/VMOVAPD (VEX 128-bit: 16-byte, VEX 256-bit: 32-byte).
Unaligned accesses executed without raising #GP(0). Fixed by adding
alignment checks before memory reads/writes.

**SDM (MOVAPS):** "When the source or destination operand is a memory
operand, the operand must be aligned on a 16-byte boundary or a
general-protection exception (#GP) will be generated."

**Verdict:** SDM is clear. No SDM issue.

---

### 19. VEX.vvvv reserved field not checked (~25 instructions) (commits 60a1691, 4c3f36a)

**Bug:** Many 2-operand VEX instructions that don't use the vvvv field as a
source/destination did not check that vvvv == 1111b (reserved). A non-zero
vvvv was silently ignored instead of raising #UD. Affected instructions:

- VMOVAPS/VMOVAPD/VMOVUPS/VMOVUPD load and store
- VMOVDQA/VMOVDQU load and store
- VUCOMISS/VUCOMISD, VCOMISS/VCOMISD
- VCVTPS2PD/VCVTPD2PS (packed variants only; scalar uses vvvv)
- VCVTDQ2PS/VCVTPS2DQ/VCVTTPS2DQ
- VSQRTPS/VSQRTPD (packed variants only; scalar uses vvvv)
- VZEROUPPER/VZEROALL
- VBROADCASTSS/VBROADCASTSD/VBROADCASTF128
- VPBROADCASTB/VPBROADCASTW/VPBROADCASTD/VPBROADCASTQ
- VCVTPH2PS

**SDM:** Each instruction page states "VEX.vvvv is reserved and must be
1111b, otherwise instructions will #UD."

**Verdict:** SDM is clear. No SDM issue.

---

### 20. VEX.L not checked on 128-bit-only instructions (commit 633a11f)

**Bug:** VPINSRW, VPEXTRW, VMOVD, and VMOVQ did not check VEX.L and
allowed VEX.L=1 (256-bit) encoding without raising #UD.

Note: Scalar VEX instructions (VUCOMISS, VCVTSI2SS, etc.) do NOT #UD with
VEX.L=1 on real hardware — the L bit is silently ignored. This is not
documented clearly in the SDM.

**SDM:** Each instruction page states "VEX.L must be 0, otherwise
instructions will #UD."

**Verdict:** SDM is clear for packed/integer instructions. Scalar behavior
underdocumented.

---

### 21. 15-byte instruction length limit not enforced

**Bug:** The Sail model did not enforce the x86 15-byte maximum instruction
length. Instructions with more than 14 prefix bytes (e.g., 15 redundant `66`
prefixes + `NOP`) would execute successfully in the model while real hardware
raises #GP(0). The prefix scanner looped indefinitely on pathological inputs.

Fixed by adding a length check in `fetch_byte()`: if `decode_pos - insn_start
>= 15`, throw #GP(0). This covers all instruction bytes (prefixes, opcode,
ModR/M, SIB, displacement, and immediates) with a single check point. Also
added `insn_start` register to track instruction start position.

**SDM (Section 2.3.11, "AVX Instruction Length"):** "The instruction length,
including all prefixes, is limited to 15 bytes." Also SDM Vol. 3A Section
6.15: exceeding the limit causes #GP(0).

**Verdict:** SDM is clear. No SDM issue.

---

## Missing Features (discovered via KVM test coverage gaps)

The following instructions or instruction variants were not implemented in
the Sail model and were added after KVM testing revealed the gaps:

- CRC32 (all r32/r64 x r/m8/16/32/64 variants) — commit 29ecde4
- VUNPCKLPS/VUNPCKHPS/VUNPCKLPD/VUNPCKHPD — commit 57017c5
- VCMPPS/VCMPPD/VCMPSS/VCMPSD — commit 57017c5
- VCVTDQ2PS/VCVTPS2DQ/VCVTTPS2DQ — commit 57017c5
- VEX FMA3 (all 36 opcodes: 0F38 96-BF) — commit f6bdece
- VBROADCASTSS — commit fbf968d
- VPADDSB, VPADDUSB, VPSUBSB, VPSUBUSB, VUCOMISS, VUCOMISD — commit 8000fea
- BMI1: ANDN, BLSI, BLSMSK, BLSR, BEXTR — commit 4117d9e
- MOVBE (0F 38 F0/F1): byte-swap load/store, 16/32/64-bit
- VCMPPS/VCMPPD 256-bit paths (8 f32 / 4 f64 element comparison)
- VSHUFPS/VSHUFPD 256-bit paths (independent lane shuffles)
- XSAVE/XRSTOR (0F AE /4, 0F AE /5): extended state save/restore
- 66 0F D6: MOVQ xmm/m64, xmm (store direction) — was blocking clang
- VEX.128.66.0F D6: VMOVQ store direction

**Systematic opcode audit — ~100 VEX encodings added:**

- **VEX SSSE3** (0F38 00-0B, 1C-1E): VPSHUFB, VPHADDW/D/SW, VPMADDUBSW,
  VPHSUBW/D/SW, VPSIGNB/W/D, VPMULHRSW, VPABSB/W/D
- **VEX SSE4.1** (0F38 20-25, 28-2B, 30-35, 38-41): VPMOVSXBW/BD/BQ/WD/WQ/DQ,
  VPMOVZXBW/BD/BQ/WD/WQ/DQ, VPMULDQ, VPCMPEQQ, VMOVNTDQA, VPACKUSDW,
  VPMINSB/SD/UW/UD, VPMAXSB/SD/UW/UD, VPMULLD, VPHMINPOSUW
- **VEX 0F3A SSE4.1**: VROUNDPS/PD/SS/SD, VBLENDPS/PD, VPBLENDW, VPALIGNR,
  VPEXTRB/W/D/Q, VEXTRACTPS, VPINSRB/D/Q, VINSERTPS, VDPPS, VDPPD,
  VMPSADBW, VPCLMULQDQ
- **VEX 0F3A AVX2**: VPERMQ, VPERMPD, VPBLENDD
- **VEX 0F integer**: VPUNPCKLBW/WD/DQ, VPUNPCKHBW/WD/DQ, VPUNPCKLQDQ,
  VPUNPCKHQDQ, VPACKSSWB, VPACKUSWB, VPACKSSDW, VPCMPGTB/W/D,
  VPCMPEQB/W, VPMULLW, VPMULHUW, VPMULHW, VPMULUDQ, VPMADDWD,
  VPSADBW, VPAVGB/W, VPADDSB/W, VPADDUSB/W, VPSUBSB/W, VPSUBUSB/W,
  VPMINUB, VPMAXUB, VPMINSW
- **VEX shifts**: VPSRLW/D/Q, VPSRAW/D, VPSLLW/D/Q (shift-by-XMM),
  group 71/72/73 immediate shifts (VPSRLW/D/Q, VPSRAW/D, VPSLLW/D/Q,
  VPSRLDQ, VPSLLDQ)
- **AVX2**: VPERMPS, VPERMD, VPSRLVD/Q, VPSRAVD, VPSLLVD/Q
- **AVX FP**: VTESTPS/PD, VMASKMOVPS/PD (load and store)
- **BMI2**: BZHI, PDEP, PEXT, MULX, SARX, SHLX, SHRX, RORX
- **VEX AES-NI**: VAESENC, VAESENCLAST, VAESDEC, VAESDECLAST, VAESIMC,
  VAESKEYGENASSIST

**VEX 0F gap closure — remaining opcodes added:**

- **VEX 0F stores**: VMOVLPS store (0F 13), VMOVHPS store (0F 17),
  VMOVNTPS/VMOVNTPD (0F 2B)
- **VEX 0F conversions**: VCVTSS2SI/VCVTSD2SI (0F 2D), VCVTDQ2PD (0F E6 F3),
  VCVTPD2DQ (0F E6 F2), VCVTTPD2DQ (0F E6 66)
- **VEX 0F misc**: VMOVMSKPS/VMOVMSKPD (0F 50), VPMOVMSKB (0F D7),
  VPMAXSW (0F EE), VLDDQU (0F F0)
- **VEX gather (AVX2)**: VPGATHERDD/DQ (0F38 90/91), VGATHERDPS/DPD (0F38 92/93),
  VPGATHERQD/QQ (0F38 90/91 with W), VGATHERQPS/QPD (0F38 92/93 with W)
- **K-register ops**: KANDNW (0F 42), KORW (0F 45), KXNORW (0F 46),
  KUNPCKBW (0F 4B), KORTESTW (0F 98), KTESTW (0F 99),
  KMOV k,k/m16 (0F 90), KMOV m16,k (0F 91)
- **EVEX blend**: VPBLENDMD/Q (0F38 64), VBLENDMPS/PD (0F38 65),
  VPBLENDMB/W (0F38 66)

**VEX 0F remaining gap closure:**

- **VEX 0F SSE3**: VHADDPS/PD (0F 7C), VHSUBPS/PD (0F 7D),
  VADDSUBPS/PD (0F D0) — 128/256-bit
- **VEX 0F store**: VMOVNTDQ (0F E7), VMASKMOVDQU (0F F7)
- **VEX 0F38 permute**: VPERMILPS register (0F38 0C), VPERMILPD register (0F38 0D)
- **VEX 0F38 compare**: VPTEST (0F38 17), VPCMPGTQ (0F38 37)
- **VEX 0F38 masked**: VPMASKMOVD/Q load (0F38 8C), VPMASKMOVD/Q store (0F38 8E)
- **VEX 0F3A permute**: VPERMILPS imm (0F3A 04), VPERMILPD imm (0F3A 05),
  VPERM2F128 (0F3A 06), VPERM2I128 (0F3A 46)
- **VEX 0F3A AVX2**: VINSERTI128 (0F3A 38), VEXTRACTI128 (0F3A 39)

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
| 14 | FXSAVE MXCSR_MASK missing DAZ bit | C emulator | Yes | No |
| 15 | DAZ/FTZ denormal modes missing | C emulator | Yes | No |
| 16 | LZCNT/TZCNT F3 prefix not checked | Decoder | Yes | No |
| 17 | LOCK prefix not validated | Decoder | Yes | No |
| 18 | MOVAPS/VMOVAPS missing alignment #GP | Decoder | Yes | No |
| 19 | VEX.vvvv reserved not checked (~25 insns) | Decoder | Yes | No |
| 20 | VEX.L not checked on 128-bit-only insns | Decoder | Yes | No |
| 21 | 15-byte instruction length limit not enforced | Decoder | Yes | No |

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

The KVM differential test suite currently runs **122 ctest categories**. Tests compare architectural state (GPRs, flags,
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
- **VEX SSSE3**: VPSHUFB, VPHADDW/D/SW, VPMADDUBSW, VPHSUBW/D/SW,
  VPSIGNB/W/D, VPMULHRSW, VPABSB/W/D
- **VEX SSE4.1**: VPMOVSXBW/BD/BQ/WD/WQ/DQ, VPMOVZXBW/BD/BQ/WD/WQ/DQ,
  VPMULDQ, VPCMPEQQ, VPACKUSDW, VPMINSB/SD/UW/UD, VPMAXSB/SD/UW/UD,
  VPMULLD, VPHMINPOSUW
- **VEX 0F3A**: VBLENDPS/PD, VPBLENDW, VPALIGNR, VPEXTRB/D, VEXTRACTPS,
  VPINSRB/D, VPCLMULQDQ, VPBLENDD
- **VEX pack/unpack**: VPUNPCKLBW/WD/DQ, VPUNPCKHBW/WD/DQ, VPUNPCKLQDQ,
  VPUNPCKHQDQ, VPACKSSWB/VPACKUSWB/VPACKSSDW, VPCMPGTB/W/D, VPCMPEQB/W
- **VEX multiply**: VPMULLW, VPMULHUW, VPMULHW, VPMULUDQ, VPMADDWD,
  VPSADBW, VPAVGB/W
- **VEX saturating arith**: VPADDSB/W, VPADDUSB/W, VPSUBSB/W, VPSUBUSB/W,
  VPMINUB, VPMAXUB, VPMINSW
- **VEX shifts**: Shift-by-XMM (VPSRLW/D/Q, VPSRAW/D, VPSLLW/D/Q)
- **VEX imm shifts**: Group 71/72/73 immediate shifts (VPSRLW/D/Q,
  VPSRAW/D, VPSLLW/D/Q, VPSRLDQ, VPSLLDQ)
- **AVX2 var shifts**: VPSRLVD/Q, VPSRAVD, VPSLLVD/Q
- **VEX test**: VTESTPS, VTESTPD
- **MOVQ store**: 66 0F D6 (legacy) and VEX.128.66.0F D6
- **BMI2**: BZHI, PDEP, PEXT, MULX, SARX, SHLX, SHRX, RORX
- **VEX AES-NI**: VAESENC, VAESENCLAST, VAESDEC, VAESDECLAST, VAESIMC,
  VAESKEYGENASSIST
- **VEX 0F misc**: VMOVMSKPS, VMOVMSKPD, VPMOVMSKB, VCVTSS2SI, VCVTSD2SI,
  VCVTDQ2PD, VCVTPD2DQ, VCVTTPD2DQ, VPMAXSW, VMOVLPS store, VMOVHPS store
- **VEX gather**: VPGATHERDD (full mask, partial mask), VGATHERDPS
- **K-register ops**: KORTESTW (full/zero), KTESTW
- **EVEX blend**: VPBLENDMD, VBLENDMPS (no mask)
- **VLDDQU**: Unaligned 128-bit load
- **VEX horiz FP**: VHADDPS, VHSUBPS, VADDSUBPS, VHADDPD
- **VPTEST**: All-ones, zero+ones, ones+zero flag cases
- **VPCMPGTQ**: Signed qword comparison
- **VPERMIL**: VPERMILPS imm (reverse, broadcast), VPERMILPD imm (swap)
- **VMOVNTDQ**: Non-temporal store 128-bit, memory verification
- **VPERM2F128**: 256-bit lane permute with VINSERTF128 setup
- **VEX insert/extract i128**: VINSERTI128 (hi/lo), VEXTRACTI128 (hi/lo)
- **VPMASKMOVD**: Partial masked dword load
- **EVEX**: EVEX-encoded operations including VPADDD, VPXORD
- **XSAVE/XRSTOR**: Round-trip save/restore with various masks (x87,
  SSE, both), XRSTOR from pre-built XSAVE area, init path
  (XSTATE_BV=0), partial init (XSTATE_BV=1), high XMM registers
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
- **Exception #DE**: DIV/IDIV divide-by-zero and quotient overflow
- **Exception #UD**: UD2, UD1, LOCK violations, VEX.L/vvvv checks,
  memory-only register form, 256-only L=0 checks
- **Exception #GP**: MOVAPS/VMOVAPS/VMOVAPD alignment checks (128/256-bit),
  15-byte instruction length limit violations

### Boundary value test set (30 values)

The ALU stratified tests use a 30-value boundary set generating 900 input
pairs per operation/size. Values include: zero, ±1, ±2, signed min/max at
8/16/32/64-bit widths, unsigned max at all widths, MAX-1 and MIN+1 for
off-by-one detection, size-boundary crossings (UINT8_MAX+1, UINT16_MAX+1),
alternating bit patterns, a 32/64-bit boundary value, sign-extension edge
(0xFFFFFFFF00000000), and a non-trivial mixed pattern.

### Known test coverage gaps

- **AVX2 gather 256-bit**: Only 128-bit VPGATHERDD/VGATHERDPS tested;
  256-bit and qword-index variants need tests
- **VPMASKMOVD/Q store**: Only load direction tested; store tests needed
- **256-bit tests**: Most new VEX tests are 128-bit only; 256-bit
  variants should be added
- **EVEX masking/zeroing**: Only no-mask EVEX blend tested; writemask
  and zeroing-mask KVM tests needed
- **K-register full set**: Only KORTESTW/KTESTW tested; KANDW/KORW/KNOTW/
  KXORW/KANDNW/KXNORW/KUNPCKBW/KMOV need KVM tests
- **EVEX conflict detection**: VPCONFLICTD/Q, VPLZCNTD/Q
- **512-bit EVEX**: Requires host AVX-512 support
- **x87 transcendentals**: FSIN, FCOS, FPTAN precision matching is fragile
- **BT/BTS/BTR/BTC with memory**: Bit offset extending beyond addressed
  byte (requires memory-form tests with large bit indices)
- **LOCK prefix**: Atomic memory operations (LOCK validation is tested,
  but actual atomic semantics require multi-threaded tests)
- **Segment overrides**: Not applicable in 64-bit flat memory model

### Implementation Roadmap

Prioritized list of test coverage improvements to implement. Each item
is self-contained and should be committed separately.

#### Item 1: x87 FPU — expand coverage (HIGH priority) ✅ DONE

Added 24 tests in "x87 mem" category covering:
- D8 memory forms (FADD/FSUB/FMUL/FDIV m32fp)
- DC memory forms (FADD/FSUB/FMUL/FDIV m64fp)
- DA integer ops (FIADD/FISUB/FIMUL/FIDIV m32int)
- DE integer ops with pop (FADDP/FSUBP/FMULP/FDIVP)
- FCMOVcc (DA C0-DF range), FSINCOS (D9 FB), FISTTP (DF /1)
- FCOMIP (DB F1), FSUBR/FDIVR reverse operations

#### Item 2: EVEX writemask (k-register masking) tests (HIGH priority) ✅ DONE

Added 9 tests in "EVEX mask" category covering merge and zero masking
for VPADDD, VADDPS, VPXORD at 128-bit and 256-bit widths.

**Bugs found and fixed:**
1. **Sail model: writemask not applied for 128/256-bit EVEX paths.**
   Only the 512-bit (ZMM) paths applied the opmask writemask. Added
   `apply_writemask_ps_xmm`, `apply_writemask_ps_ymm`,
   `apply_writemask_pd_xmm`, `apply_writemask_pd_ymm` helpers in
   `insn_evex.sail`, and updated VPADDD, VPSUBD, VPADDQ, VPSUBQ,
   VPXORD, VPANDD, VPORD, VADDPS in their 128/256-bit paths.
2. **KVM harness: wrong XSAVE offset for opmask registers.**
   Was using 0x440; correct offset is 0x340 (CPUID leaf 0xD subleaf 5
   returns EBX=0x340 on this CPU). Fixed in load_test() and run_test().

#### Item 3: K-register operations (MEDIUM priority) ✅ DONE

Added 10 tests to "K-register ops" category (joining 4 existing
KORTESTW/KTESTW tests) covering:
- KANDW, KORW, KXORW, KANDNW, KXNORW, KNOTW logical operations
- KUNPCKBW byte interleave
- KMOVW memory load and store

**Bug found and fixed:** Sail model's KUNPCKBW (opcode 0F 4B) did not
distinguish mandatory prefix: KUNPCKBW requires 66 prefix (pp=01),
while NP (pp=00) encodes KUNPCKWD. Added mp dispatch to handle both.

#### Item 4: SSE/VEX memory store verification (MEDIUM priority)

Many vector store instructions are tested for register effects but
not for memory output correctness.

**Tests to add:**
- MOVAPS [mem], xmm — verify 16 bytes written
- MOVUPS [mem], xmm — verify 16 bytes written
- MOVDQU [mem], xmm — verify 16 bytes written
- VMOVAPS [mem], xmm/ymm — verify 16/32 bytes
- VMOVDQU [mem], xmm — verify 16 bytes
- VMOVNTDQ [mem], xmm — already has 1 test; add ymm variant
- MOVLPS/MOVHPS [mem], xmm — verify 8 bytes (partial store)
- MOVSS [mem], xmm — verify 4 bytes
- MOVSD [mem], xmm — verify 8 bytes

#### Item 5: LOCK prefix memory operations (MEDIUM priority)

LOCK validation (#UD) is tested, but actual LOCK'd memory semantics
are not.

**Tests to add:**
- LOCK ADD [mem], reg (all sizes)
- LOCK SUB [mem], reg
- LOCK INC [mem] / LOCK DEC [mem]
- LOCK BTS [mem], reg / LOCK BTR [mem], reg / LOCK BTC [mem], reg
- LOCK XADD [mem], reg (verify both memory and register results)
- LOCK OR [mem], imm / LOCK AND [mem], imm

#### Item 6: Indirect JMP/CALL (LOW priority)

Only direct JMP/CALL tested. Need:
- JMP rax (FF /4 reg)
- JMP [mem] (FF /4 mem)
- CALL rax (FF /2 reg)
- CALL [mem] (FF /2 mem)

#### Item 7: PUSH/POP memory operands (LOW priority)

- PUSH [mem] (FF /6)
- POP [mem] (8F /0)
- PUSH imm16 (66 68 imm16)

#### Item 8: FP conversion edge cases (LOW priority)

- CVTPS2PD with denormals, NaN, Inf, -0
- CVTPD2PS with precision loss (large doubles)
- CVTSD2SS round-trip precision
- CVTSI2SS with large integers (rounding)

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

**Tests implemented: 78 tests across 3 exception categories.**

**Bugs found and fixed:**
- MOVAPS/MOVAPD (SSE): missing 16-byte alignment check → added #GP(0)
- VMOVAPS/VMOVAPD (VEX 128): missing 16-byte alignment check → added #GP(0)
- VMOVAPS/VMOVAPD (VEX 256): missing 32-byte alignment check → added #GP(0)
- VMOVAPS/VMOVAPD store (VEX): missing alignment checks → added #GP(0)
- LOCK prefix: model didn't check `has_lock` at all → added comprehensive
  LOCK validation for 1-byte and 2-byte opcodes (lockable opcode check +
  register-vs-memory check + CMP exclusion)
- LOCK on 2-byte lockable instructions (CMPXCHG, XADD, BTS, BTR, BTC):
  missing register-vs-memory check → added `check_lock_rm` calls
- Group 8 (0F BA): BT (/4) incorrectly allowed with LOCK → added #UD
- VEX.L=1 on VPINSRW, VPEXTRW, VMOVD/VMOVQ: missing VEX.L check → added #UD
- VCMPPS/VCMPPD 256-bit: not implemented → added 256-bit paths
- VSHUFPS/VSHUFPD 256-bit: not implemented → added 256-bit paths
- avx_test `_start`: missing `force_align_arg_pointer` attribute
- VEX.vvvv reserved field: ~25 instructions missing `vex_vvvv != 0` check →
  added #UD for VMOVAPS/VMOVAPD/VMOVUPS/VMOVUPD load/store,
  VMOVDQA/VMOVDQU load/store, VUCOMISS/VUCOMISD, VCOMISS/VCOMISD,
  VCVTPS2PD/VCVTPD2PS, VCVTDQ2PS/VCVTPS2DQ/VCVTTPS2DQ, VSQRTPS/VSQRTPD,
  VZEROUPPER/VZEROALL, VBROADCASTSS/VBROADCASTSD/VBROADCASTF128,
  VPBROADCASTB/VPBROADCASTW/VPBROADCASTD/VPBROADCASTQ, VCVTPH2PS
- 15-byte instruction length limit: model didn't enforce max instruction
  length → added #GP(0) check in fetch_byte() with insn_start tracking

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

#### 3. Invalid Opcode (#UD, vector 6) — DONE (45 tests)

Triggered by undefined or invalid instruction encodings.

| Test case | Notes | Status |
|-----------|-------|--------|
| `UD2` (`0F 0B`) | Explicit undefined instruction | DONE |
| `UD1` (`0F B9`) | Explicit undefined instruction | DONE |
| VEX.L=1 on 128-bit-only instructions | VPINSRW, VPEXTRW, VMOVD (both dirs) | DONE |
| LOCK prefix on non-lockable instruction | e.g., `LOCK MOV`, `LOCK NOP`, `LOCK PUSH` | DONE |
| LOCK with register dest on lockable op | e.g., `LOCK ADD RAX, RBX` | DONE |
| LOCK CMP with memory dest | CMP doesn't write, LOCK invalid | DONE |
| LOCK on non-lockable 2-byte | e.g., `LOCK MOVZX`, `LOCK BSF` | DONE |
| LOCK on lockable 2-byte with reg dest | `LOCK CMPXCHG`, `LOCK XADD` | DONE |
| LOCK INC/NEG with reg dest | Group 4/5 and Group 3 | DONE |
| LOCK MUL/DIV | Not lockable even within Group 3 | DONE |
| VEX.vvvv reserved on move instructions | VMOVAPS/VMOVAPD/VMOVUPS/VMOVUPD/VMOVDQA/VMOVDQU | DONE |
| VEX.vvvv reserved on compare/convert | VUCOMISS/VUCOMISD/VCOMISS/VCOMISD, VCVTPS2PD/VCVTPD2PS | DONE |
| VEX.vvvv reserved on unary ops | VSQRTPS/VSQRTPD, VCVTDQ2PS/VCVTPS2DQ/VCVTTPS2DQ, VCVTPH2PS | DONE |
| VEX.vvvv reserved on broadcasts | VBROADCASTSS/SD/F128, VPBROADCASTB/W/D/Q | DONE |
| VEX.vvvv reserved on VZEROUPPER | VZEROUPPER/VZEROALL | DONE |
| VEX memory-only reg form | VBROADCASTF128 reg form → #UD | DONE |
| VEX.L=0 on 256-only instructions | VBROADCASTSD, VEXTRACTF128, VINSERTF128 | DONE |
| SSE instruction with mismatched prefix | F2/F3 on legacy SSE silently ignored, not #UD | N/A |

Note: Scalar VEX instructions (VUCOMISS, VCVTSI2SS, VCVTTSS2SI, etc.)
do NOT #UD with VEX.L=1 on real hardware — the L bit is silently ignored.

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

#### 5. General Protection Fault (#GP, vector 13) — DONE (15 tests)

| Test case | Notes | Status |
|-----------|-------|--------|
| `MOVAPS XMM0, [RDI]` | Unaligned load → #GP(0) | DONE |
| `MOVAPD XMM0, [RDI]` | Unaligned load → #GP(0) | DONE |
| `MOVAPS [RDI], XMM0` | Unaligned store → #GP(0) | DONE |
| `MOVAPD [RDI], XMM0` | Unaligned store → #GP(0) | DONE |
| `VMOVAPS XMM0, [RDI]` | VEX 128 unaligned → #GP(0) | DONE |
| `VMOVAPS [RDI], XMM0` | VEX 128 store unaligned → #GP(0) | DONE |
| `VMOVAPD XMM0, [RDI]` | VEX 128 unaligned → #GP(0) | DONE |
| `VMOVAPD [RDI], XMM0` | VEX 128 store unaligned → #GP(0) | DONE |
| `VMOVAPS YMM0, [RDI]` | VEX 256, 16-aligned not 32 → #GP(0) | DONE |
| `VMOVAPD YMM0, [RDI]` | VEX 256, 16-aligned not 32 → #GP(0) | DONE |
| `VMOVAPS [RDI], YMM0` | VEX 256 store, 16-aligned not 32 → #GP(0) | DONE |
| `VMOVAPD [RDI], YMM0` | VEX 256 store, 16-aligned not 32 → #GP(0) | DONE |
| 15×66 + NOP (16 bytes) | Exceeds 15-byte instruction length limit → #GP(0) | DONE |
| 14×66 + 3-byte NOP (17 bytes) | Exceeds limit with multi-byte opcode → #GP(0) | DONE |
| 15×F3 + NOP (16 bytes) | Exceeds limit with REP prefix → #GP(0) | DONE |
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
3. **#UD (invalid opcode)** — DONE (45 tests: UD2, UD1, LOCK violations,
   VEX.L checks, VEX.vvvv reserved, memory-only reg form, 256-only L=0)
4. **#GP (alignment + length)** — DONE (15 tests; alignment checks for
   MOVAPS/MOVAPD/VMOVAPS/VMOVAPD load and store 128/256-bit, plus
   15-byte instruction length limit enforcement)
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
