// x86-64 Decoder — Fetch-Decode-Execute Loop
//
// Top-level entry point for the instruction cycle.
// Fetches and decodes one instruction from RIP, executes it,
// and advances RIP past the instruction bytes.

// Check for and acknowledge a pending external interrupt.
// Returns the vector number, or -1 if no interrupt pending.
// Implemented in C++ — checks device state.
val __check_pending_irq : unit -> int

// Decode and execute one instruction.
// Returns the execution result (Ok, Fault, or Halt).
val step : unit -> ExecutionResult
function step() = {
  // Check for pending external interrupts before fetching.
  // Only deliver if IF=1 (interrupts enabled) and in system mode.
  if system_mode & IF_flag == bitone then {
    let irq_vec = __check_pending_irq();
    if 0 <= irq_vec & irq_vec <= 255 then {
      let vec : exception_vector = irq_vec;
      try {
        deliver_exception(vec, 0x00000000, false);
        return Ok()
      } catch {
        X86Fault(vec2, err2) => return Fault(vec2, err2),
      }
    }
  };

  // Set decode position to current RIP
  decode_pos = RIP;
  insn_start = RIP;
  rip_rel_pending = false;
  next_rip = None();

  let result : ExecutionResult =
    try {
      // Phase 1: Scan prefixes and get opcode byte
      let (pfx, opcode) = scan_prefixes();

      // Phase 2-5: Dispatch opcode (handles ModR/M, SIB, disp, imm internally)
      dispatch_opcode_1byte(opcode, pfx)
    } catch {
      X86Fault(vec, err) => Fault(vec, err),
    };

  // In system mode, deliver faults through the IDT instead of returning them.
  // deliver_exception sets RIP to the handler address, so we must not
  // overwrite it with the normal RIP advance logic.
  let result : ExecutionResult = match result {
    Fault(vec, err) if system_mode => {
      try {
        deliver_exception(vec, err, false);
        // RIP already set to handler by deliver_exception; skip normal advance
        Ok()
      } catch {
        // deliver_exception itself faulted — triple fault
        X86Fault(vec2, err2) => Fault(vec2, err2),
      }
    },
    _ => {
      // Advance RIP. Control-flow instructions set next_rip to the branch
      // target; otherwise we fall through to the next instruction.
      match result {
        Ok(_) => RIP = match next_rip { Some(t) => t, None() => decode_pos },
        Fault(_, _) => (),
        Halt(_) => (),
      };
      result
    },
  };

  result
}

// Run instructions until a fault, halt, or step count reached.
val run : int -> ExecutionResult
function run(max_steps) = {
  var remaining : int = max_steps;
  var last_result : ExecutionResult = Ok();
  var done : bool = false;

  while not_bool(done) & remaining > 0 do {
    last_result = step();
    match last_result {
      Ok(_) => remaining = remaining - 1,
      Fault(_, _) => done = true,
      Halt(_) => done = true,
    }
  };

  last_result
}

// Dummy main function required by the Sail C++ backend.
val main : unit -> unit
function main() = ()
