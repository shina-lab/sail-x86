// x86-64 — VEX Dispatch

val dispatch_vex_0f : (byte, Prefixes) -> unit
function dispatch_vex_0f(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);

  match op {
    // FP: moves, arithmetic, compare, convert, shuffle, unpack
    op if (16 <= op & op <= 23) | (40 <= op & op <= 47)
        | (80 <= op & op <= 95) | op == 194 | op == 198
      => dispatch_vex_0f_fp(op, pfx),

    // Integer: moves, arithmetic, logical, compare, shuffle, insert/extract,
    // mask register ops, pack/unpack, shift, VZEROUPPER/VZEROALL
    op if (65 <= op & op <= 66) | (68 <= op & op <= 71) | (74 <= op & op <= 75)
        | (96 <= op & op <= 119) | (124 <= op & op <= 127)
        | (144 <= op & op <= 147) | (152 <= op & op <= 153)
        | (196 <= op & op <= 197) | (208 <= op & op <= 254)
      => dispatch_vex_0f_int(op, pfx),

    // 0F AE /2, /3: VLDMXCSR/VSTMXCSR m32 — VEX.LZ.0F.WIG with vvvv = 1111b.
    // The other Group 15 members have no VEX form, and a register operand
    // or VEX.L = 1 is #UD.  The MXCSR reserved-bit #GP is in __ldmxcsr.
    174 => {
      if pfx.vex_l | pfx.vex_vvvv != 0 | get_mandatory_prefix(pfx) != MP_NONE then raise_UD();
      let (reg_field, dest) = fetch_modrm_raw(pfx);
      match (reg_field, dest) {
        (2, RM_mem(_)) => __ldmxcsr(rm_mem(dest)),
        (3, RM_mem(_)) => rm_mem(dest) = __stmxcsr(),
        _ => raise_UD(),
      }
    },

    _ => raise_UD(),
  }
}

// =========================================================================
// VEX 0F38 map dispatch — routes to sub-dispatchers
// =========================================================================

val dispatch_vex_0f38 : (byte, Prefixes) -> unit
function dispatch_vex_0f38(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);

  // BMI1/BMI2 GPR instructions (opcodes F2-F7) do not require AVX, and
  // the Intel AMX instructions (49, 4B, 5C, 5E) need CR4.OSXSAVE and
  // XCR0[18:17] rather than XCR0.AVX (SDM Vol.2 Table 1-67; checked in
  // dispatch_amx).  All other VEX 0F38 instructions use SIMD and require
  // avx_enabled().
  let is_bmi = (242 <= op & op <= 247);
  let is_amx = op == 73 | op == 75 | op == 92 | op == 94;
  if ~(is_bmi) & ~(is_amx) & ~(avx_enabled()) then raise_UD();

  match op {
    // Intel AMX: LDTILECFG/STTILECFG/TILERELEASE/TILEZERO (49),
    // TILELOADD/TILELOADDT1/TILESTORED (4B), TDPBF16PS (5C),
    // TDPBSSD/TDPBSUD/TDPBUSD/TDPBUUD (5E)
    op if is_amx => dispatch_amx(op, pfx),

    // SSSE3, SSE4, broadcast, BMI, variable shifts, gather, test, maskmov,
    // permute, AVX-VNNI, VGF2P8MULB, AES
    op if (0 <= op & op <= 15) | op == 19 | (22 <= op & op <= 26)
        | (28 <= op & op <= 30) | (32 <= op & op <= 37) | (40 <= op & op <= 65)
        | (69 <= op & op <= 71) | (80 <= op & op <= 83) | (88 <= op & op <= 90)
        | (120 <= op & op <= 121)
        | op == 140 | op == 142 | (144 <= op & op <= 147) | op == 207
        | (219 <= op & op <= 223) | (242 <= op & op <= 243) | (245 <= op & op <= 247)
      => dispatch_vex_0f38_arith(op, pfx),

    // FMA3 instructions (0F38 96..BF)
    op if (150 <= op & op <= 159) | (166 <= op & op <= 175)
        | (182 <= op & op <= 191)
      => dispatch_vex_0f38_fma(op, pfx),

    _ => raise_UD(),
  }
}

// =========================================================================
// Top-level VEX dispatch — called from 1-byte opcode map for C4/C5.
// Must come after dispatch_vex_0f/0f38/0f3a definitions.
// =========================================================================

// Dispatch VEX-encoded instruction when the second byte has already been
// fetched (needed for C4/C5 in non-64-bit mode where the second byte is
// peeked at to distinguish VEX from LES/LDS).
val dispatch_vex_with_byte2 : (byte, byte) -> unit
function dispatch_vex_with_byte2(first_byte, b1) = {
  if cur_mode == Virtual8086Mode then raise_UD();
  // NOTE: avx_enabled() is NOT checked here.  VEX-encoded GPR-only
  // instructions (BMI1/BMI2) do not require CR4.OSXSAVE or XCR0[AVX].
  // The check is deferred to sub-dispatchers that handle SIMD instructions.
  let (pfx, map) : (Prefixes, range(0, 31)) =
    if first_byte == 0xC5 then {
      decode_vex2(b1)
    } else {
      // C4 = 3-byte VEX
      let b2 = fetch(1);
      decode_vex3(b1, b2)
    };

  let opcode = fetch(1);

  match map {
    1 => { if ~(avx_enabled()) then raise_UD(); dispatch_vex_0f(opcode, pfx) },
    2 => dispatch_vex_0f38(opcode, pfx),
    3 => dispatch_vex_0f3a(opcode, pfx),
    _ => raise_UD(),
  }
}

val dispatch_vex : byte -> unit
function dispatch_vex(first_byte) = {
  let b1 = fetch(1);
  dispatch_vex_with_byte2(first_byte, b1)
}
