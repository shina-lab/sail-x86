// x86-64 — Fetch-Decode-Execute Loop
//
// Top-level entry point for the instruction cycle.
// Fetches and decodes one instruction from RIP, executes it,
// and advances RIP past the instruction bytes.

// Check for and acknowledge a pending external interrupt.
// Returns the vector number, or -1 if no interrupt pending.
// Implemented in C++ — checks device state.
val __check_pending_irq : unit -> int

// Decode and execute one instruction.
// Sets fault_pending/fault_vector/fault_error_code on exception.
val step : unit -> unit
function step() = {
  fault_pending = false;

  // Check for pending external interrupts before fetching.
  // Only deliver if IF=1 (interrupts enabled) and in system mode.
  if system_mode & IF_flag == bitone then {
    let irq_vec = __check_pending_irq();
    if 0 <= irq_vec & irq_vec <= 255 then {
      let vec : exception_vector = irq_vec;
      try {
        deliver_exception(vec, 0x00000000, false);
        return ()
      } catch {
        Fault(vec2, err2) => {
          fault_pending = true;
          fault_vector = vec2;
          fault_error_code = err2;
          return ()
        },
      }
    }
  };

  // Set decode position to current RIP
  decode_pos = RIP;
  insn_start = RIP;
  rip_rel_pending = false;
  next_rip = None();

  let faulted : bool =
    try {
      // Decode and execute one instruction
      decode_execute();
      false
    } catch {
      Fault(vec, err) => {
        if system_mode then {
          // In system mode, deliver faults through the IDT.
          try {
            deliver_exception(vec, err, false);
            // RIP already set to handler by deliver_exception; skip normal advance
            return ()
          } catch {
            // deliver_exception itself faulted — double/triple fault
            Fault(vec2, err2) => {
              fault_pending = true;
              fault_vector = vec2;
              fault_error_code = err2;
              return ()
            },
          }
        } else {
          fault_pending = true;
          fault_vector = vec;
          fault_error_code = err;
          true
        }
      },
    };

  // Advance RIP unless we faulted or halted.
  // Control-flow instructions set next_rip to the branch target;
  // otherwise we fall through to the next instruction.
  if ~(faulted) & system_state == SysRunning then
    RIP = match next_rip { Some(t) => t, None() => decode_pos }
}

// Run instructions until a fault, halt, or step count reached.
val run : int -> unit
function run(max_steps) = {
  var remaining : int = max_steps;

  while remaining > 0 & ~(fault_pending) & system_state == SysRunning do {
    step();
    remaining = remaining - 1
  }
}

// Dummy main function required by the Sail C++ backend.
val main : unit -> unit
function main() = ()
