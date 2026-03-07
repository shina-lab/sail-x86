// x86-64 Decoder — 2-Byte Opcode Map (0F xx) Dispatch
//
// Phase 2: CMOVcc, SETcc, Jcc rel32, MOVZX/SX, BSF/BSR, CMPXCHG, BT*,
// SHLD/SHRD, IMUL 2-op, BSWAP, XADD, etc.

val dispatch_opcode_2byte : (byte, Prefixes) -> ExecutionResult
function dispatch_opcode_2byte(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  match op {
    // 0F 38: 3-byte escape (SSSE3/SSE4/AES-NI)
    56 => {
      let opcode3 = fetch_byte();
      let op3 : range(0, 255) = unsigned(opcode3);
      if op3 == 246 then {
        // ADCX (66) / ADOX (F3)
        let mp = get_mandatory_prefix(pfx);
        let os = get_operand_size(pfx);
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let rm = decode_rm(modrm, pfx);
        let src_val = read_rm_val(rm, os, pfx.has_rex);
        if mp == MP_66 then {
          let a : qword = read_gpr(reg, os);
          let c : int = if CF == bitone then 1 else 0;
          let result : qword = a + src_val + zero_extend(CF);
          match os {
            OS32 => CF = bool_to_bit(unsigned(result[31..0]) != unsigned(a[31..0]) + unsigned(src_val[31..0]) + c),
            OS64 => CF = bool_to_bit(unsigned(result) != unsigned(a) + unsigned(src_val) + c),
            _ => (),
          };
          write_gpr(reg, os, result);
          Ok()
        } else if mp == MP_F3 then {
          let a : qword = read_gpr(reg, os);
          let c : int = if OF == bitone then 1 else 0;
          let result : qword = a + src_val + zero_extend(OF);
          match os {
            OS32 => OF = bool_to_bit(unsigned(result[31..0]) != unsigned(a[31..0]) + unsigned(src_val[31..0]) + c),
            OS64 => OF = bool_to_bit(unsigned(result) != unsigned(a) + unsigned(src_val) + c),
            _ => (),
          };
          write_gpr(reg, os, result);
          Ok()
        } else {
          raise_UD()
        }
      } else if op3 == 20 then {
        dispatch_3byte_38_sse_fp(opcode3, pfx)    // BLENDVPS
      } else if op3 == 21 then {
        dispatch_3byte_38_sse_fp(opcode3, pfx)    // BLENDVPD
      } else {
        dispatch_3byte_38_sse_int(opcode3, pfx)
      }
    },
    // 0F 3A: 3-byte escape (SSE4/AES-NI with imm8)
    58 => {
      let opcode3 = fetch_byte();
      let op3 : range(0, 255) = unsigned(opcode3);
      if op3 == 8 then dispatch_3byte_3a_sse_fp(opcode3, pfx)       // ROUNDPS
      else if op3 == 9 then dispatch_3byte_3a_sse_fp(opcode3, pfx)  // ROUNDPD
      else if op3 == 10 then dispatch_3byte_3a_sse_fp(opcode3, pfx) // ROUNDSS
      else if op3 == 11 then dispatch_3byte_3a_sse_fp(opcode3, pfx) // ROUNDSD
      else if op3 == 12 then dispatch_3byte_3a_sse_fp(opcode3, pfx) // BLENDPS
      else if op3 == 13 then dispatch_3byte_3a_sse_fp(opcode3, pfx) // BLENDPD
      else if op3 == 23 then dispatch_3byte_3a_sse_fp(opcode3, pfx) // EXTRACTPS
      else if op3 == 33 then dispatch_3byte_3a_sse_fp(opcode3, pfx) // INSERTPS
      else if op3 == 64 then dispatch_3byte_3a_sse_fp(opcode3, pfx) // DPPS
      else if op3 == 65 then dispatch_3byte_3a_sse_fp(opcode3, pfx) // DPPD
      else dispatch_3byte_3a_sse_int(opcode3, pfx)
    },

    // SSE floating-point (data movement, arithmetic, conversion, comparison)
    op if 16 <= op & op <= 23 => dispatch_2byte_sse_fp(op, pfx),
    op if 40 <= op & op <= 47 => dispatch_2byte_sse_fp(op, pfx),
    op if 80 <= op & op <= 95 => dispatch_2byte_sse_fp(op, pfx),
    124 => dispatch_2byte_sse_fp(op, pfx),
    125 => dispatch_2byte_sse_fp(op, pfx),
    194 => dispatch_2byte_sse_fp(op, pfx),
    198 => dispatch_2byte_sse_fp(op, pfx),
    208 => dispatch_2byte_sse_fp(op, pfx),
    214 => dispatch_2byte_sse_fp(op, pfx),
    230 => dispatch_2byte_sse_fp(op, pfx),

    // SSE integer (packed integer arithmetic, logical, shift, pack/unpack)
    op if 96 <= op & op <= 118 => dispatch_2byte_sse_int(op, pfx),
    126 => dispatch_2byte_sse_int(op, pfx),
    127 => dispatch_2byte_sse_int(op, pfx),
    196 => dispatch_2byte_sse_int(op, pfx),
    197 => dispatch_2byte_sse_int(op, pfx),
    op if 209 <= op & op <= 213 => dispatch_2byte_sse_int(op, pfx),
    op if 215 <= op & op <= 229 => dispatch_2byte_sse_int(op, pfx),
    op if 231 <= op & op <= 255 => dispatch_2byte_sse_int(op, pfx),

    // GPR and system operations (everything else)
    _ => dispatch_2byte_gpr(op, pfx),
  }
}
