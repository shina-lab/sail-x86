// Proof: INVPCID descriptor validation — branchy vs branchless equivalence.
//
// Run:
//   sail --smt --smt-auto --smt-auto-solver z3 /tmp/prop_invpcid_branchless.sail

$include "../model/prelude.sail"

// inv_type is 0..3 (the >3 case is handled before this code).
// We use bits(2) to represent the type.
// reserved = desc[63..12], pcid = desc[11..0], top17 = desc[127..111] =
// lin_addr[63..47], pcide = CR4.PCIDE.

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

// Prove that desc[127..111] == desc[127..64][63..47]
// (extracting top17 directly from desc vs via lin_addr intermediate)
$property
function prop_invpcid_top17_equiv(desc_hi : bits(64)) -> bool = {
  let lin_addr : bits(64) = desc_hi;
  let via_lin_addr : bits(17) = lin_addr[63..47];
  let direct : bits(17) = desc_hi[63..47];
  via_lin_addr == direct
}
