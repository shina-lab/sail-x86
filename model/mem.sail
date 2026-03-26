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
val write_mem_linear : forall 'n, 'n > 0. (implicit('n), qword, bits('n)) -> unit
val read_mem_ref : forall 'n, 'n > 0. (implicit('n), MemRef) -> bits('n)
val write_mem_ref : forall 'n, 'n > 0. (implicit('n), MemRef, bits('n)) -> unit

overload read_mem = {read_mem_data, read_mem_ref}
overload write_mem = {write_mem_linear, write_mem_ref}

// Read 'n bits from memory at the given virtual address.
// Goes through address translation when paging is enabled.
// If the access crosses a 4KB page boundary, each byte is translated
// separately to handle non-contiguous physical pages.
function read_mem_linear(n, addr, access) = {
  let page_offset = unsigned(addr & 0x0000000000000FFF);
  if page_offset + n / 8 <= 4096 then {
    let paddr = translate_addr(addr, access);
    phys_read(n, paddr)
  } else {
    __mem_read_crossing(addr, n, access)
  }
}

// Data-read wrapper: read_mem_linear with PT_Read access.
function read_mem_data(n, addr) = read_mem_linear(addr, PT_Read)

// Write 'n bits to memory at the given virtual address.
// Same page-crossing logic as mem_read.
function write_mem_linear(n, addr, data) = {
  let page_offset = unsigned(addr & 0x0000000000000FFF);
  if page_offset + n / 8 <= 4096 then {
    let paddr = translate_addr(addr, PT_Write);
    phys_write(n, paddr, data)
  } else {
    __mem_write_crossing(addr, n, data)
  }
}

// Stack operations.
// In long mode, uses RSP directly (SS base is 0).
// In non-long mode, linear address = SS base + ESP/SP (SDM Vol.3A §3.4).
// Stack pointer width depends on SS.B: if SS.B=1 then ESP (32-bit),
// if SS.B=0 then SP (16-bit). In long mode, always RSP (64-bit).

// Read the stack pointer as a linear address (SS base + ESP/RSP/SP).
val read_stack_ptr : unit -> qword
function read_stack_ptr() =
  if cur_mode == LongMode then v(64, RSP)
  else get_seg_base(SS) + (
    if SegCache[SS].seg_db == 0b1 then zero_extend(v(32, RSP))
    else zero_extend(v(16, RSP))
  )

// Write the stack pointer (only the SP/ESP/RSP portion, not the base).
val write_stack_ptr : qword -> unit
function write_stack_ptr(v) =
  if cur_mode == LongMode then v(RSP) = v
  else if SegCache[SS].seg_db == 0b1 then v(RSP) = v[31..0]
  else v(RSP) = v[15..0]

// Stack push helper: decrement SP by the value's byte width, write
// the value at the new SP, then commit the SP update — all as a
// single logical operation.  Because SP is written only after the
// store succeeds, a fault during write_mem leaves SP unchanged.
//
// In non-64-bit modes with SS.B=0, SP is 16-bit and wraps at 0xFFFF.
// Without wrapping, SP=2 minus 4 would produce linear address SS.base-2,
// which is below the segment — wrong.  It should wrap to SS.base+0xFFFE.
val push : forall 'n, 8 <= 'n & 'n <= 512. (implicit('n), bits('n)) -> unit
function push(n, v) = {
  let nbytes = n / 8;
  if cur_mode == LongMode then {
    let sp = v(64, RSP) - nbytes;
    write_mem(sp, v);
    v(RSP) = sp
  } else {
    let base = get_seg_base(SS);
    let new_off : qword = if SegCache[SS].seg_db == 0b1
      then zero_extend(v(32, RSP) - nbytes)
      else zero_extend(v(16, RSP) - nbytes);
    write_mem(base + new_off, v);
    write_stack_ptr(new_off)
  }
}

// Stack pop helper: read 'n bits from SP, then advance SP — again
// as a single logical operation.
val pop : forall 'n, 8 <= 'n & 'n <= 512. (implicit('n)) -> bits('n)
function pop(n) = {
  let sp = read_stack_ptr();
  let x : bits('n) = read_mem(sp);
  write_stack_ptr(sp + n / 8 - get_seg_base(SS));
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
val load_segment_register : (segreg_idx, word) -> unit
function load_segment_register(idx, selector) = {
  // Do memory reads (GDT lookup) before writing the segment register,
  // so that a fault during the GDT read leaves the segment unchanged.
  match cur_mode {
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
      let desc_lo : dword = read_mem(table_base + desc_offset);
      let desc_hi : dword = read_mem(table_base + desc_offset + 4);
      write_segreg(idx, selector);
      SegCache[idx] = parse_seg_descriptor(desc_lo, desc_hi)
    },
  }
}

// =========================================================================
// Segment limit checking (SDM Vol.3A §6.3)
// =========================================================================

// Check that an access at the given offset with the given size is within
// the segment limit. Raises #GP(0) for non-SS segments, #SS(0) for SS.
// Only checks in non-long mode; 64-bit mode disables limit checking for
// CS/DS/ES/SS (SDM Vol.3A §6.3.1).
// For expand-up segments: offset + size - 1 <= effective_limit.
val check_seg_limit : (segreg_idx, qword, int) -> unit
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
val seg_linear : (MemRef, int) -> qword
function seg_linear(m, access_size) = {
  // Apply RIP-relative fixup if pending (only in LongMode, where
  // mod=00 rm=101 means [RIP+disp32])
  let offset = if rip_rel_pending then decode_pos + rip_rel_disp else m.addr;
  check_seg_limit(m.seg, offset, access_size);
  offset + get_seg_base(m.seg)
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
  let d : bits(2 * 'os) = pop();
  (zero_extend(d['os - 1 .. 0]), d['os + 15 .. 'os])
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
    throw Fault(EXN_GP, zero_extend(selector))
  };
  let desc_lo : dword = read_mem(table_base + desc_offset);
  let desc_hi : dword = read_mem(table_base + desc_offset + 4);
  parse_seg_descriptor(desc_lo, desc_hi)
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
    throw Fault(EXN_GP, zero_extend(selector))
  };
  // Must be a code segment (type bit 3 set)
  if desc.seg_type[3] == 0b0 then {
    throw Fault(EXN_GP, zero_extend(selector))
  };

  let rpl : range(0, 3) = unsigned(selector[1..0]);
  let conforming : bool = desc.seg_type[2] == 0b1;

  if conforming then {
    // Conforming: DPL must be <= CPL
    if desc.seg_dpl > cur_cpl then {
      throw Fault(EXN_GP, zero_extend(selector))
    }
  } else {
    // Non-conforming: DPL must equal CPL, RPL must be <= CPL
    if desc.seg_dpl != cur_cpl then {
      throw Fault(EXN_GP, zero_extend(selector))
    };
    if rpl > cur_cpl then {
      throw Fault(EXN_GP, zero_extend(selector))
    }
  };

  // Segment must be present
  if desc.seg_present == 0b0 then {
    throw Fault(EXN_NP, zero_extend(selector))
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
  RealMode => {
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
  RealMode => {
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
