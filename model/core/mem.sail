// x86-64 Sail Model — Memory Interface
//
// Simplified memory model. We model a flat 64-bit address space for now.
// Segmentation and paging can be layered on top later.

// Raw physical memory read/write primitives.
// These are external functions provided by the execution environment.
val __read_mem : forall 'n, 'n > 0. (qword, int('n)) -> bits(8 * 'n)
val __write_mem : forall 'n, 'n > 0. (qword, int('n), bits(8 * 'n)) -> unit

// Read 'n bytes from memory at the given virtual address.
val mem_read : forall 'n, 'n > 0. (qword, int('n)) -> bits(8 * 'n)
function mem_read(addr, n) = __read_mem(addr, n)

// Write 'n bytes to memory at the given virtual address.
val mem_write : forall 'n, 'n > 0. (qword, int('n), bits(8 * 'n)) -> unit
function mem_write(addr, n, data) = __write_mem(addr, n, data)

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

// Stack operations using RSP.
val push64 : qword -> unit
function push64(v) = {
  let rsp = read_gpr64(RSP);
  let new_rsp = rsp - 8;
  mem_write64(new_rsp, v);
  write_gpr64(RSP, new_rsp)
}

val pop64 : unit -> qword
function pop64() = {
  let rsp = read_gpr64(RSP);
  let v = mem_read64(rsp);
  write_gpr64(RSP, rsp + 8);
  v
}

val push16 : word -> unit
function push16(v) = {
  let rsp = read_gpr64(RSP);
  let new_rsp = rsp - 2;
  mem_write16(new_rsp, v);
  write_gpr64(RSP, new_rsp)
}

val pop16 : unit -> word
function pop16() = {
  let rsp = read_gpr64(RSP);
  let v = mem_read16(rsp);
  write_gpr64(RSP, rsp + 2);
  v
}
