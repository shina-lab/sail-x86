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
function __check_pending_irq() = negate(1)
function __mem_read_crossing(addr, n) = phys_read(addr, n)
function __mem_write_crossing(addr, n, data) = phys_write(addr, n, data)

// Override ifetch to read from insn_buf register.
// Use low 4 bits of address as byte index (base is 0x400000, page-aligned).
function ifetch_read8(addr) = {
  let idx : bits(4) = addr[3..0];
  if idx == 0x0 then insn_buf[7..0]
  else if idx == 0x1 then insn_buf[15..8]
  else if idx == 0x2 then insn_buf[23..16]
  else if idx == 0x3 then insn_buf[31..24]
  else if idx == 0x4 then insn_buf[39..32]
  else if idx == 0x5 then insn_buf[47..40]
  else if idx == 0x6 then insn_buf[55..48]
  else if idx == 0x7 then insn_buf[63..56]
  else if idx == 0x8 then insn_buf[71..64]
  else if idx == 0x9 then insn_buf[79..72]
  else if idx == 0xA then insn_buf[87..80]
  else if idx == 0xB then insn_buf[95..88]
  else if idx == 0xC then insn_buf[103..96]
  else if idx == 0xD then insn_buf[111..104]
  else insn_buf[119..112]
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
  let rex : bits(8) = 0x48 | (0b0000000 @ reg[3..3]);
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
  let rex : bits(8) = 0x48 | (0b0000000 @ reg[3..3]);
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
  let rex : bits(8) = 0x48 | (0b0000000 @ reg[3..3]);
  let modrm : bits(8) = 0xE0 | (0b00000 @ reg[2..0]);
  let bytes : bits(120) =
    0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @ 0xF4 @
    0xF4 @ 0xF4 @ 0xF4 @
    imm @ modrm @ 0xC1 @ rex;
  setup_and_exec(bytes)
}

// ============================================================
// Branchless overrides for saturation and min/max helpers.
//
// The default implementations use if/else (e.g., "if diff < 0 then 0
// else diff") which causes Isla to fork on every symbolic byte —
// 16 bytes per psubusb = 2^16 path explosion. These branchless
// versions use pure bitvector ops so Isla produces a single trace.
// ============================================================

// --- OR-reduce helpers (branchless non-zero test) ---

val or_reduce_8 : byte -> bits(1)
function or_reduce_8(v) = {
  let r4 : bits(4) = v[7..4] | v[3..0];
  let r2 : bits(2) = r4[3..2] | r4[1..0];
  r2[1..1] | r2[0..0]
}

val or_reduce_16 : word -> bits(1)
function or_reduce_16(v) = or_reduce_8(v[15..8] | v[7..0])

// --- Comparison helpers (PCMPEQ/PCMPGT) ---

function cmp_eq8(a, b) = {
  let diff : byte = a ^ b;
  let any : bits(1) = or_reduce_8(diff);
  replicate_bits(~(any), 8)
}

function cmp_gt8(a, b) = {
  let diff : bits(9) = sign_extend(a) - sign_extend(b);
  replicate_bits(~(diff[8..8]) & or_reduce_8(diff[7..0]), 8)
}

function cmp_eq16(a, b) = {
  let diff : word = a ^ b;
  let any : bits(1) = or_reduce_16(diff);
  replicate_bits(~(any), 16)
}

function cmp_gt16(a, b) = {
  let diff : bits(17) = sign_extend(a) - sign_extend(b);
  replicate_bits(~(diff[16..16]) & or_reduce_16(diff[15..0]), 16)
}

// --- Unsigned saturation ---

// PSUBUSB: max(a - b, 0) for unsigned bytes
function sat_sub_u8(a, b) = {
  let wide : bits(9) = (0b0 @ a) - (0b0 @ b);
  let mask : byte = replicate_bits(~(wide[8..8]), 8);
  wide[7..0] & mask
}

// PSUBUSW: max(a - b, 0) for unsigned words
function sat_sub_u16(a, b) = {
  let wide : bits(17) = (0b0 @ a) - (0b0 @ b);
  let mask : word = replicate_bits(~(wide[16..16]), 16);
  wide[15..0] & mask
}

// PADDUSB: min(a + b, 255) for unsigned bytes
function sat_add_u8(a, b) = {
  let wide : bits(9) = (0b0 @ a) + (0b0 @ b);
  let sat : byte = replicate_bits(wide[8..8], 8);
  wide[7..0] | sat
}

// PADDUSW: min(a + b, 65535) for unsigned words
function sat_add_u16(a, b) = {
  let wide : bits(17) = (0b0 @ a) + (0b0 @ b);
  let sat : word = replicate_bits(wide[16..16], 16);
  wide[15..0] | sat
}

// --- Unsigned min/max (derived from branchless sat_sub) ---

function min_u8(a, b) = a - sat_sub_u8(a, b)
function max_u8(a, b) = b + sat_sub_u8(a, b)
function min_u16(a, b) = a - sat_sub_u16(a, b)
function max_u16(a, b) = b + sat_sub_u16(a, b)

// --- Pack with saturation (branchless) ---

// PACKUSWB: clamp signed 16-bit to unsigned 8-bit [0, 255]
function sat_s16_to_u8(x) = {
  let neg_mask : word = replicate_bits(x[15..15], 16);
  let pos_val : word = x & ~(neg_mask);
  let overflow : bits(1) = or_reduce_8(pos_val[15..8]);
  let over_mask : byte = replicate_bits(overflow, 8);
  pos_val[7..0] | over_mask
}

// PACKUSDW: clamp signed 32-bit to unsigned 16-bit [0, 65535]
function sat_s32_to_u16(v) = {
  let neg_mask : dword = replicate_bits(v[31..31], 32);
  let pos_val : dword = v & ~(neg_mask);
  let overflow : bits(1) = or_reduce_16(pos_val[31..16]);
  let over_mask : word = replicate_bits(overflow, 16);
  pos_val[15..0] | over_mask
}

// --- Signed saturation (branchless) ---

function sat_add_s8(a, b) = {
  let wide : bits(9) = sign_extend(a) + sign_extend(b);
  let ov : bits(1) = ~(wide[8..8]) & wide[7..7];
  let uf : bits(1) = wide[8..8] & ~(wide[7..7]);
  let ov_mask : byte = replicate_bits(ov, 8);
  let uf_mask : byte = replicate_bits(uf, 8);
  (0x7F & ov_mask) | (0x80 & uf_mask) | (wide[7..0] & ~(ov_mask) & ~(uf_mask))
}

function sat_sub_s8(a, b) = {
  let wide : bits(9) = sign_extend(a) - sign_extend(b);
  let ov : bits(1) = ~(wide[8..8]) & wide[7..7];
  let uf : bits(1) = wide[8..8] & ~(wide[7..7]);
  let ov_mask : byte = replicate_bits(ov, 8);
  let uf_mask : byte = replicate_bits(uf, 8);
  (0x7F & ov_mask) | (0x80 & uf_mask) | (wide[7..0] & ~(ov_mask) & ~(uf_mask))
}

function sat_add_s16(a, b) = {
  let wide : bits(17) = sign_extend(a) + sign_extend(b);
  let ov : bits(1) = ~(wide[16..16]) & wide[15..15];
  let uf : bits(1) = wide[16..16] & ~(wide[15..15]);
  let ov_mask : word = replicate_bits(ov, 16);
  let uf_mask : word = replicate_bits(uf, 16);
  (0x7FFF & ov_mask) | (0x8000 & uf_mask) | (wide[15..0] & ~(ov_mask) & ~(uf_mask))
}

function sat_sub_s16(a, b) = {
  let wide : bits(17) = sign_extend(a) - sign_extend(b);
  let ov : bits(1) = ~(wide[16..16]) & wide[15..15];
  let uf : bits(1) = wide[16..16] & ~(wide[15..15]);
  let ov_mask : word = replicate_bits(ov, 16);
  let uf_mask : word = replicate_bits(uf, 16);
  (0x7FFF & ov_mask) | (0x8000 & uf_mask) | (wide[15..0] & ~(ov_mask) & ~(uf_mask))
}

// --- Signed min/max (branchless via sign of difference) ---

function min_s8(a, b) = {
  let diff : bits(9) = sign_extend(a) - sign_extend(b);
  let a_less : byte = replicate_bits(diff[8..8], 8);
  (a & a_less) | (b & ~(a_less))
}

function max_s8(a, b) = {
  let diff : bits(9) = sign_extend(a) - sign_extend(b);
  let a_less : byte = replicate_bits(diff[8..8], 8);
  (b & a_less) | (a & ~(a_less))
}

function min_s16(a, b) = {
  let diff : bits(17) = sign_extend(a) - sign_extend(b);
  let a_less : word = replicate_bits(diff[16..16], 16);
  (a & a_less) | (b & ~(a_less))
}

function max_s16(a, b) = {
  let diff : bits(17) = sign_extend(a) - sign_extend(b);
  let a_less : word = replicate_bits(diff[16..16], 16);
  (b & a_less) | (a & ~(a_less))
}

function min_s32(a, b) = {
  let diff : bits(33) = sign_extend(a) - sign_extend(b);
  let a_less : dword = replicate_bits(diff[32..32], 32);
  (a & a_less) | (b & ~(a_less))
}

function max_s32(a, b) = {
  let diff : bits(33) = sign_extend(a) - sign_extend(b);
  let a_less : dword = replicate_bits(diff[32..32], 32);
  (b & a_less) | (a & ~(a_less))
}

function min_u32(a, b) = {
  let diff : bits(33) = (0b0 @ a) - (0b0 @ b);
  let a_less : dword = replicate_bits(diff[32..32], 32);
  (a & a_less) | (b & ~(a_less))
}

function max_u32(a, b) = {
  let diff : bits(33) = (0b0 @ a) - (0b0 @ b);
  let a_less : dword = replicate_bits(diff[32..32], 32);
  (b & a_less) | (a & ~(a_less))
}

function main() = {
  let _ = step();
  isla_test_add_r64_imm32(0b0000, 0x00000000);
  isla_test_mov_r64_imm64(0b0000, 0x0000000000000000);
  isla_test_shl_r64_imm8(0b0000, 0x00);
  ()
}
