// x86-64 — x87 FPU Register State
//
// The x87 FPU has an 8-register stack of 80-bit extended precision values.
// Registers are accessed relative to the TOP pointer in the status word.
// The full state includes the control word, status word, and tag word.

register x87_ST : vector(8, fp80)
register x87_cw : word    // control word (default 0x037F)
register x87_sw : word    // status word (default 0x0000)
register x87_tw : word    // tag word (default 0xFFFF = all empty)

val x87_top : unit -> range(0, 7)
function x87_top() = unsigned(x87_sw[13..11])

val x87_set_top : int -> unit
function x87_set_top(t) = {
  x87_sw[13..11] = to_bits_truncate(3, t)
}

val x87_physical : int -> range(0, 7)
function x87_physical(i) = unsigned(to_bits_truncate(3, x87_top() + i))

// Tag word helpers: each register has a 2-bit tag at bits [2*phys+1 .. 2*phys].
// Tag value 3 = empty, anything else = valid.
val x87_mark_valid : range(0, 7) -> unit
function x87_mark_valid(phys) = {
  let shift_amt = 2 * phys;
  let mask : word = ~(0x0003 << shift_amt);
  x87_tw = x87_tw & mask
}

val x87_mark_empty : range(0, 7) -> unit
function x87_mark_empty(phys) = {
  let shift_amt = 2 * phys;
  let bits : word = 0x0003 << shift_amt;
  x87_tw = x87_tw | bits
}

// Read ST(i) — the i-th register from the top of the x87 stack.
val x87_read_st : int -> fp80
function x87_read_st(i) = x87_ST[x87_physical(i)]

// Write a value to ST(i).
val x87_write_st : (int, fp80) -> unit
function x87_write_st(i, v) = {
  x87_ST[x87_physical(i)] = v
}

// Push a value onto the x87 stack (decrement TOP, write to new ST(0)).
val x87_push : fp80 -> unit
function x87_push(v) = {
  let new_top = x87_physical(-1);
  x87_set_top(new_top);
  x87_ST[new_top] = v;
  x87_mark_valid(new_top)
}

// Pop the top of the x87 stack (read ST(0), increment TOP).
val x87_pop : unit -> fp80
function x87_pop() = {
  let cur_top = x87_top();
  let result = x87_ST[cur_top];
  x87_mark_empty(cur_top);
  x87_set_top(x87_physical(1));
  result
}

// Mark ST(i) as empty (used by FFREE).
val x87_free : int -> unit
function x87_free(i) = x87_mark_empty(x87_physical(i))

// Decrement TOP (used by FDECSTP).
val x87_dec_top : unit -> unit
function x87_dec_top() = x87_set_top(x87_physical(-1))

// Increment TOP (used by FINCSTP).
val x87_inc_top : unit -> unit
function x87_inc_top() = x87_set_top(x87_physical(1))

// Initialize x87 state (used by FINIT/FNINIT).
val x87_init : unit -> unit
function x87_init() = {
  x87_cw = 0x037F;
  x87_sw = 0x0000;
  x87_tw = 0xFFFF;
  foreach (i from 0 to 7) {
    x87_ST[i] = zeros()
  }
}

// =========================================================================
// MMX register access
//
// MMX registers MM0-MM7 alias the low 64 bits of the x87 physical registers
// ST(0)-ST(7), accessed by physical index (not relative to TOP).
// Writing an MMX register sets bits [79:64] to all ones and marks the tag
// as valid. All MMX instructions also set TOS (TOP) to 0 and mark all
// tag bits as valid (tag word = 0x0000).
// =========================================================================

val read_mm : range(0, 7) -> qword
function read_mm(idx) = x87_ST[idx][63..0]

val write_mm : (range(0, 7), qword) -> unit
function write_mm(idx, v) = {
  x87_ST[idx] = ones(16) @ v
}

// Called on any MMX instruction: set TOS=0, all tags=valid.
val mmx_touch : unit -> unit
function mmx_touch() = {
  x87_sw[13..11] = 0b000;  // TOP = 0
  x87_tw = 0x0000          // all valid
}

// MMX register index from modrm reg field (3-bit, no REX extension)
val modrm_mm_reg : byte -> range(0, 7)
function modrm_mm_reg(modrm) = unsigned(modrm[5..3])

// MMX register index from modrm r/m field (3-bit, no REX extension)
val modrm_mm_rm : byte -> range(0, 7)
function modrm_mm_rm(modrm) = unsigned(modrm[2..0])

// Save 28-byte x87 environment (CW, SW, TW) as bits(224).
val x87_save_env : unit -> bits(224)
function x87_save_env() = {
  var buf : bits(224) = zeros();
  buf[15..0] = x87_cw;
  buf[47..32] = x87_sw;
  buf[79..64] = x87_tw;
  buf
}

// Load 28-byte x87 environment from bits(224).
val x87_load_env : bits(224) -> unit
function x87_load_env(buf) = {
  x87_cw = buf[15..0];
  x87_sw = buf[47..32];
  x87_tw = buf[79..64]
}

// Save full x87 state (28 bytes env + 8 x 10 bytes regs) as bits(864).
val x87_save_state : unit -> bits(864)
function x87_save_state() = {
  var buf : bits(864) = zeros();
  buf[15..0] = x87_cw;
  buf[47..32] = x87_sw;
  buf[79..64] = x87_tw;
  foreach (i from 0 to 7) {
    let lo = 224 + i * 80;
    buf[(lo + 79) .. lo] = x87_ST[i]
  };
  buf
}

// Load full x87 state from bits(864).
val x87_load_state : bits(864) -> unit
function x87_load_state(buf) = {
  x87_cw = buf[15..0];
  x87_sw = buf[47..32];
  x87_tw = buf[79..64];
  foreach (i from 0 to 7) {
    let lo = 224 + i * 80;
    x87_ST[i] = buf[(lo + 79) .. lo]
  }
}
