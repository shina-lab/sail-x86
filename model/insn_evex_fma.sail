/* ---- 2-source word permute (VPERMI2W/VPERMT2W) ---- */

// gather_addr and gather_addr_q are defined in insn_sse4_helpers.sail

// VPGATHERDD / VGATHERDPS: 32-bit indices, 32-bit elements
// ZMM: 16 elements, mask is 16 bits

val exec_gather_d32_512 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_d32_512(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : zmmword = read_zmm(dst);
  let indices : zmmword = read_zmm(vsib.vsib_vidx);
  foreach (i from 0 to 15) {
    let lo : range(0, 480) = i * 32;
    if mask[i] == bitone then {
      let idx : dword = indices[(lo + 31)..lo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : dword = mem_read32(addr);
      result = [result with (lo + 31)..lo = v];
    }
  };
  write_zmm(dst, result);
  write_kreg(k_idx, zeros()); // all mask bits cleared
  Ok()
}

val exec_gather_d32_256 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_d32_256(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : ymmword = read_ymm(dst);
  let indices : ymmword = read_ymm(vsib.vsib_vidx);
  foreach (i from 0 to 7) {
    let lo : range(0, 224) = i * 32;
    if mask[i] == bitone then {
      let idx : dword = indices[(lo + 31)..lo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : dword = mem_read32(addr);
      result = [result with (lo + 31)..lo = v];
    }
  };
  write_ymm(dst, result);
  write_kreg(k_idx, zeros());
  Ok()
}

val exec_gather_d32_128 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_d32_128(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : xmmword = read_xmm(dst);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    if mask[i] == bitone then {
      let idx : dword = indices[(lo + 31)..lo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : dword = mem_read32(addr);
      result = [result with (lo + 31)..lo = v];
    }
  };
  write_xmm(dst, result);
  write_kreg(k_idx, zeros());
  Ok()
}

// VPGATHERDQ / VGATHERDPD: 32-bit indices, 64-bit elements
// ZMM: 8 qword elements, indices from YMM (8 dwords)

val exec_gather_d64_512 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_d64_512(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : zmmword = read_zmm(dst);
  let indices : ymmword = read_ymm(vsib.vsib_vidx);
  foreach (i from 0 to 7) {
    let ilo : range(0, 224) = i * 32;
    let olo : range(0, 448) = i * 64;
    if mask[i] == bitone then {
      let idx : dword = indices[(ilo + 31)..ilo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : qword = mem_read64(addr);
      result = [result with (olo + 63)..olo = v];
    }
  };
  write_zmm(dst, result);
  write_kreg(k_idx, zeros());
  Ok()
}

val exec_gather_d64_256 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_d64_256(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : ymmword = read_ymm(dst);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 3) {
    let ilo : range(0, 96) = i * 32;
    let olo : range(0, 192) = i * 64;
    if mask[i] == bitone then {
      let idx : dword = indices[(ilo + 31)..ilo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : qword = mem_read64(addr);
      result = [result with (olo + 63)..olo = v];
    }
  };
  write_ymm(dst, result);
  write_kreg(k_idx, zeros());
  Ok()
}

val exec_gather_d64_128 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_d64_128(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : xmmword = read_xmm(dst);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 1) {
    let ilo : range(0, 32) = i * 32;
    let olo : range(0, 64) = i * 64;
    if mask[i] == bitone then {
      let idx : dword = indices[(ilo + 31)..ilo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : qword = mem_read64(addr);
      result = [result with (olo + 63)..olo = v];
    }
  };
  write_xmm(dst, result);
  write_kreg(k_idx, zeros());
  Ok()
}

// VPGATHERQD / VGATHERQPS: 64-bit indices, 32-bit elements
// ZMM index: 8 qwords → 8 dword results in YMM

val exec_gather_q32_512 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_q32_512(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : ymmword = read_ymm(dst);
  let indices : zmmword = read_zmm(vsib.vsib_vidx);
  foreach (i from 0 to 7) {
    let ilo : range(0, 448) = i * 64;
    let olo : range(0, 224) = i * 32;
    if mask[i] == bitone then {
      let idx : qword = indices[(ilo + 63)..ilo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : dword = mem_read32(addr);
      result = [result with (olo + 31)..olo = v];
    }
  };
  write_ymm(dst, result);
  write_kreg(k_idx, zeros());
  Ok()
}

val exec_gather_q32_256 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_q32_256(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : xmmword = read_xmm(dst);
  let indices : ymmword = read_ymm(vsib.vsib_vidx);
  foreach (i from 0 to 3) {
    let ilo : range(0, 192) = i * 64;
    let olo : range(0, 96) = i * 32;
    if mask[i] == bitone then {
      let idx : qword = indices[(ilo + 63)..ilo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : dword = mem_read32(addr);
      result = [result with (olo + 31)..olo = v];
    }
  };
  // Write as XMM (zero-extends upper)
  write_xmm(dst, result);
  write_kreg(k_idx, zeros());
  Ok()
}

val exec_gather_q32_128 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_q32_128(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : xmmword = read_xmm(dst);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 1) {
    let ilo : range(0, 64) = i * 64;
    let olo : range(0, 32) = i * 32;
    if mask[i] == bitone then {
      let idx : qword = indices[(ilo + 63)..ilo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : dword = mem_read32(addr);
      result = [result with (olo + 31)..olo = v];
    }
  };
  write_xmm(dst, result);
  write_kreg(k_idx, zeros());
  Ok()
}

// VPGATHERQQ / VGATHERQPD: 64-bit indices, 64-bit elements

val exec_gather_q64_512 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_q64_512(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : zmmword = read_zmm(dst);
  let indices : zmmword = read_zmm(vsib.vsib_vidx);
  foreach (i from 0 to 7) {
    let lo : range(0, 448) = i * 64;
    if mask[i] == bitone then {
      let idx : qword = indices[(lo + 63)..lo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : qword = mem_read64(addr);
      result = [result with (lo + 63)..lo = v];
    }
  };
  write_zmm(dst, result);
  write_kreg(k_idx, zeros());
  Ok()
}

val exec_gather_q64_256 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_q64_256(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : ymmword = read_ymm(dst);
  let indices : ymmword = read_ymm(vsib.vsib_vidx);
  foreach (i from 0 to 3) {
    let lo : range(0, 192) = i * 64;
    if mask[i] == bitone then {
      let idx : qword = indices[(lo + 63)..lo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : qword = mem_read64(addr);
      result = [result with (lo + 63)..lo = v];
    }
  };
  write_ymm(dst, result);
  write_kreg(k_idx, zeros());
  Ok()
}

val exec_gather_q64_128 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_gather_q64_128(dst, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  var result : xmmword = read_xmm(dst);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    if mask[i] == bitone then {
      let idx : qword = indices[(lo + 63)..lo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      let v : qword = mem_read64(addr);
      result = [result with (lo + 63)..lo = v];
    }
  };
  write_xmm(dst, result);
  write_kreg(k_idx, zeros());
  Ok()
}

/* ---- Scatter: VPSCATTERDD/DQ, VSCATTERDPS/DPD (dword indices) ---- */
/* ---- Scatter: VPSCATTERQD/QQ, VSCATTERQPS/QPD (qword indices) ---- */

// VPSCATTERDD / VSCATTERDPS: 32-bit indices, 32-bit elements

val exec_scatter_d32_512 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_d32_512(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : zmmword = read_zmm(src);
  let indices : zmmword = read_zmm(vsib.vsib_vidx);
  foreach (i from 0 to 15) {
    let lo : range(0, 480) = i * 32;
    if mask[i] == bitone then {
      let idx : dword = indices[(lo + 31)..lo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write32(addr, data[(lo + 31)..lo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok()
}

val exec_scatter_d32_256 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_d32_256(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : ymmword = read_ymm(src);
  let indices : ymmword = read_ymm(vsib.vsib_vidx);
  foreach (i from 0 to 7) {
    let lo : range(0, 224) = i * 32;
    if mask[i] == bitone then {
      let idx : dword = indices[(lo + 31)..lo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write32(addr, data[(lo + 31)..lo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok()
}

val exec_scatter_d32_128 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_d32_128(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : xmmword = read_xmm(src);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    if mask[i] == bitone then {
      let idx : dword = indices[(lo + 31)..lo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write32(addr, data[(lo + 31)..lo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok()
}

// VPSCATTERDQ / VSCATTERDPD: 32-bit indices, 64-bit elements

val exec_scatter_d64_512 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_d64_512(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : zmmword = read_zmm(src);
  let indices : ymmword = read_ymm(vsib.vsib_vidx);
  foreach (i from 0 to 7) {
    let ilo : range(0, 224) = i * 32;
    let olo : range(0, 448) = i * 64;
    if mask[i] == bitone then {
      let idx : dword = indices[(ilo + 31)..ilo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write64(addr, data[(olo + 63)..olo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok()
}

val exec_scatter_d64_256 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_d64_256(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : ymmword = read_ymm(src);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 3) {
    let ilo : range(0, 96) = i * 32;
    let olo : range(0, 192) = i * 64;
    if mask[i] == bitone then {
      let idx : dword = indices[(ilo + 31)..ilo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write64(addr, data[(olo + 63)..olo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok()
}

val exec_scatter_d64_128 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_d64_128(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : xmmword = read_xmm(src);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 1) {
    let ilo : range(0, 32) = i * 32;
    let olo : range(0, 64) = i * 64;
    if mask[i] == bitone then {
      let idx : dword = indices[(ilo + 31)..ilo];
      let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write64(addr, data[(olo + 63)..olo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok()
}

// VPSCATTERQD / VSCATTERQPS: 64-bit indices, 32-bit elements

val exec_scatter_q32_512 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_q32_512(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : ymmword = read_ymm(src);
  let indices : zmmword = read_zmm(vsib.vsib_vidx);
  foreach (i from 0 to 7) {
    let ilo : range(0, 448) = i * 64;
    let olo : range(0, 224) = i * 32;
    if mask[i] == bitone then {
      let idx : qword = indices[(ilo + 63)..ilo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write32(addr, data[(olo + 31)..olo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok()
}

val exec_scatter_q32_256 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_q32_256(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : xmmword = read_xmm(src);
  let indices : ymmword = read_ymm(vsib.vsib_vidx);
  foreach (i from 0 to 3) {
    let ilo : range(0, 192) = i * 64;
    let olo : range(0, 96) = i * 32;
    if mask[i] == bitone then {
      let idx : qword = indices[(ilo + 63)..ilo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write32(addr, data[(olo + 31)..olo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok()
}

val exec_scatter_q32_128 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_q32_128(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : xmmword = read_xmm(src);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 1) {
    let ilo : range(0, 64) = i * 64;
    let olo : range(0, 32) = i * 32;
    if mask[i] == bitone then {
      let idx : qword = indices[(ilo + 63)..ilo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write32(addr, data[(olo + 31)..olo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok()
}

// VPSCATTERQQ / VSCATTERQPD: 64-bit indices, 64-bit elements

val exec_scatter_q64_512 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_q64_512(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : zmmword = read_zmm(src);
  let indices : zmmword = read_zmm(vsib.vsib_vidx);
  foreach (i from 0 to 7) {
    let lo : range(0, 448) = i * 64;
    if mask[i] == bitone then {
      let idx : qword = indices[(lo + 63)..lo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write64(addr, data[(lo + 63)..lo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok()
}

val exec_scatter_q64_256 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_q64_256(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : ymmword = read_ymm(src);
  let indices : ymmword = read_ymm(vsib.vsib_vidx);
  foreach (i from 0 to 3) {
    let lo : range(0, 192) = i * 64;
    if mask[i] == bitone then {
      let idx : qword = indices[(lo + 63)..lo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write64(addr, data[(lo + 63)..lo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok()
}

val exec_scatter_q64_128 : (simd_idx, VSIB, kreg_idx) -> ExecutionResult
function exec_scatter_q64_128(src, vsib, k_idx) = {
  let mask : qword = read_kreg(k_idx);
  let data : xmmword = read_xmm(src);
  let indices : xmmword = read_xmm(vsib.vsib_vidx);
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    if mask[i] == bitone then {
      let idx : qword = indices[(lo + 63)..lo];
      let addr = gather_addr_q(vsib.vsib_base, idx, vsib.vsib_scale);
      mem_write64(addr, data[(lo + 63)..lo]);
    }
  };
  write_kreg(k_idx, zeros());
  Ok()
}

/* ---- VPCLMULQDQ: carry-less multiply per 128-bit lane ---- */

val avx_vpmadd52luq_elem : (qword, qword, qword) -> qword
function avx_vpmadd52luq_elem(dst, src1, src2) = {
  let a : int = unsigned(src1[51..0]);
  let b : int = unsigned(src2[51..0]);
  let product : int = a * b;
  let low52 : qword = get_slice_int(64, product, 0);
  // Add low 52 bits of product to dst, keep result as 64-bit
  let sum : int = unsigned(dst) + unsigned(low52[51..0] : bits(52));
  get_slice_int(64, sum, 0)
}

val avx_vpmadd52huq_elem : (qword, qword, qword) -> qword
function avx_vpmadd52huq_elem(dst, src1, src2) = {
  let a : int = unsigned(src1[51..0]);
  let b : int = unsigned(src2[51..0]);
  let product : int = a * b;
  let high52 : qword = get_slice_int(64, product, 52);
  let sum : int = unsigned(dst) + unsigned(high52[51..0] : bits(52));
  get_slice_int(64, sum, 0)
}

val avx_vpmadd52luq_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpmadd52luq_128(dst, src1, src2) = {
  avx_vpmadd52luq_elem(dst[127..64], src1[127..64], src2[127..64]) @
  avx_vpmadd52luq_elem(dst[63..0], src1[63..0], src2[63..0])
}

val avx_vpmadd52luq_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpmadd52luq_256(dst, src1, src2) = {
  avx_vpmadd52luq_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpmadd52luq_128(dst[127..0], src1[127..0], src2[127..0])
}

val avx_vpmadd52luq_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpmadd52luq_512(dst, src1, src2) = {
  avx_vpmadd52luq_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpmadd52luq_256(dst[255..0], src1[255..0], src2[255..0])
}

val avx_vpmadd52huq_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpmadd52huq_128(dst, src1, src2) = {
  avx_vpmadd52huq_elem(dst[127..64], src1[127..64], src2[127..64]) @
  avx_vpmadd52huq_elem(dst[63..0], src1[63..0], src2[63..0])
}

val avx_vpmadd52huq_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpmadd52huq_256(dst, src1, src2) = {
  avx_vpmadd52huq_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpmadd52huq_128(dst[127..0], src1[127..0], src2[127..0])
}

val avx_vpmadd52huq_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpmadd52huq_512(dst, src1, src2) = {
  avx_vpmadd52huq_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpmadd52huq_256(dst[255..0], src1[255..0], src2[255..0])
}

/* ---- VPMULTISHIFTQB: multi-shift qword bytes (VBMI) ---- */
// For each byte in src1 (shift control), extract 8 consecutive bits from src2 qword
// starting at bit position = src1_byte[5:0], within the same 64-bit lane.

val avx_gf2p8mulb_128 : (xmmword, xmmword) -> xmmword
function avx_gf2p8mulb_128(src1, src2) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    r[(lo + 7)..lo] = gf2p8_mul(src1[(lo + 7)..lo], src2[(lo + 7)..lo]);
  };
  r
}

val avx_gf2p8mulb_256 : (ymmword, ymmword) -> ymmword
function avx_gf2p8mulb_256(src1, src2) = {
  avx_gf2p8mulb_128(src1[255..128], src2[255..128]) @
  avx_gf2p8mulb_128(src1[127..0], src2[127..0])
}

val avx_gf2p8mulb_512 : (zmmword, zmmword) -> zmmword
function avx_gf2p8mulb_512(src1, src2) = {
  avx_gf2p8mulb_256(src1[511..256], src2[511..256]) @
  avx_gf2p8mulb_256(src1[255..0], src2[255..0])
}

// GF2P8AFFINEQB: For each byte in src1, compute an affine transformation
// using an 8x8 bit matrix from the corresponding qword of src2, then XOR with imm8.
// result_byte[i] = popcount(src1_byte & matrix_row[i]) ^ imm8[i]
// where matrix_row[i] is the i-th byte of the qword (MSB first: row0 = qword[63:56])

val avx_vexp2ps_512 : zmmword -> zmmword
function avx_vexp2ps_512(src) = {
  __f32_exp2(src[511..480]) @ __f32_exp2(src[479..448]) @
  __f32_exp2(src[447..416]) @ __f32_exp2(src[415..384]) @
  __f32_exp2(src[383..352]) @ __f32_exp2(src[351..320]) @
  __f32_exp2(src[319..288]) @ __f32_exp2(src[287..256]) @
  __f32_exp2(src[255..224]) @ __f32_exp2(src[223..192]) @
  __f32_exp2(src[191..160]) @ __f32_exp2(src[159..128]) @
  __f32_exp2(src[127..96])  @ __f32_exp2(src[95..64])   @
  __f32_exp2(src[63..32])   @ __f32_exp2(src[31..0])
}

val avx_vexp2pd_512 : zmmword -> zmmword
function avx_vexp2pd_512(src) = {
  __f64_exp2(src[511..448]) @ __f64_exp2(src[447..384]) @
  __f64_exp2(src[383..320]) @ __f64_exp2(src[319..256]) @
  __f64_exp2(src[255..192]) @ __f64_exp2(src[191..128]) @
  __f64_exp2(src[127..64])  @ __f64_exp2(src[63..0])
}

// =========================================================================
// VRCP28PS/PD/SS/SD — Approximate Reciprocal (28 bits, AVX-512ER / KNL)
// =========================================================================

val avx_vrcp28ps_512 : zmmword -> zmmword
function avx_vrcp28ps_512(src) = {
  __f32_rcp28(src[511..480]) @ __f32_rcp28(src[479..448]) @
  __f32_rcp28(src[447..416]) @ __f32_rcp28(src[415..384]) @
  __f32_rcp28(src[383..352]) @ __f32_rcp28(src[351..320]) @
  __f32_rcp28(src[319..288]) @ __f32_rcp28(src[287..256]) @
  __f32_rcp28(src[255..224]) @ __f32_rcp28(src[223..192]) @
  __f32_rcp28(src[191..160]) @ __f32_rcp28(src[159..128]) @
  __f32_rcp28(src[127..96])  @ __f32_rcp28(src[95..64])   @
  __f32_rcp28(src[63..32])   @ __f32_rcp28(src[31..0])
}

val avx_vrcp28pd_512 : zmmword -> zmmword
function avx_vrcp28pd_512(src) = {
  __f64_rcp28(src[511..448]) @ __f64_rcp28(src[447..384]) @
  __f64_rcp28(src[383..320]) @ __f64_rcp28(src[319..256]) @
  __f64_rcp28(src[255..192]) @ __f64_rcp28(src[191..128]) @
  __f64_rcp28(src[127..64])  @ __f64_rcp28(src[63..0])
}

// =========================================================================
// VRSQRT28PS/PD/SS/SD — Approximate Reciprocal Square Root (28 bits, AVX-512ER / KNL)
// =========================================================================

val avx_vrsqrt28ps_512 : zmmword -> zmmword
function avx_vrsqrt28ps_512(src) = {
  __f32_rsqrt28(src[511..480]) @ __f32_rsqrt28(src[479..448]) @
  __f32_rsqrt28(src[447..416]) @ __f32_rsqrt28(src[415..384]) @
  __f32_rsqrt28(src[383..352]) @ __f32_rsqrt28(src[351..320]) @
  __f32_rsqrt28(src[319..288]) @ __f32_rsqrt28(src[287..256]) @
  __f32_rsqrt28(src[255..224]) @ __f32_rsqrt28(src[223..192]) @
  __f32_rsqrt28(src[191..160]) @ __f32_rsqrt28(src[159..128]) @
  __f32_rsqrt28(src[127..96])  @ __f32_rsqrt28(src[95..64])   @
  __f32_rsqrt28(src[63..32])   @ __f32_rsqrt28(src[31..0])
}

val avx_vrsqrt28pd_512 : zmmword -> zmmword
function avx_vrsqrt28pd_512(src) = {
  __f64_rsqrt28(src[511..448]) @ __f64_rsqrt28(src[447..384]) @
  __f64_rsqrt28(src[383..320]) @ __f64_rsqrt28(src[319..256]) @
  __f64_rsqrt28(src[255..192]) @ __f64_rsqrt28(src[191..128]) @
  __f64_rsqrt28(src[127..64])  @ __f64_rsqrt28(src[63..0])
}

// VGETEXPPD — Convert Exponents of Packed Float64 Values to Float64 Values (AVX-512)
// VGETEXPPS — Convert Exponents of Packed Float32 Values to Float32 Values (AVX-512)
// VGETEXPSD — Convert Exponent of Scalar Float64 Value to Float64 Value (AVX-512)
// VGETEXPSS — Convert Exponent of Scalar Float32 Value to Float32 Value (AVX-512)
//
// These instructions convert the biased exponent of each FP element to an
// FP value representing the unbiased integer exponent.

// =========================================================================
// Packed PS (float32) helpers: 128 -> 256 -> 512
// =========================================================================

val vgetexpps_xmm : xmmword -> xmmword
function vgetexpps_xmm(a) =
  __f32_getexp(a[127..96]) @ __f32_getexp(a[95..64]) @
  __f32_getexp(a[63..32])  @ __f32_getexp(a[31..0])

val vgetexpps_ymm : ymmword -> ymmword
function vgetexpps_ymm(a) =
  vgetexpps_xmm(a[255..128]) @ vgetexpps_xmm(a[127..0])

val vgetexpps_zmm : zmmword -> zmmword
function vgetexpps_zmm(a) =
  vgetexpps_ymm(a[511..256]) @ vgetexpps_ymm(a[255..0])

// =========================================================================
// Packed PD (float64) helpers: 128 -> 256 -> 512
// =========================================================================

val vgetexppd_xmm : xmmword -> xmmword
function vgetexppd_xmm(a) =
  __f64_getexp(a[127..64]) @ __f64_getexp(a[63..0])

val vgetexppd_ymm : ymmword -> ymmword
function vgetexppd_ymm(a) =
  vgetexppd_xmm(a[255..128]) @ vgetexppd_xmm(a[127..0])

val vgetexppd_zmm : zmmword -> zmmword
function vgetexppd_zmm(a) =
  vgetexppd_ymm(a[511..256]) @ vgetexppd_ymm(a[255..0])

// VRCP14PD — Compute Approximate Reciprocals of Packed Float64 Values (AVX-512)
// VRCP14PS — Compute Approximate Reciprocals of Packed Float32 Values (AVX-512)
// VRCP14SD — Compute Approximate Reciprocal of Scalar Float64 Value (AVX-512)
// VRCP14SS — Compute Approximate Reciprocal of Scalar Float32 Value (AVX-512)
//
// These instructions compute approximate reciprocals with a relative error
// bound of 2^-14.

// =========================================================================
// Packed PS (float32) helpers: 128 -> 256 -> 512
// =========================================================================

val vrcp14ps_xmm : xmmword -> xmmword
function vrcp14ps_xmm(a) =
  __f32_rcp14(a[127..96]) @ __f32_rcp14(a[95..64]) @
  __f32_rcp14(a[63..32])  @ __f32_rcp14(a[31..0])

val vrcp14ps_ymm : ymmword -> ymmword
function vrcp14ps_ymm(a) =
  vrcp14ps_xmm(a[255..128]) @ vrcp14ps_xmm(a[127..0])

val vrcp14ps_zmm : zmmword -> zmmword
function vrcp14ps_zmm(a) =
  vrcp14ps_ymm(a[511..256]) @ vrcp14ps_ymm(a[255..0])

// =========================================================================
// Packed PD (float64) helpers: 128 -> 256 -> 512
// =========================================================================

val vrcp14pd_xmm : xmmword -> xmmword
function vrcp14pd_xmm(a) =
  __f64_rcp14(a[127..64]) @ __f64_rcp14(a[63..0])

val vrcp14pd_ymm : ymmword -> ymmword
function vrcp14pd_ymm(a) =
  vrcp14pd_xmm(a[255..128]) @ vrcp14pd_xmm(a[127..0])

val vrcp14pd_zmm : zmmword -> zmmword
function vrcp14pd_zmm(a) =
  vrcp14pd_ymm(a[511..256]) @ vrcp14pd_ymm(a[255..0])

// =========================================================================
// VRCP28 / VRCPPH / VRCPSH stubs (external, no YMM/ZMM infrastructure yet)
// =========================================================================

val vrsqrt14ps_xmm : xmmword -> xmmword
function vrsqrt14ps_xmm(a) =
  __f32_rsqrt14(a[127..96]) @ __f32_rsqrt14(a[95..64]) @
  __f32_rsqrt14(a[63..32])  @ __f32_rsqrt14(a[31..0])

val vrsqrt14ps_ymm : ymmword -> ymmword
function vrsqrt14ps_ymm(a) =
  vrsqrt14ps_xmm(a[255..128]) @ vrsqrt14ps_xmm(a[127..0])

val vrsqrt14ps_zmm : zmmword -> zmmword
function vrsqrt14ps_zmm(a) =
  vrsqrt14ps_ymm(a[511..256]) @ vrsqrt14ps_ymm(a[255..0])

// =========================================================================
// Packed PD (float64) helpers: 128 -> 256 -> 512
// =========================================================================

val vrsqrt14pd_xmm : xmmword -> xmmword
function vrsqrt14pd_xmm(a) =
  __f64_rsqrt14(a[127..64]) @ __f64_rsqrt14(a[63..0])

val vrsqrt14pd_ymm : ymmword -> ymmword
function vrsqrt14pd_ymm(a) =
  vrsqrt14pd_xmm(a[255..128]) @ vrsqrt14pd_xmm(a[127..0])

val vrsqrt14pd_zmm : zmmword -> zmmword
function vrsqrt14pd_zmm(a) =
  vrsqrt14pd_ymm(a[511..256]) @ vrsqrt14pd_ymm(a[255..0])

// =========================================================================
// VRSQRT28 / VRSQRTPH / VRSQRTSH stubs (external, no YMM/ZMM infrastructure yet)
// =========================================================================

val vscalefps_xmm : (xmmword, xmmword) -> xmmword
function vscalefps_xmm(a, b) =
  __f32_scalef(a[127..96], b[127..96]) @
  __f32_scalef(a[95..64],  b[95..64])  @
  __f32_scalef(a[63..32],  b[63..32])  @
  __f32_scalef(a[31..0],   b[31..0])

val vscalefps_ymm : (ymmword, ymmword) -> ymmword
function vscalefps_ymm(a, b) =
  vscalefps_xmm(a[255..128], b[255..128]) @ vscalefps_xmm(a[127..0], b[127..0])

val vscalefps_zmm : (zmmword, zmmword) -> zmmword
function vscalefps_zmm(a, b) =
  vscalefps_ymm(a[511..256], b[511..256]) @ vscalefps_ymm(a[255..0], b[255..0])

// =========================================================================
// Packed PD (float64) helpers: 128 -> 256 -> 512
// =========================================================================

val vscalefpd_xmm : (xmmword, xmmword) -> xmmword
function vscalefpd_xmm(a, b) =
  __f64_scalef(a[127..64], b[127..64]) @ __f64_scalef(a[63..0], b[63..0])

val vscalefpd_ymm : (ymmword, ymmword) -> ymmword
function vscalefpd_ymm(a, b) =
  vscalefpd_xmm(a[255..128], b[255..128]) @ vscalefpd_xmm(a[127..0], b[127..0])

val vscalefpd_zmm : (zmmword, zmmword) -> zmmword
function vscalefpd_zmm(a, b) =
  vscalefpd_ymm(a[511..256], b[511..256]) @ vscalefpd_ymm(a[255..0], b[255..0])

// VPMASKMOV — Conditional SIMD Integer Packed Loads and Stores (AVX2)
//
// Conditionally loads/stores packed dword/qword values using a mask register.
// Modeled as external function (no YMM/ZMM infrastructure).

val dispatch_evex_fma : (range(0, 255), Prefixes) -> ExecutionResult
function dispatch_evex_fma(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {
  // 0F38 90: VPGATHERDD (66,W0) / VPGATHERDQ (66,W1) [F]
  144 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let vsib = decode_vsib_evex(modrm, pfx, 4);
      if pfx.rex_w then { // VPGATHERDQ: dword indices, qword elements
        match pfx.evex_ll {
          2 => exec_gather_d64_512(dst, vsib, pfx.evex_aaa),
          1 => exec_gather_d64_256(dst, vsib, pfx.evex_aaa),
          _ => exec_gather_d64_128(dst, vsib, pfx.evex_aaa),
        }
      } else { // VPGATHERDD: dword indices, dword elements
        match pfx.evex_ll {
          2 => exec_gather_d32_512(dst, vsib, pfx.evex_aaa),
          1 => exec_gather_d32_256(dst, vsib, pfx.evex_aaa),
          _ => exec_gather_d32_128(dst, vsib, pfx.evex_aaa),
        }
      }
    }
  },

  // 0F38 91: VPGATHERQD (66,W0) / VPGATHERQQ (66,W1) [F]
  // 0F38 91: VPGATHERQD (66,W0) / VPGATHERQQ (66,W1) [F]
  145 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let vsib = decode_vsib_evex(modrm, pfx, 4);
      if pfx.rex_w then { // VPGATHERQQ: qword indices, qword elements
        match pfx.evex_ll {
          2 => exec_gather_q64_512(dst, vsib, pfx.evex_aaa),
          1 => exec_gather_q64_256(dst, vsib, pfx.evex_aaa),
          _ => exec_gather_q64_128(dst, vsib, pfx.evex_aaa),
        }
      } else { // VPGATHERQD: qword indices, dword elements
        match pfx.evex_ll {
          2 => exec_gather_q32_512(dst, vsib, pfx.evex_aaa),
          1 => exec_gather_q32_256(dst, vsib, pfx.evex_aaa),
          _ => exec_gather_q32_128(dst, vsib, pfx.evex_aaa),
        }
      }
    }
  },

  // 0F38 92: VGATHERDPS (66,W0) / VGATHERDPD (66,W1) [F]
  // 0F38 92: VGATHERDPS (66,W0) / VGATHERDPD (66,W1) [F]
  146 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let vsib = decode_vsib_evex(modrm, pfx, 4);
      if pfx.rex_w then { // VGATHERDPD: dword indices, f64 elements
        match pfx.evex_ll {
          2 => exec_gather_d64_512(dst, vsib, pfx.evex_aaa),
          1 => exec_gather_d64_256(dst, vsib, pfx.evex_aaa),
          _ => exec_gather_d64_128(dst, vsib, pfx.evex_aaa),
        }
      } else { // VGATHERDPS: dword indices, f32 elements
        match pfx.evex_ll {
          2 => exec_gather_d32_512(dst, vsib, pfx.evex_aaa),
          1 => exec_gather_d32_256(dst, vsib, pfx.evex_aaa),
          _ => exec_gather_d32_128(dst, vsib, pfx.evex_aaa),
        }
      }
    }
  },

  // 0F38 93: VGATHERQPS (66,W0) / VGATHERQPD (66,W1) [F]
  // 0F38 93: VGATHERQPS (66,W0) / VGATHERQPD (66,W1) [F]
  147 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let vsib = decode_vsib_evex(modrm, pfx, 4);
      if pfx.rex_w then { // VGATHERQPD: qword indices, f64 elements
        match pfx.evex_ll {
          2 => exec_gather_q64_512(dst, vsib, pfx.evex_aaa),
          1 => exec_gather_q64_256(dst, vsib, pfx.evex_aaa),
          _ => exec_gather_q64_128(dst, vsib, pfx.evex_aaa),
        }
      } else { // VGATHERQPS: qword indices, f32 elements
        match pfx.evex_ll {
          2 => exec_gather_q32_512(dst, vsib, pfx.evex_aaa),
          1 => exec_gather_q32_256(dst, vsib, pfx.evex_aaa),
          _ => exec_gather_q32_128(dst, vsib, pfx.evex_aaa),
        }
      }
    }
  },

  // =====================================================================
  // FMA 132 forms (0x96-0x9F)
  // =====================================================================

  // 0F38 96: VFMADDSUB132PS (66,W0) / VFMADDSUB132PD (66,W1) [F]
  // 0F38 96: VFMADDSUB132PS (66,W0) / VFMADDSUB132PD (66,W1) [F]
  150 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmaddsub_pd_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok() },
        1 => { write_ymm(dst, avx_fmaddsub_pd_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok() },
        _ => { write_xmm(dst, avx_fmaddsub_pd_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok() },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmaddsub_ps_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok() },
        1 => { write_ymm(dst, avx_fmaddsub_ps_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok() },
        _ => { write_xmm(dst, avx_fmaddsub_ps_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok() },
      }
    }
  },

  // 0F38 97: VFMSUBADD132PS (66,W0) / VFMSUBADD132PD (66,W1) [F]
  // 0F38 97: VFMSUBADD132PS (66,W0) / VFMSUBADD132PD (66,W1) [F]
  151 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsubadd_pd_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok() },
        1 => { write_ymm(dst, avx_fmsubadd_pd_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok() },
        _ => { write_xmm(dst, avx_fmsubadd_pd_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok() },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsubadd_ps_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok() },
        1 => { write_ymm(dst, avx_fmsubadd_ps_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok() },
        _ => { write_xmm(dst, avx_fmsubadd_ps_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok() },
      }
    }
  },

  // 0F38 98: VFMADD132PS (66,W0) / VFMADD132PD (66,W1) [F]
  // 0F38 98: VFMADD132PS (66,W0) / VFMADD132PD (66,W1) [F]
  152 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmadd_pd_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok() },
        1 => { write_ymm(dst, avx_fmadd_pd_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok() },
        _ => { write_xmm(dst, avx_fmadd_pd_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok() },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmadd_ps_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok() },
        1 => { write_ymm(dst, avx_fmadd_ps_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok() },
        _ => { write_xmm(dst, avx_fmadd_ps_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok() },
      }
    }
  },

  // 0F38 99: VFMADD132SS (66,W0) / VFMADD132SD (66,W1) [F]
  // 0F38 99: VFMADD132SS (66,W0) / VFMADD132SD (66,W1) [F]
  153 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfmadd132sd(dst, src2, src3)
      else exec_vfmadd132ss(dst, src2, src3)
    }
  },

  // 0F38 9A: VFMSUB132PS (66,W0) / VFMSUB132PD (66,W1) [F]
  // 0F38 9A: VFMSUB132PS (66,W0) / VFMSUB132PD (66,W1) [F]
  154 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsub_pd_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok() },
        1 => { write_ymm(dst, avx_fmsub_pd_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok() },
        _ => { write_xmm(dst, avx_fmsub_pd_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok() },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsub_ps_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok() },
        1 => { write_ymm(dst, avx_fmsub_ps_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok() },
        _ => { write_xmm(dst, avx_fmsub_ps_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok() },
      }
    }
  },

  // 0F38 9B: VFMSUB132SS (66,W0) / VFMSUB132SD (66,W1) [F]
  // 0F38 9B: VFMSUB132SS (66,W0) / VFMSUB132SD (66,W1) [F]
  155 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfmsub132sd(dst, src2, src3)
      else exec_vfmsub132ss(dst, src2, src3)
    }
  },

  // 0F38 9C: VFNMADD132PS (66,W0) / VFNMADD132PD (66,W1) [F]
  // 0F38 9C: VFNMADD132PS (66,W0) / VFNMADD132PD (66,W1) [F]
  156 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmadd_pd_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok() },
        1 => { write_ymm(dst, avx_fnmadd_pd_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok() },
        _ => { write_xmm(dst, avx_fnmadd_pd_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok() },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmadd_ps_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok() },
        1 => { write_ymm(dst, avx_fnmadd_ps_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok() },
        _ => { write_xmm(dst, avx_fnmadd_ps_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok() },
      }
    }
  },

  // 0F38 9D: VFNMADD132SS (66,W0) / VFNMADD132SD (66,W1) [F]
  // 0F38 9D: VFNMADD132SS (66,W0) / VFNMADD132SD (66,W1) [F]
  157 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfnmadd132sd(dst, src2, src3)
      else exec_vfnmadd132ss(dst, src2, src3)
    }
  },

  // 0F38 9E: VFNMSUB132PS (66,W0) / VFNMSUB132PD (66,W1) [F]
  // 0F38 9E: VFNMSUB132PS (66,W0) / VFNMSUB132PD (66,W1) [F]
  158 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmsub_pd_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok() },
        1 => { write_ymm(dst, avx_fnmsub_pd_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok() },
        _ => { write_xmm(dst, avx_fnmsub_pd_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok() },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmsub_ps_512(read_zmm(dst), evex_src_zmm(modrm, rm, pfx), read_zmm(v))); Ok() },
        1 => { write_ymm(dst, avx_fnmsub_ps_256(read_ymm(dst), evex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok() },
        _ => { write_xmm(dst, avx_fnmsub_ps_128(read_xmm(dst), evex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok() },
      }
    }
  },

  // 0F38 9F: VFNMSUB132SS (66,W0) / VFNMSUB132SD (66,W1) [F]
  // 0F38 9F: VFNMSUB132SS (66,W0) / VFNMSUB132SD (66,W1) [F]
  159 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfnmsub132sd(dst, src2, src3)
      else exec_vfnmsub132ss(dst, src2, src3)
    }
  },

  // =====================================================================
  // Scatter (0xA0-0xA3) — VSIB addressing
  // =====================================================================

  // 0F38 A0: VPSCATTERDD (66,W0) / VPSCATTERDQ (66,W1) [F]
  // 0F38 A0: VPSCATTERDD (66,W0) / VPSCATTERDQ (66,W1) [F]
  160 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let vsib = decode_vsib_evex(modrm, pfx, 4);
      if pfx.rex_w then {
        match pfx.evex_ll {
          2 => exec_scatter_d64_512(src, vsib, pfx.evex_aaa),
          1 => exec_scatter_d64_256(src, vsib, pfx.evex_aaa),
          _ => exec_scatter_d64_128(src, vsib, pfx.evex_aaa),
        }
      } else {
        match pfx.evex_ll {
          2 => exec_scatter_d32_512(src, vsib, pfx.evex_aaa),
          1 => exec_scatter_d32_256(src, vsib, pfx.evex_aaa),
          _ => exec_scatter_d32_128(src, vsib, pfx.evex_aaa),
        }
      }
    }
  },

  // 0F38 A1: VPSCATTERQD (66,W0) / VPSCATTERQQ (66,W1) [F]
  // 0F38 A1: VPSCATTERQD (66,W0) / VPSCATTERQQ (66,W1) [F]
  161 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let vsib = decode_vsib_evex(modrm, pfx, 4);
      if pfx.rex_w then {
        match pfx.evex_ll {
          2 => exec_scatter_q64_512(src, vsib, pfx.evex_aaa),
          1 => exec_scatter_q64_256(src, vsib, pfx.evex_aaa),
          _ => exec_scatter_q64_128(src, vsib, pfx.evex_aaa),
        }
      } else {
        match pfx.evex_ll {
          2 => exec_scatter_q32_512(src, vsib, pfx.evex_aaa),
          1 => exec_scatter_q32_256(src, vsib, pfx.evex_aaa),
          _ => exec_scatter_q32_128(src, vsib, pfx.evex_aaa),
        }
      }
    }
  },

  // 0F38 A2: VSCATTERDPS (66,W0) / VSCATTERDPD (66,W1) [F]
  // 0F38 A2: VSCATTERDPS (66,W0) / VSCATTERDPD (66,W1) [F]
  162 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let vsib = decode_vsib_evex(modrm, pfx, 4);
      if pfx.rex_w then {
        match pfx.evex_ll {
          2 => exec_scatter_d64_512(src, vsib, pfx.evex_aaa),
          1 => exec_scatter_d64_256(src, vsib, pfx.evex_aaa),
          _ => exec_scatter_d64_128(src, vsib, pfx.evex_aaa),
        }
      } else {
        match pfx.evex_ll {
          2 => exec_scatter_d32_512(src, vsib, pfx.evex_aaa),
          1 => exec_scatter_d32_256(src, vsib, pfx.evex_aaa),
          _ => exec_scatter_d32_128(src, vsib, pfx.evex_aaa),
        }
      }
    }
  },

  // 0F38 A3: VSCATTERQPS (66,W0) / VSCATTERQPD (66,W1) [F]
  // 0F38 A3: VSCATTERQPS (66,W0) / VSCATTERQPD (66,W1) [F]
  163 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let vsib = decode_vsib_evex(modrm, pfx, 4);
      if pfx.rex_w then {
        match pfx.evex_ll {
          2 => exec_scatter_q64_512(src, vsib, pfx.evex_aaa),
          1 => exec_scatter_q64_256(src, vsib, pfx.evex_aaa),
          _ => exec_scatter_q64_128(src, vsib, pfx.evex_aaa),
        }
      } else {
        match pfx.evex_ll {
          2 => exec_scatter_q32_512(src, vsib, pfx.evex_aaa),
          1 => exec_scatter_q32_256(src, vsib, pfx.evex_aaa),
          _ => exec_scatter_q32_128(src, vsib, pfx.evex_aaa),
        }
      }
    }
  },

  // =====================================================================
  // FMA 213 forms (0xA6-0xAF)
  // =====================================================================

  // 0F38 A6: VFMADDSUB213PS (66,W0) / VFMADDSUB213PD (66,W1) [F]
  // 0F38 A6: VFMADDSUB213PS (66,W0) / VFMADDSUB213PD (66,W1) [F]
  166 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmaddsub_pd_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, avx_fmaddsub_pd_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, avx_fmaddsub_pd_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok() },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmaddsub_ps_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, avx_fmaddsub_ps_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, avx_fmaddsub_ps_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok() },
      }
    }
  },

  // 0F38 A7: VFMSUBADD213PS (66,W0) / VFMSUBADD213PD (66,W1) [F]
  // 0F38 A7: VFMSUBADD213PS (66,W0) / VFMSUBADD213PD (66,W1) [F]
  167 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsubadd_pd_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, avx_fmsubadd_pd_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, avx_fmsubadd_pd_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok() },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsubadd_ps_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, avx_fmsubadd_ps_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, avx_fmsubadd_ps_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok() },
      }
    }
  },

  // 0F38 A8: VFMADD213PS (66,W0) / VFMADD213PD (66,W1) [F]
  // 0F38 A8: VFMADD213PS (66,W0) / VFMADD213PD (66,W1) [F]
  168 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmadd_pd_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, avx_fmadd_pd_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, avx_fmadd_pd_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok() },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmadd_ps_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, avx_fmadd_ps_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, avx_fmadd_ps_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok() },
      }
    }
  },

  // 0F38 A9: VFMADD213SS (66,W0) / VFMADD213SD (66,W1) [F]
  // 0F38 A9: VFMADD213SS (66,W0) / VFMADD213SD (66,W1) [F]
  169 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfmadd213sd(dst, src2, src3)
      else exec_vfmadd213ss(dst, src2, src3)
    }
  },

  // 0F38 AA: VFMSUB213PS (66,W0) / VFMSUB213PD (66,W1) [F]
  // 0F38 AA: VFMSUB213PS (66,W0) / VFMSUB213PD (66,W1) [F]
  170 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsub_pd_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, avx_fmsub_pd_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, avx_fmsub_pd_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok() },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsub_ps_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, avx_fmsub_ps_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, avx_fmsub_ps_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok() },
      }
    }
  },

  // 0F38 AB: VFMSUB213SS (66,W0) / VFMSUB213SD (66,W1) [F]
  // 0F38 AB: VFMSUB213SS (66,W0) / VFMSUB213SD (66,W1) [F]
  171 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfmsub213sd(dst, src2, src3)
      else exec_vfmsub213ss(dst, src2, src3)
    }
  },

  // 0F38 AC: VFNMADD213PS (66,W0) / VFNMADD213PD (66,W1) [F]
  // 0F38 AC: VFNMADD213PS (66,W0) / VFNMADD213PD (66,W1) [F]
  172 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmadd_pd_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, avx_fnmadd_pd_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, avx_fnmadd_pd_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok() },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmadd_ps_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, avx_fnmadd_ps_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, avx_fnmadd_ps_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok() },
      }
    }
  },

  // 0F38 AD: VFNMADD213SS (66,W0) / VFNMADD213SD (66,W1) [F]
  // 0F38 AD: VFNMADD213SS (66,W0) / VFNMADD213SD (66,W1) [F]
  173 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfnmadd213sd(dst, src2, src3)
      else exec_vfnmadd213ss(dst, src2, src3)
    }
  },

  // 0F38 AE: VFNMSUB213PS (66,W0) / VFNMSUB213PD (66,W1) [F]
  // 0F38 AE: VFNMSUB213PS (66,W0) / VFNMSUB213PD (66,W1) [F]
  174 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmsub_pd_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, avx_fnmsub_pd_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, avx_fnmsub_pd_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok() },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmsub_ps_512(read_zmm(v), read_zmm(dst), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, avx_fnmsub_ps_256(read_ymm(v), read_ymm(dst), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, avx_fnmsub_ps_128(read_xmm(v), read_xmm(dst), evex_src_xmm(modrm, rm, pfx))); Ok() },
      }
    }
  },

  // 0F38 AF: VFNMSUB213SS (66,W0) / VFNMSUB213SD (66,W1) [F]
  // 0F38 AF: VFNMSUB213SS (66,W0) / VFNMSUB213SD (66,W1) [F]
  175 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfnmsub213sd(dst, src2, src3)
      else exec_vfnmsub213ss(dst, src2, src3)
    }
  },

  // 0F38 B4: VPMADD52LUQ (66,W1) [IFMA]
  // 0F38 B4: VPMADD52LUQ (66,W1) [IFMA]
  180 => {
    if mp != MP_66 | not_bool(pfx.rex_w) then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpmadd52luq_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, avx_vpmadd52luq_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, avx_vpmadd52luq_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok() },
      }
    }
  },

  // 0F38 B5: VPMADD52HUQ (66,W1) [IFMA]
  // 0F38 B5: VPMADD52HUQ (66,W1) [IFMA]
  181 => {
    if mp != MP_66 | not_bool(pfx.rex_w) then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_vpmadd52huq_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, avx_vpmadd52huq_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, avx_vpmadd52huq_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok() },
      }
    }
  },

  // =====================================================================
  // FMA 231 forms (0xB6-0xBF)
  // =====================================================================

  // 0F38 B6: VFMADDSUB231PS (66,W0) / VFMADDSUB231PD (66,W1) [F]
  // 0F38 B6: VFMADDSUB231PS (66,W0) / VFMADDSUB231PD (66,W1) [F]
  182 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmaddsub_pd_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok() },
        1 => { write_ymm(dst, avx_fmaddsub_pd_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok() },
        _ => { write_xmm(dst, avx_fmaddsub_pd_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok() },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmaddsub_ps_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok() },
        1 => { write_ymm(dst, avx_fmaddsub_ps_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok() },
        _ => { write_xmm(dst, avx_fmaddsub_ps_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok() },
      }
    }
  },

  // 0F38 B7: VFMSUBADD231PS (66,W0) / VFMSUBADD231PD (66,W1) [F]
  // 0F38 B7: VFMSUBADD231PS (66,W0) / VFMSUBADD231PD (66,W1) [F]
  183 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsubadd_pd_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok() },
        1 => { write_ymm(dst, avx_fmsubadd_pd_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok() },
        _ => { write_xmm(dst, avx_fmsubadd_pd_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok() },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsubadd_ps_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok() },
        1 => { write_ymm(dst, avx_fmsubadd_ps_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok() },
        _ => { write_xmm(dst, avx_fmsubadd_ps_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok() },
      }
    }
  },

  // 0F38 B8: VFMADD231PS (66,W0) / VFMADD231PD (66,W1) [F]
  // 0F38 B8: VFMADD231PS (66,W0) / VFMADD231PD (66,W1) [F]
  184 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmadd_pd_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok() },
        1 => { write_ymm(dst, avx_fmadd_pd_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok() },
        _ => { write_xmm(dst, avx_fmadd_pd_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok() },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmadd_ps_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok() },
        1 => { write_ymm(dst, avx_fmadd_ps_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok() },
        _ => { write_xmm(dst, avx_fmadd_ps_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok() },
      }
    }
  },

  // 0F38 B9: VFMADD231SS (66,W0) / VFMADD231SD (66,W1) [F]
  // 0F38 B9: VFMADD231SS (66,W0) / VFMADD231SD (66,W1) [F]
  185 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfmadd231sd(dst, src2, src3)
      else exec_vfmadd231ss(dst, src2, src3)
    }
  },

  // 0F38 BA: VFMSUB231PS (66,W0) / VFMSUB231PD (66,W1) [F]
  // 0F38 BA: VFMSUB231PS (66,W0) / VFMSUB231PD (66,W1) [F]
  186 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsub_pd_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok() },
        1 => { write_ymm(dst, avx_fmsub_pd_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok() },
        _ => { write_xmm(dst, avx_fmsub_pd_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok() },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fmsub_ps_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok() },
        1 => { write_ymm(dst, avx_fmsub_ps_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok() },
        _ => { write_xmm(dst, avx_fmsub_ps_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok() },
      }
    }
  },

  // 0F38 BB: VFMSUB231SS (66,W0) / VFMSUB231SD (66,W1) [F]
  // 0F38 BB: VFMSUB231SS (66,W0) / VFMSUB231SD (66,W1) [F]
  187 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfmsub231sd(dst, src2, src3)
      else exec_vfmsub231ss(dst, src2, src3)
    }
  },

  // 0F38 BC: VFNMADD231PS (66,W0) / VFNMADD231PD (66,W1) [F]
  // 0F38 BC: VFNMADD231PS (66,W0) / VFNMADD231PD (66,W1) [F]
  188 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmadd_pd_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok() },
        1 => { write_ymm(dst, avx_fnmadd_pd_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok() },
        _ => { write_xmm(dst, avx_fnmadd_pd_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok() },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmadd_ps_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok() },
        1 => { write_ymm(dst, avx_fnmadd_ps_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok() },
        _ => { write_xmm(dst, avx_fnmadd_ps_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok() },
      }
    }
  },

  // 0F38 BD: VFNMADD231SS (66,W0) / VFNMADD231SD (66,W1) [F]
  // 0F38 BD: VFNMADD231SS (66,W0) / VFNMADD231SD (66,W1) [F]
  189 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfnmadd231sd(dst, src2, src3)
      else exec_vfnmadd231ss(dst, src2, src3)
    }
  },

  // 0F38 BE: VFNMSUB231PS (66,W0) / VFNMSUB231PD (66,W1) [F]
  // 0F38 BE: VFNMSUB231PS (66,W0) / VFNMSUB231PD (66,W1) [F]
  190 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let v = pfx.evex_vvvvv;
      if pfx.rex_w then match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmsub_pd_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok() },
        1 => { write_ymm(dst, avx_fnmsub_pd_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok() },
        _ => { write_xmm(dst, avx_fnmsub_pd_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok() },
      } else match pfx.evex_ll {
        2 => { write_zmm(dst, avx_fnmsub_ps_512(read_zmm(v), evex_src_zmm(modrm, rm, pfx), read_zmm(dst))); Ok() },
        1 => { write_ymm(dst, avx_fnmsub_ps_256(read_ymm(v), evex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok() },
        _ => { write_xmm(dst, avx_fnmsub_ps_128(read_xmm(v), evex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok() },
      }
    }
  },

  // 0F38 BF: VFNMSUB231SS (66,W0) / VFNMSUB231SD (66,W1) [F]
  // 0F38 BF: VFNMSUB231SS (66,W0) / VFNMSUB231SD (66,W1) [F]
  191 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src2 = read_xmm(pfx.evex_vvvvv);
      let src3 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then exec_vfnmsub231sd(dst, src2, src3)
      else exec_vfnmsub231ss(dst, src2, src3)
    }
  },

  // 0F38 2C: VSCALEFPS (66,W0) / VSCALEFPD (66,W1) [F]
  // 0F38 2C: VSCALEFPS (66,W0) / VSCALEFPD (66,W1) [F]
  44 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
      if pfx.rex_w then {
        // VSCALEFPD
        match pfx.evex_ll {
          2 => {
            let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, vscalefpd_zmm(src1, src2)); Ok()
          },
          1 => { write_ymm(dst, vscalefpd_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok() },
          _ => { write_xmm(dst, vscalefpd_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok() },
        }
      } else {
        // VSCALEFPS
        match pfx.evex_ll {
          2 => {
            let src1 : zmmword = read_zmm(pfx.evex_vvvvv);
            let src2 : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, vscalefps_zmm(src1, src2)); Ok()
          },
          1 => { write_ymm(dst, vscalefps_ymm(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok() },
          _ => { write_xmm(dst, vscalefps_xmm(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok() },
        }
      }
    }
  },

  // 0F38 2D: VSCALEFSS (66,W0) / VSCALEFSD (66,W1) [T1S]
  // 0F38 2D: VSCALEFSS (66,W0) / VSCALEFSD (66,W1) [T1S]
  45 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src1 = read_xmm(pfx.evex_vvvvv);
      let src2 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then {
        // VSCALEFSD
        let r = __f64_scalef(src1[63..0], src2[63..0]);
        write_xmm(dst, src1[127..64] @ r); Ok()
      } else {
        // VSCALEFSS
        let r = __f32_scalef(src1[31..0], src2[31..0]);
        write_xmm(dst, src1[127..32] @ r); Ok()
      }
    }
  },

  // 0F38 42: VGETEXPPS (66,W0) / VGETEXPPD (66,W1) [F]
  // 0F38 42: VGETEXPPS (66,W0) / VGETEXPPD (66,W1) [F]
  66 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
      if pfx.rex_w then {
        // VGETEXPPD
        match pfx.evex_ll {
          2 => {
            let src : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, vgetexppd_zmm(src)); Ok()
          },
          1 => { write_ymm(dst, vgetexppd_ymm(evex_src_ymm(modrm, rm, pfx))); Ok() },
          _ => { write_xmm(dst, vgetexppd_xmm(evex_src_xmm(modrm, rm, pfx))); Ok() },
        }
      } else {
        // VGETEXPPS
        match pfx.evex_ll {
          2 => {
            let src : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, vgetexpps_zmm(src)); Ok()
          },
          1 => { write_ymm(dst, vgetexpps_ymm(evex_src_ymm(modrm, rm, pfx))); Ok() },
          _ => { write_xmm(dst, vgetexpps_xmm(evex_src_xmm(modrm, rm, pfx))); Ok() },
        }
      }
    }
  },

  // 0F38 43: VGETEXPSS (66,W0) / VGETEXPSD (66,W1) [T1S]
  // 0F38 43: VGETEXPSS (66,W0) / VGETEXPSD (66,W1) [T1S]
  67 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src1 = read_xmm(pfx.evex_vvvvv);
      let src2 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then {
        // VGETEXPSD
        let r = __f64_getexp(src2[63..0]);
        write_xmm(dst, src1[127..64] @ r); Ok()
      } else {
        // VGETEXPSS
        let r = __f32_getexp(src2[31..0]);
        write_xmm(dst, src1[127..32] @ r); Ok()
      }
    }
  },

  // 0F38 4C: VRCP14PS (66,W0) / VRCP14PD (66,W1) [F]
  // 0F38 4C: VRCP14PS (66,W0) / VRCP14PD (66,W1) [F]
  76 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
      if pfx.rex_w then {
        // VRCP14PD
        match pfx.evex_ll {
          2 => {
            let src : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, vrcp14pd_zmm(src)); Ok()
          },
          1 => { write_ymm(dst, vrcp14pd_ymm(evex_src_ymm(modrm, rm, pfx))); Ok() },
          _ => { write_xmm(dst, vrcp14pd_xmm(evex_src_xmm(modrm, rm, pfx))); Ok() },
        }
      } else {
        // VRCP14PS
        match pfx.evex_ll {
          2 => {
            let src : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, vrcp14ps_zmm(src)); Ok()
          },
          1 => { write_ymm(dst, vrcp14ps_ymm(evex_src_ymm(modrm, rm, pfx))); Ok() },
          _ => { write_xmm(dst, vrcp14ps_xmm(evex_src_xmm(modrm, rm, pfx))); Ok() },
        }
      }
    }
  },

  // 0F38 4D: VRCP14SS (66,W0) / VRCP14SD (66,W1) [T1S]
  // 0F38 4D: VRCP14SS (66,W0) / VRCP14SD (66,W1) [T1S]
  77 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src1 = read_xmm(pfx.evex_vvvvv);
      let src2 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then {
        // VRCP14SD
        let r = __f64_rcp14(src2[63..0]);
        write_xmm(dst, src1[127..64] @ r); Ok()
      } else {
        // VRCP14SS
        let r = __f32_rcp14(src2[31..0]);
        write_xmm(dst, src1[127..32] @ r); Ok()
      }
    }
  },

  // 0F38 4E: VRSQRT14PS (66,W0) / VRSQRT14PD (66,W1) [F]
  // 0F38 4E: VRSQRT14PS (66,W0) / VRSQRT14PD (66,W1) [F]
  78 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
      if pfx.rex_w then {
        // VRSQRT14PD
        match pfx.evex_ll {
          2 => {
            let src : zmmword = if pfx.evex_b & is_mem
              then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, vrsqrt14pd_zmm(src)); Ok()
          },
          1 => { write_ymm(dst, vrsqrt14pd_ymm(evex_src_ymm(modrm, rm, pfx))); Ok() },
          _ => { write_xmm(dst, vrsqrt14pd_xmm(evex_src_xmm(modrm, rm, pfx))); Ok() },
        }
      } else {
        // VRSQRT14PS
        match pfx.evex_ll {
          2 => {
            let src : zmmword = if pfx.evex_b & is_mem
              then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
              else evex_src_zmm(modrm, rm, pfx);
            write_zmm(dst, vrsqrt14ps_zmm(src)); Ok()
          },
          1 => { write_ymm(dst, vrsqrt14ps_ymm(evex_src_ymm(modrm, rm, pfx))); Ok() },
          _ => { write_xmm(dst, vrsqrt14ps_xmm(evex_src_xmm(modrm, rm, pfx))); Ok() },
        }
      }
    }
  },

  // 0F38 4F: VRSQRT14SS (66,W0) / VRSQRT14SD (66,W1) [T1S]
  // 0F38 4F: VRSQRT14SS (66,W0) / VRSQRT14SD (66,W1) [T1S]
  79 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src1 = read_xmm(pfx.evex_vvvvv);
      let src2 = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then {
        // VRSQRT14SD
        let r = __f64_rsqrt14(src2[63..0]);
        write_xmm(dst, src1[127..64] @ r); Ok()
      } else {
        // VRSQRT14SS
        let r = __f32_rsqrt14(src2[31..0]);
        write_xmm(dst, src1[127..32] @ r); Ok()
      }
    }
  },

  // 0F38 2A: VPBROADCASTMB2Q (F3, W=1) [CD] — also VMOVNTDQA (66)
  // 0F38 C6: VGATHERPF0DPS/DPD, VGATHERPF1DPS/DPD (66) [PF]
  // Gather prefetch — architectural NOP (just compute VSIB addresses and discard)
  198 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      // reg=1: PF0, reg=2: PF1; VSIB addressing
      if (reg_field != 1 & reg_field != 2) then {
        raise_UD()
      } else {
        let disp_n : range(4, 64) = if pfx.rex_w then 8 else 4;
        let _ = decode_vsib_evex(modrm, pfx, disp_n);
        Ok()
      }
    }
  },

  // 0F38 C7: VGATHERPF0QPS/QPD, VGATHERPF1QPS/QPD (66) [PF]
  // Gather prefetch (qword index) — architectural NOP
  // 0F38 C7: VGATHERPF0QPS/QPD, VGATHERPF1QPS/QPD (66) [PF]
  // Gather prefetch (qword index) — architectural NOP
  199 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      if (reg_field != 1 & reg_field != 2) then {
        raise_UD()
      } else {
        let disp_n : range(4, 64) = if pfx.rex_w then 8 else 4;
        let _ = decode_vsib_evex(modrm, pfx, disp_n);
        Ok()
      }
    }
  },

  // 0F38 C8: VEXP2PS (66,W0) / VEXP2PD (66,W1) [ER] — 512-bit only
  // 0F38 C8: VEXP2PS (66,W0) / VEXP2PD (66,W1) [ER] — 512-bit only
  200 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      if pfx.rex_w then {
        write_zmm(dst, avx_vexp2pd_512(evex_src_zmm(modrm, rm, pfx))); Ok()
      } else {
        write_zmm(dst, avx_vexp2ps_512(evex_src_zmm(modrm, rm, pfx))); Ok()
      }
    }
  },

  // 0F38 CA: VRCP28PS (66,W0) / VRCP28PD (66,W1) [ER] — 512-bit only
  // 0F38 CA: VRCP28PS (66,W0) / VRCP28PD (66,W1) [ER] — 512-bit only
  202 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      if pfx.rex_w then {
        write_zmm(dst, avx_vrcp28pd_512(evex_src_zmm(modrm, rm, pfx))); Ok()
      } else {
        write_zmm(dst, avx_vrcp28ps_512(evex_src_zmm(modrm, rm, pfx))); Ok()
      }
    }
  },

  // 0F38 CB: VRCP28SS (66,W0) / VRCP28SD (66,W1) [ER] — scalar
  // 0F38 CB: VRCP28SS (66,W0) / VRCP28SD (66,W1) [ER] — scalar
  203 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src1 = read_zmm(pfx.evex_vvvvv);
      if pfx.rex_w then {
        let src2 = evex_src_xmm(modrm, rm, pfx);
        write_zmm(dst, src1[511..64] @ __f64_rcp28(src2[63..0])); Ok()
      } else {
        let src2 = evex_src_xmm(modrm, rm, pfx);
        write_zmm(dst, src1[511..32] @ __f32_rcp28(src2[31..0])); Ok()
      }
    }
  },

  // 0F38 CC: VRSQRT28PS (66,W0) / VRSQRT28PD (66,W1) [ER] — 512-bit only
  // 0F38 CC: VRSQRT28PS (66,W0) / VRSQRT28PD (66,W1) [ER] — 512-bit only
  204 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      if pfx.rex_w then {
        write_zmm(dst, avx_vrsqrt28pd_512(evex_src_zmm(modrm, rm, pfx))); Ok()
      } else {
        write_zmm(dst, avx_vrsqrt28ps_512(evex_src_zmm(modrm, rm, pfx))); Ok()
      }
    }
  },

  // 0F38 CD: VRSQRT28SS (66,W0) / VRSQRT28SD (66,W1) [ER] — scalar
  // 0F38 CD: VRSQRT28SS (66,W0) / VRSQRT28SD (66,W1) [ER] — scalar
  205 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
      let src1 = read_zmm(pfx.evex_vvvvv);
      if pfx.rex_w then {
        let src2 = evex_src_xmm(modrm, rm, pfx);
        write_zmm(dst, src1[511..64] @ __f64_rsqrt28(src2[63..0])); Ok()
      } else {
        let src2 = evex_src_xmm(modrm, rm, pfx);
        write_zmm(dst, src1[511..32] @ __f32_rsqrt28(src2[31..0])); Ok()
      }
    }
  },

  // 0F38 CF: VGF2P8MULB (66,W0) [GFNI]
  // 0F38 CF: VGF2P8MULB (66,W0) [GFNI]
  207 => {
    if mp != MP_66 | pfx.rex_w then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_gf2p8mulb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok() },
        1 => { write_ymm(dst, avx_gf2p8mulb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok() },
        _ => { write_xmm(dst, avx_gf2p8mulb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok() },
      }
    }
  },

  _ => raise_UD(),
  }
}
