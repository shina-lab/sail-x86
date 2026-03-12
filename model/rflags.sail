// x86-64 — RFLAGS Register and Flag Computation

// RFLAGS register. We model individual flags as separate registers
// for clarity, since different instructions update different subsets.

register CF : bit  // Carry Flag
register PF : bit  // Parity Flag
register AF : bit  // Auxiliary Carry Flag
register ZF : bit  // Zero Flag
register SF : bit  // Sign Flag
register OF : bit  // Overflow Flag
register DF : bit  // Direction Flag
register IF_flag : bit  // Interrupt Enable Flag (IF is a Sail keyword)
register TF : bit  // Trap Flag
register IOPL : bits(2)  // I/O Privilege Level
register NT : bit  // Nested Task
register RF : bit  // Resume Flag
register ID : bit  // ID Flag (CPUID available if toggleable)
register AC_flag : bit // Alignment Check flag

// Pack individual flags into a 64-bit RFLAGS value.
// Bits: 0=CF, 1=1(reserved), 2=PF, 4=AF, 6=ZF, 7=SF, 8=TF, 9=IF, 10=DF,
//       11=OF, 13:12=IOPL, 14=NT, 16=RF, 17=VM, 18=AC, 21=ID
val read_rflags : unit -> qword
function read_rflags() = {
  var r : qword = zeros();
  r[0] = CF;
  r[1] = bitone;  // reserved, always 1
  r[2] = PF;
  r[4] = AF;
  r[6] = ZF;
  r[7] = SF;
  r[8] = TF;
  r[9] = IF_flag;
  r[10] = DF;
  r[11] = OF;
  r[13..12] = IOPL;
  r[14] = NT;
  r[16] = RF;
  r[18] = AC_flag;
  r[21] = ID;
  r
}

// Write all individual flags from a packed RFLAGS value.
// This sets CF, PF, AF, ZF, SF, TF, IF, DF, OF, IOPL, NT, AC, ID.
// RF and VM are NOT set (they have special handling).
val write_rflags : qword -> unit
function write_rflags(v) = {
  CF      = v[0];
  PF      = v[2];
  AF      = v[4];
  ZF      = v[6];
  SF      = v[7];
  TF      = v[8];
  IF_flag = v[9];
  DF      = v[10];
  OF      = v[11];
  IOPL    = v[13..12];
  NT      = v[14];
  AC_flag = v[18];
  ID      = v[21];
}

// Compute the parity of the low 8 bits of a value.
// PF is set if the number of set bits in the low byte is even.
val compute_PF : byte -> bit
function compute_PF(val8) = {
  let p = val8[0] ^ val8[1] ^ val8[2] ^ val8[3] ^
          val8[4] ^ val8[5] ^ val8[6] ^ val8[7];
  // PF=1 means even parity, so invert
  bool_to_bit(p == bitzero)
}

// Update SF, ZF, PF based on a result value.
// These three flags are set identically by most arithmetic/logic instructions.
val update_SF_ZF_PF : forall 'n, 'n >= 8. bits('n) -> unit
function update_SF_ZF_PF(result) = {
  SF = result['n - 1];
  ZF = bool_to_bit(result == zeros());
  PF = compute_PF(result[7..0])
}

// Compute OF, AF, SF, ZF, PF for addition without modifying CF.
// Used by INC which must preserve CF.
val update_flags_add_no_cf : forall 'n, 'n >= 8. (bits('n), bits('n), bits('n)) -> unit
function update_flags_add_no_cf(result, a, b) = {
  OF = bool_to_bit((a['n - 1] == b['n - 1]) & (result['n - 1] != a['n - 1]));
  AF = bool_to_bit(unsigned(result[3..0]) != unsigned(a[3..0]) + unsigned(b[3..0]));
  update_SF_ZF_PF(result)
}

// Compute OF, AF, SF, ZF, PF for subtraction without modifying CF.
// Used by DEC which must preserve CF.
val update_flags_sub_no_cf : forall 'n, 'n >= 8. (bits('n), bits('n), bits('n)) -> unit
function update_flags_sub_no_cf(result, a, b) = {
  OF = bool_to_bit((a['n - 1] != b['n - 1]) & (result['n - 1] != a['n - 1]));
  AF = bool_to_bit(unsigned(a[3..0]) < unsigned(b[3..0]));
  update_SF_ZF_PF(result)
}

// Compute CF and OF for addition: dest = a + b.
val update_flags_add : forall 'n, 'n >= 8. (bits('n), bits('n), bits('n)) -> unit
function update_flags_add(result, a, b) = {
  // CF: unsigned overflow
  CF = bool_to_bit(unsigned(result) != unsigned(a) + unsigned(b));
  // OF: signed overflow — occurs when both operands have the same sign
  // but the result has a different sign
  OF = bool_to_bit((a['n - 1] == b['n - 1]) & (result['n - 1] != a['n - 1]));
  // AF: carry out of bit 3
  AF = bool_to_bit(unsigned(result[3..0]) != unsigned(a[3..0]) + unsigned(b[3..0]));
  update_SF_ZF_PF(result)
}

// Compute CF and OF for subtraction: dest = a - b.
val update_flags_sub : forall 'n, 'n >= 8. (bits('n), bits('n), bits('n)) -> unit
function update_flags_sub(result, a, b) = {
  // CF: borrow (unsigned underflow)
  CF = bool_to_bit(unsigned(a) < unsigned(b));
  // OF: signed overflow — occurs when operands have different signs
  // and result sign differs from first operand
  OF = bool_to_bit((a['n - 1] != b['n - 1]) & (result['n - 1] != a['n - 1]));
  // AF: borrow out of bit 3
  AF = bool_to_bit(unsigned(a[3..0]) < unsigned(b[3..0]));
  update_SF_ZF_PF(result)
}

// Compute CF and OF for addition with carry: dest = a + b + carry_in.
val update_flags_adc : forall 'n, 'n >= 8. (bits('n), bits('n), bits('n), bit) -> unit
function update_flags_adc(result, a, b, carry_in) = {
  let c : int = unsigned(zero_extend(carry_in) : bits(1));
  CF = bool_to_bit(unsigned(result) != unsigned(a) + unsigned(b) + c);
  OF = bool_to_bit(signed(result) != signed(a) + signed(b) + c);
  AF = bool_to_bit(unsigned(result[3..0]) != unsigned(a[3..0]) + unsigned(b[3..0]) + c);
  update_SF_ZF_PF(result)
}

// Compute CF and OF for subtraction with borrow: dest = a - b - borrow_in.
val update_flags_sbb : forall 'n, 'n >= 8. (bits('n), bits('n), bits('n), bit) -> unit
function update_flags_sbb(result, a, b, borrow_in) = {
  let bw : int = unsigned(zero_extend(borrow_in) : bits(1));
  CF = bool_to_bit(unsigned(a) < unsigned(b) + bw);
  OF = bool_to_bit(signed(result) != signed(a) - signed(b) - bw);
  AF = bool_to_bit(unsigned(a[3..0]) < unsigned(b[3..0]) + bw);
  update_SF_ZF_PF(result)
}

// Evaluate an x86 condition code (4-bit, from Jcc/CMOVcc/SETcc opcodes).
// The condition codes correspond to the low 4 bits of the opcode:
//   0=O  1=NO  2=B   3=AE  4=E   5=NE  6=BE  7=A
//   8=S  9=NS  A=P   B=NP  C=L   D=GE  E=LE  F=G
type cc_idx = range(0, 15)

val eval_cc : cc_idx -> bool
function eval_cc(cc) = match cc {
  0  => OF == bitone,                                    // O
  1  => OF == bitzero,                                   // NO
  2  => CF == bitone,                                    // B/C/NAE
  3  => CF == bitzero,                                   // AE/NB/NC
  4  => ZF == bitone,                                    // E/Z
  5  => ZF == bitzero,                                   // NE/NZ
  6  => CF == bitone | ZF == bitone,                     // BE/NA
  7  => CF == bitzero & ZF == bitzero,                   // A/NBE
  8  => SF == bitone,                                    // S
  9  => SF == bitzero,                                   // NS
  10 => PF == bitone,                                    // P/PE
  11 => PF == bitzero,                                   // NP/PO
  12 => SF != OF,                                        // L/NGE
  13 => SF == OF,                                        // GE/NL
  14 => ZF == bitone | SF != OF,                         // LE/NG
  15 => ZF == bitzero & SF == OF,                        // G/NLE
}

// Update flags for logical operations (AND, OR, XOR).
// CF and OF are cleared; AF is undefined per SDM.
val update_flags_logic : forall 'n, 'n >= 8. bits('n) -> unit
function update_flags_logic(result) = {
  CF = bitzero;
  OF = bitzero;
  AF = undefined;
  update_SF_ZF_PF(result)
}
