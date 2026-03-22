$include "../model/prelude.sail"

// ================================================================
// AAA — ASCII Adjust After Addition
// ================================================================

$property
function prop_aaa(ax : bits(16), af : bits(1)) -> bool = {
  let lo : bits(4) = ax[3..0];

  // Original (branching)
  let (orig_ax, orig_af, orig_cf) : (bits(16), bits(1), bits(1)) =
    if (unsigned(lo) > 9) | (af == 0b1) then {
      let new_ax : bits(16) = ax + 0x0106;
      (new_ax[15..8] @ (new_ax[7..0] & 0x0F), 0b1, 0b1)
    } else {
      (ax[15..8] @ (ax[7..0] & 0x0F), 0b0, 0b0)
    };

  // Branchless
  let cond : bits(1) = (lo[3..3] & (lo[2..2] | lo[1..1])) | af;
  let mask : bits(16) = sign_extend(cond);
  let new_ax : bits(16) = ax + (0x0106 & mask);

  orig_ax == new_ax[15..8] @ (new_ax[7..0] & 0x0F) &
  orig_af == cond & orig_cf == cond
}

// ================================================================
// AAS — ASCII Adjust AL After Subtraction
// ================================================================

$property
function prop_aas(ax : bits(16), af : bits(1)) -> bool = {
  let lo : bits(4) = ax[3..0];

  // Original (branching)
  let (orig_ax, orig_af, orig_cf) : (bits(16), bits(1), bits(1)) =
    if (unsigned(lo) > 9) | (af == 0b1) then {
      let ax1 : bits(16) = ax - 0x0006;
      let ax2 : bits(16) = (ax1[15..8] - 0x01) @ ax1[7..0];
      (ax2[15..8] @ (ax2[7..0] & 0x0F), 0b1, 0b1)
    } else {
      (ax[15..8] @ (ax[7..0] & 0x0F), 0b0, 0b0)
    };

  // Branchless
  let cond : bits(1) = (lo[3..3] & (lo[2..2] | lo[1..1])) | af;
  let mask : bits(16) = sign_extend(cond);
  let new_ax : bits(16) = ax - (0x0106 & mask);

  orig_ax == new_ax[15..8] @ (new_ax[7..0] & 0x0F) &
  orig_af == cond & orig_cf == cond
}

// ================================================================
// DAA — Decimal Adjust AL After Addition
// CF is always set by stage 2 (SDM: ELSE CF := 0), so CF = cond2.
// ================================================================

$property
function prop_daa(old_al : bits(8), old_cf : bits(1), af : bits(1)) -> bool = {
  let lo : bits(4) = old_al[3..0];

  // Original (branching)
  let (al1, af1) : (bits(8), bits(1)) =
    if (unsigned(lo) > 9) | (af == 0b1) then {
      (old_al + 0x06, 0b1)
    } else {
      (old_al, 0b0)
    };
  let (orig_al, orig_cf) : (bits(8), bits(1)) =
    if (unsigned(old_al) > 153) | (old_cf == 0b1) then {
      (al1 + 0x60, 0b1)
    } else {
      (al1, 0b0)
    };

  // Branchless
  let cond1 : bits(1) = (lo[3..3] & (lo[2..2] | lo[1..1])) | af;
  let al1_bl : bits(8) = old_al + (0x06 & sign_extend(cond1));
  let cond2 : bits(1) = ~(((0b0 @ old_al) - 0b0_1001_1010)[8..8]) | old_cf;
  let bl_al : bits(8) = al1_bl + (0x60 & sign_extend(cond2));

  orig_al == bl_al & orig_cf == cond2 & af1 == cond1
}

// ================================================================
// DAS — Decimal Adjust AL After Subtraction
// Stage 2 has no ELSE CF:=0, so CF keeps stage 1 value when !cond2.
// ================================================================

$property
function prop_das(old_al : bits(8), old_cf : bits(1), af : bits(1)) -> bool = {
  let lo : bits(4) = old_al[3..0];

  // Original (branching)
  let (al1, cf1, af1) : (bits(8), bits(1), bits(1)) =
    if (unsigned(lo) > 9) | (af == 0b1) then {
      (old_al - 0x06, old_cf | bool_to_bit(unsigned(lo) < 6), 0b1)
    } else {
      (old_al, 0b0, 0b0)
    };
  let (orig_al, orig_cf) : (bits(8), bits(1)) =
    if (unsigned(old_al) > 153) | (old_cf == 0b1) then {
      (al1 - 0x60, 0b1)
    } else {
      (al1, cf1)
    };

  // Branchless
  let cond1 : bits(1) = (lo[3..3] & (lo[2..2] | lo[1..1])) | af;
  let bl_al1 : bits(8) = old_al - (0x06 & sign_extend(cond1));
  let borrow1 : bits(5) = (0b0 @ lo) - (0b0 @ 0b0110);
  let cond2 : bits(1) = ~(((0b0 @ old_al) - 0b0_1001_1010)[8..8]) | old_cf;
  let bl_al : bits(8) = bl_al1 - (0x60 & sign_extend(cond2));
  let bl_cf : bits(1) = cond2 | (cond1 & (old_cf | borrow1[4..4]));

  orig_al == bl_al & orig_cf == bl_cf & af1 == cond1
}
