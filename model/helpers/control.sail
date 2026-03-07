// CALL — Call Procedure
//
// Pushes return address (current RIP) onto the stack, then jumps.
// RIP is assumed to already point past the CALL instruction (advanced by decoder).
// No flags are affected.

// CALL near relative: push return address, then RIP := decode_pos + offset
// decode_pos points past the instruction (the return address).
val exec_call_rel : (qword, OperandSize) -> ExecutionResult
function exec_call_rel(offset, os) = {
  let return_addr = decode_pos;
  match os {
    OS64 => push64(return_addr),
    OS32 => push64(zero_extend(return_addr[31..0])),
    OS16 => push16(return_addr[15..0]),
    _ => (),
  };
  let new_rip = return_addr + offset;
  RIP = new_rip;
  decode_pos = new_rip;
  Ok(())
}

// CALL near absolute indirect: push return address, then RIP := target
val exec_call_abs : (qword, OperandSize) -> ExecutionResult
function exec_call_abs(target, os) = {
  let return_addr = decode_pos;
  match os {
    OS64 => push64(return_addr),
    OS32 => push64(zero_extend(return_addr[31..0])),
    OS16 => push16(return_addr[15..0]),
    _ => (),
  };
  RIP = target;
  decode_pos = target;
  Ok(())
}
// RET — Return from Procedure
//
// Pops a return address from the stack into RIP.
// Optionally adds an immediate value to RSP to release stack parameters.
// No flags are affected (near return).

// RET near (no immediate)
val exec_ret : OperandSize -> ExecutionResult
function exec_ret(os) = {
  let target : qword = match os {
    OS64 => pop64(),
    OS32 => zero_extend(pop64()[31..0]),
    OS16 => zero_extend(pop16()),
    OS8 => zeros(),
  };
  RIP = target;
  decode_pos = target;
  Ok(())
}

// RET near with immediate (release stack parameters)
val exec_ret_imm : (word, OperandSize) -> ExecutionResult
function exec_ret_imm(imm, os) = {
  let target : qword = match os {
    OS64 => pop64(),
    OS32 => zero_extend(pop64()[31..0]),
    OS16 => zero_extend(pop16()),
    OS8 => zeros(),
  };
  RIP = target;
  decode_pos = target;
  GPR[RSP] = GPR[RSP] + zero_extend(imm);
  Ok(())
}
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
  Ok(())
}

// JMP near absolute indirect: RIP := value from register
val exec_jmp_abs : qword -> ExecutionResult
function exec_jmp_abs(target) = {
  RIP = target;
  decode_pos = target;
  Ok(())
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
  Ok(())
}
// INT imm8 — Software Interrupt
// INT3 — Breakpoint (opcode 0xCC)
// INTO — Interrupt on Overflow (opcode 0xCE, invalid in 64-bit mode)
//
// These trigger software interrupts. The exact behavior (pushing flags,
// looking up IDT entries, switching privilege levels) is highly
// implementation-dependent, so we model them as external calls.

val __software_interrupt : byte -> ExecutionResult

// INT imm8
val exec_int : byte -> ExecutionResult
function exec_int(imm8) = __software_interrupt(imm8)

// INT3 (breakpoint)
val exec_int3 : unit -> ExecutionResult
function exec_int3() = __software_interrupt(0x03)

// ENTER — Make Stack Frame for Procedure Parameters
//
// Creates a stack frame. imm16 = dynamic storage size, imm8 = nesting level.
// Nesting level 0 is the common case (simple procedure frame).
// We model 64-bit mode only (OperandSize=64 default, or 16 with 66H prefix).

val exec_enter : (word, byte, OperandSize) -> ExecutionResult
function exec_enter(alloc_size, nesting_raw, os) = {
  let nesting : range(0, 31) = unsigned(nesting_raw) % 32;
  match os {
    OS64 => {
      push64(read_gpr64(RBP));
      let frame_temp : qword = read_gpr64(RSP);
      if nesting > 1 then {
        foreach (i from 1 to (nesting - 1)) {
          write_gpr64(RBP, read_gpr64(RBP) - 8);
          push64(mem_read64(read_gpr64(RBP)));
        };
      };
      if nesting >= 1 then
        push64(frame_temp);
      write_gpr64(RBP, frame_temp);
      write_gpr64(RSP, read_gpr64(RSP) - zero_extend(alloc_size));
    },
    OS16 => {
      push16(read_gpr16(RBP));
      let frame_temp : word = read_gpr16(RSP);
      if nesting > 1 then {
        foreach (i from 1 to (nesting - 1)) {
          write_gpr16(RBP, read_gpr16(RBP) - 2);
          push16(mem_read16(zero_extend(read_gpr16(RBP))));
        };
      };
      if nesting >= 1 then
        push16(frame_temp);
      write_gpr16(RBP, frame_temp);
      write_gpr64(RSP, read_gpr64(RSP) - zero_extend(alloc_size));
    },
    _ => (),
  };
  Ok(())
}
// LEAVE — High Level Procedure Exit
//
// Copies frame pointer (RBP) into stack pointer (RSP), then pops RBP.
// No flags affected.

val exec_leave : OperandSize -> ExecutionResult
function exec_leave(os) = {
  match os {
    OS64 => {
      write_gpr64(RSP, read_gpr64(RBP));
      write_gpr64(RBP, pop64());
    },
    OS32 => {
      write_gpr64(RSP, zero_extend(read_gpr32(RBP)));
      let v : qword = pop64();
      write_gpr32(RBP, v[31..0]);
    },
    OS16 => {
      write_gpr16(RSP, read_gpr16(RBP));
      write_gpr16(RBP, pop16());
    },
    _ => (),
  };
  Ok(())
}
// PUSH — Push Value Onto the Stack
//
// Decrements RSP and stores the source operand on top of the stack.
// No flags are affected.

// PUSH reg
val exec_push_reg : (gpr_idx, OperandSize) -> ExecutionResult
function exec_push_reg(src, os) = {
  match os {
    OS64 => push64(read_gpr64(src)),
    OS32 => push64(zero_extend(read_gpr32(src))),
    OS16 => push16(read_gpr16(src)),
    _ => (),
  };
  Ok(())
}

// PUSH imm
val exec_push_imm : (qword, OperandSize) -> ExecutionResult
function exec_push_imm(imm, os) = {
  match os {
    OS64 => push64(imm),
    OS32 => push64(imm),
    OS16 => push16(imm[15..0]),
    _ => (),
  };
  Ok(())
}
// POP — Pop a Value from the Stack
//
// Loads the value from the top of the stack to a register,
// then increments RSP.
// No flags are affected.

// POP reg
val exec_pop_reg : (gpr_idx, OperandSize) -> ExecutionResult
function exec_pop_reg(dst, os) = {
  match os {
    OS64 => write_gpr64(dst, pop64()),
    OS32 => write_gpr32(dst, pop64()[31..0]),
    OS16 => write_gpr16(dst, pop16()),
    _ => (),
  };
  Ok(())
}
// POPF/POPFD/POPFQ — Pop Stack Into EFLAGS Register
//
// Pops flags from stack. In 64-bit mode at CPL=0, all flags except
// VIP, VIF, VM are loaded. At CPL>0, IOPL is not modified.
// Simplified model: assumes CPL=0.

val exec_popf : OperandSize -> ExecutionResult
function exec_popf(os) = {
  match os {
    OS16 => {
      let v : word = pop16();
      CF = v[0];
      PF = v[2];
      AF = v[4];
      ZF = v[6];
      SF = v[7];
      TF = v[8];
      IF_flag = v[9];
      DF = v[10];
      OF = v[11];
    },
    OS64 => {
      let v : qword = pop64();
      CF = v[0];
      PF = v[2];
      AF = v[4];
      ZF = v[6];
      SF = v[7];
      TF = v[8];
      IF_flag = v[9];
      DF = v[10];
      OF = v[11];
      IOPL = v[13..12];
    },
    _ => (),
  };
  Ok(())
}
