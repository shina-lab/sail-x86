// =========================================================================
// VEX 0F map dispatch — routes to sub-dispatchers
// =========================================================================

val dispatch_vex_0f : (byte, Prefixes) -> unit
function dispatch_vex_0f(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);

  match op {

  // FP: moves, arithmetic, compare, convert, shuffle, unpack
  16 => dispatch_vex_0f_fp(op, pfx),
  17 => dispatch_vex_0f_fp(op, pfx),
  18 => dispatch_vex_0f_fp(op, pfx),
  19 => dispatch_vex_0f_fp(op, pfx),
  20 => dispatch_vex_0f_fp(op, pfx),
  21 => dispatch_vex_0f_fp(op, pfx),
  22 => dispatch_vex_0f_fp(op, pfx),
  23 => dispatch_vex_0f_fp(op, pfx),
  40 => dispatch_vex_0f_fp(op, pfx),
  41 => dispatch_vex_0f_fp(op, pfx),
  42 => dispatch_vex_0f_fp(op, pfx),
  43 => dispatch_vex_0f_fp(op, pfx),
  44 => dispatch_vex_0f_fp(op, pfx),
  45 => dispatch_vex_0f_fp(op, pfx),
  46 => dispatch_vex_0f_fp(op, pfx),
  47 => dispatch_vex_0f_fp(op, pfx),
  80 => dispatch_vex_0f_fp(op, pfx),
  op if 81 <= op & op <= 95 => dispatch_vex_0f_fp(op, pfx),
  194 => dispatch_vex_0f_fp(op, pfx),
  198 => dispatch_vex_0f_fp(op, pfx),

  // Integer: moves, arithmetic, logical, compare, shuffle, insert/extract,
  // mask register ops, pack/unpack, shift, VZEROUPPER/VZEROALL
  65 => dispatch_vex_0f_int(op, pfx),
  66 => dispatch_vex_0f_int(op, pfx),
  68 => dispatch_vex_0f_int(op, pfx),
  69 => dispatch_vex_0f_int(op, pfx),
  70 => dispatch_vex_0f_int(op, pfx),
  71 => dispatch_vex_0f_int(op, pfx),
  74 => dispatch_vex_0f_int(op, pfx),
  75 => dispatch_vex_0f_int(op, pfx),
  96 => dispatch_vex_0f_int(op, pfx),
  97 => dispatch_vex_0f_int(op, pfx),
  98 => dispatch_vex_0f_int(op, pfx),
  99 => dispatch_vex_0f_int(op, pfx),
  100 => dispatch_vex_0f_int(op, pfx),
  101 => dispatch_vex_0f_int(op, pfx),
  102 => dispatch_vex_0f_int(op, pfx),
  103 => dispatch_vex_0f_int(op, pfx),
  104 => dispatch_vex_0f_int(op, pfx),
  105 => dispatch_vex_0f_int(op, pfx),
  106 => dispatch_vex_0f_int(op, pfx),
  107 => dispatch_vex_0f_int(op, pfx),
  108 => dispatch_vex_0f_int(op, pfx),
  109 => dispatch_vex_0f_int(op, pfx),
  110 => dispatch_vex_0f_int(op, pfx),
  111 => dispatch_vex_0f_int(op, pfx),
  112 => dispatch_vex_0f_int(op, pfx),
  113 => dispatch_vex_0f_int(op, pfx),
  114 => dispatch_vex_0f_int(op, pfx),
  115 => dispatch_vex_0f_int(op, pfx),
  116 => dispatch_vex_0f_int(op, pfx),
  117 => dispatch_vex_0f_int(op, pfx),
  118 => dispatch_vex_0f_int(op, pfx),
  119 => dispatch_vex_0f_int(op, pfx),
  124 => dispatch_vex_0f_int(op, pfx),
  125 => dispatch_vex_0f_int(op, pfx),
  126 => dispatch_vex_0f_int(op, pfx),
  127 => dispatch_vex_0f_int(op, pfx),
  144 => dispatch_vex_0f_int(op, pfx),
  145 => dispatch_vex_0f_int(op, pfx),
  146 => dispatch_vex_0f_int(op, pfx),
  147 => dispatch_vex_0f_int(op, pfx),
  152 => dispatch_vex_0f_int(op, pfx),
  153 => dispatch_vex_0f_int(op, pfx),
  196 => dispatch_vex_0f_int(op, pfx),
  197 => dispatch_vex_0f_int(op, pfx),
  208 => dispatch_vex_0f_int(op, pfx),
  209 => dispatch_vex_0f_int(op, pfx),
  210 => dispatch_vex_0f_int(op, pfx),
  211 => dispatch_vex_0f_int(op, pfx),
  212 => dispatch_vex_0f_int(op, pfx),
  213 => dispatch_vex_0f_int(op, pfx),
  214 => dispatch_vex_0f_int(op, pfx),
  215 => dispatch_vex_0f_int(op, pfx),
  216 => dispatch_vex_0f_int(op, pfx),
  217 => dispatch_vex_0f_int(op, pfx),
  218 => dispatch_vex_0f_int(op, pfx),
  219 => dispatch_vex_0f_int(op, pfx),
  220 => dispatch_vex_0f_int(op, pfx),
  221 => dispatch_vex_0f_int(op, pfx),
  222 => dispatch_vex_0f_int(op, pfx),
  223 => dispatch_vex_0f_int(op, pfx),
  224 => dispatch_vex_0f_int(op, pfx),
  225 => dispatch_vex_0f_int(op, pfx),
  226 => dispatch_vex_0f_int(op, pfx),
  227 => dispatch_vex_0f_int(op, pfx),
  228 => dispatch_vex_0f_int(op, pfx),
  229 => dispatch_vex_0f_int(op, pfx),
  230 => dispatch_vex_0f_int(op, pfx),
  231 => dispatch_vex_0f_int(op, pfx),
  232 => dispatch_vex_0f_int(op, pfx),
  233 => dispatch_vex_0f_int(op, pfx),
  234 => dispatch_vex_0f_int(op, pfx),
  235 => dispatch_vex_0f_int(op, pfx),
  236 => dispatch_vex_0f_int(op, pfx),
  237 => dispatch_vex_0f_int(op, pfx),
  238 => dispatch_vex_0f_int(op, pfx),
  239 => dispatch_vex_0f_int(op, pfx),
  240 => dispatch_vex_0f_int(op, pfx),
  241 => dispatch_vex_0f_int(op, pfx),
  242 => dispatch_vex_0f_int(op, pfx),
  243 => dispatch_vex_0f_int(op, pfx),
  244 => dispatch_vex_0f_int(op, pfx),
  245 => dispatch_vex_0f_int(op, pfx),
  246 => dispatch_vex_0f_int(op, pfx),
  247 => dispatch_vex_0f_int(op, pfx),
  248 => dispatch_vex_0f_int(op, pfx),
  249 => dispatch_vex_0f_int(op, pfx),
  250 => dispatch_vex_0f_int(op, pfx),
  251 => dispatch_vex_0f_int(op, pfx),
  252 => dispatch_vex_0f_int(op, pfx),
  253 => dispatch_vex_0f_int(op, pfx),
  254 => dispatch_vex_0f_int(op, pfx),

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

  // SSSE3, SSE4, broadcast, BMI, variable shifts, gather, test, maskmov, permute
  0 => dispatch_vex_0f38_arith(op, pfx),
  1 => dispatch_vex_0f38_arith(op, pfx),
  2 => dispatch_vex_0f38_arith(op, pfx),
  3 => dispatch_vex_0f38_arith(op, pfx),
  4 => dispatch_vex_0f38_arith(op, pfx),
  5 => dispatch_vex_0f38_arith(op, pfx),
  6 => dispatch_vex_0f38_arith(op, pfx),
  7 => dispatch_vex_0f38_arith(op, pfx),
  8 => dispatch_vex_0f38_arith(op, pfx),
  9 => dispatch_vex_0f38_arith(op, pfx),
  10 => dispatch_vex_0f38_arith(op, pfx),
  11 => dispatch_vex_0f38_arith(op, pfx),
  12 => dispatch_vex_0f38_arith(op, pfx),
  13 => dispatch_vex_0f38_arith(op, pfx),
  14 => dispatch_vex_0f38_arith(op, pfx),
  15 => dispatch_vex_0f38_arith(op, pfx),
  19 => dispatch_vex_0f38_arith(op, pfx),
  22 => dispatch_vex_0f38_arith(op, pfx),
  23 => dispatch_vex_0f38_arith(op, pfx),
  24 => dispatch_vex_0f38_arith(op, pfx),
  25 => dispatch_vex_0f38_arith(op, pfx),
  26 => dispatch_vex_0f38_arith(op, pfx),
  28 => dispatch_vex_0f38_arith(op, pfx),
  29 => dispatch_vex_0f38_arith(op, pfx),
  30 => dispatch_vex_0f38_arith(op, pfx),
  32 => dispatch_vex_0f38_arith(op, pfx),
  33 => dispatch_vex_0f38_arith(op, pfx),
  34 => dispatch_vex_0f38_arith(op, pfx),
  35 => dispatch_vex_0f38_arith(op, pfx),
  36 => dispatch_vex_0f38_arith(op, pfx),
  37 => dispatch_vex_0f38_arith(op, pfx),
  40 => dispatch_vex_0f38_arith(op, pfx),
  41 => dispatch_vex_0f38_arith(op, pfx),
  42 => dispatch_vex_0f38_arith(op, pfx),
  43 => dispatch_vex_0f38_arith(op, pfx),
  44 => dispatch_vex_0f38_arith(op, pfx),
  45 => dispatch_vex_0f38_arith(op, pfx),
  46 => dispatch_vex_0f38_arith(op, pfx),
  47 => dispatch_vex_0f38_arith(op, pfx),
  48 => dispatch_vex_0f38_arith(op, pfx),
  49 => dispatch_vex_0f38_arith(op, pfx),
  50 => dispatch_vex_0f38_arith(op, pfx),
  51 => dispatch_vex_0f38_arith(op, pfx),
  52 => dispatch_vex_0f38_arith(op, pfx),
  53 => dispatch_vex_0f38_arith(op, pfx),
  54 => dispatch_vex_0f38_arith(op, pfx),
  55 => dispatch_vex_0f38_arith(op, pfx),
  56 => dispatch_vex_0f38_arith(op, pfx),
  57 => dispatch_vex_0f38_arith(op, pfx),
  58 => dispatch_vex_0f38_arith(op, pfx),
  59 => dispatch_vex_0f38_arith(op, pfx),
  60 => dispatch_vex_0f38_arith(op, pfx),
  61 => dispatch_vex_0f38_arith(op, pfx),
  62 => dispatch_vex_0f38_arith(op, pfx),
  63 => dispatch_vex_0f38_arith(op, pfx),
  64 => dispatch_vex_0f38_arith(op, pfx),
  65 => dispatch_vex_0f38_arith(op, pfx),
  69 => dispatch_vex_0f38_arith(op, pfx),
  70 => dispatch_vex_0f38_arith(op, pfx),
  71 => dispatch_vex_0f38_arith(op, pfx),
  88 => dispatch_vex_0f38_arith(op, pfx),
  89 => dispatch_vex_0f38_arith(op, pfx),
  90 => dispatch_vex_0f38_arith(op, pfx),
  120 => dispatch_vex_0f38_arith(op, pfx),
  121 => dispatch_vex_0f38_arith(op, pfx),
  140 => dispatch_vex_0f38_arith(op, pfx),
  142 => dispatch_vex_0f38_arith(op, pfx),
  144 => dispatch_vex_0f38_arith(op, pfx),
  145 => dispatch_vex_0f38_arith(op, pfx),
  146 => dispatch_vex_0f38_arith(op, pfx),
  147 => dispatch_vex_0f38_arith(op, pfx),
  219 => dispatch_vex_0f38_arith(op, pfx),
  220 => dispatch_vex_0f38_arith(op, pfx),
  221 => dispatch_vex_0f38_arith(op, pfx),
  222 => dispatch_vex_0f38_arith(op, pfx),
  223 => dispatch_vex_0f38_arith(op, pfx),
  242 => dispatch_vex_0f38_arith(op, pfx),
  243 => dispatch_vex_0f38_arith(op, pfx),
  245 => dispatch_vex_0f38_arith(op, pfx),
  246 => dispatch_vex_0f38_arith(op, pfx),
  247 => dispatch_vex_0f38_arith(op, pfx),

  // FMA3 instructions (0F38 96..BF)
  150 => dispatch_vex_0f38_fma(op, pfx),
  151 => dispatch_vex_0f38_fma(op, pfx),
  152 => dispatch_vex_0f38_fma(op, pfx),
  153 => dispatch_vex_0f38_fma(op, pfx),
  154 => dispatch_vex_0f38_fma(op, pfx),
  155 => dispatch_vex_0f38_fma(op, pfx),
  156 => dispatch_vex_0f38_fma(op, pfx),
  157 => dispatch_vex_0f38_fma(op, pfx),
  158 => dispatch_vex_0f38_fma(op, pfx),
  159 => dispatch_vex_0f38_fma(op, pfx),
  166 => dispatch_vex_0f38_fma(op, pfx),
  167 => dispatch_vex_0f38_fma(op, pfx),
  168 => dispatch_vex_0f38_fma(op, pfx),
  169 => dispatch_vex_0f38_fma(op, pfx),
  170 => dispatch_vex_0f38_fma(op, pfx),
  171 => dispatch_vex_0f38_fma(op, pfx),
  172 => dispatch_vex_0f38_fma(op, pfx),
  173 => dispatch_vex_0f38_fma(op, pfx),
  174 => dispatch_vex_0f38_fma(op, pfx),
  175 => dispatch_vex_0f38_fma(op, pfx),
  182 => dispatch_vex_0f38_fma(op, pfx),
  183 => dispatch_vex_0f38_fma(op, pfx),
  184 => dispatch_vex_0f38_fma(op, pfx),
  185 => dispatch_vex_0f38_fma(op, pfx),
  186 => dispatch_vex_0f38_fma(op, pfx),
  187 => dispatch_vex_0f38_fma(op, pfx),
  188 => dispatch_vex_0f38_fma(op, pfx),
  189 => dispatch_vex_0f38_fma(op, pfx),
  190 => dispatch_vex_0f38_fma(op, pfx),
  191 => dispatch_vex_0f38_fma(op, pfx),

  // VGF2P8MULB: VEX.128/256.66.0F38.W0 CF /r
  207 => dispatch_vex_0f38_arith(op, pfx),

  _ => raise_UD(),
  }
}

// =========================================================================
// Top-level VEX dispatch — called from 1-byte opcode map for C4/C5.
// Must come after dispatch_vex_0f/0f38/0f3a definitions.
// =========================================================================

val dispatch_vex : byte -> unit
function dispatch_vex(first_byte) = {
  let (pfx, map) : (Prefixes, range(0, 31)) =
    if first_byte == 0xC5 then {
      let b1 = fetch_byte();
      decode_vex2(b1)
    } else {
      // C4 = 3-byte VEX
      let b1 = fetch_byte();
      let b2 = fetch_byte();
      decode_vex3(b1, b2)
    };

  let opcode = fetch_byte();

  match map {
    1 => dispatch_vex_0f(opcode, pfx),
    2 => dispatch_vex_0f38(opcode, pfx),
    3 => dispatch_vex_0f3a(opcode, pfx),
    _ => raise_UD(),
  }
}
