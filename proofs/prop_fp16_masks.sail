// Proof that the branchless writemask handling added to the FP16 scalar
// forms (VMOVSH load, 2026-09-24) matches the SDM's if/else pseudocode.
//
// Run:
//   sail --smt --smt-auto --smt-auto-solver z3 proofs/prop_fp16_masks.sail

$include "../model/prelude.sail"

// --- blend (textually identical to model/branchless.sail) ---

val blend : forall 'n, 0 < 'n. (bits('n), bits('n), bit) -> bits('n)
function blend(a, b, sel) = {
  let m : bits('n) = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

// ================================================================
// VMOVSH xmm1{k1}{z}, m16 (SDM Vol. 2C, VMOVSH Operation):
//   IF k1[0] OR *no writemask*: DEST.fp16[0] := SRC.fp16[0]
//   ELSE IF *zeroing*:          DEST.fp16[0] := 0
//   ELSE                        DEST.fp16[0] remains unchanged
// The model computes blend(blend(old, 0, z), src, k).
// ================================================================

$property
function prop_vmovsh_load_mask(old : bits(16), src : bits(16), k : bits(1), z : bits(1)) -> bool = {
  let orig : bits(16) =
    if k == 0b1 then src else (if z == 0b1 then zeros() else old);
  let merge : bits(16) = blend(old, zeros(), z[0]);
  let branchless : bits(16) = blend(merge, src, k[0]);
  orig == branchless
}

// The same rule at the 32-bit element width used by VCVTSH2SS and the
// scalar complex FMA (evex_write_scalar with eb = 32).
$property
function prop_scalar_mask_32(old : bits(32), src : bits(32), k : bits(1), z : bits(1)) -> bool = {
  let orig : bits(32) =
    if k == 0b1 then src else (if z == 0b1 then zeros() else old);
  let merge : bits(32) = blend(old, zeros(), z[0]);
  let branchless : bits(32) = blend(merge, src, k[0]);
  orig == branchless
}
