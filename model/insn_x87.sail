// x86-64 — x87 FPU (opcodes D8-DF)
//
// Each x87 opcode consumes a ModR/M byte. When mod != 11 (memory),
// the reg field selects the operation. When mod == 11 (register),
// the full ModR/M byte selects from a large table.

// =========================================================================
// 80-bit extended precision arithmetic (external — no native float80 in Sail)
// =========================================================================

val __f80_add : (fp80, fp80) -> fp80
val __f80_sub : (fp80, fp80) -> fp80
val __f80_mul : (fp80, fp80) -> fp80
val __f80_div : (fp80, fp80) -> fp80
val __f80_sqrt : fp80 -> fp80
val __f80_abs : fp80 -> fp80
val __f80_chs : fp80 -> fp80
val __f80_compare : (fp80, fp80) -> FPCompareResult

// Conversions to/from 80-bit extended precision
val __f80_from_f32 : dword -> fp80
val __f80_from_f64 : qword -> fp80
val __f80_to_f32 : fp80 -> dword
val __f80_to_f64 : fp80 -> qword
val __f80_from_int16 : word -> fp80
val __f80_from_int32 : dword -> fp80
val __f80_from_int64 : qword -> fp80
val __f80_to_int16 : fp80 -> word
val __f80_to_int32 : fp80 -> dword
val __f80_to_int64 : fp80 -> qword
val __f80_to_int16_trunc : fp80 -> word
val __f80_to_int32_trunc : fp80 -> dword
val __f80_to_int64_trunc : fp80 -> qword

// Constants
val __f80_zero : unit -> fp80
val __f80_one : unit -> fp80
val __f80_log2_10 : unit -> fp80
val __f80_log2_e : unit -> fp80
val __f80_pi : unit -> fp80
val __f80_log10_2 : unit -> fp80
val __f80_ln_2 : unit -> fp80

// Classification
val __f80_classify : fp80 -> FPClass

// Decomposition (used by FXTRACT)
val __f80_extract_exponent : fp80 -> fp80
val __f80_extract_significand : fp80 -> fp80

// Transcendental operations
val __f80_yl2x : (fp80, fp80) -> fp80
val __f80_yl2xp1 : (fp80, fp80) -> fp80
val __f80_sin : fp80 -> fp80
val __f80_cos : fp80 -> fp80
val __f80_tan : fp80 -> fp80
val __f80_atan2 : (fp80, fp80) -> fp80
val __f80_2xm1 : fp80 -> fp80
val __f80_scale : (fp80, fp80) -> fp80
val __f80_prem : (fp80, fp80) -> fp80
val __f80_prem1 : (fp80, fp80) -> fp80
val __f80_round : fp80 -> fp80

// BCD conversions (for FBLD/FBSTP)
val __f80_from_bcd : fp80 -> fp80
val __f80_to_bcd : fp80 -> fp80

val __wait : unit -> unit

// =========================================================================
// Memory access helpers for x87 data sizes
// =========================================================================

val seg_read_fp80 : (segreg_idx, qword) -> fp80
function seg_read_fp80(seg, offset) = read_mem(seg_linear(seg, offset, 10))

val seg_write_fp80 : (segreg_idx, qword, fp80) -> unit
function seg_write_fp80(seg, offset, v) = write_mem(seg_linear(seg, offset, 10), v)

val seg_read_224 : (segreg_idx, qword) -> bits(224)
function seg_read_224(seg, offset) = read_mem(seg_linear(seg, offset, 28))

val seg_write_224 : (segreg_idx, qword, bits(224)) -> unit
function seg_write_224(seg, offset, v) = write_mem(seg_linear(seg, offset, 28), v)

val seg_read_864 : (segreg_idx, qword) -> bits(864)
function seg_read_864(seg, offset) = read_mem(seg_linear(seg, offset, 108))

val seg_write_864 : (segreg_idx, qword, bits(864)) -> unit
function seg_write_864(seg, offset, v) = write_mem(seg_linear(seg, offset, 108), v)

// =========================================================================
// Status word condition code helpers
// =========================================================================

// Set x87 status word condition codes C3(14), C2(10), C0(8) from comparison
val x87_set_sw_cc : FPCompareResult -> unit
function x87_set_sw_cc(cmp) = {
  var sw : word = x87_sw;
  match cmp {
    FP_GT        => { sw[14] = 0b0; sw[10] = 0b0; sw[8] = 0b0; },
    FP_LT        => { sw[14] = 0b0; sw[10] = 0b0; sw[8] = 0b1;  },
    FP_EQ        => { sw[14] = 0b1; sw[10] = 0b0; sw[8] = 0b0; },
    FP_UNORDERED => { sw[14] = 0b1; sw[10] = 0b1; sw[8] = 0b1;  },
  };
  x87_sw = sw
}

// Set RFLAGS from FP comparison (for FCOMI/FUCOMI variants)
val x87_set_rflags_cc : FPCompareResult -> unit
function x87_set_rflags_cc(cmp) = {
  match cmp {
    FP_UNORDERED => { ZF = 0b1; PF = 0b1; CF = 0b1;  },
    FP_GT        => { ZF = 0b0; PF = 0b0; CF = 0b0; },
    FP_LT        => { ZF = 0b0; PF = 0b0; CF = 0b1;  },
    FP_EQ        => { ZF = 0b1; PF = 0b0; CF = 0b0; },
  };
  OF = 0b0;
  AF = 0b0;
  SF = 0b0
}

// =========================================================================
// D8: FADD/FMUL/FCOM/FCOMP/FSUB/FSUBR/FDIV/FDIVR (f32 mem or ST(i))
// =========================================================================

val dispatch_x87_d8 : (byte, RM, Prefixes) -> unit
function dispatch_x87_d8(modrm, src, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match src {
    RM_mem(m) => {
      let src : fp80 = __f80_from_f32(read_mem(m));
      let st0 : fp80 = x87_read_st(0);
      match reg {
        0 => x87_write_st(0, __f80_add(st0, src)),
        1 => x87_write_st(0, __f80_mul(st0, src)),
        2 => x87_set_sw_cc(__f80_compare(st0, src)),
        3 => { x87_set_sw_cc(__f80_compare(st0, src)); let _ = x87_pop() },
        4 => x87_write_st(0, __f80_sub(st0, src)),
        5 => x87_write_st(0, __f80_sub(src, st0)),
        6 => x87_write_st(0, __f80_div(st0, src)),
        7 => x87_write_st(0, __f80_div(src, st0)),
      }
    },
    RM_reg(_) => {
      match reg {
        0 => x87_write_st(0, __f80_add(x87_read_st(0), x87_read_st(sti))),
        1 => x87_write_st(0, __f80_mul(x87_read_st(0), x87_read_st(sti))),
        2 => x87_set_sw_cc(__f80_compare(x87_read_st(0), x87_read_st(sti))),
        3 => {
          x87_set_sw_cc(__f80_compare(x87_read_st(0), x87_read_st(sti)));
          let _ = x87_pop()
        },
        4 => x87_write_st(0, __f80_sub(x87_read_st(0), x87_read_st(sti))),
        5 => x87_write_st(0, __f80_sub(x87_read_st(sti), x87_read_st(0))),
        6 => x87_write_st(0, __f80_div(x87_read_st(0), x87_read_st(sti))),
        7 => x87_write_st(0, __f80_div(x87_read_st(sti), x87_read_st(0))),
      }
    },
  }
}

// =========================================================================
// D9: FLD/FST/FSTP/FLDENV/FLDCW/FNSTENV/FNSTCW (f32 mem) or misc register ops
// =========================================================================

val dispatch_x87_d9 : (byte, RM, Prefixes) -> unit
function dispatch_x87_d9(modrm, operand, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match operand {
    RM_mem(m) => {
      match reg {
        0 => x87_push(__f80_from_f32(read_mem(m))),
        1 => raise_UD(),
        2 => write_mem(m,__f80_to_f32(x87_read_st(0))),
        3 => write_mem(m,__f80_to_f32(x87_pop())),
        4 => x87_load_env(seg_read_224(m.seg, m.addr)),
        5 => x87_cw = read_mem(m),
        6 => seg_write_224(m.seg, m.addr, x87_save_env()),
        7 => write_mem(m,x87_cw),
      }
    },
    RM_reg(_) => {
      let modrm_val : range(0, 255) = unsigned(modrm);
      match reg {
        0 => x87_push(x87_read_st(sti)),
        // FXCH ST(i)
        1 => {
          let v0 : fp80 = x87_read_st(0);
          let vi : fp80 = x87_read_st(sti);
          x87_write_st(0, vi);
          x87_write_st(sti, v0)
        },
        2 => if sti == 0 then () else raise_UD(),  // FNOP
        _ => {
          // D9 E0-FF: misc operations encoded by full ModR/M
          match modrm_val {
            // FCHS
            224 => x87_write_st(0, __f80_chs(x87_read_st(0))),
            // FABS
            225 => x87_write_st(0, __f80_abs(x87_read_st(0))),
            // FTST
            228 => x87_set_sw_cc(__f80_compare(x87_read_st(0), __f80_zero())),
            // FXAM — examine ST(0), set C3/C2/C0 for class, C1 for sign
            229 => {
              let val80 : fp80 = x87_read_st(0);
              var sw : word = x87_sw;
              sw[9] = val80[79];  // C1 = sign bit
              match __f80_classify(val80) {
                FP_Unsupported => { sw[14] = 0b0; sw[10] = 0b0; sw[8] = 0b0; },
                FP_NaN         => { sw[14] = 0b0; sw[10] = 0b0; sw[8] = 0b1;  },
                FP_Normal      => { sw[14] = 0b0; sw[10] = 0b1; sw[8] = 0b0; },
                FP_Infinity    => { sw[14] = 0b0; sw[10] = 0b1; sw[8] = 0b1;  },
                FP_Zero        => { sw[14] = 0b1; sw[10] = 0b0; sw[8] = 0b0; },
                FP_Empty       => { sw[14] = 0b1; sw[10] = 0b0; sw[8] = 0b1;  },
                FP_Denormal    => { sw[14] = 0b1; sw[10] = 0b1; sw[8] = 0b0; },
              };
              x87_sw = sw
            },
            // FLD1
            232 => x87_push(__f80_one()),
            // FLDL2T
            233 => x87_push(__f80_log2_10()),
            // FLDL2E
            234 => x87_push(__f80_log2_e()),
            // FLDPI
            235 => x87_push(__f80_pi()),
            // FLDLG2
            236 => x87_push(__f80_log10_2()),
            // FLDLN2
            237 => x87_push(__f80_ln_2()),
            // FLDZ
            238 => x87_push(__f80_zero()),
            // F2XM1
            240 => x87_write_st(0, __f80_2xm1(x87_read_st(0))),
            // FYL2X — ST(1) * log2(ST(0)), pop
            241 => {
              let result = __f80_yl2x(x87_read_st(1), x87_read_st(0));
              let _ = x87_pop();
              x87_write_st(0, result)
            },
            // FPTAN — tan(ST(0)), push 1.0
            242 => {
              x87_write_st(0, __f80_tan(x87_read_st(0)));
              x87_push(__f80_one())
            },
            // FPATAN — atan2(ST(1), ST(0)), pop
            243 => {
              let result = __f80_atan2(x87_read_st(1), x87_read_st(0));
              let _ = x87_pop();
              x87_write_st(0, result)
            },
            // FXTRACT — split into exponent + significand
            244 => {
              let val80 = x87_read_st(0);
              x87_write_st(0, __f80_extract_exponent(val80));
              x87_push(__f80_extract_significand(val80))
            },
            // FPREM1
            245 => x87_write_st(0, __f80_prem1(x87_read_st(0), x87_read_st(1))),
            // FDECSTP
            246 => x87_dec_top(),
            // FINCSTP
            247 => x87_inc_top(),
            // FPREM
            248 => x87_write_st(0, __f80_prem(x87_read_st(0), x87_read_st(1))),
            // FYL2XP1 — ST(1) * log2(ST(0) + 1), pop
            249 => {
              let result = __f80_yl2xp1(x87_read_st(1), x87_read_st(0));
              let _ = x87_pop();
              x87_write_st(0, result)
            },
            // FSQRT
            250 => x87_write_st(0, __f80_sqrt(x87_read_st(0))),
            // FSINCOS — sin in ST(0), push cos
            251 => {
              let src = x87_read_st(0);
              x87_write_st(0, __f80_sin(src));
              x87_push(__f80_cos(src))
            },
            // FRNDINT
            252 => x87_write_st(0, __f80_round(x87_read_st(0))),
            // FSCALE
            253 => x87_write_st(0, __f80_scale(x87_read_st(0), x87_read_st(1))),
            // FSIN
            254 => x87_write_st(0, __f80_sin(x87_read_st(0))),
            // FCOS
            255 => x87_write_st(0, __f80_cos(x87_read_st(0))),
            _   => raise_UD(),
          }
        },
      }
    },
  }
}

// =========================================================================
// DA: FIADD/FIMUL/FICOM/FICOMP/FISUB/FISUBR/FIDIV/FIDIVR (i32 mem) or FCMOVcc
// =========================================================================

val dispatch_x87_da : (byte, RM, Prefixes) -> unit
function dispatch_x87_da(modrm, src, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match src {
    RM_mem(m) => {
      let src : fp80 = __f80_from_int32(read_mem(m));
      let st0 : fp80 = x87_read_st(0);
      match reg {
        0 => x87_write_st(0, __f80_add(st0, src)),
        1 => x87_write_st(0, __f80_mul(st0, src)),
        2 => x87_set_sw_cc(__f80_compare(st0, src)),
        3 => { x87_set_sw_cc(__f80_compare(st0, src)); let _ = x87_pop() },
        4 => x87_write_st(0, __f80_sub(st0, src)),
        5 => x87_write_st(0, __f80_sub(src, st0)),
        6 => x87_write_st(0, __f80_div(st0, src)),
        7 => x87_write_st(0, __f80_div(src, st0)),
      }
    },
    RM_reg(_) => {
      match reg {
        0 => if CF == 0b1 then x87_write_st(0, x87_read_st(sti)),
        1 => if ZF == 0b1 then x87_write_st(0, x87_read_st(sti)),
        2 => if CF == 0b1 | ZF == 0b1 then x87_write_st(0, x87_read_st(sti)),
        3 => if PF == 0b1 then x87_write_st(0, x87_read_st(sti)),
        // FUCOMPP
        5 => {
          if sti == 1 then {
            x87_set_sw_cc(__f80_compare(x87_read_st(0), x87_read_st(1)));
            let _ = x87_pop();
            let _ = x87_pop()
          } else {
            raise_UD()
          }
        },
        _ => raise_UD(),
      }
    },
  }
}

// =========================================================================
// DB: FILD/FISTTP/FIST/FISTP (i32 mem) / FLD/FSTP (f80) or FCMOVcc/FCOMI/FUCOMI
// =========================================================================

val dispatch_x87_db : (byte, RM, Prefixes) -> unit
function dispatch_x87_db(modrm, operand, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match operand {
    RM_mem(m) => {
      match reg {
        0 => x87_push(__f80_from_int32(read_mem(m))),
        1 => write_mem(m,__f80_to_int32_trunc(x87_pop())),
        2 => write_mem(m,__f80_to_int32(x87_read_st(0))),
        3 => write_mem(m,__f80_to_int32(x87_pop())),
        4 => raise_UD(),
        5 => x87_push(seg_read_fp80(m.seg, m.addr)),
        6 => raise_UD(),
        7 => seg_write_fp80(m.seg, m.addr, x87_pop()),
      }
    },
    RM_reg(_) => {
      let modrm_val : range(0, 255) = unsigned(modrm);
      match reg {
        0 => if CF == 0b0 then x87_write_st(0, x87_read_st(sti)),
        1 => if ZF == 0b0 then x87_write_st(0, x87_read_st(sti)),
        2 => if CF == 0b0 & ZF == 0b0 then x87_write_st(0, x87_read_st(sti)),
        3 => if PF == 0b0 then x87_write_st(0, x87_read_st(sti)),
        // FNCLEX — clear exception flags
        4 => {
          if modrm_val == 226 then {
            var sw : word = x87_sw;
            sw[7 .. 0] = 0x00;
            sw[15] = 0b0;
            x87_sw = sw
          // FNINIT
          } else if modrm_val == 227 then {
            x87_init()
          } else {
            raise_UD()
          }
        },
        5 => x87_set_rflags_cc(__f80_compare(x87_read_st(0), x87_read_st(sti))),
        6 => x87_set_rflags_cc(__f80_compare(x87_read_st(0), x87_read_st(sti))),
        7 => raise_UD(),
      }
    },
  }
}

// =========================================================================
// DC: FADD/FMUL/FCOM/FCOMP/FSUB/FSUBR/FDIV/FDIVR (f64 mem or ST(i),ST(0))
// =========================================================================

val dispatch_x87_dc : (byte, RM, Prefixes) -> unit
function dispatch_x87_dc(modrm, src, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match src {
    RM_mem(m) => {
      let src : fp80 = __f80_from_f64(read_mem(m));
      let st0 : fp80 = x87_read_st(0);
      match reg {
        0 => x87_write_st(0, __f80_add(st0, src)),
        1 => x87_write_st(0, __f80_mul(st0, src)),
        2 => x87_set_sw_cc(__f80_compare(st0, src)),
        3 => { x87_set_sw_cc(__f80_compare(st0, src)); let _ = x87_pop() },
        4 => x87_write_st(0, __f80_sub(st0, src)),
        5 => x87_write_st(0, __f80_sub(src, st0)),
        6 => x87_write_st(0, __f80_div(st0, src)),
        7 => x87_write_st(0, __f80_div(src, st0)),
      }
    },
    RM_reg(_) => {
      // Note: SUB/SUBR and DIV/DIVR are swapped vs D8
      match reg {
        0 => x87_write_st(sti, __f80_add(x87_read_st(sti), x87_read_st(0))),
        1 => x87_write_st(sti, __f80_mul(x87_read_st(sti), x87_read_st(0))),
        2 => raise_UD(),
        3 => raise_UD(),
        4 => x87_write_st(sti, __f80_sub(x87_read_st(0), x87_read_st(sti))),
        5 => x87_write_st(sti, __f80_sub(x87_read_st(sti), x87_read_st(0))),
        6 => x87_write_st(sti, __f80_div(x87_read_st(0), x87_read_st(sti))),
        7 => x87_write_st(sti, __f80_div(x87_read_st(sti), x87_read_st(0))),
      }
    },
  }
}

// =========================================================================
// DD: FLD/FISTTP/FST/FSTP (f64 mem) / FRSTOR/FNSAVE/FNSTSW or FFREE/FUCOM/FUCOMP
// =========================================================================

val dispatch_x87_dd : (byte, RM, Prefixes) -> unit
function dispatch_x87_dd(modrm, operand, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match operand {
    RM_mem(m) => {
      match reg {
        0 => x87_push(__f80_from_f64(read_mem(m))),
        1 => write_mem(m,__f80_to_int64_trunc(x87_pop())),
        2 => write_mem(m,__f80_to_f64(x87_read_st(0))),
        3 => write_mem(m,__f80_to_f64(x87_pop())),
        4 => x87_load_state(seg_read_864(m.seg, m.addr)),
        5 => raise_UD(),
        // FNSAVE — save state, then reinitialize
        6 => {
          let state = x87_save_state();
          x87_init();
          seg_write_864(m.seg, m.addr, state)
        },
        7 => write_mem(m,x87_sw),
      }
    },
    RM_reg(_) => {
      match reg {
        0 => x87_free(sti),
        1 => raise_UD(),
        2 => x87_write_st(sti, x87_read_st(0)),
        3 => { x87_write_st(sti, x87_read_st(0)); let _ = x87_pop() },
        4 => x87_set_sw_cc(__f80_compare(x87_read_st(0), x87_read_st(sti))),
        5 => {
          x87_set_sw_cc(__f80_compare(x87_read_st(0), x87_read_st(sti)));
          let _ = x87_pop()
        },
        6 => raise_UD(),
        7 => raise_UD(),
      }
    },
  }
}

// =========================================================================
// DE: FIADD/FIMUL/FICOM/FICOMP/FISUB/FISUBR/FIDIV/FIDIVR (i16 mem) or FADDP/etc
// =========================================================================

val dispatch_x87_de : (byte, RM, Prefixes) -> unit
function dispatch_x87_de(modrm, src, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match src {
    RM_mem(m) => {
      let src : fp80 = __f80_from_int16(read_mem(m));
      let st0 : fp80 = x87_read_st(0);
      match reg {
        0 => x87_write_st(0, __f80_add(st0, src)),
        1 => x87_write_st(0, __f80_mul(st0, src)),
        2 => x87_set_sw_cc(__f80_compare(st0, src)),
        3 => { x87_set_sw_cc(__f80_compare(st0, src)); let _ = x87_pop() },
        4 => x87_write_st(0, __f80_sub(st0, src)),
        5 => x87_write_st(0, __f80_sub(src, st0)),
        6 => x87_write_st(0, __f80_div(st0, src)),
        7 => x87_write_st(0, __f80_div(src, st0)),
      }
    },
    RM_reg(_) => {
      let modrm_val : range(0, 255) = unsigned(modrm);
      // Note: SUB/SUBR and DIV/DIVR swapped vs DA
      match reg {
        0 => {
          let result = __f80_add(x87_read_st(sti), x87_read_st(0));
          let _ = x87_pop();
          x87_write_st(sti - 1, result)
        },
        1 => {
          let result = __f80_mul(x87_read_st(sti), x87_read_st(0));
          let _ = x87_pop();
          x87_write_st(sti - 1, result)
        },
        // FCOMPP
        2 => {
          if modrm_val == 217 then {
            x87_set_sw_cc(__f80_compare(x87_read_st(0), x87_read_st(1)));
            let _ = x87_pop();
            let _ = x87_pop()
          } else {
            raise_UD()
          }
        },
        3 => raise_UD(),
        // FSUBRP — ST(i) = ST(0) - ST(i), pop
        4 => {
          let result = __f80_sub(x87_read_st(0), x87_read_st(sti));
          let _ = x87_pop();
          x87_write_st(sti - 1, result)
        },
        // FSUBP — ST(i) = ST(i) - ST(0), pop
        5 => {
          let result = __f80_sub(x87_read_st(sti), x87_read_st(0));
          let _ = x87_pop();
          x87_write_st(sti - 1, result)
        },
        // FDIVRP — ST(i) = ST(0) / ST(i), pop
        6 => {
          let result = __f80_div(x87_read_st(0), x87_read_st(sti));
          let _ = x87_pop();
          x87_write_st(sti - 1, result)
        },
        // FDIVP — ST(i) = ST(i) / ST(0), pop
        7 => {
          let result = __f80_div(x87_read_st(sti), x87_read_st(0));
          let _ = x87_pop();
          x87_write_st(sti - 1, result)
        },
      }
    },
  }
}

// =========================================================================
// DF: FILD/FISTTP/FIST/FISTP (i16/i64 mem) / FBLD/FBSTP or FNSTSW AX/FUCOMIP/FCOMIP
// =========================================================================

val dispatch_x87_df : (byte, RM, Prefixes) -> unit
function dispatch_x87_df(modrm, operand, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match operand {
    RM_mem(m) => {
      match reg {
        0 => x87_push(__f80_from_int16(read_mem(m))),
        1 => write_mem(m,__f80_to_int16_trunc(x87_pop())),
        2 => write_mem(m,__f80_to_int16(x87_read_st(0))),
        3 => write_mem(m,__f80_to_int16(x87_pop())),
        4 => x87_push(__f80_from_bcd(seg_read_fp80(m.seg, m.addr))),
        5 => x87_push(__f80_from_int64(read_mem(m))),
        6 => seg_write_fp80(m.seg, m.addr, __f80_to_bcd(x87_pop())),
        7 => write_mem(m,__f80_to_int64(x87_pop())),
      }
    },
    RM_reg(_) => {
      let modrm_val : range(0, 255) = unsigned(modrm);
      match reg {
        // FNSTSW AX
        4 => {
          if modrm_val == 224 then {
            reg(RAX) = x87_sw
          } else {
            raise_UD()
          }
        },
        // FUCOMIP — unordered compare, set RFLAGS, pop
        5 => {
          x87_set_rflags_cc(__f80_compare(x87_read_st(0), x87_read_st(sti)));
          let _ = x87_pop()
        },
        // FCOMIP — compare, set RFLAGS, pop
        6 => {
          x87_set_rflags_cc(__f80_compare(x87_read_st(0), x87_read_st(sti)));
          let _ = x87_pop()
        },
        _ => raise_UD(),
      }
    },
  }
}

// =========================================================================
// Main x87 dispatcher: takes the opcode byte (D8-DF)
// =========================================================================

val dispatch_x87 : (byte, Prefixes) -> unit
function dispatch_x87(opcode, pfx) = {
  let modrm = fetch_byte();
  let operand = decode_rm(modrm, pfx);
  let op : range(0, 255) = unsigned(opcode);
  match op {
    216 => dispatch_x87_d8(modrm, operand, pfx),
    217 => dispatch_x87_d9(modrm, operand, pfx),
    218 => dispatch_x87_da(modrm, operand, pfx),
    219 => dispatch_x87_db(modrm, operand, pfx),
    220 => dispatch_x87_dc(modrm, operand, pfx),
    221 => dispatch_x87_dd(modrm, operand, pfx),
    222 => dispatch_x87_de(modrm, operand, pfx),
    223 => dispatch_x87_df(modrm, operand, pfx),
    _   => raise_UD(),
  }
}
