// x86-64 — ALU Helpers
//
// These helpers perform ALU operations on resolved values, handling
// flag updates and result write-back. They support both register and
// memory operands via the RM union.

// Perform an ALU operation on two operand-sized values.
// Returns (result, should_write_back). CMP doesn't write back.
val alu_compute : forall 'os, 'os in {8, 16, 32, 64}. (ALUOp, bits('os), bits('os), int('os)) -> (bits('os), bool)
function alu_compute(op, a, b, os) = {
  match op {
    ALU_ADD => {
      let result = a + b;
      update_flags_add(result, a, b);
      (result, true)
    },
    ALU_OR => {
      let result = a | b;
      update_flags_logic(result);
      (result, true)
    },
    ALU_ADC => {
      let result = a + b + zero_extend(CF);
      update_flags_adc(result, a, b, CF);
      (result, true)
    },
    ALU_SBB => {
      let result = a - b - zero_extend(CF);
      update_flags_sbb(result, a, b, CF);
      (result, true)
    },
    ALU_AND => {
      let result = a & b;
      update_flags_logic(result);
      (result, true)
    },
    ALU_SUB => {
      let result = a - b;
      update_flags_sub(result, a, b);
      (result, true)
    },
    ALU_XOR => {
      let result = a ^ b;
      update_flags_logic(result);
      (result, true)
    },
    ALU_CMP => {
      let result = a - b;
      update_flags_sub(result, a, b);
      (result, false)  // CMP: don't write back
    },
  }
}

// Execute ALU: dst_rm OP= src_reg
val exec_alu_rm_reg : (ALUOp, RM, GPRRef, {8, 16, 32, 64}) -> unit
function exec_alu_rm_reg(op, dest, reg, os) = {
  let a = v(os, dest);
  let b = v(os, reg);
  let (result, wb) = alu_compute(op, a, b, os);
  if wb then v(os, dest) = result
}

// Execute ALU: dst_reg OP= src_rm
val exec_alu_reg_rm : (ALUOp, GPRRef, RM, {8, 16, 32, 64}) -> unit
function exec_alu_reg_rm(op, reg, src, os) = {
  let a = v(os, reg);
  let b = v(os, src);
  let (result, wb) = alu_compute(op, a, b, os);
  if wb then v(reg) = result
}

// Execute ALU: AL/AX/EAX/RAX OP= imm (accumulator short forms)
val exec_alu_acc_imm : forall 'os, 'os in {8, 16, 32, 64}. (ALUOp, bits('os), int('os), Prefixes) -> unit
function exec_alu_acc_imm(op, imm, os, _) = {
  let a = v(os, RAX);
  let (result, wb) = alu_compute(op, a, imm, os);
  if wb then v(RAX) = result
}

// Execute ALU: dest OP= imm (Group 1: opcodes 80, 81, 83)
val exec_alu_rm_imm : forall 'os, 'os in {8, 16, 32, 64}. (ALUOp, RM, bits('os), int('os)) -> unit
function exec_alu_rm_imm(op, dest, imm, os) = {
  let a = v(os, dest);
  let (result, wb) = alu_compute(op, a, imm, os);
  if wb then v(os, dest) = result
}

// Map Group 1 reg field (0-7) to ALUOp.
val group1_op : range(0, 7) -> ALUOp
function group1_op(reg) = match reg {
  0 => ALU_ADD,
  1 => ALU_OR,
  2 => ALU_ADC,
  3 => ALU_SBB,
  4 => ALU_AND,
  5 => ALU_SUB,
  6 => ALU_XOR,
  7 => ALU_CMP,
}
