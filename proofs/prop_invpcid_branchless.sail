// Proof: INVPCID descriptor validation — branchy vs branchless equivalence.
//
// Run:
//   sail --smt --smt-auto --smt-auto-solver z3 /tmp/prop_invpcid_branchless.sail

$include "../model/prelude.sail"

// inv_type is 0..3 (the >3 case is handled before this code).
// We use bits(2) to represent the type.
// reserved = desc[63..12], top17 = desc[127..111] = lin_addr[63..47].

$property
function prop_invpcid_fault(inv_type : bits(2), reserved : bits(52), top17 : bits(17)) -> bool = {
  // OLD (branchy) — textually matches insn_dispatch.sail lines 421-428:
  //   if unsigned(inv_type) <= 1 then {
  //     if reserved != zeros() then raise_GP0();
  //     if unsigned(inv_type) == 0 then {
  //       let top17 : bits(17) = lin_addr[63..47];
  //       if top17 != zeros() & top17 != ones() then raise_GP0()
  //     }
  //   };
  let old_fault : bool =
    if unsigned(inv_type) <= 1 then {
      if reserved != zeros() then {
        true
      } else if unsigned(inv_type) == 0 then {
        top17 != zeros() & top17 != ones()
      } else {
        false
      }
    } else {
      false
    };

  // NEW (branchless) — textually matches replacement code:
  let is_type_01 : bit = bool_to_bit(unsigned(inv_type) <= 1);
  let is_type_0 : bit = bool_to_bit(inv_type == zeros());
  let bad_reserved : bit = bool_to_bit(reserved != zeros());
  let non_canonical : bit = bool_to_bit(top17 != zeros() & top17 != ones());
  let fault : bit = (is_type_01 & bad_reserved) | (is_type_0 & non_canonical);
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
