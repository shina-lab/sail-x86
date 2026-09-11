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
// 1024 (Hi16_ZMM).
val xsave_std_offset : int -> range(0, 4095)
function xsave_std_offset(component) = match component {
  2 => 576,
  5 => match vendor { Vendor_Intel => 1088, Vendor_AMD => 832 },
  6 => match vendor { Vendor_Intel => 1152, Vendor_AMD => 896 },
  7 => match vendor { Vendor_Intel => 1664, Vendor_AMD => 1408 },
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
  blend(s3, to_bits(32, xsave_std_offset(7) + 1024), mask[7])
}

// Compacted format XSAVE area size for a given feature mask.  Components
// 2, 5, 6 and 7 are packed from offset 576 in component order; every
// size is a multiple of 64, so the 64-byte alignment that components
// 5-7 require (CPUID.0DH.n:ECX[1]) never adds padding.  Unlike the
// standard layout this does not depend on the vendor.
val xsave_area_size_compacted : qword -> dword
function xsave_area_size_compacted(mask) = {
  let s0 : dword = to_bits(32, 576);
  let s1 : dword = s0 + blend(zeros() : dword, to_bits(32, 256), mask[2]);
  let s2 : dword = s1 + blend(zeros() : dword, to_bits(32, 64), mask[5]);
  let s3 : dword = s2 + blend(zeros() : dword, to_bits(32, 512), mask[6]);
  s3 + blend(zeros() : dword, to_bits(32, 1024), mask[7])
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
    let tag : bits(2) = tw[2 * i + 1 .. 2 * i];
    if tag != 0b11 then
      result = result | zero_extend(0b1 << i)
  };
  result
}

val ftw_abridged_to_full : byte -> word
function ftw_abridged_to_full(ab) = {
  var tw : word = 0x0000;
  foreach (i from 0 to 7) {
    if ab[i] == 0b0 then
      tw = tw | zero_extend(0b11 << (2 * i))
    // else: tag = 00 (valid) — FXRSTOR/XRSTOR semantics
  };
  tw
}

// -------------------------------------------------------------------------
// Save x87 state to legacy region (component 0)
// SDM: bytes 0-23 (FCW, FSW, FTW, FOP, FIP, FDP) and bytes 32-159 (ST0-ST7)
// -------------------------------------------------------------------------

val xsave_x87 : qword -> unit
function xsave_x87(base) = {
  write_mem(base, x87_cw);
  write_mem(base + 2, x87_sw);
  write_mem(base + 4, ftw_full_to_abridged(x87_tw));
  write_mem(base + 5, 0x00);    // reserved
  write_mem(base + 6, 0x0000); // FOP
  write_mem(base + 8, zeros() : qword); // FIP
  write_mem(base + 16, zeros() : qword); // FDP
  // ST0-ST7 at offset 32, 16 bytes each (10 bytes used, 6 reserved)
  foreach (i from 0 to 7) {
    let st_val : fp80 = x87_ST[i];
    write_mem(base + 32 + 16 * i, st_val);
    // Zero the reserved 6 bytes
    write_mem(48, base + 32 + 16 * i + 10, zeros())
  }
}

// -------------------------------------------------------------------------
// Save SSE state to legacy region (component 1)
// SDM: bytes 24-31 (MXCSR, MXCSR_MASK) and bytes 160-415 (XMM0-XMM15)
// -------------------------------------------------------------------------

// MXCSR_MASK reports which MXCSR bits the processor accepts; the SDM
// leaves the value implementation dependent (Vol. 1, Ch. 11, "Guidelines
// for Writing to the MXCSR Register").  Intel processors report
// 0x0000FFFF (bits 15:0, DAZ included); AMD processors report 0x0002FFFF
// because bit 17 is their misaligned-SSE mode, gated by the MISALIGNSSE
// CPUID feature.  The value follows the vendor profile register.  The
// FXSAVE externals in usermode-emu and system-emu call this too, so the
// FXSAVE and XSAVE images agree.
val mxcsr_mask : unit -> dword
function mxcsr_mask() = match vendor {
  Vendor_Intel => 0x0000FFFF,
  Vendor_AMD   => 0x0002FFFF
}

// Save just MXCSR and MXCSR_MASK (shared between SSE and AVX)
val xsave_mxcsr : qword -> unit
function xsave_mxcsr(base) = {
  write_mem(base + 24, __stmxcsr());
  write_mem(base + 28, mxcsr_mask())
}

val xsave_sse : qword -> unit
function xsave_sse(base) = {
  xsave_mxcsr(base);
  // XMM0-XMM15 at offset 160, 16 bytes each
  foreach (i from 0 to 15) {
    write_mem(128, base + 160 + 16 * i, ZMM[i][127..0])
  }
}

// -------------------------------------------------------------------------
// Restore x87 state from legacy region (component 0)
// -------------------------------------------------------------------------

val xrstor_x87 : qword -> unit
function xrstor_x87(base) = {
  x87_cw = read_mem(base);
  x87_sw = read_mem(base + 2);
  x87_tw = ftw_abridged_to_full(read_mem(base + 4));
  // FOP, FIP, FDP are not modeled (they're for debugging only)
  // ST0-ST7
  foreach (i from 0 to 7) {
    x87_ST[i] = read_mem(base + 32 + 16 * i)
  }
}

// Restore just MXCSR
val xrstor_mxcsr : qword -> unit
function xrstor_mxcsr(base) = {
  __ldmxcsr(read_mem(base + 24))
}

val xrstor_sse : qword -> unit
function xrstor_sse(base) = {
  xrstor_mxcsr(base);
  // XMM0-XMM15
  foreach (i from 0 to 15) {
    let xmm_val : xmmword = read_mem(base + 160 + 16 * i);
    ZMM[i] = zero_extend(xmm_val)
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

val xinit_sse : unit -> unit
function xinit_sse() = {
  foreach (i from 0 to 15) {
    ZMM[i] = zero_extend(zeros() : xmmword)
  };
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

val exec_xsave : (qword, qword) -> unit
function exec_xsave(base, mask) = {
  let rfbm : qword = mask & XCR0;

  // Save legacy region components
  if rfbm[0] == bitone then xsave_x87(base);
  if rfbm[1] == bitone then xsave_sse(base);
  // SDM: MXCSR is saved when RFBM[1] OR RFBM[2]
  if rfbm[1] == bitzero & rfbm[2] == bitone then xsave_mxcsr(base);

  // Save extended region components (standard fixed offsets)
  if rfbm[2] == bitone then xsave_avx(base);
  if rfbm[5] == bitone then xsave_opmask(base);
  if rfbm[6] == bitone then xsave_zmm_hi256(base);
  if rfbm[7] == bitone then xsave_hi16_zmm(base);

  // Update XSAVE header
  // Read old XSTATE_BV, merge with RFBM
  let old_bv : qword = read_mem(base + 512);
  // XINUSE = XCR0 (no init optimization)
  let xstate_bv : qword = (old_bv & ~(rfbm)) | (XCR0 & rfbm);
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

val exec_xsaveopt : (qword, qword) -> unit
function exec_xsaveopt(base, mask) = exec_xsave(base, mask)

// =========================================================================
// XSAVEC — Compacted format save (SDM Section 13.10)
//
// RFBM = XCR0 & EDX:EAX
// Uses compacted format: XCOMP_BV[63] = 1, XCOMP_BV[62:0] = RFBM
// XSTATE_BV = XINUSE & RFBM (fresh write, not merged with old)
// We set XINUSE = XCR0 so XSTATE_BV = RFBM.
// Components packed contiguously starting at offset 576.
// =========================================================================

val exec_xsavec : (qword, qword) -> unit
function exec_xsavec(base, mask) = {
  let rfbm : qword = mask & XCR0;

  // Save legacy region (same offsets as standard format)
  if rfbm[0] == bitone then xsave_x87(base);
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

  // Write XSAVE header
  // XSTATE_BV = XINUSE & RFBM = RFBM (since XINUSE = XCR0, RFBM <= XCR0)
  write_mem(base + 512, rfbm);
  // XCOMP_BV = RFBM | bit 63
  write_mem(base + 520, rfbm | 0x8000000000000000)
}

// =========================================================================
// XSAVES — Save with supervisor state support (SDM Section 13.11)
//
// Like XSAVEC but RFBM = (XCR0 | IA32_XSS) & EDX:EAX
// Requires CPL = 0.  We don't model IA32_XSS (= 0).
// =========================================================================

val exec_xsaves : (qword, qword) -> unit
function exec_xsaves(base, mask) = exec_xsavec(base, mask)

// Standard form XRSTOR
val xrstor_standard : (qword, qword, qword) -> unit
function xrstor_standard(base, rfbm, xstate_bv) = {
  let to_restore : qword = rfbm & xstate_bv;
  let to_init : qword = rfbm & ~(xstate_bv);

  if to_restore[0] == bitone then xrstor_x87(base);
  if to_init[0] == bitone then xinit_x87();

  if to_restore[1] == bitone then xrstor_sse(base);
  if to_init[1] == bitone then xinit_sse();

  // SDM: Standard XRSTOR loads MXCSR when (RFBM[1] | RFBM[2]) & XSTATE_BV[1]
  if rfbm[2] == bitone & xstate_bv[1] == bitone & to_restore[1] == bitzero then
    xrstor_mxcsr(base);

  if to_restore[2] == bitone then xrstor_avx(base);
  if to_init[2] == bitone then xinit_avx();

  if to_restore[5] == bitone then xrstor_opmask(base);
  if to_init[5] == bitone then xinit_opmask();

  if to_restore[6] == bitone then xrstor_zmm_hi256(base);
  if to_init[6] == bitone then xinit_zmm_hi256();

  if to_restore[7] == bitone then xrstor_hi16_zmm(base);
  if to_init[7] == bitone then xinit_hi16_zmm()
}

// Compacted form XRSTOR
val xrstor_compacted : (qword, qword, qword, qword) -> unit
function xrstor_compacted(base, rfbm, xstate_bv, xcomp_bv) = {
  if rfbm[0] == bitone then {
    if xstate_bv[0] == bitone then xrstor_x87(base)
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
    }
  } else {
    if rfbm[7] == bitone then xinit_hi16_zmm()
  }
}

// =========================================================================
// XRSTOR — Restore extended state (SDM Section 13.8)
//
// RFBM = XCR0 & EDX:EAX
// Reads XCOMP_BV[63] to decide standard vs compacted format.
// For each component i where RFBM[i]=1:
//   If XSTATE_BV[i]=1: restore from XSAVE area
//   If XSTATE_BV[i]=0: initialize to default
// =========================================================================

val exec_xrstor : (qword, qword) -> unit
function exec_xrstor(base, mask) = {
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
    xrstor_compacted(base, rfbm, xstate_bv, xcomp_bv)
  } else {
    // Standard form (Section 13.8.1)
    if (xstate_bv & ~(XCR0)) != zeros() then raise_GP0();
    if xcomp_bv != zeros() then raise_GP0();
    xrstor_standard(base, rfbm, xstate_bv)
  }
}

// =========================================================================
// XRSTORS — Restore with supervisor state (SDM Section 13.12)
//
// Like compacted XRSTOR but RFBM = (XCR0 | IA32_XSS) & EDX:EAX
// Requires CPL = 0 and XCOMP_BV[63] = 1.
// =========================================================================

val exec_xrstors : (qword, qword) -> unit
function exec_xrstors(base, mask) = {
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
  xrstor_compacted(base, rfbm, xstate_bv, xcomp_bv)
}
