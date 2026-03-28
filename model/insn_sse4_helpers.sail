// x86-64 — SSE4/AVX Shared Integer Helpers
//
// These helper functions are used by both VEX (insn_vex.sail) and
// EVEX (insn_evex_arith.sail) instruction dispatch. This file must
// be included before both.

// All 12 PMOVSX/PMOVZX widening functions replaced by
// packed_widen_unop(op, src_eb, dst_eb, src) in insn_vex.sail.
// See PackedWidenOp enum: PW_SignExtend, PW_ZeroExtend.

// pmuldq and pmulld kept for VEX (not yet in packed_binop)
val avx_pmuldq_128 : (xmmword, xmmword) -> xmmword
function avx_pmuldq_128(a, b) = {
  let lo_prod : bits(64) = to_bits_truncate(signed(a[31..0]) * signed(b[31..0]));
  let hi_prod : bits(64) = to_bits_truncate(signed(a[95..64]) * signed(b[95..64]));
  hi_prod @ lo_prod
}

val avx_pmuldq_256 : (ymmword, ymmword) -> ymmword
function avx_pmuldq_256(a, b) =
  avx_pmuldq_128(a[255..128], b[255..128]) @ avx_pmuldq_128(a[127..0], b[127..0])

// =========================================================================
// VPACKUSDW: pack dwords to words with unsigned saturation (for VEX use)
// =========================================================================

// =========================================================================
// Gather address computation (shared by VEX and EVEX gather instructions)
// =========================================================================

val gather_addr : forall 'n, 'n in {32, 64}. (qword, bits('n), range(0, 3)) -> qword
function gather_addr(base, idx, scale) = {
  let offset : qword = sign_extend(idx);
  match scale {
    0 => base + offset,
    1 => base + (offset << 1),
    2 => base + (offset << 2),
    3 => base + (offset << 3),
  }
}

// VEX VSIB decoder: decode SIB for VEX gather instructions.
// Returns (base_addr, vector_index_reg, scale).
// Unlike EVEX, index register is only 4-bit (REX.X extends it).
val decode_vsib_vex : (byte, Prefixes) -> VSIB
function decode_vsib_vex(modrm, pfx) = {
  let modbits : range(0, 3) = unsigned(modrm[7..6]);
  let sib = fetch(1);
  let scale : range(0, 3) = unsigned(sib[7..6]);

  let base_idx : gpr_idx = unsigned(pfx.rex_b @ sib[2..0]);
  let vidx : simd_idx = unsigned(pfx.rex_x @ sib[5..3]);

  let base_val : qword =
    if sib[2..0] == 0b101 & modbits == 0 then {
      let b0 = fetch(1);
      let b1 = fetch(1);
      let b2 = fetch(1);
      let b3 = fetch(1);
      sign_extend(b3 @ b2 @ b1 @ b0)
    } else if modbits == 0 then {
      v(64, base_idx)
    } else if modbits == 1 then {
      let d8 = fetch(1);
      v(64, base_idx) + sign_extend(d8)
    } else {
      let b0 = fetch(1);
      let b1 = fetch(1);
      let b2 = fetch(1);
      let b3 = fetch(1);
      v(64, base_idx) + sign_extend(b3 @ b2 @ b1 @ b0)
    };

  struct { vsib_base = base_val, vsib_vidx = vidx, vsib_scale = scale }
}

