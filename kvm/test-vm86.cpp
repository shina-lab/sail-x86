// Run the same protected-mode monitor and virtual-8086 program on the Sail
// system model and KVM. Both enter through IRETD, then stop in an IDT handler
// at HLT. Compare the registers, saved exception frame and application memory.
// --model-only also runs without /dev/kvm, checking the expected exit vector.

#include "sail_x86_model.h"
#include "x86-helpers.h"
#include <algorithm>
#include <array>
#include <cassert>
#include <cerrno>
#include <cstdio>
#include <cstring>
#include <fcntl.h>
#include <linux/kvm.h>
#include <string>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <vector>

static constexpr u32 MEM_SIZE = 0x100000;
static constexpr u32 PD = 0x1000, PT = 0x2000, GDT = 0x3000, IDT = 0x4000;
static constexpr u32 TSS = 0x5000, ENTRY = 0x8000, HANDLERS = 0x8100;
static constexpr u32 ENTRY_SP = 0x9800, KERNEL_SP = 0xa000;
static constexpr u32 VM_CODE = 0x20000, VM_STACK = 0x30000;
static constexpr u32 VM_FLAG = 1 << 17, VIF_FLAG = 1 << 19, VIP_FLAG = 1 << 20;
static constexpr u32 IO_MAP = 0xa0, TSS_LIMIT = IO_MAP + 8192;
static constexpr u32 ARITH = 0x8d5;
using Bytes = std::vector<u8>;

struct Test {
  std::string name;
  Bytes code;
  u32 flags = 0x23002; // VM=1, IOPL=3; no single step or external interrupts
  u32 cr4 = 0;
  u32 ip = 0x100;
  u32 sp = 0x1234ff00; // stack addressing uses SP, preserving upper ESP
  u16 cs = VM_CODE >> 4;
  unsigned vector = 3; // INT3 ends successful programs, even at IOPL < 3
  u32 error = 0;
  bool supervisor_data = false;
  bool allow_io = false;
  bool supervisor_ivt = false;
  u8 gate_type = 0xe;
  u8 gate_dpl = 3;
  u32 kernel_stack_base = 0;
  u32 kernel_stack_limit = 0xfffff;
  u8 kernel_stack_access = 0x93;
  u8 kernel_stack_flags = 0xc;
  u32 kernel_sp = KERNEL_SP;
  std::vector<std::pair<u32, Bytes>> patches;
  bool check_descriptor_accessed = false;
};

template <typename T> static void store(Bytes &mem, u32 addr, T value) {
  assert(addr + sizeof(value) <= mem.size());
  memcpy(mem.data() + addr, &value, sizeof(value));
}

static u64 descriptor(u32 base, u32 limit, u8 access, u8 flags) {
  return (limit & 0xffffULL) | ((base & 0xffffULL) << 16) |
         (((base >> 16) & 0xffULL) << 32) | (u64(access) << 40) |
         (((limit >> 16) & 0xfULL) << 48) | (u64(flags) << 52) |
         (u64(base >> 24) << 56);
}

static Bytes image(const Test &t, u32 fill) {
  Bytes mem(MEM_SIZE);
  store<u32>(mem, PD, PT | 7);
  for (unsigned i = 0; i < MEM_SIZE / 4096; i++)
    store<u32>(mem, PT + i * 4, i * 4096 | 7);
  // Tables, monitor and its stack are inaccessible to virtual-8086 code.
  for (unsigned i = 1; i < 16; i++)
    store<u32>(mem, PT + i * 4, i * 4096 | 3);
  if (t.supervisor_data) store<u32>(mem, PT + 0x50 * 4, 0x50000 | 3);
  if (t.supervisor_ivt) store<u32>(mem, PT, 3);
  store<u64>(mem, GDT + 8, descriptor(0, 0xfffff, 0x9b, 0xc));
  store<u64>(mem, GDT + 16, descriptor(t.kernel_stack_base, t.kernel_stack_limit,
                                      t.kernel_stack_access, t.kernel_stack_flags));
  store<u64>(mem, GDT + 24, descriptor(TSS, TSS_LIMIT, 0x8b, 0));
  store<u32>(mem, TSS + 4, t.kernel_sp);
  store<u16>(mem, TSS + 8, 0x10);
  store<u16>(mem, TSS + 102, IO_MAP);
  std::fill(mem.begin() + TSS + IO_MAP - 32, mem.begin() + TSS + TSS_LIMIT + 1, 0xff);
  if (t.allow_io) mem[TSS + IO_MAP + 0xe0 / 8] = 0;
  for (unsigned vec = 0; vec < 256; vec++) {
    u32 addr = HANDLERS + vec * 16;
    store<u64>(mem, IDT + vec * 8,
               (addr & 0xffffULL) | (8ULL << 16) |
               (u64(0x80 | t.gate_type | (t.gate_dpl << 5)) << 40) |
               (u64(addr >> 16) << 48));
    mem[addr] = 0xf4;
  }
  // Touch the monitor tables before entering VM86. An EPT fault during
  // INT delivery can make KVM reinject the interrupt, whose VM-entry
  // semantics differ from executing INT with insufficient IOPL.
  Bytes entry = {0x50}; // preserve EAX
  for (u32 addr : {0U, GDT, IDT, TSS, TSS + 4096, TSS + 8192}) {
    entry.push_back(0xa1); // mov eax, [addr]
    for (unsigned i = 0; i < 4; i++) entry.push_back(addr >> (i * 8));
  }
  entry.insert(entry.end(), {0x58, 0xcf}); // pop eax; IRETD
  std::copy(entry.begin(), entry.end(), mem.begin() + ENTRY);
  const u32 frame[] = {t.ip, t.cs, t.flags | (fill & ARITH), t.sp,
                       VM_STACK >> 4, 0x4000, 0x5000, 0x6000, 0x7000};
  memcpy(mem.data() + ENTRY_SP, frame, sizeof(frame));
  assert(u32(t.cs) * 16 + t.ip + t.code.size() + 1 <= MEM_SIZE);
  std::copy(t.code.begin(), t.code.end(), mem.begin() + u32(t.cs) * 16 + t.ip);
  mem[u32(t.cs) * 16 + t.ip + t.code.size()] = 0xcc;
  // Data read by the memory and string tests, identical for both fills.
  store<u32>(mem, 0x50100, 0x89abcdef);
  for (const auto &[addr, bytes] : t.patches)
    std::copy(bytes.begin(), bytes.end(), mem.begin() + addr);
  return mem;
}

struct Result {
  std::array<u32, 8> gpr;
  u32 ip, flags, cr2;
  std::array<u16, 6> seg;
  Bytes mem;
};

static u32 monitor_stack_addr(const Test &t, const Result &r) {
  u32 sp = (t.kernel_stack_flags & 4) ? r.gpr[4] : r.gpr[4] & 0xffff;
  u32 addr = t.kernel_stack_base + sp;
  // Interrupt entry replaces ESP/SP with the TSS monitor stack. Diagnose
  // an incorrect width in generated models before indexing the saved frame.
  if (addr + 40 > MEM_SIZE)
    fprintf(stderr, "%s: monitor stack outside RAM: ESP=%08x base=%08x\n",
            t.name.c_str(), r.gpr[4], t.kernel_stack_base);
  assert(addr + 40 <= MEM_SIZE);
  return addr;
}

static Result run_model(const Test &t, const Bytes &mem, u32 fill) {
  x86::Model m;
  m.model_init();
  m.zinitializze_registers(UNIT);
  x86::enable_all_features(m);
  m.zsystem_mode = true;
  m.za20_enabled = true;
  m.zsystem_state = x86::zSysRunning;
  m.zcur_mode = x86::zProtectedMode;
  m.zcur_cpl = 0;
  m.zCR0 = 0x80000031;
  m.zCR2 = 0;
  m.zCR3 = PD;
  m.zCR4 = t.cr4;
  m.zEFER = 0;
  m.zRIP = ENTRY;
  m.zwrite_rflags(2);
  m.zRF = 0;
  m.zGDTR_base = GDT;
  m.zGDTR_limit = 31;
  m.zIDTR_base = IDT;
  m.zIDTR_limit = 2047;
  m.zTR = 24;
  m.zTR_base = TSS;
  m.zTR_limit = TSS_LIMIT;
  for (int i = 0; i < 16; i++) m.zGPR.data[i] = fill;
  m.zGPR.data[4] = ENTRY_SP;
  for (int i = 0; i < 6; i++) {
    bool cs = i == 1;
    auto &cache = m.zSegCache.data[i];
    m.zSegReg.data[i] = cs ? 8 : 16;
    cache.zseg_base = 0;
    cache.zseg_limit = 0xffffffff;
    cache.zseg_type = cs ? 0xb : 3;
    cache.zseg_s = 1;
    cache.zseg_dpl = 0;
    cache.zseg_present = 1;
    cache.zseg_db = 1;
    cache.zseg_l = 0;
    cache.zseg_g = 1;
  }
  assert(m.phys_mem.init(MEM_SIZE));
  m.phys_mem.write_bytes(0, mem.data(), mem.size());
  for (unsigned n = 0; n < 1000; n++) {
    m.zstep(UNIT);
    if (m.zfault_pending || m.zsystem_state == x86::zSysHalted) break;
  }
  if (m.zfault_pending || m.zsystem_state != x86::zSysHalted) {
    fprintf(stderr, "%s: model did not reach monitor HLT (ip=%lx fault=%ld)\n",
            t.name.c_str(), u64(m.zRIP), long(m.zfault_vector));
    abort();
  }
  assert(m.zcur_mode == x86::zProtectedMode && m.zcur_cpl == 0);
  Result r;
  for (int i = 0; i < 8; i++) r.gpr[i] = m.zGPR.data[i];
  for (int i = 0; i < 6; i++) r.seg[i] = m.zSegReg.data[i];
  r.ip = m.zRIP;
  r.flags = m.zread_rflags(UNIT);
  r.cr2 = m.zCR2;
  r.mem.resize(MEM_SIZE);
  m.phys_mem.read_bytes(0, r.mem.data(), MEM_SIZE);
  m.model_fini();
  return r;
}

static void checked(int ret, const char *what) {
  if (ret < 0) { perror(what); exit(1); }
}

class Kvm {
  int kvm, vm, cpu, run_size;
  u8 *mem;
  kvm_run *run;
public:
  Kvm() {
    kvm = open("/dev/kvm", O_RDWR | O_CLOEXEC);
    checked(kvm, "open /dev/kvm");
    vm = ioctl(kvm, KVM_CREATE_VM, 0);
    checked(vm, "create VM");
    mem = static_cast<u8 *>(mmap(nullptr, MEM_SIZE, PROT_READ | PROT_WRITE,
                                MAP_PRIVATE | MAP_ANONYMOUS, -1, 0));
    assert(mem != MAP_FAILED);
    kvm_userspace_memory_region region{};
    region.memory_size = MEM_SIZE;
    region.userspace_addr = reinterpret_cast<u64>(mem);
    checked(ioctl(vm, KVM_SET_USER_MEMORY_REGION, &region), "set memory");
    cpu = ioctl(vm, KVM_CREATE_VCPU, 0);
    checked(cpu, "create VCPU");
    Bytes cpuid_bytes(sizeof(kvm_cpuid2) + 256 * sizeof(kvm_cpuid_entry2));
    auto *cpuid = reinterpret_cast<kvm_cpuid2 *>(cpuid_bytes.data());
    cpuid->nent = 256;
    checked(ioctl(kvm, KVM_GET_SUPPORTED_CPUID, cpuid), "get CPUID");
    checked(ioctl(cpu, KVM_SET_CPUID2, cpuid), "set CPUID");
    run_size = ioctl(kvm, KVM_GET_VCPU_MMAP_SIZE, 0);
    checked(run_size, "get run size");
    run = static_cast<kvm_run *>(mmap(nullptr, run_size, PROT_READ | PROT_WRITE,
                                    MAP_SHARED, cpu, 0));
    assert(run != MAP_FAILED);
  }
  ~Kvm() {
    munmap(run, run_size);
    munmap(mem, MEM_SIZE);
    close(cpu); close(vm); close(kvm);
  }
  Result execute(const Test &t, const Bytes &img, u32 fill) {
    memcpy(mem, img.data(), MEM_SIZE); // includes tables and accessed bits
    kvm_sregs s{};
    s.cr0 = 0x80000031;
    s.cr3 = PD;
    s.cr4 = t.cr4;
    s.apic_base = 0xfee00900;
    s.gdt.base = GDT; s.gdt.limit = 31;
    s.idt.base = IDT; s.idt.limit = 2047;
    s.cs = {.base=0, .limit=0xffffffff, .selector=8, .type=11,
            .present=1, .dpl=0, .db=1, .s=1, .l=0, .g=1};
    s.ds = s.es = s.ss = s.fs = s.gs = s.cs;
    s.ds.selector = s.es.selector = s.ss.selector = s.fs.selector = s.gs.selector = 16;
    s.ds.type = s.es.type = s.ss.type = s.fs.type = s.gs.type = 3;
    s.tr = {.base=TSS, .limit=TSS_LIMIT, .selector=24, .type=11, .present=1};
    s.ldt = {.type=2, .unusable=1};
    checked(ioctl(cpu, KVM_SET_SREGS, &s), "set sregs");
    kvm_regs regs{};
    regs.rax = regs.rbx = regs.rcx = regs.rdx = fill;
    regs.rsi = regs.rdi = regs.rbp = fill;
    regs.rsp = ENTRY_SP; regs.rip = ENTRY; regs.rflags = 2;
    checked(ioctl(cpu, KVM_SET_REGS, &regs), "set regs");
    for (;;) {
      int ret = ioctl(cpu, KVM_RUN, 0);
      if (ret < 0 && errno == EINTR) continue;
      checked(ret, "KVM_RUN");
      if (run->exit_reason == KVM_EXIT_HLT) break;
      if (run->exit_reason == KVM_EXIT_IO) {
        if (run->io.direction == KVM_EXIT_IO_IN)
          memset(reinterpret_cast<u8 *>(run) + run->io.data_offset, 0xff,
                 run->io.size * run->io.count);
        continue;
      }
      fprintf(stderr, "%s: unexpected KVM exit %u\n", t.name.c_str(), run->exit_reason);
      abort();
    }
    checked(ioctl(cpu, KVM_GET_REGS, &regs), "get regs");
    checked(ioctl(cpu, KVM_GET_SREGS, &s), "get sregs");
    return {{u32(regs.rax), u32(regs.rcx), u32(regs.rdx), u32(regs.rbx),
             u32(regs.rsp), u32(regs.rbp), u32(regs.rsi), u32(regs.rdi)},
            u32(regs.rip), u32(regs.rflags), u32(s.cr2),
            {s.es.selector, s.cs.selector, s.ss.selector, s.ds.selector,
             s.fs.selector, s.gs.selector}, Bytes(mem, mem + MEM_SIZE)};
  }
};

static std::vector<Test> tests() {
  std::vector<Test> ts;
  ts.push_back({"nop", {0x90}});
  for (bool wide : {false, true}) {
    Test t{"descriptor accessed on monitor entry wide=" + std::to_string(wide), {0x90}};
    t.gate_type = wide ? 0xe : 0x6;
    t.kernel_stack_access = 0x92;
    t.kernel_stack_flags = wide ? 0xc : 0;
    t.kernel_stack_limit = wide ? 0xfffff : 0xffff;
    t.patches.push_back({GDT + 13, {0x9a}});
    t.check_descriptor_accessed = true;
    ts.push_back(t);
  }

  ts.push_back({"VIF/VIP survive monitor entry", {0x90}});
  ts.back().flags |= VIF_FLAG | VIP_FLAG;
  ts.push_back({"16-bit arithmetic", {0xb8,0xff,0x7f, 0x05,0x01,0x00}});
  ts.push_back({"32-bit arithmetic", {0x66,0xb8,0xff,0xff,0xff,0x7f, 0x66,0x40}});
  ts.push_back({"DS memory", {0xa1,0x00,0x01}});
  ts.push_back({"32-bit address/operand", {0x67,0x66,0xa1,0x00,0x01,0,0}});
  ts.push_back({"null data segment", {0xb8,0,0, 0x8e,0xd8, 0xa1,0,0}});
  ts.push_back({"segment low bits are address bits", {0xb8,0x07,0x50, 0x8e,0xd8, 0xa1,0x90,0}});
  ts.push_back({"FS/GS loads", {0xb8,0x07,0x50, 0x8e,0xe0, 0x8e,0xe8,
                                0x64,0xa1,0x90,0, 0x65,0x8b,0x1e,0x90,0}});
  ts.push_back({"push/pop 16", {0x68,0x34,0x12, 0x58}});
  ts.push_back({"push/pop 32", {0x66,0x68,0x78,0x56,0x34,0x12, 0x66,0x58}});
  ts.push_back({"16-bit stack wrap", {0x68,0x34,0x12, 0x58}});
  ts.back().sp = 0xabcd0000;
  ts.push_back({"MOVS", {0xbe,0,1, 0xbf,0,2, 0xfc, 0xa5}});
  ts.push_back({"REP MOVS", {0xbe,0,1, 0xbf,0,2, 0xb9,2,0, 0xfc, 0xf3,0xa5}});
  for (u8 op : {0xa4, 0xa5, 0xac, 0xad})
  for (bool wide : {false, true}) for (bool memory : {false, true})
  for (u8 count : {0, 5}) {
    Test t{"double shift opcode=" + std::to_string(op) +
           " wide=" + std::to_string(wide) + " memory=" + std::to_string(memory) +
           " count=" + std::to_string(count),
           {0x66,0xb8,1,0x80,0x34,0x12, 0xba,0xef,0xcd,
            0xb9,count,0, 0xbf,0,2}};
    if (wide) t.code.push_back(0x66);
    t.code.insert(t.code.end(), {0x0f, op, u8(memory ? 0x15 : 0xd0)});
    if (!(op & 1)) t.code.push_back(count);
    // Normalize undefined shift flags; compare GPRs and every memory byte.
    t.code.insert(t.code.end(), {0x39,0xdb}); // CMP BX,BX
    t.patches.push_back({0x50200, {1,0x80,0x34,0x12,0x55,0x66,0x77,0x88}});
    ts.push_back(t);
  }
  for (u8 op : {0xa4, 0xa5, 0xaa, 0xab, 0xac, 0xad})
  for (bool wide : {false, true}) for (bool backward : {false, true}) {
    Test t{"F2 string opcode=" + std::to_string(op) +
           " wide=" + std::to_string(wide) + " DF=" + std::to_string(backward),
           {0xbe,0,1, 0xbf,0,2, 0xb9,3,0, u8(backward ? 0xfd : 0xfc)}};
    if (wide) t.code.push_back(0x66);
    t.code.insert(t.code.end(), {0xf2, op});
    ts.push_back(t);
  }
  ts.push_back({"CS selector zero", {0x90}});
  ts.back().cs = 0;
  ts.push_back({"far jump", {0xea,0x00,0x04,0x01,0x20}});
  ts.back().patches.push_back({0x20410, {0xcc}});
  ts.push_back({"far call/return", {0x9a,0x00,0x04,0x01,0x20}});
  ts.back().patches.push_back({0x20410, {0xcb}});
  ts.push_back({"IRET in vm86", {0x68,0x02,0x02, 0x68,0x01,0x20, 0x68,0,4, 0xcf}});
  ts.back().patches.push_back({0x20410, {0xcc}});
  ts.push_back({"IRETD in vm86", {0x66,0x68,2,2,0,0, 0x66,0x68,1,0x20,0,0,
                                 0x66,0x68,0,4,0,0, 0x66,0xcf}});
  ts.back().patches.push_back({0x20410, {0xcc}});
  for (auto [name, code] : std::vector<std::pair<std::string, Bytes>>{
      {"HLT", {0xf4}}, {"CLI", {0xfa}}, {"STI", {0xfb}},
      {"PUSHF", {0x9c}}, {"PUSHFD", {0x66,0x9c}},
      {"POPF", {0x68,2,0,0x9d}}, {"POPFD", {0x66,0x68,2,0,0,0,0x66,0x9d}},
      {"IRET", {0xcf}}, {"INT", {0xcd,0x80}}}) {
    for (unsigned iopl : {0U, 3U}) {
      Test t{name + " IOPL=" + std::to_string(iopl), code};
      t.flags = VM_FLAG | (iopl << 12) | 2;
      if (iopl != 3 || name == "HLT") t.vector = 13;
      else if (name == "INT") t.vector = 0x80;
      else if (name == "IRET") continue; // explicit valid frames above
      ts.push_back(t);
    }
  }
  for (auto [name, code] : std::vector<std::pair<std::string, Bytes>>{
      {"ARPL", {0x63,0xc0}}, {"SLDT", {0x0f,0x00,0xc0}},
      {"STR", {0x0f,0x00,0xc8}}, {"LLDT", {0x0f,0x00,0xd0}},
      {"LTR", {0x0f,0x00,0xd8}}, {"VERR", {0x0f,0x00,0xe0}},
      {"VERW", {0x0f,0x00,0xe8}}, {"LAR", {0x0f,0x02,0xc0}},
      {"LSL", {0x0f,0x03,0xc0}}}) {
    Test t{name + " #UD", code}; t.vector = 6; ts.push_back(t);
  }
  for (auto [name, code] : std::vector<std::pair<std::string, Bytes>>{
      {"BLSI", {0xc4,0xe2,0x78,0xf3,0xd8}},
      {"VZEROUPPER", {0xc5,0xf8,0x77}},
      {"VMXON", {0xf3,0x0f,0xc7,0x36,0,1}}}) {
    Test t{name + " #UD in vm86", code}; t.vector = 6; ts.push_back(t);
  }
  for (auto [name, code] : std::vector<std::pair<std::string, Bytes>>{
      {"MOV CR0", {0x0f,0x20,0xc0}}, {"CLTS", {0x0f,0x06}},
      {"LGDT", {0x0f,0x01,0x16,0,1}}, {"LIDT", {0x0f,0x01,0x1e,0,1}}}) {
    Test t{name + " #GP", code}; t.vector = 13; ts.push_back(t);
  }
  for (unsigned iopl : {0U, 3U}) {
    for (bool allow : {false, true}) {
      for (auto [name, code] : std::vector<std::pair<std::string, Bytes>>{
          {"IN", {0xe4,0xe0}}, {"OUT", {0xb0,0x5a,0xe6,0xe0}},
          {"INS", {0xba,0xe0,0, 0xbf,0,2, 0xfc, 0x6d}},
          {"OUTS", {0xba,0xe0,0, 0xbe,0,1, 0xfc, 0x6f}}}) {
        Test t{name + (allow ? " allowed" : " denied") + " IOPL=" + std::to_string(iopl), code};
        t.flags = VM_FLAG | (iopl << 12) | 2;
        t.allow_io = allow;
        t.vector = allow ? 3 : 13;
        ts.push_back(t);
      }
    }
  }
  Test pf{"user page protection", {0xa1,0,1}};
  pf.supervisor_data = true; pf.vector = 14; pf.error = 5; ts.push_back(pf);
  Test limit{"data segment limit", {0x67,0xa1,0,0,1,0}};
  limit.vector = 13; ts.push_back(limit);
  Test stack{"stack segment limit", {0x66,0x58}};
  stack.sp = 0xffff; stack.vector = 12; ts.push_back(stack);
  Test entry{"IRETD entry truncates EIP", {}};
  entry.ip = 0x10000; entry.vector = 3;
  entry.patches.push_back({VM_CODE, {0xcc}}); ts.push_back(entry);
  Test trap{"INT3 ignores IOPL", {0xcc}};
  trap.flags = VM_FLAG | 2; ts.push_back(trap);
  Test dpl{"INT3 gate DPL", {0xcc}};
  dpl.gate_dpl = 0; dpl.vector = 13; dpl.error = 3 * 8 + 2; ts.push_back(dpl);
  Test base{"nonzero monitor SS base", {0x90}};
  base.kernel_stack_base = 0x10000; ts.push_back(base);
  Test resume{"monitor IRETD resumes vm86", {0x0f,0x0b, 0xbb,0x34,0x12}};
  // #UD has no error code: skip UD2 in the saved EIP, then IRETD.
  resume.patches.push_back({HANDLERS + 6 * 16, {0x83,0x04,0x24,2, 0xcf}});
  ts.push_back(resume);
  Test gate16{"16-bit interrupt gate", {0xcc}};
  gate16.gate_type = 6; ts.push_back(gate16);
  gate16.name = "16-bit gate with error code";
  gate16.code = {0xf4}; gate16.vector = 13; ts.push_back(gate16);
  Test into{"INTO at IOPL 0", {0xb8,0xff,0x7f, 0x40, 0xce}};
  into.flags = VM_FLAG | 2; into.vector = 4; ts.push_back(into);

  for (u32 iopl : {0U, 3U}) {
    for (unsigned state = 0; state < 4; state++) {
      bool vif = state & 1, vip = state & 2;
      for (auto [name, code] : std::vector<std::pair<std::string, Bytes>>{
          {"CLI", {0xfa}}, {"STI", {0xfb}},
          {"PUSHF", {0x9c,0x58}}, {"PUSHFD", {0x66,0x9c,0x66,0x58}},
          {"POPF IF=0", {0x68,2,0,0x9d}},
          {"POPF IF=1", {0x68,2,2,0x9d}},
          {"POPFD", {0x66,0x68,2,0,0,0,0x66,0x9d}},
          {"IRET", {0x68,2,0,0x68,0,0x20,0x68,0,4,0xcf}},
          {"IRET IF=1", {0x68,2,2,0x68,0,0x20,0x68,0,4,0xcf}},
          {"IRET TF=1", {0x68,2,1,0x68,0,0x20,0x68,0,4,0xcf}},
          {"IRETD", {0x66,0x68,2,0,0,0,0x66,0x68,0,0x20,0,0,
                      0x66,0x68,0,4,0,0,0x66,0xcf}}}) {
        if (iopl == 3 && name == "IRET TF=1") continue;
        Test t{"VME " + name + " IOPL=" + std::to_string(iopl) +
               " VIF=" + std::to_string(vif) + " VIP=" + std::to_string(vip), code};
        t.cr4 = 1;
        t.flags = VM_FLAG | 2 | (iopl << 12) | (vif ? VIF_FLAG : 0) |
                  (vip ? VIP_FLAG : 0);
        if ((vif && vip) ||
            (iopl == 0 && (name == "PUSHFD" || name == "POPFD" || name == "IRETD" ||
                           name == "IRET TF=1" ||
                           (vip && (name == "STI" || name == "POPF IF=1" ||
                                    name == "IRET IF=1")))))
          t.vector = 13;
        t.patches.push_back({VM_CODE + 0x400, {0xcc}});
        ts.push_back(t);
      }
      for (bool redirect : {false, true}) {
        Test t{"VME INT IOPL=" + std::to_string(iopl) +
               " state=" + std::to_string(state) + (redirect ? " redirected" : " monitored"),
               {0xcd,0x21}};
        t.flags = VM_FLAG | 2 | (iopl << 12) | (vif ? VIF_FLAG : 0) |
                  (vip ? VIP_FLAG : 0);
        t.cr4 = 1;
        if (redirect) {
          t.supervisor_ivt = true;
          t.patches.push_back({TSS + IO_MAP - 32 + 0x21 / 8, {0xfd}});
          t.patches.push_back({0x21 * 4, {0,4,0,0x20}});
          t.patches.push_back({VM_CODE + 0x400, {0xcf}});
        } else {
          t.vector = iopl == 3 ? 0x21 : 13;
        }
        if (vif && vip) t.vector = 13;
        ts.push_back(t);
      }
    }
  }
  Test tf{"VME POPF rejects TF", {0x68,2,1,0x9d}};
  tf.cr4 = 1; tf.flags = VM_FLAG | 2; tf.vector = 13; ts.push_back(tf);
  for (bool db : {false, true}) {
    Test down{"expand-down monitor stack " + std::to_string(db ? 32 : 16), {0x90}};
    down.kernel_stack_limit = 0x9000;
    down.kernel_stack_access = 0x97;
    down.kernel_stack_flags = db ? 4 : 0;
    ts.push_back(down);
  }
  for (bool down : {false, true}) {
    Test wrap{"16-bit monitor stack at zero" + std::string(down ? " expand-down" : ""), {0x90}};
    wrap.kernel_stack_limit = down ? 0x9000 : 0xffff;
    wrap.kernel_stack_access = down ? 0x97 : 0x93;
    wrap.kernel_stack_flags = 0;
    wrap.kernel_sp = 0;
    ts.push_back(wrap);
  }
  return ts;
}

int main(int argc, char **argv) {
  bool model_only = argc > 1 && std::string(argv[1]) == "--model-only";
  if (!model_only && access("/dev/kvm", R_OK | W_OK)) return 77;
  unsigned passed = 0, failed = 0;
  for (const auto &t : tests()) {
    for (u32 fill : {0U, ~0U}) {
      Bytes mem = image(t, fill);
      Result m = run_model(t, mem, fill);
      bool ok = m.ip == HANDLERS + t.vector * 16 + 1;
      bool error = t.vector == 12 || t.vector == 13 || t.vector == 14;
      if (t.gate_type & 8) {
        u32 saved_flags;
        memcpy(&saved_flags, m.mem.data() + monitor_stack_addr(t, m) +
               (error ? 12 : 8), 4);
        ok &= (saved_flags & VM_FLAG) != 0;
      }
      if (error) {
        u32 saved = 0;
        memcpy(&saved, m.mem.data() + monitor_stack_addr(t, m),
               (t.gate_type & 8) ? 4 : 2);
        ok &= saved == t.error;
      }
      if (!model_only) {
        Kvm kvm; // independent VM and fresh memory for each run
        Result hw = kvm.execute(t, mem, fill);
        ok &= m.gpr == hw.gpr && m.ip == hw.ip && m.flags == hw.flags &&
              m.seg == hw.seg && m.cr2 == hw.cr2;
        if (t.check_descriptor_accessed) {
          for (u32 addr : {GDT + 13, GDT + 21}) {
            if (!(m.mem[addr] & 1) || m.mem[addr] != hw.mem[addr]) {
              fprintf(stderr, "%s: descriptor[%x] model=%02x hardware=%02x\n",
                      t.name.c_str(), addr, m.mem[addr], hw.mem[addr]);
              ok = false;
            }
          }
        }
        // Ignore page-table A/D bits and descriptor-cache accessed bits.
        // Everything the test or exception handler can write is compared.
        for (u32 addr = ENTRY_SP; addr < MEM_SIZE; addr++) {
          if (m.mem[addr] != hw.mem[addr]) {
            fprintf(stderr, "%s: memory[%x] model=%02x hardware=%02x\n",
                    t.name.c_str(), addr, m.mem[addr], hw.mem[addr]);
            ok = false; break;
          }
        }
        if (!ok) {
          fprintf(stderr, "%s: ip=%x/%x flags=%x/%x cr2=%x/%x (model/hardware)\n",
                  t.name.c_str(), m.ip, hw.ip, m.flags, hw.flags, m.cr2, hw.cr2);
          for (int i = 0; i < 8; i++)
            if (m.gpr[i] != hw.gpr[i])
              fprintf(stderr, "  gpr[%d]=%x/%x\n", i, m.gpr[i], hw.gpr[i]);
          for (int i = 0; i < 10; i++) {
            u32 a, b;
            memcpy(&a, m.mem.data() + monitor_stack_addr(t, m) + i * 4, 4);
            memcpy(&b, hw.mem.data() + monitor_stack_addr(t, hw) + i * 4, 4);
            fprintf(stderr, "  frame[%d]=%x/%x\n", i, a, b);
          }
        }
      }
      printf("%s %s [fill=%s]\n", ok ? "PASS" : "FAIL", t.name.c_str(), fill ? "ones" : "zeros");
      ok ? passed++ : failed++;
    }
  }
  printf("vm86: %u passed, %u failed\n", passed, failed);
  return failed != 0;
}
