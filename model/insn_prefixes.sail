// x86-64 Decoder — Prefix Scanning
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
  while not_bool(done) do {
    let b = fetch_byte();
    let bv : range(0, 255) = unsigned(b);

    // Clear REX state on any legacy prefix (REX must be last)
    if bv == 240 then {
      // F0 = LOCK
      pfx = {pfx with has_lock = true, has_rex = false,
             rex_w = false, rex_r = false, rex_x = false, rex_b = false};
    } else if bv == 242 then {
      // F2 = REPNE / mandatory prefix
      pfx = {pfx with has_repne = true, has_rep = false, has_rex = false,
             rex_w = false, rex_r = false, rex_x = false, rex_b = false};
    } else if bv == 243 then {
      // F3 = REP / mandatory prefix
      pfx = {pfx with has_rep = true, has_repne = false, has_rex = false,
             rex_w = false, rex_r = false, rex_x = false, rex_b = false};
    } else if bv == 38 then {
      // 26 = ES override
      pfx = {pfx with seg_override = Some(ES), has_rex = false,
             rex_w = false, rex_r = false, rex_x = false, rex_b = false};
    } else if bv == 46 then {
      // 2E = CS override
      pfx = {pfx with seg_override = Some(CS), has_rex = false,
             rex_w = false, rex_r = false, rex_x = false, rex_b = false};
    } else if bv == 54 then {
      // 36 = SS override
      pfx = {pfx with seg_override = Some(SS), has_rex = false,
             rex_w = false, rex_r = false, rex_x = false, rex_b = false};
    } else if bv == 62 then {
      // 3E = DS override
      pfx = {pfx with seg_override = Some(DS), has_rex = false,
             rex_w = false, rex_r = false, rex_x = false, rex_b = false};
    } else if bv == 100 then {
      // 64 = FS override
      pfx = {pfx with seg_override = Some(FS), has_rex = false,
             rex_w = false, rex_r = false, rex_x = false, rex_b = false};
    } else if bv == 101 then {
      // 65 = GS override
      pfx = {pfx with seg_override = Some(GS), has_rex = false,
             rex_w = false, rex_r = false, rex_x = false, rex_b = false};
    } else if bv == 102 then {
      // 66 = operand size override
      pfx = {pfx with has_opsize = true, has_rex = false,
             rex_w = false, rex_r = false, rex_x = false, rex_b = false};
    } else if bv == 103 then {
      // 67 = address size override
      pfx = {pfx with has_adsize = true, has_rex = false,
             rex_w = false, rex_r = false, rex_x = false, rex_b = false};
    } else if bv >= 64 & bv <= 79 then {
      // 40-4F = REX prefix (64-bit mode only)
      pfx = {pfx with
        has_rex = true,
        rex_w = b[3] == bitone,
        rex_r = b[2] == bitone,
        rex_x = b[1] == bitone,
        rex_b = b[0] == bitone,
      };
    } else {
      // Not a prefix — this is the opcode byte
      opcode = b;
      done = true;
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
