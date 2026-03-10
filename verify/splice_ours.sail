// Isla entry points for sail-x86 model.
// Provides wrappers for symbolic execution and comparison.

val isla_reset_registers = pure "reset_registers" : unit -> unit

// Wrapper for ADD 64-bit: takes two 64-bit operands, returns result
// and flag values (CF, PF, AF, ZF, SF, OF) as a struct.
// This normalizes our flag-as-side-effect model into a pure function return.
val compare_add64 : (bits(64), bits(64)) -> (bits(64), bit, bit, bit, bit, bit, bit)
function compare_add64(a, b) = {
  let (result, _) = alu_compute(ALU_ADD, a, b, OS64);
  (result, CF, PF, AF, ZF, SF, OF)
}

val compare_sub64 : (bits(64), bits(64)) -> (bits(64), bit, bit, bit, bit, bit, bit)
function compare_sub64(a, b) = {
  let (result, _) = alu_compute(ALU_SUB, a, b, OS64);
  (result, CF, PF, AF, ZF, SF, OF)
}

val compare_and64 : (bits(64), bits(64)) -> (bits(64), bit, bit, bit, bit, bit, bit)
function compare_and64(a, b) = {
  let (result, _) = alu_compute(ALU_AND, a, b, OS64);
  (result, CF, PF, AF, ZF, SF, OF)
}

val compare_or64 : (bits(64), bits(64)) -> (bits(64), bit, bit, bit, bit, bit, bit)
function compare_or64(a, b) = {
  let (result, _) = alu_compute(ALU_OR, a, b, OS64);
  (result, CF, PF, AF, ZF, SF, OF)
}

val compare_xor64 : (bits(64), bits(64)) -> (bits(64), bit, bit, bit, bit, bit, bit)
function compare_xor64(a, b) = {
  let (result, _) = alu_compute(ALU_XOR, a, b, OS64);
  (result, CF, PF, AF, ZF, SF, OF)
}

val compare_adc64 : (bits(64), bits(64), bit) -> (bits(64), bit, bit, bit, bit, bit, bit)
function compare_adc64(a, b, carry_in) = {
  CF = carry_in;
  let (result, _) = alu_compute(ALU_ADC, a, b, OS64);
  (result, CF, PF, AF, ZF, SF, OF)
}

val compare_sbb64 : (bits(64), bits(64), bit) -> (bits(64), bit, bit, bit, bit, bit, bit)
function compare_sbb64(a, b, borrow_in) = {
  CF = borrow_in;
  let (result, _) = alu_compute(ALU_SBB, a, b, OS64);
  (result, CF, PF, AF, ZF, SF, OF)
}

// 32-bit variants
val compare_add32 : (bits(64), bits(64)) -> (bits(64), bit, bit, bit, bit, bit, bit)
function compare_add32(a, b) = {
  let (result, _) = alu_compute(ALU_ADD, a, b, OS32);
  (result, CF, PF, AF, ZF, SF, OF)
}

val compare_sub32 : (bits(64), bits(64)) -> (bits(64), bit, bit, bit, bit, bit, bit)
function compare_sub32(a, b) = {
  let (result, _) = alu_compute(ALU_SUB, a, b, OS32);
  (result, CF, PF, AF, ZF, SF, OF)
}

// Isla footprint for full decode+execute
val isla_footprint : bits(120) -> bool
function isla_footprint(opcode) = {
  try {
    isla_reset_registers();
    system_mode = false;
    decode_pos = RIP;
    insn_start = RIP;
    rip_rel_pending = false;
    next_rip = None();
    let (pfx, opcode_byte) = scan_prefixes();
    let result = dispatch_opcode_1byte(opcode_byte, pfx);
    match result {
      Ok(_) => RIP = match next_rip { Some(t) => t, None() => decode_pos },
      _ => (),
    };
    true
  } catch {
    _ => false
  }
}
