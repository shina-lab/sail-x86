// LOOP/LOOPcc — Loop According to ECX Counter
//
// Decrements RCX/ECX/CX, then jumps to target if count != 0.
// LOOPE: also requires ZF=1. LOOPNE: also requires ZF=0.
// No flags affected. We model 64-bit address size (RCX).

enum LoopVariant = { LOOP_always, LOOP_e, LOOP_ne }

val exec_loop : (byte, LoopVariant, AddressSize) -> ExecutionResult
function exec_loop(rel8, variant, asz) = {
  // Decrement counter based on address size
  match asz {
    AS64 => write_gpr64(RCX, read_gpr64(RCX) - 1),
    AS32 => write_gpr32(RCX, read_gpr32(RCX) - 1),
    AS16 => write_gpr16(RCX, read_gpr16(RCX) - 1),
  };
  let count_nonzero : bool = match asz {
    AS64 => read_gpr64(RCX) != zeros(),
    AS32 => read_gpr32(RCX) != zeros(),
    AS16 => read_gpr16(RCX) != zeros(),
  };
  let take_branch : bool = match variant {
    LOOP_always => count_nonzero,
    LOOP_e      => if count_nonzero then ZF == bitone else false,
    LOOP_ne     => if count_nonzero then ZF == bitzero else false,
  };
  if take_branch then {
    let new_rip = decode_pos + sign_extend(rel8);
    RIP = new_rip;
    decode_pos = new_rip;
  };
  Ok(())
}
