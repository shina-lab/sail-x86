// x86-64 — Prefix Scanning
//
// Scans legacy prefixes and REX prefix from the instruction stream.
// In 64-bit mode, bytes 40-4F are REX prefixes (not INC/DEC).
// REX must be the last prefix before the opcode byte.

val scan_prefixes : unit -> (Prefixes, byte)
function scan_prefixes() = {
  var pfx : Prefixes = default_prefixes();
  var opcode : byte = 0x00;
  var done : bool = false;

  // Loop scanning prefix bytes. The 15-byte instruction length limit is
  // enforced by fetch_byte(), which raises #GP(0) if exceeded.
  while ~(done) do {
    let b = fetch_byte();
    let bv : range(0, 255) = unsigned(b);

    // Clear REX state on any legacy prefix (REX must be last)
    match bv {
      // F0 = LOCK
      240 => pfx = {pfx with has_lock = true, has_rex = false,
               rex_w = false, rex_r = 0b0, rex_x = 0b0, rex_b = 0b0},
      // F2 = REPNE / mandatory prefix
      242 => pfx = {pfx with has_repne = true, has_rep = false, has_rex = false,
               rex_w = false, rex_r = 0b0, rex_x = 0b0, rex_b = 0b0},
      // F3 = REP / mandatory prefix
      243 => pfx = {pfx with has_rep = true, has_repne = false, has_rex = false,
               rex_w = false, rex_r = 0b0, rex_x = 0b0, rex_b = 0b0},
      // 26 = ES override
      38 => pfx = {pfx with seg_override = Some(ES), has_rex = false,
              rex_w = false, rex_r = 0b0, rex_x = 0b0, rex_b = 0b0},
      // 2E = CS override
      46 => pfx = {pfx with seg_override = Some(CS), has_rex = false,
              rex_w = false, rex_r = 0b0, rex_x = 0b0, rex_b = 0b0},
      // 36 = SS override
      54 => pfx = {pfx with seg_override = Some(SS), has_rex = false,
              rex_w = false, rex_r = 0b0, rex_x = 0b0, rex_b = 0b0},
      // 3E = DS override
      62 => pfx = {pfx with seg_override = Some(DS), has_rex = false,
              rex_w = false, rex_r = 0b0, rex_x = 0b0, rex_b = 0b0},
      // 64 = FS override
      100 => pfx = {pfx with seg_override = Some(FS), has_rex = false,
               rex_w = false, rex_r = 0b0, rex_x = 0b0, rex_b = 0b0},
      // 65 = GS override
      101 => pfx = {pfx with seg_override = Some(GS), has_rex = false,
               rex_w = false, rex_r = 0b0, rex_x = 0b0, rex_b = 0b0},
      // 66 = operand size override
      102 => pfx = {pfx with has_opsize = true, has_rex = false,
               rex_w = false, rex_r = 0b0, rex_x = 0b0, rex_b = 0b0},
      // 67 = address size override
      103 => pfx = {pfx with has_adsize = 0b1, has_rex = false,
               rex_w = false, rex_r = 0b0, rex_x = 0b0, rex_b = 0b0},
      // 40-4F = REX prefix (64-bit mode only; INC/DEC in 32-bit mode)
      bv if 64 <= bv & bv <= 79 & cur_mode == LongMode =>
        pfx = {pfx with
          has_rex = true,
          rex_w = b[3] == 0b1,
          rex_r = b[2],
          rex_x = b[1],
          rex_b = b[0],
        },
      _ => {
        // Not a prefix — this is the opcode byte
        opcode = b;
        done = true;
      },
    }
  };
  (pfx, opcode)
}

// Determine the mandatory prefix for 2-byte/3-byte opcode interpretation.
// F2/F3 take priority over 66. Last F2/F3 wins (handled in scan_prefixes).
val get_mandatory_prefix : Prefixes -> MandatoryPrefix
function get_mandatory_prefix(pfx) =
  if pfx.has_repne then MP_F2
  else if pfx.has_rep then MP_F3
  else if pfx.has_opsize then MP_66
  else MP_NONE
