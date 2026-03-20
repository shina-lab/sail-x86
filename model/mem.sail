// x86-64 — Memory Interface
//
// Two-layer memory model following the sail-riscv pattern:
//   mem_read/mem_write (virtual) → translate_addr → phys_read/phys_write
//
// When paging is disabled (CR0.PG=0, user-mode emulation), translate_addr
// returns the address unchanged, so all existing instruction code works
// without modification.
//
// Physical memory primitives (__read_mem, __write_mem, phys_read, phys_write)
// and the address translation function (translate_addr) are defined in
// paging.sail, which is compiled before this file.

// Slow-path externals for page-crossing accesses.
// These translate each byte separately via translate_addr, so accesses
// that span a 4KB page boundary read/write correct physical memory.
val __mem_read_crossing : forall 'n, 'n > 0. (qword, int('n)) -> bits(8 * 'n)
val __mem_write_crossing : forall 'n, 'n > 0. (qword, int('n), bits(8 * 'n)) -> unit

// Read 'n bytes from memory at the given virtual address.
// Goes through address translation when paging is enabled.
// If the access crosses a 4KB page boundary, each byte is translated
// separately to handle non-contiguous physical pages.
val mem_read : forall 'n, 'n > 0. (qword, int('n)) -> bits(8 * 'n)
function mem_read(addr, n) = {
  let page_offset = unsigned(addr & 0x0000000000000FFF);
  if page_offset + n <= 4096 then {
    let paddr = translate_addr(addr, PT_Read);
    phys_read(paddr, n)
  } else {
    __mem_read_crossing(addr, n)
  }
}

// Write 'n bytes to memory at the given virtual address.
// Same page-crossing logic as mem_read.
val mem_write : forall 'n, 'n > 0. (qword, int('n), bits(8 * 'n)) -> unit
function mem_write(addr, n, data) = {
  let page_offset = unsigned(addr & 0x0000000000000FFF);
  if page_offset + n <= 4096 then {
    let paddr = translate_addr(addr, PT_Write);
    phys_write(paddr, n, data)
  } else {
    __mem_write_crossing(addr, n, data)
  }
}

// Convenience functions for common access sizes.
val mem_read8  : qword -> byte
val mem_read16 : qword -> word
val mem_read32 : qword -> dword
val mem_read64 : qword -> qword
function mem_read8(addr)  = mem_read(addr, 1)
function mem_read16(addr) = mem_read(addr, 2)
function mem_read32(addr) = mem_read(addr, 4)
function mem_read64(addr) = mem_read(addr, 8)

val mem_write8  : (qword, byte)  -> unit
val mem_write16 : (qword, word) -> unit
val mem_write32 : (qword, dword) -> unit
val mem_write64 : (qword, qword) -> unit
function mem_write8(addr, v)  = mem_write(addr, 1, v)
function mem_write16(addr, v) = mem_write(addr, 2, v)
function mem_write32(addr, v) = mem_write(addr, 4, v)
function mem_write64(addr, v) = mem_write(addr, 8, v)

val mem_read128 : qword -> xmmword
val mem_write128 : (qword, xmmword) -> unit
function mem_read128(addr) = mem_read(addr, 16)
function mem_write128(addr, v) = mem_write(addr, 16, v)

val mem_read256 : qword -> ymmword
val mem_write256 : (qword, ymmword) -> unit
function mem_read256(addr) = mem_read(addr, 32)
function mem_write256(addr, v) = mem_write(addr, 32, v)

val mem_read512 : qword -> zmmword
val mem_write512 : (qword, zmmword) -> unit
function mem_read512(addr) = mem_read(addr, 64)
function mem_write512(addr, v) = mem_write(addr, 64, v)

// Stack operations.
// In long mode, uses RSP directly (SS base is 0).
// In non-long mode, linear address = SS base + ESP/SP (SDM Vol.3A §3.4).
// Stack pointer width depends on SS.B: if SS.B=1 then ESP (32-bit),
// if SS.B=0 then SP (16-bit). In long mode, always RSP (64-bit).

// Read the stack pointer as a linear address (SS base + ESP/RSP/SP).
val read_stack_ptr : unit -> qword
function read_stack_ptr() =
  if cur_mode == LongMode then read_gpr64(RSP)
  else get_seg_base(SS) + (
    if SegCache[SS].seg_db == bitone then zero_extend(read_gpr32(RSP))
    else zero_extend(read_gpr16(RSP))
  )

// Write the stack pointer (only the SP/ESP/RSP portion, not the base).
val write_stack_ptr : qword -> unit
function write_stack_ptr(v) =
  if cur_mode == LongMode then write_gpr64(RSP, v)
  else if SegCache[SS].seg_db == bitone then write_gpr32(RSP, v[31..0])
  else write_gpr16(RSP, v[15..0])

val push64 : qword -> unit
function push64(v) = {
  let sp = read_stack_ptr();
  let new_sp = sp - 8;
  mem_write64(new_sp, v);
  write_stack_ptr(new_sp - get_seg_base(SS))
}

val push32 : dword -> unit
function push32(v) = {
  let sp = read_stack_ptr();
  let new_sp = sp - 4;
  mem_write32(new_sp, v);
  write_stack_ptr(new_sp - get_seg_base(SS))
}

val pop64 : unit -> qword
function pop64() = {
  let sp = read_stack_ptr();
  let v = mem_read64(sp);
  write_stack_ptr(sp + 8 - get_seg_base(SS));
  v
}

val pop32 : unit -> dword
function pop32() = {
  let sp = read_stack_ptr();
  let v = mem_read32(sp);
  write_stack_ptr(sp + 4 - get_seg_base(SS));
  v
}

val push16 : word -> unit
function push16(v) = {
  let sp = read_stack_ptr();
  let new_sp = sp - 2;
  mem_write16(new_sp, v);
  write_stack_ptr(new_sp - get_seg_base(SS))
}

val pop16 : unit -> word
function pop16() = {
  let sp = read_stack_ptr();
  let v = mem_read16(sp);
  write_stack_ptr(sp + 2 - get_seg_base(SS));
  v
}

// =========================================================================
// Segment register loading
// =========================================================================

// Load a segment register with a selector, updating both the visible
// selector and the hidden descriptor cache (SDM Vol.3A §3.4.5).
// In real mode: base = selector << 4, limit = 0xFFFF, present, R/W.
// In protected/compat mode: read 8-byte descriptor from GDT/LDT.
// In long mode: just store the selector (FS/GS base set via MSR).
val load_segment_register : (segreg_idx, word) -> unit
function load_segment_register(idx, selector) = {
  write_segreg(idx, selector);
  match cur_mode {
    RealMode => {
      SegCache[idx].seg_base = zero_extend(selector) << 4;
      SegCache[idx].seg_limit = 0x0000FFFF;
      SegCache[idx].seg_present = bitone
    },
    LongMode => (),
    _ => {
      // Protected mode / compatibility mode: read descriptor from GDT or LDT
      let ti : bit = selector[2];
      let index : bits(13) = selector[15..3];
      let table_base : qword = if ti == bitone then {
        // LDT: TODO — for now treat as GDT
        GDTR_base
      } else {
        GDTR_base
      };
      let desc_offset : qword = zero_extend(index @ 0b000);
      let desc_lo : dword = mem_read32(table_base + desc_offset);
      let desc_hi : dword = mem_read32(table_base + desc_offset + 4);
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
