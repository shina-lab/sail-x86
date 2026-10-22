$include "../model/prelude.sail"

// INVPCID descriptor validation (model/insn_dispatch.sail, 66 0F 38 82):
// the model's branchless fault bit equals the SDM's #GP(0) conditions on
// the descriptor, each written as a flag with bool_to_bit (SDM Vol.2A
// INVPCID, 64-Bit Mode Exceptions):
//   bits 63:12 of INVPCID_DESC are not all zero;
//   CR4.PCIDE = 0, INVPCID_TYPE is 0 or 1, and INVPCID_DESC[11:0] is not
//   zero;
//   INVPCID_TYPE is 0 and the linear address in INVPCID_DESC[127:64] is
//   not canonical.
// (The protected-mode and real-address-mode lists leave out CR4.PCIDE = 0,
// which holds outside IA-32e mode: MOV to CR4 cannot set PCIDE there.)
// INVPCID_TYPE > 3, also #GP(0), is checked before this code, so the type
// is 0-3 and only its low 2 bits matter.  reserved = desc[63..12], pcid =
// desc[11..0], top17 = desc[127..111], the bits of the linear address that
// a canonical one has all equal; pcide = CR4.PCIDE.

$property
function prop_invpcid_fault(inv_type : bits(2), reserved : bits(52), pcid : bits(12),
                            top17 : bits(17), pcide : bit) -> bool = {
  // SDM: one flag per condition
  let type_01 : bits(1) = bool_to_bit(unsigned(inv_type) <= 1);
  let type_0 : bits(1) = bool_to_bit(inv_type == 0b00);
  let reserved_set : bits(1) = bool_to_bit(reserved != zeros());
  let pcid_without_pcide : bits(1) = bool_to_bit(pcide == bitzero & pcid != zeros());
  let not_canonical : bits(1) = bool_to_bit(top17 != zeros() & top17 != ones());
  let sdm : bits(1) = reserved_set | (type_01 & pcid_without_pcide) | (type_0 & not_canonical);

  // Branchless, as in insn_dispatch.sail
  let is_type_01 : bit = ~(inv_type[1]);
  let is_type_0 : bit = ~(inv_type[1] | inv_type[0]);
  let bad_reserved : bit = ~(((0b0 @ reserved) - 1)[52]);
  let bad_pcid : bit = ~(((0b0 @ pcid) - 1)[12]) & ~(pcide);
  // non-canonical: top17 bits not all the same. XOR with sign-extend of MSB
  // gives zero iff all bits match MSB (canonical).
  let diff : bits(17) = top17 ^ sign_extend(top17[16]);
  let non_canonical : bit = ~(((0b0 @ diff) - 1)[17]);
  let fault : bit = bad_reserved | (is_type_01 & bad_pcid) | (is_type_0 & non_canonical);

  sdm == [fault]
}
