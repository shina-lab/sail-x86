// AVX-512 Mask Register (k*) Instructions
//
// These instructions operate on opmask registers k0-k7.
// We use external functions for mask register access since we don't have
// mask register infrastructure yet.

val __read_kreg : int -> qword
val __write_kreg : (int, qword) -> unit

// =========================================================================
// KADD -- Add Mask Registers
// =========================================================================

val exec_kaddb : (int, int, int) -> ExecutionResult
function exec_kaddb(dst, src1, src2) = {
  let a : byte = __read_kreg(src1)[7..0];
  let b : byte = __read_kreg(src2)[7..0];
  __write_kreg(dst, zero_extend(a + b));
  Ok(())
}

val exec_kaddw : (int, int, int) -> ExecutionResult
function exec_kaddw(dst, src1, src2) = {
  let a : word = __read_kreg(src1)[15..0];
  let b : word = __read_kreg(src2)[15..0];
  __write_kreg(dst, zero_extend(a + b));
  Ok(())
}

val exec_kaddd : (int, int, int) -> ExecutionResult
function exec_kaddd(dst, src1, src2) = {
  let a : dword = __read_kreg(src1)[31..0];
  let b : dword = __read_kreg(src2)[31..0];
  __write_kreg(dst, zero_extend(a + b));
  Ok(())
}

val exec_kaddq : (int, int, int) -> ExecutionResult
function exec_kaddq(dst, src1, src2) = {
  let a : qword = __read_kreg(src1);
  let b : qword = __read_kreg(src2);
  __write_kreg(dst, a + b);
  Ok(())
}

// =========================================================================
// KAND -- Bitwise Logical AND Mask Registers
// =========================================================================

val exec_kandb : (int, int, int) -> ExecutionResult
function exec_kandb(dst, src1, src2) = {
  let a : byte = __read_kreg(src1)[7..0];
  let b : byte = __read_kreg(src2)[7..0];
  __write_kreg(dst, zero_extend(a & b));
  Ok(())
}

val exec_kandw : (int, int, int) -> ExecutionResult
function exec_kandw(dst, src1, src2) = {
  let a : word = __read_kreg(src1)[15..0];
  let b : word = __read_kreg(src2)[15..0];
  __write_kreg(dst, zero_extend(a & b));
  Ok(())
}

val exec_kandd : (int, int, int) -> ExecutionResult
function exec_kandd(dst, src1, src2) = {
  let a : dword = __read_kreg(src1)[31..0];
  let b : dword = __read_kreg(src2)[31..0];
  __write_kreg(dst, zero_extend(a & b));
  Ok(())
}

val exec_kandq : (int, int, int) -> ExecutionResult
function exec_kandq(dst, src1, src2) = {
  let a : qword = __read_kreg(src1);
  let b : qword = __read_kreg(src2);
  __write_kreg(dst, a & b);
  Ok(())
}

// =========================================================================
// KANDN -- Bitwise Logical AND NOT Mask Registers
// =========================================================================

val exec_kandnb : (int, int, int) -> ExecutionResult
function exec_kandnb(dst, src1, src2) = {
  let a : byte = __read_kreg(src1)[7..0];
  let b : byte = __read_kreg(src2)[7..0];
  __write_kreg(dst, zero_extend((~(a)) & b));
  Ok(())
}

val exec_kandnw : (int, int, int) -> ExecutionResult
function exec_kandnw(dst, src1, src2) = {
  let a : word = __read_kreg(src1)[15..0];
  let b : word = __read_kreg(src2)[15..0];
  __write_kreg(dst, zero_extend((~(a)) & b));
  Ok(())
}

val exec_kandnd : (int, int, int) -> ExecutionResult
function exec_kandnd(dst, src1, src2) = {
  let a : dword = __read_kreg(src1)[31..0];
  let b : dword = __read_kreg(src2)[31..0];
  __write_kreg(dst, zero_extend((~(a)) & b));
  Ok(())
}

val exec_kandnq : (int, int, int) -> ExecutionResult
function exec_kandnq(dst, src1, src2) = {
  let a : qword = __read_kreg(src1);
  let b : qword = __read_kreg(src2);
  __write_kreg(dst, (~(a)) & b);
  Ok(())
}

// =========================================================================
// KMOV -- Move Mask Register
// =========================================================================

// KMOV kreg, kreg
val exec_kmovb_kreg_kreg : (int, int) -> ExecutionResult
function exec_kmovb_kreg_kreg(dst, src) = {
  __write_kreg(dst, zero_extend(__read_kreg(src)[7..0]));
  Ok(())
}

val exec_kmovw_kreg_kreg : (int, int) -> ExecutionResult
function exec_kmovw_kreg_kreg(dst, src) = {
  __write_kreg(dst, zero_extend(__read_kreg(src)[15..0]));
  Ok(())
}

val exec_kmovd_kreg_kreg : (int, int) -> ExecutionResult
function exec_kmovd_kreg_kreg(dst, src) = {
  __write_kreg(dst, zero_extend(__read_kreg(src)[31..0]));
  Ok(())
}

val exec_kmovq_kreg_kreg : (int, int) -> ExecutionResult
function exec_kmovq_kreg_kreg(dst, src) = {
  __write_kreg(dst, __read_kreg(src));
  Ok(())
}

// KMOV kreg, GPR
val exec_kmovb_kreg_gpr : (int, dword) -> ExecutionResult
function exec_kmovb_kreg_gpr(dst, src) = {
  __write_kreg(dst, zero_extend(src[7..0]));
  Ok(())
}

val exec_kmovw_kreg_gpr : (int, dword) -> ExecutionResult
function exec_kmovw_kreg_gpr(dst, src) = {
  __write_kreg(dst, zero_extend(src[15..0]));
  Ok(())
}

val exec_kmovd_kreg_gpr : (int, dword) -> ExecutionResult
function exec_kmovd_kreg_gpr(dst, src) = {
  __write_kreg(dst, zero_extend(src));
  Ok(())
}

val exec_kmovq_kreg_gpr : (int, qword) -> ExecutionResult
function exec_kmovq_kreg_gpr(dst, src) = {
  __write_kreg(dst, src);
  Ok(())
}

// KMOV GPR, kreg
val exec_kmovb_gpr_kreg : (gpr_idx, int) -> ExecutionResult
function exec_kmovb_gpr_kreg(dst, src) = {
  write_gpr(dst, OS32, zero_extend(__read_kreg(src)[7..0]));
  Ok(())
}

val exec_kmovw_gpr_kreg : (gpr_idx, int) -> ExecutionResult
function exec_kmovw_gpr_kreg(dst, src) = {
  write_gpr(dst, OS32, zero_extend(__read_kreg(src)[15..0]));
  Ok(())
}

val exec_kmovd_gpr_kreg : (gpr_idx, int) -> ExecutionResult
function exec_kmovd_gpr_kreg(dst, src) = {
  write_gpr(dst, OS32, zero_extend(__read_kreg(src)[31..0]));
  Ok(())
}

val exec_kmovq_gpr_kreg : (gpr_idx, int) -> ExecutionResult
function exec_kmovq_gpr_kreg(dst, src) = {
  write_gpr(dst, OS64, __read_kreg(src));
  Ok(())
}

// =========================================================================
// KNOT -- NOT Mask Register
// =========================================================================

val exec_knotb : (int, int) -> ExecutionResult
function exec_knotb(dst, src) = {
  __write_kreg(dst, zero_extend(~(__read_kreg(src)[7..0])));
  Ok(())
}

val exec_knotw : (int, int) -> ExecutionResult
function exec_knotw(dst, src) = {
  __write_kreg(dst, zero_extend(~(__read_kreg(src)[15..0])));
  Ok(())
}

val exec_knotd : (int, int) -> ExecutionResult
function exec_knotd(dst, src) = {
  __write_kreg(dst, zero_extend(~(__read_kreg(src)[31..0])));
  Ok(())
}

val exec_knotq : (int, int) -> ExecutionResult
function exec_knotq(dst, src) = {
  __write_kreg(dst, ~(__read_kreg(src)));
  Ok(())
}

// =========================================================================
// KOR -- Bitwise Logical OR Mask Registers
// =========================================================================

val exec_korb : (int, int, int) -> ExecutionResult
function exec_korb(dst, src1, src2) = {
  __write_kreg(dst, zero_extend(__read_kreg(src1)[7..0] | __read_kreg(src2)[7..0]));
  Ok(())
}

val exec_korw : (int, int, int) -> ExecutionResult
function exec_korw(dst, src1, src2) = {
  __write_kreg(dst, zero_extend(__read_kreg(src1)[15..0] | __read_kreg(src2)[15..0]));
  Ok(())
}

val exec_kord : (int, int, int) -> ExecutionResult
function exec_kord(dst, src1, src2) = {
  __write_kreg(dst, zero_extend(__read_kreg(src1)[31..0] | __read_kreg(src2)[31..0]));
  Ok(())
}

val exec_korq : (int, int, int) -> ExecutionResult
function exec_korq(dst, src1, src2) = {
  __write_kreg(dst, __read_kreg(src1) | __read_kreg(src2));
  Ok(())
}

// =========================================================================
// KORTEST -- OR Mask and Set Flags
// =========================================================================

val exec_kortestb : (int, int) -> ExecutionResult
function exec_kortestb(src1, src2) = {
  let tmp : byte = __read_kreg(src1)[7..0] | __read_kreg(src2)[7..0];
  ZF = if tmp == 0x00 then bitone else bitzero;
  CF = if tmp == 0xFF then bitone else bitzero;
  SF = bitzero;
  OF = bitzero;
  AF = bitzero;
  PF = bitzero;
  Ok(())
}

val exec_kortestw : (int, int) -> ExecutionResult
function exec_kortestw(src1, src2) = {
  let tmp : word = __read_kreg(src1)[15..0] | __read_kreg(src2)[15..0];
  ZF = if tmp == 0x0000 then bitone else bitzero;
  CF = if tmp == 0xFFFF then bitone else bitzero;
  SF = bitzero;
  OF = bitzero;
  AF = bitzero;
  PF = bitzero;
  Ok(())
}

val exec_kortestd : (int, int) -> ExecutionResult
function exec_kortestd(src1, src2) = {
  let tmp : dword = __read_kreg(src1)[31..0] | __read_kreg(src2)[31..0];
  ZF = if tmp == 0x00000000 then bitone else bitzero;
  CF = if tmp == 0xFFFFFFFF then bitone else bitzero;
  SF = bitzero;
  OF = bitzero;
  AF = bitzero;
  PF = bitzero;
  Ok(())
}

val exec_kortestq : (int, int) -> ExecutionResult
function exec_kortestq(src1, src2) = {
  let tmp : qword = __read_kreg(src1) | __read_kreg(src2);
  ZF = if tmp == 0x0000000000000000 then bitone else bitzero;
  CF = if tmp == 0xFFFFFFFFFFFFFFFF then bitone else bitzero;
  SF = bitzero;
  OF = bitzero;
  AF = bitzero;
  PF = bitzero;
  Ok(())
}

// =========================================================================
// KSHIFTL -- Shift Left Mask Register
// =========================================================================

val exec_kshiftlb : (int, int, byte) -> ExecutionResult
function exec_kshiftlb(dst, src, imm8) = {
  let count : int = unsigned(imm8);
  let result : byte = if count <= 7 then shift_bits_left(__read_kreg(src)[7..0], imm8[2..0]) else 0x00;
  __write_kreg(dst, zero_extend(result));
  Ok(())
}

val exec_kshiftlw : (int, int, byte) -> ExecutionResult
function exec_kshiftlw(dst, src, imm8) = {
  let count : int = unsigned(imm8);
  let result : word = if count <= 15 then shift_bits_left(__read_kreg(src)[15..0], imm8[3..0]) else 0x0000;
  __write_kreg(dst, zero_extend(result));
  Ok(())
}

val exec_kshiftld : (int, int, byte) -> ExecutionResult
function exec_kshiftld(dst, src, imm8) = {
  let count : int = unsigned(imm8);
  let result : dword = if count <= 31 then shift_bits_left(__read_kreg(src)[31..0], imm8[4..0]) else 0x00000000;
  __write_kreg(dst, zero_extend(result));
  Ok(())
}

val exec_kshiftlq : (int, int, byte) -> ExecutionResult
function exec_kshiftlq(dst, src, imm8) = {
  let count : int = unsigned(imm8);
  let result : qword = if count <= 63 then shift_bits_left(__read_kreg(src), imm8[5..0]) else 0x0000000000000000;
  __write_kreg(dst, result);
  Ok(())
}

// =========================================================================
// KSHIFTR -- Shift Right Mask Register
// =========================================================================

val exec_kshiftrb : (int, int, byte) -> ExecutionResult
function exec_kshiftrb(dst, src, imm8) = {
  let count : int = unsigned(imm8);
  let result : byte = if count <= 7 then shift_bits_right(__read_kreg(src)[7..0], imm8[2..0]) else 0x00;
  __write_kreg(dst, zero_extend(result));
  Ok(())
}

val exec_kshiftrw : (int, int, byte) -> ExecutionResult
function exec_kshiftrw(dst, src, imm8) = {
  let count : int = unsigned(imm8);
  let result : word = if count <= 15 then shift_bits_right(__read_kreg(src)[15..0], imm8[3..0]) else 0x0000;
  __write_kreg(dst, zero_extend(result));
  Ok(())
}

val exec_kshiftrd : (int, int, byte) -> ExecutionResult
function exec_kshiftrd(dst, src, imm8) = {
  let count : int = unsigned(imm8);
  let result : dword = if count <= 31 then shift_bits_right(__read_kreg(src)[31..0], imm8[4..0]) else 0x00000000;
  __write_kreg(dst, zero_extend(result));
  Ok(())
}

val exec_kshiftrq : (int, int, byte) -> ExecutionResult
function exec_kshiftrq(dst, src, imm8) = {
  let count : int = unsigned(imm8);
  let result : qword = if count <= 63 then shift_bits_right(__read_kreg(src), imm8[5..0]) else 0x0000000000000000;
  __write_kreg(dst, result);
  Ok(())
}

// =========================================================================
// KTEST -- AND Mask and Set Flags
// =========================================================================

val exec_ktestb : (int, int) -> ExecutionResult
function exec_ktestb(src1, src2) = {
  let s1 : byte = __read_kreg(src1)[7..0];
  let s2 : byte = __read_kreg(src2)[7..0];
  let tmp1 : byte = s2 & s1;
  let tmp2 : byte = s2 & ~(s1);
  ZF = if tmp1 == 0x00 then bitone else bitzero;
  CF = if tmp2 == 0x00 then bitone else bitzero;
  SF = bitzero;
  OF = bitzero;
  AF = bitzero;
  PF = bitzero;
  Ok(())
}

val exec_ktestw : (int, int) -> ExecutionResult
function exec_ktestw(src1, src2) = {
  let s1 : word = __read_kreg(src1)[15..0];
  let s2 : word = __read_kreg(src2)[15..0];
  let tmp1 : word = s2 & s1;
  let tmp2 : word = s2 & ~(s1);
  ZF = if tmp1 == 0x0000 then bitone else bitzero;
  CF = if tmp2 == 0x0000 then bitone else bitzero;
  SF = bitzero;
  OF = bitzero;
  AF = bitzero;
  PF = bitzero;
  Ok(())
}

val exec_ktestd : (int, int) -> ExecutionResult
function exec_ktestd(src1, src2) = {
  let s1 : dword = __read_kreg(src1)[31..0];
  let s2 : dword = __read_kreg(src2)[31..0];
  let tmp1 : dword = s2 & s1;
  let tmp2 : dword = s2 & ~(s1);
  ZF = if tmp1 == 0x00000000 then bitone else bitzero;
  CF = if tmp2 == 0x00000000 then bitone else bitzero;
  SF = bitzero;
  OF = bitzero;
  AF = bitzero;
  PF = bitzero;
  Ok(())
}

val exec_ktestq : (int, int) -> ExecutionResult
function exec_ktestq(src1, src2) = {
  let s1 : qword = __read_kreg(src1);
  let s2 : qword = __read_kreg(src2);
  let tmp1 : qword = s2 & s1;
  let tmp2 : qword = s2 & ~(s1);
  ZF = if tmp1 == 0x0000000000000000 then bitone else bitzero;
  CF = if tmp2 == 0x0000000000000000 then bitone else bitzero;
  SF = bitzero;
  OF = bitzero;
  AF = bitzero;
  PF = bitzero;
  Ok(())
}

// =========================================================================
// KUNPCK -- Unpack Mask Registers
// =========================================================================

// KUNPCKBW: DEST[7:0] = SRC2[7:0], DEST[15:8] = SRC1[7:0]
val exec_kunpckbw : (int, int, int) -> ExecutionResult
function exec_kunpckbw(dst, src1, src2) = {
  let lo : byte = __read_kreg(src2)[7..0];
  let hi : byte = __read_kreg(src1)[7..0];
  __write_kreg(dst, zero_extend(hi @ lo));
  Ok(())
}

// KUNPCKWD: DEST[15:0] = SRC2[15:0], DEST[31:16] = SRC1[15:0]
val exec_kunpckwd : (int, int, int) -> ExecutionResult
function exec_kunpckwd(dst, src1, src2) = {
  let lo : word = __read_kreg(src2)[15..0];
  let hi : word = __read_kreg(src1)[15..0];
  __write_kreg(dst, zero_extend(hi @ lo));
  Ok(())
}

// KUNPCKDQ: DEST[31:0] = SRC2[31:0], DEST[63:32] = SRC1[31:0]
val exec_kunpckdq : (int, int, int) -> ExecutionResult
function exec_kunpckdq(dst, src1, src2) = {
  let lo : dword = __read_kreg(src2)[31..0];
  let hi : dword = __read_kreg(src1)[31..0];
  __write_kreg(dst, hi @ lo);
  Ok(())
}

// =========================================================================
// KXNOR -- Bitwise Logical XNOR Mask Registers
// =========================================================================

val exec_kxnorb : (int, int, int) -> ExecutionResult
function exec_kxnorb(dst, src1, src2) = {
  __write_kreg(dst, zero_extend(~(xor_vec(__read_kreg(src1)[7..0], __read_kreg(src2)[7..0]))));
  Ok(())
}

val exec_kxnorw : (int, int, int) -> ExecutionResult
function exec_kxnorw(dst, src1, src2) = {
  __write_kreg(dst, zero_extend(~(xor_vec(__read_kreg(src1)[15..0], __read_kreg(src2)[15..0]))));
  Ok(())
}

val exec_kxnord : (int, int, int) -> ExecutionResult
function exec_kxnord(dst, src1, src2) = {
  __write_kreg(dst, zero_extend(~(xor_vec(__read_kreg(src1)[31..0], __read_kreg(src2)[31..0]))));
  Ok(())
}

val exec_kxnorq : (int, int, int) -> ExecutionResult
function exec_kxnorq(dst, src1, src2) = {
  __write_kreg(dst, ~(xor_vec(__read_kreg(src1), __read_kreg(src2))));
  Ok(())
}

// =========================================================================
// KXOR -- Bitwise Logical XOR Mask Registers
// =========================================================================

val exec_kxorb : (int, int, int) -> ExecutionResult
function exec_kxorb(dst, src1, src2) = {
  __write_kreg(dst, zero_extend(xor_vec(__read_kreg(src1)[7..0], __read_kreg(src2)[7..0])));
  Ok(())
}

val exec_kxorw : (int, int, int) -> ExecutionResult
function exec_kxorw(dst, src1, src2) = {
  __write_kreg(dst, zero_extend(xor_vec(__read_kreg(src1)[15..0], __read_kreg(src2)[15..0])));
  Ok(())
}

val exec_kxord : (int, int, int) -> ExecutionResult
function exec_kxord(dst, src1, src2) = {
  __write_kreg(dst, zero_extend(xor_vec(__read_kreg(src1)[31..0], __read_kreg(src2)[31..0])));
  Ok(())
}

val exec_kxorq : (int, int, int) -> ExecutionResult
function exec_kxorq(dst, src1, src2) = {
  __write_kreg(dst, xor_vec(__read_kreg(src1), __read_kreg(src2)));
  Ok(())
}
