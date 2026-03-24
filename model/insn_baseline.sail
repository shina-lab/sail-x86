// x86-64 — 2-Byte Opcode Map: Baseline Operations
//
// CMOVcc, Jcc, SETcc, BT/BTS/BTR/BTC, SHLD/SHRD, IMUL, MOVZX/MOVSX,
// BSF/BSR, POPCNT, CMPXCHG, XADD, BSWAP, CPUID, RDTSC, and more.

// Check LOCK prefix validity: requires memory destination on a lockable instruction.
// LOCK with register operand or on CMP (which doesn't write) raises #UD.
val check_lock_rm : (Prefixes, RM, bool) -> unit
function check_lock_rm(pfx, dest, is_cmp) = {
  if pfx.has_lock then {
    match dest {
      RM_reg(_, _) => raise_UD(),
      RM_mem(_, _) => if is_cmp then raise_UD() else (),
    }
  }
}

// XADD — Exchange and Add
val exec_xadd : (gpr_idx, gpr_idx, operand_size) -> unit
function exec_xadd(dst, src, os) = {
  let a = reg(os, dst);
  let b = reg(os, src);
  let sum = a + b;
  update_flags_add(sum, a, b);
  reg(src) = a;
  reg(dst) = sum
}

// Branchless CLZ via smear (fill all bits below MSB) then popcount.
val clz : ({16, 32, 64}, qword) -> range(0, 64)
function clz(os, v) = {
  let x1 : qword = v  | (v  >> 1);
  let x2 : qword = x1 | (x1 >> 2);
  let x3 : qword = x2 | (x2 >> 4);
  let x4 : qword = x3 | (x3 >> 8);
  let x5 : qword = x4 | (x4 >> 16);
  let x6 : qword = x5 | (x5 >> 32);
  let pc = popcount(x6);
  assert(pc <= os);
  os - pc
}

// Branchless CTZ via popcount: ctz(v) = popcount(~v & (v - 1))
val ctz : ({16, 32, 64}, qword) -> range(0, 64)
function ctz(os, v) = {
  let masked : qword = v | (0xFFFFFFFFFFFFFFFF << os);
  popcount(~(masked) & (masked - 1))
}

// Branchless BSR (bit scan reverse): index of highest set bit = popcount(smear) - 1.
// Precondition: v != 0 (BSR is undefined for zero).
val bsr : qword -> range(0, 63)
function bsr(v) = {
  let x1 : qword = v  | (v  >> 1);
  let x2 : qword = x1 | (x1 >> 2);
  let x3 : qword = x2 | (x2 >> 4);
  let x4 : qword = x3 | (x3 >> 8);
  let x5 : qword = x4 | (x4 >> 16);
  let x6 : qword = x5 | (x5 >> 32);
  let n = popcount(x6);
  assert(n > 0);
  n - 1
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
    0 => (0x0000000D, 0x756E6547, 0x6C65746E, 0x49656E69),

    // Leaf 1: Family/Model/Stepping, feature bits
    1 => {
      let eax : dword = 0x000506E3;  // Family 6, Model 5E, Stepping 3
      let ebx : dword = 0x00010800;  // CLFLUSH=8, max logical=1

      // ECX: built dynamically from has_* flags and CR4/XCR0
      var ecx : dword = 0x00000000;
      if has_sse3       then ecx = ecx | 0x00000001;  // bit 0 (SSE3)
      if has_pclmulqdq  then ecx = ecx | 0x00000002;  // bit 1
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
        if has_avx512     then ebx = ebx | 0xD0030000;  // F(16)+DQ(17)+CD(28)+BW(30)+VL(31)
        if has_rdseed     then ebx = ebx | 0x00040000;  // bit 18
        if has_adx        then ebx = ebx | 0x00080000;  // bit 19
        if has_sha        then ebx = ebx | 0x20000000;  // bit 29
        var ecx : dword = 0x00000000;
        if has_la57       then ecx = ecx | 0x00010000;  // bit 16 (LA57)
        if has_movdiri    then ecx = ecx | 0x08000000;  // bit 27
        if has_movdir64b  then ecx = ecx | 0x10000000;  // bit 28
        (0x00000000, ebx, ecx, 0x00000000)
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
      // AVX state (component 2): 256 bytes at offset 576
      (true, 2) => (0x00000100, 0x00000240, 0x00000000, 0x00000000),
      // Opmask state (component 5): 64 bytes at offset 832
      (true, 5) => (0x00000040, 0x00000340, 0x00000000, 0x00000000),
      // ZMM_Hi256 (component 6): 512 bytes at offset 896
      (true, 6) => (0x00000200, 0x00000380, 0x00000000, 0x00000000),
      // Hi16_ZMM (component 7): 1024 bytes at offset 1408
      (true, 7) => (0x00000400, 0x00000580, 0x00000000, 0x00000000),
      _ => (0x00000000, 0x00000000, 0x00000000, 0x00000000)
    },

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

val __rdtsc : unit -> qword
val __rdrand64 : unit -> (qword, bit)
val __rdseed64 : unit -> (qword, bit)

// MSR read/write — implemented in C++ as a key-value store
val __rdmsr : dword -> qword
val __wrmsr : (dword, qword) -> unit

val __syscall : (qword, qword) -> unit
val __fxsave : qword -> unit
val __fxsave64 : qword -> unit
val __fxrstor : qword -> unit
val __fxrstor64 : qword -> unit

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
  if count == 0 then {
    d
  } else if count > os then {
    // SDM: result and flags undefined when count > operand size
    CF = undefined;
    OF = undefined;
    SF = undefined;
    ZF = undefined;
    PF = undefined;
    AF = undefined;
    undefined
  } else {
    let wide = d @ s;
    let shifted = wide << count;
    let r = shifted[(os * 2 - 1)..os];
    CF = wide[os * 2 - count];
    update_SF_ZF_PF(r);
    if count == 1 then
      OF = r[os - 1] ^ d[os - 1]
    else OF = undefined;
    AF = undefined;
    r
  }
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
  if count == 0 then {
    d
  } else if count > os then {
    // SDM: result and flags undefined when count > operand size
    CF = undefined;
    OF = undefined;
    SF = undefined;
    ZF = undefined;
    PF = undefined;
    AF = undefined;
    undefined
  } else {
    let wide = s @ d;
    let shifted = wide >> count;
    let r = shifted[(os - 1)..0];
    CF = d[count - 1];
    update_SF_ZF_PF(r);
    if count == 1 then
      OF = r[os - 1] ^ d[os - 1]
    else OF = undefined;
    AF = undefined;
    r
  }
}

// Adjust BT/BTS/BTR/BTC operands for memory bit string addressing.
// For register rm: bit index is masked to operand size (e.g., mod 64 for 64).
// For memory rm: the full signed bit offset indexes into an arbitrarily long
// bit string, so the effective address is displaced by (offset / op_bits) words.
// Returns (possibly-adjusted RM, bit number within the accessed word).
val bt_adjust : forall 'os, 'os in {16, 32, 64}. (implicit('os), RM, bits('os)) -> (RM, range(0, 'os - 1))
function bt_adjust(os, rm, bit_idx) = {
  match rm {
    RM_reg(_, _) => {
      let bit_num : range(0, 'os - 1) = unsigned(bit_idx) % os;
      (rm, bit_num)
    },
    RM_mem(seg, offset) => {
      // Apply RIP-relative fixup first, before adding the bit string
      // displacement. Otherwise fixup_addr would discard our adjustment.
      let base_addr : qword = fixup_addr(offset);
      rip_rel_pending = false;

      // For memory operands, the full signed bit offset indexes into a bit
      // string starting at the effective address. Compute the word displacement
      // (Euclidean: bit_num is always in [0, op_bits)).
      let off = signed(bit_idx);
      let r = rem_round_zero(off, os);
      let q = quot_round_zero(off, os);
      let (byte_disp, bit_num_int) : (int, int) =
        if r >= 0 then (q * (os / 8), r) else ((q - 1) * (os / 8), r + os);
      let new_addr : qword = base_addr + get_slice_int(64, byte_disp, 0);
      let bit_num : range(0, 63) = unsigned(get_slice_int(6, bit_num_int, 0));
      assert(bit_num < os);
      (RM_mem(seg, new_addr), bit_num)
    },
  }
}

val dispatch_2byte_gpr : (range(0, 255), Prefixes) -> unit
function dispatch_2byte_gpr(op, pfx) = {
  match op {
    // 0F 00: Group 6 (SLDT, STR, LLDT, LTR, VERR, VERW)
    0 => {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      match reg_field {
        // 0F 00 /0: SLDT r/m16 — Store LDTR
        0 => {
          let dest = decode_rm(modrm, pfx);
          match dest {
            RM_reg(r, _) => reg(r) = LDTR,
            RM_mem(seg, offset) => seg_write(seg, offset, LDTR),
          }
        },

        // 0F 00 /1: STR r/m16 — Store Task Register
        1 => {
          let dest = decode_rm(modrm, pfx);
          match dest {
            RM_reg(r, _) => reg(r) = TR,
            RM_mem(seg, offset) => seg_write(seg, offset, TR),
          }
        },

        // 0F 00 /2: LLDT r/m16 — Load LDT Register (requires CPL=0)
        2 => {
          if cur_cpl != 0 then raise_GP0();
          let src = decode_rm(modrm, pfx);
          let sel : word = rm(src);
          LDTR = sel
        },

        // 0F 00 /3: LTR r/m16 — Load Task Register (requires CPL=0)
        3 => {
          if cur_cpl != 0 then raise_GP0();
          let src = decode_rm(modrm, pfx);
          let sel : word = rm(src);
          TR = sel;
          // Load TSS base/limit from GDT descriptor
          let desc_addr : qword = GDTR_base + zero_extend(sel & 0xFFF8);
          let desc_lo : dword = mem_read(desc_addr);
          let desc_hi : dword = mem_read(desc_addr + 4);
          // Base = desc[63:56] @ desc[39:32] @ desc[31:16]
          let base_lo : dword = desc_lo[31..16] @ 0x0000;
          let base_mid : byte = desc_hi[7..0];
          let base_hi : byte = desc_hi[31..24];
          TR_base = zero_extend(base_hi @ base_mid @ base_lo[31..16]);
          // In 64-bit mode, read the next 8 bytes for the high 32 bits of base
          let desc_ext : dword = mem_read(desc_addr + 8);
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
          let src = decode_rm(modrm, pfx);
          let selector : word = rm(src);
          if (selector & 0xFFFC) == zeros() then {
            ZF = 0b0
          } else {
            let sel_offset : qword = zero_extend(selector & 0xFFF8);
            if unsigned(sel_offset) + 7 > unsigned(GDTR_limit) then {
              ZF = 0b0
            } else {
              let desc_hi : dword = mem_read(GDTR_base + sel_offset + 4);
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
          let src = decode_rm(modrm, pfx);
          let selector : word = rm(src);
          if (selector & 0xFFFC) == zeros() then {
            ZF = 0b0
          } else {
            let sel_offset : qword = zero_extend(selector & 0xFFF8);
            if unsigned(sel_offset) + 7 > unsigned(GDTR_limit) then {
              ZF = 0b0
            } else {
              let desc_hi : dword = mem_read(GDTR_base + sel_offset + 4);
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
      let modrm = fetch_byte();
      let modrm_val : range(0, 255) = unsigned(modrm);
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let mod_field : range(0, 3) = unsigned(modrm[7..6]);
      match modrm_val {
        // 0F 01 D1: XSETBV — Write XCR (ECX selects register, EDX:EAX = value)
        // SDM: #GP(0) if CPL > 0; #GP(0) if ECX != 0 (only XCR0 exists);
        // #GP(0) if attempting to set unsupported bits or violating constraints.
        209 => {
          if cur_cpl != 0 then raise_GP0();
          let ecx_val : dword = reg(RCX);
          if ecx_val != 0x00000000 then raise_GP0();
          let new_xcr0 : qword = reg(32, RDX) @ reg(32, RAX);
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
          let ecx_val : dword = reg(RCX);
          if ecx_val == 0x00000000 | ecx_val == 0x00000001 then {
            // ECX=0: read XCR0; ECX=1: read XCR0 | IA32_XSS (IA32_XSS is 0)
            reg(RAX) = XCR0[31..0];
            reg(RDX) = XCR0[63..32]
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
          reg(RAX) = 0x00000000;
          reg(RDX) = 0x00000000
        },

        // 0F 01 EF: WRPKRU — Write Protection Key Rights (NOP, no PKU)
        239 => (),

        // 0F 01 F9: RDTSCP — Read TSC and IA32_TSC_AUX
        // SDM: #GP(0) if CR4.TSD (bit 2) = 1 and CPL > 0
        249 => {
          if CR4[2] == 0b1 & cur_cpl != 0 then raise_GP0();
          let tsc : qword = __rdtsc();
          reg(RAX) = tsc[31..0];
          reg(RDX) = tsc[63..32];
          let tsc_aux : qword = __rdmsr(0xC0000103);
          reg(RCX) = tsc_aux[31..0]
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
          let dest = decode_rm(modrm, pfx);
          match reg_field {
            // 0F 01 /0: SGDT m — Store GDTR (memory only)
            // Non-64-bit: 6 bytes (2 limit + 4 base).
            // 64-bit: 10 bytes (2 limit + 8 base). SDM Vol.2A LGDT/LIDT.
            0 => match dest {
              RM_mem(seg, offset) => {
                let total_size = if cur_mode == LongMode then 10 else 6;
                let addr = seg_linear(seg, offset, total_size);
                mem_write(addr, GDTR_limit);
                if cur_mode == LongMode then mem_write(addr + 2, GDTR_base)
                else mem_write(4, addr + 2, GDTR_base[31..0])
              },
              _ => raise_UD(),
            },

            // 0F 01 /1: SIDT m — Store IDTR (memory only)
            1 => match dest {
              RM_mem(seg, offset) => {
                let total_size = if cur_mode == LongMode then 10 else 6;
                let addr = seg_linear(seg, offset, total_size);
                mem_write(addr, IDTR_limit);
                if cur_mode == LongMode then mem_write(addr + 2, IDTR_base)
                else mem_write(4, addr + 2, IDTR_base[31..0])
              },
              _ => raise_UD(),
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
                RM_mem(seg, offset) => {
                  let gdt_os = if cur_mode == LongMode then 64
                               else get_operand_size(pfx);
                  let total_size : int = if gdt_os == 64 then 10 else 6;
                  let addr = seg_linear(seg, offset, total_size);
                  GDTR_limit = mem_read(addr);
                  match gdt_os {
                    16 => GDTR_base = zero_extend(mem_read(addr + 2) & 0x00FFFFFF),
                    32 => GDTR_base = zero_extend(mem_read(4, addr + 2)),
                    64 => GDTR_base = mem_read(addr + 2),
                  }
                },
                _ => raise_UD(),
              }
            },

            // 0F 01 /3: LIDT m — Load IDTR (memory only, requires CPL=0)
            // Same operand-size semantics as LGDT.
            3 => {
              if cur_cpl != 0 then raise_GP0();
              match dest {
                RM_mem(seg, offset) => {
                  let idt_os = if cur_mode == LongMode then 64
                               else get_operand_size(pfx);
                  let total_size : int = if idt_os == 64 then 10 else 6;
                  let addr = seg_linear(seg, offset, total_size);
                  IDTR_limit = mem_read(addr);
                  match idt_os {
                    16 => IDTR_base = zero_extend(mem_read(addr + 2) & 0x00FFFFFF),
                    32 => IDTR_base = zero_extend(mem_read(4, addr + 2)),
                    64 => IDTR_base = mem_read(addr + 2),
                  }
                },
                _ => raise_UD(),
              }
            },

            // 0F 01 /4: SMSW r/m16 — Store Machine Status Word
            // No privilege check required (accessible from any CPL).
            // SDM: stores low 16 bits of CR0 to r/m16. With 32-bit
            // register operand, stores low 32 bits; with 64-bit, all 64.
            4 => match dest {
              RM_reg(r, _) => {
                let os = get_operand_size(pfx);
                reg(r) = CR0[(os - 1) .. 0]
              },
              RM_mem(seg, offset) => seg_write(2, seg, offset, CR0[15..0]),
            },

            // 0F 01 /6: LMSW r/m16 — Load Machine Status Word (requires CPL=0)
            6 => {
              if cur_cpl != 0 then raise_GP0();
              let msw : word = rm(dest);
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
                RM_mem(_, _) => __tlb_flush(),
                _ => raise_UD(),
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
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let src = decode_rm(modrm, pfx);
      let selector : word = rm(src);
      if (selector & 0xFFFC) == zeros() then {
        ZF = 0b0
      } else {
        let sel_offset : qword = zero_extend(selector & 0xFFF8);
        let desc_addr : qword = GDTR_base + sel_offset;
        if unsigned(sel_offset) + 7 > unsigned(GDTR_limit) then {
          ZF = 0b0
        } else {
          let desc_hi : dword = mem_read(desc_addr + 4);
          if ~(lar_type_valid_64(desc_hi)) | ~(desc_privilege_ok(desc_hi, selector)) then {
            ZF = 0b0
          } else {
            let ar : qword = zero_extend(zero_extend(desc_hi[23..0]) & 0x00FFFF00 : dword);
            reg(reg) = ar[(os - 1) .. 0];
            ZF = 0b1
          }
        }
      }
    },

    // 0F 03: LSL r, r/m16 — Load Segment Limit
    // Reads descriptor from GDT, validates type and privilege, loads segment limit.
    3 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let src = decode_rm(modrm, pfx);
      let selector : word = rm(src);
      if (selector & 0xFFFC) == zeros() then {
        ZF = 0b0
      } else {
        let sel_offset : qword = zero_extend(selector & 0xFFF8);
        let desc_addr : qword = GDTR_base + sel_offset;
        if unsigned(sel_offset) + 7 > unsigned(GDTR_limit) then {
          ZF = 0b0
        } else {
          let desc_lo : dword = mem_read(desc_addr);
          let desc_hi : dword = mem_read(desc_addr + 4);
          if ~(lsl_type_valid_64(desc_hi)) | ~(desc_privilege_ok(desc_hi, selector)) then {
            ZF = 0b0
          } else {
            let limit_lo : word = desc_lo[15..0];
            let limit_hi : bits(4) = desc_hi[19..16];
            let granularity : bit = desc_hi[23];
            let limit : dword = zero_extend(limit_hi @ limit_lo);
            let final_limit : dword = if granularity == 0b1
              then (limit << 12) | 0x00000FFF
              else limit;
            let fl_ext : qword = zero_extend(final_limit);
            reg(reg) = fl_ext[(os - 1) .. 0];
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
        reg(RCX) = decode_pos;
        let saved_rflags = read_rflags();
        reg(R11) = saved_rflags;

        // Read MSRs
        let star  : qword = __rdmsr(0xC0000081);
        let lstar : qword = __rdmsr(0xC0000082);
        let fmask : qword = __rdmsr(0xC0000084);

        // Mask RFLAGS: clear bits in FMASK, also clear RF (bit 16)
        let new_rflags = saved_rflags & ~(fmask) & ~(0x0000000000010000);
        write_rflags(new_rflags);

        // CS = STAR[47:32] & 0xFFFC, SS = STAR[47:32] + 8
        let syscall_cs : word = star[47..32] & 0xFFFC;
        write_segreg(CS, syscall_cs);
        write_segreg(SS, syscall_cs + 0x0008);

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
      let new_rip : qword = reg(RCX);
      let new_rflags : qword = reg(R11);

      // SDM: RFLAGS := (R11 & 3C7FD7H) | 2
      // Clear RF (bit 16), VM (bit 17), reserved bits; force bit 1 = 1
      let restored = (new_rflags & 0x00000000003C7FD7) | 0x0000000000000002;
      write_rflags(restored);

      // Load CS and SS from IA32_STAR MSR.
      // SDM Vol.2: SYSRET with REX.W (64-bit):
      //   CS.Sel = STAR[63:48] + 16, SS.Sel = STAR[63:48] + 8
      // SYSRET without REX.W (32-bit compat):
      //   CS.Sel = STAR[63:48], SS.Sel = STAR[63:48] + 8
      let star : qword = __rdmsr(0xC0000081);
      let sysret_base : bits(16) = star[63..48];
      write_segreg(CS, if pfx.rex_w then sysret_base + 0x0010 else sysret_base);
      write_segreg(SS, sysret_base + 0x0008);  // + 8

      // Return to ring 3
      cur_cpl = 3;
      // REX.W -> 64-bit mode; without REX.W -> 32-bit compat mode
      if pfx.rex_w then {
        cur_mode = LongMode;
        SegCache[CS].seg_l = 0b1;
        SegCache[CS].seg_db = 0b0
      } else {
        cur_mode = CompatibilityMode;
        SegCache[CS].seg_l = 0b0;
        SegCache[CS].seg_db = 0b1
      };
      next_rip = Some(new_rip)
    },

    // 0F 09: WBINVD — Write Back and Invalidate Cache (NOP, requires CPL=0)
    // 0F 08: INVD — Invalidate Internal Caches (requires CPL=0)
    // SDM: Flush(InternalCaches); SignalFlush(ExternalCaches); Continue
    // Destructive: dirty cache lines discarded (not written back).
    8 => if cur_cpl != 0 then raise_GP0(),

    // 0F 09: WBINVD — Write Back and Invalidate Cache (requires CPL=0)
    9 => if cur_cpl != 0 then raise_GP0(),

    // 0F 0B: UD2
    11 => raise_UD(),

    // 0F 1F: Multi-byte NOP r/m (prefetch hint)
    31 => {
      let modrm = fetch_byte();
      let _ = decode_rm(modrm, pfx)  // consume ModR/M + SIB + disp
    },

    // 0F 20: MOV reg, CRn — Read control register (requires CPL=0)
    // REX.R extends reg field to access CR8
    32 => {
      if cur_cpl != 0 then raise_GP0();
      let modrm = fetch_byte();
      let rex_r_eff : bit = if pfx.has_rex then pfx.rex_r else 0b0;
      let cr_idx : range(0, 15) = unsigned(rex_r_eff @ modrm[5..3]);
      let rm_idx : gpr_idx = unsigned(pfx.rex_b @ modrm[2..0]);
      let cr_val : qword = match cr_idx {
        0 => CR0,
        2 => CR2,
        3 => CR3,
        4 => CR4,
        8 => zero_extend(CR8),
        _ => throw Fault(EXN_UD, 0x00000000),
      };
      reg(rm_idx) = cr_val
    },

    // 0F 22: MOV CRn, reg — Write control register (requires CPL=0)
    // REX.R extends reg field to access CR8
    34 => {
      if cur_cpl != 0 then raise_GP0();
      let modrm = fetch_byte();
      let rex_r_eff : bit = if pfx.has_rex then pfx.rex_r else 0b0;
      let cr_idx : range(0, 15) = unsigned(rex_r_eff @ modrm[5..3]);
      let rm_idx : gpr_idx = unsigned(pfx.rex_b @ modrm[2..0]);
      let cr_val : qword = reg(rm_idx);
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
          } else if cr_val[0] == 0b1 then
            cur_mode = ProtectedMode
          else
            cur_mode = RealMode
        },
        2 => CR2 = cr_val,
        3 => { CR3 = cr_val; __tlb_flush() },
        4 => {
          // SDM: #GP(0) if changing CR4.LA57 (bit 12) while paging is enabled
          if CR0[31] == 0b1 & cr_val[12] != CR4[12] then raise_GP0();
          CR4 = cr_val
        },
        8 => CR8 = cr_val[3..0],
        _ => throw Fault(EXN_UD, 0x00000000),
      }
    },

    // 0F 21: MOV reg, DRn — Read debug register (requires CPL=0)
    // SDM: CR4.DE=1 and DR4/DR5 → #UD; otherwise DR4/5 alias DR6/7.
    33 => {
      if cur_cpl != 0 then raise_GP0();
      let modrm = fetch_byte();
      let dr_idx : range(0, 7) = unsigned(modrm[5..3]);
      if (dr_idx == 4 | dr_idx == 5) & CR4[3] == 0b1 then raise_UD();
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
      reg(rm_idx) = dr_val
    },

    // 0F 23: MOV DRn, reg — Write debug register (requires CPL=0)
    // SDM: CR4.DE=1 and DR4/DR5 → #UD; otherwise DR4/5 alias DR6/7.
    35 => {
      if cur_cpl != 0 then raise_GP0();
      let modrm = fetch_byte();
      let dr_idx : range(0, 7) = unsigned(modrm[5..3]);
      if (dr_idx == 4 | dr_idx == 5) & CR4[3] == 0b1 then raise_UD();
      let rm_idx : gpr_idx = unsigned(pfx.rex_b @ modrm[2..0]);
      let dr_val : qword = reg(rm_idx);
      match dr_idx {
        0 => DR0 = dr_val,
        1 => DR1 = dr_val,
        2 => DR2 = dr_val,
        3 => DR3 = dr_val,
        4 => DR6 = dr_val,  // alias when CR4.DE=0
        5 => DR7 = dr_val,  // alias when CR4.DE=0
        6 => DR6 = dr_val,
        7 => DR7 = dr_val,
      }
    },

    // 0F 30: WRMSR — Write MSR (requires CPL=0)
    48 => {
      if cur_cpl != 0 then raise_GP0();
      let ecx : dword = reg(RCX);
      let msr_val : qword = reg(32, RDX) @ reg(32, RAX);

      // Handle EFER specially since it has a Sail register
      if ecx == 0xC0000080 then {
        EFER = msr_val
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
      } else {
        __wrmsr(ecx, msr_val)
      }
    },

    // 0F 18-1E: Prefetch hints / multi-byte NOPs
    // These all consume ModR/M and do nothing.
    op if 24 <= op & op <= 30 => {
      let modrm = fetch_byte();
      let _ = decode_rm(modrm, pfx)
    },

    // 0F 31: RDTSC
    // SDM: #GP(0) if CR4.TSD (bit 2) = 1 and CPL > 0
    49 => {
      if CR4[2] == 0b1 & cur_cpl != 0 then raise_GP0();
      let tsc : qword = __rdtsc();
      reg(RAX) = tsc[31..0];
      reg(RDX) = tsc[63..32]
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

    // 0F 34: SYSENTER — Fast System Call (legacy, used in compat mode)
    // SDM: loads CS/SS/EIP/ESP from MSRs IA32_SYSENTER_CS/ESP/EIP
    52 => {
      let sysenter_cs : qword = __rdmsr(0x00000174);
      if sysenter_cs[15..0] == zeros() then raise_GP0();
      write_segreg(CS, sysenter_cs[15..0] & 0xFFFC);
      cur_cpl = 0;
      write_segreg(SS, (sysenter_cs[15..0] + 0x0008) & 0xFFFC);
      let sysenter_esp : qword = __rdmsr(0x00000175);
      let sysenter_eip : qword = __rdmsr(0x00000176);
      reg(RSP) = sysenter_esp;
      IF_flag = 0b0;
      next_rip = Some(sysenter_eip)
    },

    // 0F 35: SYSEXIT — Fast Return from System Call (companion to SYSENTER)
    // SDM: requires CPL=0; loads CS/SS from IA32_SYSENTER_CS, RIP from RDX, RSP from RCX
    53 => {
      if cur_cpl != 0 then raise_GP0();
      let sysenter_cs : qword = __rdmsr(0x00000174);
      if sysenter_cs[15..0] == zeros() then raise_GP0();
      if pfx.rex_w then {
        // 64-bit: CS.sel = IA32_SYSENTER_CS + 32, SS.sel = IA32_SYSENTER_CS + 40
        write_segreg(CS, (sysenter_cs[15..0] + 0x0020) | 0x0003);
        write_segreg(SS, (sysenter_cs[15..0] + 0x0028) | 0x0003);
        cur_cpl = 3;
        next_rip = Some(reg(64, RDX));
        reg(RSP) = reg(64, RCX)
      } else {
        // 32-bit: CS.sel = IA32_SYSENTER_CS + 16, SS.sel = IA32_SYSENTER_CS + 24
        write_segreg(CS, (sysenter_cs[15..0] + 0x0010) | 0x0003);
        write_segreg(SS, (sysenter_cs[15..0] + 0x0018) | 0x0003);
        cur_cpl = 3;
        next_rip = Some(zero_extend(reg(32, RDX)));
        reg(64, RSP) = zero_extend(reg(32, RCX))
      }
    },

    // 0F 32: RDMSR — Read MSR (requires CPL=0)
    50 => {
      if cur_cpl != 0 then raise_GP0();
      let ecx : dword = reg(RCX);
      // Handle registers with Sail state specially
      let msr_val : qword = if ecx == 0xC0000080 then EFER
        else if ecx == 0xC0000100 then SegCache[FS].seg_base
        else if ecx == 0xC0000101 then SegCache[GS].seg_base
        else if ecx == 0xC0000102 then KERNEL_GS_BASE
        // IA32_XSS (0xDA0): always 0 (no supervisor state components supported)
        else if ecx == 0x00000DA0 then zeros()
        else __rdmsr(ecx);
      reg(RAX) = msr_val[31..0];
      reg(RDX) = msr_val[63..32]
    },

    // 0F 40-4F: CMOVcc r, r/m
    op if 64 <= op & op <= 79 => {
      let cc : cc_idx = op - 64;
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let src = decode_rm(modrm, pfx);
      let src_val = rm(os, src);
      let dst = reg(os, reg);
      if eval_cc(cc) == 0b1 then
        reg(reg) = src_val
      else
        reg(reg) = dst
    },

    // 0F 77: EMMS — set x87 tag word to all empty
    119 => x87_tw = 0xFFFF,

    // 0F 80-8F: Jcc rel16/rel32 (f64)
    op if 128 <= op & op <= 143 => {
      let cc : cc_idx = op - 128;
      let offset = fetch_rel_os(pfx);
      if eval_cc(cc) == 0b1 then {
        let os = get_operand_size_f64(pfx);
        next_rip = Some(truncate_rip(decode_pos + offset, os));
      }
    },

    // 0F 90-9F: SETcc r/m8
    op if 144 <= op & op <= 159 => {
      let cc : cc_idx = op - 144;
      let modrm = fetch_byte();
      let dest = decode_rm(modrm, pfx);
      let v : byte = zero_extend(eval_cc(cc));
      rm(dest) = v
    },

    // 0F AE: Group 15 — FXSAVE/FXRSTOR/LDMXCSR/STMXCSR/XSAVE/XRSTOR/
    //                    LFENCE/MFENCE/SFENCE/RDFSBASE/RDGSBASE/WRFSBASE/WRGSBASE
    174 => {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let dest = decode_rm(modrm, pfx);
      // F3 prefix with mod=11 and reg_field 0-3: FSGSBASE instructions
      // SDM: #UD if CR4.FSGSBASE (bit 16) = 0
      if pfx.has_rep & reg_field <= 3 then {
        if CR4[16] != 0b1 then raise_UD();
        match dest {
          RM_reg(r, _) => match (reg_field, pfx.rex_w) {
            // F3 0F AE /0 mod=11: RDFSBASE r32/r64
            (0, true)  => reg(r) = SegCache[FS].seg_base,
            (0, false) => reg(r) = SegCache[FS].seg_base[31..0],
            // F3 0F AE /1 mod=11: RDGSBASE r32/r64
            (1, true)  => reg(r) = SegCache[GS].seg_base,
            (1, false) => reg(r) = SegCache[GS].seg_base[31..0],
            // F3 0F AE /2 mod=11: WRFSBASE r32/r64
            (2, true)  => SegCache[FS].seg_base = reg(64, r),
            (2, false) => SegCache[FS].seg_base = zero_extend(reg(32, r)),
            // F3 0F AE /3 mod=11: WRGSBASE r32/r64
            (3, true)  => SegCache[GS].seg_base = reg(64, r),
            (3, false) => SegCache[GS].seg_base = zero_extend(reg(32, r)),
            _ => raise_UD(),
          },
          RM_mem(_, _) => raise_UD(),
        }
      } else match reg_field {
        // FXSAVE m512byte
        0 => match (dest, pfx.rex_w) {
          (RM_mem(seg, offset), true)  => __fxsave64(seg_linear(seg, offset, 512)),
          (RM_mem(seg, offset), false) => __fxsave(seg_linear(seg, offset, 512)),
          _ => raise_UD(),
        },

        // FXRSTOR m512byte
        1 => match (dest, pfx.rex_w) {
          (RM_mem(seg, offset), true)  => __fxrstor64(seg_linear(seg, offset, 512)),
          (RM_mem(seg, offset), false) => __fxrstor(seg_linear(seg, offset, 512)),
          _ => raise_UD(),
        },

        // LDMXCSR m32
        2 => __ldmxcsr(rm_mem(dest)),

        // STMXCSR m32
        3 => rm_mem(dest) = __stmxcsr(),

        // XSAVE m
        4 => match dest {
          RM_mem(seg, offset) => {
            let mask : qword = reg(32, RDX) @ reg(32, RAX);
            exec_xsave(seg_linear(seg, offset, 576), mask)
          },
          RM_reg(_, _) => raise_UD(),
        },

        5 => match dest {
          RM_mem(seg, offset) => {
            // /5 mem: XRSTOR m
            let mask : qword = reg(32, RDX) @ reg(32, RAX);
            exec_xrstor(seg_linear(seg, offset, 576), mask)
          },
          RM_reg(_, _) => {
            // /5 mod=11: LFENCE
            ()
          },
        },

        // /6: XSAVEOPT (NP, mem) / CLWB (66, mem) / MFENCE (reg)
        6 => match dest {
          RM_mem(seg, offset) => {
            if pfx.has_opsize then {
              ()  // CLWB: NOP (cache write-back, no architectural effect)
            } else {
              // XSAVEOPT: architecturally equivalent to XSAVE
              let mask : qword = reg(32, RDX) @ reg(32, RAX);
              exec_xsaveopt(seg_linear(seg, offset, 576), mask)
            }
          },
          RM_reg(_, _) => (),  // MFENCE
        },

        // /7: CLFLUSH (NP, mem) / CLFLUSHOPT (66, mem) / SFENCE (reg)
        7 => match dest {
          RM_mem(_, _) => (),  // CLFLUSH/CLFLUSHOPT: NOP (cache flush, no architectural effect)
          RM_reg(_, _) => (),  // SFENCE
        },
      }
    },

    // 0F A2: CPUID
    162 => {
      let leaf : dword = reg(RAX);
      let subleaf : dword = reg(RCX);
      let (out_eax, out_ebx, out_ecx, out_edx) = cpuid(leaf, subleaf);
      reg(RAX) = out_eax;
      reg(RBX) = out_ebx;
      reg(RCX) = out_ecx;
      reg(RDX) = out_edx
    },

    // 0F A0: PUSH FS (d64)
    // SDM: pushes FS selector. d64 = default 64 in long mode.
    // Non-64-bit mode: operand size from CS.D and 66h prefix.
    160 => {
      let os = get_operand_size_d64(pfx);
      match os {
        16 => push16(read_segreg(FS)),
        32 => push32(zero_extend(read_segreg(FS))),
        64 => push64(zero_extend(read_segreg(FS))),
      }
    },

    // 0F A1: POP FS (d64)
    161 => {
      let os = get_operand_size_d64(pfx);
      let v : word = match os {
        16 => pop16(),
        32 => pop32()[15..0],
        64 => pop64()[15..0],
      };
      load_segment_register(FS, v)
    },

    // 0F A3: BT r/m, r
    163 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let src = decode_rm(modrm, pfx);
      let bit_idx = reg(os, reg);
      let (adj_rm, bit_num) = bt_adjust(src, bit_idx);
      let v = rm(os, adj_rm);
      CF = v[bit_num]
    },

    // 0F A4: SHLD r/m, r, imm8
    164 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let dest = decode_rm(modrm, pfx);
      let count = fetch_byte();
      let dst_val = rm(os, dest);
      let src_val = reg(os, reg);
      let new_val = exec_shld(dst_val, src_val, count);
      rm(os, dest) = new_val
    },

    // 0F A5: SHLD r/m, r, CL
    165 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let dest = decode_rm(modrm, pfx);
      let count : byte = reg(RCX);
      let dst_val = rm(os, dest);
      let src_val = reg(os, reg);
      let new_val = exec_shld(dst_val, src_val, count);
      rm(os, dest) = new_val
    },

    // 0F A8: PUSH GS (d64)
    168 => {
      let os = get_operand_size_d64(pfx);
      match os {
        16 => push16(read_segreg(GS)),
        32 => push32(zero_extend(read_segreg(GS))),
        64 => push64(zero_extend(read_segreg(GS))),
      }
    },

    // 0F A9: POP GS (d64)
    169 => {
      let os = get_operand_size_d64(pfx);
      let v : word = match os {
        16 => pop16(),
        32 => pop32()[15..0],
        64 => pop64()[15..0],
      };
      load_segment_register(GS, v)
    },

    // 0F AA: RSM — Resume from System Management Mode
    // SDM Vol.2B §RSM: #UD if not in SMM. Restores processor state from
    // SMRAM and returns to the mode active before the SMI.
    170 => exec_rsm(),

    // 0F AB: BTS r/m, r
    171 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let dest = decode_rm(modrm, pfx);
      check_lock_rm(pfx, dest, false);
      let bit_idx = reg(os, reg);
      let (adj_rm, bit_num) = bt_adjust(dest, bit_idx);
      var v = rm(os, adj_rm);
      CF = v[bit_num];
      v[bit_num] = 0b1;
      rm(os, adj_rm) = v
    },

    // 0F AC: SHRD r/m, r, imm8
    172 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let dest = decode_rm(modrm, pfx);
      let count = fetch_byte();
      let dst_val = rm(os, dest);
      let src_val = reg(os, reg);
      let new_val = exec_shrd(dst_val, src_val, count);
      rm(os, dest) = new_val
    },

    // 0F AD: SHRD r/m, r, CL
    173 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let dest = decode_rm(modrm, pfx);
      let count : byte = reg(RCX);
      let dst_val = rm(os, dest);
      let src_val = reg(os, reg);
      let new_val = exec_shrd(dst_val, src_val, count);
      rm(os, dest) = new_val
    },

    // 0F AF: IMUL r, r/m (2-operand)
    175 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let src = decode_rm(modrm, pfx);
      let a = reg(os, reg);
      let b = rm(os, src);
      let product : int = signed(sign_extend(a) : qword) * signed(sign_extend(b) : qword);
      let result : qword = to_bits_truncate(product);
      CF = match os {
        16 => {
          let w : bits(32) = to_bits_truncate(product);
          is_nonzero(w[31..16] ^ sign_extend(w[15]))
        },
        32 => {
          let w : bits(64) = to_bits_truncate(product);
          is_nonzero(w[63..32] ^ sign_extend(w[31]))
        },
        64 => {
          let w : bits(128) = to_bits_truncate(product);
          is_nonzero(w[127..64] ^ sign_extend(w[63]))
        },
      };
      OF = CF;
      reg(reg) = result[(os - 1) .. 0]
    },

    // 0F B3: BTR r/m, r
    179 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let dest = decode_rm(modrm, pfx);
      check_lock_rm(pfx, dest, false);
      let bit_idx = reg(os, reg);
      let (adj_rm, bit_num) = bt_adjust(dest, bit_idx);
      var v = rm(os, adj_rm);
      CF = v[bit_num];
      v[bit_num] = 0b0;
      rm(os, adj_rm) = v
    },

    // 0F B2: LSS r, m16:16/32/64 — Load far pointer into SS
    // 0F B4: LFS r, m16:16/32/64 — Load far pointer into FS
    // 0F B5: LGS r, m16:16/32/64 — Load far pointer into GS
    // Memory format: [offset (16/32/64-bit)][selector (16-bit)]
    // Register operand only (memory source); #UD for register source.
    op if op == 178 | op == 180 | op == 181 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let src = decode_rm(modrm, pfx);
      match src {
        RM_mem(seg, ea) => {
          let far_offset = seg_read(os / 8, seg, ea);
          let selector : word = seg_read(seg, ea + to_bits_truncate(os / 8));
          reg(reg) = far_offset;
          let seg : segreg_idx = match op {
            178 => SS,
            180 => FS,
            _   => GS,
          };
          load_segment_register(seg, selector)
        },
        RM_reg(_, _) => raise_UD(),
      }
    },

    // 0F B0: CMPXCHG r/m8, r8
    176 => {
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let dest = decode_rm(modrm, pfx);
      check_lock_rm(pfx, dest, false);
      let dest_val = rm(8, dest);
      let acc : byte = reg(RAX);
      let src : byte = read_gpr8(reg, pfx.has_rex);
      let cmp_result = acc - dest_val;
      update_flags_sub(cmp_result, acc, dest_val);
      if ZF == 0b1 then {
        rm(dest) = src;
      } else {
        reg(RAX) = dest_val;
        rm(dest) = dest_val;
      }
    },

    // 0F B1: CMPXCHG r/m, r
    177 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let dest = decode_rm(modrm, pfx);
      check_lock_rm(pfx, dest, false);
      let dest_val = rm(os, dest);
      let acc = reg(os, RAX);
      let src = reg(os, reg);
      let cmp_result = acc - dest_val;
      update_flags_sub(cmp_result, acc, dest_val);
      if ZF == 0b1 then {
        rm(os, dest) = src;
      } else {
        reg(RAX) = dest_val;
        rm(os, dest) = dest_val;
      }
    },

    // 0F B6: MOVZX r, r/m8
    182 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let src = decode_rm(modrm, pfx);
      let v = rm(8, src);
      reg(os, reg) = zero_extend(v)
    },

    // 0F B7: MOVZX r, r/m16
    183 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let src = decode_rm(modrm, pfx);
      let v = rm(16, src);
      reg(os, reg) = zero_extend(v)
    },

    // 0F BA: Group 8 — BT/BTS/BTR/BTC r/m, imm8
    186 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let dest = decode_rm(modrm, pfx);
      // LOCK valid only for BTS (/5), BTR (/6), BTC (/7) with memory
      if pfx.has_lock & reg_field == 4 then raise_UD();
      check_lock_rm(pfx, dest, false);
      let imm = fetch_byte();
      var v = rm(os, dest);
      let bit_num : range(0, 63) = unsigned(imm) % os;
      assert(bit_num < os);
      CF = v[bit_num];
      match reg_field {
        // BT — just test, no modification
        4 => (),
        // BTS — set bit
        5 => {
          v[bit_num] = 0b1;
          rm(os, dest) = v
        },
        // BTR — reset bit
        6 => {
          v[bit_num] = 0b0;
          rm(os, dest) = v
        },
        // BTC — complement bit
        7 => {
          v[bit_num] = ~(v[bit_num]);
          rm(os, dest) = v
        },
        _ => raise_UD(),
      }
    },

    // 0F BB: BTC r/m, r
    187 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let dest = decode_rm(modrm, pfx);
      check_lock_rm(pfx, dest, false);
      let bit_idx = reg(os, reg);
      let (adj_rm, bit_num) = bt_adjust(dest, bit_idx);
      var v = rm(os, adj_rm);
      CF = v[bit_num];
      v[bit_num] = ~(v[bit_num]);
      rm(os, adj_rm) = v
    },

    // 0F BC: BSF r, r/m (or TZCNT with F3 prefix)
    188 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let src = decode_rm(modrm, pfx);
      if pfx.has_rep then {
        // TZCNT r16/r32/r64, r/m16/r/m32/r/m64
        if ~(has_bmi1) then raise_UD();
        let src_val = rm(os, src);
        let count : range(0, 64) = ctz(os, zero_extend(src_val));
        let result : qword = to_bits_truncate(count);
        reg(reg) = result[(os - 1) .. 0];
        CF = is_zero(src_val);
        ZF = src_val[0]
      } else {
        // BSF r16/r32/r64, r/m16/r/m32/r/m64
        // SDM: CF, OF, SF, AF cleared. ZF set if source is zero.
        // PF set from result parity (verified against real hardware).
        // SDM footnote: "On some older processors, CF, OF, SF, AF, and
        // PF flags are unmodified." We follow the main text.
        let src_val = rm(os, src);
        CF = 0b0;
        OF = 0b0;
        SF = 0b0;
        AF = 0b0;
        if src_val == zeros() then {
          ZF = 0b1;
          PF = compute_PF(0x00);
        } else {
          ZF = 0b0;
          let idx : range(0, 64) = ctz(os, zero_extend(src_val));
          let result : qword = to_bits_truncate(idx);
          PF = compute_PF(result[7..0]);
          reg(reg) = result[(os - 1) .. 0];
        }
      }
    },

    // 0F BD: BSR r, r/m (or LZCNT with F3 prefix)
    189 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let src = decode_rm(modrm, pfx);
      if pfx.has_rep then {
        // LZCNT r16/r32/r64, r/m16/r/m32/r/m64
        if ~(has_lzcnt) then raise_UD();
        let src_val = rm(os, src);
        let count : range(0, 64) = clz(os, zero_extend(src_val));
        let result : qword = to_bits_truncate(count);
        reg(reg) = result[(os - 1) .. 0];
        CF = is_zero(src_val);
        ZF = src_val[os - 1]
      } else {
        // BSR r16/r32/r64, r/m16/r/m32/r/m64
        // SDM: CF, OF, SF, AF cleared. ZF set if source is zero.
        // PF set from result parity (verified against real hardware).
        // SDM footnote: "On some older processors, CF, OF, SF, AF, and
        // PF flags are unmodified." We follow the main text.
        let src_val = rm(os, src);
        CF = 0b0;
        OF = 0b0;
        SF = 0b0;
        AF = 0b0;
        if src_val == zeros() then {
          ZF = 0b1;
          PF = compute_PF(0x00);
        } else {
          ZF = 0b0;
          let idx : range(0, 63) = bsr(zero_extend(src_val));
          let result : qword = to_bits_truncate(idx);
          PF = compute_PF(result[7..0]);
          reg(reg) = result[(os - 1) .. 0];
        }
      }
    },

    // 0F BE: MOVSX r, r/m8
    190 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let src = decode_rm(modrm, pfx);
      let v = rm(8, src);
      let sx : qword = sign_extend(v);
      reg(reg) = sx[(os - 1) .. 0]
    },

    // 0F BF: MOVSX r, r/m16
    191 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let src = decode_rm(modrm, pfx);
      let v = rm(16, src);
      let sx : qword = sign_extend(v);
      reg(reg) = sx[(os - 1) .. 0]
    },

    // 0F C0: XADD r/m8, r8
    192 => {
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let dest = decode_rm(modrm, pfx);
      check_lock_rm(pfx, dest, false);
      match dest {
        RM_reg(dst, _) => exec_xadd(dst, reg, 8),
        RM_mem(seg, offset) => {
          // Memory operand: read, exchange, add, write back
          let mem_val : qword = zero_extend(seg_read(1,seg, offset));
          let reg_val : qword = zero_extend(read_gpr8(reg, pfx.has_rex));
          let sum : qword = mem_val + reg_val;
          update_flags_add(sum[7..0], mem_val[7..0], reg_val[7..0]);
          write_gpr8(reg, pfx.has_rex, mem_val[7..0]);
          seg_write(1, seg, offset, sum[7..0])
        },
      }
    },

    // 0F C1: XADD r/m, r
    193 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let dest = decode_rm(modrm, pfx);
      check_lock_rm(pfx, dest, false);
      match dest {
        RM_reg(dst, _) => exec_xadd(dst, reg, os),
        RM_mem(_, _) => {
          let mem_val = rm(os, dest);
          let reg_val = reg(os, reg);
          let sum = mem_val + reg_val;
          update_flags_add(sum, mem_val, reg_val);
          reg(reg) = mem_val;
          rm(os, dest) = sum
        },
      }
    },

    // 0F B8: POPCNT r, r/m (F3 prefix)
    184 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_F3 then raise_UD();
      if ~(has_popcnt) then raise_UD();
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let src = decode_rm(modrm, pfx);
      let src_val = rm(os, src);
      let count : range(0, 64) = popcount(zero_extend(src_val) : qword);
      OF = 0b0;
      SF = 0b0;
      AF = 0b0;
      CF = 0b0;
      PF = 0b0;
      ZF = is_zero(src_val);
      let result : qword = to_bits_truncate(count);
      reg(reg) = result[(os - 1) .. 0]
    },

    // 0F C3: MOVNTI m32/64, r
    195 => {
      let os = get_operand_size(pfx);
      let modrm = fetch_byte();
      let reg = modrm_reg(modrm, pfx);
      let dest = decode_rm(modrm, pfx);
      let v = reg(os, reg);
      rm_mem(dest) = v
    },

    // 0F C7 /1: CMPXCHG8B/CMPXCHG16B m64/m128
    199 => {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let dest = decode_rm(modrm, pfx);
      match reg_field {
        // CMPXCHG8B/CMPXCHG16B m64/m128
        1 => match dest {
          RM_mem(seg, offset) => {
            if pfx.rex_w then {
              if ~(has_cx16) then raise_UD();
              let mem_lo : qword = seg_read(seg, offset);
              let mem_hi : qword = seg_read(seg, offset + 8);
              if reg(64, RAX) == mem_lo & reg(64, RDX) == mem_hi then {
                ZF = 0b1;
                seg_write(seg, offset, reg(64, RBX));
                seg_write(seg, offset + 8, reg(64, RCX));
              } else {
                ZF = 0b0;
                reg(RAX) = mem_lo;
                reg(RDX) = mem_hi;
              }
            } else {
              let mem_lo : dword = seg_read(seg, offset);
              let mem_hi : dword = seg_read(seg, offset + 4);
              if reg(32, RAX) == mem_lo & reg(32, RDX) == mem_hi then {
                ZF = 0b1;
                seg_write(seg, offset, reg(32, RBX));
                seg_write(seg, offset + 4, reg(32, RCX));
              } else {
                ZF = 0b0;
                reg(RAX) = mem_lo;
                reg(RDX) = mem_hi;
              }
            }
          },
          RM_reg(_, _) => raise_UD(),
        },
        // /4 mem: XSAVEC — save extended state with compaction
        // /3 mem: XRSTORS — restore extended state (supervisor, requires CPL=0)
        3 => match dest {
          RM_mem(seg, offset) => {
            if cur_cpl != 0 then raise_GP0();
            let mask : qword = reg(32, RDX) @ reg(32, RAX);
            exec_xrstors(seg_linear(seg, offset, 576), mask)
          },
          _ => raise_UD(),
        },
        // /4 mem: XSAVEC — save extended state with compaction
        4 => match dest {
          RM_mem(seg, offset) => {
            let mask : qword = reg(32, RDX) @ reg(32, RAX);
            exec_xsavec(seg_linear(seg, offset, 576), mask)
          },
          _ => raise_UD(),
        },
        // /5 mem: XSAVES — save extended state (supervisor, requires CPL=0)
        5 => match dest {
          RM_mem(seg, offset) => {
            if cur_cpl != 0 then raise_GP0();
            let mask : qword = reg(32, RDX) @ reg(32, RAX);
            exec_xsaves(seg_linear(seg, offset, 576), mask)
          },
          _ => raise_UD(),
        },
        // /6 mod=11: RDRAND r16/r32/r64
        6 => match dest {
          RM_reg(r, _) => {
            if ~(has_rdrand) then raise_UD();
            let os = get_operand_size(pfx);
            let (rnd, cf_val) = __rdrand64();
            if cf_val == 0b1 then
              reg(r) = rnd[(os - 1) .. 0]
            else
              reg(os, r) = zeros();
            CF = cf_val;
            OF = 0b0;
            SF = 0b0;
            ZF = 0b0;
            AF = 0b0;
            PF = 0b0
          },
          RM_mem(_, _) => raise_UD(),
        },
        // /7 mod=11: RDSEED r16/r32/r64
        7 => match dest {
          RM_reg(r, _) => {
            if ~(has_rdseed) then raise_UD();
            let os = get_operand_size(pfx);
            let (rnd, cf_val) = __rdseed64();
            if cf_val == 0b1 then
              reg(r) = rnd[(os - 1) .. 0]
            else
              reg(os, r) = zeros();
            CF = cf_val;
            OF = 0b0;
            SF = 0b0;
            ZF = 0b0;
            AF = 0b0;
            PF = 0b0
          },
          RM_mem(_, _) => raise_UD(),
        },
        _ => raise_UD(),
      }
    },

    // 0F C8-CF: BSWAP r32/r64 (register in opcode)
    op if 200 <= op & op <= 207 => {
      let reg_field : range(0, 7) = op - 200;
      let reg = extend_reg(reg_field, pfx.rex_b);
      let os = get_operand_size(pfx);
      if os == 16 then {
        // SDM says "result is undefined" for 16-bit operand, but real
        // hardware zeroes the low 16 bits.
        reg(reg) = zeros() : word
      } else {
        reg(os, reg) = bswap(reg(os, reg))
      }
    },

    _ => raise_UD(),
  }
}
