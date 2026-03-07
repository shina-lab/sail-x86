// x86-64 Decoder — x87 FPU (opcodes D8-DF)
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

val __wait : unit -> ExecutionResult

// =========================================================================
// Memory access helpers for x87 data sizes
// =========================================================================

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

// =========================================================================
// Status word condition code helpers
// =========================================================================

// Set x87 status word condition codes C3(14), C2(10), C0(8) from comparison
val x87_set_sw_cc : FPCompareResult -> unit
function x87_set_sw_cc(cmp) = {
  var sw : word = x87_sw;
  match cmp {
    FP_GT        => { sw[14] = bitzero; sw[10] = bitzero; sw[8] = bitzero; },
    FP_LT        => { sw[14] = bitzero; sw[10] = bitzero; sw[8] = bitone;  },
    FP_EQ        => { sw[14] = bitone;  sw[10] = bitzero; sw[8] = bitzero; },
    FP_UNORDERED => { sw[14] = bitone;  sw[10] = bitone;  sw[8] = bitone;  },
  };
  x87_sw = sw
}

// Set RFLAGS from FP comparison (for FCOMI/FUCOMI variants)
val x87_set_rflags_cc : FPCompareResult -> unit
function x87_set_rflags_cc(cmp) = {
  match cmp {
    FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
    FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
    FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
    FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
  };
  OF = bitzero;
  AF = bitzero;
  SF = bitzero
}

// =========================================================================
// D8: FADD/FMUL/FCOM/FCOMP/FSUB/FSUBR/FDIV/FDIVR (f32 mem or ST(i))
// =========================================================================

val dispatch_x87_d8 : (byte, RM, Prefixes) -> ExecutionResult
function dispatch_x87_d8(modrm, rm, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match rm {
    RM_mem(addr) => {
      let src : fp80 = __f80_from_f32(mem_read32(addr));
      let st0 : fp80 = x87_read_st(0);
      match reg {
        0 => { x87_write_st(0, __f80_add(st0, src)); Ok() },
        1 => { x87_write_st(0, __f80_mul(st0, src)); Ok() },
        2 => { x87_set_sw_cc(__f80_compare(st0, x87_read_st(sti))); Ok() },
        3 => { x87_set_sw_cc(__f80_compare(st0, x87_read_st(sti))); let _ = x87_pop(); Ok() },
        4 => { x87_write_st(0, __f80_sub(st0, src)); Ok() },
        5 => { x87_write_st(0, __f80_sub(src, st0)); Ok() },
        6 => { x87_write_st(0, __f80_div(st0, src)); Ok() },
        7 => { x87_write_st(0, __f80_div(src, st0)); Ok() },
      }
    },
    RM_reg(_) => {
      match reg {
        0 => { x87_write_st(0, __f80_add(x87_read_st(0), x87_read_st(sti))); Ok() },
        1 => { x87_write_st(0, __f80_mul(x87_read_st(0), x87_read_st(sti))); Ok() },
        2 => { x87_set_sw_cc(__f80_compare(x87_read_st(0), x87_read_st(sti))); Ok() },
        3 => {
          x87_set_sw_cc(__f80_compare(x87_read_st(0), x87_read_st(sti)));
          let _ = x87_pop();
          Ok()
        },
        4 => { x87_write_st(0, __f80_sub(x87_read_st(0), x87_read_st(sti))); Ok() },
        5 => { x87_write_st(0, __f80_sub(x87_read_st(sti), x87_read_st(0))); Ok() },
        6 => { x87_write_st(0, __f80_div(x87_read_st(0), x87_read_st(sti))); Ok() },
        7 => { x87_write_st(0, __f80_div(x87_read_st(sti), x87_read_st(0))); Ok() },
      }
    },
  }
}

// =========================================================================
// D9: FLD/FST/FSTP/FLDENV/FLDCW/FNSTENV/FNSTCW (f32 mem) or misc register ops
// =========================================================================

val dispatch_x87_d9 : (byte, RM, Prefixes) -> ExecutionResult
function dispatch_x87_d9(modrm, rm, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match rm {
    RM_mem(addr) => {
      match reg {
        0 => { x87_push(__f80_from_f32(mem_read32(addr))); Ok() },
        2 => { mem_write32(addr, __f80_to_f32(x87_read_st(0))); Ok() },
        3 => { mem_write32(addr, __f80_to_f32(x87_pop())); Ok() },
        4 => { x87_load_env(mem_read_224(addr)); Ok() },
        5 => { x87_cw = mem_read16(addr); Ok() },
        6 => { mem_write_224(addr, x87_save_env()); Ok() },
        7 => { mem_write16(addr, x87_cw); Ok() },
        _ => raise_UD(),
      }
    },
    RM_reg(_) => {
      let modrm_val : range(0, 255) = unsigned(modrm);
      match reg {
        0 => { x87_push(x87_read_st(sti)); Ok() },
        1 => {
          // FXCH ST(i)
          let v0 : fp80 = x87_read_st(0);
          let vi : fp80 = x87_read_st(sti);
          x87_write_st(0, vi);
          x87_write_st(sti, v0);
          Ok()
        },
        2 => if sti == 0 then Ok() else raise_UD(),  // FNOP
        _ => {
          // D9 E0-FF: misc operations encoded by full ModR/M
          match modrm_val {
            // FCHS / FABS
            224 => { x87_write_st(0, __f80_chs(x87_read_st(0))); Ok() },
            225 => { x87_write_st(0, __f80_abs(x87_read_st(0))); Ok() },
            // FTST / FXAM
            228 => { x87_set_sw_cc(__f80_compare(x87_read_st(0), __f80_zero())); Ok() },
            229 => {
              // FXAM — examine ST(0), set C3/C2/C0 for class, C1 for sign
              let val80 : fp80 = x87_read_st(0);
              var sw : word = x87_sw;
              sw[9] = val80[79];  // C1 = sign bit
              match __f80_classify(val80) {
                FP_Unsupported => { sw[14] = bitzero; sw[10] = bitzero; sw[8] = bitzero; },
                FP_NaN         => { sw[14] = bitzero; sw[10] = bitzero; sw[8] = bitone;  },
                FP_Normal      => { sw[14] = bitzero; sw[10] = bitone;  sw[8] = bitzero; },
                FP_Infinity    => { sw[14] = bitzero; sw[10] = bitone;  sw[8] = bitone;  },
                FP_Zero        => { sw[14] = bitone;  sw[10] = bitzero; sw[8] = bitzero; },
                FP_Empty       => { sw[14] = bitone;  sw[10] = bitzero; sw[8] = bitone;  },
                FP_Denormal    => { sw[14] = bitone;  sw[10] = bitone;  sw[8] = bitzero; },
              };
              x87_sw = sw;
              Ok()
            },
            // Load constants
            232 => { x87_push(__f80_one()); Ok() },
            233 => { x87_push(__f80_log2_10()); Ok() },
            234 => { x87_push(__f80_log2_e()); Ok() },
            235 => { x87_push(__f80_pi()); Ok() },
            236 => { x87_push(__f80_log10_2()); Ok() },
            237 => { x87_push(__f80_ln_2()); Ok() },
            238 => { x87_push(__f80_zero()); Ok() },
            // Transcendental / special
            240 => { x87_write_st(0, __f80_2xm1(x87_read_st(0))); Ok() },
            241 => {
              // FYL2X — ST(1) * log2(ST(0)), pop
              let result = __f80_yl2x(x87_read_st(1), x87_read_st(0));
              let _ = x87_pop();
              x87_write_st(0, result);
              Ok()
            },
            242 => {
              // FPTAN — tan(ST(0)), push 1.0
              x87_write_st(0, __f80_tan(x87_read_st(0)));
              x87_push(__f80_one());
              Ok()
            },
            243 => {
              // FPATAN — atan2(ST(1), ST(0)), pop
              let result = __f80_atan2(x87_read_st(1), x87_read_st(0));
              let _ = x87_pop();
              x87_write_st(0, result);
              Ok()
            },
            244 => {
              // FXTRACT — split into exponent + significand
              let val80 = x87_read_st(0);
              x87_write_st(0, __f80_extract_exponent(val80));
              x87_push(__f80_extract_significand(val80));
              Ok()
            },
            245 => { x87_write_st(0, __f80_prem1(x87_read_st(0), x87_read_st(1))); Ok() },
            // FDECSTP
            246 => { x87_dec_top(); Ok() },
            // FINCSTP
            247 => { x87_inc_top(); Ok() },
            248 => { x87_write_st(0, __f80_prem(x87_read_st(0), x87_read_st(1))); Ok() },
            249 => {
              // FYL2XP1 — ST(1) * log2(ST(0) + 1), pop
              let result = __f80_yl2xp1(x87_read_st(1), x87_read_st(0));
              let _ = x87_pop();
              x87_write_st(0, result);
              Ok()
            },
            250 => { x87_write_st(0, __f80_sqrt(x87_read_st(0))); Ok() },
            251 => {
              // FSINCOS — sin in ST(0), push cos
              let src = x87_read_st(0);
              x87_write_st(0, __f80_sin(src));
              x87_push(__f80_cos(src));
              Ok()
            },
            252 => { x87_write_st(0, __f80_round(x87_read_st(0))); Ok() },
            253 => { x87_write_st(0, __f80_scale(x87_read_st(0), x87_read_st(1))); Ok() },
            254 => { x87_write_st(0, __f80_sin(x87_read_st(0))); Ok() },
            255 => { x87_write_st(0, __f80_cos(x87_read_st(0))); Ok() },
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

val dispatch_x87_da : (byte, RM, Prefixes) -> ExecutionResult
function dispatch_x87_da(modrm, rm, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match rm {
    RM_mem(addr) => {
      let src : fp80 = __f80_from_int32(mem_read32(addr));
      let st0 : fp80 = x87_read_st(0);
      match reg {
        0 => { x87_write_st(0, __f80_add(st0, src)); Ok() },
        1 => { x87_write_st(0, __f80_mul(st0, src)); Ok() },
        2 => { x87_set_sw_cc(__f80_compare(st0, src)); Ok() },
        3 => { x87_set_sw_cc(__f80_compare(st0, src)); let _ = x87_pop(); Ok() },
        4 => { x87_write_st(0, __f80_sub(st0, src)); Ok() },
        5 => { x87_write_st(0, __f80_sub(src, st0)); Ok() },
        6 => { x87_write_st(0, __f80_div(st0, src)); Ok() },
        7 => { x87_write_st(0, __f80_div(src, st0)); Ok() },
      }
    },
    RM_reg(_) => {
      match reg {
        0 => { if CF == bitone then x87_write_st(0, x87_read_st(sti)); Ok() },
        1 => { if ZF == bitone then x87_write_st(0, x87_read_st(sti)); Ok() },
        2 => { if CF == bitone | ZF == bitone then x87_write_st(0, x87_read_st(sti)); Ok() },
        3 => { if PF == bitone then x87_write_st(0, x87_read_st(sti)); Ok() },
        5 => {
          // FUCOMPP
          if sti == 1 then {
            x87_set_sw_cc(__f80_compare(x87_read_st(0), x87_read_st(1)));
            let _ = x87_pop();
            let _ = x87_pop();
            Ok()
          } else raise_UD()
        },
        _ => raise_UD(),
      }
    },
  }
}

// =========================================================================
// DB: FILD/FISTTP/FIST/FISTP (i32 mem) / FLD/FSTP (f80) or FCMOVcc/FCOMI/FUCOMI
// =========================================================================

val dispatch_x87_db : (byte, RM, Prefixes) -> ExecutionResult
function dispatch_x87_db(modrm, rm, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match rm {
    RM_mem(addr) => {
      match reg {
        0 => { x87_push(__f80_from_int32(mem_read32(addr))); Ok() },
        1 => { mem_write32(addr, __f80_to_int32_trunc(x87_pop())); Ok() },
        2 => { mem_write32(addr, __f80_to_int32(x87_read_st(0))); Ok() },
        3 => { mem_write32(addr, __f80_to_int32(x87_pop())); Ok() },
        5 => { x87_push(mem_read_fp80(addr)); Ok() },
        7 => { mem_write_fp80(addr, x87_pop()); Ok() },
        _ => raise_UD(),
      }
    },
    RM_reg(_) => {
      let modrm_val : range(0, 255) = unsigned(modrm);
      match reg {
        0 => { if CF == bitzero then x87_write_st(0, x87_read_st(sti)); Ok() },
        1 => { if ZF == bitzero then x87_write_st(0, x87_read_st(sti)); Ok() },
        2 => { if CF == bitzero & ZF == bitzero then x87_write_st(0, x87_read_st(sti)); Ok() },
        3 => { if PF == bitzero then x87_write_st(0, x87_read_st(sti)); Ok() },
        4 => {
          if modrm_val == 226 then {
            // FNCLEX — clear exception flags
            var sw : word = x87_sw;
            sw[7 .. 0] = 0x00;
            sw[15] = bitzero;
            x87_sw = sw;
            Ok()
          } else if modrm_val == 227 then {
            // FNINIT
            x87_init();
            Ok()
          } else raise_UD()
        },
        5 => { x87_set_rflags_cc(__f80_compare(x87_read_st(0), x87_read_st(sti))); Ok() },
        6 => { x87_set_rflags_cc(__f80_compare(x87_read_st(0), x87_read_st(sti))); Ok() },
        _ => raise_UD(),
      }
    },
  }
}

// =========================================================================
// DC: FADD/FMUL/FCOM/FCOMP/FSUB/FSUBR/FDIV/FDIVR (f64 mem or ST(i),ST(0))
// =========================================================================

val dispatch_x87_dc : (byte, RM, Prefixes) -> ExecutionResult
function dispatch_x87_dc(modrm, rm, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match rm {
    RM_mem(addr) => {
      let src : fp80 = __f80_from_f64(mem_read64(addr));
      let st0 : fp80 = x87_read_st(0);
      match reg {
        0 => { x87_write_st(0, __f80_add(st0, src)); Ok() },
        1 => { x87_write_st(0, __f80_mul(st0, src)); Ok() },
        2 => { x87_set_sw_cc(__f80_compare(st0, x87_read_st(sti))); Ok() },
        3 => { x87_set_sw_cc(__f80_compare(st0, x87_read_st(sti))); let _ = x87_pop(); Ok() },
        4 => { x87_write_st(0, __f80_sub(st0, src)); Ok() },
        5 => { x87_write_st(0, __f80_sub(src, st0)); Ok() },
        6 => { x87_write_st(0, __f80_div(st0, src)); Ok() },
        7 => { x87_write_st(0, __f80_div(src, st0)); Ok() },
      }
    },
    RM_reg(_) => {
      // Note: SUB/SUBR and DIV/DIVR are swapped vs D8
      match reg {
        0 => { x87_write_st(sti, __f80_add(x87_read_st(sti), x87_read_st(0))); Ok() },
        1 => { x87_write_st(sti, __f80_mul(x87_read_st(sti), x87_read_st(0))); Ok() },
        4 => { x87_write_st(sti, __f80_sub(x87_read_st(0), x87_read_st(sti))); Ok() },
        5 => { x87_write_st(sti, __f80_sub(x87_read_st(sti), x87_read_st(0))); Ok() },
        6 => { x87_write_st(sti, __f80_div(x87_read_st(0), x87_read_st(sti))); Ok() },
        7 => { x87_write_st(sti, __f80_div(x87_read_st(sti), x87_read_st(0))); Ok() },
        _ => raise_UD(),
      }
    },
  }
}

// =========================================================================
// DD: FLD/FISTTP/FST/FSTP (f64 mem) / FRSTOR/FNSAVE/FNSTSW or FFREE/FUCOM/FUCOMP
// =========================================================================

val dispatch_x87_dd : (byte, RM, Prefixes) -> ExecutionResult
function dispatch_x87_dd(modrm, rm, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match rm {
    RM_mem(addr) => {
      match reg {
        0 => { x87_push(__f80_from_f64(mem_read64(addr))); Ok() },
        1 => { mem_write64(addr, __f80_to_int64_trunc(x87_pop())); Ok() },
        2 => { mem_write64(addr, __f80_to_f64(x87_read_st(0))); Ok() },
        3 => { mem_write64(addr, __f80_to_f64(x87_pop())); Ok() },
        4 => { x87_load_state(mem_read_864(addr)); Ok() },
        6 => {
          // FNSAVE — save state, then reinitialize
          let state = x87_save_state();
          x87_init();
          mem_write_864(addr, state);
          Ok()
        },
        7 => { mem_write16(addr, x87_sw); Ok() },
        _ => raise_UD(),
      }
    },
    RM_reg(_) => {
      match reg {
        0 => { x87_free(sti); Ok() },
        2 => { x87_write_st(sti, x87_read_st(0)); Ok() },
        3 => { let v = x87_pop(); x87_write_st(sti, v); Ok() },
        4 => { x87_set_sw_cc(__f80_compare(x87_read_st(0), x87_read_st(sti))); Ok() },
        5 => {
          x87_set_sw_cc(__f80_compare(x87_read_st(0), x87_read_st(sti)));
          let _ = x87_pop();
          Ok()
        },
        _ => raise_UD(),
      }
    },
  }
}

// =========================================================================
// DE: FIADD/FIMUL/FICOM/FICOMP/FISUB/FISUBR/FIDIV/FIDIVR (i16 mem) or FADDP/etc
// =========================================================================

val dispatch_x87_de : (byte, RM, Prefixes) -> ExecutionResult
function dispatch_x87_de(modrm, rm, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match rm {
    RM_mem(addr) => {
      let src : fp80 = __f80_from_int16(mem_read16(addr));
      let st0 : fp80 = x87_read_st(0);
      match reg {
        0 => { x87_write_st(0, __f80_add(st0, src)); Ok() },
        1 => { x87_write_st(0, __f80_mul(st0, src)); Ok() },
        2 => { x87_set_sw_cc(__f80_compare(st0, src)); Ok() },
        3 => { x87_set_sw_cc(__f80_compare(st0, src)); let _ = x87_pop(); Ok() },
        4 => { x87_write_st(0, __f80_sub(st0, src)); Ok() },
        5 => { x87_write_st(0, __f80_sub(src, st0)); Ok() },
        6 => { x87_write_st(0, __f80_div(st0, src)); Ok() },
        7 => { x87_write_st(0, __f80_div(src, st0)); Ok() },
      }
    },
    RM_reg(_) => {
      let modrm_val : range(0, 255) = unsigned(modrm);
      // Note: SUB/SUBR and DIV/DIVR swapped vs DA
      match reg {
        0 => {
          let result = __f80_add(x87_read_st(sti), x87_read_st(0));
          let _ = x87_pop();
          x87_write_st(sti - 1, result);
          Ok()
        },
        1 => {
          let result = __f80_mul(x87_read_st(sti), x87_read_st(0));
          let _ = x87_pop();
          x87_write_st(sti - 1, result);
          Ok()
        },
        2 => {
          // FCOMPP
          if modrm_val == 217 then {
            x87_set_sw_cc(__f80_compare(x87_read_st(0), x87_read_st(1)));
            let _ = x87_pop();
            let _ = x87_pop();
            Ok()
          } else raise_UD()
        },
        4 => {
          // FSUBRP — ST(i) = ST(0) - ST(i), pop
          let result = __f80_sub(x87_read_st(0), x87_read_st(sti));
          let _ = x87_pop();
          x87_write_st(sti - 1, result);
          Ok()
        },
        5 => {
          // FSUBP — ST(i) = ST(i) - ST(0), pop
          let result = __f80_sub(x87_read_st(sti), x87_read_st(0));
          let _ = x87_pop();
          x87_write_st(sti - 1, result);
          Ok()
        },
        6 => {
          // FDIVRP — ST(i) = ST(0) / ST(i), pop
          let result = __f80_div(x87_read_st(0), x87_read_st(sti));
          let _ = x87_pop();
          x87_write_st(sti - 1, result);
          Ok()
        },
        7 => {
          // FDIVP — ST(i) = ST(i) / ST(0), pop
          let result = __f80_div(x87_read_st(sti), x87_read_st(0));
          let _ = x87_pop();
          x87_write_st(sti - 1, result);
          Ok()
        },
        _ => raise_UD(),
      }
    },
  }
}

// =========================================================================
// DF: FILD/FISTTP/FIST/FISTP (i16/i64 mem) / FBLD/FBSTP or FNSTSW AX/FUCOMIP/FCOMIP
// =========================================================================

val dispatch_x87_df : (byte, RM, Prefixes) -> ExecutionResult
function dispatch_x87_df(modrm, rm, _) = {
  let reg : range(0, 7) = unsigned(modrm[5..3]);
  let sti : int = unsigned(modrm[2..0]);
  match rm {
    RM_mem(addr) => {
      match reg {
        0 => { x87_push(__f80_from_int16(mem_read16(addr))); Ok() },
        1 => { mem_write16(addr, __f80_to_int16_trunc(x87_pop())); Ok() },
        2 => { mem_write16(addr, __f80_to_int16(x87_read_st(0))); Ok() },
        3 => { mem_write16(addr, __f80_to_int16(x87_pop())); Ok() },
        4 => { x87_push(__f80_from_bcd(mem_read_fp80(addr))); Ok() },
        5 => { x87_push(__f80_from_int64(mem_read64(addr))); Ok() },
        6 => { mem_write_fp80(addr, __f80_to_bcd(x87_pop())); Ok() },
        7 => { mem_write64(addr, __f80_to_int64(x87_pop())); Ok() },
        _ => raise_UD(),
      }
    },
    RM_reg(_) => {
      let modrm_val : range(0, 255) = unsigned(modrm);
      match reg {
        4 => {
          // FNSTSW AX
          if modrm_val == 224 then {
            write_gpr16(RAX, x87_sw);
            Ok()
          } else raise_UD()
        },
        5 => {
          // FUCOMIP — unordered compare, set RFLAGS, pop
          x87_set_rflags_cc(__f80_compare(x87_read_st(0), x87_read_st(sti)));
          let _ = x87_pop();
          Ok()
        },
        6 => {
          // FCOMIP — compare, set RFLAGS, pop
          x87_set_rflags_cc(__f80_compare(x87_read_st(0), x87_read_st(sti)));
          let _ = x87_pop();
          Ok()
        },
        _ => raise_UD(),
      }
    },
  }
}

// =========================================================================
// Main x87 dispatcher: takes the opcode byte (D8-DF)
// =========================================================================

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
