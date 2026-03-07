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
  Ok()
}
// JMP — Jump
//
// Transfers control to a different point in the instruction stream.
// No flags are affected. RIP is assumed to already point past the
// JMP instruction itself (advanced by decoder).

// JMP near relative: RIP := decode_pos + sign-extended offset
// (decode_pos points past the JMP instruction)
val exec_jmp_rel : qword -> ExecutionResult
function exec_jmp_rel(offset) = {
  let new_rip = decode_pos + offset;
  RIP = new_rip;
  decode_pos = new_rip;
  Ok()
}

// JMP near absolute indirect: RIP := value from register
val exec_jmp_abs : qword -> ExecutionResult
function exec_jmp_abs(target) = {
  RIP = target;
  decode_pos = target;
  Ok()
}
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
  Ok()
}
// INT imm8 — Software Interrupt
//
// These trigger software interrupts. The exact behavior is highly
// implementation-dependent, so we model them as external calls.

val __software_interrupt : byte -> ExecutionResult

// PUSH imm
val exec_push_imm : (qword, OperandSize) -> ExecutionResult
function exec_push_imm(imm, os) = {
  match os {
    OS64 => push64(imm),
    OS32 => push64(imm),
    OS16 => push16(imm[15..0]),
    _ => (),
  };
  Ok()
}
// POP — Pop a Value from the Stack
//
// Loads the value from the top of the stack to a register,
// then increments RSP.
// No flags are affected.

val exec_pop_reg : (gpr_idx, OperandSize) -> ExecutionResult
function exec_pop_reg(dst, os) = {
  match os {
    OS64 => write_gpr64(dst, pop64()),
    OS32 => write_gpr32(dst, pop64()[31..0]),
    OS16 => write_gpr16(dst, pop16()),
    _ => (),
  };
  Ok()
}
