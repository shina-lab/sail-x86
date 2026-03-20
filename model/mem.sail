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
