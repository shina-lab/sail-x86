// x86-64 — 2-Byte Opcode Map: Baseline Operations
//
// CMOVcc, Jcc, SETcc, BT/BTS/BTR/BTC, SHLD/SHRD, IMUL, MOVZX/MOVSX,
// BSF/BSR, POPCNT, CMPXCHG, XADD, BSWAP, CPUID, RDTSC, and more.

// Check LOCK prefix validity: requires memory destination on a lockable instruction.
// LOCK with register operand or on CMP (which doesn't write) raises #UD.
// DR7.GD (SDM Vol.3B §20.2.4, §20.3.1.3): any MOV DR while GD is set raises
// #DB before the access, a fault with DR6.BD set and RF = 1 in the pushed
// image; the processor clears GD on the way to the handler so that the
// handler itself can use the debug registers.
val general_detect_check : unit -> unit
function general_detect_check() = {
  if DR7[13] == bitone then {
    DR7[13] = bitzero;
    DR6 = (DR6 & 0xFFFFFFFFFFFFFFF0) | 0x0000000000002000;
    RF = 0b1;
    throw Fault(EXN_DB, 0x00000000)
  }
}

val check_lock_rm : (Prefixes, RM, bool) -> unit
function check_lock_rm(pfx, dest, is_cmp) = {
  if pfx.has_lock then {
    match dest {
      RM_reg(_) => raise_UD(),
      RM_mem(_) => if is_cmp then raise_UD(),
    }
  }
}

// XADD — Exchange and Add
val exec_xadd : (GPRRef, GPRRef, operand_size) -> unit
function exec_xadd(dst, src, os) = {
  let a = v(os, dst);
  let b = v(os, src);
  update_flags_add(a + b, a, b);
  v(src) = a;
  v(dst) = a + b
}

// Descriptor type validation for LAR in IA-32e mode (SDM Table 1-49).
// System segment types (S=0): valid = 2 (LDT), 9 (avail TSS), B (busy TSS), C (call gate).
// Code/data segments (S=1): all valid.
val lar_type_valid_64 : dword -> bool
function lar_type_valid_64(desc_hi) = {
  let s_bit : bit = desc_hi[12];
  if s_bit == 0b1 then {
    true
  } else {
    let typ : bits(4) = desc_hi[11..8];
    typ == 0x2 | typ == 0x9 | typ == 0xB | typ == 0xC
  }
}

// Descriptor type validation for LSL in IA-32e mode (SDM Table 1-53).
// System segment types (S=0): valid = 2 (LDT), 9 (avail TSS), B (busy TSS).
// Code/data segments (S=1): all valid.
val lsl_type_valid_64 : dword -> bool
function lsl_type_valid_64(desc_hi) = {
  let s_bit : bit = desc_hi[12];
  if s_bit == 0b1 then {
    true
  } else {
    let typ : bits(4) = desc_hi[11..8];
    typ == 0x2 | typ == 0x9 | typ == 0xB
  }
}

// Privilege check for non-conforming segments: CPL ≤ DPL and RPL ≤ DPL.
// Conforming code segments (S=1, type[3]=1, type[2]=1) bypass this check.
val desc_privilege_ok : (dword, word) -> bool
function desc_privilege_ok(desc_hi, selector) = {
  let s_bit : bit = desc_hi[12];
  let is_conforming : bool = s_bit == 0b1 & desc_hi[11] == 0b1 & desc_hi[10] == 0b1;
  if is_conforming then {
    true
  } else {
    let dpl : range(0, 3) = unsigned(desc_hi[14..13]);
    let rpl : range(0, 3) = unsigned(selector[1..0]);
    cur_cpl <= dpl & rpl <= dpl
  }
}

// CPUID — returns (EAX, EBX, ECX, EDX) for a given leaf/subleaf.
// Feature-dependent leaves are built from has_* registers and XCR0.
val cpuid : (dword, dword) -> (dword, dword, dword, dword)
function cpuid(leaf, subleaf) = {
  let leaf_val : range(0, 4294967295) = unsigned(leaf);
  let sub_val : range(0, 4294967295) = unsigned(subleaf);

  match leaf_val {
    // Leaf 0: Vendor string + max basic leaf.
    // We report "GenuineIntel" because system libraries (e.g. glibc)
    // select code paths based on the vendor string. Presenting as a
    // genuine Intel CPU ensures the same feature negotiation that would
    // happen on real hardware.
    0 => (0x00000016, 0x756E6547, 0x6C65746E, 0x49656E69),

    // Leaf 1: Family/Model/Stepping, feature bits
    1 => {
      let eax : dword = 0x000506E3;  // Family 6, Model 5E, Stepping 3
      let ebx : dword = 0x00010800;  // CLFLUSH=8, max logical=1

      // ECX: built dynamically from has_* flags and CR4/XCR0
      var ecx : dword = 0x00000000;
      if has_sse3       then ecx = ecx | 0x00000001;  // bit 0 (SSE3)
      if has_pclmulqdq  then ecx = ecx | 0x00000002;  // bit 1
      if has_vmx        then ecx = ecx | 0x00000020;  // bit 5 (VMX)
      if has_ssse3      then ecx = ecx | 0x00000200;  // bit 9 (SSSE3)
      if has_fma        then ecx = ecx | 0x00001000;  // bit 12
      if has_cx16       then ecx = ecx | 0x00002000;  // bit 13 (CX16)
      if has_sse4_1     then ecx = ecx | 0x00080000;  // bit 19 (SSE4.1)
      if has_sse4_2     then ecx = ecx | 0x00100000;  // bit 20 (SSE4.2)
      if has_movbe      then ecx = ecx | 0x00400000;  // bit 22
      if has_popcnt     then ecx = ecx | 0x00800000;  // bit 23
      if has_aesni      then ecx = ecx | 0x02000000;  // bit 25
      if has_xsave      then ecx = ecx | 0x04000000;  // bit 26 (XSAVE)
      if CR4[18] == 0b1 then ecx = ecx | 0x08000000;  // bit 27 (OSXSAVE)
      if XCR0[2] == 0b1 then ecx = ecx | 0x10000000;  // bit 28 (AVX)
      if has_f16c       then ecx = ecx | 0x20000000;  // bit 29
      if has_rdrand     then ecx = ecx | 0x40000000;  // bit 30

      // EDX: baseline features (FPU, DE, PSE, TSC, MSR, PAE, MCE, CX8,
      //       APIC, SEP, MTRR, PGE, MCA, CMOV, PAT, PSE36, CLFLUSH,
      //       MMX, FXSR, SSE, SSE2)
      let edx : dword = 0x078BFBFD;
      (eax, ebx, ecx, edx)
    },

    // Leaf 2: Cache/TLB descriptors
    2 => (0x76036301, 0x00F0B5FF, 0x00000000, 0x00C30000),

    // Leaf 4: Deterministic cache parameters — no more caches
    4 => (0x00000000, 0x00000000, 0x00000000, 0x00000000),

    // Leaf 7: Structured extended feature flags
    7 => {
      if sub_val == 0 then {
        var ebx : dword = 0x00000000;
        ebx = ebx | 0x00000200;  // ERMS (bit 9)
        if has_bmi1       then ebx = ebx | 0x00000008;  // bit 3
        if XCR0[2] == 0b1 then ebx = ebx | 0x00000020;  // AVX2 (bit 5)
        if has_bmi2       then ebx = ebx | 0x00000100;  // bit 8
        // AVX-512: has_avx512 covers the F/CD/BW/DQ/VL base and every
        // sub-extension the model implements in full (IFMA, VBMI, VBMI2,
        // VNNI, BITALG, VPOPCNTDQ, VP2INTERSECT, FP16, and BF16 in
        // sub-leaf 1), so all are advertised together.
        if has_avx512     then ebx = ebx | 0xD0230000;  // F(16)+DQ(17)+IFMA(21)+CD(28)+BW(30)+VL(31)
        if has_rdseed     then ebx = ebx | 0x00040000;  // bit 18
        if has_adx        then ebx = ebx | 0x00080000;  // bit 19
        if has_sha        then ebx = ebx | 0x20000000;  // bit 29
        var ecx : dword = 0x00000000;
        if has_avx512     then ecx = ecx | 0x00005842;  // VBMI(1)+VBMI2(6)+VNNI(11)+BITALG(12)+VPOPCNTDQ(14)
        if has_gfni       then ecx = ecx | 0x00000100;  // bit 8 (GFNI)
        if has_vaes       then ecx = ecx | 0x00000200;  // bit 9 (VAES)
        if has_vpclmulqdq then ecx = ecx | 0x00000400;  // bit 10 (VPCLMULQDQ)
        if has_la57       then ecx = ecx | 0x00010000;  // bit 16 (LA57)
        if has_movdiri    then ecx = ecx | 0x08000000;  // bit 27
        if has_movdir64b  then ecx = ecx | 0x10000000;  // bit 28
        var edx : dword = 0x00000000;
        if has_avx512     then edx = edx | 0x00800100;  // bit 8 (AVX512_VP2INTERSECT) + bit 23 (AVX512_FP16)
        // EAX: maximum sub-leaf; sub-leaf 1 exists once something is in it
        let max_sub : dword = if has_avx_vnni | has_avx512 then 0x00000001 else 0x00000000;
        (max_sub, ebx, ecx, edx)
      } else if sub_val == 1 then {
        var eax : dword = 0x00000000;
        if has_avx_vnni   then eax = eax | 0x00000010;  // bit 4 (AVX-VNNI)
        if has_avx512     then eax = eax | 0x00000020;  // bit 5 (AVX512_BF16)
        (eax, 0x00000000, 0x00000000, 0x00000000)
      } else {
        (0x00000000, 0x00000000, 0x00000000, 0x00000000)
      }
    },

    // Leaf 0xD: XSAVE state component info
    13 => match (has_xsave, sub_val) {
      // EAX = XCR0_SUPPORTED
      // EBX = standard size for currently enabled components (dynamic)
      // ECX = max standard size for all supported components
      (true, 0) => (XCR0_SUPPORTED[31..0],
                    xsave_area_size_standard(XCR0),
                    xsave_area_size_standard(XCR0_SUPPORTED),
                    0x00000000),
      // EAX: XSAVEOPT(0), XSAVEC(1), XGETBV w/ ECX=1(2), XSAVES/XRSTORS(3)
      // EBX = compacted size for currently enabled components (dynamic)
      // ECX = supported IA32_XSS bits [31:0] (none)
      // EDX = supported IA32_XSS bits [63:32] (none)
      (true, 1) => (0x0000000F, xsave_area_size_compacted(XCR0), 0x00000000, 0x00000000),
      // Components 2 (AVX, 256 bytes), 5 (opmask, 64), 6 (ZMM_Hi256, 512)
      // and 7 (Hi16_ZMM, 1024).  EBX, the standard-format offset, follows
      // the vendor profile: see xsave_std_offset in insn_xsave.sail.
      (true, 2) => (0x00000100, to_bits(32, xsave_std_offset(2)), 0x00000000, 0x00000000),
      (true, 5) => (0x00000040, to_bits(32, xsave_std_offset(5)), 0x00000000, 0x00000000),
      (true, 6) => (0x00000200, to_bits(32, xsave_std_offset(6)), 0x00000000, 0x00000000),
      (true, 7) => (0x00000400, to_bits(32, xsave_std_offset(7)), 0x00000000, 0x00000000),
      _ => (0x00000000, 0x00000000, 0x00000000, 0x00000000)
    },

    // Leaf 0x15: Time Stamp Counter / Core Crystal Clock
    // EAX = denominator, EBX = numerator, ECX = crystal frequency (Hz)
    // TSC freq = crystal_freq * numerator / denominator = 25MHz * 40 / 1 = 1GHz
    21 => (0x00000001, 0x00000028, 0x017D7840, 0x00000000),

    // Leaf 0x16: Processor Frequency Information (MHz)
    // EAX = base freq, EBX = max freq, ECX = bus freq
    22 => (0x000003E8, 0x000003E8, 0x00000064, 0x00000000),

    // Leaf 0x80000000: Max extended leaf
    2147483648 => (0x80000008, 0x00000000, 0x00000000, 0x00000000),

    // Leaf 0x80000001: Extended feature bits
    2147483649 => {
      // ECX: LAHF(0), conditionally LZCNT(5)
      var ecx : dword = 0x00000001;  // LAHF
      if has_lzcnt then ecx = ecx | 0x00000020;  // bit 5
      // EDX: SYSCALL(11), NX(20), LM(29)
      let edx : dword = 0x20100800;
      (0x00000000, 0x00000000, ecx, edx)
    },

    // Leaves 0x80000002-0x80000004: Processor brand string "Sail x86-64 Emulator"
    2147483650 => (0x6C696153, 0x36387820, 0x2034362D, 0x6C756D45),
    2147483651 => (0x726F7461, 0x00000000, 0x00000000, 0x00000000),
    2147483652 => (0x00000000, 0x00000000, 0x00000000, 0x00000000),

    // Leaf 0x80000007: Advanced power management — invariant TSC (bit 8)
    2147483655 => (0x00000000, 0x00000000, 0x00000000, 0x00000100),

    // Leaf 0x80000008: Address sizes
    // EAX[7:0] = physical address bits (39), EAX[15:8] = virtual address bits
    // Virtual: 57 with LA57, 48 without
    2147483656 => {
      let virt_bits : dword = if has_la57 then 0x00003900 else 0x00003000;
      (virt_bits | 0x00000027, 0x00000000, 0x00000000, 0x00000000)
    },

    // Unknown leaf: return zeros
    _ => (0x00000000, 0x00000000, 0x00000000, 0x00000000),
  }
}

// SHLD — Double Precision Shift Left
//
// Shifts dst left by count, filling vacated bits from src (high bits).
// Equivalent to: result = upper_half(dst:src << count)
// If count=0, no operation. If count > operand_size, undefined.
// CF = last bit shifted out. SF, ZF, PF set from result.
// OF defined for count=1 (sign change). AF undefined.
val exec_shld : forall 'os, 'os in {16, 32, 64}. (implicit('os), bits('os), bits('os), byte) -> bits('os)
function exec_shld(os, d, s, count_raw) = {
  let count : range(0, 63) = match os {
    64 => unsigned(count_raw) % 64,
    _  => unsigned(count_raw) % 32,
  };

  let count_bv : bits(6) = to_bits(6, count);
  let old_CF = CF;
  let old_OF = OF;
  let old_SF = SF;
  let old_ZF = ZF;
  let old_PF = PF;
  let old_AF = AF;

  // Clamp count to [0, os] for valid computation; garbage for count > os is blended away
  let clamped_bv : bits(7) = min_u(to_bits(7, count), to_bits(7, os));
  let clamped : range(0, 127) = unsigned(clamped_bv);
  let cf_count = clamped + unsigned(is_zero(count_bv));
  assert(cf_count >= 1 & cf_count <= os);
  let wide = d @ s;
  let shifted = wide << clamped;
  let r = shifted[(os * 2 - 1)..os];
  CF = wide[os * 2 - cf_count];
  update_SF_ZF_PF(r);
  OF = r[os - 1] ^ d[os - 1];
  AF = undefined;
  // OF defined only for count==1; undefined otherwise
  OF = blend(undefined, OF, is_eq(count_bv, 0b000001));

  // count==0: restore old flags
  let count_nz : bit = is_nonzero(count_bv);
  CF = blend(old_CF, CF, count_nz);
  OF = blend(old_OF, OF, count_nz);
  SF = blend(old_SF, SF, count_nz);
  ZF = blend(old_ZF, ZF, count_nz);
  PF = blend(old_PF, PF, count_nz);
  AF = blend(old_AF, AF, count_nz);
  let result : bits('os) = blend(d, r, count_nz);

  // count > os: SDM says result and flags undefined
  let count_gt_os : bit = is_gt_u(to_bits(7, count), to_bits(7, os));
  CF = blend(CF, undefined, count_gt_os);
  OF = blend(OF, undefined, count_gt_os);
  SF = blend(SF, undefined, count_gt_os);
  ZF = blend(ZF, undefined, count_gt_os);
  PF = blend(PF, undefined, count_gt_os);
  AF = blend(AF, undefined, count_gt_os);
  blend(result, undefined, count_gt_os)
}

// SHRD — Double Precision Shift Right
//
// Shifts dst right by count, filling vacated bits from src (low bits).
// Equivalent to: result = lower_half(src:dst >> count)
// If count=0, no operation. If count > operand_size, undefined.
// CF = last bit shifted out. SF, ZF, PF set from result.
// OF defined for count=1 (sign change). AF undefined.
val exec_shrd : forall 'os, 'os in {16, 32, 64}. (implicit('os), bits('os), bits('os), byte) -> bits('os)
function exec_shrd(os, d, s, count_raw) = {
  let count : range(0, 63) = match os {
    64 => unsigned(count_raw) % 64,
    _  => unsigned(count_raw) % 32,
  };

  let count_bv : bits(6) = to_bits(6, count);
  let old_CF = CF;
  let old_OF = OF;
  let old_SF = SF;
  let old_ZF = ZF;
  let old_PF = PF;
  let old_AF = AF;

  // Clamp count to [0, os] for valid computation
  let clamped_bv : bits(7) = min_u(to_bits(7, count), to_bits(7, os));
  let clamped : range(0, 127) = unsigned(clamped_bv);
  let cf_count = clamped + unsigned(is_zero(count_bv));
  assert(cf_count >= 1 & cf_count <= 64);
  let wide = s @ d;
  let shifted = wide >> clamped;
  let r = shifted[(os - 1)..0];
  let d_ext : bits(64) = zero_extend(d);
  CF = d_ext[cf_count - 1];
  update_SF_ZF_PF(r);
  OF = r[os - 1] ^ d[os - 1];
  AF = undefined;
  // OF defined only for count==1; undefined otherwise
  OF = blend(undefined, OF, is_eq(count_bv, 0b000001));

  // count==0: restore old flags
  let count_nz : bit = is_nonzero(count_bv);
  CF = blend(old_CF, CF, count_nz);
  OF = blend(old_OF, OF, count_nz);
  SF = blend(old_SF, SF, count_nz);
  ZF = blend(old_ZF, ZF, count_nz);
  PF = blend(old_PF, PF, count_nz);
  AF = blend(old_AF, AF, count_nz);
  let result : bits('os) = blend(d, r, count_nz);

  // count > os: SDM says result and flags undefined
  let count_gt_os : bit = is_gt_u(to_bits(7, count), to_bits(7, os));
  CF = blend(CF, undefined, count_gt_os);
  OF = blend(OF, undefined, count_gt_os);
  SF = blend(SF, undefined, count_gt_os);
  ZF = blend(ZF, undefined, count_gt_os);
  PF = blend(PF, undefined, count_gt_os);
  AF = blend(AF, undefined, count_gt_os);
  blend(result, undefined, count_gt_os)
}

// Adjust BT/BTS/BTR/BTC operands for memory bit string addressing.
// For register rm: bit index is masked to operand size (e.g., mod 64 for 64).
// For memory rm: the full signed bit offset indexes into an arbitrarily long
// bit string, so the effective address is displaced by (offset / op_bits) words.
// Returns (possibly-adjusted RM, bit number within the accessed word).
val bt_adjust : forall 'os, 'os in {16, 32, 64}. (implicit('os), RM, bits('os)) -> (RM, range(0, 'os - 1))
function bt_adjust(os, rm, bit_idx) = {
  match rm {
    RM_reg(_) => {
      let bit_num : range(0, 'os - 1) = unsigned(bit_idx) % os;
      (rm, bit_num)
    },
    RM_mem(m) => {
      // Apply RIP-relative fixup first, before adding the bit string
      // displacement. Otherwise fixup_addr would discard our adjustment.
      let base_addr : qword = fixup_addr(m.addr);
      rip_rel_pending = false;

      // For memory operands, the full signed bit offset indexes into a bit
      // string starting at the effective address. Compute the word displacement
      // (Euclidean: bit_num is always in [0, op_bits)).
      let off = signed(bit_idx);
      let r = rem_round_zero(off, os);
      let q = quot_round_zero(off, os);
      // Branchless Euclidean adjustment: sign = 0 when r >= 0, -1 when r < 0
      let r_bv : bits(7) = get_slice_int(7, r, 0);
      let sign : int = negate(unsigned(r_bv[6]));
      let byte_disp : int = (q + sign) * (os / 8);
      let bit_num_int : int = r - sign * os;
      let new_addr : qword = base_addr + get_slice_int(64, byte_disp, 0);
      let bit_num : range(0, 63) = unsigned(get_slice_int(6, bit_num_int, 0));
      assert(bit_num < os);
      (RM_mem(struct { seg = m.seg, addr = new_addr }), bit_num)
    },
  }
}

val dispatch_2byte_gpr : (range(0, 255), Prefixes) -> unit
function dispatch_2byte_gpr(op, pfx) = {
  match op {
    // 0F 00: Group 6 (SLDT, STR, LLDT, LTR, VERR, VERW)
    0 => {
      let modrm = fetch(1);
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      match reg_field {
        // 0F 00 /0: SLDT r/m16 — Store LDTR
        0 => {
          let dest = modrm_rm(modrm, pfx);
          match dest {
            RM_reg(r) => v(r) = LDTR,
            RM_mem(m) => v(m) = LDTR,
          }
        },

        // 0F 00 /1: STR r/m16 — Store Task Register
        1 => {
          let dest = modrm_rm(modrm, pfx);
          match dest {
            RM_reg(r) => v(r) = TR,
            RM_mem(m) => v(m) = TR,
          }
        },

        // 0F 00 /2: LLDT r/m16 — Load LDT Register (requires CPL=0)
        2 => {
          if cur_cpl != 0 then raise_GP0();
          let src = modrm_rm(modrm, pfx);
          let sel : word = v(src);
          LDTR = sel
        },

        // 0F 00 /3: LTR r/m16 — Load Task Register (requires CPL=0)
        3 => {
          if cur_cpl != 0 then raise_GP0();
          let src = modrm_rm(modrm, pfx);
          let sel : word = v(src);
          TR = sel;
          // Load TSS base/limit from GDT descriptor (implicit supervisor read).
          let desc_addr : qword = GDTR_base + zero_extend(sel & 0xFFF8);
          let desc_lo : dword = read_mem_implicit(desc_addr);
          let desc_hi : dword = read_mem_implicit(desc_addr + 4);
          // Base = desc[63:56] @ desc[39:32] @ desc[31:16]
          let base_lo : dword = desc_lo[31..16] @ 0x0000;
          let base_mid : byte = desc_hi[7..0];
          let base_hi : byte = desc_hi[31..24];
          TR_base = zero_extend(base_hi @ base_mid @ base_lo[31..16]);
          // In 64-bit mode, read the next 8 bytes for the high 32 bits of base
          let desc_ext : dword = read_mem_implicit(desc_addr + 8);
          TR_base = zero_extend(desc_ext) @ TR_base[31..0];
          // Limit = desc[51:48] @ desc[15:0] (with granularity)
          let limit_lo : word = desc_lo[15..0];
          let limit_hi : bits(4) = desc_hi[19..16];
          let g : bit = desc_hi[23];
          TR_limit = if g == 0b1
            then (zero_extend(limit_hi @ limit_lo) << 12) | 0x00000FFF
            else zero_extend(limit_hi @ limit_lo)
        },

        // 0F 00 /4: VERR r/m16 — Verify segment readable, set ZF
        4 => {
          let src = modrm_rm(modrm, pfx);
          let selector : word = v(src);
          if (selector & 0xFFFC) == zeros() then {
            ZF = 0b0
          } else {
            let sel_offset : qword = zero_extend(selector & 0xFFF8);
            if unsigned(sel_offset) + 7 > unsigned(GDTR_limit) then {
              ZF = 0b0
            } else {
              let desc_hi : dword = read_mem_implicit(GDTR_base + sel_offset + 4);
              let present : bit = desc_hi[15];
              let s_bit : bit = desc_hi[12];
              // Readable: data segments always readable; code readable if R bit set
              let is_code : bit = desc_hi[11];
              let readable : bit = desc_hi[9] | ~(is_code);
              if present == 0b0 | s_bit == 0b0 | readable == 0b0
                | ~(desc_privilege_ok(desc_hi, selector)) then {
                ZF = 0b0
              } else {
                ZF = 0b1
              }
            }
          }
        },

        // 0F 00 /5: VERW r/m16 — Verify segment writable, set ZF
        5 => {
          let src = modrm_rm(modrm, pfx);
          let selector : word = v(src);
          if (selector & 0xFFFC) == zeros() then {
            ZF = 0b0
          } else {
            let sel_offset : qword = zero_extend(selector & 0xFFF8);
            if unsigned(sel_offset) + 7 > unsigned(GDTR_limit) then {
              ZF = 0b0
            } else {
              let desc_hi : dword = read_mem_implicit(GDTR_base + sel_offset + 4);
              let present : bit = desc_hi[15];
              let s_bit : bit = desc_hi[12];
              let is_code : bit = desc_hi[11];
              // Writable: only data segments with W bit set
              let writable : bit = desc_hi[9] & ~(is_code);
              if present == 0b0 | s_bit == 0b0 | writable == 0b0
                | ~(desc_privilege_ok(desc_hi, selector)) then {
                ZF = 0b0
              } else {
                ZF = 0b1
              }
            }
          }
        },
        _ => raise_UD(),
      }
    },

    // 0F 01: Group 7 (privileged/system instructions)
    1 => {
      let modrm = fetch(1);
      let modrm_val : range(0, 255) = unsigned(modrm);
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let mod_field : range(0, 3) = unsigned(modrm[7..6]);

      match modrm_val {
        // 0F 01 D1: XSETBV — Write XCR (ECX selects register, EDX:EAX = value)
        // SDM: #GP(0) if CPL > 0; #GP(0) if ECX != 0 (only XCR0 exists);
        // #GP(0) if attempting to set unsupported bits or violating constraints.
        // Unconditional VM exit in non-root (SDM §26.1.2).
        209 => {
          vmx_exit_xsetbv();
          if cur_cpl != 0 then raise_GP0();
          let ecx_val : dword = v(RCX);
          if ecx_val != 0x00000000 then raise_GP0();
          let new_xcr0 : qword = v(32, RDX) @ v(32, RAX);
          // Any bit set that is not in XCR0_SUPPORTED → #GP
          if (new_xcr0 & ~(XCR0_SUPPORTED)) != zeros() then raise_GP0();
          // Bit 0 (x87) must always be 1
          if new_xcr0[0] == 0b0 then raise_GP0();
          // Can't set AVX (bit 2) without SSE (bit 1)
          if new_xcr0[2..1] == 0b10 then raise_GP0();
          // Bits 7:5 (AVX-512) must be all-or-nothing, and require bits 2:1
          let avx512_bits : bits(3) = new_xcr0[7..5];
          if avx512_bits != 0b000 & avx512_bits != 0b111 then raise_GP0();
          if avx512_bits == 0b111 & (new_xcr0[2] == 0b0 | new_xcr0[1] == 0b0) then raise_GP0();
          // Bits 18:17 (AMX) must be both-or-neither
          if new_xcr0[17] != new_xcr0[18] then raise_GP0();
          XCR0 = new_xcr0
        },

        // 0F 01 D0: XGETBV — Read XCR0
        208 => {
          let ecx_val : dword = v(RCX);
          if ecx_val == 0x00000000 | ecx_val == 0x00000001 then {
            // ECX=0: read XCR0; ECX=1: read XCR0 | IA32_XSS (IA32_XSS is 0)
            v(RAX) = XCR0[31..0];
            v(RDX) = XCR0[63..32]
          } else {
            raise_GP0()
          }
        },

        // 0F 01 CA: CLAC — Clear AC flag (SMAP)
        202 => AC_flag = 0b0,

        // 0F 01 CB: STAC — Set AC flag (SMAP)
        203 => AC_flag = 0b1,

        // 0F 01 E8: SERIALIZE — NOP in sequential interpreter
        232 => (),

        // 0F 01 EE: RDPKRU — Read Protection Key Rights (ECX must be 0)
        // Returns PKRU in EAX, 0 in EDX.  We don't implement PKU, so
        // return 0 (all access allowed).
        238 => {
          v(RAX) = 0x00000000;
          v(RDX) = 0x00000000
        },

        // 0F 01 EF: WRPKRU — Write Protection Key Rights (NOP, no PKU)
        239 => (),

        // 0F 01 F9: RDTSCP — Read TSC and IA32_TSC_AUX
        // SDM: #GP(0) if CR4.TSD (bit 2) = 1 and CPL > 0
        249 => {
          if CR4[2] == 0b1 & cur_cpl != 0 then raise_GP0();
          vmx_exit_if_rdtscp();
          let tsc = __rdtsc();
          v(RAX) = tsc[31..0];
          v(RDX) = tsc[63..32];
          v(RCX) = __rdmsr(0xC0000103)[31..0]
        },

        // 0F 01 C1: VMCALL (SDM Vol.3C §31.2.6)
        193 => exec_vmcall(),

        // 0F 01 C2: VMLAUNCH (SDM Vol.3C §31.2.7)
        194 => exec_vmlaunch(),

        // 0F 01 C3: VMRESUME (SDM Vol.3C §31.2.7)
        195 => exec_vmresume(),

        // 0F 01 C4: VMXOFF (SDM Vol.3C §31.2.2)
        196 => {
          vmx_exit_vmx_insn(VMEXIT_VMXOFF);
          exec_vmxoff()
        },

        // 0F 01 F8: SWAPGS (requires CPL=0)
        248 => {
          if cur_cpl != 0 then raise_GP0();
          let tmp = SegCache[GS].seg_base;
          SegCache[GS].seg_base = KERNEL_GS_BASE;
          KERNEL_GS_BASE = tmp
        },

        _ => {
          // Group 7: dispatch by reg_field, then check memory vs register
          let dest = modrm_rm(modrm, pfx);
          match reg_field {
            // 0F 01 /0: SGDT m — Store GDTR (memory only)
            // Non-64-bit: 6 bytes (2 limit + 4 base).
            // 64-bit: 10 bytes (2 limit + 8 base). SDM Vol.2A LGDT/LIDT.
            0 => match dest {
              RM_mem(m) => {
                if cur_mode == LongMode then
                  write_mem(80, m, GDTR_base @ GDTR_limit)
                else
                  write_mem(48, m, GDTR_base[31..0] @ GDTR_limit)
              },
              RM_reg(_) => raise_UD(),
            },

            // 0F 01 /1: SIDT m — Store IDTR (memory only)
            1 => match dest {
              RM_mem(m) => {
                if cur_mode == LongMode then
                  write_mem(80, m, IDTR_base @ IDTR_limit)
                else
                  write_mem(48, m, IDTR_base[31..0] @ IDTR_limit)
              },
              RM_reg(_) => raise_UD(),
            },

            // 0F 01 /2: LGDT m — Load GDTR (memory only, requires CPL=0)
            // SDM Vol.2A §LGDT Operation:
            //   16: Limit := SRC[0:15]; Base := SRC[16:47] AND 00FFFFFFH;
            //   32: Limit := SRC[0:15]; Base := SRC[16:47];
            //   64: Limit := SRC[0:15]; Base := SRC[16:79];
            // 16 and 32 both read 6 bytes (2 limit + 4 base); 16
            // masks the base to 24 bits. 64 reads 10 bytes (2 + 8).
            // In 64-bit mode, the operand size is forced to 64-bit
            // regardless of REX.W (SDM: "In 64-bit mode, the instruction's
            // operand size is fixed at 8+2 bytes").
            2 => {
              if cur_cpl != 0 then raise_GP0();
              match dest {
                RM_mem(m) => {
                  if cur_mode == LongMode then {
                    let d : bits(80) = read_mem(m);
                    GDTR_base = d[79..16];
                    GDTR_limit = d[15..0]
                  } else {
                    let d : bits(48) = read_mem(m);
                    GDTR_base = if opsize(pfx) == 16
                      then zero_extend(d[39..16])
                      else zero_extend(d[47..16]);
                    GDTR_limit = d[15..0]
                  }
                },
                RM_reg(_) => raise_UD(),
              }
            },

            // 0F 01 /3: LIDT m — Load IDTR (memory only, requires CPL=0)
            // Same operand-size semantics as LGDT.
            3 => {
              if cur_cpl != 0 then raise_GP0();
              match dest {
                RM_mem(m) => {
                  if cur_mode == LongMode then {
                    let d : bits(80) = read_mem(m);
                    IDTR_base = d[79..16];
                    IDTR_limit = d[15..0]
                  } else {
                    let d : bits(48) = read_mem(m);
                    IDTR_base = if opsize(pfx) == 16
                      then zero_extend(d[39..16])
                      else zero_extend(d[47..16]);
                    IDTR_limit = d[15..0]
                  }
                },
                RM_reg(_) => raise_UD(),
              }
            },

            // 0F 01 /4: SMSW r/m16 — Store Machine Status Word
            // No privilege check required (accessible from any CPL).
            // SDM: stores low 16 bits of CR0 to r/m16. With 32-bit
            // register operand, stores low 32 bits; with 64-bit, all 64.
            4 => match dest {
              RM_reg(r) => {
                let os = opsize(pfx);
                v(r) = CR0[(os - 1) .. 0]
              },
              RM_mem(m) => v(m) = CR0[15..0],
            },

            // 0F 01 /6: LMSW r/m16 — Load Machine Status Word (requires CPL=0)
            6 => {
              if cur_cpl != 0 then raise_GP0();
              let msw : word = v(dest);
              // LMSW sets low 4 bits of CR0; only PE (bit 0) is sticky
              // (cannot clear PE once set). MP/EM/TS are freely assignable.
              var new_cr0 = CR0;
              new_cr0[3..1] = msw[3..1];
              new_cr0[0] = msw[0] | CR0[0];
              CR0 = new_cr0
            },

            // 0F 01 /7: INVLPG m — Invalidate TLB Entry (memory only, requires CPL=0)
            7 => {
              if cur_cpl != 0 then raise_GP0();
              match dest {
                RM_mem(m) => {
                  vmx_exit_if_invlpg(seg_linear(m, 1));
                  __tlb_flush()
                },
                RM_reg(_) => raise_UD(),
              }
            },
            _ => raise_UD(),
          }
        },
      }
    },

    // 0F 02: LAR r, r/m16 — Load Access Rights Byte
    // Reads descriptor from GDT, validates type and privilege, loads access rights.
    2 => {
      let os = opsize(pfx);
      let (reg, src) = fetch_modrm(pfx);
      let selector : word = v(src);
      if (selector & 0xFFFC) == zeros() then {
        ZF = 0b0
      } else {
        let sel_offset : qword = zero_extend(selector & 0xFFF8);
        let desc_addr : qword = GDTR_base + sel_offset;
        if unsigned(sel_offset) + 7 > unsigned(GDTR_limit) then {
          ZF = 0b0
        } else {
          let desc_hi : dword = read_mem_implicit(desc_addr + 4);
          if ~(lar_type_valid_64(desc_hi)) | ~(desc_privilege_ok(desc_hi, selector)) then {
            ZF = 0b0
          } else {
            let ar : qword = zero_extend(zero_extend(desc_hi[23..0]) & 0x00FFFF00 : dword);
            v(reg) = ar[(os - 1) .. 0];
            ZF = 0b1
          }
        }
      }
    },

    // 0F 03: LSL r, r/m16 — Load Segment Limit
    // Reads descriptor from GDT, validates type and privilege, loads segment limit.
    3 => {
      let os = opsize(pfx);
      let (reg, src) = fetch_modrm(pfx);
      let selector : word = v(src);
      if (selector & 0xFFFC) == zeros() then {
        ZF = 0b0
      } else {
        let sel_offset : qword = zero_extend(selector & 0xFFF8);
        let desc_addr : qword = GDTR_base + sel_offset;
        if unsigned(sel_offset) + 7 > unsigned(GDTR_limit) then {
          ZF = 0b0
        } else {
          let desc_lo : dword = read_mem_implicit(desc_addr);
          let desc_hi : dword = read_mem_implicit(desc_addr + 4);
          if ~(lsl_type_valid_64(desc_hi)) | ~(desc_privilege_ok(desc_hi, selector)) then {
            ZF = 0b0
          } else {
            let limit_lo : word = desc_lo[15..0];
            let limit_hi : bits(4) = desc_hi[19..16];
            let granularity : bit = desc_hi[23];
            let limit : dword = zero_extend(limit_hi @ limit_lo);
            let fl_ext : qword = zero_extend(if granularity == 0b1
              then (limit << 12) | 0x00000FFF
              else limit);
            v(reg) = fl_ext[(os - 1) .. 0];
            ZF = 0b1
          }
        }
      }
    },

    // 0F 05: SYSCALL
    // SDM: #UD if EFER.SCE (bit 0) = 0
    5 => {
      if EFER[0] != 0b1 then raise_UD();
      if system_mode then {
        // Full hardware SYSCALL per Intel SDM Vol.2.
        // RCX = return address, R11 = RFLAGS
        v(RCX) = decode_pos;
        let saved_rflags = read_rflags();
        v(R11) = saved_rflags;

        // Read MSRs
        let star  : qword = __rdmsr(0xC0000081);
        let lstar : qword = __rdmsr(0xC0000082);
        let fmask : qword = __rdmsr(0xC0000084);

        // Mask RFLAGS: clear bits in FMASK, also clear RF (bit 16)
        let new_rflags = saved_rflags & ~(fmask) & ~(0x0000000000010000);
        write_rflags(new_rflags);

        // CS = STAR[47:32] & 0xFFFC, SS = STAR[47:32] + 8
        // SDM Vol.2 SYSCALL pseudocode: SYSCALL unconditionally transitions
        // to 64-bit mode and sets CS/SS descriptor-cache fields to specific
        // fixed values (the selector is taken from IA32_STAR but the hidden
        // part is NOT read from the GDT). In particular CS.L=1, CS.D=0 and
        // SS.B=1 — this is what gets the kernel a real 64-bit stack.
        // Without this, a 32-bit compat-mode SYSCALL enters the kernel with
        // stale SegCache values and stack_addr_size() returns 32, so the
        // very first PUSH on the kernel stack truncates RSP to 32 bits.
        let syscall_cs : word = star[47..32] & 0xFFFC;
        write_segreg(CS, syscall_cs);
        SegCache[CS] = struct {
          seg_base    = 0x0000000000000000,
          seg_limit   = 0xFFFFFFFF,
          seg_type    = 0xB,   // exec/read/accessed
          seg_s       = 0b1,   // code/data
          seg_dpl     = 0,
          seg_present = 0b1,
          seg_db      = 0b0,   // D = 0
          seg_l       = 0b1,   // L = 1 (64-bit)
          seg_g       = 0b1,   // 4KB granularity
        };
        write_segreg(SS, syscall_cs + 0x0008);
        SegCache[SS] = struct {
          seg_base    = 0x0000000000000000,
          seg_limit   = 0xFFFFFFFF,
          seg_type    = 0x3,   // R/W data/accessed
          seg_s       = 0b1,
          seg_dpl     = 0,
          seg_present = 0b1,
          seg_db      = 0b1,   // B = 1 (32-bit stack — CPL 0 uses RSP anyway)
          seg_l       = 0b0,
          seg_g       = 0b1,
        };

        // Transition to 64-bit long mode.
        cur_mode = LongMode;

        // CPL = 0
        cur_cpl = 0;

        // RIP = LSTAR
        next_rip = Some(lstar)
      } else {
        __syscall(RIP, read_rflags())
      }
    },

    // 0F 06: CLTS — Clear TS flag in CR0 (requires CPL=0)
    6 => {
      if cur_cpl != 0 then raise_GP0();
      CR0[3] = 0b0  // TS = bit 3
    },

    // 0F 07: SYSRET (requires CPL=0)
    7 => {
      if cur_cpl != 0 then raise_GP0();
      // SYSRET: restore RIP from RCX, RFLAGS from R11
      let new_rip : qword = v(RCX);

      // SDM: RFLAGS := (R11 & 3C7FD7H) | 2
      // Clear RF (bit 16), VM (bit 17), reserved bits; force bit 1 = 1
      write_rflags((v(R11) & 0x00000000003C7FD7) | 0x0000000000000002);

      // Load CS and SS from IA32_STAR MSR.
      // SDM Vol.2: SYSRET with REX.W (64-bit):
      //   CS.Sel = STAR[63:48] + 16, SS.Sel = STAR[63:48] + 8
      // SYSRET without REX.W (32-bit compat):
      //   CS.Sel = STAR[63:48], SS.Sel = STAR[63:48] + 8
      // Both forms set the *entire* CS/SS descriptor cache to fixed values
      // per SDM pseudocode — base=0, limit=4GB, DPL=3, P=1, G=1, etc.
      let star : qword = __rdmsr(0xC0000081);
      let sysret_base : bits(16) = star[63..48];
      write_segreg(CS, if pfx.rex_w then sysret_base + 0x0010 else sysret_base);
      SegCache[CS] = struct {
        seg_base    = 0x0000000000000000,
        seg_limit   = 0xFFFFFFFF,
        seg_type    = 0xB,   // exec/read/accessed
        seg_s       = 0b1,
        seg_dpl     = 3,
        seg_present = 0b1,
        seg_db      = if pfx.rex_w then 0b0 else 0b1,
        seg_l       = if pfx.rex_w then 0b1 else 0b0,
        seg_g       = 0b1,
      };
      write_segreg(SS, sysret_base + 0x0008);
      SegCache[SS] = struct {
        seg_base    = 0x0000000000000000,
        seg_limit   = 0xFFFFFFFF,
        seg_type    = 0x3,   // R/W data/accessed
        seg_s       = 0b1,
        seg_dpl     = 3,
        seg_present = 0b1,
        seg_db      = 0b1,
        seg_l       = 0b0,
        seg_g       = 0b1,
      };

      // Return to ring 3
      cur_cpl = 3;
      // REX.W -> 64-bit mode; without REX.W -> 32-bit compat mode
      if pfx.rex_w then cur_mode = LongMode
      else cur_mode = CompatibilityMode;
      next_rip = Some(new_rip)
    },

    // 0F 09: WBINVD — Write Back and Invalidate Cache (NOP, requires CPL=0)
    // 0F 08: INVD — Invalidate Internal Caches (requires CPL=0)
    // SDM: Flush(InternalCaches); SignalFlush(ExternalCaches); Continue
    // Destructive: dirty cache lines discarded (not written back).
    8 => {
      if cur_cpl != 0 then raise_GP0();
      vmx_exit_invd()
    },

    // 0F 09: WBINVD — Write Back and Invalidate Cache (requires CPL=0)
    9 => {
      if cur_cpl != 0 then raise_GP0();
      vmx_exit_if_wbinvd()
    },

    // 0F 0B: UD2
    11 => raise_UD(),

    // 0F 1F: Multi-byte NOP r/m (prefetch hint)
    31 => {
      let modrm = fetch(1);
      let _ = modrm_rm(modrm, pfx)  // consume ModR/M + SIB + disp
    },

    // 0F 20: MOV reg, CRn — Read control register (requires CPL=0)
    // REX.R extends reg field to access CR8
    32 => {
      if cur_cpl != 0 then raise_GP0();
      let modrm = fetch(1);
      let rex_r_eff : bit = if pfx.has_rex then pfx.rex_r else 0b0;
      let cr_idx : range(0, 15) = unsigned(rex_r_eff @ modrm[5..3]);
      let rm_idx : gpr_idx = unsigned(pfx.rex_b @ modrm[2..0]);
      let cr_val : qword = match vmx_cr_read_shadow(cr_idx) {
        Some(shadow_val) => shadow_val,
        None() => match cr_idx {
          0 => CR0,
          2 => CR2,
          3 => CR3,
          4 => CR4,
          8 => zero_extend(CR8),
          _ => raise_UD(),
        },
      };
      v(rm_idx) = cr_val
    },

    // 0F 22: MOV CRn, reg — Write control register (requires CPL=0)
    // REX.R extends reg field to access CR8
    34 => {
      if cur_cpl != 0 then raise_GP0();
      let modrm = fetch(1);
      let rex_r_eff : bit = if pfx.has_rex then pfx.rex_r else 0b0;
      let cr_idx : range(0, 15) = unsigned(rex_r_eff @ modrm[5..3]);
      let rm_idx : gpr_idx = unsigned(pfx.rex_b @ modrm[2..0]);
      let cr_val : qword = v(rm_idx);
      vmx_exit_if_cr_write(cr_idx, cr_val);
      match cr_idx {
        0 => {
          CR0 = cr_val;
          // EFER.LMA = EFER.LME & CR0.PG (SDM Vol.3 §4.1.1)
          let lme = EFER[8];
          let pg  = cr_val[31];
          EFER[10] = lme & pg;  // Update LMA
          if lme == 0b1 & pg == 0b1 then {
            // IA-32e mode: 64-bit if CS.L=1, compatibility if CS.L=0
            if SegCache[CS].seg_l == 0b1 then
              cur_mode = LongMode
            else
              cur_mode = CompatibilityMode
          } else if cr_val[0] == 0b1 then {
            cur_mode = ProtectedMode
          } else {
            cur_mode = RealMode
          }
        },
        2 => CR2 = cr_val,
        3 => { CR3 = cr_val; __tlb_flush() },
        4 => {
          // SDM: #GP(0) if changing CR4.LA57 (bit 12) while paging is enabled
          if CR0[31] == 0b1 & cr_val[12] != CR4[12] then raise_GP0();
          CR4 = cr_val
        },
        8 => CR8 = cr_val[3..0],
        _ => raise_UD(),
      }
    },

    // 0F 21: MOV reg, DRn — Read debug register (requires CPL=0)
    // SDM MOV DR: CR4.DE=1 and DR4/DR5 → #UD; otherwise DR4/5 alias DR6/7;
    // CPL > 0 → #GP(0); DR7.GD → #DB before the access (§20.3.1.3).
    // Outside 64-bit mode the read returns the low 32 bits (§20.2.6).
    33 => {
      let modrm = fetch(1);
      let dr_idx : range(0, 7) = unsigned(modrm[5..3]);
      if (dr_idx == 4 | dr_idx == 5) & CR4[3] == 0b1 then raise_UD();
      if cur_cpl != 0 then raise_GP0();
      general_detect_check();
      vmx_exit_if_dr_access();
      let rm_idx : gpr_idx = unsigned(pfx.rex_b @ modrm[2..0]);
      let dr_val : qword = match dr_idx {
        0 => DR0,
        1 => DR1,
        2 => DR2,
        3 => DR3,
        4 => DR6,  // alias when CR4.DE=0
        5 => DR7,  // alias when CR4.DE=0
        6 => DR6,
        7 => DR7,
      };
      if cur_mode == LongMode then v(rm_idx) = dr_val
      else v(32, rm_idx) = dr_val[31..0]
    },

    // 0F 23: MOV DRn, reg — Write debug register (requires CPL=0)
    // Same checks as the read.  In 64-bit mode a 1 in bits 63:32 of the
    // value for DR6 or DR7 is #GP(0) (§20.2.6); outside it the upper 32
    // bits are filled with zeros.  DR6 keeps only its status bits (B0-B3,
    // BD, BS, BT) over fixed reserved bits; DR7 keeps its enable and
    // condition fields, bit 10 reads as 1 and the other reserved bits as 0.
    35 => {
      let modrm = fetch(1);
      let dr_idx : range(0, 7) = unsigned(modrm[5..3]);
      if (dr_idx == 4 | dr_idx == 5) & CR4[3] == 0b1 then raise_UD();
      if cur_cpl != 0 then raise_GP0();
      general_detect_check();
      vmx_exit_if_dr_access();
      let rm_idx : gpr_idx = unsigned(pfx.rex_b @ modrm[2..0]);
      let dr_val : qword = if cur_mode == LongMode then v(rm_idx) else zero_extend(v(32, rm_idx));
      let status_reg : bool = dr_idx >= 4;
      if status_reg & dr_val[63..32] != zeros() then raise_GP0();
      match dr_idx {
        0 => DR0 = dr_val,
        1 => DR1 = dr_val,
        2 => DR2 = dr_val,
        3 => DR3 = dr_val,
        4 => DR6 = (dr_val & 0x000000000000E00F) | 0x00000000FFFF0FF0,  // alias when CR4.DE=0
        5 => DR7 = (dr_val & 0x00000000FFFF2BFF) | 0x0000000000000400,  // alias when CR4.DE=0
        6 => DR6 = (dr_val & 0x000000000000E00F) | 0x00000000FFFF0FF0,
        7 => DR7 = (dr_val & 0x00000000FFFF2BFF) | 0x0000000000000400,
      }
    },

    // 0F 30: WRMSR — Write MSR (requires CPL=0)
    48 => {
      if cur_cpl != 0 then raise_GP0();
      vmx_exit_if_wrmsr();
      let ecx : dword = v(RCX);
      let msr_val : qword = v(32, RDX) @ v(32, RAX);

      // Handle EFER specially since it has a Sail register
      if ecx == 0xC0000080 then {
        EFER = msr_val
      } else if ecx == 0x0000003A then {
        // IA32_FEATURE_CONTROL: #GP(0) if lock bit (bit 0) is already set
        if ia32_feature_control[0] == 0b1 then raise_GP0();
        ia32_feature_control = msr_val
      } else if ecx == 0xC0000100 then {
        SegCache[FS].seg_base = msr_val
      } else if ecx == 0xC0000101 then {
        SegCache[GS].seg_base = msr_val
      } else if ecx == 0xC0000102 then {
        KERNEL_GS_BASE = msr_val
      } else if ecx == 0x00000DA0 then {
        // IA32_XSS (0xDA0): supervisor state components for XSAVES/XRSTORS.
        // No supervisor components supported, so only 0 is valid.
        if msr_val != zeros() then raise_GP0()
      } else if ecx >=_u 0x00000480 & ecx <=_u 0x00000491 then {
        // VMX capability MSRs are read-only — #GP(0) on write
        raise_GP0()
      } else {
        __wrmsr(ecx, msr_val)
      }
    },

    // 0F 18-1E: Prefetch hints / multi-byte NOPs
    // These all consume ModR/M and do nothing.
    op if 24 <= op & op <= 30 => {
      let modrm = fetch(1);
      let _ = modrm_rm(modrm, pfx)
    },

    // 0F 31: RDTSC
    // SDM: #GP(0) if CR4.TSD (bit 2) = 1 and CPL > 0
    49 => {
      if CR4[2] == 0b1 & cur_cpl != 0 then raise_GP0();
      vmx_exit_if_rdtsc();
      let tsc = __rdtsc();
      v(RAX) = tsc[31..0];
      v(RDX) = tsc[63..32]
    },

    // 0F 33: RDPMC — Read Performance-Monitoring Counter
    // SDM pseudocode:
    //   IF (((CR4.PCE = 1) or (CPL = 0)) and (ECX indicates a supported counter))
    //     THEN EAX := counter[31:0]; EDX := ZeroExtend(counter[MSCB:32]);
    //     ELSE #GP(0);
    //   FI;
    // No performance counters are modeled, so ECX always indicates an
    // unsupported counter → unconditional #GP(0).
    51 => raise_GP0(),

    // 0F 34: SYSENTER — Fast System Call
    // SDM Vol.2 SYSENTER pseudocode: loads CS/SS selectors from
    // IA32_SYSENTER_CS, forces RPL=0, then populates the hidden CS/SS
    // descriptor cache with fixed values (base=0, limit=4GB, code/data).
    // In IA-32e mode SYSENTER switches to 64-bit mode (CS.L=1, CS.D=0);
    // in legacy protected mode it enters 32-bit code (CS.L=0, CS.D=1).
    // The original handler only wrote the visible selectors and set CPL=0,
    // which left cur_mode and the stale user SegCache[CS]/[SS] in place —
    // so the kernel entry point ran with stack_addr_size() returning 32,
    // truncating PUSH addresses to the low 32 bits of RSP.
    52 => {
      let sysenter_cs : qword = __rdmsr(0x00000174);
      if sysenter_cs[15..0] == zeros() then raise_GP0();
      let ia32e : bool = EFER[10] == 0b1;
      write_segreg(CS, sysenter_cs[15..0] & 0xFFFC);
      SegCache[CS] = struct {
        seg_base    = 0x0000000000000000,
        seg_limit   = 0xFFFFFFFF,
        seg_type    = 0xB,   // exec/read/accessed code
        seg_s       = 0b1,
        seg_dpl     = 0,
        seg_present = 0b1,
        seg_db      = if ia32e then 0b0 else 0b1,
        seg_l       = if ia32e then 0b1 else 0b0,
        seg_g       = 0b1,
      };
      cur_cpl = 0;
      write_segreg(SS, (sysenter_cs[15..0] + 0x0008) & 0xFFFC);
      SegCache[SS] = struct {
        seg_base    = 0x0000000000000000,
        seg_limit   = 0xFFFFFFFF,
        seg_type    = 0x3,   // R/W data/accessed
        seg_s       = 0b1,
        seg_dpl     = 0,
        seg_present = 0b1,
        seg_db      = 0b1,   // B = 1 (32-bit stack); in 64-bit CPL 0 uses RSP
        seg_l       = 0b0,
        seg_g       = 0b1,
      };
      if ia32e then cur_mode = LongMode
      else cur_mode = ProtectedMode;

      let sysenter_esp : qword = __rdmsr(0x00000175);
      let sysenter_eip : qword = __rdmsr(0x00000176);
      v(RSP) = if ia32e then sysenter_esp else zero_extend(sysenter_esp[31..0]);
      IF_flag = 0b0;
      next_rip = Some(if ia32e then sysenter_eip else zero_extend(sysenter_eip[31..0]))
    },

    // 0F 35: SYSEXIT — Fast Return from System Call (companion to SYSENTER)
    // SDM Vol.2 SYSEXIT pseudocode: loads CS/SS selectors from
    // IA32_SYSENTER_CS and sets the hidden descriptor cache to fixed values.
    // 64-bit SYSEXIT (REX.W=1) returns to 64-bit user (CS.L=1, CS.D=0);
    // 32-bit SYSEXIT (REX.W=0) returns to compat-mode user (CS.L=0, CS.D=1).
    // Without the descriptor-cache / cur_mode updates, the user code runs
    // with stale kernel-CS metadata (or whatever was last loaded).
    53 => {
      if cur_cpl != 0 then raise_GP0();
      let sysenter_cs : qword = __rdmsr(0x00000174);
      if sysenter_cs[15..0] == zeros() then raise_GP0();
      if pfx.rex_w then {
        // 64-bit: CS.sel = IA32_SYSENTER_CS + 32, SS.sel = IA32_SYSENTER_CS + 40
        write_segreg(CS, (sysenter_cs[15..0] + 0x0020) | 0x0003);
        SegCache[CS] = struct {
          seg_base    = 0x0000000000000000,
          seg_limit   = 0xFFFFFFFF,
          seg_type    = 0xB,
          seg_s       = 0b1,
          seg_dpl     = 3,
          seg_present = 0b1,
          seg_db      = 0b0,
          seg_l       = 0b1,
          seg_g       = 0b1,
        };
        write_segreg(SS, (sysenter_cs[15..0] + 0x0028) | 0x0003);
        SegCache[SS] = struct {
          seg_base    = 0x0000000000000000,
          seg_limit   = 0xFFFFFFFF,
          seg_type    = 0x3,
          seg_s       = 0b1,
          seg_dpl     = 3,
          seg_present = 0b1,
          seg_db      = 0b1,
          seg_l       = 0b0,
          seg_g       = 0b1,
        };
        cur_cpl = 3;
        cur_mode = LongMode;
        next_rip = Some(v(64, RDX));
        v(RSP) = v(64, RCX)
      } else {
        // 32-bit: CS.sel = IA32_SYSENTER_CS + 16, SS.sel = IA32_SYSENTER_CS + 24
        write_segreg(CS, (sysenter_cs[15..0] + 0x0010) | 0x0003);
        SegCache[CS] = struct {
          seg_base    = 0x0000000000000000,
          seg_limit   = 0xFFFFFFFF,
          seg_type    = 0xB,
          seg_s       = 0b1,
          seg_dpl     = 3,
          seg_present = 0b1,
          seg_db      = 0b1,   // D = 1 (32-bit compat code)
          seg_l       = 0b0,
          seg_g       = 0b1,
        };
        write_segreg(SS, (sysenter_cs[15..0] + 0x0018) | 0x0003);
        SegCache[SS] = struct {
          seg_base    = 0x0000000000000000,
          seg_limit   = 0xFFFFFFFF,
          seg_type    = 0x3,
          seg_s       = 0b1,
          seg_dpl     = 3,
          seg_present = 0b1,
          seg_db      = 0b1,
          seg_l       = 0b0,
          seg_g       = 0b1,
        };
        cur_cpl = 3;
        if EFER[10] == 0b1 then cur_mode = CompatibilityMode
        else cur_mode = ProtectedMode;
        next_rip = Some(zero_extend(v(32, RDX)));
        v(RSP) = zero_extend(64, v(32, RCX))
      }
    },

    // 0F 32: RDMSR — Read MSR (requires CPL=0)
    50 => {
      if cur_cpl != 0 then raise_GP0();
      vmx_exit_if_rdmsr();
      let ecx : dword = v(RCX);
      // Handle registers with Sail state specially
      let msr : qword = match ecx {
        0xC0000080 => EFER,
        0x0000003A => ia32_feature_control,
        0x00000DA0 => zeros(), // IA32_XSS is always 0 (no supervisor state components supported)
        0xC0000100 => SegCache[FS].seg_base,
        0xC0000101 => SegCache[GS].seg_base,
        0xC0000102 => KERNEL_GS_BASE,
        // VMX Capability MSRs (SDM Appendix A) — read-only
        0x00000480 => 0x0098040000000001, // VMX_BASIC: rev=1, size=1024, WB, TRUE controls
        0x00000481 => 0x0000003F00000016, // VMX_PINBASED_CTLS
        0x00000482 => 0xFFF9FFFE0401E172, // VMX_PROCBASED_CTLS
        0x00000483 => 0x003FFFFF00036DFF, // VMX_EXIT_CTLS
        0x00000484 => 0x0000F3FF000011FF, // VMX_ENTRY_CTLS
        0x00000485 => 0x0000000000000020, // VMX_MISC
        0x00000486 => 0x0000000080000021, // VMX_CR0_FIXED0: PE+NE+PG must be 1
        0x00000487 => 0x00000000FFFFFFFF, // VMX_CR0_FIXED1: all allowed
        0x00000488 => 0x0000000000002000, // VMX_CR4_FIXED0: VMXE must be 1
        0x00000489 => 0x00000000FFFFFFFF, // VMX_CR4_FIXED1: all bits allowed
        0x0000048A => 0x000000000000002E, // VMX_VMCS_ENUM
        0x0000048B => 0x001010EA00000000, // VMX_PROCBASED_CTLS2: EPT, unrestricted guest, RDTSCP, WBINVD, INVPCID, XSAVES
        0x0000048C => 0x0000000006134141, // VMX_EPT_VPID_CAP: exec-only, 4-level walk, UC, WB, 2MB, 1GB, INVEPT
        0x0000048D => 0x0000003F00000000, // VMX_TRUE_PINBASED_CTLS
        0x0000048E => 0xFFF9FFFE04006172, // VMX_TRUE_PROCBASED_CTLS
        0x0000048F => 0x003FFFFF00036DFB, // VMX_TRUE_EXIT_CTLS
        0x00000490 => 0x0000F3FF000011FB, // VMX_TRUE_ENTRY_CTLS
        0x00000491 => 0x0000000000000000, // VMX_VMFUNC: no VM functions
        0x00000492 => 0x0000000000000000, // VMX_PROCBASED_CTLS3: no tertiary controls
        _ => __rdmsr(ecx),
      };
      v(RAX) = msr[31..0];
      v(RDX) = msr[63..32]
    },

    // 0F 40-4F: CMOVcc r, r/m
    op if 64 <= op & op <= 79 => {
      let cc : cc_idx = op - 64;
      let os = opsize(pfx);
      let (reg, src) = fetch_modrm(pfx);
      v(reg) = blend(v(os, reg), v(os, src), eval_cc(cc))
    },

    // 0F 77: EMMS — set x87 tag word to all empty
    119 => x87_tw = 0xFFFF,

    // 0F 80-8F: Jcc rel16/rel32 (forced64)
    op if 128 <= op & op <= 143 => {
      let cc : cc_idx = op - 128;
      let rs = opsize_rel(pfx);
      let offset : qword = sign_extend(fetch(rs / 8));
      if eval_cc(cc) == 0b1 then {
        let os = opsize_forced64(pfx);
        next_rip = Some(zero_extend((decode_pos + offset)[(os - 1) .. 0]));
      }
    },

    // 0F 90-9F: SETcc r/m8
    op if 144 <= op & op <= 159 => {
      let cc : cc_idx = op - 144;
      let modrm = fetch(1);
      let dest = modrm_rm(modrm, pfx);
      v(dest) = zero_extend(8, eval_cc(cc))
    },

    // 0F AE: Group 15 — FXSAVE/FXRSTOR/LDMXCSR/STMXCSR/XSAVE/XRSTOR/
    //                    LFENCE/MFENCE/SFENCE/RDFSBASE/RDGSBASE/WRFSBASE/WRGSBASE
    174 => {
      let (reg_field, dest) = fetch_modrm_raw(pfx);
      // F3 prefix with mod=11 and reg_field 0-3: FSGSBASE instructions
      // SDM: #UD if CR4.FSGSBASE (bit 16) = 0
      if pfx.has_rep & reg_field <= 3 then {
        if CR4[16] != 0b1 then raise_UD();
        match dest {
          RM_reg(r) => match (reg_field, pfx.rex_w) {
            // F3 0F AE /0 mod=11: RDFSBASE r32/r64
            (0, true)  => v(r) = SegCache[FS].seg_base,
            (0, false) => v(r) = SegCache[FS].seg_base[31..0],
            // F3 0F AE /1 mod=11: RDGSBASE r32/r64
            (1, true)  => v(r) = SegCache[GS].seg_base,
            (1, false) => v(r) = SegCache[GS].seg_base[31..0],
            // F3 0F AE /2 mod=11: WRFSBASE r32/r64
            (2, true)  => SegCache[FS].seg_base = v(64, r),
            (2, false) => SegCache[FS].seg_base = zero_extend(v(32, r)),
            // F3 0F AE /3 mod=11: WRGSBASE r32/r64
            (3, true)  => SegCache[GS].seg_base = v(64, r),
            (3, false) => SegCache[GS].seg_base = zero_extend(v(32, r)),
            _ => raise_UD(),
          },
          RM_mem(_) => raise_UD(),
        }
      } else match reg_field {
        // FXSAVE m512byte
        0 => match (dest, pfx.rex_w) {
          (RM_mem(m), true)  => __fxsave64(seg_linear(m, 512)),
          (RM_mem(m), false) => __fxsave(seg_linear(m, 512)),
          _ => raise_UD(),
        },

        // FXRSTOR m512byte
        1 => match (dest, pfx.rex_w) {
          (RM_mem(m), true)  => __fxrstor64(seg_linear(m, 512)),
          (RM_mem(m), false) => __fxrstor(seg_linear(m, 512)),
          _ => raise_UD(),
        },

        // LDMXCSR m32
        2 => __ldmxcsr(rm_mem(dest)),

        // STMXCSR m32
        3 => rm_mem(dest) = __stmxcsr(),

        // XSAVE m
        4 => match dest {
          RM_mem(m) => {
            let mask : qword = v(32, RDX) @ v(32, RAX);
            exec_xsave(seg_linear(m, 576), mask)
          },
          RM_reg(_) => raise_UD(),
        },

        5 => match dest {
          RM_mem(m) => {
            // /5 mem: XRSTOR m
            let mask : qword = v(32, RDX) @ v(32, RAX);
            exec_xrstor(seg_linear(m, 576), mask)
          },
          RM_reg(_) => {
            // /5 mod=11: LFENCE
            ()
          },
        },

        // /6: XSAVEOPT (NP, mem) / CLWB (66, mem) / MFENCE (reg)
        6 => match dest {
          RM_mem(m) => {
            if pfx.has_opsize then {
              ()  // CLWB: NOP (cache write-back, no architectural effect)
            } else {
              // XSAVEOPT: architecturally equivalent to XSAVE
              let mask : qword = v(32, RDX) @ v(32, RAX);
              exec_xsaveopt(seg_linear(m, 576), mask)
            }
          },
          RM_reg(_) => (),  // MFENCE
        },

        // /7: CLFLUSH (NP, mem) / CLFLUSHOPT (66, mem) / SFENCE (reg)
        7 => (),
      }
    },

    // 0F A2: CPUID — unconditional VM exit in non-root (SDM §26.1.2)
    162 => {
      vmx_exit_cpuid();
      let leaf : dword = v(RAX);
      let subleaf : dword = v(RCX);
      let (eax, ebx, ecx, edx) = cpuid(leaf, subleaf);
      v(RAX) = eax;
      v(RBX) = ebx;
      v(RCX) = ecx;
      v(RDX) = edx
    },

    // 0F A0: PUSH FS (d64)
    // SDM: pushes FS selector. d64 = default 64 in long mode.
    // Non-64-bit mode: operand size from CS.D and 66h prefix.
    160 => {
      let os = opsize_default64(pfx);
      match os {
        16 => push(16, read_segreg(FS)),
        32 => push(32, zero_extend(read_segreg(FS))),
        64 => push(64, zero_extend(read_segreg(FS))),
      }
    },

    // 0F A1: POP FS (d64)
    161 => {
      let os = opsize_default64(pfx);
      load_segment_register(FS, match os {
        16 => pop(16),
        32 => pop(32)[15..0],
        64 => pop(64)[15..0],
      })
    },

    // 0F A3: BT r/m, r
    163 => {
      let os = opsize(pfx);
      let (reg, src) = fetch_modrm(pfx);
      let bit_idx = v(os, reg);
      let (adj_rm, bit_num) = bt_adjust(src, bit_idx);
      CF = v(os, adj_rm)[bit_num]
    },

    // 0F A4: SHLD r/m, r, imm8
    164 => {
      let os = opsize(pfx);
      let (reg, dest) = fetch_modrm(pfx);
      let count = fetch(1);
      v(dest) = exec_shld(os, v(dest), v(reg), count)
    },

    // 0F A5: SHLD r/m, r, CL
    165 => {
      let os = opsize(pfx);
      let (reg, dest) = fetch_modrm(pfx);
      let count : byte = v(RCX);
      v(dest) = exec_shld(os, v(dest), v(reg), count)
    },

    // 0F A8: PUSH GS (d64)
    168 => {
      let os = opsize_default64(pfx);
      match os {
        16 => push(16, read_segreg(GS)),
        32 => push(32, zero_extend(read_segreg(GS))),
        64 => push(64, zero_extend(read_segreg(GS))),
      }
    },

    // 0F A9: POP GS (d64)
    169 => {
      let os = opsize_default64(pfx);
      load_segment_register(GS, match os {
        16 => pop(16),
        32 => pop(32)[15..0],
        64 => pop(64)[15..0],
      })
    },

    // 0F AA: RSM — Resume from System Management Mode
    // SDM Vol.2B §RSM: #UD if not in SMM. Restores processor state from
    // SMRAM and returns to the mode active before the SMI.
    170 => exec_rsm(),

    // 0F AB: BTS r/m, r
    171 => {
      let os = opsize(pfx);
      let (reg, dest) = fetch_modrm(pfx);
      check_lock_rm(pfx, dest, false);
      let bit_idx = v(os, reg);
      let (adj_rm, bit_num) = bt_adjust(dest, bit_idx);
      var x = v(os, adj_rm);
      CF = x[bit_num];
      x[bit_num] = 0b1;
      v(adj_rm) = x
    },

    // 0F AC: SHRD r/m, r, imm8
    172 => {
      let os = opsize(pfx);
      let (reg, dest) = fetch_modrm(pfx);
      let count = fetch(1);
      v(dest) = exec_shrd(os, v(dest), v(reg), count)
    },

    // 0F AD: SHRD r/m, r, CL
    173 => {
      let os = opsize(pfx);
      let (reg, dest) = fetch_modrm(pfx);
      let count : byte = v(RCX);
      v(dest) = exec_shrd(os, v(dest), v(reg), count)
    },

    // 0F AF: IMUL r, r/m (2-operand)
    // SDM: SF, ZF, AF, PF are undefined after IMUL.
    175 => {
      let os = opsize(pfx);
      let (reg, src) = fetch_modrm(pfx);
      let a = v(os, reg);
      let b = v(os, src);
      let product : int = signed(sign_extend(a) : qword) * signed(sign_extend(b) : qword);
      let result : qword = to_bits_truncate(product);
      let w = to_bits_truncate(os * 2, product);
      CF = is_nonzero(w[os * 2 - 1 .. os] ^ sign_extend(w[os - 1]));
      OF = CF;
      SF = undefined;
      ZF = undefined;
      AF = undefined;
      PF = undefined;
      v(reg) = to_bits_truncate(os, product)
    },

    // 0F B3: BTR r/m, r
    179 => {
      let os = opsize(pfx);
      let (reg, dest) = fetch_modrm(pfx);
      check_lock_rm(pfx, dest, false);
      let bit_idx = v(os, reg);
      let (adj_rm, bit_num) = bt_adjust(dest, bit_idx);
      var x = v(os, adj_rm);
      CF = x[bit_num];
      x[bit_num] = 0b0;
      v(os, adj_rm) = x
    },

    // 0F B2: LSS r, m16:16/32/64 — Load far pointer into SS
    // 0F B4: LFS r, m16:16/32/64 — Load far pointer into FS
    // 0F B5: LGS r, m16:16/32/64 — Load far pointer into GS
    // Memory format: [offset (16/32/64-bit)][selector (16-bit)]
    // Register operand only (memory source); #UD for register source.
    op if op == 178 | op == 180 | op == 181 => {
      let os = opsize(pfx);
      let (reg, src) = fetch_modrm(pfx);
      match src {
        RM_mem(m) => {
          let (far_offset, selector) = read_far_pointer(os, m);
          v(reg) = far_offset;
          let seg : segreg_idx = match op {
            178 => SS,
            180 => FS,
            181 => GS,
          };
          load_segment_register(seg, selector)
        },
        RM_reg(_) => raise_UD(),
      }
    },

    // 0F B0: CMPXCHG r/m8, r8
    176 => {
      let (reg, dest) = fetch_modrm(pfx);
      check_lock_rm(pfx, dest, false);
      let dest_val = v(8, dest);
      let acc : byte = v(RAX);
      let src : byte = v(reg);
      let cmp_result = acc - dest_val;
      update_flags_sub(cmp_result, acc, dest_val);
      v(dest) = blend(dest_val, src, ZF);
      v(RAX) = blend(dest_val, acc, ZF)
    },

    // 0F B1: CMPXCHG r/m, r
    177 => {
      let os = opsize(pfx);
      let (reg, dest) = fetch_modrm(pfx);
      check_lock_rm(pfx, dest, false);
      let dest_val = v(os, dest);
      let acc = v(os, RAX);
      let src = v(os, reg);
      let cmp_result = acc - dest_val;
      update_flags_sub(cmp_result, acc, dest_val);
      v(os, dest) = blend(dest_val, src, ZF);
      v(RAX) = blend(dest_val, acc, ZF)
    },

    // 0F B6: MOVZX r, r/m8
    182 => {
      let os = opsize(pfx);
      let (reg, src) = fetch_modrm(pfx);
      v(reg) = zero_extend(os, v(8, src))
    },

    // 0F B7: MOVZX r, r/m16
    183 => {
      let os = opsize(pfx);
      let (reg, src) = fetch_modrm(pfx);
      v(reg) = zero_extend(os, v(16, src))
    },

    // 0F BA: Group 8 — BT/BTS/BTR/BTC r/m, imm8
    186 => {
      let os = opsize(pfx);
      let (reg_field, dest) = fetch_modrm_raw(pfx);
      // LOCK valid only for BTS (/5), BTR (/6), BTC (/7) with memory
      if pfx.has_lock & reg_field == 4 then raise_UD();
      check_lock_rm(pfx, dest, false);
      let imm = fetch(1);
      var x = v(os, dest);
      let bit_num : range(0, 63) = unsigned(imm) % os;
      assert(bit_num < os);
      CF = x[bit_num];
      match reg_field {
        // BT — just test, no modification
        4 => (),
        // BTS — set bit
        5 => {
          x[bit_num] = 0b1;
          v(dest) = x
        },
        // BTR — reset bit
        6 => {
          x[bit_num] = 0b0;
          v(dest) = x
        },
        // BTC — complement bit
        7 => {
          x[bit_num] = ~(x[bit_num]);
          v(dest) = x
        },
        _ => raise_UD(),
      }
    },

    // 0F BB: BTC r/m, r
    187 => {
      let os = opsize(pfx);
      let (reg, dest) = fetch_modrm(pfx);
      check_lock_rm(pfx, dest, false);
      let bit_idx = v(os, reg);
      let (adj_rm, bit_num) = bt_adjust(dest, bit_idx);
      var x = v(os, adj_rm);
      CF = x[bit_num];
      x[bit_num] = ~(x[bit_num]);
      v(os, adj_rm) = x
    },

    // 0F BC: BSF r, r/m (or TZCNT with F3 prefix)
    188 => {
      let os = opsize(pfx);
      let (reg, src) = fetch_modrm(pfx);
      if pfx.has_rep then {
        // TZCNT r16/r32/r64, r/m16/r/m32/r/m64
        if ~(has_bmi1) then raise_UD();
        let src_val = v(os, src);
        let count = ctz(src_val);
        let result : qword = to_bits_truncate(count);
        v(reg) = result[(os - 1) .. 0];
        CF = is_zero(src_val);
        ZF = src_val[0]
      } else {
        // BSF r16/r32/r64, r/m16/r/m32/r/m64
        // SDM: ZF is set if the source is zero and cleared otherwise; CF,
        // OF, SF, AF, PF are undefined, and so is the destination for a
        // zero source.  The model deliberately fixes the de-facto behavior
        // instead.  Flags: CF/OF/SF/AF cleared and PF from the result's
        // parity, as observed on both differential hosts (AMD Zen 4 and
        // Intel Emerald Rapids).  Destination: untouched on a zero
        // source.  That rule is a contract programs rely on, not a
        // modeling choice: AMD documents it, and Linux's ffs()/fls()
        // (arch/x86/include/asm/bitops.h) preload -1 into the destination
        // and depend on it surviving, citing Intel's architects for the
        // same guarantee.  A model that leaves the destination undefined
        // (the C++ backend folds it to zero) panics Linux early in boot.
        // "Untouched" means the whole 64-bit register: for a 32-bit
        // operand both hosts preserve the upper half too, so the write
        // below is undone rather than repeated at operand width (which
        // would zero-extend).  The kernel comment describes Intel as
        // rewriting the old value, which would clear the upper half; the
        // Emerald Rapids run shows that it does not.  The differential
        // templates compare the fixed behavior.
        let src_val = v(os, src);
        let zf : bit = is_zero(src_val);
        let idx = ctz(src_val);
        let result : qword = to_bits_truncate(idx);
        CF = 0b0;
        OF = 0b0;
        SF = 0b0;
        AF = 0b0;
        ZF = zf;
        PF = blend(compute_PF(result[7..0]), 0b1, zf);  // PF(0x00) = 1 (even parity)
        let old : qword = GPR[reg.gpr_idx];
        v(reg) = result[(os - 1) .. 0];
        GPR[reg.gpr_idx] = blend(GPR[reg.gpr_idx], old, zf)
      }
    },

    // 0F BD: BSR r, r/m (or LZCNT with F3 prefix)
    189 => {
      let os = opsize(pfx);
      let (reg, src) = fetch_modrm(pfx);
      if pfx.has_rep then {
        // LZCNT r16/r32/r64, r/m16/r/m32/r/m64
        if ~(has_lzcnt) then raise_UD();
        let src_val = v(os, src);
        let count = clz(src_val);
        let result : qword = to_bits_truncate(count);
        v(reg) = result[(os - 1) .. 0];
        CF = is_zero(src_val);
        ZF = src_val[os - 1]
      } else {
        // BSR r16/r32/r64, r/m16/r/m32/r/m64
        // Same flag and destination rules as BSF above, fixed for the same
        // reasons (Linux's fls() relies on the destination surviving a
        // zero source exactly as ffs() does).
        let src_val = v(os, src);
        let zf : bit = is_zero(src_val);
        // Sentinel bit 0 ensures bsr gets nonzero input; result ignored when zf=1
        let idx : range(0, 63) = bsr(zero_extend(src_val) | 0x0000000000000001);
        let result : qword = to_bits_truncate(idx);
        CF = 0b0;
        OF = 0b0;
        SF = 0b0;
        AF = 0b0;
        ZF = zf;
        PF = blend(compute_PF(result[7..0]), 0b1, zf);  // PF(0x00) = 1 (even parity)
        let old : qword = GPR[reg.gpr_idx];
        v(reg) = result[(os - 1) .. 0];
        GPR[reg.gpr_idx] = blend(GPR[reg.gpr_idx], old, zf)
      }
    },

    // 0F BE: MOVSX r, r/m8
    190 => {
      let os = opsize(pfx);
      let (reg, src) = fetch_modrm(pfx);
      let sx : qword = sign_extend(v(8, src));
      v(reg) = sx[(os - 1) .. 0]
    },

    // 0F BF: MOVSX r, r/m16
    191 => {
      let os = opsize(pfx);
      let (reg, src) = fetch_modrm(pfx);
      let sx : qword = sign_extend(v(16, src));
      v(reg) = sx[(os - 1) .. 0]
    },

    // 0F C0: XADD r/m8, r8
    192 => {
      let (reg, dest) = fetch_modrm(pfx);
      check_lock_rm(pfx, dest, false);
      match dest {
        RM_reg(dst) => exec_xadd(dst, reg, 8),
        RM_mem(m) => {
          // Memory operand: read, exchange, add, write back
          let mem_val : byte = v(m);
          let reg_val : byte = v(reg);
          let sum : byte = mem_val + reg_val;
          update_flags_add(sum, mem_val, reg_val);
          v(reg) = mem_val;
          v(m) = sum
        },
      }
    },

    // 0F C1: XADD r/m, r
    193 => {
      let os = opsize(pfx);
      let (reg, dest) = fetch_modrm(pfx);
      check_lock_rm(pfx, dest, false);
      match dest {
        RM_reg(dst) => exec_xadd(dst, reg, os),
        RM_mem(_) => {
          let mem_val = v(os, dest);
          let reg_val = v(os, reg);
          let sum = mem_val + reg_val;
          update_flags_add(sum, mem_val, reg_val);
          v(reg) = mem_val;
          v(os, dest) = sum
        },
      }
    },

    // 0F B8: POPCNT r, r/m (F3 prefix)
    184 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_F3 then raise_UD();
      if ~(has_popcnt) then raise_UD();
      let os = opsize(pfx);
      let (reg, src) = fetch_modrm(pfx);
      let src_val = v(os, src);
      let count : range(0, 64) = popcount(zero_extend(src_val) : qword);
      OF = 0b0;
      SF = 0b0;
      AF = 0b0;
      CF = 0b0;
      PF = 0b0;
      ZF = is_zero(src_val);
      let result : qword = to_bits_truncate(count);
      v(reg) = result[(os - 1) .. 0]
    },

    // 0F C3: MOVNTI m32/64, r
    195 => {
      let os = opsize(pfx);
      let (reg, dest) = fetch_modrm(pfx);
      rm_mem(dest) = v(os, reg)
    },

    // 0F C7 /1: CMPXCHG8B/CMPXCHG16B m64/m128
    199 => {
      let (reg_field, dest) = fetch_modrm_raw(pfx);
      match reg_field {
        // CMPXCHG8B/CMPXCHG16B m64/m128
        1 => match dest {
          RM_mem(m) => {
            if pfx.rex_w then {
              if ~(has_cx16) then raise_UD();
              let mem_val : bits(128) = read_mem(m);
              let mem_lo : qword = mem_val[63..0];
              let mem_hi : qword = mem_val[127..64];
              let eq : bit = is_eq(v(64, RAX), mem_lo) & is_eq(v(64, RDX), mem_hi);
              ZF = eq;
              if eq == 0b1 then write_mem(128, m, v(64, RCX) @ v(64, RBX));
              v(RAX) = blend(mem_lo, v(64, RAX), eq);
              v(RDX) = blend(mem_hi, v(64, RDX), eq)
            } else {
              let mem_val : qword = v(m);
              let mem_lo : dword = mem_val[31..0];
              let mem_hi : dword = mem_val[63..32];
              let eq : bit = is_eq(v(32, RAX), mem_lo) & is_eq(v(32, RDX), mem_hi);
              ZF = eq;
              if eq == 0b1 then v(m) = v(32, RCX) @ v(32, RBX);
              v(RAX) = blend(mem_lo, v(32, RAX), eq);
              v(RDX) = blend(mem_hi, v(32, RDX), eq)
            }
          },
          RM_reg(_) => raise_UD(),
        },
        // /4 mem: XSAVEC — save extended state with compaction
        // /3 mem: XRSTORS — restore extended state (supervisor, requires CPL=0)
        3 => match dest {
          RM_mem(m) => {
            if cur_cpl != 0 then raise_GP0();
            let mask : qword = v(32, RDX) @ v(32, RAX);
            exec_xrstors(seg_linear(m, 576), mask)
          },
          _ => raise_UD(),
        },
        // /4 mem: XSAVEC — save extended state with compaction
        4 => match dest {
          RM_mem(m) => {
            let mask : qword = v(32, RDX) @ v(32, RAX);
            exec_xsavec(seg_linear(m, 576), mask)
          },
          _ => raise_UD(),
        },
        // /5 mem: XSAVES — save extended state (supervisor, requires CPL=0)
        5 => match dest {
          RM_mem(m) => {
            if cur_cpl != 0 then raise_GP0();
            let mask : qword = v(32, RDX) @ v(32, RAX);
            exec_xsaves(seg_linear(m, 576), mask)
          },
          _ => raise_UD(),
        },
        // /6: RDRAND (mod=11) or VMX (mod!=11)
        6 => match dest {
          RM_reg(r) => {
            // /6 mod=11: RDRAND r16/r32/r64
            if ~(has_rdrand) then raise_UD();
            let os = opsize(pfx);
            let (rnd, cf_val) = __rdrand64();
            v(r) = rnd[(os - 1) .. 0] & sign_extend(cf_val);
            CF = cf_val;
            OF = 0b0;
            SF = 0b0;
            ZF = 0b0;
            AF = 0b0;
            PF = 0b0
          },
          RM_mem(m) => {
            // /6 mem: VMX instructions discriminated by prefix
            // NP 0F C7 /6 mem → VMPTRLD
            // 66 0F C7 /6 mem → VMCLEAR
            // F3 0F C7 /6 mem → VMXON
            if pfx.has_rep then
              vmx_exit_vmx_insn(VMEXIT_VMXON)
            else if pfx.has_opsize then
              vmx_exit_vmx_insn(VMEXIT_VMCLEAR)
            else
              vmx_exit_vmx_insn(VMEXIT_VMPTRLD);
            let addr = seg_linear(m, 8);
            if pfx.has_rep then
              exec_vmxon(addr)
            else if pfx.has_opsize then
              exec_vmclear(addr)
            else
              exec_vmptrld(addr)
          },
        },
        // /7: RDSEED (mod=11) or VMPTRST (mod!=11)
        7 => match dest {
          RM_reg(r) => {
            // /7 mod=11: RDSEED r16/r32/r64
            if ~(has_rdseed) then raise_UD();
            let os = opsize(pfx);
            let (rnd, cf_val) = __rdseed64();
            v(r) = rnd[(os - 1) .. 0] & sign_extend(cf_val);
            CF = cf_val;
            OF = 0b0;
            SF = 0b0;
            ZF = 0b0;
            AF = 0b0;
            PF = 0b0
          },
          RM_mem(m) => {
            // /7 mem: VMPTRST — store current VMCS pointer
            vmx_exit_vmx_insn(VMEXIT_VMPTRST);
            exec_vmptrst(seg_linear(m, 8))
          },
        },
        _ => raise_UD(),
      }
    },

    // 0F C8-CF: BSWAP r32/r64 (register in opcode)
    op if 200 <= op & op <= 207 => {
      let reg_field : range(0, 7) = op - 200;
      let reg = unsigned(pfx.rex_b @ to_bits(3, reg_field));
      let os = opsize(pfx);
      if os == 16 then {
        // SDM says "result is undefined" for 16-bit operand, but real
        // hardware zeroes the low 16 bits.
        v(reg) = zeros() : word
      } else {
        v(os, reg) = bswap(v(os, reg))
      }
    },

    // 0F 78: VMREAD r/m64, r64 (SDM Vol.3C §31.2.4)
    // In 64-bit mode, operand size is always 64 bits.
    120 => {
      vmx_exit_vmx_insn(VMEXIT_VMREAD);
      let (reg, dest) = fetch_modrm(pfx);
      exec_vmread(pfx, dest, reg.gpr_idx)
    },

    // 0F 79: VMWRITE r64, r/m64 (SDM Vol.3C §31.2.5)
    121 => {
      vmx_exit_vmx_insn(VMEXIT_VMWRITE);
      let (reg, src) = fetch_modrm(pfx);
      exec_vmwrite(pfx, src, reg.gpr_idx)
    },

    _ => raise_UD(),
  }
}
