// Equivalence proof: fully branchless eval_cc (no bool_to_bit)
// Old: bitvector lookup using bool_to_bit for each condition
// New: direct bit arithmetic (^, &, |, ~) on flag registers

$include "../model/prelude.sail"

// Current code (from rflags.sail) — uses bool_to_bit
val eval_cc_current : (bit, bit, bit, bit, bit) -> bits(16)
function eval_cc_current(of, cf, zf, sf, pf) =
  bool_to_bit(zf == bitzero & sf == of) @      // F: G/NLE
  bool_to_bit(zf == bitone | sf != of) @       // E: LE/NG
  bool_to_bit(sf == of) @                       // D: GE/NL
  bool_to_bit(sf != of) @                       // C: L/NGE
  bool_to_bit(pf == bitzero) @                  // B: NP/PO
  bool_to_bit(pf == bitone) @                   // A: P/PE
  bool_to_bit(sf == bitzero) @                  // 9: NS
  bool_to_bit(sf == bitone) @                   // 8: S
  bool_to_bit(cf == bitzero & zf == bitzero) @  // 7: A/NBE
  bool_to_bit(cf == bitone | zf == bitone) @    // 6: BE/NA
  bool_to_bit(zf == bitzero) @                  // 5: NE/NZ
  bool_to_bit(zf == bitone) @                   // 4: E/Z
  bool_to_bit(cf == bitzero) @                  // 3: AE/NB/NC
  bool_to_bit(cf == bitone) @                   // 2: B/C/NAE
  bool_to_bit(of == bitzero) @                  // 1: NO
  bool_to_bit(of == bitone)                     // 0: O

// New: direct bit arithmetic, no bool_to_bit
val eval_cc_branchless : (bit, bit, bit, bit, bit) -> bits(16)
function eval_cc_branchless(of, cf, zf, sf, pf) = {
  let sf_ne_of : bits(1) = sf ^ of;
  (~(zf) & ~(sf_ne_of)) @  // F: G/NLE
  (zf | sf_ne_of) @        // E: LE/NG
  (~(sf_ne_of)) @          // D: GE/NL
  sf_ne_of @               // C: L/NGE
  (~(pf)) @                // B: NP/PO
  pf @                     // A: P/PE
  (~(sf)) @                // 9: NS
  sf @                     // 8: S
  (~(cf) & ~(zf)) @       // 7: A/NBE
  (cf | zf) @              // 6: BE/NA
  (~(zf)) @                // 5: NE/NZ
  zf @                     // 4: E/Z
  (~(cf)) @                // 3: AE/NB/NC
  cf @                     // 2: B/C/NAE
  (~(of)) @                // 1: NO
  of                       // 0: O
}

$property
function prop_eval_cc(of : bit, cf : bit, zf : bit, sf : bit, pf : bit) -> bool =
  eval_cc_current(of, cf, zf, sf, pf) == eval_cc_branchless(of, cf, zf, sf, pf)
