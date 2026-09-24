// x86-64 — Memory Interface
//
// Two-layer memory model following the sail-riscv pattern:
//   read_mem/write_mem (virtual) → translate_addr → phys_read/phys_write
//
// When paging is disabled (CR0.PG=0, user-mode emulation), translate_addr
// returns the address unchanged, so all existing instruction code works
// without modification.
//
// Physical memory primitives (__read_mem, __write_mem, phys_read, phys_write)
// and the address translation function (translate_addr) are defined in
// paging.sail, which is compiled before this file.

// Forward declarations so that the read_mem/write_mem overloads are
// available to all functions in this file (including stack operations).
// Size parameter 'n is in bits.
val read_mem_linear : forall 'n, 'n > 0. (implicit('n), qword, PTAccess) -> bits('n)
val read_mem_data : forall 'n, 'n > 0. (implicit('n), qword) -> bits('n)
val read_mem_implicit : forall 'n, 'n > 0. (implicit('n), qword) -> bits('n)
val write_mem_linear : forall 'n, 'n > 0. (implicit('n), qword, bits('n)) -> unit
val read_mem_ref : forall 'n, 'n > 0. (implicit('n), MemRef) -> bits('n)
val write_mem_ref : forall 'n, 'n > 0. (implicit('n), MemRef, bits('n)) -> unit

overload read_mem = {read_mem_data, read_mem_ref}
overload write_mem = {write_mem_linear, write_mem_ref}

// Data breakpoints (SDM Vol.3B §20.2.5, §20.3.1.2): an access hits DRn
// when the breakpoint is enabled by Ln or Gn, R/Wn is 01 (writes) or 11
// (reads and writes), and any byte of the access lies in the LENn-byte
// range at DRn, whose low address bits LENn masks (1, 2, 8 and 4 bytes for
// 00, 01, 10 and 11).  Instruction fetches and the processor's own
// descriptor-table reads do not count.  Hits accumulate in pending_dbp for
// the trap that step() raises after the instruction.
val note_data_access : (qword, int, bool) -> unit
function note_data_access(lin, nbytes, is_write) = {
  foreach (n from 0 to 3) {
    let enabled : bool = DR7[2 * n] == bitone | DR7[2 * n + 1] == bitone;
    let rw : bits(2) = DR7[(17 + 4 * n) .. (16 + 4 * n)];
    let len : range(1, 8) = match DR7[(19 + 4 * n) .. (18 + 4 * n)] {
      0b00 => 1, 0b01 => 2, 0b10 => 8, _ => 4
    };
    let dr : qword = match n { 0 => DR0, 1 => DR1, 2 => DR2, _ => DR3 };
    let base : int = unsigned(dr & ~(to_bits(64, len - 1)));
    let applies : bool = (rw == 0b01 & is_write) | rw == 0b11;
    if enabled & applies & unsigned(lin) < base + len & base < unsigned(lin) + nbytes then
      pending_dbp[n] = bitone
  }
}

// I/O breakpoints (SDM Vol.3B §20.2.4, §20.2.5): with CR4.DE set, R/Wn = 10
// makes DRn an I/O breakpoint; the port address is zero-extended and
// compared with the LENn-byte range at DRn like a data breakpoint.  Hits
// join pending_dbp.  Without CR4.DE the encoding is undefined and ignored.
val note_io_access : (word, int) -> unit
function note_io_access(port, nbytes) = {
  if CR4[3] == bitone then {
    foreach (n from 0 to 3) {
      let enabled : bool = DR7[2 * n] == bitone | DR7[2 * n + 1] == bitone;
      let rw : bits(2) = DR7[(17 + 4 * n) .. (16 + 4 * n)];
      let len : range(1, 8) = match DR7[(19 + 4 * n) .. (18 + 4 * n)] {
        0b00 => 1, 0b01 => 2, 0b10 => 8, _ => 4
      };
      let dr : qword = match n { 0 => DR0, 1 => DR1, 2 => DR2, _ => DR3 };
      let base : int = unsigned(dr & ~(to_bits(64, len - 1)));
      let p : int = unsigned(port);
      if enabled & rw == 0b10 & p < base + len & base < p + nbytes then
        pending_dbp[n] = bitone
    }
  }
}

// Validate every page before a crossing access enters the external byte-copy
// helper. Keep faulting translations in Sail: an external callback into
// translate_addr cannot propagate a Sail exception through every backend's
// foreign-call ABI. In particular, an instruction fetch must not consume
// bytes from a failed translation. SDM Vol.3A §§7.5–7.6 and Interrupt 14:
// #PF preserves the faulting instruction for restart; CR2 identifies its
// failing linear address. Checking all pages also avoids partial MOV stores.
val check_crossing_pages : (qword, int, PTAccess) -> unit
function check_crossing_pages(addr, nbytes, access) = {
  let _ = translate_addr(addr, access);
  var offset : int = 4096 - unsigned(addr[11..0]);
  while offset < nbytes do {
    let _ = translate_addr(addr + to_bits(64, offset), access);
    offset = offset + 4096
  }
}

// Read 'n bits from memory at the given virtual address.
// Goes through address translation when paging is enabled.
// If the access crosses a 4KB page boundary, each byte is translated
// separately to handle non-contiguous physical pages.
function read_mem_linear(n, addr, access) = {
  if access == PT_Read then note_data_access(addr, n / 8, false);
  let page_offset = unsigned(addr & 0x0000000000000FFF);
  if page_offset + n / 8 <= 4096 then {
    let paddr = translate_addr(addr, access);
    phys_read(n, paddr)
  } else {
    check_crossing_pages(addr, n / 8, access);
    __mem_read_crossing(addr, n, access)
  }
}

// Data-read wrapper: read_mem_linear with PT_Read access.
function read_mem_data(n, addr) = read_mem_linear(addr, PT_Read)

// Implicit-read wrapper for descriptor-table accesses (GDT/LDT/IDT/TSS).
// SDM Vol.3A §4.6: these reads the CPU itself performs always execute
// at supervisor regardless of the current CPL and bypass the U/S page
// check, so user-mode instructions (e.g. `MOV GS, sel` at CPL=3) can
// load a descriptor out of a kernel-mapped GDT without a #PF.
function read_mem_implicit(n, addr) = read_mem_linear(addr, PT_Implicit)

// Write 'n bits to memory at the given virtual address.
// Same page-crossing logic as mem_read.
function write_mem_linear(n, addr, data) = {
  note_data_access(addr, n / 8, true);
  let page_offset = unsigned(addr & 0x0000000000000FFF);
  if page_offset + n / 8 <= 4096 then {
    let paddr = translate_addr(addr, PT_Write);
    phys_write(n, paddr, data)
  } else {
    check_crossing_pages(addr, n / 8, PT_Write);
    __mem_write_crossing(addr, n, data)
  }
}

// Stack operations.
// In long mode, uses RSP directly (SS base is 0).
// In non-long mode, linear address = SS base + ESP/SP (SDM Vol.3A §3.4).
// Stack pointer width depends on SS.B: if SS.B=1 then ESP (32-bit),
// if SS.B=0 then SP (16-bit). In long mode, always RSP (64-bit).

// Stack address size: 64 in long mode, 32 if SS.B=1, 16 if SS.B=0.
val stack_addr_size : unit -> {16, 32, 64}
function stack_addr_size() =
  if cur_mode == LongMode then 64
  else if SegCache[SS].seg_db == 0b1 then 32
  else 16

// Stack push helper: decrement SP by the value's byte width, write
// the value at the new SP, then commit the SP update — all as a
// single logical operation.  Because SP is written only after the
// store succeeds, a fault during write_mem leaves SP unchanged.
//
// In non-64-bit modes with SS.B=0, SP is 16-bit and wraps at 0xFFFF.
// Without wrapping, SP=2 minus 4 would produce linear address SS.base-2,
// which is below the segment — wrong.  It should wrap to SS.base+0xFFFE.
val push : forall 'n, 8 <= 'n & 'n <= 512. (implicit('n), bits('n)) -> unit
val check_seg_limit : (segreg_idx, qword, int) -> unit
function push(n, v) = {
  let sas = stack_addr_size();
  let new_sp = v(sas, RSP) - n / 8;
  if cur_mode == Virtual8086Mode then check_seg_limit(SS, zero_extend(new_sp), n / 8);
  write_mem(get_seg_base(SS) + zero_extend(new_sp), v);
  v(RSP) = new_sp
}

// Stack pop helper: read 'n bits from SP, then advance SP — again
// as a single logical operation.
val pop : forall 'n, 8 <= 'n & 'n <= 512. (implicit('n)) -> bits('n)
function pop(n) = {
  let sas = stack_addr_size();
  let sp = v(sas, RSP);
  if cur_mode == Virtual8086Mode then check_seg_limit(SS, zero_extend(sp), n / 8);
  let x : bits('n) = read_mem(get_seg_base(SS) + zero_extend(sp));
  v(RSP) = sp + n / 8;
  x
}

// =========================================================================
// Segment register loading
// =========================================================================

// Load a segment register with a selector, updating both the visible
// selector and the hidden descriptor cache (SDM Vol.3A §3.4.5).
// In real mode: base = selector << 4; limit and attributes are NOT changed.
//   This preserves "unreal mode" / "big real mode" behavior where a segment
//   retains its large limit from a prior protected-mode descriptor load.
//   (SDM Vol.3A §3.4.5: "Every segment register has a 'visible' part and
//    a 'hidden' part... in real-address mode, only the base is updated.")
// In protected/compat mode: read 8-byte descriptor from GDT/LDT.
// In long mode: just store the selector (FS/GS base set via MSR).
// Virtual-8086 segment loads ignore descriptor tables, including selectors
// whose low bits look like an RPL or TI. All six caches describe writable
// 64-KByte segments at selector * 16 with DPL 3 (SDM Vol.3B §23.2).
val load_vm86_segment : (segreg_idx, word) -> unit
function load_vm86_segment(idx, selector) = {
  write_segreg(idx, selector);
  SegCache[idx] = {default_seg_desc_cache() with
    seg_base = zero_extend(selector) << 4, seg_dpl = 3}
}

val load_segment_register : (segreg_idx, word) -> unit
function load_segment_register(idx, selector) = {
  // Do memory reads (GDT lookup) before writing the segment register,
  // so that a fault during the GDT read leaves the segment unchanged.
  match cur_mode {
    Virtual8086Mode => load_vm86_segment(idx, selector),
    RealMode => {
      write_segreg(idx, selector);
      SegCache[idx].seg_base = zero_extend(selector) << 4
    },
    _ => {
      // SDM §3.4.4: In all modes (including 64-bit), segment loads read the
      // GDT/LDT and populate the hidden descriptor cache. For DS/ES/SS in
      // 64-bit mode, the cached values are ignored during address calculation
      // (handled by get_seg_base). For FS/GS, the 32-bit base is loaded
      // (upper bits cleared); WRMSR can then set the full 64-bit base.
      let ti : bit = selector[2];
      let index : bits(13) = selector[15..3];
      let table_base : qword = if ti == 0b1 then {
        // LDT: TODO — for now treat as GDT
        GDTR_base
      } else {
        GDTR_base
      };
      let desc_offset : qword = zero_extend(index @ 0b000);
      // Implicit supervisor access: the CPU's own GDT/LDT reads bypass
      // U/S so a CPL=3 `MOV GS, sel` can load a descriptor out of a
      // kernel-mapped GDT.
      let desc_lo : dword = read_mem_implicit(table_base + desc_offset);
      let desc_hi : dword = read_mem_implicit(table_base + desc_offset + 4);
      write_segreg(idx, selector);
      SegCache[idx] = parse_seg_descriptor(desc_lo, desc_hi)
    },
  }
}

// Error code of a fault attributed to a segment selector (SDM Vol.3A §7.13,
// Figure 7-7): the selector's index and TI bit; bits 1:0 are the IDT and
// EXT flags, both clear for a selector referenced by an instruction.
val selector_error_code : word -> dword
function selector_error_code(selector) = zero_extend(selector & 0xFFFC)

// =========================================================================
// Segment limit checking (SDM Vol.3A §6.3)
// =========================================================================

// Check that an access at the given offset with the given size is within
// the segment limit. Raises #GP(0) for non-SS segments, #SS(0) for SS.
// Only checks in non-long mode; 64-bit mode disables limit checking for
// CS/DS/ES/SS (SDM Vol.3A §6.3.1).
// For expand-up segments: offset + size - 1 <= effective_limit.
function check_seg_limit(seg, offset, access_size) = {
  if cur_mode != LongMode then {
    let limit : dword = SegCache[seg].seg_limit;
    // Expand-up check: offset + size - 1 must not exceed limit
    if unsigned(offset) + access_size - 1 > unsigned(limit) then {
      if seg == SS then throw Fault(EXN_SS, 0x00000000)
      else throw Fault(EXN_GP, 0x00000000)
    }
  }
}

// =========================================================================
// Segment-aware memory access (SDM Vol.3A §3.4)
//
// Translates a logical address (segment, offset) to a linear address:
//   1. Check offset against segment limit (§6.3)
//   2. Linear address = segment base + offset
// Then passes the linear address through paging (translate_addr).
// =========================================================================

// Translate a logical (segment, offset) pair to a linear address,
// performing segment limit checking with the given access size.
// Also applies the RIP-relative fixup if pending.
//
// Linear address width (SDM Vol.1 §3.3.3):
//   Long mode:        64-bit canonical linear addresses.
//   Compatibility:    32-bit linear address space — (seg_base + offset)
//                     is computed mod 2^32.  This matters for FS/GS
//                     accesses with negative 32-bit displacements:
//                     glibc's 32-bit TLS code reads %gs:-44 expecting
//                     the 32-bit wrap (GS.base + 0xFFFFFFD4 =
//                     GS.base-44 mod 2^32).  Without the truncation the
//                     64-bit sum overflows past 4GB into unmapped
//                     territory and every TLS load #PFs.
//   Real/protected:   32-bit linear — same truncation.
val seg_linear : (MemRef, int) -> qword
function seg_linear(m, access_size) = {
  // Apply RIP-relative fixup if pending (only in LongMode, where
  // mod=00 rm=101 means [RIP+disp32])
  let offset = if rip_rel_pending then decode_pos + rip_rel_disp else m.addr;
  check_seg_limit(m.seg, offset, access_size);
  let linear : qword = offset + get_seg_base(m.seg);
  if cur_mode == LongMode then {
    // A data access through a non-canonical linear address is #GP(0),
    // or #SS(0) when the SS segment is used (SDM Vol.1 §3.3.7.1; the
    // "64-Bit Mode Exceptions" of every memory instruction).  Canonical:
    // bits 63:47 all equal, or 63:56 with 5-level paging (CR4.LA57).
    let high : bits(17) = if CR4[12] == 0b1 then sign_extend(linear[63..56]) else linear[63..47];
    if high != zeros() & high != ones() then {
      if m.seg == SS then raise_SS0() else raise_GP0()
    };
    linear
  } else {
    zero_extend(linear[31..0])
  }
}

// Segmented memory read/write via MemRef (n is in bits; seg_linear takes bytes).
function read_mem_ref(n, m) = read_mem_linear(seg_linear(m, n / 8), PT_Read)
function write_mem_ref(n, m, v) = write_mem_linear(seg_linear(m, n / 8), v)

// Read a far pointer (selector:offset) from memory.
// Memory layout: [offset (os bits)][selector (16 bits)].
// Returns (zero-extended offset, selector).
val read_far_pointer : forall 'os, 'os in {16, 32, 64}. (int('os), MemRef) -> (qword, word)
function read_far_pointer(os, m) = {
  let d : bits('os + 16) = read_mem(m);
  (zero_extend(d['os - 1 .. 0]), d['os + 15 .. 'os])
}

// Pop a far pointer (selector:offset) from the stack.
// Each element occupies a full operand-size slot, so the frame is 2*os bits.
// This differs from read_far_pointer (compact os+16 layout for memory
// operands) because CALL FAR pushes each element as a separate os-wide
// push, and RETF pops them the same way.
val pop_far_pointer : forall 'os, 'os in {16, 32, 64}. int('os) -> (qword, word)
function pop_far_pointer(os) = {
  let offset = pop(os);
  let selector = pop(os);
  (zero_extend(offset), selector[15..0])
}

// =========================================================================
// Protected-mode far transfer helpers (SDM Vol.2A JMP/CALL — Protected Mode)
// =========================================================================

// Read a segment descriptor from the GDT (or LDT — TODO: LDT support).
// Returns the parsed descriptor cache entry.
// Raises #GP(selector) if the selector index is beyond the table limit.
val read_descriptor : word -> SegDescCache
function read_descriptor(selector) = {
  let ti : bit = selector[2];
  let index : bits(13) = selector[15..3];
  let table_base : qword = if ti == 0b1 then GDTR_base  // TODO: LDT base
                            else GDTR_base;
  let table_limit : word = GDTR_limit;
  let desc_offset : qword = zero_extend(index @ 0b000);
  // Descriptor must fit within the table limit (offset + 7 <= limit)
  if unsigned(desc_offset) + 7 > unsigned(table_limit) then {
    throw Fault(EXN_GP, selector_error_code(selector))
  };
  // Implicit supervisor access (SDM Vol.3A §4.6): descriptor-table reads
  // bypass U/S regardless of CPL.
  let desc_lo : dword = read_mem_implicit(table_base + desc_offset);
  let desc_hi : dword = read_mem_implicit(table_base + desc_offset + 4);
  parse_seg_descriptor(desc_lo, desc_hi)
}

// Load SS, DS, ES, FS or GS on behalf of MOV Sreg, POP Sreg and the LxS
// instructions, with the checks of the SDM's Operation sections (Vol.2B
// MOV, "Loading a segment register while in protected mode results in
// special checks and actions"; Vol.2B POP; Vol.2A LDS/LES/LFS/LGS/LSS):
//   SS: null selector -> #GP(0); index beyond the table limit, RPL != CPL,
//       not a writable data segment, or DPL != CPL -> #GP(selector);
//       not present -> #SS(selector).  In 64-bit mode a null SS is
//       permitted when CPL < 3 and RPL = CPL (MOV, 64-Bit Mode Exceptions).
//   DS/ES/FS/GS with a non-null selector: index beyond the table limit,
//       neither a data nor a readable code segment, or a data or
//       nonconforming code segment with RPL > DPL or CPL > DPL
//       -> #GP(selector); not present -> #NP(selector).
//   DS/ES/FS/GS with a null selector: loaded without checks.
// Real mode loads the base from the selector.  CS is never loaded here:
// far transfers have their own checks.
val load_data_segment_register : (segreg_idx, word) -> unit
function load_data_segment_register(idx, selector) = {
  if cur_mode == RealMode | cur_mode == Virtual8086Mode then load_segment_register(idx, selector)
  else {
    let rpl : range(0, 3) = unsigned(selector[1..0]);
    let null_selector : bool = selector[15..2] == zeros();
    if idx == SS then {
      if null_selector then {
        if cur_mode == LongMode & cur_cpl < 3 & rpl == cur_cpl then
          load_segment_register(idx, selector)
        else
          raise_GP0()
      } else {
        let desc = read_descriptor(selector);
        let writable_data : bool = desc.seg_s == 0b1 & desc.seg_type[3] == 0b0
                                 & desc.seg_type[1] == 0b1;
        if rpl != cur_cpl | ~(writable_data) | desc.seg_dpl != cur_cpl then {
          throw Fault(EXN_GP, selector_error_code(selector))
        };
        if desc.seg_present == 0b0 then {
          throw Fault(EXN_SS, selector_error_code(selector))
        };
        load_segment_register(idx, selector)
      }
    } else if null_selector then {
      load_segment_register(idx, selector)
    } else {
      let desc = read_descriptor(selector);
      let data : bool = desc.seg_type[3] == 0b0;
      let readable_code : bool = desc.seg_type[3] == 0b1 & desc.seg_type[1] == 0b1;
      let conforming_code : bool = desc.seg_type[3] == 0b1 & desc.seg_type[2] == 0b1;
      if desc.seg_s == 0b0 | ~(data | readable_code) then {
        throw Fault(EXN_GP, selector_error_code(selector))
      };
      if ~(conforming_code) & (rpl > desc.seg_dpl | cur_cpl > desc.seg_dpl) then {
        throw Fault(EXN_GP, selector_error_code(selector))
      };
      if desc.seg_present == 0b0 then {
        throw Fault(EXN_NP, selector_error_code(selector))
      };
      load_segment_register(idx, selector)
    }
  }
}

// Validate and load CS for a far JMP in protected mode (same-privilege,
// code segment only — no call gates or task switches).
// SDM Vol.2A JMP — Protected Mode, non-64-bit:
//   1. Selector must not be null (#GP(0))
//   2. Selector index must be within GDT/LDT limits (#GP(selector))
//   3. Descriptor must be a code segment (S=1, type bit 3 set) (#GP(selector))
//   4. Non-conforming: DPL = CPL and RPL <= CPL (#GP(selector))
//      Conforming: DPL <= CPL (#GP(selector))
//   5. Segment must be present (#NP(selector))
//   6. Load CS, set RPL = CPL
val validate_far_jmp_cs : word -> SegDescCache
function validate_far_jmp_cs(selector) = {
  // Null selector check
  if selector[15..2] == zeros() then {
    throw Fault(EXN_GP, 0x00000000)
  };

  let desc = read_descriptor(selector);

  // Must be a code/data segment (S=1), not a system descriptor
  if desc.seg_s == 0b0 then {
    throw Fault(EXN_GP, selector_error_code(selector))
  };
  // Must be a code segment (type bit 3 set)
  if desc.seg_type[3] == 0b0 then {
    throw Fault(EXN_GP, selector_error_code(selector))
  };

  let rpl : range(0, 3) = unsigned(selector[1..0]);
  let conforming : bool = desc.seg_type[2] == 0b1;

  if conforming then {
    // Conforming: DPL must be <= CPL
    if desc.seg_dpl > cur_cpl then {
      throw Fault(EXN_GP, selector_error_code(selector))
    }
  } else {
    // Non-conforming: DPL must equal CPL, RPL must be <= CPL
    if desc.seg_dpl != cur_cpl then {
      throw Fault(EXN_GP, selector_error_code(selector))
    };
    if rpl > cur_cpl then {
      throw Fault(EXN_GP, selector_error_code(selector))
    }
  };

  // Segment must be present
  if desc.seg_present == 0b0 then {
    throw Fault(EXN_NP, selector_error_code(selector))
  };

  desc
}

// Complete a far transfer in protected mode: load CS from a validated
// descriptor, update execution mode, and set RIP.
// Shared by exec_far_jmp and exec_far_call.
val finish_far_transfer : (SegDescCache, word, qword, {16, 32, 64}) -> unit
function finish_far_transfer(desc, selector, offset, os) = {
  let adj_sel : word = (selector & 0xFFFC) | zero_extend(to_bits(2, cur_cpl));
  write_segreg(CS, adj_sel);
  SegCache[CS] = desc;
  if EFER[10] == 0b1 then {
    if desc.seg_l == 0b1 then cur_mode = LongMode
    else cur_mode = CompatibilityMode
  };
  next_rip = Some(match os {
    16 => zero_extend(offset[15..0]),
    32 => zero_extend(offset[31..0]),
    _  => offset,
  })
}

// Execute far JMP: load CS:RIP from selector:offset.
val exec_far_jmp : (word, qword, {16, 32, 64}) -> unit
function exec_far_jmp(selector, offset, os) = match cur_mode {
  m if m == RealMode | m == Virtual8086Mode => {
    if cur_mode == Virtual8086Mode & os == 32 & unsigned(offset[31..0]) > 65535 then raise_GP0();
    load_segment_register(CS, selector);
    next_rip = Some(match os {
      16 => zero_extend(offset[15..0]),
      _  => zero_extend(offset[31..0]),
    })
  },
  _ => finish_far_transfer(validate_far_jmp_cs(selector), selector, offset, os),
}

// Execute far CALL: push CS:RIP, then load CS:RIP from selector:offset.
// In protected mode, the descriptor is validated before pushing so that
// a fault does not modify the stack.
val exec_far_call : (word, qword, {16, 32, 64}) -> unit
function exec_far_call(selector, offset, os) = match cur_mode {
  m if m == RealMode | m == Virtual8086Mode => {
    if cur_mode == Virtual8086Mode & os == 32 & unsigned(offset[31..0]) > 65535 then raise_GP0();
    match os {
      16 => push(32, read_segreg(CS) @ decode_pos[15..0]),
      _  => push(64, zero_extend(32, read_segreg(CS)) @ decode_pos[31..0]),
    };
    exec_far_jmp(selector, offset, os)
  },
  _ => {
    let desc = validate_far_jmp_cs(selector);
    match os {
      16 => push(32,  read_segreg(CS) @ decode_pos[15..0]),
      32 => push(64,  zero_extend(32, read_segreg(CS)) @ decode_pos[31..0]),
      64 => push(128, zero_extend(64, read_segreg(CS)) @ decode_pos),
    };
    finish_far_transfer(desc, selector, offset, os)
  },
}
