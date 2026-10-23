// =========================================================================
// XSAVE / XRSTOR / XSAVEC / XSAVEOPT / XSAVES / XRSTORS
//
// Save and restore extended processor state (x87, SSE, AVX, AVX-512).
// SDM Chapter 13.
// =========================================================================

// -------------------------------------------------------------------------
// XSAVE area layout (CPUID leaf 0xD), from the implementation's
// parameters xsave_comp_size, xsave_comp_offset and xsave_comp_align
// (regs.sail).
//
// Standard format: "Each state component i (i≥ 2) is located at the byte
// offset from the base address of the XSAVE area enumerated in
// CPUID.0DH.i:EBX" (SDM Vol.1 §13.4.3 p.13-9).  The size for a set of
// components is the end of the last one, at least 576 (the legacy region
// and the header).
//
// Compacted format (same page): the first component of XCOMP_BV is at 576;
// each other one i at "locationJ + sizeJ" after the preceding one j, or
// "ceiling(locationJ + sizeJ, 64)" where CPUID.0DH.i:ECX[1] = 1.
// -------------------------------------------------------------------------

// The #UD of the XSAVE feature set (SDM Vol.2D XSAVE, XSAVEOPT, XSAVEC,
// XSAVES, XRSTOR, XRSTORS, XSETBV; Vol.2B XGETBV): "If
// CPUID.01H:ECX.XSAVE[26] = 0", "If CR4.OSXSAVE[bit 18] = 0", and for an
// extension of CPUID.0DH.01H:EAX (ext; true for the base instructions)
// "If ... CPUID.0DH.01H:EAX.<bit> = 0".  The model raises it ahead of the
// #NM of CR0.TS; the two are in one class of Vol.3A Table 7-2, within
// which "the priority of events ... is implementation-dependent" (p.7-9).
val check_xsave_enabled : bool -> unit
function check_xsave_enabled(ext) =
  if ~(has_xsave) | ~(ext) | CR4[18] == bitzero then raise_UD()

val xsave_std_offset : range(0, 18) -> int
function xsave_std_offset(component) = unsigned(xsave_comp_offset[component])

val xsave_comp_bytes : range(0, 18) -> int
function xsave_comp_bytes(component) = unsigned(xsave_comp_size[component])

// The standard-format size for the components of mask.
val xsave_area_size_standard : qword -> dword
function xsave_area_size_standard(mask) = {
  var size : int = 576;
  foreach (i from 2 to 18) {
    let last : int = xsave_std_offset(i) + xsave_comp_bytes(i);
    if mask[i] == bitone & last > size then size = last
  };
  get_slice_int(32, size, 0)
}

// The offset in the compacted format of the component that follows
// `offset`, the end of the components before it: aligned to 64 bytes
// where CPUID.0DH.i:ECX[1] is set.
val xsave_compacted_place : (qword, range(0, 18)) -> qword
function xsave_compacted_place(offset, i) =
  if xsave_comp_align[i] then (offset + 63) & 0xFFFFFFFFFFFFFFC0 else offset

// The compacted-format size for the components of mask.
val xsave_area_size_compacted : qword -> dword
function xsave_area_size_compacted(mask) = {
  var offset : qword = to_bits(64, 576);
  foreach (i from 2 to 18) {
    if mask[i] == bitone then
      offset = xsave_compacted_place(offset, i) + xsave_comp_bytes(i)
  };
  offset[31..0]
}

// -------------------------------------------------------------------------
// FTW conversion: full 16-bit tag word <-> abridged 8-bit tag word
//
// Full: 2 bits per register (0=valid, 1=zero, 2=special, 3=empty)
// Abridged: 1 bit per register (0=empty, 1=valid/zero/special)
// -------------------------------------------------------------------------

val ftw_full_to_abridged : word -> byte
function ftw_full_to_abridged(tw) = {
  var result : byte = 0x00;
  foreach (i from 0 to 7) {
    if tw[2 * i + 1 .. 2 * i] != 0b11 then result[i] = bitone
  };
  result
}

val ftw_abridged_to_full : byte -> word
function ftw_abridged_to_full(ab) = {
  var tw : word = 0x0000;
  foreach (i from 0 to 7) {
    // A nonempty register is tagged valid (00); FNSTENV and FNSAVE
    // classify its contents (x87_tag_word).
    if ab[i] == bitzero then tw[2 * i + 1 .. 2 * i] = 0b11
  };
  tw
}

// -------------------------------------------------------------------------
// The legacy region, shared by FXSAVE/FXRSTOR and the x87 and SSE
// components of XSAVE/XRSTOR (SDM Vol.1 §10.5.1, Tables 10-2 and 10-3).
// With REX.W (FXSAVE64, XSAVE64, ...) the x87 instruction and data
// pointers are 64-bit offsets; otherwise each is a 32-bit offset and a
// selector.  Bytes 416-511 are neither written nor read.
// -------------------------------------------------------------------------

// The x87 component: FCW, FSW, the abridged FTW, FOP, FIP and FDP, and
// ST(0)-ST(7) in stack order, each in 16 bytes (SDM Vol.2A FXSAVE, Field
// Definitions p.3-413-3-414; APM Vol.2 §11.5.10, Figures 11-9 and 11-10
// p.362-363).  The reserved parts, for which the two manuals give no
// common value, are written undefined: FOP bits 15:11 ("upper 5 bits are
// reserved"), bytes 0Eh-0Fh and 16h-17h of the 32-bit format ("rsrvd, IGN"
// in the APM), the last 6 bytes of each register, and byte 5, "Rsvd" in the
// SDM and "(Byte 05h contains the value 00h.)" in the APM.  Two more rules
// are the SDM's alone, and the fields they reserve are undefined as well:
// after MMX code "the high 16 bits of the field are reserved" for each
// register, which the APM saves like any other, and in 16-bit mode the
// "high 16 bits are reserved" of FIP and FDP.
//
// The SDM saves FOP, FIP, FCS, FDP and FDS always (Vol.1 §8.1.8).  The APM
// saves them only while an x87 exception is pending (FSW.ES = 1): FXSAVE
// "does not save the x87 pointer registers" otherwise (Vol.5 FXSAVE p.26),
// nor does XSAVE "On processors where CPUID Fn8000_0008_EBX[2] is 0", and
// with RstrFpErrPtrs "the error pointer fields in the save area are zeroed
// if there is no pending #MF" (Vol.2 §11.5.10 p.361, Vol.4 XSAVE p.1774).
// With FSW.ES = 0 the fields are therefore undefined, but for those of an
// XSAVE with RstrFpErrPtrs (fx is FXSAVE).
val xsave_x87 : (qword, bool, bool) -> unit
function xsave_x87(base, w, fx) = {
  let pointers : bool = x87_sw[7] == bitone;
  let zeroed : bool = ~(pointers) & ~(fx) & has_rstr_fp_err_ptrs;
  let fop : bits(11) = if pointers then x87_fop else if zeroed then zeros() else undefined;
  let fip : qword = if pointers then x87_fip else if zeroed then zeros() else undefined;
  let fdp : qword = if pointers then x87_fdp else if zeroed then zeros() else undefined;
  let fcs : word = if pointers then x87_saved_selector(x87_fcs) else if zeroed then zeros() else undefined;
  let fds : word = if pointers then x87_saved_selector(x87_fds) else if zeroed then zeros() else undefined;
  let mode16 = cur_mode != LongMode & get_cs_db() == bitzero;
  let fip32 : dword = if mode16 then (undefined : word) @ fip[15..0] else fip[31..0];
  let fdp32 : dword = if mode16 then (undefined : word) @ fdp[15..0] else fdp[31..0];
  write_mem(base, x87_cw);
  write_mem(base + 2, x87_sw);
  write_mem(base + 4, ftw_full_to_abridged(x87_tw));
  write_mem(base + 5, undefined : byte);
  write_mem(base + 6, (undefined : bits(5)) @ fop);
  if w then {
    write_mem(base + 8, fip);
    write_mem(base + 16, fdp)
  } else {
    write_mem(base + 8, fip32);
    write_mem(base + 12, (undefined : word) @ fcs);
    write_mem(base + 16, fdp32);
    write_mem(base + 20, (undefined : word) @ fds)
  };
  foreach (i from 0 to 7) {
    let st : fp80 = x87_read_st(i);
    let high : word = if x87_mmx_last then undefined else st[79..64];
    write_mem(base + 32 + 16 * i, high @ st[63..0]);
    write_mem(48, base + 32 + 16 * i + 10, undefined)
  }
}

// The x87 component back from an image, for FXRSTOR (fx) or XRSTOR.
// The SDM loads FOP, FIP and FDP always, and FCS and FDS from the 32-bit
// format; the 64-bit format (REX.W) "clears FCS and FDS" (Vol.1 §8.1.8).
// The APM's FXRSTOR loads the pointers only "when FXRSTOR sets FSW.ES=1
// after recomputing it" (Vol.5 FXRSTOR p.24), and its XRSTOR as well "On
// processors where CPUID Fn8000_0008_EBX[2] is 0"; with RstrFpErrPtrs
// XRSTOR loads them always, "and if in 64-bit mode the CS and DS portions
// of the error pointer registers are zeroed" (Vol.2 §11.5.10 p.361).  So
// when the recomputed FSW.ES is 0 they are undefined after the load, but
// for those of an XRSTOR with RstrFpErrPtrs.
val xrstor_x87 : (qword, bool, bool) -> unit
function xrstor_x87(base, w, fx) = {
  x87_set_cw(read_mem(base));
  x87_set_sw(read_mem(base + 2));
  x87_tw = ftw_abridged_to_full(read_mem(base + 4));
  let rstr : bool = ~(fx) & has_rstr_fp_err_ptrs;
  let pointers : bool = x87_sw[7] == bitone | rstr;
  let no_selectors : bool = w | rstr & cur_mode == LongMode;
  if pointers then {
    let fop : word = read_mem(base + 6);
    x87_fop = fop[10..0];
    if w then {
      x87_fip = read_mem(base + 8);
      x87_fdp = read_mem(base + 16)
    } else {
      x87_fip = zero_extend(read_mem(base + 8) : dword);
      x87_fdp = zero_extend(read_mem(base + 16) : dword)
    };
    x87_fcs = if no_selectors then zeros() else read_mem(base + 12);
    x87_fds = if no_selectors then zeros() else read_mem(base + 20)
  } else x87_forget_last();
  // ST(i) relative to the TOP just loaded.
  foreach (i from 0 to 7) {
    x87_ST[x87_physical(i)] = read_mem(base + 32 + 16 * i)
  }
}

// The MXCSR bits the processor accepts: the MXCSR_MASK parameter
// (regs.sail), or 0000FFBFH where that is 0 (SDM Vol.1 §11.6.6 p.11-21).
// FXSAVE and XSAVE store the parameter itself.
val mxcsr_mask : unit -> dword
function mxcsr_mask() = if MXCSR_MASK == zeros() then 0x0000FFBF else MXCSR_MASK

// LDMXCSR and VLDMXCSR: #GP(0) for a value that sets a reserved bit, one
// clear in MXCSR_MASK (SDM LDMXCSR).
val load_mxcsr : dword -> unit
function load_mxcsr(value) = {
  if (value & ~(mxcsr_mask())) != zeros() then raise_GP0();
  __ldmxcsr(value)
}

// Save just MXCSR and MXCSR_MASK (shared between SSE and AVX)
val xsave_mxcsr : qword -> unit
function xsave_mxcsr(base) = {
  write_mem(base + 24, __stmxcsr());
  write_mem(base + 28, MXCSR_MASK)
}

// The XMM registers in the legacy region: XMM0-XMM15 in 64-bit mode,
// XMM0-XMM7 outside it, where the rest of the area is reserved.
val legacy_xmm_count : unit -> {8, 16}
function legacy_xmm_count() = if cur_mode == LongMode then 16 else 8

// The SSE component: MXCSR, MXCSR_MASK and the XMM registers' low 128 bits.
val xsave_sse : qword -> unit
function xsave_sse(base) = {
  xsave_mxcsr(base);
  foreach (i from 0 to legacy_xmm_count() - 1) {
    write_mem(128, base + 160 + 16 * i, ZMM[i][127..0])
  }
}

// Restore just MXCSR.  The callers have checked its reserved bits
// (check_image_mxcsr) before loading any state.
val xrstor_mxcsr : qword -> unit
function xrstor_mxcsr(base) = {
  __ldmxcsr(read_mem(base + 24))
}

val xrstor_xmm : qword -> unit
function xrstor_xmm(base) = {
  foreach (i from 0 to legacy_xmm_count() - 1) {
    let xmm_val : xmmword = read_mem(base + 160 + 16 * i);
    ZMM[i][127..0] = xmm_val
  }
}

val xrstor_sse : qword -> unit
function xrstor_sse(base) = {
  xrstor_mxcsr(base);
  xrstor_xmm(base)
}

// FXRSTOR and XRSTOR are #GP(0) for an image whose MXCSR, when loaded,
// would set a reserved bit (SDM Vol.2B FXRSTOR, XRSTOR).
val check_image_mxcsr : qword -> unit
function check_image_mxcsr(base) = {
  let mxcsr : dword = read_mem(base + 24);
  if (mxcsr & ~(mxcsr_mask())) != zeros() then raise_GP0()
}

// FXSAVE and FXRSTOR m512byte (SDM Vol.2A): the x87 and SSE components of
// the legacy region.  As non-VEX instructions on XMM state they do not
// access bits 511:128 of the registers (Vol.1 §14.8).
//
// With CR4.OSFXSR = 0, "FXSAVE and FXRSTOR may or may not operate on SSE
// state; this behavior is implementation dependent" (SDM Vol.1 §10.5.1
// p.10-16; FXSAVE p.3-414, FXRSTOR p.3-409), and the APM's FXSAVE "does
// not save the image of XMM0–XMM15 or MXCSR" and its FXRSTOR does not load
// it (APM Vol.5 FXSAVE p.26, FXRSTOR p.24).  So the MXCSR and XMM fields
// FXSAVE writes, and MXCSR and the XMM registers after FXRSTOR, are
// undefined (MXCSR within MXCSR_MASK, as either outcome is).  MXCSR_MASK is
// outside either rule and is saved.  FXRSTOR raises its #GP for reserved
// MXCSR bits only with OSFXSR = 1: with 0 the APM's FXRSTOR does not load
// MXCSR, so it makes no attempt "to load non-zero values into reserved
// MXCSR bits" (p.24), and only an SDM processor that loads it could fault.
val exec_fxsave : (qword, bool) -> unit
function exec_fxsave(base, w) = {
  xsave_x87(base, w, true);
  if CR4[9] == bitone then xsave_sse(base)   // OSFXSR
  else {
    write_mem(base + 24, undefined : dword);
    foreach (i from 0 to legacy_xmm_count() - 1) {
      write_mem(128, base + 160 + 16 * i, undefined)
    };
    write_mem(base + 28, MXCSR_MASK)
  }
}

val exec_fxrstor : (qword, bool) -> unit
function exec_fxrstor(base, w) = {
  let osfxsr = CR4[9] == bitone;
  if osfxsr then check_image_mxcsr(base);
  xrstor_x87(base, w, true);
  if osfxsr then xrstor_sse(base)
  else {
    __ldmxcsr((undefined : dword) & mxcsr_mask());
    foreach (i from 0 to legacy_xmm_count() - 1) {
      ZMM[i][127..0] = undefined
    }
  }
}

// -------------------------------------------------------------------------
// Save/restore at given address (used by both standard and compacted)
// -------------------------------------------------------------------------

val xsave_avx_at : qword -> unit
function xsave_avx_at(addr) = {
  foreach (i from 0 to 15) {
    write_mem(128, addr + 16 * i, ZMM[i][255..128])
  }
}

val xsave_opmask_at : qword -> unit
function xsave_opmask_at(addr) = {
  foreach (i from 0 to 7) {
    write_mem(addr + 8 * i, KREG[i])
  }
}

val xsave_zmm_hi256_at : qword -> unit
function xsave_zmm_hi256_at(addr) = {
  foreach (i from 0 to 15) {
    write_mem(256, addr + 32 * i, ZMM[i][511..256])
  }
}

val xsave_hi16_zmm_at : qword -> unit
function xsave_hi16_zmm_at(addr) = {
  foreach (i from 0 to 15) {
    write_mem(addr + 64 * i, ZMM[16 + i])
  }
}

val xrstor_avx_at : qword -> unit
function xrstor_avx_at(addr) = {
  foreach (i from 0 to 15) {
    let upper : xmmword = read_mem(addr + 16 * i);
    ZMM[i] = ZMM[i][511..256] @ upper @ ZMM[i][127..0]
  }
}

val xrstor_opmask_at : qword -> unit
function xrstor_opmask_at(addr) = {
  foreach (i from 0 to 7) {
    KREG[i] = read_mem(addr + 8 * i)
  }
}

val xrstor_zmm_hi256_at : qword -> unit
function xrstor_zmm_hi256_at(addr) = {
  foreach (i from 0 to 15) {
    let upper : ymmword = read_mem(addr + 32 * i);
    ZMM[i] = upper @ ZMM[i][255..0]
  }
}

// -------------------------------------------------------------------------
// Extended feature disable (SDM Vol.1 §13.14): XFD is enabled for state
// component i when XCR0[i] = IA32_XFD[i] = 1.  An instruction that would
// access the component then raises #NM after loading IA32_XFD_ERR with the
// component's bit.  XSAVE* save the component as if it were in its initial
// configuration (XSTATE_BV[i] = 0; XSAVE writes the initial state, the
// others nothing); XRSTOR* raise #NM only when XSTATE_BV[i] = 1.
// -------------------------------------------------------------------------

val xfd_enabled : range(0, 63) -> bool
function xfd_enabled(i) = XCR0[i] == bitone & IA32_XFD[i] == bitone

// The components with CPUID.0DH.i:ECX[2], those IA32_XFD can disable.  The
// model implements XFD for TILEDATA (component 18) only.
val xfd_supported : unit -> qword
function xfd_supported() =
  if has_xfd & XCR0_SUPPORTED[18] == bitone then 0x0000000000040000 else zeros()

val raise_xfd_nm : forall ('a : Type). range(0, 63) -> 'a
function raise_xfd_nm(i) = {
  IA32_XFD_ERR = IA32_XFD & (zero_extend(0b1) << i);
  throw Fault(EXN_NM, 0x00000000)
}

// -------------------------------------------------------------------------
// Intel AMX components (SDM Vol.1 §13.5.14): 17 is TILECFG in its LDTILECFG
// image (palette, start_row, colsb[8] at 16, rows[8] at 48; 64 bytes), 18
// is TILEDATA, the eight tiles in order, 16 rows of 64 bytes each, all
// 8 KB whatever TILECFG says.
// -------------------------------------------------------------------------

val xsave_tilecfg_at : qword -> unit
function xsave_tilecfg_at(addr) = {
  var buf : bits(512) = zeros();
  buf[7..0] = tilecfg_palette;
  buf[15..8] = tilecfg_start_row;
  foreach (n from 0 to 7) {
    buf[(16 * n + 143) .. (16 * n + 128)] = tilecfg_colsb[n];
    buf[(8 * n + 391) .. (8 * n + 384)] = tilecfg_rows[n]
  };
  write_mem(addr, buf)
}

// TILEDATA, or its initial configuration (zeros) under XFD.
val xsave_tiledata_at : qword -> unit
function xsave_tiledata_at(addr) = {
  foreach (i from 0 to 127) {
    write_mem(addr + 64 * i, if xfd_enabled(18) then (zeros() : zmmword) else TMM[i])
  }
}

// XRSTOR of TILECFG: an image LDTILECFG would reject (#GP) initializes the
// register instead (TILES_CONFIGURED = 0), and TILEDATA is left alone.
val xrstor_tilecfg_at : qword -> unit
function xrstor_tilecfg_at(addr) = {
  let buf : bits(512) = read_mem(addr);
  let palette : byte = buf[7..0];
  var error : bool = palette >_u 0x01;
  if palette != 0x00 then {
    if buf[127..16] != zeros() | buf[383..256] != zeros() | buf[511..448] != zeros() then error = true;
    foreach (n from 0 to 7) {
      let colsb : word = velem(16, buf, 8 + n);
      let rows : byte = velem(8, buf, 48 + n);
      if colsb >_u 0x0040 | rows >_u 0x10 then error = true;
      if (rows == 0x00) != (colsb == 0x0000) then error = true
    }
  };
  if error | palette == 0x00 then {
    amx_init_tilecfg()
  } else {
    tilecfg_palette = palette;
    tilecfg_start_row = buf[15..8];
    foreach (n from 0 to 7) {
      tilecfg_colsb[n] = velem(16, buf, 8 + n);
      tilecfg_rows[n] = velem(8, buf, 48 + n)
    }
  }
}

val xrstor_tiledata_at : qword -> unit
function xrstor_tiledata_at(addr) = {
  foreach (i from 0 to 127) {
    TMM[i] = read_mem(addr + 64 * i)
  }
}

val xrstor_hi16_zmm_at : qword -> unit
function xrstor_hi16_zmm_at(addr) = {
  foreach (i from 0 to 15) {
    ZMM[16 + i] = read_mem(addr + 64 * i)
  }
}

// -------------------------------------------------------------------------
// Standard-format save/restore wrappers (base + CPUID.0DH.i:EBX)
// -------------------------------------------------------------------------

val xsave_avx : qword -> unit
function xsave_avx(base) = xsave_avx_at(base + xsave_std_offset(2))

val xsave_opmask : qword -> unit
function xsave_opmask(base) = xsave_opmask_at(base + xsave_std_offset(5))

val xsave_zmm_hi256 : qword -> unit
function xsave_zmm_hi256(base) = xsave_zmm_hi256_at(base + xsave_std_offset(6))

val xsave_hi16_zmm : qword -> unit
function xsave_hi16_zmm(base) = xsave_hi16_zmm_at(base + xsave_std_offset(7))

val xrstor_avx : qword -> unit
function xrstor_avx(base) = xrstor_avx_at(base + xsave_std_offset(2))

val xrstor_opmask : qword -> unit
function xrstor_opmask(base) = xrstor_opmask_at(base + xsave_std_offset(5))

val xrstor_zmm_hi256 : qword -> unit
function xrstor_zmm_hi256(base) = xrstor_zmm_hi256_at(base + xsave_std_offset(6))

val xrstor_hi16_zmm : qword -> unit
function xrstor_hi16_zmm(base) = xrstor_hi16_zmm_at(base + xsave_std_offset(7))

// -------------------------------------------------------------------------
// Initialize state components to their default values (Section 13.6)
// -------------------------------------------------------------------------

val xinit_x87 : unit -> unit
function xinit_x87() = x87_init()

val xinit_xmm : unit -> unit
function xinit_xmm() = {
  foreach (i from 0 to 15) {
    ZMM[i][127..0] = zeros()
  }
}

val xinit_sse : unit -> unit
function xinit_sse() = {
  xinit_xmm();
  __ldmxcsr(0x00001F80)
}

val xinit_avx : unit -> unit
function xinit_avx() = {
  foreach (i from 0 to 15) {
    // Zero upper 128 bits (YMM_Hi128), preserve low 128
    ZMM[i] = ZMM[i][511..256] @ (zeros() : xmmword) @ ZMM[i][127..0]
  }
}

val xinit_opmask : unit -> unit
function xinit_opmask() = {
  foreach (i from 0 to 7) {
    KREG[i] = zeros()
  }
}

val xinit_zmm_hi256 : unit -> unit
function xinit_zmm_hi256() = {
  foreach (i from 0 to 15) {
    // Zero upper 256 bits, preserve low 256
    ZMM[i] = (zeros() : ymmword) @ ZMM[i][255..0]
  }
}

val xinit_hi16_zmm : unit -> unit
function xinit_hi16_zmm() = {
  foreach (i from 0 to 15) {
    ZMM[16 + i] = zeros()
  }
}

// The extended-region components the model implements, by number: save
// component i at addr, restore it from addr, and initialize it.
val xsave_component_at : (range(0, 18), qword) -> unit
function xsave_component_at(i, addr) = match i {
  2 => xsave_avx_at(addr),
  5 => xsave_opmask_at(addr),
  6 => xsave_zmm_hi256_at(addr),
  7 => xsave_hi16_zmm_at(addr),
  17 => xsave_tilecfg_at(addr),
  18 => xsave_tiledata_at(addr),
  _ => ()
}

val xrstor_component_at : (range(0, 18), qword) -> unit
function xrstor_component_at(i, addr) = match i {
  2 => xrstor_avx_at(addr),
  5 => xrstor_opmask_at(addr),
  6 => xrstor_zmm_hi256_at(addr),
  7 => xrstor_hi16_zmm_at(addr),
  17 => xrstor_tilecfg_at(addr),
  18 => xrstor_tiledata_at(addr),
  _ => ()
}

val xinit_component : range(0, 18) -> unit
function xinit_component(i) = match i {
  2 => xinit_avx(),
  5 => xinit_opmask(),
  6 => xinit_zmm_hi256(),
  7 => xinit_hi16_zmm(),
  17 => amx_init_tilecfg(),
  18 => amx_zero_all_tiles(),
  _ => ()
}

// =========================================================================
// XINUSE, the state-component bitmap of the init optimization (SDM Vol.1
// §13.6 p.13-18): "If XINUSE[i] = 0, state component i is known to be in
// its initial configuration; otherwise XINUSE[i] = 1.  It is possible for
// XINUSE[i] to be 1 even when state component i is in its initial
// configuration."  So bit i is 1 for a component out of its initial
// configuration and undefined for one in it; the APM leaves the same
// choice "implementation-dependent" (Vol.4 XSAVE p.1774).  The initial
// configurations, from §13.6: x87 with FCW 037FH, FSW 0000H, FTW FFFFH,
// FCS, FDS, FIP and FDP 0 and ST0-ST7 0; SSE with the XMM registers 0
// ("XINUSE[1] pertains only to the state of the XMM registers and not to
// MXCSR"); AVX, ZMM_Hi256 and Hi16_ZMM with their parts of the vector
// registers 0, of registers 0-15 in 64-bit mode and 0-7 outside it, where
// Hi16_ZMM "is always in its initial configuration"; opmask with k0-k7 0;
// and AMX with "the TILECFG register is zero and all tile data are zero"
// (both components).
// =========================================================================

val xinuse : unit -> qword
function xinuse() = {
  let n = legacy_xmm_count();
  var x87 : bool = x87_cw != 0x037F | x87_sw != 0x0000 | x87_tw != 0xFFFF |
    x87_fcs != 0x0000 | x87_fds != 0x0000 | x87_fip != zeros() | x87_fdp != zeros();
  var opmask : bool = false;
  foreach (i from 0 to 7) {
    if x87_ST[i] != zeros() then x87 = true;
    if KREG[i] != zeros() then opmask = true
  };
  var sse : bool = false;
  var avx : bool = false;
  var zmm_hi256 : bool = false;
  foreach (i from 0 to n - 1) {
    if ZMM[i][127..0] != zeros() then sse = true;
    if ZMM[i][255..128] != zeros() then avx = true;
    if ZMM[i][511..256] != zeros() then zmm_hi256 = true
  };
  var hi16_zmm : bool = false;
  if cur_mode == LongMode then foreach (i from 16 to 31) {
    if ZMM[i] != zeros() then hi16_zmm = true
  };
  var amx : bool = tilecfg_palette != 0x00 | tilecfg_start_row != 0x00;
  foreach (j from 0 to 7) {
    if tilecfg_colsb[j] != 0x0000 | tilecfg_rows[j] != 0x00 then amx = true
  };
  foreach (i from 0 to 127) {
    if TMM[i] != zeros() then amx = true
  };
  var used : qword = undefined;
  if x87 then used[0] = bitone;
  if sse then used[1] = bitone;
  if avx then used[2] = bitone;
  if opmask then used[5] = bitone;
  if zmm_hi256 then used[6] = bitone;
  if hi16_zmm then used[7] = bitone;
  if amx then { used[17] = bitone; used[18] = bitone };
  used
}

// What XSAVE* save XSTATE_BV from: a component XFD disables they save "as
// if XINUSE[i] = 0 (and the state component was in its initial state)"
// (§13.14 p.13-27).
val xinuse_saved : unit -> qword
function xinuse_saved() = xinuse() & ~(XCR0 & IA32_XFD)

// =========================================================================
// XSAVE and XSAVEOPT — standard format save (SDM Vol.1 §13.7 p.13-19,
// §13.9 p.13-22)
//
// RFBM = XCR0 & EDX:EAX.  XSTATE_BV[i] is kept for RFBM[i] = 0 and set to
// XINUSE[i] for RFBM[i] = 1; neither instruction "write[s] any part of the
// XSAVE header other than the XSTATE_BV field; in particular, it does not
// write to the XCOMP_BV field."  XSAVE saves every component of RFBM.
// XSAVEOPT uses the init optimization, "If XINUSE[i] = 0, state component
// i is not saved to the XSAVE area (even if RFBM[i] = 1)", except for
// MXCSR and MXCSR_MASK, saved for RFBM[1] or RFBM[2] by both; the model
// does not use its modified optimization, which an implementation may
// lack ("XMODIFIED[i] is always 1", §13.6).
// =========================================================================

val xsave_standard : (qword, qword, bool, bool) -> unit
function xsave_standard(base, mask, w, opt) = {
  let rfbm : qword = mask & XCR0;
  let used : qword = xinuse_saved();
  let save : qword = if opt then rfbm & used else rfbm;

  if save[0] == bitone then xsave_x87(base, w, false);
  if save[1] == bitone then xsave_sse(base)
  else if rfbm[1] == bitone | rfbm[2] == bitone then xsave_mxcsr(base);
  if save[2] == bitone then xsave_avx(base);
  if save[5] == bitone then xsave_opmask(base);
  if save[6] == bitone then xsave_zmm_hi256(base);
  if save[7] == bitone then xsave_hi16_zmm(base);
  if save[17] == bitone then xsave_tilecfg_at(base + xsave_std_offset(17));
  if save[18] == bitone then xsave_tiledata_at(base + xsave_std_offset(18));

  let old_bv : qword = read_mem(base + 512);
  write_mem(base + 512, (old_bv & ~(rfbm)) | (used & rfbm))
}

val exec_xsave : (qword, qword, bool) -> unit
function exec_xsave(base, mask, w) = xsave_standard(base, mask, w, false)

val exec_xsaveopt : (qword, qword, bool) -> unit
function exec_xsaveopt(base, mask, w) = xsave_standard(base, mask, w, true)

// =========================================================================
// XSAVEC — Compacted format save (SDM Vol.1 §13.10 p.13-23)
//
// RFBM = XCR0 & EDX:EAX.  XCOMP_BV[63] = 1 and XCOMP_BV[62:0] = RFBM;
// XSTATE_BV = RFBM & XINUSE, written whole, but "if RFBM[1] = 1 and MXCSR
// does not have the value 1F80H, XSAVEC writes XSTATE_BV[1] as 1 even if
// XINUSE[1] = 0".  With the init optimization a component is saved only
// where XSTATE_BV is 1, the SSE one with MXCSR and MXCSR_MASK, whatever
// RFBM[2] is.  Components are packed from offset 576 in the order of
// XCOMP_BV, each in its place whether saved or not
// (xsave_compacted_place).  A component XFD disables keeps its place too
// (XCOMP_BV is unaffected, §13.14) but is not written (xinuse_saved).
// =========================================================================

val exec_xsavec : (qword, qword, bool) -> unit
function exec_xsavec(base, mask, w) = {
  let rfbm : qword = mask & XCR0;
  var save : qword = rfbm & xinuse_saved();
  if rfbm[1] == bitone & __stmxcsr() != 0x00001F80 then save[1] = bitone;

  // Save legacy region (same offsets as standard format)
  if save[0] == bitone then xsave_x87(base, w, false);
  if save[1] == bitone then xsave_sse(base);

  var offset : qword = to_bits(64, 576);
  foreach (i from 2 to 18) {
    if rfbm[i] == bitone then {
      offset = xsave_compacted_place(offset, i);
      if save[i] == bitone then xsave_component_at(i, base + offset);
      offset = offset + xsave_comp_bytes(i)
    }
  };

  write_mem(base + 512, save);                       // XSTATE_BV
  write_mem(base + 520, rfbm | 0x8000000000000000)   // XCOMP_BV
}

// =========================================================================
// XSAVES — Save with supervisor state support (SDM Section 13.11)
//
// Like XSAVEC but RFBM = (XCR0 | IA32_XSS) & EDX:EAX
// Requires CPL = 0.  We don't model IA32_XSS (= 0).
// =========================================================================

val exec_xsaves : (qword, qword, bool) -> unit
function exec_xsaves(base, mask, w) = exec_xsavec(base, mask, w)

// Standard form XRSTOR
val xrstor_standard : (qword, qword, qword, bool) -> unit
function xrstor_standard(base, rfbm, xstate_bv, w) = {
  let to_restore : qword = rfbm & xstate_bv;
  let to_init : qword = rfbm & ~(xstate_bv);

  if to_restore[0] == bitone then xrstor_x87(base, w, false);
  if to_init[0] == bitone then xinit_x87();

  // The standard form loads MXCSR from the image for RFBM[1] or RFBM[2],
  // whatever XSTATE_BV says, and the SSE component then loads or
  // initializes only the XMM registers (SDM Vol.2B XRSTOR, Operation).
  if rfbm[1] == bitone | rfbm[2] == bitone then xrstor_mxcsr(base);
  if to_restore[1] == bitone then xrstor_xmm(base);
  if to_init[1] == bitone then xinit_xmm();

  if to_restore[2] == bitone then xrstor_avx(base);
  if to_init[2] == bitone then xinit_avx();

  if to_restore[5] == bitone then xrstor_opmask(base);
  if to_init[5] == bitone then xinit_opmask();

  if to_restore[6] == bitone then xrstor_zmm_hi256(base);
  if to_init[6] == bitone then xinit_zmm_hi256();

  if to_restore[7] == bitone then xrstor_hi16_zmm(base);
  if to_init[7] == bitone then xinit_hi16_zmm();

  if to_restore[17] == bitone then xrstor_tilecfg_at(base + xsave_std_offset(17));
  if to_init[17] == bitone then amx_init_tilecfg();

  if to_restore[18] == bitone then xrstor_tiledata_at(base + xsave_std_offset(18));
  if to_init[18] == bitone then amx_zero_all_tiles()
}

// Compacted form XRSTOR
val xrstor_compacted : (qword, qword, qword, qword, bool) -> unit
function xrstor_compacted(base, rfbm, xstate_bv, xcomp_bv, w) = {
  if rfbm[0] == bitone then {
    if xstate_bv[0] == bitone then xrstor_x87(base, w, false)
    else xinit_x87()
  };

  if rfbm[1] == bitone then {
    if xstate_bv[1] == bitone then xrstor_sse(base)
    else xinit_sse()
  };

  // The extended region: each component of XCOMP_BV has its place
  // (xsave_compacted_place), and the callers have checked that XSTATE_BV
  // is within XCOMP_BV.
  var offset : qword = to_bits(64, 576);
  foreach (i from 2 to 18) {
    if xcomp_bv[i] == bitone then offset = xsave_compacted_place(offset, i);
    if rfbm[i] == bitone then {
      if xstate_bv[i] == bitone then xrstor_component_at(i, base + offset)
      else xinit_component(i)
    };
    if xcomp_bv[i] == bitone then offset = offset + xsave_comp_bytes(i)
  }
}

// XFD (§13.14): restoring a component the MSR disables is #NM when the
// image has it (XSTATE_BV[i] = 1); an image without it initializes the
// component instead.  Checked before any component is loaded.
val xrstor_check_xfd : (qword, qword) -> unit
function xrstor_check_xfd(rfbm, xstate_bv) =
  if rfbm[18] == bitone & xstate_bv[18] == bitone & xfd_enabled(18) then raise_xfd_nm(18)

// =========================================================================
// XRSTOR — Restore extended state (SDM Section 13.8)
//
// RFBM = XCR0 & EDX:EAX
// Reads XCOMP_BV[63] to decide standard vs compacted format.
// For each component i where RFBM[i]=1:
//   If XSTATE_BV[i]=1: restore from XSAVE area
//   If XSTATE_BV[i]=0: initialize to default
// =========================================================================

val exec_xrstor : (qword, qword, bool) -> unit
function exec_xrstor(base, mask, w) = {
  let rfbm : qword = mask & XCR0;

  let xstate_bv : qword = read_mem(base + 512);
  let xcomp_bv : qword = read_mem(base + 520);

  if xcomp_bv[63] == bitone then {
    // Compacted form (Section 13.8.2), #GP(0) "If bit 63 of the XCOMP_BV
    // field of the XSAVE header is 1 and CPUID.0DH.01H:EAX.XSAVEC[1] = 0"
    if ~(has_xsavec) then raise_GP0();
    if (xcomp_bv & 0x7FFFFFFFFFFFFFFF & ~(XCR0)) != zeros() then raise_GP0();
    if (xstate_bv & ~(xcomp_bv & 0x7FFFFFFFFFFFFFFF)) != zeros() then raise_GP0();
    foreach (i from 0 to 5) {
      if read_mem(64, base + 528 + 8 * i) != zeros() then raise_GP0()
    };
    // The compacted form loads MXCSR with the SSE component.
    if rfbm[1] == bitone & xstate_bv[1] == bitone then check_image_mxcsr(base);
    xrstor_check_xfd(rfbm, xstate_bv);
    xrstor_compacted(base, rfbm, xstate_bv, xcomp_bv, w)
  } else {
    // Standard form (Section 13.8.1)
    if (xstate_bv & ~(XCR0)) != zeros() then raise_GP0();
    if xcomp_bv != zeros() then raise_GP0();
    // The standard form loads MXCSR for RFBM[1] or RFBM[2] (xrstor_standard).
    if rfbm[1] == bitone | rfbm[2] == bitone then check_image_mxcsr(base);
    xrstor_check_xfd(rfbm, xstate_bv);
    xrstor_standard(base, rfbm, xstate_bv, w)
  }
}

// =========================================================================
// XRSTORS — Restore with supervisor state (SDM Section 13.12)
//
// Like compacted XRSTOR but RFBM = (XCR0 | IA32_XSS) & EDX:EAX
// Requires CPL = 0 and XCOMP_BV[63] = 1.
// =========================================================================

val exec_xrstors : (qword, qword, bool) -> unit
function exec_xrstors(base, mask, w) = {
  let rfbm : qword = mask & XCR0;

  let xstate_bv : qword = read_mem(base + 512);
  let xcomp_bv : qword = read_mem(base + 520);

  // XRSTORS requires compacted format
  if xcomp_bv[63] == bitzero then raise_GP0();
  if (xcomp_bv & 0x7FFFFFFFFFFFFFFF & ~(XCR0)) != zeros() then raise_GP0();
  if (xstate_bv & ~(xcomp_bv & 0x7FFFFFFFFFFFFFFF)) != zeros() then raise_GP0();
  foreach (i from 0 to 5) {
    if read_mem(64, base + 528 + 8 * i) != zeros() then raise_GP0()
  };
  if rfbm[1] == bitone & xstate_bv[1] == bitone then check_image_mxcsr(base);
  xrstor_check_xfd(rfbm, xstate_bv);
  xrstor_compacted(base, rfbm, xstate_bv, xcomp_bv, w)
}
