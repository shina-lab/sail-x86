// x86-64 VEX — FMA Instructions (0F38 map)
//
// FMA3 fused multiply-add/sub instructions (0F38 96..BF).
// All require 66 mandatory prefix.
// W=0 selects PS/SS variants, W=1 selects PD/SD variants.
// L=0 for 128-bit (or scalar), L=1 for 256-bit.
//
// Operand mapping (avx_fmadd(a,b,c) computes a*b+c):
//   132: a=dst, b=rm,  c=vvvv
//   213: a=vvvv, b=dst, c=rm
//   231: a=vvvv, b=rm,  c=dst

val dispatch_vex_0f38_fma : (range(0, 255), Prefixes) -> unit
function dispatch_vex_0f38_fma(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {

  // -----------------------------------------------------------------------
  // VEX FMA3 instructions (0F38 96..BF)
  //
  // All require 66 mandatory prefix.
  // W=0 selects PS/SS variants, W=1 selects PD/SD variants.
  // L=0 for 128-bit (or scalar), L=1 for 256-bit.
  //
  // Operand mapping (avx_fmadd(a,b,c) computes a*b+c):
  //   132: a=dst, b=rm,  c=vvvv
  //   213: a=vvvv, b=dst, c=rm
  //   231: a=vvvv, b=rm,  c=dst
  // -----------------------------------------------------------------------

  // 0F38 96: VFMADDSUB132PS (W0) / VFMADDSUB132PD (W1)
  150 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_w then {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmaddsub_pd_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v)))
      } else {
        write_xmm(dst, avx_fmaddsub_pd_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v)))
      }
    } else {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmaddsub_ps_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v)))
      } else {
        write_xmm(dst, avx_fmaddsub_ps_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v)))
      }
    }
  },

  // 0F38 97: VFMSUBADD132PS (W0) / VFMSUBADD132PD (W1)
  151 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_w then {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmsubadd_pd_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v)))
      } else {
        write_xmm(dst, avx_fmsubadd_pd_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v)))
      }
    } else {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmsubadd_ps_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v)))
      } else {
        write_xmm(dst, avx_fmsubadd_ps_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v)))
      }
    }
  },

  // 0F38 98: VFMADD132PS (W0) / VFMADD132PD (W1)
  152 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_w then {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmadd_pd_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v)))
      } else {
        write_xmm(dst, avx_fmadd_pd_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v)))
      }
    } else {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmadd_ps_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v)))
      } else {
        write_xmm(dst, avx_fmadd_ps_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v)))
      }
    }
  },

  // 0F38 99: VFMADD132SS (W0) / VFMADD132SD (W1)
  153 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src2 = read_xmm(pfx.vex_vvvv);
    let src3 = decode_vex_src_xmm(modrm, rm, pfx);
    if pfx.vex_w then {
      exec_vfmadd132sd(dst, src2, src3)
    } else {
      exec_vfmadd132ss(dst, src2, src3)
    }
  },

  // 0F38 9A: VFMSUB132PS (W0) / VFMSUB132PD (W1)
  154 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_w then {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmsub_pd_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v)))
      } else {
        write_xmm(dst, avx_fmsub_pd_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v)))
      }
    } else {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmsub_ps_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v)))
      } else {
        write_xmm(dst, avx_fmsub_ps_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v)))
      }
    }
  },

  // 0F38 9B: VFMSUB132SS (W0) / VFMSUB132SD (W1)
  155 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src2 = read_xmm(pfx.vex_vvvv);
    let src3 = decode_vex_src_xmm(modrm, rm, pfx);
    if pfx.vex_w then {
      exec_vfmsub132sd(dst, src2, src3)
    } else {
      exec_vfmsub132ss(dst, src2, src3)
    }
  },

  // 0F38 9C: VFNMADD132PS (W0) / VFNMADD132PD (W1)
  156 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_w then {
      if pfx.vex_l then {
        write_ymm(dst, avx_fnmadd_pd_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v)))
      } else {
        write_xmm(dst, avx_fnmadd_pd_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v)))
      }
    } else {
      if pfx.vex_l then {
        write_ymm(dst, avx_fnmadd_ps_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v)))
      } else {
        write_xmm(dst, avx_fnmadd_ps_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v)))
      }
    }
  },

  // 0F38 9D: VFNMADD132SS (W0) / VFNMADD132SD (W1)
  157 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src2 = read_xmm(pfx.vex_vvvv);
    let src3 = decode_vex_src_xmm(modrm, rm, pfx);
    if pfx.vex_w then {
      exec_vfnmadd132sd(dst, src2, src3)
    } else {
      exec_vfnmadd132ss(dst, src2, src3)
    }
  },

  // 0F38 9E: VFNMSUB132PS (W0) / VFNMSUB132PD (W1)
  158 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_w then {
      if pfx.vex_l then {
        write_ymm(dst, avx_fnmsub_pd_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v)))
      } else {
        write_xmm(dst, avx_fnmsub_pd_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v)))
      }
    } else {
      if pfx.vex_l then {
        write_ymm(dst, avx_fnmsub_ps_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v)))
      } else {
        write_xmm(dst, avx_fnmsub_ps_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v)))
      }
    }
  },

  // 0F38 9F: VFNMSUB132SS (W0) / VFNMSUB132SD (W1)
  159 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src2 = read_xmm(pfx.vex_vvvv);
    let src3 = decode_vex_src_xmm(modrm, rm, pfx);
    if pfx.vex_w then {
      exec_vfnmsub132sd(dst, src2, src3)
    } else {
      exec_vfnmsub132ss(dst, src2, src3)
    }
  },

  // 0F38 A6: VFMADDSUB213PS (W0) / VFMADDSUB213PD (W1)
  166 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_w then {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmaddsub_pd_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx)))
      } else {
        write_xmm(dst, avx_fmaddsub_pd_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx)))
      }
    } else {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmaddsub_ps_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx)))
      } else {
        write_xmm(dst, avx_fmaddsub_ps_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx)))
      }
    }
  },

  // 0F38 A7: VFMSUBADD213PS (W0) / VFMSUBADD213PD (W1)
  167 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_w then {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmsubadd_pd_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx)))
      } else {
        write_xmm(dst, avx_fmsubadd_pd_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx)))
      }
    } else {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmsubadd_ps_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx)))
      } else {
        write_xmm(dst, avx_fmsubadd_ps_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx)))
      }
    }
  },

  // 0F38 A8: VFMADD213PS (W0) / VFMADD213PD (W1)
  168 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_w then {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmadd_pd_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx)))
      } else {
        write_xmm(dst, avx_fmadd_pd_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx)))
      }
    } else {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmadd_ps_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx)))
      } else {
        write_xmm(dst, avx_fmadd_ps_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx)))
      }
    }
  },

  // 0F38 A9: VFMADD213SS (W0) / VFMADD213SD (W1)
  169 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src2 = read_xmm(pfx.vex_vvvv);
    let src3 = decode_vex_src_xmm(modrm, rm, pfx);
    if pfx.vex_w then {
      exec_vfmadd213sd(dst, src2, src3)
    } else {
      exec_vfmadd213ss(dst, src2, src3)
    }
  },

  // 0F38 AA: VFMSUB213PS (W0) / VFMSUB213PD (W1)
  170 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_w then {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmsub_pd_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx)))
      } else {
        write_xmm(dst, avx_fmsub_pd_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx)))
      }
    } else {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmsub_ps_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx)))
      } else {
        write_xmm(dst, avx_fmsub_ps_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx)))
      }
    }
  },

  // 0F38 AB: VFMSUB213SS (W0) / VFMSUB213SD (W1)
  171 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src2 = read_xmm(pfx.vex_vvvv);
    let src3 = decode_vex_src_xmm(modrm, rm, pfx);
    if pfx.vex_w then {
      exec_vfmsub213sd(dst, src2, src3)
    } else {
      exec_vfmsub213ss(dst, src2, src3)
    }
  },

  // 0F38 AC: VFNMADD213PS (W0) / VFNMADD213PD (W1)
  172 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_w then {
      if pfx.vex_l then {
        write_ymm(dst, avx_fnmadd_pd_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx)))
      } else {
        write_xmm(dst, avx_fnmadd_pd_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx)))
      }
    } else {
      if pfx.vex_l then {
        write_ymm(dst, avx_fnmadd_ps_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx)))
      } else {
        write_xmm(dst, avx_fnmadd_ps_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx)))
      }
    }
  },

  // 0F38 AD: VFNMADD213SS (W0) / VFNMADD213SD (W1)
  173 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src2 = read_xmm(pfx.vex_vvvv);
    let src3 = decode_vex_src_xmm(modrm, rm, pfx);
    if pfx.vex_w then {
      exec_vfnmadd213sd(dst, src2, src3)
    } else {
      exec_vfnmadd213ss(dst, src2, src3)
    }
  },

  // 0F38 AE: VFNMSUB213PS (W0) / VFNMSUB213PD (W1)
  174 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_w then {
      if pfx.vex_l then {
        write_ymm(dst, avx_fnmsub_pd_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx)))
      } else {
        write_xmm(dst, avx_fnmsub_pd_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx)))
      }
    } else {
      if pfx.vex_l then {
        write_ymm(dst, avx_fnmsub_ps_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx)))
      } else {
        write_xmm(dst, avx_fnmsub_ps_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx)))
      }
    }
  },

  // 0F38 AF: VFNMSUB213SS (W0) / VFNMSUB213SD (W1)
  175 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src2 = read_xmm(pfx.vex_vvvv);
    let src3 = decode_vex_src_xmm(modrm, rm, pfx);
    if pfx.vex_w then {
      exec_vfnmsub213sd(dst, src2, src3)
    } else {
      exec_vfnmsub213ss(dst, src2, src3)
    }
  },

  // 0F38 B6: VFMADDSUB231PS (W0) / VFMADDSUB231PD (W1)
  182 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_w then {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmaddsub_pd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst)))
      } else {
        write_xmm(dst, avx_fmaddsub_pd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst)))
      }
    } else {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmaddsub_ps_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst)))
      } else {
        write_xmm(dst, avx_fmaddsub_ps_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst)))
      }
    }
  },

  // 0F38 B7: VFMSUBADD231PS (W0) / VFMSUBADD231PD (W1)
  183 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_w then {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmsubadd_pd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst)))
      } else {
        write_xmm(dst, avx_fmsubadd_pd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst)))
      }
    } else {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmsubadd_ps_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst)))
      } else {
        write_xmm(dst, avx_fmsubadd_ps_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst)))
      }
    }
  },

  // 0F38 B8: VFMADD231PS (W0) / VFMADD231PD (W1)
  184 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_w then {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmadd_pd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst)))
      } else {
        write_xmm(dst, avx_fmadd_pd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst)))
      }
    } else {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmadd_ps_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst)))
      } else {
        write_xmm(dst, avx_fmadd_ps_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst)))
      }
    }
  },

  // 0F38 B9: VFMADD231SS (W0) / VFMADD231SD (W1)
  185 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src2 = read_xmm(pfx.vex_vvvv);
    let src3 = decode_vex_src_xmm(modrm, rm, pfx);
    if pfx.vex_w then {
      exec_vfmadd231sd(dst, src2, src3)
    } else {
      exec_vfmadd231ss(dst, src2, src3)
    }
  },

  // 0F38 BA: VFMSUB231PS (W0) / VFMSUB231PD (W1)
  186 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_w then {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmsub_pd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst)))
      } else {
        write_xmm(dst, avx_fmsub_pd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst)))
      }
    } else {
      if pfx.vex_l then {
        write_ymm(dst, avx_fmsub_ps_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst)))
      } else {
        write_xmm(dst, avx_fmsub_ps_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst)))
      }
    }
  },

  // 0F38 BB: VFMSUB231SS (W0) / VFMSUB231SD (W1)
  187 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src2 = read_xmm(pfx.vex_vvvv);
    let src3 = decode_vex_src_xmm(modrm, rm, pfx);
    if pfx.vex_w then {
      exec_vfmsub231sd(dst, src2, src3)
    } else {
      exec_vfmsub231ss(dst, src2, src3)
    }
  },

  // 0F38 BC: VFNMADD231PS (W0) / VFNMADD231PD (W1)
  188 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_w then {
      if pfx.vex_l then {
        write_ymm(dst, avx_fnmadd_pd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst)))
      } else {
        write_xmm(dst, avx_fnmadd_pd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst)))
      }
    } else {
      if pfx.vex_l then {
        write_ymm(dst, avx_fnmadd_ps_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst)))
      } else {
        write_xmm(dst, avx_fnmadd_ps_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst)))
      }
    }
  },

  // 0F38 BD: VFNMADD231SS (W0) / VFNMADD231SD (W1)
  189 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src2 = read_xmm(pfx.vex_vvvv);
    let src3 = decode_vex_src_xmm(modrm, rm, pfx);
    if pfx.vex_w then {
      exec_vfnmadd231sd(dst, src2, src3)
    } else {
      exec_vfnmadd231ss(dst, src2, src3)
    }
  },

  // 0F38 BE: VFNMSUB231PS (W0) / VFNMSUB231PD (W1)
  190 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let v = pfx.vex_vvvv;
    if pfx.vex_w then {
      if pfx.vex_l then {
        write_ymm(dst, avx_fnmsub_pd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst)))
      } else {
        write_xmm(dst, avx_fnmsub_pd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst)))
      }
    } else {
      if pfx.vex_l then {
        write_ymm(dst, avx_fnmsub_ps_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst)))
      } else {
        write_xmm(dst, avx_fnmsub_ps_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst)))
      }
    }
  },

  // 0F38 BF: VFNMSUB231SS (W0) / VFNMSUB231SD (W1)
  191 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src2 = read_xmm(pfx.vex_vvvv);
    let src3 = decode_vex_src_xmm(modrm, rm, pfx);
    if pfx.vex_w then {
      exec_vfnmsub231sd(dst, src2, src3)
    } else {
      exec_vfnmsub231ss(dst, src2, src3)
    }
  },

  _ => raise_UD(),
  }
}
