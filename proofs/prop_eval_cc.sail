// Equivalence proof for branchless eval_cc.
// Original: 16-way match on cc index
// New: pack all 16 results into bits(16), index by cc

$include "../model/prelude.sail"

// Original: match-based eval_cc
val eval_cc_orig : (bits(4), bit, bit, bit, bit, bit) -> bool
function eval_cc_orig(cc, of, cf, zf, sf, pf) = match cc {
  0x0 => of == bitone,
  0x1 => of == bitzero,
  0x2 => cf == bitone,
  0x3 => cf == bitzero,
  0x4 => zf == bitone,
  0x5 => zf == bitzero,
  0x6 => cf == bitone | zf == bitone,
  0x7 => cf == bitzero & zf == bitzero,
  0x8 => sf == bitone,
  0x9 => sf == bitzero,
  0xA => pf == bitone,
  0xB => pf == bitzero,
  0xC => sf != of,
  0xD => sf == of,
  0xE => zf == bitone | sf != of,
  0xF => zf == bitzero & sf == of,
}

// New: branchless eval_cc using bitvector lookup
val eval_cc_branchless : (bits(4), bit, bit, bit, bit, bit) -> bool
function eval_cc_branchless(cc, of, cf, zf, sf, pf) = {
  let results : bits(16) =
    bool_to_bit(zf == bitzero & sf == of) @      // F: G
    bool_to_bit(zf == bitone | sf != of) @       // E: LE
    bool_to_bit(sf == of) @                       // D: GE
    bool_to_bit(sf != of) @                       // C: L
    bool_to_bit(pf == bitzero) @                  // B: NP
    bool_to_bit(pf == bitone) @                   // A: P
    bool_to_bit(sf == bitzero) @                  // 9: NS
    bool_to_bit(sf == bitone) @                   // 8: S
    bool_to_bit(cf == bitzero & zf == bitzero) @  // 7: A
    bool_to_bit(cf == bitone | zf == bitone) @    // 6: BE
    bool_to_bit(zf == bitzero) @                  // 5: NE
    bool_to_bit(zf == bitone) @                   // 4: E
    bool_to_bit(cf == bitzero) @                  // 3: AE
    bool_to_bit(cf == bitone) @                   // 2: B
    bool_to_bit(of == bitzero) @                  // 1: NO
    bool_to_bit(of == bitone);                    // 0: O

  let idx = unsigned(cc);
  results[idx] == bitone
}

$property
function prop_eval_cc(cc : bits(4), of : bit, cf : bit, zf : bit, sf : bit, pf : bit) -> bool = {
  let orig = eval_cc_orig(cc, of, cf, zf, sf, pf);
  let branchless = eval_cc_branchless(cc, of, cf, zf, sf, pf);
  orig == branchless
}
