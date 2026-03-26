// x86-64 — EVEX Prefix Decoding and Dispatch
//
// Decodes 4-byte EVEX prefix (62h) and routes opcodes to sub-dispatchers.
//
// EVEX format (SDM Vol.2 §2.6):
//   Byte 0: 62h (already consumed by caller)
//   Byte 1 (P0): [R̄][X̄][B̄][R'̄][0][mmm]  (mmm: 3-bit opcode map)
//   Byte 2 (P1): [W][v̄v̄v̄v̄][1][pp]        (pp: mandatory prefix)
//   Byte 3 (P2): [z][L'L][b][V'̄][aaa]     (masking, length, broadcast)
//
// Register encoding (5 bits = 32 registers):
//   reg field:  EVEX.R' : EVEX.R : modrm.reg  (destination)
//   vvvvv:      EVEX.V' : EVEX.vvvv           (source 2)
//   r/m field:  EVEX.X : EVEX.B : modrm.rm    (source, reg only; for mem B extends base)

// Decode EVEX prefix (62h already consumed). Reads 3 payload bytes.
// Returns (Prefixes, opcode_map) where map is mmm field (1=0F, 2=0F38, 3=0F3A).
val decode_evex : unit -> (Prefixes, range(0, 7))
function decode_evex() = {
  let p0 = fetch(1);
  let p1 = fetch(1);
  let p2 = fetch(1);

  // Reserved field checks (SDM Vol.2 §2.6.1):
  // P0[3] must be 0; P1[2] must be 1. Violation → #UD.
  if p0[3] == 0b1 | p1[2] == 0b0 then raise_UD();

  let mmm : range(0, 7) = unsigned(p0[2..0]);
  let pfx = {default_prefixes() with
    evex_present = true,
    has_rex = true,
    // P0: R̄, X̄, B̄ (inverted), R'̄ (inverted)
    rex_r  = ~(p0[7]),
    rex_x  = ~(p0[6]),
    rex_b  = ~(p0[5]),
    evex_rr = ~(p0[4]),
    // P1: W, vvvv (inverted), pp
    rex_w  = p1[7] == 0b1,
    vex_w  = p1[7] == 0b1,
    evex_vvvvv = {
      let vprime : range(0, 1) = unsigned(zero_extend(~(p2[3])) : bits(1));
      let vvvv : range(0, 15) = unsigned(~(p1[6..3]));
      vprime * 16 + vvvv
    },
    // pp → mandatory prefix flags
    has_opsize = p1[1..0] == 0b01,
    has_rep    = p1[1..0] == 0b10,
    has_repne  = p1[1..0] == 0b11,
    // P2: z, L'L, b, V', aaa
    evex_z   = p2[7],
    evex_ll  = unsigned(p2[6..5]),
    evex_b   = p2[4] == 0b1,
    evex_aaa = unsigned(p2[2..0]),
    // Also populate VEX fields for compatibility
    vex_present = true,
  };
  (pfx, mmm)
}

val dispatch_evex_0f : (byte, Prefixes) -> unit
function dispatch_evex_0f(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  match op {
    // FP: mov, arith, compare, convert
    op if (16 <= op & op <= 23) | (40 <= op & op <= 47)
        | op == 81 | (84 <= op & op <= 95) | (120 <= op & op <= 123)
        | op == 194 | op == 198 | op == 230
      => dispatch_evex_fp(op, pfx),

    // Integer: arith, logic, pack, shift, compare, mov
    op if (96 <= op & op <= 118) | (126 <= op & op <= 127)
        | (196 <= op & op <= 197) | (209 <= op & op <= 214)
        | (216 <= op & op <= 229) | (231 <= op & op <= 239)
        | (241 <= op & op <= 246) | (248 <= op & op <= 254)
      => dispatch_evex_int(op, pfx),

    _ => raise_UD(),
  }
}

val dispatch_evex_0f38 : (byte, Prefixes) -> unit
function dispatch_evex_0f38(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  match op {
    // FMA, FP math, gather/scatter, GFNI
    op if (44 <= op & op <= 45) | (66 <= op & op <= 67) | (76 <= op & op <= 79)
        | (144 <= op & op <= 147) | (150 <= op & op <= 163)
        | (166 <= op & op <= 175) | (180 <= op & op <= 191)
        | (198 <= op & op <= 200) | (202 <= op & op <= 205) | op == 207
      => dispatch_evex_fma(op, pfx),

    // Broadcast, permute, shuffle, compress/expand
    op if op == 0 | (12 <= op & op <= 13) | op == 22 | (24 <= op & op <= 27)
        | op == 42 | op == 54 | op == 58 | (88 <= op & op <= 91)
        | (98 <= op & op <= 101) | (117 <= op & op <= 127)
        | (136 <= op & op <= 139) | op == 141 | op == 143
      => dispatch_evex_perm(op, pfx),

    // SIMD integer: arith, shifts, narrowing, VNNI, bit-manip
    op if op == 4 | op == 11 | (16 <= op & op <= 21) | (28 <= op & op <= 41)
        | op == 43 | (48 <= op & op <= 53) | (55 <= op & op <= 57)
        | (59 <= op & op <= 64) | (68 <= op & op <= 71) | (80 <= op & op <= 85)
        | op == 102 | (112 <= op & op <= 115) | op == 131 | op == 196
      => dispatch_evex_arith(op, pfx),

    _ => raise_UD(),
  }
}

val dispatch_evex_0f3a : (byte, Prefixes) -> unit
function dispatch_evex_0f3a(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  dispatch_evex_imm(op, pfx)
}

val dispatch_evex : unit -> unit
function dispatch_evex() = {
  if ~(avx512_enabled()) then raise_UD();
  let (pfx, mmm) = decode_evex();
  let opcode = fetch(1);
  match mmm {
    1 => dispatch_evex_0f(opcode, pfx),
    2 => dispatch_evex_0f38(opcode, pfx),
    3 => dispatch_evex_0f3a(opcode, pfx),
    5 => dispatch_evex_map5(opcode, pfx),
    6 => dispatch_evex_map6(opcode, pfx),
    _ => raise_UD(),  // mmm=0,4,7 are reserved (#UD)
  }
}
