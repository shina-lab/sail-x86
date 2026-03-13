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
  let r4 : bits(4) = val8[7..4] ^ val8[3..0];
  let r2 : bits(2) = r4[3..2] ^ r4[1..0];
  let r1 : bits(1) = r2[1..1] ^ r2[0..0];
  // PF=1 means even parity, so invert
  (~(r1))[0]
}

// Update SF, ZF, PF based on a result value.
// These three flags are set identically by most arithmetic/logic instructions.
val update_SF_ZF_PF : forall 'n, 'n >= 8. bits('n) -> unit
function update_SF_ZF_PF(result) = {
  SF = result['n - 1];
  let zf_wide : bits('n + 1) = (0b0 @ result) - 1;
  ZF = zf_wide['n];
  PF = compute_PF(result[7..0])
}

// Compute OF, AF, SF, ZF, PF for addition without modifying CF.
// Used by INC which must preserve CF.
val update_flags_add_no_cf : forall 'n, 'n >= 8. (bits('n), bits('n), bits('n)) -> unit
function update_flags_add_no_cf(result, a, b) = {
  OF = (~(a['n - 1 .. 'n - 1] ^ b['n - 1 .. 'n - 1]) & (result['n - 1 .. 'n - 1] ^ a['n - 1 .. 'n - 1]))[0];
  let af_wide : bits(5) = (0b0 @ a[3..0]) + (0b0 @ b[3..0]);
  AF = af_wide[4];
  update_SF_ZF_PF(result)
}

// Compute OF, AF, SF, ZF, PF for subtraction without modifying CF.
// Used by DEC which must preserve CF.
val update_flags_sub_no_cf : forall 'n, 'n >= 8. (bits('n), bits('n), bits('n)) -> unit
function update_flags_sub_no_cf(result, a, b) = {
  OF = ((a['n - 1 .. 'n - 1] ^ b['n - 1 .. 'n - 1]) & (result['n - 1 .. 'n - 1] ^ a['n - 1 .. 'n - 1]))[0];
  let af_wide : bits(5) = (0b0 @ a[3..0]) - (0b0 @ b[3..0]);
  AF = af_wide[4];
  update_SF_ZF_PF(result)
}

// Compute CF and OF for addition: dest = a + b.
val update_flags_add : forall 'n, 'n >= 8. (bits('n), bits('n), bits('n)) -> unit
function update_flags_add(result, a, b) = {
  // CF: carry bit from wide addition
  let cf_wide : bits('n + 1) = (0b0 @ a) + (0b0 @ b);
  CF = cf_wide['n];
  // OF: signed overflow — same sign inputs, different sign result
  OF = (~(a['n - 1 .. 'n - 1] ^ b['n - 1 .. 'n - 1]) & (result['n - 1 .. 'n - 1] ^ a['n - 1 .. 'n - 1]))[0];
  // AF: carry out of bit 3
  let af_wide : bits(5) = (0b0 @ a[3..0]) + (0b0 @ b[3..0]);
  AF = af_wide[4];
  update_SF_ZF_PF(result)
}

// Compute CF and OF for subtraction: dest = a - b.
val update_flags_sub : forall 'n, 'n >= 8. (bits('n), bits('n), bits('n)) -> unit
function update_flags_sub(result, a, b) = {
  // CF: borrow bit from wide subtraction
  let cf_wide : bits('n + 1) = (0b0 @ a) - (0b0 @ b);
  CF = cf_wide['n];
  // OF: signed overflow — different sign inputs, result sign differs from a
  OF = ((a['n - 1 .. 'n - 1] ^ b['n - 1 .. 'n - 1]) & (result['n - 1 .. 'n - 1] ^ a['n - 1 .. 'n - 1]))[0];
  // AF: borrow out of bit 3
  let af_wide : bits(5) = (0b0 @ a[3..0]) - (0b0 @ b[3..0]);
  AF = af_wide[4];
  update_SF_ZF_PF(result)
}

// Compute CF and OF for addition with carry: dest = a + b + carry_in.
val update_flags_adc : forall 'n, 'n >= 8. (bits('n), bits('n), bits('n), bit) -> unit
function update_flags_adc(result, a, b, carry_in) = {
  // CF: carry bit from wide addition with carry_in
  let cf_wide : bits('n + 1) = (0b0 @ a) + (0b0 @ b) + zero_extend(carry_in);
  CF = cf_wide['n];
  // OF: signed overflow from wide signed addition
  let of_wide : bits('n + 1) = sign_extend(a) + sign_extend(b) + zero_extend(carry_in);
  OF = (of_wide['n .. 'n] ^ of_wide['n - 1 .. 'n - 1])[0];
  // AF: nibble carry with carry_in
  let af_wide : bits(5) = (0b0 @ a[3..0]) + (0b0 @ b[3..0]) + zero_extend(carry_in);
  AF = af_wide[4];
  update_SF_ZF_PF(result)
}

// Compute CF and OF for subtraction with borrow: dest = a - b - borrow_in.
val update_flags_sbb : forall 'n, 'n >= 8. (bits('n), bits('n), bits('n), bit) -> unit
function update_flags_sbb(result, a, b, borrow_in) = {
  // CF: borrow bit from wide subtraction with borrow_in
  let cf_wide : bits('n + 1) = (0b0 @ a) - (0b0 @ b) - zero_extend(borrow_in);
  CF = cf_wide['n];
  // OF: signed overflow from wide signed subtraction
  let of_wide : bits('n + 1) = sign_extend(a) - sign_extend(b) - zero_extend(borrow_in);
  OF = (of_wide['n .. 'n] ^ of_wide['n - 1 .. 'n - 1])[0];
  // AF: nibble borrow with borrow_in
  let af_wide : bits(5) = (0b0 @ a[3..0]) - (0b0 @ b[3..0]) - zero_extend(borrow_in);
  AF = af_wide[4];
  update_SF_ZF_PF(result)
}

// Evaluate an x86 condition code (4-bit, from Jcc/CMOVcc/SETcc opcodes).
// The condition codes correspond to the low 4 bits of the opcode:
//   0=O  1=NO  2=B   3=AE  4=E   5=NE  6=BE  7=A
//   8=S  9=NS  A=P   B=NP  C=L   D=GE  E=LE  F=G
type cc_idx = range(0, 15)

val eval_cc : cc_idx -> bool
function eval_cc(cc) = {
  let sf_ne_of : bits(1) = SF ^ OF;
  let results : bits(16) =
    (~(ZF) & ~(sf_ne_of)) @  // F: G/NLE
    (ZF | sf_ne_of) @        // E: LE/NG
    (~(sf_ne_of)) @          // D: GE/NL
    sf_ne_of @               // C: L/NGE
    (~(PF)) @                // B: NP/PO
    PF @                     // A: P/PE
    (~(SF)) @                // 9: NS
    SF @                     // 8: S
    (~(CF) & ~(ZF)) @       // 7: A/NBE
    (CF | ZF) @              // 6: BE/NA
    (~(ZF)) @                // 5: NE/NZ
    ZF @                     // 4: E/Z
    (~(CF)) @                // 3: AE/NB/NC
    CF @                     // 2: B/C/NAE
    (~(OF)) @                // 1: NO
    OF;                      // 0: O
  results[cc] == bitone
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
