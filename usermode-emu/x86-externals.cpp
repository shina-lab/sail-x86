// User-mode specific external function implementations.
// Shared functions are in ../emu-shared/x86-externals-common.cpp.

#include "sail_x86_model.h"
#include "x86-cpuid.h"
#include "x86-helpers.h"
#include <cstring>
#include <cmath>
#include <cfenv>
#include <unordered_map>
#include <vector>
#include <immintrin.h>
#include <x86intrin.h>

namespace x86 {
void Model::z__read_mem(lbits *rop, u64 addr, sail_int n) {
  i64 nbits = mpz_get_si(n);
  i64 nbytes = nbits / 8;
  u8 buf[128];
  if (nbytes > 128) {
    fprintf(stderr, "z__read_mem: nbytes=%ld > 128\n", nbytes);
    abort();
  }
  memcpy(buf, (void *)addr, nbytes);
  bytes_to_bits(rop, buf, nbytes, nbits);
}

unit Model::z__write_mem(u64 addr, sail_int n, lbits data) {
  i64 nbits = mpz_get_si(n);
  i64 nbytes = nbits / 8;
  u8 buf[128];
  if (nbytes > 128) {
    fprintf(stderr, "z__write_mem: nbytes=%ld > 128\n", nbytes);
    abort();
  }
  bits_to_bytes(data, buf, nbytes);
  memcpy((void *)addr, buf, nbytes);
  return UNIT;
}

// Page-crossing read/write — translate each byte's virtual address
// separately, like the system emulator.  With paging disabled (CR0.PG=0,
// the user-mode emulator's normal state) translate_addr is the identity,
// so this matches the old direct access; with paging enabled (the KVM
// harness's #PF tests link this file) a crossing access faults exactly
// like the non-crossing path instead of bypassing translation.
void Model::z__mem_read_crossing(lbits *rop, u64 addr, sail_int n, enum zPTAccess access) {
  i64 nbits = mpz_get_si(n);
  i64 nbytes = nbits / 8;
  u8 buf[128];
  if (nbytes > 128) {
    fprintf(stderr, "z__mem_read_crossing: nbytes=%ld > 128\n", nbytes);
    abort();
  }
  for (i64 i = 0; i < nbytes; i++) {
    u64 paddr = ztranslate_addr(addr + i, access);
    // On #PF the generated code records the exception and returns a
    // dummy value; propagate instead of dereferencing it.
    if (have_exception) {
      bytes_to_bits(rop, buf, nbytes, nbits);
      return;
    }
    buf[i] = *(u8 *)paddr;
  }
  bytes_to_bits(rop, buf, nbytes, nbits);
}

unit Model::z__mem_write_crossing(u64 addr, sail_int n, lbits data) {
  i64 nbits = mpz_get_si(n);
  i64 nbytes = nbits / 8;
  u8 buf[128];
  if (nbytes > 128) {
    fprintf(stderr, "z__mem_write_crossing: nbytes=%ld > 128\n", nbytes);
    abort();
  }
  bits_to_bytes(data, buf, nbytes);
  for (i64 i = 0; i < nbytes; i++) {
    u64 paddr = ztranslate_addr(addr + i, zPT_Write);
    if (have_exception)
      return UNIT;  // #PF recorded; do not touch the dummy address
    *(u8 *)paddr = buf[i];
  }
  return UNIT;
}

// =========================================================================
// Software TLB — no-op stubs for user mode (paging is disabled)
// =========================================================================

void Model::z__tlb_lookup(struct zoptionzIbzK *rop, u64, bool) {
  rop->kind = Kind_zNonezIbzK;
}
unit Model::z__tlb_insert(u64, u64, bool) { return UNIT; }
unit Model::z__tlb_flush(unit) { return UNIT; }

// =========================================================================
// MSRs the model keeps outside its registers: a plain store, empty at start
// (user mode has no MSR access; the KVM harness loads a test's MSRs).
// =========================================================================

static std::unordered_map<u64, u64> msr_store;

u64 Model::z__read_cr8(unit) { return zCR8; }
unit Model::z__write_cr8(u64) { return UNIT; }

void x86_externals_reset_msrs() { msr_store.clear(); }
void x86_externals_set_msr(u64 msr, u64 value) { msr_store[msr] = value; }

u64 Model::z__rdmsr(u64 msr) {
  auto it = msr_store.find(msr);
  return it == msr_store.end() ? 0 : it->second;
}
unit Model::z__wrmsr(u64 msr, u64 value) {
  msr_store[msr] = value;
  return UNIT;
}
bool Model::z__check_pending_smi(unit) { return false; }

// =========================================================================
// I/O ports: user mode has no devices.  The KVM harness compares the
// sequence of port accesses with the guest's, so every access is logged
// (direction in bit 63, size in bits 55:48, port in bits 47:32, value in
// bits 31:0), and IN returns a value derived from the port, which the
// harness also supplies to the guest.
// =========================================================================

static std::vector<u64> port_io_log;

u32 x86_externals_port_in_value(u16 port, unsigned size) {
  u32 value = 0xA5000000u ^ (u32(port) * 0x01010101u);
  return size == 4 ? value : value & ((1u << (8 * size)) - 1);
}
static void log_port_io(bool out, unsigned size, u64 port, u64 value) {
  port_io_log.push_back((u64(out) << 63) | (u64(size) << 48) | ((port & 0xFFFF) << 32) | (value & 0xFFFFFFFF));
}
void x86_externals_reset_port_io() { port_io_log.clear(); }
const std::vector<u64> &x86_externals_port_io() { return port_io_log; }

u64 Model::z__port_in8(u64 port) {
  u32 v = x86_externals_port_in_value(port, 1);
  log_port_io(false, 1, port, v);
  return v;
}
u64 Model::z__port_in16(u64 port) {
  u32 v = x86_externals_port_in_value(port, 2);
  log_port_io(false, 2, port, v);
  return v;
}
u64 Model::z__port_in32(u64 port) {
  u32 v = x86_externals_port_in_value(port, 4);
  log_port_io(false, 4, port, v);
  return v;
}
unit Model::z__port_out8(u64 port, u64 value) { log_port_io(true, 1, port, value & 0xFF); return UNIT; }
unit Model::z__port_out16(u64 port, u64 value) { log_port_io(true, 2, port, value & 0xFFFF); return UNIT; }
unit Model::z__port_out32(u64 port, u64 value) { log_port_io(true, 4, port, value); return UNIT; }

// External interrupt check — not used in user mode
void Model::z__check_pending_irq(sail_int *rop, unit) { mpz_set_si(*rop, -1); }

} // namespace x86
