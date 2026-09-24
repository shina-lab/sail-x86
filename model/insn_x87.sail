// x86-64 — x87 FPU (opcodes D8-DF)
//
// Each x87 opcode consumes a ModR/M byte. When mod != 11 (memory),
// the reg field selects the operation. When mod == 11 (register),
// the full ModR/M byte selects from a large table.

// =========================================================================
// Status word condition code helpers
// =========================================================================

// Leave the specified condition codes unconstrained without changing TOP,
// exception flags, or the condition codes defined by the instruction.
val x87_undefine_cc : word -> unit
function x87_undefine_cc(mask) =
  x87_sw = (x87_sw & ~(mask)) | ((undefined : word) & mask)

// SDM Vol.1 Table 8-1 and the individual Vol.2 instruction entries.
// Apply after successful execution: stores must save the incoming condition
// codes, and a fault must not change them. FCOMI/FUCOMI preserve C0/C2/C3
// according to their instruction entries, despite the older Vol.1 table.
val x87_finish_cc : (byte, byte) -> unit
function x87_finish_cc(opcode, modrm) = {
  let reg = unsigned(modrm[5..3]);
  let mem = modrm[7..6] != 0b11;
  let mask : word = match unsigned(opcode) {
    // Arithmetic has undefined C0/C2/C3; comparisons define them.
    op if op == 216 | op == 220 | op == 222 =>
      if reg == 2 | reg == 3 then 0x0000 else 0x4500,
    217 => if mem then match reg {
      4 => 0x0000,                 // FLDENV loads all condition codes
      n if n >= 5 => 0x4700,      // FLDCW, FNSTENV, FNSTCW
      _ => 0x4500,                // FLD, FST, FSTP
    } else match unsigned(modrm) {
      208 => 0x4700,              // FNOP
      n if n == 228 | n == 229 => 0x0000, // FTST, FXAM
      n if n == 245 | n == 248 => 0x0000, // FPREM1, FPREM
      n if n == 242 | n == 251 | n == 254 | n == 255 => 0x4100, // trig
      _ => 0x4500,
    },
    218 => if mem then {
      if reg == 2 | reg == 3 then 0x0000 else 0x4500
    } else {
      if reg <= 3 then 0x4500 else 0x0000 // FCMOVcc versus FUCOMPP
    },
    219 => if mem | reg <= 3 then 0x4500
           else if modrm == 0xE2 then 0x4700 // FNCLEX
           else 0x0000,                    // FNINIT, FCOMI, FUCOMI
    221 => if mem then match reg {
      n if n == 4 | n == 6 => 0x0000, // FRSTOR, FNSAVE
      7 => 0x4700,                // FNSTSW
      _ => 0x4500,
    } else match reg {
      0 => 0x4700,                // FFREE
      n if n == 4 | n == 5 => 0x0000, // FUCOM, FUCOMP
      _ => 0x4500,                // FST, FSTP
    },
    223 => if mem then 0x4500
           else if reg == 0 | modrm == 0xE0 then 0x4700 // FFREEP, FNSTSW AX
           else 0x0000,                    // FCOMIP, FUCOMIP
    _ => 0x0000,
  };
  x87_undefine_cc(mask);
  // Register exchanges and stores do not round; their defined C1 is zero.
  // The compatibility encodings are normalized before reaching this code.
  if ~(mem) & ((opcode == 0xD9 & (reg == 1 | reg == 3)) |
               (opcode == 0xDD & (reg == 2 | reg == 3))) then {
    x87_sw[9] = 0b0
  };
  if opcode == 0xD9 & ~(mem) then {
    match unsigned(modrm) {
      // Outside the trigonometric input range, C1 is undefined as well.
      n if n == 242 | n == 251 | n == 254 | n == 255 =>
        x87_undefine_cc(0x0200 & sign_extend(16, x87_sw[10])),
      _ => (),
    }
  }
}

// Set x87 status word condition codes C3(14), C2(10), C0(8) from comparison
val x87_set_sw_cc : FPCompareResult -> unit
function x87_set_sw_cc(cmp) = {
  var sw : word = x87_sw;
  sw[9] = 0b0; // C1 is cleared by comparisons
  match cmp {
    FP_GT        => { sw[14] = 0b0; sw[10] = 0b0; sw[8] = 0b0; },
    FP_LT        => { sw[14] = 0b0; sw[10] = 0b0; sw[8] = 0b1;  },
    FP_EQ        => { sw[14] = 0b1; sw[10] = 0b0; sw[8] = 0b0; },
    FP_UNORDERED => { sw[14] = 0b1; sw[10] = 0b1; sw[8] = 0b1;  },
  };
  x87_sw = sw
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
      let src : fp80 = __f80_from_f32(v(m));
      let st0 : fp80 = x87_read_st(0);
      match reg {
        0 => x87_write_st(0, fp_add(st0, src)),
        1 => x87_write_st(0, fp_mul(st0, src)),
        2 => x87_set_sw_cc(fp_compare(st0, src)),
        3 => { x87_set_sw_cc(fp_compare(st0, src)); let _ = x87_pop() },
        4 => x87_write_st(0, fp_sub(st0, src)),
        5 => x87_write_st(0, fp_sub(src, st0)),
        6 => x87_write_st(0, fp_div(st0, src)),
        7 => x87_write_st(0, fp_div(src, st0)),
      }
    },
    RM_reg(_) => {
      match reg {
        0 => x87_write_st(0, fp_add(x87_read_st(0), x87_read_st(sti))),
        1 => x87_write_st(0, fp_mul(x87_read_st(0), x87_read_st(sti))),
        2 => x87_set_sw_cc(fp_compare(x87_read_st(0), x87_read_st(sti))),
        3 => {
          x87_set_sw_cc(fp_compare(x87_read_st(0), x87_read_st(sti)));
          let _ = x87_pop()
        },
        4 => x87_write_st(0, fp_sub(x87_read_st(0), x87_read_st(sti))),
        5 => x87_write_st(0, fp_sub(x87_read_st(sti), x87_read_st(0))),
        6 => x87_write_st(0, fp_div(x87_read_st(0), x87_read_st(sti))),
        7 => x87_write_st(0, fp_div(x87_read_st(sti), x87_read_st(0))),
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
        0 => x87_push(__f80_from_f32(v(m))),
        1 => raise_UD(),
        2 => v(m) = __f80_to_f32(x87_read_st(0)),
        3 => { v(m) = __f80_to_f32(x87_read_st(0)); let _ = x87_pop() },
        4 => x87_load_env(read_mem(m)),
        5 => x87_cw = v(m),
        // FNSTENV stores the environment, then masks all exceptions
        6 => {
          write_mem(m, x87_save_env());
          x87_cw[5..0] = 0b111111
        },
        7 => v(m) = x87_cw,
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
        // D9 D8+i: FSTP without a stack-underflow exception (SDM Vol.3B,
        // "Obsolete Instructions and Undefined Opcodes"). An empty ST(0)
        // skips the store, preserving the destination's value and tag;
        // the pop still happens. Unlike FSTP, it never substitutes a NaN.
        3 => {
          let tag : bits(2) = (x87_tw >> (2 * x87_physical(0)))[1..0];
          if tag != 0b11 then x87_write_st(sti, x87_read_st(0));
          let _ = x87_pop()
        },
        _ => {
          // D9 E0-FF: misc operations encoded by full ModR/M
          match modrm_val {
            // FCHS
            224 => x87_write_st(0, __f80_chs(x87_read_st(0))),
            // FABS
            225 => x87_write_st(0, __f80_abs(x87_read_st(0))),
            // FTST
            228 => x87_set_sw_cc(fp_compare(x87_read_st(0), __f80_zero())),
            // FXAM — examine ST(0), set C3/C2/C0 for class, C1 for sign.
            // Empty is the register's tag, not a property of its contents;
            // C1 is the sign bit whether the register is empty or full.
            229 => {
              let val80 : fp80 = x87_read_st(0);
              var sw : word = x87_sw;
              sw[9] = val80[79];  // C1 = sign bit
              let tag : bits(2) = (x87_tw >> (2 * x87_physical(0)))[1..0];
              if tag == 0b11 then {
                sw[14] = 0b1; sw[10] = 0b0; sw[8] = 0b1
              } else {
                match __f80_classify(val80) {
                  FP_Unsupported => { sw[14] = 0b0; sw[10] = 0b0; sw[8] = 0b0; },
                  FP_NaN         => { sw[14] = 0b0; sw[10] = 0b0; sw[8] = 0b1;  },
                  FP_Normal      => { sw[14] = 0b0; sw[10] = 0b1; sw[8] = 0b0; },
                  FP_Infinity    => { sw[14] = 0b0; sw[10] = 0b1; sw[8] = 0b1;  },
                  FP_Zero        => { sw[14] = 0b1; sw[10] = 0b0; sw[8] = 0b0; },
                  FP_Empty       => { sw[14] = 0b1; sw[10] = 0b0; sw[8] = 0b1;  },
                  FP_Denormal    => { sw[14] = 0b1; sw[10] = 0b1; sw[8] = 0b0; },
                }
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
            250 => x87_write_st(0, fp_sqrt(x87_read_st(0))),
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
      let src : fp80 = __f80_from_int32(v(m));
      let st0 : fp80 = x87_read_st(0);
      match reg {
        0 => x87_write_st(0, fp_add(st0, src)),
        1 => x87_write_st(0, fp_mul(st0, src)),
        2 => x87_set_sw_cc(fp_compare(st0, src)),
        3 => { x87_set_sw_cc(fp_compare(st0, src)); let _ = x87_pop() },
        4 => x87_write_st(0, fp_sub(st0, src)),
        5 => x87_write_st(0, fp_sub(src, st0)),
        6 => x87_write_st(0, fp_div(st0, src)),
        7 => x87_write_st(0, fp_div(src, st0)),
      }
    },
    RM_reg(_) => {
      match reg {
        0 => x87_write_st(0, blend(x87_read_st(0), x87_read_st(sti), CF)),
        1 => x87_write_st(0, blend(x87_read_st(0), x87_read_st(sti), ZF)),
        2 => x87_write_st(0, blend(x87_read_st(0), x87_read_st(sti), CF | ZF)),
        3 => x87_write_st(0, blend(x87_read_st(0), x87_read_st(sti), PF)),
        // FUCOMPP
        5 => {
          if sti == 1 then {
            x87_set_sw_cc(fp_compare(x87_read_st(0), x87_read_st(1)));
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
        0 => x87_push(__f80_from_int32(v(m))),
        1 => { v(m) = __f80_to_int32_trunc(x87_read_st(0)); let _ = x87_pop() },
        2 => v(m) = __f80_to_int32(x87_read_st(0)),
        3 => { v(m) = __f80_to_int32(x87_read_st(0)); let _ = x87_pop() },
        4 => raise_UD(),
        5 => x87_push(read_mem(m)),
        6 => raise_UD(),
        7 => { let x = x87_read_st(0); write_mem(m, x); let _ = x87_pop() },
      }
    },
    RM_reg(_) => {
      let modrm_val : range(0, 255) = unsigned(modrm);
      match reg {
        0 => x87_write_st(0, blend(x87_read_st(0), x87_read_st(sti), ~(CF))),
        1 => x87_write_st(0, blend(x87_read_st(0), x87_read_st(sti), ~(ZF))),
        2 => x87_write_st(0, blend(x87_read_st(0), x87_read_st(sti), ~(CF) & ~(ZF))),
        3 => x87_write_st(0, blend(x87_read_st(0), x87_read_st(sti), ~(PF))),
        // Obsolete controls, FNCLEX and FNINIT
        4 => {
          // SDM Vol.3B, "Obsolete Instructions and Undefined Opcodes":
          // FENI, FDISI and FSETPM act as integer NOPs, preserving all
          // x87 state (including the condition codes and exception flags).
          if modrm_val == 224 | modrm_val == 225 | modrm_val == 228 then {
            ()
          } else if modrm_val == 226 then {
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
        5 => set_eflags_fp_compare(x87_read_st(0), x87_read_st(sti)),
        6 => set_eflags_fp_compare(x87_read_st(0), x87_read_st(sti)),
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
      let src : fp80 = __f80_from_f64(v(m));
      let st0 : fp80 = x87_read_st(0);
      match reg {
        0 => x87_write_st(0, fp_add(st0, src)),
        1 => x87_write_st(0, fp_mul(st0, src)),
        2 => x87_set_sw_cc(fp_compare(st0, src)),
        3 => { x87_set_sw_cc(fp_compare(st0, src)); let _ = x87_pop() },
        4 => x87_write_st(0, fp_sub(st0, src)),
        5 => x87_write_st(0, fp_sub(src, st0)),
        6 => x87_write_st(0, fp_div(st0, src)),
        7 => x87_write_st(0, fp_div(src, st0)),
      }
    },
    RM_reg(_) => {
      // Note: SUB/SUBR and DIV/DIVR are swapped vs D8
      match reg {
        0 => x87_write_st(sti, fp_add(x87_read_st(sti), x87_read_st(0))),
        1 => x87_write_st(sti, fp_mul(x87_read_st(sti), x87_read_st(0))),
        2 => raise_UD(),
        3 => raise_UD(),
        4 => x87_write_st(sti, fp_sub(x87_read_st(0), x87_read_st(sti))),
        5 => x87_write_st(sti, fp_sub(x87_read_st(sti), x87_read_st(0))),
        6 => x87_write_st(sti, fp_div(x87_read_st(0), x87_read_st(sti))),
        7 => x87_write_st(sti, fp_div(x87_read_st(sti), x87_read_st(0))),
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
        0 => x87_push(__f80_from_f64(v(m))),
        1 => { v(m) = __f80_to_int64_trunc(x87_read_st(0)); let _ = x87_pop() },
        2 => v(m) = __f80_to_f64(x87_read_st(0)),
        3 => { v(m) = __f80_to_f64(x87_read_st(0)); let _ = x87_pop() },
        4 => x87_load_state(read_mem(m)),
        5 => raise_UD(),
        // FNSAVE — save state, then reinitialize.
        // write_mem before x87_init so that x87 state is unchanged on fault.
        6 => {
          let state = x87_save_state();
          write_mem(m, state);
          x87_init()
        },
        7 => v(m) = x87_sw,
      }
    },
    RM_reg(_) => {
      match reg {
        0 => x87_free(sti),
        1 => raise_UD(),
        2 => x87_write_st(sti, x87_read_st(0)),
        3 => { x87_write_st(sti, x87_read_st(0)); let _ = x87_pop() },
        4 => x87_set_sw_cc(fp_compare(x87_read_st(0), x87_read_st(sti))),
        5 => {
          x87_set_sw_cc(fp_compare(x87_read_st(0), x87_read_st(sti)));
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
      let src : fp80 = __f80_from_int16(v(m));
      let st0 : fp80 = x87_read_st(0);
      match reg {
        0 => x87_write_st(0, fp_add(st0, src)),
        1 => x87_write_st(0, fp_mul(st0, src)),
        2 => x87_set_sw_cc(fp_compare(st0, src)),
        3 => { x87_set_sw_cc(fp_compare(st0, src)); let _ = x87_pop() },
        4 => x87_write_st(0, fp_sub(st0, src)),
        5 => x87_write_st(0, fp_sub(src, st0)),
        6 => x87_write_st(0, fp_div(st0, src)),
        7 => x87_write_st(0, fp_div(src, st0)),
      }
    },
    RM_reg(_) => {
      let modrm_val : range(0, 255) = unsigned(modrm);
      // Note: SUB/SUBR and DIV/DIVR swapped vs DA
      match reg {
        0 => {
          let result = fp_add(x87_read_st(sti), x87_read_st(0));
          let _ = x87_pop();
          x87_write_st(sti - 1, result)
        },
        1 => {
          let result = fp_mul(x87_read_st(sti), x87_read_st(0));
          let _ = x87_pop();
          x87_write_st(sti - 1, result)
        },
        2 => raise_UD(),
        // DE D9: FCOMPP — compare ST(0) with ST(1), pop twice; the other
        // DE D8+i encodings are reserved
        3 => {
          if modrm_val == 217 then {
            x87_set_sw_cc(fp_compare(x87_read_st(0), x87_read_st(1)));
            let _ = x87_pop();
            let _ = x87_pop()
          } else {
            raise_UD()
          }
        },
        // FSUBRP — ST(i) = ST(0) - ST(i), pop
        4 => {
          let result = fp_sub(x87_read_st(0), x87_read_st(sti));
          let _ = x87_pop();
          x87_write_st(sti - 1, result)
        },
        // FSUBP — ST(i) = ST(i) - ST(0), pop
        5 => {
          let result = fp_sub(x87_read_st(sti), x87_read_st(0));
          let _ = x87_pop();
          x87_write_st(sti - 1, result)
        },
        // FDIVRP — ST(i) = ST(0) / ST(i), pop
        6 => {
          let result = fp_div(x87_read_st(0), x87_read_st(sti));
          let _ = x87_pop();
          x87_write_st(sti - 1, result)
        },
        // FDIVP — ST(i) = ST(i) / ST(0), pop
        7 => {
          let result = fp_div(x87_read_st(sti), x87_read_st(0));
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
        0 => x87_push(__f80_from_int16(v(m))),
        1 => { v(m) = __f80_to_int16_trunc(x87_read_st(0)); let _ = x87_pop() },
        2 => v(m) = __f80_to_int16(x87_read_st(0)),
        3 => { v(m) = __f80_to_int16(x87_read_st(0)); let _ = x87_pop() },
        4 => x87_push(__f80_from_bcd(read_mem(m))),
        5 => x87_push(__f80_from_int64(v(m))),
        6 => { let x = __f80_to_bcd(x87_read_st(0)); write_mem(m, x); let _ = x87_pop() },
        7 => { v(m) = __f80_to_int64(x87_read_st(0)); let _ = x87_pop() },
      }
    },
    RM_reg(_) => {
      let modrm_val : range(0, 255) = unsigned(modrm);
      match reg {
        // DF C0+i: FFREEP, free the original ST(i), then pop ST(0).
        // Neither step consumes a floating-point operand or checks its tag.
        0 => { x87_free(sti); let _ = x87_pop() },
        // FNSTSW AX
        4 => {
          if modrm_val == 224 then {
            v(RAX) = x87_sw
          } else {
            raise_UD()
          }
        },
        // FUCOMIP — unordered compare, set RFLAGS, pop
        5 => {
          set_eflags_fp_compare(x87_read_st(0), x87_read_st(sti));
          let _ = x87_pop()
        },
        // FCOMIP — compare, set RFLAGS, pop
        6 => {
          set_eflags_fp_compare(x87_read_st(0), x87_read_st(sti));
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
function dispatch_x87(encoded_opcode, pfx) = {
  let encoded_modrm = fetch(1);
  // SDM Vol.3B, "Obsolete Instructions and Undefined Opcodes": these
  // seven register-form groups have the semantics of existing instructions.
  // Normalize both execution and condition-code handling to the canonical
  // encoding. Matching all five high ModR/M bits leaves memory forms and
  // adjacent invalid encodings unchanged. D9 D8+i and DF C0+i have distinct
  // semantics and are handled separately by their dispatchers.
  let (opcode, modrm) : (byte, byte) = match (encoded_opcode, encoded_modrm[7..3]) {
    (0xDC, 0b11010) => (0xD8, encoded_modrm),        // FCOM
    (0xDC, 0b11011) => (0xD8, encoded_modrm),        // FCOMP
    (0xDD, 0b11001) => (0xD9, encoded_modrm),        // FXCH
    (0xDE, 0b11010) => (0xD8, encoded_modrm | 0x08), // FCOMP
    (0xDF, 0b11010) => (0xDD, encoded_modrm | 0x08), // FSTP
    (0xDF, 0b11001) => (0xD9, encoded_modrm),        // FXCH
    (0xDF, 0b11011) => (0xDD, encoded_modrm),        // FSTP
    _ => (encoded_opcode, encoded_modrm),
  };
  let operand = modrm_rm(modrm, pfx);
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
  };
  x87_finish_cc(opcode, modrm)
}
