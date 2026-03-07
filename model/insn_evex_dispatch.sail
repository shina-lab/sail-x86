// x86-64 EVEX — Prefix Decoding and Top-level Dispatch
//
// Decodes 4-byte EVEX prefix (62h) and routes opcodes to sub-dispatchers.
//
// EVEX format:
//   Byte 0: 62h (already consumed by caller)
//   Byte 1 (P0): [R̄][X̄][B̄][R'̄][0][mm]   (mm: opcode map)
//   Byte 2 (P1): [W][v̄v̄v̄v̄][1][pp]        (pp: mandatory prefix)
//   Byte 3 (P2): [z][L'L][b][V'̄][aaa]     (masking, length, broadcast)
//
// Register encoding (5 bits = 32 registers):
//   reg field:  EVEX.R' : EVEX.R : modrm.reg  (destination)
//   vvvvv:      EVEX.V' : EVEX.vvvv           (source 2)
//   r/m field:  EVEX.X : EVEX.B : modrm.rm    (source, reg only; for mem B extends base)

// Decode EVEX prefix (62h already consumed). Reads 3 payload bytes.
// Returns (Prefixes, opcode_map) where map is mm field (1=0F, 2=0F38, 3=0F3A).
val decode_evex : unit -> (Prefixes, range(0, 3))
function decode_evex() = {
  let p0 = fetch_byte();
  let p1 = fetch_byte();
  let p2 = fetch_byte();

  let mm : range(0, 3) = unsigned(p0[1..0]);
  let pfx = {default_prefixes() with
    evex_present = true,
    has_rex = true,
    // P0: R̄, X̄, B̄ (inverted), R'̄ (inverted)
    rex_r  = not_bool(p0[7] == bitone),
    rex_x  = not_bool(p0[6] == bitone),
    rex_b  = not_bool(p0[5] == bitone),
    evex_rr = not_bool(p0[4] == bitone),
    // P1: W, vvvv (inverted), pp
    rex_w  = p1[7] == bitone,
    vex_w  = p1[7] == bitone,
    evex_vvvvv = {
      let vprime : range(0, 1) = if p2[3] == bitone then 0 else 1;
      let vvvv : range(0, 15) = unsigned(~(p1[6..3]));
      vprime * 16 + vvvv
    },
    // pp → mandatory prefix flags
    has_opsize = p1[1..0] == 0b01,
    has_rep    = p1[1..0] == 0b10,
    has_repne  = p1[1..0] == 0b11,
    // P2: z, L'L, b, V', aaa
    evex_z   = p2[7] == bitone,
    evex_ll  = unsigned(p2[6..5]),
    evex_b   = p2[4] == bitone,
    evex_aaa = unsigned(p2[2..0]),
    // Also populate VEX fields for compatibility
    vex_present = true,
  };
  (pfx, mm)
}

val dispatch_evex_0f : (byte, Prefixes) -> ExecutionResult
function dispatch_evex_0f(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  match op {
    // FP: mov, arith, compare, convert
    16 => dispatch_evex_fp(op, pfx),
    17 => dispatch_evex_fp(op, pfx),
    18 => dispatch_evex_fp(op, pfx),
    19 => dispatch_evex_fp(op, pfx),
    20 => dispatch_evex_fp(op, pfx),
    21 => dispatch_evex_fp(op, pfx),
    22 => dispatch_evex_fp(op, pfx),
    23 => dispatch_evex_fp(op, pfx),
    40 => dispatch_evex_fp(op, pfx),
    41 => dispatch_evex_fp(op, pfx),
    42 => dispatch_evex_fp(op, pfx),
    43 => dispatch_evex_fp(op, pfx),
    44 => dispatch_evex_fp(op, pfx),
    45 => dispatch_evex_fp(op, pfx),
    46 => dispatch_evex_fp(op, pfx),
    47 => dispatch_evex_fp(op, pfx),
    81 => dispatch_evex_fp(op, pfx),
    84 => dispatch_evex_fp(op, pfx),
    85 => dispatch_evex_fp(op, pfx),
    86 => dispatch_evex_fp(op, pfx),
    87 => dispatch_evex_fp(op, pfx),
    88 => dispatch_evex_fp(op, pfx),
    89 => dispatch_evex_fp(op, pfx),
    90 => dispatch_evex_fp(op, pfx),
    91 => dispatch_evex_fp(op, pfx),
    92 => dispatch_evex_fp(op, pfx),
    93 => dispatch_evex_fp(op, pfx),
    94 => dispatch_evex_fp(op, pfx),
    95 => dispatch_evex_fp(op, pfx),
    120 => dispatch_evex_fp(op, pfx),
    121 => dispatch_evex_fp(op, pfx),
    122 => dispatch_evex_fp(op, pfx),
    123 => dispatch_evex_fp(op, pfx),
    194 => dispatch_evex_fp(op, pfx),
    198 => dispatch_evex_fp(op, pfx),
    230 => dispatch_evex_fp(op, pfx),
    // Integer: arith, logic, pack, shift, compare, mov
    96 => dispatch_evex_int(op, pfx),
    97 => dispatch_evex_int(op, pfx),
    98 => dispatch_evex_int(op, pfx),
    99 => dispatch_evex_int(op, pfx),
    100 => dispatch_evex_int(op, pfx),
    101 => dispatch_evex_int(op, pfx),
    102 => dispatch_evex_int(op, pfx),
    103 => dispatch_evex_int(op, pfx),
    104 => dispatch_evex_int(op, pfx),
    105 => dispatch_evex_int(op, pfx),
    106 => dispatch_evex_int(op, pfx),
    107 => dispatch_evex_int(op, pfx),
    108 => dispatch_evex_int(op, pfx),
    109 => dispatch_evex_int(op, pfx),
    110 => dispatch_evex_int(op, pfx),
    111 => dispatch_evex_int(op, pfx),
    112 => dispatch_evex_int(op, pfx),
    113 => dispatch_evex_int(op, pfx),
    114 => dispatch_evex_int(op, pfx),
    115 => dispatch_evex_int(op, pfx),
    116 => dispatch_evex_int(op, pfx),
    117 => dispatch_evex_int(op, pfx),
    118 => dispatch_evex_int(op, pfx),
    126 => dispatch_evex_int(op, pfx),
    127 => dispatch_evex_int(op, pfx),
    196 => dispatch_evex_int(op, pfx),
    197 => dispatch_evex_int(op, pfx),
    209 => dispatch_evex_int(op, pfx),
    210 => dispatch_evex_int(op, pfx),
    211 => dispatch_evex_int(op, pfx),
    212 => dispatch_evex_int(op, pfx),
    213 => dispatch_evex_int(op, pfx),
    214 => dispatch_evex_int(op, pfx),
    216 => dispatch_evex_int(op, pfx),
    217 => dispatch_evex_int(op, pfx),
    218 => dispatch_evex_int(op, pfx),
    219 => dispatch_evex_int(op, pfx),
    220 => dispatch_evex_int(op, pfx),
    221 => dispatch_evex_int(op, pfx),
    222 => dispatch_evex_int(op, pfx),
    223 => dispatch_evex_int(op, pfx),
    224 => dispatch_evex_int(op, pfx),
    225 => dispatch_evex_int(op, pfx),
    226 => dispatch_evex_int(op, pfx),
    227 => dispatch_evex_int(op, pfx),
    228 => dispatch_evex_int(op, pfx),
    229 => dispatch_evex_int(op, pfx),
    231 => dispatch_evex_int(op, pfx),
    232 => dispatch_evex_int(op, pfx),
    233 => dispatch_evex_int(op, pfx),
    234 => dispatch_evex_int(op, pfx),
    235 => dispatch_evex_int(op, pfx),
    236 => dispatch_evex_int(op, pfx),
    237 => dispatch_evex_int(op, pfx),
    238 => dispatch_evex_int(op, pfx),
    239 => dispatch_evex_int(op, pfx),
    241 => dispatch_evex_int(op, pfx),
    242 => dispatch_evex_int(op, pfx),
    243 => dispatch_evex_int(op, pfx),
    244 => dispatch_evex_int(op, pfx),
    245 => dispatch_evex_int(op, pfx),
    246 => dispatch_evex_int(op, pfx),
    248 => dispatch_evex_int(op, pfx),
    249 => dispatch_evex_int(op, pfx),
    250 => dispatch_evex_int(op, pfx),
    251 => dispatch_evex_int(op, pfx),
    252 => dispatch_evex_int(op, pfx),
    253 => dispatch_evex_int(op, pfx),
    254 => dispatch_evex_int(op, pfx),
    _ => raise_UD(),
  }
}

val dispatch_evex_0f38 : (byte, Prefixes) -> ExecutionResult
function dispatch_evex_0f38(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  match op {
    // FMA, FP math, gather/scatter, GFNI
    44 => dispatch_evex_fma(op, pfx),
    45 => dispatch_evex_fma(op, pfx),
    66 => dispatch_evex_fma(op, pfx),
    67 => dispatch_evex_fma(op, pfx),
    76 => dispatch_evex_fma(op, pfx),
    77 => dispatch_evex_fma(op, pfx),
    78 => dispatch_evex_fma(op, pfx),
    79 => dispatch_evex_fma(op, pfx),
    144 => dispatch_evex_fma(op, pfx),
    145 => dispatch_evex_fma(op, pfx),
    146 => dispatch_evex_fma(op, pfx),
    147 => dispatch_evex_fma(op, pfx),
    150 => dispatch_evex_fma(op, pfx),
    151 => dispatch_evex_fma(op, pfx),
    152 => dispatch_evex_fma(op, pfx),
    153 => dispatch_evex_fma(op, pfx),
    154 => dispatch_evex_fma(op, pfx),
    155 => dispatch_evex_fma(op, pfx),
    156 => dispatch_evex_fma(op, pfx),
    157 => dispatch_evex_fma(op, pfx),
    158 => dispatch_evex_fma(op, pfx),
    159 => dispatch_evex_fma(op, pfx),
    160 => dispatch_evex_fma(op, pfx),
    161 => dispatch_evex_fma(op, pfx),
    162 => dispatch_evex_fma(op, pfx),
    163 => dispatch_evex_fma(op, pfx),
    166 => dispatch_evex_fma(op, pfx),
    167 => dispatch_evex_fma(op, pfx),
    168 => dispatch_evex_fma(op, pfx),
    169 => dispatch_evex_fma(op, pfx),
    170 => dispatch_evex_fma(op, pfx),
    171 => dispatch_evex_fma(op, pfx),
    172 => dispatch_evex_fma(op, pfx),
    173 => dispatch_evex_fma(op, pfx),
    174 => dispatch_evex_fma(op, pfx),
    175 => dispatch_evex_fma(op, pfx),
    180 => dispatch_evex_fma(op, pfx),
    181 => dispatch_evex_fma(op, pfx),
    182 => dispatch_evex_fma(op, pfx),
    183 => dispatch_evex_fma(op, pfx),
    184 => dispatch_evex_fma(op, pfx),
    185 => dispatch_evex_fma(op, pfx),
    186 => dispatch_evex_fma(op, pfx),
    187 => dispatch_evex_fma(op, pfx),
    188 => dispatch_evex_fma(op, pfx),
    189 => dispatch_evex_fma(op, pfx),
    190 => dispatch_evex_fma(op, pfx),
    191 => dispatch_evex_fma(op, pfx),
    198 => dispatch_evex_fma(op, pfx),
    199 => dispatch_evex_fma(op, pfx),
    200 => dispatch_evex_fma(op, pfx),
    202 => dispatch_evex_fma(op, pfx),
    203 => dispatch_evex_fma(op, pfx),
    204 => dispatch_evex_fma(op, pfx),
    205 => dispatch_evex_fma(op, pfx),
    207 => dispatch_evex_fma(op, pfx),
    // Broadcast, permute, shuffle, compress/expand
    0 => dispatch_evex_perm(op, pfx),
    12 => dispatch_evex_perm(op, pfx),
    13 => dispatch_evex_perm(op, pfx),
    22 => dispatch_evex_perm(op, pfx),
    24 => dispatch_evex_perm(op, pfx),
    25 => dispatch_evex_perm(op, pfx),
    26 => dispatch_evex_perm(op, pfx),
    27 => dispatch_evex_perm(op, pfx),
    42 => dispatch_evex_perm(op, pfx),
    54 => dispatch_evex_perm(op, pfx),
    58 => dispatch_evex_perm(op, pfx),
    88 => dispatch_evex_perm(op, pfx),
    89 => dispatch_evex_perm(op, pfx),
    90 => dispatch_evex_perm(op, pfx),
    91 => dispatch_evex_perm(op, pfx),
    98 => dispatch_evex_perm(op, pfx),
    99 => dispatch_evex_perm(op, pfx),
    118 => dispatch_evex_perm(op, pfx),
    119 => dispatch_evex_perm(op, pfx),
    120 => dispatch_evex_perm(op, pfx),
    121 => dispatch_evex_perm(op, pfx),
    122 => dispatch_evex_perm(op, pfx),
    123 => dispatch_evex_perm(op, pfx),
    124 => dispatch_evex_perm(op, pfx),
    125 => dispatch_evex_perm(op, pfx),
    126 => dispatch_evex_perm(op, pfx),
    127 => dispatch_evex_perm(op, pfx),
    136 => dispatch_evex_perm(op, pfx),
    137 => dispatch_evex_perm(op, pfx),
    138 => dispatch_evex_perm(op, pfx),
    139 => dispatch_evex_perm(op, pfx),
    141 => dispatch_evex_perm(op, pfx),
    143 => dispatch_evex_perm(op, pfx),
    // SIMD integer: arith, shifts, narrowing, VNNI, bit-manip
    4 => dispatch_evex_arith(op, pfx),
    11 => dispatch_evex_arith(op, pfx),
    16 => dispatch_evex_arith(op, pfx),
    17 => dispatch_evex_arith(op, pfx),
    18 => dispatch_evex_arith(op, pfx),
    19 => dispatch_evex_arith(op, pfx),
    20 => dispatch_evex_arith(op, pfx),
    21 => dispatch_evex_arith(op, pfx),
    28 => dispatch_evex_arith(op, pfx),
    29 => dispatch_evex_arith(op, pfx),
    30 => dispatch_evex_arith(op, pfx),
    31 => dispatch_evex_arith(op, pfx),
    32 => dispatch_evex_arith(op, pfx),
    33 => dispatch_evex_arith(op, pfx),
    34 => dispatch_evex_arith(op, pfx),
    35 => dispatch_evex_arith(op, pfx),
    36 => dispatch_evex_arith(op, pfx),
    37 => dispatch_evex_arith(op, pfx),
    38 => dispatch_evex_arith(op, pfx),
    39 => dispatch_evex_arith(op, pfx),
    40 => dispatch_evex_arith(op, pfx),
    41 => dispatch_evex_arith(op, pfx),
    43 => dispatch_evex_arith(op, pfx),
    48 => dispatch_evex_arith(op, pfx),
    49 => dispatch_evex_arith(op, pfx),
    50 => dispatch_evex_arith(op, pfx),
    51 => dispatch_evex_arith(op, pfx),
    52 => dispatch_evex_arith(op, pfx),
    53 => dispatch_evex_arith(op, pfx),
    55 => dispatch_evex_arith(op, pfx),
    56 => dispatch_evex_arith(op, pfx),
    57 => dispatch_evex_arith(op, pfx),
    59 => dispatch_evex_arith(op, pfx),
    60 => dispatch_evex_arith(op, pfx),
    61 => dispatch_evex_arith(op, pfx),
    62 => dispatch_evex_arith(op, pfx),
    63 => dispatch_evex_arith(op, pfx),
    64 => dispatch_evex_arith(op, pfx),
    68 => dispatch_evex_arith(op, pfx),
    69 => dispatch_evex_arith(op, pfx),
    70 => dispatch_evex_arith(op, pfx),
    71 => dispatch_evex_arith(op, pfx),
    80 => dispatch_evex_arith(op, pfx),
    81 => dispatch_evex_arith(op, pfx),
    82 => dispatch_evex_arith(op, pfx),
    83 => dispatch_evex_arith(op, pfx),
    84 => dispatch_evex_arith(op, pfx),
    85 => dispatch_evex_arith(op, pfx),
    112 => dispatch_evex_arith(op, pfx),
    113 => dispatch_evex_arith(op, pfx),
    114 => dispatch_evex_arith(op, pfx),
    115 => dispatch_evex_arith(op, pfx),
    131 => dispatch_evex_arith(op, pfx),
    196 => dispatch_evex_arith(op, pfx),
    _ => raise_UD(),
  }
}

val dispatch_evex_0f3a : (byte, Prefixes) -> ExecutionResult
function dispatch_evex_0f3a(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  dispatch_evex_imm(op, pfx)
}

val dispatch_evex : unit -> ExecutionResult
function dispatch_evex() = {
  let (pfx, map) = decode_evex();
  let opcode = fetch_byte();
  match map {
    1 => dispatch_evex_0f(opcode, pfx),
    2 => dispatch_evex_0f38(opcode, pfx),
    3 => dispatch_evex_0f3a(opcode, pfx),
    _ => raise_UD(),
  }
}
