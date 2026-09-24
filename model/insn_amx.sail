// x86-64 — Intel AMX: tile configuration, tile loads and stores, and the
// TMUL dot products (SDM Vol.1 Chapter 19; Vol.2 LDTILECFG, STTILECFG,
// TILELOADD/TILELOADDT1, TILERELEASE, TILESTORED, TILEZERO,
// TDPBSSD/TDPBSUD/TDPBUSD/TDPBUUD, TDPBF16PS).
//
// Palette 1 (CPUID.1DH.01H): eight tiles of at most 16 rows by 64 bytes;
// TMUL (CPUID.1EH): tmul_maxk = 16, tmul_maxn = 64.  The tile state is in
// regs.sail: tile t row r is TMM[16 * t + r], and TILES_CONFIGURED of the
// SDM is tilecfg_palette != 0.

// #UD conditions shared by the six AMX exception classes (SDM Vol.2
// Table 1-67): the AMX_TILE feature, CR4.OSXSAVE, XCR0[18:17] = 11b and
// 64-bit mode (IA32_EFER.LMA = 1 and CS.L = 1).  LOCK, 66/F2/F3 and REX
// before the VEX prefix are #UD in the VEX decoder.  Every encoding is
// VEX.128 with W0, so VEX.L = 1 and VEX.W = 1 are #UD like the other
// VEX.128.W0-only instructions of the model.
val amx_check : Prefixes -> unit
function amx_check(pfx) = {
  if ~(has_amx_tile) then raise_UD();
  if CR4[18] == 0b0 then raise_UD();
  if XCR0[18..17] != 0b11 then raise_UD();
  if cur_mode != LongMode then raise_UD();
  if pfx.vex_l | pfx.vex_w then raise_UD()
}

// A tile register operand: the 4-bit register number (modrm.reg with
// VEX.R, modrm.rm with VEX.B, or VEX.vvvv) must name one of the palette's
// max_names = 8 tiles.
val amx_tile_operand : range(0, 31) -> range(0, 7)
function amx_tile_operand(t) = {
  if t > 7 then raise_UD();
  assert(t <= 7);
  t
}

// A tile is valid when its configuration has rows and colsb both nonzero
// (LDTILECFG rejects one of them being zero).
val amx_tile_valid : range(0, 7) -> bool
function amx_tile_valid(t) = tilecfg_rows[t] != 0x00 & tilecfg_colsb[t] != 0x0000

// The configured shape of a tile, bounded by palette 1 (LDTILECFG checks
// rows <= 16 and colsb <= 64; XRSTOR initializes an unsupported TILECFG).
val amx_rows : range(0, 7) -> range(0, 16)
function amx_rows(t) = {
  let rows = unsigned(tilecfg_rows[t]);
  assert(rows <= 16);
  rows
}

val amx_colsb : range(0, 7) -> range(0, 64)
function amx_colsb(t) = {
  let colsb = unsigned(tilecfg_colsb[t]);
  assert(colsb <= 64);
  colsb
}

// zero_all_tile_data of the SDM.
val amx_zero_all_tiles : unit -> unit
function amx_zero_all_tiles() = {
  foreach (i from 0 to 127) {
    TMM[i] = zeros()
  }
}

// TILECFG in its INIT state: palette 0, TILES_CONFIGURED = 0.
val amx_init_tilecfg : unit -> unit
function amx_init_tilecfg() = {
  tilecfg_palette = 0x00;
  tilecfg_start_row = 0x00;
  foreach (n from 0 to 7) {
    tilecfg_colsb[n] = 0x0000;
    tilecfg_rows[n] = 0x00
  }
}

// write_row_and_zero of the SDM for a full row: the bytes beyond the tile's
// colsb are zero in every row an AMX instruction writes.
val amx_row_keep : range(0, 64) -> zmmword
function amx_row_keep(colsb) = (ones() : zmmword) >> (512 - 8 * colsb)

// LDTILECFG m512 — VEX.128.NP.0F38.W0 49 !(11):000:bbb (AMX-E1).  The
// 64-byte memory image: palette (byte 0), start_row (1), reserved (2-15),
// colsb of tiles 0-7 (words at 16-31), reserved (32-47), rows of tiles 0-7
// (bytes 48-55), reserved (56-63) (SDM Table 1-50).  Every check of the
// pseudocode is made before any state changes, so a #GP leaves the tiles
// as they were.
val exec_ldtilecfg : MemRef -> unit
function exec_ldtilecfg(m) = {
  let buf : bits(512) = read_mem(m);
  let palette : byte = buf[7..0];
  // max_palette = 1; palette 1 needs XCR0[18:17] = 11b, checked already
  var error : bool = palette >_u 0x01;
  if palette != 0x00 then {
    if buf[127..16] != zeros() then error = true;
    foreach (n from 0 to 7) {
      let colsb : word = velem(16, buf, 8 + n);
      if colsb >_u 0x0040 then error = true
    };
    if buf[383..256] != zeros() then error = true;
    foreach (n from 0 to 7) {
      let rows : byte = velem(8, buf, 48 + n);
      if rows >_u 0x10 then error = true
    };
    if buf[511..448] != zeros() then error = true;
    // one of rows or colsb zero but not both
    foreach (n from 0 to 7) {
      let colsb : word = velem(16, buf, 8 + n);
      let rows : byte = velem(8, buf, 48 + n);
      if (rows == 0x00) != (colsb == 0x0000) then error = true
    }
  };
  if error then raise_GP0();
  if palette == 0x00 then {
    amx_init_tilecfg()
  } else {
    tilecfg_palette = palette;
    tilecfg_start_row = buf[15..8];
    foreach (n from 0 to 7) {
      tilecfg_colsb[n] = velem(16, buf, 8 + n);
      tilecfg_rows[n] = velem(8, buf, 48 + n)
    }
  };
  amx_zero_all_tiles()
}

// STTILECFG m512 — VEX.128.66.0F38.W0 49 !(11):000:bbb (AMX-E2): the
// LDTILECFG image of the configuration, or 64 bytes of zeros when the
// tiles are not configured.
val exec_sttilecfg : MemRef -> unit
function exec_sttilecfg(m) = {
  var buf : bits(512) = zeros();
  if tilecfg_palette != 0x00 then {
    buf[7..0] = tilecfg_palette;
    buf[15..8] = tilecfg_start_row;
    foreach (n from 0 to 7) {
      buf[(16 * n + 143) .. (16 * n + 128)] = tilecfg_colsb[n];
      buf[(8 * n + 391) .. (8 * n + 384)] = tilecfg_rows[n]
    }
  };
  write_mem(m, buf)
}

// TILERELEASE — VEX.128.NP.0F38.W0 49 C0 (AMX-E6): TILECFG and TILEDATA
// back to their INIT state.
val exec_tilerelease : unit -> unit
function exec_tilerelease() = {
  amx_zero_all_tiles();
  amx_init_tilecfg()
}

// TILEZERO tmm1 — VEX.128.F2.0F38.W0 49 11:rrr:000 (AMX-E5).
val exec_tilezero : range(0, 7) -> unit
function exec_tilezero(t) = {
  if tilecfg_palette == 0x00 then raise_UD();
  if ~(amx_tile_valid(t)) then raise_UD();
  foreach (r from 0 to 15) {
    TMM[16 * t + r] = zeros()
  };
  tilecfg_start_row = 0x00
}

// The sibmem operand of TILELOADD/TILELOADDT1/TILESTORED: SIB addressing
// is required (#UD otherwise), base + displacement is the address of row
// 0 and index << scale the stride between rows, zero when the SIB encodes
// no index register (index = 100b without VEX.X).  SS is the default
// segment for a base of rSP or rBP (SDM Vol.1 Table 3-5).  Returns the
// row-0 operand and the stride.
val amx_decode_sibmem : (byte, Prefixes) -> (MemRef, qword)
function amx_decode_sibmem(modrm, pfx) = {
  let modbits : range(0, 3) = unsigned(modrm[7..6]);
  if modbits == 3 | modrm[2..0] != 0b100 then raise_UD();
  let sib : byte = fetch(1);
  let scale : range(0, 3) = unsigned(sib[7..6]);
  let base_idx : gpr_idx = unsigned(pfx.rex_b @ sib[2..0]);
  let index_idx : gpr_idx = unsigned(pfx.rex_x @ sib[5..3]);
  // mod = 00 with base = 101: no base register, disp32 follows
  let no_base : bool = sib[2..0] == 0b101 & modbits == 0;
  let base_val : qword = if no_base then zeros() else v(64, base_idx);
  let disp : qword = match modbits {
    0 => if no_base then sign_extend(fetch(4)) else zeros(),
    1 => sign_extend(fetch(1)),
    _ => sign_extend(fetch(4)),
  };
  let stride : qword =
    if sib[5..3] == 0b100 & pfx.rex_x == 0b0 then zeros() else v(64, index_idx) << scale;
  let default_seg : segreg_idx =
    if (sib[2..0] == 0b100 | sib[2..0] == 0b101) & ~(no_base) then SS else DS;
  (struct { seg = resolve_seg(pfx, default_seg), addr = base_val + disp }, stride)
}

// The address of dword j of row r: row 0 plus r strides, truncated to 32
// bits under a 67H prefix like every other effective address.
val amx_row_dword : (MemRef, qword, range(0, 15), range(0, 15), Prefixes) -> MemRef
function amx_row_dword(m, stride, r, j, pfx) = {
  let ea : qword = get_slice_int(64, unsigned(m.addr) + r * unsigned(stride) + 4 * j, 0);
  let ad_keep : qword = sign_extend(~(pfx.has_adsize));
  struct { seg = m.seg, addr = ea & (ad_keep | 0x00000000FFFFFFFF) }
}

// The AMX-E3 checks of a tile load or store on tile t: tiles configured,
// t valid, colsb a multiple of 4, and the restart row inside the tile.
// Returns (start_row, rows, colsb / 4).
val amx_check_load_store : range(0, 7) -> (range(0, 15), range(1, 16), range(1, 16))
function amx_check_load_store(t) = {
  if tilecfg_palette == 0x00 then raise_UD();
  if ~(amx_tile_valid(t)) then raise_UD();
  let rows = amx_rows(t);
  let colsb = amx_colsb(t);
  if colsb % 4 != 0 then raise_UD();
  let start = unsigned(tilecfg_start_row);
  if start >= rows then raise_UD();
  assert(1 <= rows & 4 <= colsb & start <= 15);
  (start, rows, colsb / 4)
}

// TILELOADD tmm1, sibmem — VEX.128.F2.0F38.W0 4B !(11):rrr:100;
// TILELOADDT1 — VEX.128.66.0F38.W0 4B (a caching hint) (AMX-E3).  Rows
// from TILECFG.start_row up are zeroed and then loaded, colsb bytes each,
// so the bytes beyond colsb and the rows beyond rows are zero; the rows
// below start_row, loaded before the fault that set it, are kept.  The
// restart row is written before each row's accesses, so a memory fault
// on a row leaves that row in start_row (SDM: "tilecfg.start_row :=
// start"), and cleared once every row is done.
val exec_tileloadd : (range(0, 7), MemRef, qword, Prefixes) -> unit
function exec_tileloadd(t, m, stride, pfx) = {
  let (start, rows, ndw) = amx_check_load_store(t);
  foreach (r from start to 15) {
    TMM[16 * t + r] = zeros()
  };
  foreach (r from start to rows - 1) {
    tilecfg_start_row = to_bits(8, r);
    var row : zmmword = zeros();
    foreach (j from 0 to ndw - 1) {
      row[(32 * j + 31) .. (32 * j)] = read_mem(32, amx_row_dword(m, stride, r, j, pfx))
    };
    TMM[16 * t + r] = row
  };
  tilecfg_start_row = 0x00
}

// TILESTORED sibmem, tmm1 — VEX.128.F3.0F38.W0 4B !(11):rrr:100 (AMX-E3):
// rows from TILECFG.start_row to rows - 1, colsb bytes each, with the
// same restart-row bookkeeping as TILELOADD.
val exec_tilestored : (range(0, 7), MemRef, qword, Prefixes) -> unit
function exec_tilestored(t, m, stride, pfx) = {
  let (start, rows, ndw) = amx_check_load_store(t);
  foreach (r from start to rows - 1) {
    tilecfg_start_row = to_bits(8, r);
    let row : zmmword = TMM[16 * t + r];
    foreach (j from 0 to ndw - 1) {
      write_mem(amx_row_dword(m, stride, r, j, pfx), velem(32, row, j))
    }
  };
  tilecfg_start_row = 0x00
}

// The AMX-E4 checks of a TMUL instruction C[M][N] += A[M][K] * B[K][N] on
// tiles dst (C), src1 (A) and src2 (B): distinct, configured and valid
// tiles with colsb multiples of 4, C and B of the same width, C and A of
// the same height, A's dwords per row equal to B's rows, and the width
// and depth within tmul_maxn = 64 bytes and tmul_maxk = 16.  Returns
// (M, K, N) with K and N counted in dwords.
val amx_check_tmul : (range(0, 7), range(0, 7), range(0, 7)) -> (range(1, 16), range(1, 16), range(1, 16))
function amx_check_tmul(dst, src1, src2) = {
  if dst == src1 | src1 == src2 | dst == src2 then raise_UD();
  if tilecfg_palette == 0x00 then raise_UD();
  if ~(amx_tile_valid(dst)) | ~(amx_tile_valid(src1)) | ~(amx_tile_valid(src2)) then raise_UD();
  let dst_colsb = amx_colsb(dst);
  let src1_colsb = amx_colsb(src1);
  let src2_colsb = amx_colsb(src2);
  if dst_colsb % 4 != 0 | src1_colsb % 4 != 0 | src2_colsb % 4 != 0 then raise_UD();
  if dst_colsb != src2_colsb then raise_UD();
  if amx_rows(dst) != amx_rows(src1) then raise_UD();
  if src1_colsb / 4 != amx_rows(src2) then raise_UD();
  // tmul_maxn and tmul_maxk hold for every palette-1 shape (colsb <= 64,
  // rows <= 16), so the four limit checks of the class cannot fail here.
  let m_rows = amx_rows(dst);
  assert(1 <= m_rows & 4 <= src1_colsb & 4 <= dst_colsb);
  (m_rows, src1_colsb / 4, dst_colsb / 4)
}

// DPBD of the SDM: c plus the four byte products of x and y, each byte
// sign- or zero-extended as the instruction's letters say, modulo 2^32.
val amx_dpbd : (bool, bool, dword, dword, dword) -> dword
function amx_dpbd(x_signed, y_signed, c, x, y) = {
  var sum : int = unsigned(c);
  foreach (i from 0 to 3) {
    let xb : byte = velem(8, x, i);
    let yb : byte = velem(8, y, i);
    let xv : int = if x_signed then signed(xb) else unsigned(xb);
    let yv : int = if y_signed then signed(yb) else unsigned(yb);
    sum = sum + xv * yv
  };
  get_slice_int(32, sum, 0)
}

// TDPBSSD/TDPBSUD/TDPBUSD/TDPBUUD tmm1, tmm2, tmm3 — VEX.128.F2/F3/66/NP
// .0F38.W0 5E 11:rrr:bbb (AMX-E4).  tmm2 (ModRM:r/m) is A, tmm3 (VEX.vvvv)
// is B; the first letter gives the signedness of A's bytes, the second
// that of B's.  Each row of C is accumulated in a temporary and written
// back with the bytes beyond colsb zero; the rows beyond rows are zeroed.
val exec_tdpbd : (bool, bool, range(0, 7), range(0, 7), range(0, 7)) -> unit
function exec_tdpbd(a_signed, b_signed, dst, src1, src2) = {
  let (m_rows, k, n) = amx_check_tmul(dst, src1, src2);
  foreach (m from 0 to m_rows - 1) {
    var acc : zmmword = TMM[16 * dst + m];
    foreach (kk from 0 to k - 1) {
      let a : dword = velem(32, TMM[16 * src1 + m], kk);
      let b_row : zmmword = TMM[16 * src2 + kk];
      foreach (nn from 0 to n - 1) {
        let lo = 32 * nn;
        acc[(lo + 31) .. lo] = amx_dpbd(a_signed, b_signed, acc[(lo + 31) .. lo], a, velem(32, b_row, nn))
      }
    };
    TMM[16 * dst + m] = acc & amx_row_keep(4 * n)
  };
  foreach (r from m_rows to 15) {
    TMM[16 * dst + r] = zeros()
  };
  tilecfg_start_row = 0x00
}

// make_fp32 of the SDM: a BF16 value is the high half of an FP32 value.
val amx_bf16_to_fp32 : word -> dword
function amx_bf16_to_fp32(x) = x @ 0x0000

// TDPBF16PS tmm1, tmm2, tmm3 — VEX.128.F3.0F38.W0 5C 11:rrr:bbb (AMX-E4).
// Every dword of A and B is a pair of BF16 values.  Per row of C the even
// and odd members of the pairs are accumulated in two FP32 temporaries
// over k, their sum is added to C, all with FP32 FMAs and adds under
// DAZ = FTZ = 1 and round-to-nearest-even; MXCSR is neither consulted nor
// updated, so it is set for the computation and restored afterwards.
val exec_tdpbf16ps : (range(0, 7), range(0, 7), range(0, 7)) -> unit
function exec_tdpbf16ps(dst, src1, src2) = {
  let (m_rows, k, n) = amx_check_tmul(dst, src1, src2);
  let saved_mxcsr = __stmxcsr();
  __ldmxcsr(0x00009FC0);  // FTZ, RC = nearest, all exceptions masked, DAZ
  foreach (m from 0 to m_rows - 1) {
    var even : zmmword = zeros();
    var odd : zmmword = zeros();
    foreach (kk from 0 to k - 1) {
      let a : dword = velem(32, TMM[16 * src1 + m], kk);
      let a0 : dword = amx_bf16_to_fp32(a[15..0]);
      let a1 : dword = amx_bf16_to_fp32(a[31..16]);
      let b_row : zmmword = TMM[16 * src2 + kk];
      foreach (nn from 0 to n - 1) {
        let lo = 32 * nn;
        let b : dword = velem(32, b_row, nn);
        even[(lo + 31) .. lo] = fp_fmadd(a0, amx_bf16_to_fp32(b[15..0]), even[(lo + 31) .. lo]);
        odd[(lo + 31) .. lo] = fp_fmadd(a1, amx_bf16_to_fp32(b[31..16]), odd[(lo + 31) .. lo])
      }
    };
    var acc : zmmword = TMM[16 * dst + m];
    foreach (nn from 0 to n - 1) {
      let lo = 32 * nn;
      let pair : dword = fp_add(even[(lo + 31) .. lo], odd[(lo + 31) .. lo]);
      acc[(lo + 31) .. lo] = fp_add(acc[(lo + 31) .. lo], pair)
    };
    TMM[16 * dst + m] = acc & amx_row_keep(4 * n)
  };
  foreach (r from m_rows to 15) {
    TMM[16 * dst + r] = zeros()
  };
  __ldmxcsr(saved_mxcsr);
  tilecfg_start_row = 0x00
}

// VEX 0F38 opcodes 49, 4B, 5C and 5E: the AMX instructions, distinguished
// by the mandatory prefix and ModRM.mod.
val dispatch_amx : (range(0, 255), Prefixes) -> unit
function dispatch_amx(op, pfx) = {
  amx_check(pfx);
  let mp = get_mandatory_prefix(pfx);
  let modrm = fetch(1);
  let modbits : range(0, 3) = unsigned(modrm[7..6]);
  let reg : range(0, 15) = unsigned(pfx.rex_r @ modrm[5..3]);
  match op {
    // 0F38 49: LDTILECFG m512 (NP) / STTILECFG m512 (66), both mod != 11
    // with reg = 000; TILERELEASE (NP, ModRM = C0); TILEZERO tmm1 (F2,
    // mod = 11, rm = 000).  None has a VEX.vvvv operand.
    73 => {
      if pfx.vex_vvvv != 0 then raise_UD();
      match (mp, modbits) {
        (MP_NONE, 3) => { if modrm != 0xC0 then raise_UD(); exec_tilerelease() },
        (MP_NONE, _) => {
          if modrm[5..3] != 0b000 then raise_UD();
          match modrm_rm(modrm, pfx) {
            RM_mem(m) => exec_ldtilecfg(m),
            RM_reg(_) => raise_UD(),
          }
        },
        (MP_66, 3) => raise_UD(),
        (MP_66, _) => {
          if modrm[5..3] != 0b000 then raise_UD();
          match modrm_rm(modrm, pfx) {
            RM_mem(m) => exec_sttilecfg(m),
            RM_reg(_) => raise_UD(),
          }
        },
        (MP_F2, 3) => {
          if modrm[2..0] != 0b000 then raise_UD();
          exec_tilezero(amx_tile_operand(reg))
        },
        _ => raise_UD(),
      }
    },

    // 0F38 4B: TILELOADD tmm1, sibmem (F2) / TILELOADDT1 tmm1, sibmem (66)
    // / TILESTORED sibmem, tmm1 (F3); no VEX.vvvv operand.
    75 => {
      if pfx.vex_vvvv != 0 then raise_UD();
      let (m, stride) = amx_decode_sibmem(modrm, pfx);
      let t = amx_tile_operand(reg);
      match mp {
        MP_NONE => raise_UD(),
        MP_66   => exec_tileloadd(t, m, stride, pfx),
        MP_F2   => exec_tileloadd(t, m, stride, pfx),
        MP_F3   => exec_tilestored(t, m, stride, pfx),
      }
    },

    // 0F38 5C: TDPBF16PS tmm1, tmm2, tmm3 (F3, mod = 11) [AMX-BF16]
    92 => {
      if mp != MP_F3 | modbits != 3 then raise_UD();
      if ~(has_amx_bf16) then raise_UD();
      let dst = amx_tile_operand(reg);
      let src1 = amx_tile_operand(unsigned(pfx.rex_b @ modrm[2..0]));
      let src2 = amx_tile_operand(pfx.vex_vvvv);
      exec_tdpbf16ps(dst, src1, src2)
    },

    // 0F38 5E: TDPBSSD (F2) / TDPBSUD (F3) / TDPBUSD (66) / TDPBUUD (NP)
    // tmm1, tmm2, tmm3, mod = 11 [AMX-INT8]
    94 => {
      if modbits != 3 then raise_UD();
      if ~(has_amx_int8) then raise_UD();
      let dst = amx_tile_operand(reg);
      let src1 = amx_tile_operand(unsigned(pfx.rex_b @ modrm[2..0]));
      let src2 = amx_tile_operand(pfx.vex_vvvv);
      match mp {
        MP_NONE => exec_tdpbd(false, false, dst, src1, src2),
        MP_66   => exec_tdpbd(false, true, dst, src1, src2),
        MP_F2   => exec_tdpbd(true, true, dst, src1, src2),
        MP_F3   => exec_tdpbd(true, false, dst, src1, src2),
      }
    },

    _ => raise_UD(),
  }
}
