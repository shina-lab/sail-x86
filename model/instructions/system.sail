// System/Privileged Instructions
//
// These are complex system instructions that interact with descriptor
// tables, TLBs, virtualization, and privilege levels. We model them
// as external operations.

// =========================================================================
// INVD -- Invalidate Internal Caches
// =========================================================================
val __invd : unit -> ExecutionResult

val exec_invd : unit -> ExecutionResult
function exec_invd() = __invd()

// =========================================================================
// INVLPG -- Invalidate TLB Entries
// =========================================================================
val __invlpg : qword -> ExecutionResult

val exec_invlpg : qword -> ExecutionResult
function exec_invlpg(addr) = __invlpg(addr)

// =========================================================================
// INVEPT -- Invalidate Translations Derived from EPT
// =========================================================================
val __invept : (qword, xmmword) -> ExecutionResult

val exec_invept : (qword, xmmword) -> ExecutionResult
function exec_invept(invept_type, descriptor) = __invept(invept_type, descriptor)

// =========================================================================
// INVPCID -- Invalidate Process-Context Identifier
// =========================================================================
val __invpcid : (qword, xmmword) -> ExecutionResult

val exec_invpcid : (qword, xmmword) -> ExecutionResult
function exec_invpcid(invpcid_type, descriptor) = __invpcid(invpcid_type, descriptor)

// =========================================================================
// INVVPID -- Invalidate Translations Based on VPID
// =========================================================================
val __invvpid : (qword, xmmword) -> ExecutionResult

val exec_invvpid : (qword, xmmword) -> ExecutionResult
function exec_invvpid(invvpid_type, descriptor) = __invvpid(invvpid_type, descriptor)

// =========================================================================
// IRET/IRETD/IRETQ -- Interrupt Return
// =========================================================================
// Complex privilege-level handling, stack switching, etc.
val __iret : int -> ExecutionResult

// IRET (16-bit operand size)
val exec_iret : unit -> ExecutionResult
function exec_iret() = __iret(16)

// IRETD (32-bit operand size)
val exec_iretd : unit -> ExecutionResult
function exec_iretd() = __iret(32)

// IRETQ (64-bit operand size)
val exec_iretq : unit -> ExecutionResult
function exec_iretq() = __iret(64)

// =========================================================================
// LGDT/LIDT -- Load Global/Interrupt Descriptor Table Register
// =========================================================================
val __lgdt : qword -> ExecutionResult
val __lidt : qword -> ExecutionResult

val exec_lgdt : qword -> ExecutionResult
function exec_lgdt(addr) = __lgdt(addr)

val exec_lidt : qword -> ExecutionResult
function exec_lidt(addr) = __lidt(addr)

// =========================================================================
// LLDT -- Load Local Descriptor Table Register
// =========================================================================
val __lldt : word -> ExecutionResult

val exec_lldt : word -> ExecutionResult
function exec_lldt(selector) = __lldt(selector)

// =========================================================================
// LMSW -- Load Machine Status Word
// =========================================================================
val __lmsw : word -> ExecutionResult

val exec_lmsw : word -> ExecutionResult
function exec_lmsw(src) = __lmsw(src)

// =========================================================================
// LTR -- Load Task Register
// =========================================================================
val __ltr : word -> ExecutionResult

val exec_ltr : word -> ExecutionResult
function exec_ltr(selector) = __ltr(selector)

// =========================================================================
// LAR -- Load Access Rights Byte
// =========================================================================
val __lar : (qword, word) -> (bool, qword)

val exec_lar : (gpr_idx, word, OperandSize) -> ExecutionResult
function exec_lar(dst, selector, os) = {
  let (valid, access_rights) = __lar(zero_extend(selector), selector);
  if valid then {
    ZF = bitone;
    write_gpr(dst, os, access_rights);
  } else {
    ZF = bitzero;
  };
  Ok(())
}

// =========================================================================
// LSL -- Load Segment Limit
// =========================================================================
val __lsl : (qword, word) -> (bool, qword)

val exec_lsl : (gpr_idx, word, OperandSize) -> ExecutionResult
function exec_lsl(dst, selector, os) = {
  let (valid, limit) = __lsl(zero_extend(selector), selector);
  if valid then {
    ZF = bitone;
    write_gpr(dst, os, limit);
  } else {
    ZF = bitzero;
  };
  Ok(())
}

// =========================================================================
// LDS/LES/LFS/LGS/LSS -- Load Far Pointer
// =========================================================================
// These load a segment register and a general-purpose register from memory.
// They are modeled as external due to descriptor table validation.
val __load_far_ptr : (int, qword, OperandSize) -> (word, qword)

val exec_lds : (gpr_idx, qword, OperandSize) -> ExecutionResult
function exec_lds(dst, addr, os) = {
  let (selector, offset) = __load_far_ptr(0 /* DS */, addr, os);
  write_segreg(DS, selector);
  write_gpr(dst, os, offset);
  Ok(())
}

val exec_les : (gpr_idx, qword, OperandSize) -> ExecutionResult
function exec_les(dst, addr, os) = {
  let (selector, offset) = __load_far_ptr(1 /* ES */, addr, os);
  write_segreg(ES, selector);
  write_gpr(dst, os, offset);
  Ok(())
}

val exec_lfs : (gpr_idx, qword, OperandSize) -> ExecutionResult
function exec_lfs(dst, addr, os) = {
  let (selector, offset) = __load_far_ptr(2 /* FS */, addr, os);
  write_segreg(FS, selector);
  write_gpr(dst, os, offset);
  Ok(())
}

val exec_lgs : (gpr_idx, qword, OperandSize) -> ExecutionResult
function exec_lgs(dst, addr, os) = {
  let (selector, offset) = __load_far_ptr(3 /* GS */, addr, os);
  write_segreg(GS, selector);
  write_gpr(dst, os, offset);
  Ok(())
}

val exec_lss : (gpr_idx, qword, OperandSize) -> ExecutionResult
function exec_lss(dst, addr, os) = {
  let (selector, offset) = __load_far_ptr(4 /* SS */, addr, os);
  write_segreg(SS, selector);
  write_gpr(dst, os, offset);
  Ok(())
}

// =========================================================================
// LDTILECFG -- Load Tile Configuration
// =========================================================================
// AMX instruction that loads tile configuration from memory.
val __ldtilecfg : qword -> ExecutionResult

val exec_ldtilecfg : qword -> ExecutionResult
function exec_ldtilecfg(addr) = __ldtilecfg(addr)

// =========================================================================
// LOADIWKEY -- Load Internal Wrapping Key
// =========================================================================
// AES Key Locker instruction. Loads an internal wrapping key.
val __loadiwkey : (dword, xmmword, xmmword, xmmword) -> ExecutionResult

val exec_loadiwkey : unit -> ExecutionResult
function exec_loadiwkey() = {
  let eax_val : dword = read_gpr32(RAX);
  let xmm0_val : xmmword = read_xmm(0);
  let xmm1_val : xmmword = read_xmm(1);
  let xmm2_val : xmmword = read_xmm(2);
  __loadiwkey(eax_val, xmm0_val, xmm1_val, xmm2_val)
}

// =========================================================================
// LOCK -- Assert LOCK# Signal Prefix
// =========================================================================
// LOCK is a prefix that ensures atomic read-modify-write operations.
// For our spec, atomicity is an execution concern; the prefix is a no-op.
val exec_lock : unit -> ExecutionResult
function exec_lock() = Ok(())

// =========================================================================
// MFENCE -- already in lfence.sail

// =========================================================================
// MONITOR -- Set Up Monitor Address
// =========================================================================
// Sets up a linear address range to be monitored by MWAIT.
// Microarchitectural hint; no architectural state change.
val exec_monitor : unit -> ExecutionResult
function exec_monitor() = Ok(())
