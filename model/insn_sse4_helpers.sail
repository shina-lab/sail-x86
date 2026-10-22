// x86-64 — SSE4/AVX Shared Integer Helpers
//
// These helper functions are used by both VEX (insn_vex.sail) and
// EVEX (insn_evex_arith.sail) instruction dispatch. This file must
// be included before both.

// =========================================================================
// Gather address computation (shared by VEX and EVEX gather instructions)
// =========================================================================

// The memory operand of the element with index idx: "BASE_ADDR +
// (SignExtend(VINDEX[i])*SCALE + DISP" (SDM Vol.2 VPGATHERDD etc.,
// Operation), an effective address of the instruction's address size, in
// the segment of the base register or the override (vsib_seg_asize).
val gather_addr : forall 'n, 'n in {32, 64}. (VSIB, bits('n)) -> MemRef
function gather_addr(vsib, idx) = {
  let offset : qword = sign_extend(idx);
  let ea : qword = match vsib.vsib_scale {
    0 => vsib.vsib_base + offset,
    1 => vsib.vsib_base + (offset << 1),
    2 => vsib.vsib_base + (offset << 2),
    3 => vsib.vsib_base + (offset << 3),
  };
  struct { seg = vsib.vsib_seg, addr = if vsib.vsib_addr64 then ea else zero_extend(ea[31..0]) }
}

// VEX VSIB decoder: decode SIB for VEX gather instructions.
// Returns the base address, vector index register, scale, segment and
// address size.  Unlike EVEX, index register is only 4-bit (REX.X extends it).
// A gather "will cause a #UD if the memory operand is encoded without the
// SIB byte", and "if any pair of the index, mask [VEX.vvvv], or
// destination [ModRM.reg] registers are the same" (SDM VPGATHERDD etc.;
// both on a Zen 4 and an Emerald Rapids).  dispatch_vex_with_byte2 has
// ruled out a register r/m (vex_forms_0f38).
val decode_vsib_vex : (byte, Prefixes) -> VSIB
function decode_vsib_vex(modrm, pfx) = {
  let modbits : range(0, 3) = unsigned(modrm[7..6]);
  if modrm[2..0] != 0b100 then raise_UD();
  let sib = fetch(1);
  let scale : range(0, 3) = unsigned(sib[7..6]);
  let (seg, addr64) = vsib_seg_asize(sib, modbits, pfx);

  let base_idx : gpr_idx = unsigned(pfx.rex_b @ sib[2..0]);
  let vidx : simd_idx = unsigned(pfx.rex_x @ sib[5..3]);
  let dst : simd_idx = modrm_xreg(modrm, pfx);
  if vidx == dst | vidx == pfx.vex_vvvv | dst == pfx.vex_vvvv then raise_UD();

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

  struct { vsib_base = base_val, vsib_vidx = vidx, vsib_scale = scale,
           vsib_seg = seg, vsib_addr64 = addr64 }
}

