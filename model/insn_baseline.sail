// x86-64 Decoder — 2-Byte Opcode Map: Baseline Operations
//
// CMOVcc, Jcc, SETcc, BT/BTS/BTR/BTC, SHLD/SHRD, IMUL, MOVZX/MOVSX,
// BSF/BSR, POPCNT, CMPXCHG, XADD, BSWAP, CPUID, RDTSC, and more.

val bsf64 : (qword, range(0, 63)) -> range(0, 63)
function bsf64(v, idx) =
  if idx >= 63 then 63
  else if bit_to_bool(v[idx]) then idx
  else bsf64(v, idx + 1)

val bsr64 : (qword, range(0, 63)) -> range(0, 63)
function bsr64(v, idx) =
  if idx <= 0 then 0
  else if bit_to_bool(v[idx]) then idx
  else bsr64(v, idx - 1)

// XADD — Exchange and Add

val exec_xadd : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_xadd(dst, src, os) = {
  let a : qword = read_gpr(dst, os);
  let b : qword = read_gpr(src, os);
  let sum : qword = a + b;
  match os {
    OS8  => update_flags_add(sum[7..0], a[7..0], b[7..0]),
    OS16 => update_flags_add(sum[15..0], a[15..0], b[15..0]),
    OS32 => update_flags_add(sum[31..0], a[31..0], b[31..0]),
    OS64 => update_flags_add(sum, a, b),
  };
  write_gpr(src, os, a);
  write_gpr(dst, os, sum);
  Ok()
}

// POPCNT helpers

val popcount8 : byte -> range(0, 8)
function popcount8(v) = {
  let b0 : range(0, 1) = if bit_to_bool(v[0]) then 1 else 0;
  let b1 : range(0, 1) = if bit_to_bool(v[1]) then 1 else 0;
  let b2 : range(0, 1) = if bit_to_bool(v[2]) then 1 else 0;
  let b3 : range(0, 1) = if bit_to_bool(v[3]) then 1 else 0;
  let b4 : range(0, 1) = if bit_to_bool(v[4]) then 1 else 0;
  let b5 : range(0, 1) = if bit_to_bool(v[5]) then 1 else 0;
  let b6 : range(0, 1) = if bit_to_bool(v[6]) then 1 else 0;
  let b7 : range(0, 1) = if bit_to_bool(v[7]) then 1 else 0;
  b0 + b1 + b2 + b3 + b4 + b5 + b6 + b7
}

val popcount16 : word -> range(0, 16)
function popcount16(v) =
  popcount8(v[7..0]) + popcount8(v[15..8])

val popcount32 : dword -> range(0, 32)
function popcount32(v) =
  popcount16(v[15..0]) + popcount16(v[31..16])

// LZCNT helper

val lzcnt64 : (qword, range(0, 63)) -> range(0, 64)
function lzcnt64(v, idx) =
  if idx == 0 then (if bit_to_bool(v[idx]) then 0 else 64)
  else if bit_to_bool(v[idx]) then 63 - idx
  else lzcnt64(v, idx - 1)

val __cpuid : (dword, dword) -> (dword, dword, dword, dword)
val __rdtsc : unit -> qword

val __syscall : (qword, qword) -> ExecutionResult
val __fxsave : qword -> ExecutionResult
val __fxsave64 : qword -> ExecutionResult
val __fxrstor : qword -> ExecutionResult
val __fxrstor64 : qword -> ExecutionResult

// SHLD — Double Precision Shift Left
//
// Shifts dst left by count, filling vacated bits from src (high bits).
// Equivalent to: result = upper_half(dst:src << count)
// If count=0, no operation. If count > operand_size, undefined.
// CF = last bit shifted out. SF, ZF, PF set from result.
// OF defined for count=1 (sign change). AF undefined.

val exec_shld : (qword, qword, byte, OperandSize) -> (ExecutionResult, qword)
function exec_shld(d, s, count_raw, os) = {
  let count : range(0, 63) = match os {
    OS64 => unsigned(count_raw) % 64,
    _    => unsigned(count_raw) % 32,
  };
  if count == 0 then (Ok(), d)
  else {
    let result : qword = match os {
      OS16 => {
        if count > 16 then {
          // SDM: result and flags undefined when count > operand size
          CF = undefined; OF = undefined;
          SF = undefined; ZF = undefined; PF = undefined; AF = undefined;
          undefined
        } else {
          let wide : dword = d[15..0] @ s[15..0];
          let shifted : dword = wide << count;
          let r : word = shifted[31..16];
          CF = wide[32 - count];
          update_SF_ZF_PF(r);
          if count == 1 then
            OF = bool_to_bit(r[15] != d[15])
          else OF = undefined;
          zero_extend(r)
        }
      },
      OS32 => {
        let wide : qword = d[31..0] @ s[31..0];
        let shifted : qword = wide << count;
        let r : dword = shifted[63..32];
        CF = wide[64 - count];
        update_SF_ZF_PF(r);
        if count == 1 then
          OF = bool_to_bit(r[31] != d[31])
        else OF = undefined;
        zero_extend(r)
      },
      OS64 => {
        let wide : xmmword = d @ s;
        let shifted : xmmword = wide << count;
        let r : qword = shifted[127..64];
        CF = wide[128 - count];
        update_SF_ZF_PF(r);
        if count == 1 then
          OF = bool_to_bit(r[63] != d[63])
        else OF = undefined;
        r
      },
      _ => d,
    };
    AF = undefined;
    (Ok(), result)
  }
}

// SHRD — Double Precision Shift Right
//
// Shifts dst right by count, filling vacated bits from src (low bits).
// Equivalent to: result = lower_half(src:dst >> count)
// If count=0, no operation. If count > operand_size, undefined.
// CF = last bit shifted out. SF, ZF, PF set from result.
// OF defined for count=1 (sign change). AF undefined.

val exec_shrd : (qword, qword, byte, OperandSize) -> (ExecutionResult, qword)
function exec_shrd(d, s, count_raw, os) = {
  let count : range(0, 63) = match os {
    OS64 => unsigned(count_raw) % 64,
    _    => unsigned(count_raw) % 32,
  };
  if count == 0 then (Ok(), d)
  else {
    let result : qword = match os {
      OS16 => {
        if count > 16 then {
          // SDM: result and flags undefined when count > operand size
          CF = undefined; OF = undefined;
          SF = undefined; ZF = undefined; PF = undefined; AF = undefined;
          undefined
        } else {
          let wide : dword = s[15..0] @ d[15..0];
          let shifted : dword = wide >> count;
          let r : word = shifted[15..0];
          CF = d[count - 1];
          update_SF_ZF_PF(r);
          if count == 1 then
            OF = bool_to_bit(r[15] != d[15])
          else OF = undefined;
          zero_extend(r)
        }
      },
      OS32 => {
        let wide : qword = s[31..0] @ d[31..0];
        let shifted : qword = wide >> count;
        let r : dword = shifted[31..0];
        CF = d[count - 1];
        update_SF_ZF_PF(r);
        if count == 1 then
          OF = bool_to_bit(r[31] != d[31])
        else OF = undefined;
        zero_extend(r)
      },
      OS64 => {
        let wide : xmmword = s @ d;
        let shifted : xmmword = wide >> count;
        let r : qword = shifted[63..0];
        CF = d[count - 1];
        update_SF_ZF_PF(r);
        if count == 1 then
          OF = bool_to_bit(r[63] != d[63])
        else OF = undefined;
        r
      },
      _ => d,
    };
    AF = undefined;
    (Ok(), result)
  }
}

val dispatch_2byte_gpr : (range(0, 255), Prefixes) -> ExecutionResult
function dispatch_2byte_gpr(op, pfx) = {
  match op {
    // 0F 05: SYSCALL
    5 => __syscall(RIP, read_rflags()),
    // 0F 1F: Multi-byte NOP r/m (prefetch hint)
    31 => {
      let modrm = fetch_byte();
      let _ = decode_rm(modrm, pfx);  // consume ModR/M + SIB + disp
      Ok()
    },
    // 0F 01: Group 7 (privileged/system instructions)
    1 => {
      let modrm = fetch_byte();
      let modrm_val : range(0, 255) = unsigned(modrm);
      match modrm_val {
        // 0F 01 D0: XGETBV
        208 => {
          let ecx_val : dword = read_gpr32(RCX);
          if ecx_val == 0x00000000 then {
            // bit 0=x87, 1=SSE, 2=AVX, 5=opmask, 6=ZMM_Hi256, 7=Hi16_ZMM
            write_gpr32(RAX, 0x000000E7);
            write_gpr32(RDX, 0x00000000);
            Ok()
          } else {
            raise_GP0()
          }
        },
        _ => raise_UD(),
      }
    },
    // 0F 0B: UD2
    11 => {
      raise_UD()
    },
    // 0F 18-1E: Prefetch hints / multi-byte NOPs
    // These all consume ModR/M and do nothing.
    op if 24 <= op & op <= 30 => {
      let modrm = fetch_byte();
      let _ = decode_rm(modrm, pfx);
      Ok()
    },
    // 0F 31: RDTSC
    49 => {
      let tsc : qword = __rdtsc();
      write_gpr32(RAX, tsc[31..0]);
      write_gpr32(RDX, tsc[63..32]);
      Ok()
    },
    // 0F 40-4F: CMOVcc r, r/m
    op if 64 <= op & op <= 79 => {
      let cc : cc_idx = op - 64;
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if eval_cc(cc) then {
        let v = read_rm_val(rm, os, pfx.has_rex);
        write_gpr(reg, os, v);
      };
      Ok()
    },
    // 0F 80-8F: Jcc rel32 (f64)
    op if 128 <= op & op <= 143 => {
      let cc : cc_idx = op - 128;
      let offset = fetch_rel32();
      if eval_cc(cc) then {
        RIP = decode_pos + offset;
        decode_pos = RIP;
      };
      Ok()
    },
    // 0F 90-9F: SETcc r/m8
    op if 144 <= op & op <= 159 => {
      let cc : cc_idx = op - 144;
      let modrm = fetch_byte();
      let rm = decode_rm(modrm, pfx);
      let v : qword = if eval_cc(cc) then 0x0000000000000001 else zeros();
      write_rm_val(rm, OS8, pfx.has_rex, v);
      Ok()
    },
    // 0F AE: Group 15 — LDMXCSR/STMXCSR/LFENCE/MFENCE/SFENCE
    174 => {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm(modrm, pfx);
      if reg_field == 0 then {
        // /0: FXSAVE m512byte
        match rm {
          RM_mem(addr) => {
            if pfx.rex_w then __fxsave64(fixup_addr(addr))
            else __fxsave(fixup_addr(addr))
          },
          RM_reg(_) => raise_UD(),
        }
      } else if reg_field == 1 then {
        // /1: FXRSTOR m512byte
        match rm {
          RM_mem(addr) => {
            if pfx.rex_w then __fxrstor64(fixup_addr(addr))
            else __fxrstor(fixup_addr(addr))
          },
          RM_reg(_) => raise_UD(),
        }
      } else if reg_field == 2 then {
        // /2: LDMXCSR m32
        match rm {
          RM_mem(addr) => {
            __ldmxcsr(mem_read32(addr));
            Ok()
          },
          RM_reg(_) => raise_UD(),
        }
      } else if reg_field == 3 then {
        // /3: STMXCSR m32
        match rm {
          RM_mem(addr) => {
            mem_write32(addr, __stmxcsr());
            Ok()
          },
          RM_reg(_) => raise_UD(),
        }
      } else if reg_field == 5 then {
        // /5 mod=11: LFENCE
        Ok()
      } else if reg_field == 6 then {
        // /6 mod=11: MFENCE
        Ok()
      } else if reg_field == 7 then {
        // /7 mod=11: SFENCE
        Ok()
      } else {
        raise_UD()
      }
    },
    // 0F A2: CPUID
    162 => {
      let leaf : dword = read_gpr32(RAX);
      let subleaf : dword = read_gpr32(RCX);
      let (out_eax, out_ebx, out_ecx, out_edx) = __cpuid(leaf, subleaf);
      write_gpr32(RAX, out_eax);
      write_gpr32(RBX, out_ebx);
      write_gpr32(RCX, out_ecx);
      write_gpr32(RDX, out_edx);
      Ok()
    },
    // 0F A3: BT r/m, r
    163 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = read_rm_val(rm, os, pfx.has_rex);
      let bit_idx = read_gpr(reg, os);
      let bit_num : range(0, 63) = match os {
        OS16 => unsigned(bit_idx[3..0]),
        OS32 => unsigned(bit_idx[4..0]),
        OS64 => unsigned(bit_idx[5..0]),
        _    => unsigned(bit_idx[4..0]),
      };
      CF = v[bit_num];
      Ok()
    },
    // 0F A4: SHLD r/m, r, imm8
    164 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let count = fetch_byte();
      let dst_val = read_rm_val(rm, os, pfx.has_rex);
      let src_val = read_gpr(reg, os);
      let (result, new_val) = exec_shld(dst_val, src_val, count, os);
      write_rm_val(rm, os, pfx.has_rex, new_val);
      result
    },
    // 0F A5: SHLD r/m, r, CL
    165 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let count = read_gpr8l(RCX);
      let dst_val = read_rm_val(rm, os, pfx.has_rex);
      let src_val = read_gpr(reg, os);
      let (result, new_val) = exec_shld(dst_val, src_val, count, os);
      write_rm_val(rm, os, pfx.has_rex, new_val);
      result
    },
    // 0F AB: BTS r/m, r
    171 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = read_rm_val(rm, os, pfx.has_rex);
      let bit_idx = read_gpr(reg, os);
      let bit_num : range(0, 63) = match os {
        OS16 => unsigned(bit_idx[3..0]),
        OS32 => unsigned(bit_idx[4..0]),
        OS64 => unsigned(bit_idx[5..0]),
        _    => unsigned(bit_idx[4..0]),
      };
      CF = v[bit_num];
      var result : qword = v;
      result[bit_num] = bitone;
      write_rm_val(rm, os, pfx.has_rex, result);
      Ok()
    },
    // 0F AC: SHRD r/m, r, imm8
    172 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let count = fetch_byte();
      let dst_val = read_rm_val(rm, os, pfx.has_rex);
      let src_val = read_gpr(reg, os);
      let (result, new_val) = exec_shrd(dst_val, src_val, count, os);
      write_rm_val(rm, os, pfx.has_rex, new_val);
      result
    },
    // 0F AD: SHRD r/m, r, CL
    173 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let count = read_gpr8l(RCX);
      let dst_val = read_rm_val(rm, os, pfx.has_rex);
      let src_val = read_gpr(reg, os);
      let (result, new_val) = exec_shrd(dst_val, src_val, count, os);
      write_rm_val(rm, os, pfx.has_rex, new_val);
      result
    },
    // 0F AF: IMUL r, r/m (2-operand)
    175 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let a = read_gpr(reg, os);
      let b = read_rm_val(rm, os, pfx.has_rex);
      let product : int = match os {
        OS8  => signed(a[7..0]) * signed(b[7..0]),
        OS16 => signed(a[15..0]) * signed(b[15..0]),
        OS32 => signed(a[31..0]) * signed(b[31..0]),
        OS64 => signed(a) * signed(b),
      };
      let result : qword = to_bits_truncate(product);
      let truncated : bool = match os {
        OS8  => product != signed(result[7..0]),
        OS16 => product != signed(result[15..0]),
        OS32 => product != signed(result[31..0]),
        OS64 => product != signed(result),
      };
      CF = bool_to_bit(truncated);
      OF = CF;
      write_gpr(reg, os, result);
      Ok()
    },
    // 0F B3: BTR r/m, r
    179 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = read_rm_val(rm, os, pfx.has_rex);
      let bit_idx = read_gpr(reg, os);
      let bit_num : range(0, 63) = match os {
        OS16 => unsigned(bit_idx[3..0]),
        OS32 => unsigned(bit_idx[4..0]),
        OS64 => unsigned(bit_idx[5..0]),
        _    => unsigned(bit_idx[4..0]),
      };
      CF = v[bit_num];
      var result : qword = v;
      result[bit_num] = bitzero;
      write_rm_val(rm, os, pfx.has_rex, result);
      Ok()
    },
    // 0F B0: CMPXCHG r/m8, r8
    176 => {
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let dest = read_rm_val(rm, OS8, pfx.has_rex);
      let acc : qword = zero_extend(read_gpr8l(RAX));
      let src : qword = zero_extend(read_byte_reg(reg, pfx.has_rex));
      let cmp_result = acc - dest;
      update_flags_sub(cmp_result[7..0], acc[7..0], dest[7..0]);
      if ZF == bitone then {
        write_rm_val(rm, OS8, pfx.has_rex, src);
      } else {
        write_gpr8l(RAX, dest[7..0]);
      };
      Ok()
    },
    // 0F B1: CMPXCHG r/m, r
    177 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let dest = read_rm_val(rm, os, pfx.has_rex);
      let acc = read_gpr(RAX, os);
      let src = read_gpr(reg, os);
      let cmp_result = acc - dest;
      match os {
        OS8  => update_flags_sub(cmp_result[7..0], acc[7..0], dest[7..0]),
        OS16 => update_flags_sub(cmp_result[15..0], acc[15..0], dest[15..0]),
        OS32 => update_flags_sub(cmp_result[31..0], acc[31..0], dest[31..0]),
        OS64 => update_flags_sub(cmp_result, acc, dest),
      };
      if ZF == bitone then {
        write_rm_val(rm, os, pfx.has_rex, src);
      } else {
        write_gpr(RAX, os, dest);
      };
      Ok()
    },
    // 0F B6: MOVZX r, r/m8
    182 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = read_rm_val(rm, OS8, pfx.has_rex);
      write_gpr(reg, os, v);  // already zero-extended in read_rm_val
      Ok()
    },
    // 0F B7: MOVZX r, r/m16
    183 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = read_rm_val(rm, OS16, pfx.has_rex);
      write_gpr(reg, os, v);
      Ok()
    },
    // 0F BA: Group 8 — BT/BTS/BTR/BTC r/m, imm8
    186 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm(modrm, pfx);
      let imm = fetch_byte();
      let v = read_rm_val(rm, os, pfx.has_rex);
      let bit_num : range(0, 63) = match os {
        OS16 => unsigned(imm[3..0]),
        OS32 => unsigned(imm[4..0]),
        OS64 => unsigned(imm[5..0]),
        _    => unsigned(imm[4..0]),
      };
      CF = v[bit_num];
      if reg_field == 4 then {
        // BT — just test, no modification
        Ok()
      } else if reg_field == 5 then {
        // BTS — set bit
        var result : qword = v;
        result[bit_num] = bitone;
        write_rm_val(rm, os, pfx.has_rex, result);
        Ok()
      } else if reg_field == 6 then {
        // BTR — reset bit
        var result : qword = v;
        result[bit_num] = bitzero;
        write_rm_val(rm, os, pfx.has_rex, result);
        Ok()
      } else if reg_field == 7 then {
        // BTC — complement bit
        var result : qword = v;
        result[bit_num] = ~(v[bit_num]);
        write_rm_val(rm, os, pfx.has_rex, result);
        Ok()
      } else {
        raise_UD()
      }
    },
    // 0F BB: BTC r/m, r
    187 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = read_rm_val(rm, os, pfx.has_rex);
      let bit_idx = read_gpr(reg, os);
      let bit_num : range(0, 63) = match os {
        OS16 => unsigned(bit_idx[3..0]),
        OS32 => unsigned(bit_idx[4..0]),
        OS64 => unsigned(bit_idx[5..0]),
        _    => unsigned(bit_idx[4..0]),
      };
      CF = v[bit_num];
      var result : qword = v;
      result[bit_num] = ~(v[bit_num]);
      write_rm_val(rm, os, pfx.has_rex, result);
      Ok()
    },
    // 0F BC: BSF r, r/m (or TZCNT with F3 prefix)
    188 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.has_rep then {
        // TZCNT
        let src = modrm_rm_reg(modrm, pfx);
        let src_val : qword = read_gpr(src, os);
        let os_bits : {8, 16, 32, 64} = operand_size_bits(os);
        let is_zero : bool = match os {
          OS8  => src_val[7..0] == zeros(),
          OS16 => src_val[15..0] == zeros(),
          OS32 => src_val[31..0] == zeros(),
          OS64 => src_val == zeros(),
        };
        let count : int = if is_zero then os_bits
                          else bsf64(src_val, 0);
        write_gpr(reg, os, to_bits_truncate(count));
        CF = bool_to_bit(is_zero);
        ZF = bool_to_bit(count == 0);
        Ok()
      } else {
        // BSF
        let src_val = read_rm_val(rm, os, pfx.has_rex);
        let is_zero : bool = match os {
          OS8  => src_val[7..0] == zeros(),
          OS16 => src_val[15..0] == zeros(),
          OS32 => src_val[31..0] == zeros(),
          OS64 => src_val == zeros(),
        };
        if is_zero then {
          ZF = bitone;
        } else {
          ZF = bitzero;
          let idx : range(0, 63) = bsf64(src_val, 0);
          write_gpr(reg, os, to_bits_truncate(idx));
        };
        Ok()
      }
    },
    // 0F BD: BSR r, r/m (or LZCNT with F3 prefix)
    189 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.has_rep then {
        // LZCNT
        let src = modrm_rm_reg(modrm, pfx);
        let src_val : qword = read_gpr(src, os);
        let os_bits : {8, 16, 32, 64} = operand_size_bits(os);
        let count : range(0, 64) = match os {
          OS8  => lzcnt64(zero_extend(src_val[7..0]), 7),
          OS16 => lzcnt64(zero_extend(src_val[15..0]), 15),
          OS32 => lzcnt64(zero_extend(src_val[31..0]), 31),
          OS64 => lzcnt64(src_val, 63),
        };
        write_gpr(reg, os, to_bits_truncate(count));
        CF = bool_to_bit(count == os_bits);
        ZF = bool_to_bit(count == 0);
        Ok()
      } else {
        // BSR
        let src_val = read_rm_val(rm, os, pfx.has_rex);
        let is_zero : bool = match os {
          OS8  => src_val[7..0] == zeros(),
          OS16 => src_val[15..0] == zeros(),
          OS32 => src_val[31..0] == zeros(),
          OS64 => src_val == zeros(),
        };
        if is_zero then {
          ZF = bitone;
        } else {
          ZF = bitzero;
          let top : range(0, 63) = match os {
            OS8  => 7,
            OS16 => 15,
            OS32 => 31,
            OS64 => 63,
          };
          let idx : range(0, 63) = bsr64(src_val, top);
          write_gpr(reg, os, to_bits_truncate(idx));
        };
        Ok()
      }
    },
    // 0F BE: MOVSX r, r/m8
    190 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = read_rm_val(rm, OS8, pfx.has_rex);
      let sx : qword = sign_extend(v[7..0]);
      write_gpr(reg, os, sx);
      Ok()
    },
    // 0F BF: MOVSX r, r/m16
    191 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = read_rm_val(rm, OS16, pfx.has_rex);
      let sx : qword = sign_extend(v[15..0]);
      write_gpr(reg, os, sx);
      Ok()
    },
    // 0F C0: XADD r/m8, r8
    192 => {
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_reg(dst) => exec_xadd(dst, reg, OS8),
        RM_mem(addr) => {
          // Memory operand: read, exchange, add, write back
          let mem_val : qword = zero_extend(mem_read8(addr));
          let reg_val : qword = zero_extend(read_byte_reg(reg, pfx.has_rex));
          let sum : qword = mem_val + reg_val;
          update_flags_add(sum[7..0], mem_val[7..0], reg_val[7..0]);
          write_byte_reg(reg, pfx.has_rex, mem_val[7..0]);
          mem_write8(addr, sum[7..0]);
          Ok()
        },
      }
    },
    // 0F C1: XADD r/m, r
    193 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_reg(dst) => exec_xadd(dst, reg, os),
        RM_mem(_) => {
          let mem_val = read_rm_val(rm, os, pfx.has_rex);
          let reg_val = read_gpr(reg, os);
          let sum = mem_val + reg_val;
          match os {
            OS8  => update_flags_add(sum[7..0], mem_val[7..0], reg_val[7..0]),
            OS16 => update_flags_add(sum[15..0], mem_val[15..0], reg_val[15..0]),
            OS32 => update_flags_add(sum[31..0], mem_val[31..0], reg_val[31..0]),
            OS64 => update_flags_add(sum, mem_val, reg_val),
          };
          write_gpr(reg, os, mem_val);
          write_rm_val(rm, os, pfx.has_rex, sum);
          Ok()
        },
      }
    },
    // 0F B8: POPCNT r, r/m (F3 prefix)
    184 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_F3 then {
        raise_UD()
      } else {
        let os = get_operand_size(pfx);
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_val = read_rm_val(rm, os, pfx.has_rex);
        let count : range(0, 64) = match os {
          OS8  => popcount8(src_val[7..0]),
          OS16 => popcount16(src_val[15..0]),
          OS32 => popcount32(src_val[31..0]),
          OS64 => popcount32(src_val[31..0]) + popcount32(src_val[63..32]),
        };
        OF = bitzero; SF = bitzero; AF = bitzero; CF = bitzero; PF = bitzero;
        ZF = bool_to_bit(count == 0);
        write_gpr(reg, os, to_bits_truncate(count));
        Ok()
      }
    },
    // 0F C3: MOVNTI m32/64, r
    195 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_mem(addr) => {
          let v = read_gpr(reg, os);
          match os {
            OS32 => mem_write32(addr, v[31..0]),
            OS64 => mem_write64(addr, v),
            _    => mem_write32(addr, v[31..0]),
          };
          Ok()
        },
        RM_reg(_) => raise_UD(),
      }
    },
    // 0F C7 /1: CMPXCHG8B/CMPXCHG16B m64/m128
    199 => {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm(modrm, pfx);
      if reg_field == 1 then {
        match rm {
          RM_mem(addr) => {
            if pfx.rex_w then {
              let mem_lo : qword = mem_read64(addr);
              let mem_hi : qword = mem_read64(addr + 0x0000000000000008);
              if read_gpr64(RAX) == mem_lo & read_gpr64(RDX) == mem_hi then {
                ZF = bitone;
                mem_write64(addr, read_gpr64(RBX));
                mem_write64(addr + 0x0000000000000008, read_gpr64(RCX));
              } else {
                ZF = bitzero;
                write_gpr64(RAX, mem_lo);
                write_gpr64(RDX, mem_hi);
              };
              Ok()
            } else {
              let mem_lo : dword = mem_read32(addr);
              let mem_hi : dword = mem_read32(addr + 0x0000000000000004);
              if read_gpr32(RAX) == mem_lo & read_gpr32(RDX) == mem_hi then {
                ZF = bitone;
                mem_write32(addr, read_gpr32(RBX));
                mem_write32(addr + 0x0000000000000004, read_gpr32(RCX));
              } else {
                ZF = bitzero;
                write_gpr32(RAX, mem_lo);
                write_gpr32(RDX, mem_hi);
              };
              Ok()
            }
          },
          RM_reg(_) => raise_UD(),
        }
      } else {
        raise_UD()
      }
    },
    // 0F C8-CF: BSWAP r32/r64 (register in opcode)
    op if 200 <= op & op <= 207 => {
      let reg_field : range(0, 7) = op - 200;
      let reg = extend_reg(reg_field, pfx.rex_b);
      let os = get_operand_size(pfx);
      match os {
        OS32 => {
          let v : dword = read_gpr32(reg);
          write_gpr32(reg, v[7..0] @ v[15..8] @ v[23..16] @ v[31..24])
        },
        OS64 => {
          let v : qword = read_gpr64(reg);
          write_gpr64(reg, v[7..0] @ v[15..8] @ v[23..16] @ v[31..24] @
                           v[39..32] @ v[47..40] @ v[55..48] @ v[63..56])
        },
        _ => (),
      };
      Ok()
    },
    // 0F 77: EMMS
    119 => Ok(),
    _ => raise_UD(),
  }
}
