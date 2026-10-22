// Proof: INVPCID descriptor validation — branchy vs branchless equivalence.
//
// Run:
//   sail --smt --smt-auto --smt-auto-solver z3 /tmp/prop_invpcid_branchless.sail

$include "../model/prelude.sail"

// inv_type is 0..3 (the >3 case is handled before this code).
// We use bits(2) to represent the type.
// reserved = desc[63..12], pcid = desc[11..0], top17 = lin_addr[63..47],
// or lin_addr[63..56] sign-extended with CR4.LA57, where lin_addr =
// desc[127..64]; pcide = CR4.PCIDE.

$property
function prop_invpcid_fault(inv_type : bits(2), reserved : bits(52), pcid : bits(12),
                            top17 : bits(17), pcide : bit) -> bool = {
  // SPEC (branchy) — the SDM's 64-bit mode #GP(0) conditions for INVPCID:
  //   bits 63:12 of INVPCID_DESC are not all zero;
  //   CR4.PCIDE = 0, INVPCID_TYPE is 0 or 1, and INVPCID_DESC[11:0] != 0;
  //   INVPCID_TYPE is 0 and the linear address is not canonical.
  let old_fault : bool =
    if reserved != zeros() then {
      true
    } else if unsigned(inv_type) <= 1 & pcide == bitzero & pcid != zeros() then {
      true
    } else if unsigned(inv_type) == 0 then {
      top17 != zeros() & top17 != ones()
    } else {
      false
    };

  // NEW (branchless) — textually matches insn_dispatch.sail:
  let is_type_01 : bit = ~(inv_type[1]);
  let is_type_0 : bit = ~(inv_type[1] | inv_type[0]);
  let bad_reserved : bit = ~(((0b0 @ reserved) - 1)[52]);
  let bad_pcid : bit = ~(((0b0 @ pcid) - 1)[12]) & ~(pcide);
  let diff : bits(17) = top17 ^ sign_extend(top17[16]);
  let non_canonical : bit = ~(((0b0 @ diff) - 1)[17]);
  let fault : bit = bad_reserved | (is_type_01 & bad_pcid) | (is_type_0 & non_canonical);
  let new_fault : bool = fault == bitone;

  old_fault == new_fault
}

// top17 as insn_dispatch.sail extracts it is all zeros or all ones exactly
// when lin_addr is canonical: bits 63:N repeat bit N-1, with N = 48, or 57
// under 5-level paging (SDM Vol.1 §3.3.7.1, Vol.3A §4.5).
$property
function prop_invpcid_top17_canonical(lin_addr : bits(64), la57 : bit) -> bool = {
  let top17 : bits(17) =
    if la57 == bitone then sign_extend(lin_addr[63..56]) else lin_addr[63..47];
  let canonical : bool =
    if la57 == bitone then lin_addr == sign_extend(lin_addr[56..0])
    else lin_addr == sign_extend(lin_addr[47..0]);
  (top17 == zeros() | top17 == ones()) == canonical
}
