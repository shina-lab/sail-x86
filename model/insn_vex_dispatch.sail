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

    _ => raise_UD(),
  }
}

// =========================================================================
// VEX 0F38 map dispatch — routes to sub-dispatchers
// =========================================================================

val dispatch_vex_0f38 : (byte, Prefixes) -> unit
function dispatch_vex_0f38(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);

  match op {
    // SSSE3, SSE4, broadcast, BMI, variable shifts, gather, test, maskmov,
    // permute, VGF2P8MULB
    op if (0 <= op & op <= 15) | op == 19 | (22 <= op & op <= 26)
        | (28 <= op & op <= 30) | (32 <= op & op <= 37) | (40 <= op & op <= 65)
        | (69 <= op & op <= 71) | (88 <= op & op <= 90) | (120 <= op & op <= 121)
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
  if ~(avx_enabled()) then raise_UD();
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
    1 => dispatch_vex_0f(opcode, pfx),
    2 => dispatch_vex_0f38(opcode, pfx),
    3 => dispatch_vex_0f3a(opcode, pfx),
    _ => raise_UD(),
  }
}

val dispatch_vex : byte -> unit
function dispatch_vex(first_byte) = {
  if ~(avx_enabled()) then raise_UD();
  let b1 = fetch(1);
  dispatch_vex_with_byte2(first_byte, b1)
}
