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

## Decoder Bug

### 6. LZCNT/TZCNT: F3 prefix not checked (commit e418806)

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

---

## Summary Table

| # | Bug | SDM Clear? | SDM Issue? |
|---|-----|-----------|------------|
| 1 | SHLD CF wrong bit | Yes | No |
| 2 | INC/DEC CF not preserved | Yes | No |
| 3a | SHL r32,0 no zero-extend | **Inconsistent** | **Yes — pseudocode contradicts §3.4.1.1** |
| 3b | SHL/SHR flags for large counts | Yes | No |
| 4 | PMULLW/PMULHW swapped | Yes | No |
| 5 | PHSUBW operand order | Yes | No |
| 6 | LZCNT/TZCNT vs BSF/BSR | Yes | No |

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
