// x86-64 Decoder — Generic ALU Execution Helpers
//
// These helpers perform ALU operations on resolved values, handling
// flag updates and result write-back. They support both register and
// memory operands via the RM union.

// Perform an ALU operation on two qword values at the given operand size.
// Returns (result, should_write_back). CMP doesn't write back.
val alu_compute : (ALUOp, qword, qword, OperandSize) -> (qword, bool)
function alu_compute(op, a, b, os) = {
  match op {
    ALU_ADD => {
      let result : qword = a + b;
      match os {
        OS8  => update_flags_add(result[7..0], a[7..0], b[7..0]),
        OS16 => update_flags_add(result[15..0], a[15..0], b[15..0]),
        OS32 => update_flags_add(result[31..0], a[31..0], b[31..0]),
        OS64 => update_flags_add(result, a, b),
      };
      (result, true)
    },
    ALU_OR => {
      let result : qword = a | b;
      match os {
        OS8  => update_flags_logic(result[7..0]),
        OS16 => update_flags_logic(result[15..0]),
        OS32 => update_flags_logic(result[31..0]),
        OS64 => update_flags_logic(result),
      };
      (result, true)
    },
    ALU_ADC => {
      let carry_in = CF;
      let c : qword = zero_extend(carry_in);
      let result : qword = a + b + c;
      match os {
        OS8  => update_flags_adc(result[7..0], a[7..0], b[7..0], carry_in),
        OS16 => update_flags_adc(result[15..0], a[15..0], b[15..0], carry_in),
        OS32 => update_flags_adc(result[31..0], a[31..0], b[31..0], carry_in),
        OS64 => update_flags_adc(result, a, b, carry_in),
      };
      (result, true)
    },
    ALU_SBB => {
      let borrow_in = CF;
      let bw : qword = zero_extend(borrow_in);
      let result : qword = a - b - bw;
      match os {
        OS8  => update_flags_sbb(result[7..0], a[7..0], b[7..0], borrow_in),
        OS16 => update_flags_sbb(result[15..0], a[15..0], b[15..0], borrow_in),
        OS32 => update_flags_sbb(result[31..0], a[31..0], b[31..0], borrow_in),
        OS64 => update_flags_sbb(result, a, b, borrow_in),
      };
      (result, true)
    },
    ALU_AND => {
      let result : qword = a & b;
      match os {
        OS8  => update_flags_logic(result[7..0]),
        OS16 => update_flags_logic(result[15..0]),
        OS32 => update_flags_logic(result[31..0]),
        OS64 => update_flags_logic(result),
      };
      (result, true)
    },
    ALU_SUB => {
      let result : qword = a - b;
      match os {
        OS8  => update_flags_sub(result[7..0], a[7..0], b[7..0]),
        OS16 => update_flags_sub(result[15..0], a[15..0], b[15..0]),
        OS32 => update_flags_sub(result[31..0], a[31..0], b[31..0]),
        OS64 => update_flags_sub(result, a, b),
      };
      (result, true)
    },
    ALU_XOR => {
      let result : qword = a ^ b;
      match os {
        OS8  => update_flags_logic(result[7..0]),
        OS16 => update_flags_logic(result[15..0]),
        OS32 => update_flags_logic(result[31..0]),
        OS64 => update_flags_logic(result),
      };
      (result, true)
    },
    ALU_CMP => {
      let result : qword = a - b;
      match os {
        OS8  => update_flags_sub(result[7..0], a[7..0], b[7..0]),
        OS16 => update_flags_sub(result[15..0], a[15..0], b[15..0]),
        OS32 => update_flags_sub(result[31..0], a[31..0], b[31..0]),
        OS64 => update_flags_sub(result, a, b),
      };
      (result, false)  // CMP: don't write back
    },
  }
}

// Execute ALU: dst_rm OP= src_reg (byte operand)
val exec_alu_rm_reg_byte : (ALUOp, RM, gpr_idx, Prefixes) -> ExecutionResult
function exec_alu_rm_reg_byte(op, rm, reg, pfx) = {
  let a = read_rm_val(rm, OS8, pfx.has_rex);
  let b : qword = zero_extend(read_byte_reg(reg, pfx.has_rex));
  let (result, wb) = alu_compute(op, a, b, OS8);
  if wb then write_rm_val(rm, OS8, pfx.has_rex, result);
  Ok()
}

// Execute ALU: dst_rm OP= src_reg (word/dword/qword)
val exec_alu_rm_reg : (ALUOp, RM, gpr_idx, OperandSize, Prefixes) -> ExecutionResult
function exec_alu_rm_reg(op, rm, reg, os, pfx) = {
  let a = read_rm_val(rm, os, pfx.has_rex);
  let b = read_gpr(reg, os);
  let (result, wb) = alu_compute(op, a, b, os);
  if wb then write_rm_val(rm, os, pfx.has_rex, result);
  Ok()
}

// Execute ALU: dst_reg OP= src_rm (byte operand)
val exec_alu_reg_rm_byte : (ALUOp, gpr_idx, RM, Prefixes) -> ExecutionResult
function exec_alu_reg_rm_byte(op, reg, rm, pfx) = {
  let a : qword = zero_extend(read_byte_reg(reg, pfx.has_rex));
  let b = read_rm_val(rm, OS8, pfx.has_rex);
  let (result, wb) = alu_compute(op, a, b, OS8);
  if wb then write_byte_reg(reg, pfx.has_rex, result[7..0]);
  Ok()
}

// Execute ALU: dst_reg OP= src_rm (word/dword/qword)
val exec_alu_reg_rm : (ALUOp, gpr_idx, RM, OperandSize, Prefixes) -> ExecutionResult
function exec_alu_reg_rm(op, reg, rm, os, pfx) = {
  let a = read_gpr(reg, os);
  let b = read_rm_val(rm, os, pfx.has_rex);
  let (result, wb) = alu_compute(op, a, b, os);
  if wb then write_gpr(reg, os, result);
  Ok()
}

// Execute ALU: AL/AX/EAX/RAX OP= imm (accumulator short forms)
val exec_alu_acc_imm : (ALUOp, qword, OperandSize, Prefixes) -> ExecutionResult
function exec_alu_acc_imm(op, imm, os, _) = {
  let a = read_gpr(RAX, os);
  let (result, wb) = alu_compute(op, a, imm, os);
  if wb then write_gpr(RAX, os, result);
  Ok()
}

// Execute ALU: rm OP= imm (Group 1: opcodes 80, 81, 83)
val exec_alu_rm_imm : (ALUOp, RM, qword, OperandSize, Prefixes) -> ExecutionResult
function exec_alu_rm_imm(op, rm, imm, os, pfx) = {
  let a = read_rm_val(rm, os, pfx.has_rex);
  let (result, wb) = alu_compute(op, a, imm, os);
  if wb then write_rm_val(rm, os, pfx.has_rex, result);
  Ok()
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
