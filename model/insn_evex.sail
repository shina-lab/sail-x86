// x86-64 — EVEX Shared Helpers
//
// Register index computation, source operand reading, writemask application,
// broadcast, and other utilities used by multiple EVEX dispatch files.

// Compute 5-bit destination register index from EVEX R' : R : modrm.reg
val evex_reg_idx : (byte, Prefixes) -> simd_idx
function evex_reg_idx(modrm, pfx) = {
  let base : range(0, 7) = unsigned(modrm[5..3]);
  let r_ext : range(0, 1) = unsigned(zero_extend(pfx.rex_r) : bits(1));
  let rr_ext : range(0, 1) = unsigned(zero_extend(pfx.evex_rr) : bits(1));
  // 5-bit index: R' : R : reg[2:0]
  rr_ext * 16 + r_ext * 8 + base
}

// Fetch and decode ModR/M byte with EVEX compressed disp8.
// Returns 5-bit destination register index and RM operand.
val fetch_modrm_evex : (Prefixes, range(1, 64)) -> (simd_idx, RM)
function fetch_modrm_evex(pfx, disp_n) = {
  let modrm = fetch(1);
  (evex_reg_idx(modrm, pfx), modrm_rm_evex(modrm, pfx, disp_n))
}

// Compute 5-bit r/m register index (for register operands only).
// For memory operands, B extends the base register (4 bits, not 5).
val evex_rm_reg_idx : (byte, Prefixes) -> simd_idx
function evex_rm_reg_idx(modrm, pfx) = {
  let base : range(0, 7) = unsigned(modrm[2..0]);
  let b_ext : range(0, 1) = unsigned(zero_extend(pfx.rex_b) : bits(1));
  let x_ext : range(0, 1) = unsigned(zero_extend(pfx.rex_x) : bits(1));
  // 5-bit index: X : B : rm[2:0]
  x_ext * 16 + b_ext * 8 + base
}

// Masked memory store: write only bytes where mask bit = 1.
// elem_bytes: element size (1=byte, 2=word, 4=dword, 8=qword).
// One mask bit per element.
val evex_masked_mem_store : (MemRef, zmmword, qword, int, int) -> unit
function evex_masked_mem_store(m, data, mask, nbytes, elem_bytes) = {
  if mask == ones() then {
    // Fast path: no masking, write the full vector
    match nbytes {
      64 => write_mem(m, data),
      32 => write_mem(256, m, data[255..0]),
      _  => write_mem(128, m, data[127..0]),
    }
  } else {
    // Slow path: write only elements where the corresponding mask bit = 1
    let addr = seg_linear(m, nbytes);
    var off : int = 0;
    var k : qword = mask;
    while off < nbytes do {
      if k[0] == 0b1 then {
        var j : int = 0;
        while j < elem_bytes do {
          let idx : int = off + j;
          assert(0 <= idx & idx < 512);
          write_mem(addr + to_bits(64, idx), get_slice_int(8, unsigned(data), idx * 8));
          j = j + 1;
        }
      };
      off = off + elem_bytes;
      k = k >> 1;
    }
  }
}

// Convert an LL value (0-3) to vector length in bits.
// Used for both pfx.evex_ll and eff_ll from evex_begin_rc.
val ll_to_vl : range(0, 3) -> {128, 256, 512}
function ll_to_vl(ll) = match ll {
  0 => 128,
  1 => 256,
  2 => 512,
  3 => { raise_UD(); 128 }
}

// Convert EVEX.LL to vector length in bits.
val evex_vl : Prefixes -> {128, 256, 512}
function evex_vl(pfx) = ll_to_vl(pfx.evex_ll)

// Element size from EVEX.W: W=1 → 64-bit, W=0 → 32-bit.
val evex_elem : Prefixes -> {32, 64}
function evex_elem(pfx) = if pfx.rex_w then 64 else 32

// Polymorphic SIMD source read from r/m field: register or memory.
val evex_src : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), byte, RM, Prefixes) -> bits('vl)
function evex_src(vl, modrm, rm, pfx) = match rm {
  RM_reg(_) => read_simd(evex_rm_reg_idx(modrm, pfx)),
  RM_mem(m) => read_mem(m),
}

// Read narrow source for widening instructions.
// Returns vl/ratio bits from register or memory.
val evex_widen_src : forall 'vl 'r, 'vl in {128, 256, 512} & 'r in {2, 4, 8}.
  (implicit('vl), int('r), byte, RM, Prefixes) -> bits(div('vl, 'r))
function evex_widen_src(vl, ratio, modrm, rm, pfx) = {
  let idx = evex_rm_reg_idx(modrm, pfx);
  let n = vl / ratio;
  match rm {
    RM_reg(_) => ZMM[idx][n - 1 .. 0],
    RM_mem(m) => read_mem(n, m),
  }
}

// Get the effective 64-bit opmask: aaa=0 → all-ones (no masking), else kreg(aaa).
// Branchless: OR with all-ones mask when aaa==0, which subsumes any kreg value.
val evex_kmask64 : Prefixes -> qword
function evex_kmask64(pfx) = {
  sign_extend(is_zero(to_bits(3, pfx.evex_aaa))) | read_kreg(pfx.evex_aaa)
}

val evex_get_mask16 : Prefixes -> word
function evex_get_mask16(pfx) = evex_kmask64(pfx)[15..0]

val evex_get_mask8 : Prefixes -> byte
function evex_get_mask8(pfx) = evex_kmask64(pfx)[7..0]


// Read a 16-bit value from r/m for broadcast.
val evex_src_m16 : (byte, RM, Prefixes) -> word
function evex_src_m16(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
  RM_mem(m) => v(m),
}

// Read a 32-bit value from r/m for broadcast.
val evex_src_m32 : (byte, RM, Prefixes) -> dword
function evex_src_m32(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
  RM_mem(m) => read_mem(m),
}

// Read a 64-bit value from r/m for broadcast.
val evex_src_m64 : (byte, RM, Prefixes) -> qword
function evex_src_m64(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
  RM_mem(m) => read_mem(m),
}

struct Writemask('n : Int), 'n > 0 = {
  bits : bits('n),
  zeroing : bit,
}

// Apply writemask to a vector result. Element size = 'vl / 'nm.
// Per element: mask bit=1 → write result, bit=0 → keep or zero (per zeroing flag).
// Branchless: base = old_dst & sign_extend(~zeroing), then blend(base, result, mask[i]).
val apply_writemask : forall 'vl 'nm, 'vl > 0 & 'nm > 0 & 'vl >= 'nm & mod('vl, 'nm) == 0.
  (Writemask('nm), bits('vl), bits('vl)) -> bits('vl)
function apply_writemask(wm, result, old_dst) = {
  let mask = wm.bits;
  let base : bits('vl) = old_dst & sign_extend(~(wm.zeroing));
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('nm - 1)) {
    let lo = i * ('vl / 'nm);
    let hi = lo + 'vl / 'nm - 1;
    r[hi..lo] = blend(base[hi..lo], result[hi..lo], mask[i])
  };
  r
}

// Write a SIMD register with writemask applied, zeroing upper bits.
val evex_write : forall 'vl 'nm, 'vl > 0 & 'nm > 0 & 'vl >= 'nm & mod('vl, 'nm) == 0 & 'vl <= 512.
  (simd_idx, Writemask('nm), bits('vl)) -> unit
function evex_write(dst, wm, result) = {
  let old : bits('vl) = ZMM[dst][('vl - 1)..0];
  ZMM[dst] = zero_extend(apply_writemask(wm, result, old))
}

// Write to register or memory with writemask applied.
// For register: applies writemask (merge/zero), zeroes upper bits.
// For memory: writes only masked elements (unmasked bytes untouched).
val evex_write_rm : forall 'vl 'nm, 'vl > 0 & 'nm > 0 & 'vl >= 'nm & mod('vl, 'nm) == 0 & 'vl <= 512.
  (RM, byte, Prefixes, Writemask('nm), bits('vl)) -> unit
function evex_write_rm(dst, modrm, pfx, wm, result) = match dst {
  RM_reg(_) => evex_write(evex_rm_reg_idx(modrm, pfx), wm, result),
  RM_mem(m) => {
    let nbytes = 'vl / 8;
    let num_elems = length(wm.bits);
    evex_masked_mem_store(m, zero_extend(result), evex_kmask64(pfx), nbytes, nbytes / num_elems)
  },
}

// Construct a Writemask from prefixes, vector length, and element size.
// Returns Writemask with 'vl/'eb mask bits (one per element).
// Construct Writemask for N elements from EVEX prefixes.
val evex_wmask : forall 'n, 'n in {2, 4, 8, 16, 32, 64}. (Prefixes, int('n)) -> Writemask('n)
function evex_wmask(pfx, n) =
  struct {
    bits = evex_kmask64(pfx)[('n - 1)..0],
    zeroing = pfx.evex_z,
  }

// Scalar writemask write: only the lowest 'eb bits are subject to masking,
// upper XMM bits always come from result (src1).
val evex_write_scalar : forall 'eb, 'eb in {16, 32, 64}.
  (simd_idx, xmmword, Prefixes, int('eb)) -> unit
function evex_write_scalar(dst, result, pfx, eb) = {
  let mask_bit : bit = evex_kmask64(pfx)[0];
  let merge : bits('eb) = blend(read_xmm(dst)[('eb - 1)..0], zeros(), pfx.evex_z);
  let lo : bits('eb) = blend(merge, result[('eb - 1)..0], mask_bit);
  write_xmm(dst, result[127..'eb] @ lo)
}

// Polymorphic broadcast: replicate an 'eb-bit element to fill 'vl bits.
val broadcast : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {8, 16, 32, 64}.
  (implicit('vl), bits('eb)) -> bits('vl)
function broadcast(vl, v) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[(lo + 'eb - 1)..lo] = v
  };
  r
}

// Polymorphic broadcast-aware source: read source from reg/mem,
// applying EVEX.b broadcast when the source is a memory operand.
val evex_bcast_src : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {16, 32, 64}.
  (implicit('vl), byte, RM, Prefixes, int('eb)) -> bits('vl)
function evex_bcast_src(vl, modrm, rm, pfx, eb) = {
  let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
  if pfx.evex_b & is_mem then {
    match eb {
      16 => broadcast(evex_src_m16(modrm, rm, pfx)),
      32 => broadcast(evex_src_m32(modrm, rm, pfx)),
      64 => broadcast(evex_src_m64(modrm, rm, pfx)),
    }
  } else {
    evex_src(modrm, rm, pfx)
  }
}

val select4_f32 : (bits(128), bits(2)) -> bits(32)
function select4_f32(src, ctrl) = {
  let lo : range(0, 96) = unsigned(ctrl) * 32;
  src[(lo + 31)..lo]
}

val avx_vpshldw_elem : (word, word, nat) -> word
function avx_vpshldw_elem(src1, src2, cnt) =
  ((src1 @ src2) << (cnt % 16))[31..16]

val avx_vpshldd_elem : (dword, dword, nat) -> dword
function avx_vpshldd_elem(src1, src2, cnt) =
  ((src1 @ src2) << (cnt % 32))[63..32]

val avx_vpshldq_elem : (qword, qword, nat) -> qword
function avx_vpshldq_elem(src1, src2, cnt) =
  ((src1 @ src2) << (cnt % 64))[127..64]

val avx_vpshrdw_elem : (word, word, nat) -> word
function avx_vpshrdw_elem(src1, src2, cnt) =
  ((src2 @ src1) >> (cnt % 16))[15..0]

val avx_vpshrdd_elem : (dword, dword, nat) -> dword
function avx_vpshrdd_elem(src1, src2, cnt) =
  ((src2 @ src1) >> (cnt % 32))[31..0]

val avx_vpshrdq_elem : (qword, qword, nat) -> qword
function avx_vpshrdq_elem(src1, src2, cnt) =
  ((src2 @ src1) >> (cnt % 64))[63..0]

val gf2p8_mul : (byte, byte) -> byte
function gf2p8_mul(a, b) = {
  var result : bits(9) = zeros();
  var aa : bits(9) = zero_extend(a);
  foreach (i from 0 to 7) {
    result = result ^ (sign_extend(b[i..i]) & aa);
    aa = aa << 1;
    aa = aa ^ (sign_extend(aa[8]) & 0b100011011) // 0x11B
  };
  result[7..0]
}

// =========================================================================
// EVEX Embedded Rounding Control
// =========================================================================
// When EVEX.b=1 and the operand is register-only (ModRM.mod=11), the
// EVEX.LL field encodes a static rounding mode instead of vector length:
//   00=RN (round nearest), 01=RD (round down),
//   02=RU (round up),      03=RZ (round toward zero)
// The vector length is implicitly 512-bit for packed operations.
// SAE (suppress all exceptions) is also implied.
//
// evex_begin_rc() saves the current MXCSR, overrides bits 14:13 with LL,
// and returns (effective_ll, saved_mxcsr). Call evex_end_rc() to restore.
val evex_begin_rc : (Prefixes, bool) -> (range(0, 3), dword)
function evex_begin_rc(pfx, is_reg) = {
  let saved = __stmxcsr();
  if pfx.evex_b & is_reg then {
    // LL encodes rounding control; override MXCSR RC (bits 14:13)
    __ldmxcsr((saved & 0xFFFF9FFF) | to_bits(32, pfx.evex_ll * 8192));
    (2, saved)  // force 512-bit vector length
  } else {
    (pfx.evex_ll, saved)
  }
}

val evex_end_rc : dword -> unit
function evex_end_rc(saved) = __ldmxcsr(saved)
