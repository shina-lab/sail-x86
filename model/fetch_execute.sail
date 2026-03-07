// x86-64 Decoder — Fetch-Decode-Execute Loop
//
// Top-level entry point for the instruction cycle.
// Fetches and decodes one instruction from RIP, executes it,
// and advances RIP past the instruction bytes.

// Decode and execute one instruction.
// Returns the execution result (Ok, Fault, or Halt).
val step : unit -> ExecutionResult
function step() = {
  // Set decode position to current RIP
  decode_pos = RIP;
  rip_rel_pending = false;
  next_rip = None();

  // Phase 1: Scan prefixes and get opcode byte
  let (pfx, opcode) = scan_prefixes();

  // Phase 2-5: Dispatch opcode (handles ModR/M, SIB, disp, imm internally)
  let result = dispatch_opcode_1byte(opcode, pfx);

  // Advance RIP. Control-flow instructions set next_rip to the branch
  // target; otherwise we fall through to the next instruction.
  match result {
    Ok(_) => RIP = match next_rip { Some(t) => t, None() => decode_pos },
    Fault(_, _) => (),
    Halt(_) => (),
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
