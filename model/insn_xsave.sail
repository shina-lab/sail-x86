// =========================================================================
// XSAVE / XRSTOR / XSAVEC / XSAVEOPT / XSAVES / XRSTORS
//
// Save and restore extended processor state (x87, SSE, AVX, AVX-512).
// SDM Chapter 13.
// =========================================================================

// -------------------------------------------------------------------------
// XSAVE area size computation (CPUID leaf 0xD)
//
// Standard format: each component has a fixed offset (from CPUID.0DH.n:EBX)
// and size (from CPUID.0DH.n:EAX). The total size is max(offset+size) over
// all enabled components. The minimum is 576 (legacy 512 + header 64).
//
// Compacted format: components are packed contiguously with 64-byte alignment
// for components that require it (CPUID.0DH.n:ECX bit 1).
// -------------------------------------------------------------------------

// Standard-format offset of a state component (CPUID.0DH.n:EBX).  The SDM
// only requires that software read these from CPUID, and the two vendors
// lay the AVX-512 components out differently: Intel keeps the MPX slots
// (components 3 and 4, 64 bytes each at 960 and 1024) reserved even on
// parts without MPX, so opmask, ZMM_Hi256 and Hi16_ZMM start at 1088,
// 1152 and 1664; AMD enumerates no MPX components and packs the three
// right after the AVX component at 832, 896 and 1408.  The AVX component
// is at 576 on both.  The choice follows the vendor profile register.
// Sizes are the same on both: 256 (AVX), 64 (opmask), 512 (ZMM_Hi256),
// 1024 (Hi16_ZMM).  The Intel AMX components 17 (TILECFG, 64 bytes) and
// 18 (TILEDATA, 8192 bytes) follow the PKRU slot (component 9, 2688) at
// 2752 and 2816 (CPUID.0DH.11H/12H:EBX on Sapphire Rapids and Emerald
// Rapids); no AMD part implements AMX, so the AMD profile uses the same
// values.
val xsave_std_offset : int -> range(0, 16383)
function xsave_std_offset(component) = match component {
  2 => 576,
  5 => match vendor { Vendor_Intel => 1088, Vendor_AMD => 832 },
  6 => match vendor { Vendor_Intel => 1152, Vendor_AMD => 896 },
  7 => match vendor { Vendor_Intel => 1664, Vendor_AMD => 1408 },
  17 => 2752,
  18 => 2816,
  _ => 0
}

// Standard format XSAVE area size for a given feature mask: the end of
// the highest enabled component, or 576 (legacy region + header) if none.
val xsave_area_size_standard : qword -> dword
function xsave_area_size_standard(mask) = {
  // Ascending blend: each higher enabled component overwrites the total
  // size, which is valid because the offsets increase with the component
  // number in both vendor layouts.
  let s0 : dword = to_bits(32, 576);
  let s1 : dword = blend(s0, to_bits(32, xsave_std_offset(2) + 256), mask[2]);
  let s2 : dword = blend(s1, to_bits(32, xsave_std_offset(5) + 64), mask[5]);
  let s3 : dword = blend(s2, to_bits(32, xsave_std_offset(6) + 512), mask[6]);
  let s4 : dword = blend(s3, to_bits(32, xsave_std_offset(7) + 1024), mask[7]);
  let s5 : dword = blend(s4, to_bits(32, xsave_std_offset(17) + 64), mask[17]);
  blend(s5, to_bits(32, xsave_std_offset(18) + 8192), mask[18])
}

// Compacted format XSAVE area size for a given feature mask.  Components
// 2, 5, 6, 7, 17 and 18 are packed from offset 576 in component order;
// every size is a multiple of 64, so the 64-byte alignment that
// components 5-7, 17 and 18 require (CPUID.0DH.n:ECX[1]) never adds
// padding.  Unlike the standard layout this does not depend on the vendor.
val xsave_area_size_compacted : qword -> dword
function xsave_area_size_compacted(mask) = {
  let s0 : dword = to_bits(32, 576);
  let s1 : dword = s0 + blend(zeros() : dword, to_bits(32, 256), mask[2]);
  let s2 : dword = s1 + blend(zeros() : dword, to_bits(32, 64), mask[5]);
  let s3 : dword = s2 + blend(zeros() : dword, to_bits(32, 512), mask[6]);
  let s4 : dword = s3 + blend(zeros() : dword, to_bits(32, 1024), mask[7]);
  let s5 : dword = s4 + blend(zeros() : dword, to_bits(32, 64), mask[17]);
  s5 + blend(zeros() : dword, to_bits(32, 8192), mask[18])
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
// p.362-363).  The reserved parts, for which neither manual gives a value,
// are written undefined: FOP bits 15:11 ("upper 5 bits are reserved"),
// bytes 0Eh-0Fh and 16h-17h of the 32-bit format ("rsrvd, IGN" in the
// APM), and the last 6 bytes of each register; byte 5 as well on Intel
// ("Rsvd"), where the APM has "(Byte 05h contains the value 00h.)".  Two
// more rules are the SDM's alone: after MMX code "the high 16 bits of the
// field are reserved" for each register, and in 16-bit mode the "high 16
// bits are reserved" of FIP and FDP.
//
// Intel saves FOP, FIP and FDP always (SDM Vol.1 §8.1.8).  AMD saves them
// only while an x87 exception is pending (FSW.ES = 1).  Otherwise, with
// RstrFpErrPtrs (the AMD profile), XSAVE writes zeros: "the error pointer
// fields in the save area are zeroed if there is no pending #MF" (APM
// Vol.2 §11.5.10 p.361, Vol.4 XSAVE p.1774).  FXSAVE "does not save the
// x87 pointer registers" then (Vol.5 FXSAVE p.26), without saying what
// the fields hold; the model writes the same zeros.
val xsave_x87 : (qword, bool) -> unit
function xsave_x87(base, w) = {
  let intel = vendor == Vendor_Intel;
  let pointers : bool = intel | x87_sw[7] == bitone;
  let fop : bits(11) = if pointers then x87_fop else zeros();
  let fip : qword = if pointers then x87_fip else zeros();
  let fdp : qword = if pointers then x87_fdp else zeros();
  let fcs : word = if pointers then x87_saved_selector(x87_fcs) else zeros();
  let fds : word = if pointers then x87_saved_selector(x87_fds) else zeros();
  let mode16 = intel & cur_mode != LongMode & get_cs_db() == bitzero;
  let fip32 : dword = if mode16 then (undefined : word) @ fip[15..0] else fip[31..0];
  let fdp32 : dword = if mode16 then (undefined : word) @ fdp[15..0] else fdp[31..0];
  write_mem(base, x87_cw);
  write_mem(base + 2, x87_sw);
  write_mem(base + 4, ftw_full_to_abridged(x87_tw));
  write_mem(base + 5, if intel then (undefined : byte) else 0x00);
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
    let high : word = if intel & x87_mmx_last then undefined else st[79..64];
    write_mem(base + 32 + 16 * i, high @ st[63..0]);
    write_mem(48, base + 32 + 16 * i + 10, undefined)
  }
}

// The x87 component back from an image, for FXRSTOR (fx) or XRSTOR.
// Intel loads FOP, FIP and FDP always, and FCS and FDS from the 32-bit
// format; the 64-bit format (REX.W) "clears FCS and FDS" (SDM Vol.1
// §8.1.8).  AMD's FXRSTOR loads the pointers "when FXRSTOR sets FSW.ES=1
// after recomputing it" and otherwise leaves them (APM Vol.5 FXRSTOR
// p.24).  Its XRSTOR, with RstrFpErrPtrs (the AMD profile), loads them
// always, "and if in 64-bit mode the CS and DS portions of the error
// pointer registers are zeroed" (Vol.2 §11.5.10 p.361).
val xrstor_x87 : (qword, bool, bool) -> unit
function xrstor_x87(base, w, fx) = {
  x87_set_cw(read_mem(base));
  x87_set_sw(read_mem(base + 2));
  x87_tw = ftw_abridged_to_full(read_mem(base + 4));
  let pointers : bool = vendor == Vendor_Intel | x87_sw[7] == bitone
    | ~(fx) & rstr_fp_err_ptrs();
  let no_selectors : bool = w | ~(fx) & rstr_fp_err_ptrs() & cur_mode == LongMode;
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
  };
  // ST(i) relative to the TOP just loaded.
  foreach (i from 0 to 7) {
    x87_ST[x87_physical(i)] = read_mem(base + 32 + 16 * i)
  }
}

// MXCSR_MASK reports which MXCSR bits the processor accepts; the SDM
// leaves the value implementation dependent (Vol. 1, Ch. 11, "Guidelines
// for Writing to the MXCSR Register").  Intel processors report
// 0x0000FFFF (bits 15:0, DAZ included); AMD processors report 0x0002FFFF
// because bit 17 is their misaligned-SSE mode, gated by the MISALIGNSSE
// CPUID feature.  The value follows the vendor profile register.
val mxcsr_mask : unit -> dword
function mxcsr_mask() = match vendor {
  Vendor_Intel => 0x0000FFFF,
  Vendor_AMD   => 0x0002FFFF
}

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
  write_mem(base + 28, mxcsr_mask())
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
val exec_fxsave : (qword, bool) -> unit
function exec_fxsave(base, w) = {
  xsave_x87(base, w);
  xsave_sse(base)
}

val exec_fxrstor : (qword, bool) -> unit
function exec_fxrstor(base, w) = {
  check_image_mxcsr(base);
  xrstor_x87(base, w, true);
  xrstor_sse(base)
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
// compacted forms nothing); XRSTOR* raise #NM only when XSTATE_BV[i] = 1.
// -------------------------------------------------------------------------

val xfd_enabled : range(0, 63) -> bool
function xfd_enabled(i) = XCR0[i] == bitone & IA32_XFD[i] == bitone

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
// Standard-offset save/restore wrappers (base + the profile's offset)
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

// =========================================================================
// XSAVE — Standard format save (SDM Section 13.7)
//
// RFBM = XCR0 & EDX:EAX
// For each component i where RFBM[i]=1, save component to XSAVE area.
// XSTATE_BV[i] = (old_BV[i] & ~RFBM[i]) | (XINUSE[i] & RFBM[i])
// We set XINUSE = XCR0 (no init optimization, always in-use).
// XCOMP_BV = 0, reserved header bytes = 0.
// =========================================================================

val exec_xsave : (qword, qword, bool) -> unit
function exec_xsave(base, mask, w) = {
  let rfbm : qword = mask & XCR0;

  // Save legacy region components
  if rfbm[0] == bitone then xsave_x87(base, w);
  if rfbm[1] == bitone then xsave_sse(base);
  // SDM: MXCSR is saved when RFBM[1] OR RFBM[2]
  if rfbm[1] == bitzero & rfbm[2] == bitone then xsave_mxcsr(base);

  // Save extended region components (standard fixed offsets)
  if rfbm[2] == bitone then xsave_avx(base);
  if rfbm[5] == bitone then xsave_opmask(base);
  if rfbm[6] == bitone then xsave_zmm_hi256(base);
  if rfbm[7] == bitone then xsave_hi16_zmm(base);
  if rfbm[17] == bitone then xsave_tilecfg_at(base + xsave_std_offset(17));
  if rfbm[18] == bitone then xsave_tiledata_at(base + xsave_std_offset(18));

  // Update XSAVE header
  // Read old XSTATE_BV, merge with RFBM
  let old_bv : qword = read_mem(base + 512);
  // XINUSE = XCR0 (no init optimization), except that a component XFD
  // disables is saved as if in its initial configuration (§13.14)
  let xinuse : qword = XCR0 & ~(IA32_XFD);
  let xstate_bv : qword = (old_bv & ~(rfbm)) | (xinuse & rfbm);
  write_mem(base + 512, xstate_bv);
  // XCOMP_BV = 0 (standard format)
  write_mem(base + 520, zeros() : qword);
  // Zero reserved bytes 16-63 of header (offsets 528-575)
  foreach (i from 0 to 5) {
    write_mem(base + 528 + 8 * i, zeros() : qword)
  }
}

// =========================================================================
// XSAVEOPT — Optimized save (SDM Section 13.9)
//
// Architecturally identical to XSAVE for our specification.
// The "modified optimization" is implementation-specific and optional;
// we model it as always saving (XMODIFIED = all 1s).
// =========================================================================

val exec_xsaveopt : (qword, qword, bool) -> unit
function exec_xsaveopt(base, mask, w) = exec_xsave(base, mask, w)

// =========================================================================
// XSAVEC — Compacted format save (SDM Section 13.10)
//
// RFBM = XCR0 & EDX:EAX
// Uses compacted format: XCOMP_BV[63] = 1, XCOMP_BV[62:0] = RFBM
// XSTATE_BV = XINUSE & RFBM (fresh write, not merged with old)
// We set XINUSE = XCR0 so XSTATE_BV = RFBM.
// Components packed contiguously starting at offset 576.
// =========================================================================

val exec_xsavec : (qword, qword, bool) -> unit
function exec_xsavec(base, mask, w) = {
  let rfbm : qword = mask & XCR0;

  // Save legacy region (same offsets as standard format)
  if rfbm[0] == bitone then xsave_x87(base, w);
  if rfbm[1] == bitone then xsave_sse(base);
  // SDM: XSAVEC does NOT save MXCSR based on RFBM[2], only RFBM[1]

  // Save extended region in compacted format.
  // Components packed starting at offset 576.
  // Component sizes and alignment (from CPUID.0DH.n):
  //   2 (AVX): 256 bytes, no 64-byte align requirement
  //   5 (opmask): 64 bytes, 64-byte aligned
  //   6 (ZMM_Hi256): 512 bytes, 64-byte aligned
  //   7 (Hi16_ZMM): 1024 bytes, 64-byte aligned
  var offset : qword = base + 576;

  if rfbm[2] == bitone then {
    xsave_avx_at(offset);
    offset = offset + 256
  };

  // Components 3, 4 not supported — skip
  if rfbm[5] == bitone then {
    offset = (offset + 63) & 0xFFFFFFFFFFFFFFC0; // 64-byte align
    xsave_opmask_at(offset);
    offset = offset + 64
  };

  if rfbm[6] == bitone then {
    offset = (offset + 63) & 0xFFFFFFFFFFFFFFC0;
    xsave_zmm_hi256_at(offset);
    offset = offset + 512
  };

  if rfbm[7] == bitone then {
    offset = (offset + 63) & 0xFFFFFFFFFFFFFFC0;
    xsave_hi16_zmm_at(offset);
    offset = offset + 1024
  };

  // Components 17 (TILECFG, 64 bytes) and 18 (TILEDATA, 8192), both
  // 64-byte aligned.  A component XFD disables keeps its place in the
  // layout (XCOMP_BV is unaffected, §13.14) but is not written.
  if rfbm[17] == bitone then {
    offset = (offset + 63) & 0xFFFFFFFFFFFFFFC0;
    xsave_tilecfg_at(offset);
    offset = offset + 64
  };

  if rfbm[18] == bitone then {
    offset = (offset + 63) & 0xFFFFFFFFFFFFFFC0;
    if ~(xfd_enabled(18)) then xsave_tiledata_at(offset);
    offset = offset + 8192
  };

  // Write XSAVE header
  // XSTATE_BV = XINUSE & RFBM = RFBM (since XINUSE = XCR0, RFBM <= XCR0),
  // less the components XFD disables (saved as in their initial state)
  write_mem(base + 512, rfbm & ~(IA32_XFD));
  // XCOMP_BV = RFBM | bit 63
  write_mem(base + 520, rfbm | 0x8000000000000000)
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

  // Compute compacted offsets for extended components
  var offset : qword = base + 576;

  // Component 2 (AVX)
  if xcomp_bv[2] == bitone then {
    if rfbm[2] == bitone then {
      if xstate_bv[2] == bitone then xrstor_avx_at(offset)
      else xinit_avx()
    };
    offset = offset + 256
  } else {
    if rfbm[2] == bitone then xinit_avx()
  };

  // Components 3, 4 not supported

  // Component 5 (opmask)
  if xcomp_bv[5] == bitone then {
    offset = (offset + 63) & 0xFFFFFFFFFFFFFFC0;
    if rfbm[5] == bitone then {
      if xstate_bv[5] == bitone then xrstor_opmask_at(offset)
      else xinit_opmask()
    };
    offset = offset + 64
  } else {
    if rfbm[5] == bitone then xinit_opmask()
  };

  // Component 6 (ZMM_Hi256)
  if xcomp_bv[6] == bitone then {
    offset = (offset + 63) & 0xFFFFFFFFFFFFFFC0;
    if rfbm[6] == bitone then {
      if xstate_bv[6] == bitone then xrstor_zmm_hi256_at(offset)
      else xinit_zmm_hi256()
    };
    offset = offset + 512
  } else {
    if rfbm[6] == bitone then xinit_zmm_hi256()
  };

  // Component 7 (Hi16_ZMM)
  if xcomp_bv[7] == bitone then {
    offset = (offset + 63) & 0xFFFFFFFFFFFFFFC0;
    if rfbm[7] == bitone then {
      if xstate_bv[7] == bitone then xrstor_hi16_zmm_at(offset)
      else xinit_hi16_zmm()
    };
    offset = offset + 1024
  } else {
    if rfbm[7] == bitone then xinit_hi16_zmm()
  };

  // Component 17 (TILECFG)
  if xcomp_bv[17] == bitone then {
    offset = (offset + 63) & 0xFFFFFFFFFFFFFFC0;
    if rfbm[17] == bitone then {
      if xstate_bv[17] == bitone then xrstor_tilecfg_at(offset)
      else amx_init_tilecfg()
    };
    offset = offset + 64
  } else {
    if rfbm[17] == bitone then amx_init_tilecfg()
  };

  // Component 18 (TILEDATA)
  if xcomp_bv[18] == bitone then {
    offset = (offset + 63) & 0xFFFFFFFFFFFFFFC0;
    if rfbm[18] == bitone then {
      if xstate_bv[18] == bitone then xrstor_tiledata_at(offset)
      else amx_zero_all_tiles()
    }
  } else {
    if rfbm[18] == bitone then amx_zero_all_tiles()
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
    // Compacted form (Section 13.8.2)
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
