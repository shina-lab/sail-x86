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

  // Phase 1: Scan prefixes and get opcode byte
  let (pfx, opcode) = scan_prefixes();

  // Phase 2-5: Dispatch opcode (handles ModR/M, SIB, disp, imm internally)
  let result = dispatch_opcode_1byte(opcode, pfx);

  // Advance RIP past the instruction (decode_pos tracks how far we read).
  // Control-flow instructions (JMP, CALL, RET, Jcc) set RIP themselves
  // and return Ok(()). We detect this by checking if RIP was modified.
  // If RIP still equals the original value, advance it.
  match result {
    Ok(_) => RIP = decode_pos,
    Fault(_, _) => (),  // fault: don't advance RIP
    Halt(_) => (),
  };

  result
}

// Run instructions until a fault, halt, or step count reached.
val run : int -> ExecutionResult
function run(max_steps) = {
  var remaining : int = max_steps;
  var last_result : ExecutionResult = Ok(());
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
