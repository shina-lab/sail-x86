// Jcc — Jump if Condition Is Met
//
// Checks status flags and jumps if condition is satisfied.
// RIP is assumed to already point past the Jcc instruction (advanced by decoder).
// The offset is sign-extended to 64 bits by the decoder.
// No flags are affected.

val exec_jcc : (cc_idx, qword) -> ExecutionResult
function exec_jcc(cc, offset) = {
  if eval_cc(cc) then {
    let new_rip = decode_pos + offset;
    RIP = new_rip;
    decode_pos = new_rip;
  };
  Ok(())
}
