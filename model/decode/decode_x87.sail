// x86-64 Decoder — x87 FPU (opcodes D8-DF)
//
// Each x87 opcode consumes a ModR/M byte. When mod != 11 (memory),
// the reg field selects the operation. When mod == 11 (register),
// the full ModR/M byte selects from a large table.

val mem_read_fp80 : qword -> fp80
function mem_read_fp80(addr) = mem_read(addr, 10)

val mem_write_fp80 : (qword, fp80) -> unit
function mem_write_fp80(addr, v) = mem_write(addr, 10, v)

val mem_read_224 : qword -> bits(224)
function mem_read_224(addr) = mem_read(addr, 28)

val mem_write_224 : (qword, bits(224)) -> unit
function mem_write_224(addr, v) = mem_write(addr, 28, v)

val mem_read_864 : qword -> bits(864)
function mem_read_864(addr) = mem_read(addr, 108)

val mem_write_864 : (qword, bits(864)) -> unit
function mem_write_864(addr, v) = mem_write(addr, 108, v)

// D8: FADD/FMUL/FCOM/FCOMP/FSUB/FSUBR/FDIV/FDIVR (f32 mem or ST(i))
val dispatch_x87_d8 : (byte, RM, Prefixes) -> ExecutionResult
function dispatch_x87_d8(modrm, rm, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match rm {
    RM_mem(addr) => {
      let v = mem_read32(addr);
      match reg {
        0 => exec_fadd_f32(v),
        1 => exec_fmul_f32(v),
        2 => exec_fcom(sti),
        3 => exec_fcomp(sti),
        4 => exec_fsub_f32(v),
        5 => exec_fsubr_f32(v),
        6 => exec_fdiv_f32(v),
        7 => exec_fdivr_f32(v),
      }
    },
    RM_reg(_) => {
      match reg {
        0 => exec_fadd_st0_sti(sti),
        1 => exec_fmul_st0_sti(sti),
        2 => exec_fcom(sti),
        3 => exec_fcomp(sti),
        4 => exec_fsub_st0_sti(sti),
        5 => exec_fsubr_st0_sti(sti),
        6 => exec_fdiv_st0_sti(sti),
        7 => exec_fdivr_st0_sti(sti),
      }
    },
  }
}

// D9: FLD/FST/FSTP/FLDENV/FLDCW/FNSTENV/FNSTCW (f32 mem) or misc register ops
val dispatch_x87_d9 : (byte, RM, Prefixes) -> ExecutionResult
function dispatch_x87_d9(modrm, rm, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match rm {
    RM_mem(addr) => {
      match reg {
        0 => exec_fld_f32(mem_read32(addr)),
        2 => { mem_write32(addr, exec_fst_f32()); Ok(()) },
        3 => { mem_write32(addr, exec_fstp_f32()); Ok(()) },
        4 => exec_fldenv(mem_read_224(addr)),
        5 => exec_fldcw(mem_read16(addr)),
        6 => { mem_write_224(addr, exec_fnstenv()); Ok(()) },
        7 => { mem_write16(addr, exec_fnstcw()); Ok(()) },
        _ => raise_UD(),
      }
    },
    RM_reg(_) => {
      let modrm_val : range(0, 255) = unsigned(modrm);
      match reg {
        0 => exec_fld_st(sti),
        1 => exec_fxch(sti),
        2 => if sti == 0 then exec_fnop() else raise_UD(),
        _ => {
          // D9 E0-FF: misc operations encoded by full ModR/M
          match modrm_val {
            224 => exec_fchs(),
            225 => exec_fabs(),
            228 => exec_ftst(),
            229 => exec_fxam(),
            232 => exec_fld1(),
            233 => exec_fldl2t(),
            234 => exec_fldl2e(),
            235 => exec_fldpi(),
            236 => exec_fldlg2(),
            237 => exec_fldln2(),
            238 => exec_fldz(),
            240 => exec_f2xm1(),
            241 => exec_fyl2x(),
            242 => exec_fptan(),
            243 => exec_fpatan(),
            244 => exec_fxtract(),
            245 => exec_fprem1(),
            246 => exec_fdecstp(),
            247 => exec_fincstp(),
            248 => exec_fprem(),
            249 => exec_fyl2xp1(),
            250 => exec_fsqrt(),
            251 => exec_fsincos(),
            252 => exec_frndint(),
            253 => exec_fscale(),
            254 => exec_fsin(),
            255 => exec_fcos(),
            _   => raise_UD(),
          }
        },
      }
    },
  }
}

// DA: FIADD/FIMUL/FICOM/FICOMP/FISUB/FISUBR/FIDIV/FIDIVR (i32 mem) or FCMOVcc
val dispatch_x87_da : (byte, RM, Prefixes) -> ExecutionResult
function dispatch_x87_da(modrm, rm, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match rm {
    RM_mem(addr) => {
      let v = mem_read32(addr);
      match reg {
        0 => exec_fiadd_i32(v),
        1 => exec_fimul_i32(v),
        2 => exec_ficom_i32(v),
        3 => exec_ficomp_i32(v),
        4 => exec_fisub_i32(v),
        5 => exec_fisubr_i32(v),
        6 => exec_fidiv_i32(v),
        7 => exec_fidivr_i32(v),
      }
    },
    RM_reg(_) => {
      match reg {
        0 => exec_fcmovb(sti),
        1 => exec_fcmove(sti),
        2 => exec_fcmovbe(sti),
        3 => exec_fcmovu(sti),
        5 => if sti == 1 then exec_fucompp() else raise_UD(),
        _ => raise_UD(),
      }
    },
  }
}

// DB: FILD/FISTTP/FIST/FISTP (i32 mem) / FLD/FSTP (f80) or FCMOVcc/FCOMI/FUCOMI
val dispatch_x87_db : (byte, RM, Prefixes) -> ExecutionResult
function dispatch_x87_db(modrm, rm, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match rm {
    RM_mem(addr) => {
      match reg {
        0 => exec_fild_i32(mem_read32(addr)),
        1 => { mem_write32(addr, exec_fisttp_i32()); Ok(()) },
        2 => { mem_write32(addr, exec_fist_i32()); Ok(()) },
        3 => { mem_write32(addr, exec_fistp_i32()); Ok(()) },
        5 => exec_fld_f80(mem_read_fp80(addr)),
        7 => { mem_write_fp80(addr, exec_fstp_f80()); Ok(()) },
        _ => raise_UD(),
      }
    },
    RM_reg(_) => {
      let modrm_val : range(0, 255) = unsigned(modrm);
      match reg {
        0 => exec_fcmovnb(sti),
        1 => exec_fcmovne(sti),
        2 => exec_fcmovnbe(sti),
        3 => exec_fcmovnu(sti),
        4 => {
          if modrm_val == 226 then exec_fnclex()
          else if modrm_val == 227 then exec_fninit()
          else raise_UD()
        },
        5 => exec_fucomi(sti),
        6 => exec_fcomi(sti),
        _ => raise_UD(),
      }
    },
  }
}

// DC: FADD/FMUL/FCOM/FCOMP/FSUB/FSUBR/FDIV/FDIVR (f64 mem or ST(i),ST(0))
val dispatch_x87_dc : (byte, RM, Prefixes) -> ExecutionResult
function dispatch_x87_dc(modrm, rm, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match rm {
    RM_mem(addr) => {
      let v = mem_read64(addr);
      match reg {
        0 => exec_fadd_f64(v),
        1 => exec_fmul_f64(v),
        2 => exec_fcom(sti),
        3 => exec_fcomp(sti),
        4 => exec_fsub_f64(v),
        5 => exec_fsubr_f64(v),
        6 => exec_fdiv_f64(v),
        7 => exec_fdivr_f64(v),
      }
    },
    RM_reg(_) => {
      // Note: SUB/SUBR and DIV/DIVR are swapped vs D8
      match reg {
        0 => exec_fadd_sti_st0(sti),
        1 => exec_fmul_sti_st0(sti),
        4 => exec_fsubr_sti_st0(sti),
        5 => exec_fsub_sti_st0(sti),
        6 => exec_fdivr_sti_st0(sti),
        7 => exec_fdiv_sti_st0(sti),
        _ => raise_UD(),
      }
    },
  }
}

// DD: FLD/FISTTP/FST/FSTP (f64 mem) / FRSTOR/FNSAVE/FNSTSW or FFREE/FUCOM/FUCOMP
val dispatch_x87_dd : (byte, RM, Prefixes) -> ExecutionResult
function dispatch_x87_dd(modrm, rm, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match rm {
    RM_mem(addr) => {
      match reg {
        0 => exec_fld_f64(mem_read64(addr)),
        1 => { mem_write64(addr, exec_fisttp_i64()); Ok(()) },
        2 => { mem_write64(addr, exec_fst_f64()); Ok(()) },
        3 => { mem_write64(addr, exec_fstp_f64()); Ok(()) },
        4 => exec_frstor(mem_read_864(addr)),
        6 => { mem_write_864(addr, exec_fnsave()); Ok(()) },
        7 => { mem_write16(addr, exec_fnstsw()); Ok(()) },
        _ => raise_UD(),
      }
    },
    RM_reg(_) => {
      match reg {
        0 => exec_ffree(sti),
        2 => exec_fst_st(sti),
        3 => exec_fstp_st(sti),
        4 => exec_fucom(sti),
        5 => exec_fucomp(sti),
        _ => raise_UD(),
      }
    },
  }
}

// DE: FIADD/FIMUL/FICOM/FICOMP/FISUB/FISUBR/FIDIV/FIDIVR (i16 mem) or FADDP/etc
val dispatch_x87_de : (byte, RM, Prefixes) -> ExecutionResult
function dispatch_x87_de(modrm, rm, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match rm {
    RM_mem(addr) => {
      let v = mem_read16(addr);
      match reg {
        0 => exec_fiadd_i16(v),
        1 => exec_fimul_i16(v),
        2 => exec_ficom_i16(v),
        3 => exec_ficomp_i16(v),
        4 => exec_fisub_i16(v),
        5 => exec_fisubr_i16(v),
        6 => exec_fidiv_i16(v),
        7 => exec_fidivr_i16(v),
      }
    },
    RM_reg(_) => {
      let modrm_val : range(0, 255) = unsigned(modrm);
      // Note: SUB/SUBR and DIV/DIVR swapped vs DA
      match reg {
        0 => exec_faddp_sti(sti),
        1 => exec_fmulp_sti(sti),
        2 => if modrm_val == 217 then exec_fcompp() else raise_UD(),
        4 => exec_fsubrp_sti(sti),
        5 => exec_fsubp_sti(sti),
        6 => exec_fdivrp_sti(sti),
        7 => exec_fdivp_sti(sti),
        _ => raise_UD(),
      }
    },
  }
}

// DF: FILD/FISTTP/FIST/FISTP (i16/i64 mem) / FBLD/FBSTP or FNSTSW AX/FUCOMIP/FCOMIP
val dispatch_x87_df : (byte, RM, Prefixes) -> ExecutionResult
function dispatch_x87_df(modrm, rm, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match rm {
    RM_mem(addr) => {
      match reg {
        0 => exec_fild_i16(mem_read16(addr)),
        1 => { mem_write16(addr, exec_fisttp_i16()); Ok(()) },
        2 => { mem_write16(addr, exec_fist_i16()); Ok(()) },
        3 => { mem_write16(addr, exec_fistp_i16()); Ok(()) },
        4 => exec_fbld(mem_read_fp80(addr)),
        5 => exec_fild_i64(mem_read64(addr)),
        6 => { mem_write_fp80(addr, exec_fbstp()); Ok(()) },
        7 => { mem_write64(addr, exec_fistp_i64()); Ok(()) },
        _ => raise_UD(),
      }
    },
    RM_reg(_) => {
      let modrm_val : range(0, 255) = unsigned(modrm);
      match reg {
        4 => {
          // DF E0: FNSTSW AX
          if modrm_val == 224 then {
            let sw = exec_fnstsw();
            write_gpr16(RAX, sw);
            Ok(())
          } else raise_UD()
        },
        5 => exec_fucomip(sti),
        6 => exec_fcomip(sti),
        _ => raise_UD(),
      }
    },
  }
}

// Main x87 dispatcher: takes the opcode byte (D8-DF)
val dispatch_x87 : (byte, Prefixes) -> ExecutionResult
function dispatch_x87(opcode, pfx) = {
  let modrm = fetch_byte();
  let rm = decode_rm(modrm, pfx);
  let op : range(0, 255) = unsigned(opcode);
  match op {
    216 => dispatch_x87_d8(modrm, rm, pfx),
    217 => dispatch_x87_d9(modrm, rm, pfx),
    218 => dispatch_x87_da(modrm, rm, pfx),
    219 => dispatch_x87_db(modrm, rm, pfx),
    220 => dispatch_x87_dc(modrm, rm, pfx),
    221 => dispatch_x87_dd(modrm, rm, pfx),
    222 => dispatch_x87_de(modrm, rm, pfx),
    223 => dispatch_x87_df(modrm, rm, pfx),
    _   => raise_UD(),
  }
}
