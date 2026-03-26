// Isla overrides for symbolic execution.
// This file is passed to isla-sail via -splice to replace function
// definitions that need special handling for Isla's symbolic execution.
// It is NOT included in x86.sail_project (normal builds don't see it).

// Isla's memory primitives
val isla_read_mem = impure "platform_read_mem"
  : forall 'n, 'n > 0. (bits(2), int(64), bits(64), int('n)) -> bits(8 * 'n)

val isla_write_mem = impure "platform_write_mem"
  : forall 'n, 'n > 0. (bits(2), int(64), bits(64), int('n), bits(8 * 'n)) -> bool

// Override memory primitives to use Isla's platform memory
function phys_read(addr, n) = isla_read_mem(0b00, 64, addr, n)
function phys_write(addr, n, data) = {
  let _ = isla_write_mem(0b00, 64, addr, n, data);
  ()
}

function translate_addr(linear, access) = linear
function __check_pending_irq() = -1
function __mem_read_crossing(addr, n, access) = phys_read(addr, n)
function __mem_write_crossing(addr, n, data) = phys_write(addr, n, data)

// Override fetch to read from insn_buf register.
// Uses byte index from low 4 bits of decode_pos (base is page-aligned).
function fetch(n) = {
  if unsigned(decode_pos) - unsigned(insn_start) + n > 15 then {
    throw(Fault(EXN_GP, 0x00000000))
  };
  let idx = unsigned(decode_pos[3..0]);
  assert(idx + n <= 15, "x86 instructions are at most 15 bytes");
  let result : bits(8 * 'n) = insn_buf[(8 * (idx + n) - 1) .. (8 * idx)];
  decode_pos = decode_pos + n;
  result
}

// Simplified step: no try/catch, no interrupt check.
function step() = {
  fault_pending = false;
  decode_pos = RIP;
  insn_start = RIP;
  rip_rel_pending = false;
  next_rip = None();

  decode_execute();

  if system_state == SysRunning then
    RIP = match next_rip { Some(t) => t, None() => decode_pos }
}

// Helper: pack instruction bytes into insn_buf and execute.
val setup_and_exec : bits(120) -> unit
function setup_and_exec(bytes) = {
  let base : bits(64) = 0x0000000000400000;
  RIP = base;
  insn_start = base;
  insn_buf = bytes;
  let _ = step();
  ()
}

// ADD r64, imm32: REX.W + 81 /0 + ModR/M + imm32
val isla_test_add_r64_imm32 : (bits(4), bits(32)) -> unit
function isla_test_add_r64_imm32(reg, imm) = {
  let rex : bits(8) = 0x48 | (0b0000000 @ reg[3]);
  let modrm : bits(8) = 0xC0 | (0b00000 @ reg[2..0]);
  let bytes : bits(120) =
    0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @
    imm[31..24] @ imm[23..16] @ imm[15..8] @ imm[7..0] @
    modrm @ 0x81 @ rex;
  setup_and_exec(bytes)
}

// MOV r64, imm64: REX.W + B8+rd + imm64
val isla_test_mov_r64_imm64 : (bits(4), bits(64)) -> unit
function isla_test_mov_r64_imm64(reg, imm) = {
  let rex : bits(8) = 0x48 | (0b0000000 @ reg[3]);
  let opcode : bits(8) = 0xB8 | (0b00000 @ reg[2..0]);
  let bytes : bits(120) =
    0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @
    imm[63..56] @ imm[55..48] @ imm[47..40] @ imm[39..32] @
    imm[31..24] @ imm[23..16] @ imm[15..8] @ imm[7..0] @
    opcode @ rex;
  setup_and_exec(bytes)
}

// SHL r64, imm8: REX.W + C1 /4 + ModR/M + imm8
val isla_test_shl_r64_imm8 : (bits(4), bits(8)) -> unit
function isla_test_shl_r64_imm8(reg, imm) = {
  let rex : bits(8) = 0x48 | (0b0000000 @ reg[3]);
  let modrm : bits(8) = 0xE0 | (0b00000 @ reg[2..0]);
  let bytes : bits(120) =
    0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @
    0xF4 @ 0xF4 @ 0xF4 @
    imm @ modrm @ 0xC1 @ rex;
  setup_and_exec(bytes)
}

function main() = {
  let _ = step();
  isla_test_add_r64_imm32(0b0000, 0x00000000);
  isla_test_mov_r64_imm64(0b0000, 0x0000000000000000);
  isla_test_shl_r64_imm8(0b0000, 0x00);
  ()
}
