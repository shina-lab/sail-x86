// KVM-based differential test harness for sail-x86.
//
// Sets up a KVM VM in 64-bit long mode, runs test instruction sequences,
// and compares the resulting architectural state against the Sail model.

#include "kvm-harness.h"
#include "x86-helpers.h"

#include <algorithm>
#include <cpuid.h>
#include <cfenv>
#include <csetjmp>
#include <csignal>
#include <map>
#include <unordered_map>
#include <sys/syscall.h>
#include <sys/utsname.h>

// Print the identity of the hardware oracle.  The differential result is
// only meaningful relative to the silicon it ran against (vendor behavior
// may legally diverge where the SDM leaves state undefined), so every log
// records which CPU and kernel produced it.
static void print_host_identity() {
  u32 a, b, c, d;
  char vendor[13] = {};
  if (__get_cpuid(0, &a, &b, &c, &d)) {
    memcpy(vendor + 0, &b, 4);
    memcpy(vendor + 4, &d, 4);
    memcpy(vendor + 8, &c, 4);
  }
  char brand[49] = {};
  if (__get_cpuid_max(0x80000000, nullptr) >= 0x80000004) {
    u32 *p = (u32 *)brand;
    for (u32 leaf = 0x80000002; leaf <= 0x80000004; leaf++) {
      __get_cpuid(leaf, &a, &b, &c, &d);
      *p++ = a; *p++ = b; *p++ = c; *p++ = d;
    }
  }
  for (int i = 47; i >= 0 && (brand[i] == ' ' || brand[i] == '\0'); i--)
    brand[i] = '\0';  // trim trailing padding
  struct utsname un = {};
  uname(&un);
  fprintf(stderr, "host CPU: %s (%s)\n", brand, vendor);
  fprintf(stderr, "host kernel: %s %s (%s)\n",
          un.sysname, un.release, un.machine);
}

// The host's CPUID, read once per leaf and sub-leaf (under a hypervisor
// each CPUID exits to it); zeros above the maximum leaf.
static std::array<u32, 4> host_cpuid(u32 leaf, u32 subleaf) {
  static std::map<std::pair<u32, u32>, std::array<u32, 4>> cache;
  auto [it, added] = cache.try_emplace({leaf, subleaf});
  std::array<u32, 4> &r = it->second;
  if (added && __get_cpuid_max(leaf & 0x80000000, nullptr) >= leaf)
    __cpuid_count(leaf, subleaf, r[0], r[1], r[2], r[3]);
  return r;
}

// The CPUID entries KVM supports for a guest, read once; none without
// /dev/kvm.  Linux grants a guest the AMX tile data component
// (XFEATURE_XTILEDATA = 18) only to a process that asked for it with
// ARCH_REQ_XCOMP_GUEST_PERM: before that KVM_GET_SUPPORTED_CPUID omits XCR0
// bits 17 and 18, and KVM_SET_XCRS rejects them.
static const std::vector<kvm_cpuid_entry2> &kvm_supported_cpuid() {
  static const std::vector<kvm_cpuid_entry2> entries = [] {
    std::vector<kvm_cpuid_entry2> v;
    if ((host_cpuid(7, 0)[CPUID_EDX] >> 24 & 1) &&
        syscall(SYS_arch_prctl, 0x1025 /* ARCH_REQ_XCOMP_GUEST_PERM */, 18) < 0)
      fprintf(stderr, "ARCH_REQ_XCOMP_GUEST_PERM(XTILEDATA): %s; the guest has no AMX\n",
              strerror(errno));
    int fd = open("/dev/kvm", O_RDWR | O_CLOEXEC);
    if (fd < 0)
      return v;
    std::vector<u8> buf(sizeof(kvm_cpuid2) + 256 * sizeof(kvm_cpuid_entry2));
    auto *cpuid = (kvm_cpuid2 *)buf.data();
    cpuid->nent = 256;
    if (ioctl(fd, KVM_GET_SUPPORTED_CPUID, cpuid) == 0)
      v.assign(cpuid->entries, cpuid->entries + cpuid->nent);
    else
      perror("KVM_GET_SUPPORTED_CPUID");
    close(fd);
    return v;
  }();
  return entries;
}

static kvm_cpuid_entry2 *find_cpuid_entry(std::vector<kvm_cpuid_entry2> &v, u32 leaf,
                                          u32 subleaf) {
  for (kvm_cpuid_entry2 &e : v)
    if (e.function == leaf &&
        (!(e.flags & KVM_CPUID_FLAG_SIGNIFCANT_INDEX) || e.index == subleaf))
      return &e;
  return nullptr;
}

// The CPUID the harness installs in the guest (KVM_SET_CPUID2): what KVM
// supports, with leaf 0DH restricted to the state components the harness
// uses, as the model implements them, and to no supervisor component.
// Sub-leaf 0 then enumerates those components and the largest standard
// format for them ("EAX[31:0] ... Bit i is 1 if bit i of XCR0 can be set
// to 1", ECX the size for "all supported state components"; SDM Table
// 21-34), sub-leaf 1 no IA32_XSS bit (ECX and EDX, Table 21-35), and the
// sub-leaf of a component left out zeros, as for one "not supported"
// (Table 21-36).  KVM keeps the guest's XCR0 and IA32_XSS within these
// bits and computes the dynamic sizes (0DH.0:EBX, 0DH.1:EBX) itself.
//
// Two instructions the guest executes as the host's processor does,
// whatever its CPUID says, are ones KVM does not report: ENQCMD and
// ENQCMDS (CPUID.(7,0):ECX[29]), and PTWRITE (CPUID.(14H,0):EBX[4], in the
// leaf of Intel PT, CPUID.(7,0):EBX[25]).  Their bits are the host's, so
// that the guest's CPUID describes the instructions it has.
static std::vector<kvm_cpuid_entry2> &guest_cpuid_entries() {
  static std::vector<kvm_cpuid_entry2> entries = [] {
    std::vector<kvm_cpuid_entry2> v = kvm_supported_cpuid();
    if (v.empty())
      return v;
    if (kvm_cpuid_entry2 *e7 = find_cpuid_entry(v, 7, 0)) {
      e7->ecx |= host_cpuid(7, 0)[CPUID_ECX] & (1u << 29);
      if ((host_cpuid(7, 0)[CPUID_EBX] >> 25 & 1) && (host_cpuid(0x14, 0)[CPUID_EBX] >> 4 & 1)) {
        kvm_cpuid_entry2 *e14 = find_cpuid_entry(v, 0x14, 0);
        if (!e14) {
          v.push_back({.function = 0x14, .index = 0, .flags = KVM_CPUID_FLAG_SIGNIFCANT_INDEX});
          e14 = &v.back();
          e7 = find_cpuid_entry(v, 7, 0);
        }
        e7->ebx |= 1u << 25;
        e14->ebx |= 1u << 4;
      }
    }
    kvm_cpuid_entry2 *d0 = find_cpuid_entry(v, 0xD, 0);
    if (!d0)
      return v;
    // x87 (0), SSE (1), AVX (2), AVX-512 (5-7) and AMX (17, 18).  XSETBV
    // takes the AVX-512 components only "for all three state components,
    // and only if it also does so for AVX state and SSE state", and the
    // AMX ones only together (SDM Vol.1 §13.3 p.13-5, 13-6), so each
    // group is given whole or not at all.
    u64 x = (d0->eax | (u64)d0->edx << 32) & 0x600E7;
    if ((x & 0x6) != 0x6) x &= ~0xE4ULL;
    if ((x & 0xE0) != 0xE0) x &= ~0xE0ULL;
    if ((x & 0x60000) != 0x60000) x &= ~0x60000ULL;
    u32 size = 576;
    for (kvm_cpuid_entry2 &e : v) {
      if (e.function != 0xD || e.index < 2) continue;
      if (e.index < 64 && (x >> e.index & 1))
        size = std::max(size, e.eax + e.ebx);
      else
        e.eax = e.ebx = e.ecx = e.edx = 0;
    }
    d0->eax = (u32)x;
    d0->edx = (u32)(x >> 32);
    d0->ecx = size;
    if (kvm_cpuid_entry2 *d1 = find_cpuid_entry(v, 0xD, 1))
      d1->ecx = d1->edx = 0;
    return v;
  }();
  return entries;
}

std::array<u32, 4> guest_cpuid(u32 leaf, u32 subleaf) {
  const kvm_cpuid_entry2 *e = find_cpuid_entry(guest_cpuid_entries(), leaf, subleaf);
  if (!e)
    return {};
  return {e->eax, e->ebx, e->ecx, e->edx};
}

bool host_has(u32 leaf, u32 subleaf, CpuidReg reg, unsigned bit) {
  return (host_cpuid(leaf, subleaf)[reg] >> bit & 1) &&
         (guest_cpuid(leaf, subleaf)[reg] >> bit & 1);
}

u64 guest_xcr0_supported() {
  if (!host_has(feature::XSAVE))
    return 0x3;
  std::array<u32, 4> d0 = guest_cpuid(0xD, 0);
  return d0[CPUID_EAX] | (u64)d0[CPUID_EDX] << 32;
}

u64 guest_xcr0() { return guest_xcr0_supported() & ~0x60000ULL; }

u64 guest_cr4() {
  return 0x620 | (host_has(feature::FSGSBASE) ? CR4_FSGSBASE : 0) |
         (host_has(feature::XSAVE) ? CR4_OSXSAVE : 0);
}

bool host_has_avx512() {
  return host_has(feature::AVX512F) && (guest_xcr0_supported() & 0xE0) == 0xE0;
}

bool host_has_amx() {
  static const bool amx = [] {
    if (!host_has(feature::AMX_TILE) || (guest_xcr0_supported() & 0x60000) != 0x60000)
      return false;
    // Palette 1 of 8 tiles of 16 rows of 64 bytes, and tmul_maxk 16 and
    // tmul_maxn 64: each field "Value = ..." in the SDM, as is the
    // highest palette, 1.
    std::array<u32, 4> palette1 = {0x04002000, 0x00080040, 0x00000010, 0};
    if (guest_cpuid(0x1D, 0)[CPUID_EAX] < 1 || guest_cpuid(0x1D, 1) != palette1 ||
        (guest_cpuid(0x1E, 0)[CPUID_EBX] & 0xFFFFFF) != 0x004010) {
      fprintf(stderr, "the guest's AMX palette or TMUL limits (CPUID 1DH, 1EH) are not "
              "the SDM's: AMX left out\n");
      return false;
    }
    return true;
  }();
  return amx;
}

// ---- The AVX-512 features (kvm-harness.h) ----
//
// The model has those of the host (set_avx512_features), and a case runs
// where the host has those it needs (build_suite).  --host-lacks=NAME runs
// as a host without the feature would: the cases that need it are not run,
// and the model lacks it (but GFNI, VAES and VPCLMULQDQ, which it keeps
// for their VEX and legacy forms).  --model-lacks=NAME clears it in the
// model only, so that a case that needs it fails with the model's #UD
// where the host executes it.  Between them they check the cases'
// features against the model's.

static const struct {
  const char *name;
  CpuidBit bit;
} AVX512_FEATURE_BITS[AVX512_FEATURES] = {
  {"AVX512F", feature::AVX512F},
  {"AVX512DQ", feature::AVX512DQ},
  {"AVX512_IFMA", feature::AVX512_IFMA},
  {"AVX512PF", feature::AVX512PF},
  {"AVX512ER", feature::AVX512ER},
  {"AVX512CD", feature::AVX512CD},
  {"AVX512BW", feature::AVX512BW},
  {"AVX512VL", feature::AVX512VL},
  {"AVX512_VBMI", feature::AVX512_VBMI},
  {"AVX512_VBMI2", feature::AVX512_VBMI2},
  {"GFNI", feature::GFNI},
  {"VAES", feature::VAES},
  {"VPCLMULQDQ", feature::VPCLMULQDQ},
  {"AVX512_VNNI", feature::AVX512_VNNI},
  {"AVX512_BITALG", feature::AVX512_BITALG},
  {"AVX512_VPOPCNTDQ", feature::AVX512_VPOPCNTDQ},
  {"AVX512_VP2INTERSECT", feature::AVX512_VP2INTERSECT},
  {"AVX512_FP16", feature::AVX512_FP16},
  {"AVX512_BF16", feature::AVX512_BF16},
};

static u32 g_host_lacks, g_model_lacks;  // masks of 1 << Avx512Feature

const char *avx512_feature_name(Avx512Feature f) { return AVX512_FEATURE_BITS[f].name; }

// None without the AVX-512 state components, which every EVEX instruction
// needs enabled in XCR0.
static u32 host_avx512_features() {
  static const u32 has = [] {
    u32 mask = 0;
    if (host_has_avx512())
      for (unsigned f = 0; f < AVX512_FEATURES; f++)
        if (host_has(AVX512_FEATURE_BITS[f].bit)) mask |= 1u << f;
    return mask;
  }();
  return has & ~g_host_lacks;
}

bool host_has(Avx512Feature f) { return host_avx512_features() >> f & 1; }

// The feature of --host-lacks=NAME or --model-lacks=NAME, added to *mask.
static bool parse_avx512_feature(const std::string &name, u32 *mask) {
  for (unsigned f = 0; f < AVX512_FEATURES; f++)
    if (name == AVX512_FEATURE_BITS[f].name) {
      *mask |= 1u << f;
      return true;
    }
  fprintf(stderr, "unknown AVX-512 feature %s; one of:", name.c_str());
  for (const auto &b : AVX512_FEATURE_BITS) fprintf(stderr, " %s", b.name);
  fprintf(stderr, "\n");
  return false;
}

static void set_avx512_features(x86::Model &model) {
  u32 has = host_avx512_features() & ~g_model_lacks;
  auto on = [has](Avx512Feature f) { return (has >> f & 1) != 0; };
  model.zhas_avx512f = on(AVX512F);
  model.zhas_avx512dq = on(AVX512DQ);
  model.zhas_avx512_ifma = on(AVX512_IFMA);
  model.zhas_avx512pf = on(AVX512PF);
  model.zhas_avx512er = on(AVX512ER);
  model.zhas_avx512cd = on(AVX512CD);
  model.zhas_avx512bw = on(AVX512BW);
  model.zhas_avx512vl = on(AVX512VL);
  model.zhas_avx512_vbmi = on(AVX512_VBMI);
  model.zhas_avx512_vbmi2 = on(AVX512_VBMI2);
  model.zhas_avx512_vnni = on(AVX512_VNNI);
  model.zhas_avx512_bitalg = on(AVX512_BITALG);
  model.zhas_avx512_vpopcntdq = on(AVX512_VPOPCNTDQ);
  model.zhas_avx512_vp2intersect = on(AVX512_VP2INTERSECT);
  model.zhas_avx512_fp16 = on(AVX512_FP16);
  model.zhas_avx512_bf16 = on(AVX512_BF16);
  // GFNI, VAES and VPCLMULQDQ are features of VEX and legacy forms too,
  // which set_model_profile gives the model from host_has; here only
  // --model-lacks clears them.
  if (g_model_lacks >> GFNI & 1) model.zhas_gfni = false;
  if (g_model_lacks >> VAES & 1) model.zhas_vaes = false;
  if (g_model_lacks >> VPCLMULQDQ & 1) model.zhas_vpclmulqdq = false;
}

// ---- End of the AVX-512 features ----

// Byte offsets of the extended state components in the standard-format
// XSAVE image that KVM_GET_XSAVE and KVM_SET_XSAVE exchange: "the byte
// offset from the base address of the XSAVE area enumerated in
// CPUID.0DH.i:EBX" (SDM Vol.1 §13.4.3 p.13-9).  0 for a component the
// guest does not have.
struct XsaveLayout {
  u32 ymm_hi128;  // component 2: YMM0-15 bits 255:128
  u32 opmask;     // component 5: k0-k7
  u32 zmm_hi256;  // component 6: ZMM0-15 bits 511:256
  u32 hi16_zmm;   // component 7: ZMM16-31
  u32 tilecfg;    // component 17: AMX TILECFG
  u32 tiledata;   // component 18: AMX TILEDATA, 8 tiles of 1024 bytes
};

static XsaveLayout host_xsave_layout() {
  auto offset = [](unsigned i) -> u32 {
    return guest_xcr0_supported() >> i & 1 ? guest_cpuid(0xD, i)[CPUID_EBX] : 0;
  };
  return {offset(2), offset(5), offset(6), offset(7), offset(17), offset(18)};
}

// MXCSR_MASK as the host's FXSAVE stores it, the procedure SDM Vol.1
// §11.6.6 (p.11-21) gives for software to learn the MXCSR bits the
// processor supports.  The guest runs on the same processor.
u32 host_mxcsr_mask() {
  static const u32 mask = [] {
    alignas(16) u8 image[512] = {};
    asm volatile("fxsave %0" : "=m"(image));
    u32 m;
    memcpy(&m, image + 28, 4);
    return m;
  }();
  return mask;
}

// Whether a test enables the AMX tile components (XCR0 bits 17 and 18);
// its tile state is then compared as well.
static bool test_has_amx(const TestCase &tc) {
  return (tc.xcr0_override & (3ULL << 17)) == (3ULL << 17);
}

// The model's vendor register selects the manual whose rule the model
// follows where the SDM and the APM define different behaviour
// (model/regs.sail).  The host's is the guest's.
static x86::zVendor host_vendor() {
  u32 a, b, c, d;
  __get_cpuid(0, &a, &b, &c, &d);
  return b == 0x68747541 ? x86::zVendor_AMD : x86::zVendor_Intel;  // "Auth"
}

// Exception handlers for vectors 0-31 at handler_addr (16-byte stubs, then a
// common handler 32 * 16 bytes in), and a 64-bit IDT of interrupt gates to
// them at idt_addr.  The gates select IST1, the handlers' own stack, so
// that delivery neither depends on the test's RSP (which may point where
// nothing is mapped) nor writes the test's memory.  The common handler
// records vector, error code, pushed RIP and pushed RFLAGS at
// fault_info_addr and halts.  Addresses are relative to base: the guest
// memory for the KVM side, the process's own address space (base 0) for
// the model.
static void write_idt(u8 *base, u64 idt_addr, u64 handler_addr, u64 fault_info_addr) {
  // Vectors with error codes pushed by CPU
  auto has_error_code = [](int v) {
    return v == 8 || v == 10 || v == 11 || v == 12 ||
           v == 13 || v == 14 || v == 17 || v == 21 || v == 30;
  };
  const u64 common_handler = handler_addr + 32 * 16;

  // Write handler stubs, 16 bytes each
  for (int v = 0; v < 32; v++) {
    u8 stub[16];
    memset(stub, 0xCC, sizeof(stub));  // fill with INT3
    int off = 0;
    if (!has_error_code(v)) {
      stub[off++] = 0x6A;  // push 0 (dummy error code)
      stub[off++] = 0x00;
    } else {
      stub[off++] = 0x90;  // nop nop (error code on stack)
      stub[off++] = 0x90;
    }
    stub[off++] = 0x6A;   // push <vector>
    stub[off++] = (u8)v;
    stub[off++] = 0xE9;                          // jmp rel32
    u64 stub_addr = handler_addr + v * 16;
    i32 rel = (i32)(common_handler - (stub_addr + off + 4));
    memcpy(stub + off, &rel, 4);
    memcpy(base + stub_addr, stub, 16);
  }

  // Common handler: pop vector + error code, store at fault_info_addr, HLT
  auto abs32 = [](u64 addr) {
    return std::vector<u8>{(u8)addr, (u8)(addr >> 8), (u8)(addr >> 16), (u8)(addr >> 24)};
  };
  std::vector<u8> common = {0x58};                               // pop rax (vector)
  auto emit = [&](std::initializer_list<u8> bytes, u64 addr = ~0ULL) {
    common.insert(common.end(), bytes);
    if (addr != ~0ULL) { auto a = abs32(addr); common.insert(common.end(), a.begin(), a.end()); }
  };
  emit({0x48, 0x89, 0x04, 0x25}, fault_info_addr);              // mov [fi], rax
  emit({0x58});                                                 // pop rax (error code)
  emit({0x48, 0x89, 0x04, 0x25}, fault_info_addr + 8);          // mov [fi+8], rax
  emit({0x48, 0x8B, 0x04, 0x24});                               // mov rax, [rsp]  (pushed RIP)
  emit({0x48, 0x89, 0x04, 0x25}, fault_info_addr + 16);         // mov [fi+16], rax
  emit({0x48, 0x8B, 0x44, 0x24, 0x10});                         // mov rax, [rsp+16]  (pushed RFLAGS)
  emit({0x48, 0x89, 0x04, 0x25}, fault_info_addr + 24);         // mov [fi+24], rax
  emit({0xF4});                                                 // hlt
  memcpy(base + common_handler, common.data(), common.size());

  // Write IDT entries (16-byte interrupt gate descriptors)
  for (int v = 0; v < 32; v++) {
    u64 handler = handler_addr + v * 16;
    u8 entry[16] = {};
    u16 offset_lo = handler & 0xFFFF;
    u16 selector = 0x08;  // code segment
    u8 type_attr = 0x8E;  // present, DPL=0, 64-bit interrupt gate
    u16 offset_mid = (handler >> 16) & 0xFFFF;
    u32 offset_hi = (handler >> 32) & 0xFFFFFFFF;
    memcpy(entry + 0, &offset_lo, 2);
    memcpy(entry + 2, &selector, 2);
    entry[4] = 1;  // IST1
    entry[5] = type_attr;
    memcpy(entry + 6, &offset_mid, 2);
    memcpy(entry + 8, &offset_hi, 4);
    memcpy(base + idt_addr + v * 16, entry, 16);
  }
}

// The descriptor tables and exception handlers, which both sides keep at
// the same addresses, written for every case: segment loads set Accessed
// bits and LTR a busy bit that a later LAR or LTR would see, and a stray
// store can reach them.  Relative to base, as in write_idt.
static void write_system_tables(u8 *base) {
  // GDT: null, 64-bit code, data, plus test entries for LAR/LSL/VERR/VERW
  u64 *gdt = (u64 *)(base + GDT_ADDR);
  gdt[0] = 0;
  gdt[1] = 0x00AF9A000000FFFF;  // 64-bit code (selector 0x08): type=0xA, S=1
  gdt[2] = 0x00CF92000000FFFF;  // data (selector 0x10): type=0x2, S=1
  // 64-bit TSS at TSS_ADDR (selector 0x18): type=0x9, S=0, P=1
  // Descriptor: base=TSS_ADDR, limit=0x67 (103 bytes)
  gdt[3] = 0x0000890000000067ULL
         | ((TSS_ADDR & 0x00FFFFFF) << 16)
         | ((TSS_ADDR & 0xFF000000) << 32);
  gdt[4] = 0;  // upper half: base[63:32] = 0
  gdt[5] = 0x00008E0000000000;  // interrupt gate type (selector 0x28): type=0xE, S=0, P=1
  gdt[6] = 0;                   // upper half
  gdt[7] = 0x00CF90000000FFFF;  // read-only data (selector 0x38): type=0x0, S=1, P=1
  gdt[8] = 0x00AF98000000FFFF;  // execute-only code (selector 0x40): type=0x8, S=1, P=1
  gdt[9] = 0x00CF9A000000FFFF;   // 32-bit code (selector 0x48): type=0xA, S=1, D=1, L=0
  gdt[10] = 0x00AFFA000000FFFF;  // 64-bit user code (selector 0x53): type=0xA, S=1, DPL=3, L=1
  gdt[11] = 0x00CFF2000000FFFF;  // user data (selector 0x5B): type=0x2, S=1, DPL=3

  // TSS: RSP0 at offset 4, IST1 at offset 0x24
  u8 *tss = base + TSS_ADDR;
  memset(tss, 0, 104);
  u64 rsp0 = STACK_TOP, ist1 = HANDLER_STACK_TOP;
  memcpy(tss + 4, &rsp0, 8);
  memcpy(tss + 0x24, &ist1, 8);

  // IDT: exception handlers for vectors 0-31, and no fault recorded yet
  write_idt(base, IDT_ADDR, HANDLER_ADDR, FAULT_INFO_ADDR);
  memset(base + FAULT_INFO_ADDR, 0xFF, 32);
}

// Identity page tables for the low 2MB in four consecutive pages from
// pml4_addr: PML4, PDPT, PD, and a page table of 4KB pages, present from
// CODE_ADDR up (see the layout in kvm-harness.h).  U/S is set at every
// level so that user-mode (CPL 3) tests can work.  Relative to base, as
// in write_idt.
static void write_page_tables(u8 *base, u64 pml4_addr) {
  u64 *pml4 = (u64 *)(base + pml4_addr);
  u64 *pdpt = pml4 + 512, *pd = pdpt + 512, *pt = pd + 512;
  memset(pml4, 0, 4 * 0x1000);
  pml4[0] = (pml4_addr + 0x1000) | 0x7;  // present + writable + user
  pdpt[0] = (pml4_addr + 0x2000) | 0x7;
  pd[0] = (pml4_addr + 0x3000) | 0x7;
  for (u64 addr = CODE_ADDR; addr < GUEST_MEM_SIZE; addr += 0x1000)
    pt[addr / 0x1000] = addr | 0x7;
}

// MSRs the fast system calls and RDPID read, reset to zero before every
// test and loaded from TestCase::msrs.  IA32_EFER is handled through the
// segment state (KVM) and the EFER register (model).
static constexpr u32 MSR_IA32_EFER = 0xC0000080;
static constexpr u32 MSR_IA32_TSC_AUX = 0xC0000103;
static constexpr u32 FAST_CALL_MSRS[] = {
  0xC0000081, 0xC0000082, 0xC0000083, 0xC0000084,  // STAR, LSTAR, CSTAR, FMASK
  0x00000174, 0x00000175, 0x00000176,              // SYSENTER_CS, _ESP, _EIP
  MSR_IA32_TSC_AUX,                                // RDPID, RDTSCP
};

// The model's __rdmsr/__wrmsr externals keep their values here
// (usermode-emu/x86-externals.cpp).
namespace x86 {
void x86_externals_reset_msrs();
void x86_externals_set_msr(u64 msr, u64 value);
// Port I/O: the value an IN returns for a port, and the log of the model's
// accesses in the packed form the externals define (direction, size, port,
// value), compared with the guest's KVM_EXIT_IO sequence.
u32 x86_externals_port_in_value(u16 port, unsigned size);
void x86_externals_reset_port_io();
const std::vector<u64> &x86_externals_port_io();
}

static void print_port_io(const char *label, const std::vector<u64> &log) {
  fprintf(stderr, "    %s:", label);
  for (u64 e : log)
    fprintf(stderr, " %s%u(%#x)=%#x", (e >> 63) ? "out" : "in", unsigned((e >> 48) & 0xFF),
            unsigned((e >> 32) & 0xFFFF), unsigned(e & 0xFFFFFFFF));
  fprintf(stderr, "\n");
}

void fill_data_page(const TestCase &tc, u8 *page) {
  memset(page, 0, 0x1000);
  if (!tc.init_data.empty())
    memcpy(page, tc.init_data.data(), tc.init_data.size());
}

// The memory a test can change and the harness compares after a run: the
// data page and the stack page.
struct MemPages {
  u8 data[0x1000];
  u8 stack[0x1000];
};

static bool compare_page(const char *label, const u8 *kvm, const u8 *sail) {
  if (memcmp(kvm, sail, 0x1000) == 0) return true;
  for (size_t i = 0; i < 0x1000; i += 16) {
    if (memcmp(kvm + i, sail + i, 16) == 0) continue;
    fprintf(stderr, "  MISMATCH %s+%#05zx: kvm=", label, i);
    for (int j = 0; j < 16; j++) fprintf(stderr, "%02x", kvm[i + j]);
    fprintf(stderr, " sail=");
    for (int j = 0; j < 16; j++) fprintf(stderr, "%02x", sail[i + j]);
    fprintf(stderr, "\n");
  }
  return false;
}

// The vector and opmask registers after a run that faults, which the
// handlers do not touch.  A fault restores "the machine state to the
// state prior to the beginning of execution of the faulting instruction"
// (SDM Vol.3A §7.5, p.7-5), except what an instruction's description lets
// it leave behind, such as the elements a gather completed below the
// faulting one and the mask bits of those a scatter completed.
static bool compare_vector_state(const ArchState &kvm, const ArchState &sail) {
  bool ok = true;
  for (int i = 0; i < 32; i++) {
    if (kvm.xmm[i] == sail.xmm[i]) continue;
    fprintf(stderr, "  MISMATCH ZMM%d: kvm=", i);
    for (int q = 7; q >= 0; q--) fprintf(stderr, "%016lx", kvm.xmm[i].q[q]);
    fprintf(stderr, "\n                 sail=");
    for (int q = 7; q >= 0; q--) fprintf(stderr, "%016lx", sail.xmm[i].q[q]);
    fprintf(stderr, "\n");
    ok = false;
  }
  for (int i = 0; i < 8; i++) {
    if (kvm.kregs[i] == sail.kregs[i]) continue;
    fprintf(stderr, "  MISMATCH K%d: kvm=%016lx sail=%016lx\n", i, kvm.kregs[i], sail.kregs[i]);
    ok = false;
  }
  return ok;
}

// ---- KVM VM ----

struct KvmVm {
  int kvm_fd = -1;
  int vm_fd = -1;
  int vcpu_fd = -1;
  struct kvm_run *run = nullptr;
  u8 *guest_mem = nullptr;
  const XsaveLayout xl = host_xsave_layout();
  // The XSAVE image exchanged with KVM: struct kvm_xsave (4096 bytes)
  // unless the guest's area is larger, which KVM_CAP_XSAVE2 reports and
  // KVM_GET_XSAVE2 reads (a guest with AMX has 11008 bytes).
  size_t xsave_size = sizeof(struct kvm_xsave);
  bool have_xsave2 = false;
  // The tile state after the last run of a test that enables AMX.
  AmxState amx;

  ~KvmVm() {
    if (run) munmap(run, sizeof(kvm_run));
    if (guest_mem) munmap(guest_mem, GUEST_MEM_SIZE);
    if (vcpu_fd >= 0) close(vcpu_fd);
    if (vm_fd >= 0) close(vm_fd);
    if (kvm_fd >= 0) close(kvm_fd);
  }

  bool init() {
    kvm_fd = open("/dev/kvm", O_RDWR | O_CLOEXEC);
    if (kvm_fd < 0) {
      perror("/dev/kvm");
      return false;
    }

    int api_ver = ioctl(kvm_fd, KVM_GET_API_VERSION, 0);
    if (api_ver != 12) {
      fprintf(stderr, "KVM API version %d (expected 12)\n", api_ver);
      return false;
    }

    // The AMX permission (kvm_supported_cpuid) comes before the VM.
    if (guest_cpuid_entries().empty()) {
      fprintf(stderr, "KVM_GET_SUPPORTED_CPUID failed\n");
      return false;
    }
    int xsave2 = ioctl(kvm_fd, KVM_CHECK_EXTENSION, KVM_CAP_XSAVE2);
    if (xsave2 > 0) {
      have_xsave2 = true;
      if ((size_t)xsave2 > xsave_size) xsave_size = xsave2;
    }

    vm_fd = ioctl(kvm_fd, KVM_CREATE_VM, 0UL);
    if (vm_fd < 0) {
      perror("KVM_CREATE_VM");
      return false;
    }

    guest_mem = (u8 *)mmap(nullptr, GUEST_MEM_SIZE,
                           PROT_READ | PROT_WRITE,
                           MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (guest_mem == MAP_FAILED) {
      perror("mmap guest");
      return false;
    }

    struct kvm_userspace_memory_region region = {};
    region.slot = 0;
    region.guest_phys_addr = 0;
    region.memory_size = GUEST_MEM_SIZE;
    region.userspace_addr = (u64)guest_mem;
    if (ioctl(vm_fd, KVM_SET_USER_MEMORY_REGION, &region) < 0) {
      perror("KVM_SET_USER_MEMORY_REGION");
      return false;
    }

    vcpu_fd = ioctl(vm_fd, KVM_CREATE_VCPU, 0UL);
    if (vcpu_fd < 0) {
      perror("KVM_CREATE_VCPU");
      return false;
    }

    int mmap_size = ioctl(kvm_fd, KVM_GET_VCPU_MMAP_SIZE, 0);
    if (mmap_size < 0) {
      perror("KVM_GET_VCPU_MMAP_SIZE");
      return false;
    }
    run = (struct kvm_run *)mmap(nullptr, mmap_size, PROT_READ | PROT_WRITE,
                                 MAP_SHARED, vcpu_fd, 0);
    if (run == MAP_FAILED) {
      perror("mmap vcpu");
      return false;
    }

    // The guest's CPUID (guest_cpuid_entries), which the gates and the
    // model's profile follow.
    {
      const std::vector<kvm_cpuid_entry2> &entries = guest_cpuid_entries();
      std::vector<u8> buf(sizeof(kvm_cpuid2) + entries.size() * sizeof(kvm_cpuid_entry2));
      auto *cpuid = (kvm_cpuid2 *)buf.data();
      cpuid->nent = entries.size();
      std::copy(entries.begin(), entries.end(), cpuid->entries);
      if (ioctl(vcpu_fd, KVM_SET_CPUID2, cpuid) < 0) {
        perror("KVM_SET_CPUID2");
        return false;
      }
    }

    return setup_long_mode();
  }

  // Sets XCR0, which exists with XSAVE.  False if KVM rejects the value.
  bool set_xcr0(u64 value) {
    if (!host_has(feature::XSAVE)) {
      errno = EINVAL;
      return value == 0x3;
    }
    struct kvm_xcrs xcrs = {};
    xcrs.nr_xcrs = 1;
    xcrs.xcrs[0].xcr = 0;
    xcrs.xcrs[0].value = value;
    return ioctl(vcpu_fd, KVM_SET_XCRS, &xcrs) == 0;
  }

  // The VM's long-mode setup.  False, with a message, if KVM rejects it.
  bool setup_long_mode() {
    memset(guest_mem, 0, GUEST_MEM_SIZE);
    // The guest cannot reach its page tables, below CODE_ADDR, so they are
    // written once; load_test rewrites the system tables for every case.
    write_page_tables(guest_mem, PML4_ADDR);
    write_system_tables(guest_mem);

    struct kvm_sregs sregs;
    if (ioctl(vcpu_fd, KVM_GET_SREGS, &sregs) < 0) {
      perror("KVM_GET_SREGS");
      return false;
    }

    sregs.cr0 = 0x80000011;  // PE + PG + ET (EM=0, TS=0 for SSE)
    sregs.cr4 = guest_cr4();
    sregs.efer = 0x500;      // LME + LMA
    sregs.cr3 = PML4_ADDR;

    sregs.gdt.base = GDT_ADDR;
    sregs.gdt.limit = 12 * 8 - 1;

    sregs.idt.base = IDT_ADDR;
    sregs.idt.limit = 32 * 16 - 1;

    // Code segment
    sregs.cs = {};
    sregs.cs.base = 0;
    sregs.cs.limit = 0xFFFFFFFF;
    sregs.cs.selector = 0x08;
    sregs.cs.type = 0xA;
    sregs.cs.present = 1;
    sregs.cs.s = 1;
    sregs.cs.l = 1;
    sregs.cs.g = 1;

    // Data segments
    auto setup_ds = [](struct kvm_segment &seg) {
      seg = {};
      seg.base = 0;
      seg.limit = 0xFFFFFFFF;
      seg.selector = 0x10;
      seg.type = 0x2;
      seg.present = 1;
      seg.db = 1;
      seg.s = 1;
      seg.g = 1;
    };
    setup_ds(sregs.ds);
    setup_ds(sregs.es);
    setup_ds(sregs.fs);
    setup_ds(sregs.gs);
    setup_ds(sregs.ss);

    // Task Register — needed for privilege-level changes (RSP0 from TSS)
    sregs.tr = {};
    sregs.tr.base = TSS_ADDR;
    sregs.tr.limit = 103;
    sregs.tr.selector = 0x18;
    sregs.tr.type = 0xB;  // 64-bit TSS (busy)
    sregs.tr.present = 1;
    sregs.tr.s = 0;

    // No LDT, as in the model (LDTR_valid = false): a selector with TI = 1
    // is #GP.  The vCPU's reset LDTR is usable with base 0, and the guest
    // read its descriptors from address 0.
    sregs.ldt = {};
    sregs.ldt.type = 0x2;
    sregs.ldt.unusable = 1;

    if (ioctl(vcpu_fd, KVM_SET_SREGS, &sregs) < 0) {
      perror("KVM_SET_SREGS");
      return false;
    }
    if (!set_xcr0(guest_xcr0())) {
      fprintf(stderr, "KVM_SET_XCRS of XCR0 %#lx: %s\n", guest_xcr0(), strerror(errno));
      return false;
    }
    return true;
  }

  // A KVM ioctl that fails on the harness's own state: the environment, not
  // the case, is at fault, and the run cannot go on.
  [[noreturn]] static void environment_error(const char *what) {
    fprintf(stderr, "environment error: %s: %s\n", what, strerror(errno));
    abort();
  }

  // Loads the case into the VM.  Returns why the guest cannot take it
  // when KVM rejects a value the case sets (a CR4 or XCR0 bit, an MSR, a
  // register value), and an empty string otherwise.
  std::string load_test(const TestCase &tc) {
    write_system_tables(guest_mem);  // as the previous case may have left them

    // Restore the default XCR0, CR0 and CR4, which a previous test may have
    // changed ("mov cr0,rax sets TS" leaves CR0.TS set, and an SSE
    // instruction in a later case then raised #NM on KVM only).
    if (!set_xcr0(guest_xcr0()))
      environment_error("KVM_SET_XCRS (default XCR0)");

    struct kvm_sregs sregs_tmp;
    if (ioctl(vcpu_fd, KVM_GET_SREGS, &sregs_tmp) < 0)
      environment_error("KVM_GET_SREGS");
    sregs_tmp.cr0 = 0x80000011;  // PE + PG + ET, as in init and the model's start
    sregs_tmp.cr4 = guest_cr4();
    // TPR, as the model starts every run with it.  KVM on AMD also keeps a
    // guest's CR8 write in the VMCB, which this does not reach, so a
    // template that writes CR8 restores 0 itself.
    sregs_tmp.cr8 = 0;
    // Set CS based on processor mode
    if (tc.compat_mode) {
      sregs_tmp.cs.selector = 0x48;
      sregs_tmp.cs.l = 0;   // Not 64-bit
      sregs_tmp.cs.db = 1;  // 32-bit default operand/address size
    } else {
      sregs_tmp.cs.selector = 0x08;
      sregs_tmp.cs.l = 1;   // 64-bit
      sregs_tmp.cs.db = 0;
    }
    // Restore SS and the data segments to the flat kernel data segment
    // (a previous test may have changed them: IRET to user mode sets
    // SS.DPL=3, and segment-load tests leave DS/ES modified — visible to
    // compat-mode tests, which enforce limits.  The Sail side gets fresh
    // flat segments every test.)
    auto reset_data_seg = [](struct kvm_segment &seg) {
      seg = {};
      seg.base = 0;
      seg.limit = 0xFFFFFFFF;
      seg.selector = 0x10;
      seg.type = 0x2;
      seg.present = 1;
      seg.db = 1;
      seg.s = 1;
      seg.g = 1;
    };
    reset_data_seg(sregs_tmp.ss);
    reset_data_seg(sregs_tmp.ds);
    reset_data_seg(sregs_tmp.es);
    reset_data_seg(sregs_tmp.fs);
    reset_data_seg(sregs_tmp.gs);
    // Reset CR2 so a #PF in one test is not visible to the next.
    sregs_tmp.cr2 = 0;
    // EFER: LME + LMA, plus whatever the test loads (SCE for SYSCALL).
    sregs_tmp.efer = 0x500;
    for (auto [msr, value] : tc.msrs)
      if (msr == MSR_IA32_EFER) sregs_tmp.efer = value;
    if (tc.cr4_override)
      sregs_tmp.cr4 = tc.cr4_override;
    if (ioctl(vcpu_fd, KVM_SET_SREGS, &sregs_tmp) < 0)
      return std::format("KVM_SET_SREGS (CR4 {:#x}, EFER {:#x}): {}", (u64)sregs_tmp.cr4,
                         (u64)sregs_tmp.efer, strerror(errno));

    // The fast-call MSRs: zero unless the test loads them.  IA32_TSC_AUX
    // exists with RDTSCP or RDPID (SDM Vol.4 Table 2-2), and KVM refuses
    // it to a guest with neither.  With XFD (CPUID.(0DH,1):EAX[4]) the
    // guest has IA32_XFD and IA32_XFD_ERR (1C4H, 1C5H), which a test that
    // faults on XFD leaves set; they are zeroed as well.
    {
      bool tsc_aux = host_has(feature::RDTSCP) || host_has(feature::RDPID);
      struct {
        struct kvm_msrs hdr;
        struct kvm_msr_entry entries[sizeof(FAST_CALL_MSRS) / sizeof(u32) + 2];
      } msrs = {};
      for (u32 m : FAST_CALL_MSRS) {
        if (m == MSR_IA32_TSC_AUX && !tsc_aux) continue;
        kvm_msr_entry &e = msrs.entries[msrs.hdr.nmsrs++];
        e.index = m;
        for (auto [msr, value] : tc.msrs)
          if (msr == m) e.data = value;
      }
      if (host_has(feature::XFD)) {
        msrs.entries[msrs.hdr.nmsrs++].index = 0x1C4;
        msrs.entries[msrs.hdr.nmsrs++].index = 0x1C5;
      }
      for (auto [msr, value] : tc.msrs) {
        bool known = msr == MSR_IA32_EFER;
        for (u32 m : FAST_CALL_MSRS) known |= msr == m;
        if (!known) {
          fprintf(stderr, "test %s loads MSR %#x, which the harness does not reset\n",
                  tc.name.c_str(), msr);
          abort();
        }
        if (msr == MSR_IA32_TSC_AUX && !tsc_aux)
          return "loads IA32_TSC_AUX, which a guest without RDTSCP and RDPID lacks";
      }
      int set = ioctl(vcpu_fd, KVM_SET_MSRS, &msrs);
      if (set < 0)
        environment_error("KVM_SET_MSRS");
      if (set != (int)msrs.hdr.nmsrs) {
        const kvm_msr_entry &e = msrs.entries[set];
        for (auto [msr, value] : tc.msrs)
          if (msr == e.index)
            return std::format("KVM_SET_MSRS rejects MSR {:#x} = {:#x}", msr, value);
        errno = EINVAL;
        environment_error(std::format("KVM_SET_MSRS of MSR {:#x}", (u32)e.index).c_str());
      }
    }

    memset(guest_mem + CODE_ADDR, 0, 0x1000);
    memset(guest_mem + STACK_TOP - 0x1000, 0, 0x1000);  // no cross-test residue
    io_log.clear();

    memcpy(guest_mem + CODE_ADDR, tc.code.data(), tc.code.size());
    guest_mem[CODE_ADDR + tc.code.size()] = 0xF4;  // HLT

    fill_data_page(tc, guest_mem + DATA_ADDR);

    struct kvm_regs regs = {};
    regs.rax = tc.initial.rax;
    regs.rbx = tc.initial.rbx;
    regs.rcx = tc.initial.rcx;
    regs.rdx = tc.initial.rdx;
    regs.rsi = tc.initial.rsi;
    regs.rdi = tc.initial.rdi;
    regs.rbp = tc.initial.rbp;
    regs.rsp = tc.initial.rsp ? tc.initial.rsp : STACK_TOP;
    regs.r8  = tc.initial.r8;
    regs.r9  = tc.initial.r9;
    regs.r10 = tc.initial.r10;
    regs.r11 = tc.initial.r11;
    regs.r12 = tc.initial.r12;
    regs.r13 = tc.initial.r13;
    regs.r14 = tc.initial.r14;
    regs.r15 = tc.initial.r15;
    regs.rip = CODE_ADDR;
    regs.rflags = tc.initial.rflags | 0x2;

    if (ioctl(vcpu_fd, KVM_SET_REGS, &regs) < 0)
      return std::format("KVM_SET_REGS: {}", strerror(errno));

    struct kvm_debugregs dbg = {};
    for (int i = 0; i < 4; i++) dbg.db[i] = tc.initial.dr[i];
    dbg.dr6 = tc.initial.dr6;
    dbg.dr7 = tc.initial.dr7;
    if (ioctl(vcpu_fd, KVM_SET_DEBUGREGS, &dbg) < 0)
      return std::format("KVM_SET_DEBUGREGS (DR6 {:#x}, DR7 {:#x}): {}", (u64)dbg.dr6,
                         (u64)dbg.dr7, strerror(errno));

    // Set XMM registers, MXCSR, and x87 state via XSAVE, for the components
    // of the default XCR0 (a case's state of the others is zero:
    // without_absent_state).  Components absent from XSTATE_BV (here the
    // AMX tiles, 17 and 18) return to their initial configuration, so no
    // tile state survives a test.
    std::vector<u8> xsave_buf(xsave_size, 0);
    u8 *xs = xsave_buf.data();
    // x87 state: FCW=0x037F (default), FSW=0, FTW=0xFF (all empty)
    u16 fcw = 0x037F;
    memcpy(xs + 0, &fcw, 2);     // FCW
    // FSW at offset 2 = 0 (TOP=0, all flags clear) — already zero from memset
    // Abridged FTW: 0 = empty, 1 = valid. 0x00 = all empty.
    // (Already zero from memset)
    // ST(0)-ST(7) at offset 32, 16 bytes stride — already zero from memset
    // MXCSR at offset 0x18
    memcpy(xs + 0x18, &tc.initial.mxcsr, 4);
    // XMM0-XMM15 low 128 bits at offset 0xA0 (16 bytes each)
    for (int i = 0; i < 16; i++)
      memcpy(xs + 0xA0 + i * 16, &tc.initial.xmm[i].q[0], 16);
    // The extended components sit at the host's CPUID-enumerated offsets.
    if (xl.ymm_hi128)
      for (int i = 0; i < 16; i++)
        memcpy(xs + xl.ymm_hi128 + i * 16, &tc.initial.xmm[i].q[2], 16);
    if (xl.opmask)
      for (int i = 0; i < 8; i++)
        memcpy(xs + xl.opmask + i * 8, &tc.initial.kregs[i], 8);
    if (xl.zmm_hi256)
      for (int i = 0; i < 16; i++)
        memcpy(xs + xl.zmm_hi256 + i * 32, &tc.initial.xmm[i].q[4], 32);
    if (xl.hi16_zmm)
      for (int i = 0; i < 16; i++)
        memcpy(xs + xl.hi16_zmm + i * 64, &tc.initial.xmm[16 + i].q[0], 64);

    u64 xstate_bv = guest_xcr0();
    memcpy(xs + 0x200, &xstate_bv, 8);
    if (ioctl(vcpu_fd, KVM_SET_XSAVE, xs) < 0)
      return std::format("KVM_SET_XSAVE (MXCSR {:#x}): {}", tc.initial.mxcsr, strerror(errno));

    if (tc.xcr0_override && !set_xcr0(tc.xcr0_override))
      return std::format("KVM_SET_XCRS of XCR0 {:#x}: {}", tc.xcr0_override, strerror(errno));
    return "";
  }

  // Check if a KVM run resulted in a fault (HLT in exception handler area).
  bool check_kvm_fault(FaultInfo &fi) {
    struct kvm_regs regs;
    ioctl(vcpu_fd, KVM_GET_REGS, &regs);
    if (regs.rip > COMMON_HANDLER && regs.rip <= COMMON_HANDLER + 0x100) {
      fi.faulted = true;
      u64 vec_val;
      u64 err_val;
      u64 rip_val;
      memcpy(&vec_val, guest_mem + FAULT_INFO_ADDR, 8);
      memcpy(&err_val, guest_mem + FAULT_INFO_ADDR + 8, 8);
      memcpy(&rip_val, guest_mem + FAULT_INFO_ADDR + 16, 8);
      fi.vector = (int)vec_val;
      fi.error_code = err_val;
      fi.faulting_rip = rip_val;
      struct kvm_sregs sregs;
      ioctl(vcpu_fd, KVM_GET_SREGS, &sregs);
      fi.cr2 = sregs.cr2;
      struct kvm_debugregs dbg = {};
      ioctl(vcpu_fd, KVM_GET_DEBUGREGS, &dbg);
      fi.dr6 = dbg.dr6;
      fi.dr7 = dbg.dr7;
      memcpy(&fi.rflags_image, guest_mem + FAULT_INFO_ADDR + 24, 8);
      return true;
    }
    return false;
  }

  // Set when the guest reached a state KVM cannot cleanly continue from
  // (triple fault, entry failure).  The caller must re-init the VM before
  // running the next test.
  bool poisoned = false;

  // The guest's port accesses in the run, in the externals' packed form.
  std::vector<u64> io_log;

  // KVM_RUN, resuming across the exits that carry no guest-visible event:
  // without an in-kernel APIC, a CR8 write that lowers the TPR is reported
  // to user space (KVM_EXIT_SET_TPR) and the guest simply continues.  Port
  // I/O reaches user space as well: OUT data is logged, IN data is the
  // same function of the port that the model's externals return.
  void run_vcpu() {
    for (;;) {
      if (ioctl(vcpu_fd, KVM_RUN, 0) < 0) {
        perror("KVM_RUN");  // host API failure, not a divergence
        abort();
      }
      if (run->exit_reason == KVM_EXIT_SET_TPR) continue;
      if (run->exit_reason == KVM_EXIT_IO) {
        bool out = run->io.direction == KVM_EXIT_IO_OUT;
        u8 *data = (u8 *)run + run->io.data_offset;
        for (u32 i = 0; i < run->io.count; i++, data += run->io.size) {
          u32 value = 0;
          if (out) {
            memcpy(&value, data, run->io.size);
          } else {
            value = x86::x86_externals_port_in_value(run->io.port, run->io.size);
            memcpy(data, &value, run->io.size);
          }
          io_log.push_back((u64(out) << 63) | (u64(run->io.size) << 48) |
                           (u64(run->io.port) << 32) | value);
        }
        continue;
      }
      break;
    }
  }

  // Run the loaded test.  Returns false, with a description in *err, if
  // the run ended other than at HLT (a triple fault, an odd exit reason),
  // so the caller can count a failure instead of aborting the whole suite.
  // Otherwise sets *state, and *fault for a run that ended in the
  // exception handlers.
  bool run_test_any(ArchState *state, FaultInfo *fault, std::string *err) {
    run_vcpu();

    if (run->exit_reason != KVM_EXIT_HLT) {
      *err += std::format("KVM: unexpected exit reason {}\n", run->exit_reason);
      if (run->exit_reason == KVM_EXIT_SHUTDOWN)
        *err += "  (triple fault)\n";
      if (run->exit_reason == KVM_EXIT_FAIL_ENTRY)
        *err += std::format("  hardware_entry_failure_reason: {:#x}\n",
                (u64)run->fail_entry.hardware_entry_failure_reason);
      if (run->exit_reason == KVM_EXIT_INTERNAL_ERROR)
        *err += std::format("  suberror: {}\n", run->internal.suberror);
      poisoned = true;
      return false;
    }
    check_kvm_fault(*fault);
    *state = read_state();
    return true;
  }

  ArchState read_state() {
    struct kvm_regs regs;
    ioctl(vcpu_fd, KVM_GET_REGS, &regs);

    ArchState state = {
      .rax = regs.rax, .rbx = regs.rbx, .rcx = regs.rcx, .rdx = regs.rdx,
      .rsi = regs.rsi, .rdi = regs.rdi, .rbp = regs.rbp, .rsp = regs.rsp,
      .r8  = regs.r8,  .r9  = regs.r9,  .r10 = regs.r10, .r11 = regs.r11,
      .r12 = regs.r12, .r13 = regs.r13, .r14 = regs.r14, .r15 = regs.r15,
      .rip = regs.rip,
      .rflags = regs.rflags,
    };

    std::vector<u8> xsave_buf = get_xsave();
    u8 *xs = xsave_buf.data();
    memcpy(&state.mxcsr, xs + 0x18, 4);
    for (int i = 0; i < 16; i++)
      memcpy(&state.xmm[i].q[0], xs + 0xA0 + i * 16, 16);
    // A component the guest lacks reads as zeros, as the model, with the
    // same initial state (without_absent_state), leaves it.
    for (int i = 0; i < 32; i++)
      for (int q = i < 16 ? 2 : 0; q < 8; q++)
        state.xmm[i].q[q] = 0;
    state.kregs.fill(0);
    if (xl.ymm_hi128)
      for (int i = 0; i < 16; i++)
        memcpy(&state.xmm[i].q[2], xs + xl.ymm_hi128 + i * 16, 16);
    if (xl.opmask)
      for (int i = 0; i < 8; i++)
        memcpy(&state.kregs[i], xs + xl.opmask + i * 8, 8);
    {
      struct kvm_debugregs dbg = {};
      ioctl(vcpu_fd, KVM_GET_DEBUGREGS, &dbg);
      state.dr6 = dbg.dr6;
      state.dr7 = dbg.dr7;
    }
    if (xl.zmm_hi256)
      for (int i = 0; i < 16; i++)
        memcpy(&state.xmm[i].q[4], xs + xl.zmm_hi256 + i * 32, 32);
    if (xl.hi16_zmm)
      for (int i = 0; i < 16; i++)
        memcpy(&state.xmm[16 + i].q[0], xs + xl.hi16_zmm + i * 64, 64);
    // x87 from the legacy region, which the kernel fills with the initial
    // values when the component is in its initial configuration.
    memcpy(&state.fcw, xs + 0, 2);
    memcpy(&state.fsw, xs + 2, 2);
    state.ftw = xs[4];
    for (int i = 0; i < 8; i++)
      memcpy(state.st[i].data(), xs + 32 + i * 16, 10);
    return state;
  }

  // The guest's XSAVE image, through KVM_GET_XSAVE2 where the kernel has
  // it (needed for an image larger than struct kvm_xsave).
  std::vector<u8> get_xsave() {
    std::vector<u8> buf(xsave_size, 0);
    if (ioctl(vcpu_fd, have_xsave2 ? KVM_GET_XSAVE2 : KVM_GET_XSAVE, buf.data()) < 0) {
      perror(have_xsave2 ? "KVM_GET_XSAVE2" : "KVM_GET_XSAVE");  // host API failure, not a divergence
      abort();
    }
    return buf;
  }

  // One guest MSR through KVM_GET_MSRS.
  u64 read_msr(u32 index) {
    struct {
      struct kvm_msrs hdr;
      struct kvm_msr_entry entry;
    } msrs = {};
    msrs.hdr.nmsrs = 1;
    msrs.entry.index = index;
    if (ioctl(vcpu_fd, KVM_GET_MSRS, &msrs) != 1) {
      perror("KVM_GET_MSRS");  // host API failure, not a divergence
      abort();
    }
    return msrs.entry.data;
  }

  // The guest's AMX state from its XSAVE image: a component whose
  // XSTATE_BV bit is clear is in its initial configuration, all zeros.
  AmxState read_amx() {
    AmxState s;
    std::vector<u8> buf = get_xsave();
    u64 xstate_bv;
    memcpy(&xstate_bv, buf.data() + 0x200, 8);
    if ((xstate_bv & (1ULL << 17)) && xl.tilecfg)
      memcpy(s.tilecfg, buf.data() + xl.tilecfg, 64);
    if ((xstate_bv & (1ULL << 18)) && xl.tiledata)
      memcpy(s.tiles, buf.data() + xl.tiledata, sizeof(s.tiles));
    return s;
  }

  void read_pages(MemPages *pages) {
    memcpy(pages->data, guest_mem + DATA_ADDR, 0x1000);
    memcpy(pages->stack, guest_mem + STACK_TOP - 0x1000, 0x1000);
  }
};

// ---- Sail model execution ----

static void map_guest_page(u64 addr, size_t len) {
  void *p = mmap((void *)addr, len, PROT_READ | PROT_WRITE,
                 MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED_NOREPLACE, -1, 0);
  if (p == MAP_FAILED) {
    fprintf(stderr, "mmap failed at 0x%lx: %s\n", addr, strerror(errno));
    abort();
  }
}

// A model access to memory this process does not back would kill it, and
// every case after it with it; run_sail fails the case instead.
static sigjmp_buf *g_model_jump;
static void *g_model_fault_addr;

static void model_segv(int sig, siginfo_t *info, void *) {
  if (!g_model_jump) {
    signal(sig, SIG_DFL);
    raise(sig);
    return;
  }
  g_model_fault_addr = info->si_addr;
  siglongjmp(*g_model_jump, 1);
}

// The model's tile state in the layout of AmxState: TILECFG as its
// LDTILECFG image, tile t row r at tiles[t][r].
static AmxState sail_amx_state(x86::Model &model) {
  AmxState s;
  if (model.ztilecfg_palette != 0) {
    s.tilecfg[0] = model.ztilecfg_palette;
    s.tilecfg[1] = model.ztilecfg_start_row;
    for (int n = 0; n < 8; n++) {
      u16 colsb = model.ztilecfg_colsb.data[n];
      memcpy(s.tilecfg + 16 + 2 * n, &colsb, 2);
      s.tilecfg[48 + n] = model.ztilecfg_rows.data[n];
    }
  }
  for (int t = 0; t < 8; t++)
    for (int r = 0; r < 16; r++)
      zmm_to_bytes(model.zTMM.data[16 * t + r], s.tiles[t][r]);
  return s;
}

// The model as the machine the guest is: each feature register from the
// guest's CPUID bit (host_has), and the implementation's parameters, those
// the manuals leave to it, from the guest's CPUID values and the host's
// FXSAVE image.  Every feature the model has a register for is set here.
static void set_model_profile(x86::Model &m) {
  using namespace feature;
  m.zenable_features_v1(UNIT);  // every feature off
  m.zvendor = host_vendor();
  m.zhas_sse3 = host_has(SSE3);
  m.zhas_ssse3 = host_has(SSSE3);
  m.zhas_sse4_1 = host_has(SSE4_1);
  m.zhas_sse4_2 = host_has(SSE4_2);
  m.zhas_crc32 = host_has(SSE4_2);
  m.zhas_cx16 = host_has(CX16);
  m.zhas_popcnt = host_has(POPCNT);
  m.zhas_lzzcnt = host_has(LZCNT);
  m.zhas_bmi1 = host_has(BMI1);
  m.zhas_bmi2 = host_has(BMI2);
  m.zhas_fma = host_has(FMA);
  m.zhas_aesni = host_has(AESNI);
  m.zhas_pclmulqdq = host_has(PCLMULQDQ);
  // Qualified: GFNI, VAES and VPCLMULQDQ are also Avx512Features.
  m.zhas_vpclmulqdq = host_has(feature::VPCLMULQDQ);
  m.zhas_vaes = host_has(feature::VAES);
  m.zhas_gfni = host_has(feature::GFNI);
  m.zhas_avx_vnni = host_has(AVX_VNNI);
  m.zhas_f16c = host_has(F16C);
  m.zhas_movbe = host_has(MOVBE);
  m.zhas_adx = host_has(ADX);
  m.zhas_sha = host_has(SHA);
  m.zhas_rdrand = host_has(RDRAND);
  m.zhas_rdseed = host_has(RDSEED);
  m.zhas_rdpid = host_has(RDPID);
  m.zhas_movdiri = host_has(MOVDIRI);
  m.zhas_movdir64b = host_has(MOVDIR64B);
  m.zhas_enqcmd = host_has(ENQCMD);
  m.zhas_xsave = host_has(XSAVE);
  m.zhas_xsaveopt = host_has(XSAVEOPT);
  m.zhas_xsavec = host_has(XSAVEC);
  m.zhas_xgetbv1 = host_has(XGETBV1);
  m.zhas_xsaves = host_has(XSAVES);
  m.zhas_xfd = host_has(XFD);
  m.zhas_la57 = host_has(LA57);
  m.zhas_vmx = host_has(VMX);
  m.zhas_amx_tile = host_has_amx();
  m.zhas_amx_int8 = host_has_amx() && host_has(AMX_INT8);
  m.zhas_amx_bf16 = host_has_amx() && host_has(AMX_BF16);
  m.zhas_prefetchw = host_has(PREFETCHW);
  m.zhas_cldemote = host_has(CLDEMOTE);
  m.zhas_waitpkg = host_has(WAITPKG);
  m.zhas_ptwrite = host_has(PT) && host_has(PTWRITE);
  m.zhas_sse4a = host_has(SSE4A);
  m.zhas_misalignsse = host_has(MISALIGNSSE);
  m.zhas_smap = host_has(SMAP);
  set_avx512_features(m);
  // The x87 pointer rules (model/regs.sail); the fields of an x87 image
  // that each leaves open where it is 0 are masked (x87_env_undefined,
  // fxsave_x87_undefined).
  m.zhas_fdp_excptn_only = host_has(FDP_EXCPTN_ONLY);
  m.zhas_fcs_fds_deprecation = host_has(FCS_FDS_DEPRECATION);
  m.zhas_rstr_fp_err_ptrs = host_has(RSTR_FP_ERR_PTRS);

  // The state components, with the layout CPUID.(0DH,i) gives the
  // guest, and CR4.OSXSAVE as XSAVE allows it.
  m.zXCR0_SUPPORTED = guest_xcr0_supported();
  m.zXCR0 = guest_xcr0();
  for (unsigned i : {2, 5, 6, 7, 17, 18}) {
    if (!(guest_xcr0_supported() >> i & 1)) continue;
    std::array<u32, 4> d = guest_cpuid(0xD, i);
    m.zxsave_comp_sizze.data[i] = d[CPUID_EAX];
    m.zxsave_comp_offset.data[i] = d[CPUID_EBX];
    m.zxsave_comp_align.data[i] = d[CPUID_ECX] >> 1 & 1;
  }
  m.zMXCSR_MASK = host_mxcsr_mask();
}

ArchState run_sail(const TestCase &tc, MemPages *pages_out, FaultInfo *fault_out,
                   std::string *err, AmxState *amx_out = nullptr) {
  auto save_pages = [&] {
    memcpy(pages_out->data, (void *)DATA_ADDR, 0x1000);
    memcpy(pages_out->stack, (void *)(STACK_TOP - 0x1000), 0x1000);
  };
  // The externs compute in the host's floating-point environment, and set
  // its rounding mode only where they need MXCSR.RC; a previous run (or one
  // its exception cut short) must not leave a mode this one does not have.
  fesetround(FE_TONEAREST);
  feclearexcept(FE_ALL_EXCEPT);
  x86::Model model;
  model.model_init();
  model.zinitializze_registers(UNIT);
  set_model_profile(model);
  // XCR0 as the guest starts every test; a test's override, below, may
  // add the AMX components.
  model.zXCR0 = guest_xcr0();
  model.zcur_mode = tc.compat_mode ? x86::zCompatibilityMode : x86::zLongMode;
  model.zcur_cpl = 0;

  // Set up segment descriptor caches.
  // In compatibility mode, CS.D=1 for 32-bit default operand/address size.
  // In long mode, CS.L=1 and CS.D=0 (SDM Vol.3A §3.4.5).
  // All segments get flat 4GB limits (base=0, limit=0xFFFFFFFF, present).
  for (int i = 0; i < 6; i++) {
    model.zSegCache.data[i].zseg_base = 0;
    model.zSegCache.data[i].zseg_limit = 0xFFFFFFFF;
    model.zSegCache.data[i].zseg_present = 1;
    model.zSegCache.data[i].zseg_s = 1;
    model.zSegCache.data[i].zseg_g = 1;
    model.zSegCache.data[i].zseg_db = 1;
  }
  if (tc.compat_mode) {
    model.zSegCache.data[x86::SEG_CS].zseg_l = 0;
  } else {
    model.zSegCache.data[x86::SEG_CS].zseg_db = 0;
    model.zSegCache.data[x86::SEG_CS].zseg_l = 1;
  }
  // Visible selectors as KVM loads them: CS 0x08 (0x48 in compatibility
  // mode), every other segment the flat data segment 0x10.  Instructions
  // that read a selector (MOV r/m,Sreg; PUSH seg) compare against these.
  for (int i = 0; i < 6; i++)
    model.zSegReg.data[i] = 0x10;
  model.zSegReg.data[x86::SEG_CS] = tc.compat_mode ? 0x48 : 0x08;
  model.zCR4 = guest_cr4();

  // The model reaches guest memory at the same addresses in this process.
  // Back all that the guest maps, its 2MB from CODE_ADDR: the test's pages,
  // the system tables, the model's page tables, and whatever else a
  // variant's operand reaches.
  static bool pages_mapped = false;
  if (!pages_mapped) {
    map_guest_page(CODE_ADDR, 0x200000 - CODE_ADDR);
    pages_mapped = true;
  }

  // Write test code + HLT
  memset((void *)CODE_ADDR, 0, 0x1000);
  memcpy((void *)CODE_ADDR, tc.code.data(), tc.code.size());
  u8 hlt = 0xF4;
  memcpy((void *)(CODE_ADDR + tc.code.size()), &hlt, 1);

  fill_data_page(tc, (u8 *)DATA_ADDR);

  // Clear the stack page so no state leaks from the previous test
  // (mirrors the KVM-side reset in load_test).
  memset((void *)(STACK_TOP - 0x1000), 0, 0x1000);

  // GPR order: RAX=0, RCX=1, RDX=2, RBX=3, RSP=4, RBP=5, RSI=6, RDI=7, R8-R15=8-15
  model.zGPR.data[0]  = tc.initial.rax;
  model.zGPR.data[1]  = tc.initial.rcx;
  model.zGPR.data[2]  = tc.initial.rdx;
  model.zGPR.data[3]  = tc.initial.rbx;
  model.zGPR.data[4]  = tc.initial.rsp ? tc.initial.rsp : STACK_TOP;
  model.zGPR.data[5]  = tc.initial.rbp;
  model.zGPR.data[6]  = tc.initial.rsi;
  model.zGPR.data[7]  = tc.initial.rdi;
  model.zGPR.data[8]  = tc.initial.r8;
  model.zGPR.data[9]  = tc.initial.r9;
  model.zGPR.data[10] = tc.initial.r10;
  model.zGPR.data[11] = tc.initial.r11;
  model.zGPR.data[12] = tc.initial.r12;
  model.zGPR.data[13] = tc.initial.r13;
  model.zGPR.data[14] = tc.initial.r14;
  model.zGPR.data[15] = tc.initial.r15;
  model.zRIP = CODE_ADDR;

  model.zwrite_rflags(tc.initial.rflags);
  model.zRF = (tc.initial.rflags >> 16) & 1;  // write_rflags deliberately preserves RF

  // Debug registers, as the KVM guest gets them through KVM_SET_DEBUGREGS
  model.zDR0 = tc.initial.dr[0];
  model.zDR1 = tc.initial.dr[1];
  model.zDR2 = tc.initial.dr[2];
  model.zDR3 = tc.initial.dr[3];
  model.zDR6 = tc.initial.dr6;
  model.zDR7 = tc.initial.dr7;

  // The guest's GDT, TSS, IDT and handlers, at its addresses
  write_system_tables(nullptr);
  model.zGDTR_base = GDT_ADDR;
  model.zGDTR_limit = 12 * 8 - 1;
  model.zTR_base = TSS_ADDR;

  // Initialize x87 FPU to default state (CW=0x037F, etc.)
  model.zx87_init(UNIT);

  // The guest runs with EFER.LME and LMA; far transfers and the fast system
  // calls consult them.  A test's MSRs override EFER and fill the externals'
  // MSR store, which is empty otherwise.
  model.zEFER = 0x500;
  x86::x86_externals_reset_msrs();
  x86::x86_externals_reset_port_io();
  for (auto [msr, value] : tc.msrs) {
    if (msr == MSR_IA32_EFER) model.zEFER = value;
    else x86::x86_externals_set_msr(msr, value);
  }

  // System mode: the model delivers exceptions through the guest's IDT, and
  // its handlers record them at FAULT_INFO_ADDR and halt, as the guest's do.
  if (tc.system_mode) {
    model.zIDTR_base = IDT_ADDR;
    model.zIDTR_limit = 32 * 16 - 1;
    model.zsystem_mode = true;
  }

  // Set ZMM registers and MXCSR
  model.mxcsr_state.mxcsr = tc.initial.mxcsr;
  for (int i = 0; i < 32; i++) {
    u8 bytes[64];
    memcpy(bytes, &tc.initial.xmm[i].q[0], 64);
    RECREATE(lbits)(&model.zZMM.data[i]);
    bytes_to_zmm(&model.zZMM.data[i], bytes);
  }

  // Set k-registers (opmask)
  for (int i = 0; i < 8; i++)
    model.zKREG.data[i] = tc.initial.kregs[i];

  // Apply per-test XCR0/CR4 overrides
  if (tc.xcr0_override)
    model.zXCR0 = tc.xcr0_override;
  if (tc.cr4_override)
    model.zCR4 = tc.cr4_override;

  // Identity page tables for paging-enabled tests.  The KVM guest always
  // runs with paging on (long mode requires it) over an identity map of
  // the first 2MB less the pages below CODE_ADDR; tests that probe
  // translation and #PF enable the same mapping in the model, so both
  // sides translate — and fault — on the same addresses.
  if (tc.enable_paging) {
    write_page_tables(nullptr, SAIL_PML4_ADDR);  // fresh tables (A/D bits)
    model.zCR3 = SAIL_PML4_ADDR;
    model.zCR0 = 0x80000011;  // PG + ET + PE, as in the KVM guest; EFER.LME + LMA above
  }

  static bool segv_handler = false;
  if (!segv_handler) {
    struct sigaction sa = {};
    sa.sa_sigaction = model_segv;
    sa.sa_flags = SA_SIGINFO | SA_NODEFER;
    sigaction(SIGSEGV, &sa, nullptr);
    sigaction(SIGBUS, &sa, nullptr);
    segv_handler = true;
  }
  sigjmp_buf jump;
  if (sigsetjmp(jump, 1)) {
    g_model_jump = nullptr;
    *err += std::format("Sail: access at {}, which this process does not back\n",
                        g_model_fault_addr);
    // This process backs all that the guest maps, so an access it does not
    // back is a #PF in the guest, which the model raises only when it
    // translates.
    if (!tc.enable_paging)
      *err += "  (not mapped in the guest either: the model translates, and raises\n"
              "   the #PF the guest takes, only for a test with enable_paging)\n";
    return {};
  }

  // The vector and opmask registers, which a run that faults compares as
  // well (compare_vector_state).
  auto read_vector_state = [&](ArchState &s) {
    for (int i = 0; i < 32; i++) {
      u8 bytes[64];
      zmm_to_bytes(model.zZMM.data[i], bytes);
      memcpy(&s.xmm[i].q[0], bytes, 64);
    }
    for (int i = 0; i < 8; i++)
      s.kregs[i] = model.zKREG.data[i];
  };

  for (int i = 0; i < 1000; i++) {
    g_model_jump = &jump;
    model.zstep(UNIT);
    g_model_jump = nullptr;
    if (model.zfault_pending) {
      i64 vec = model.zfault_vector;
      u32 err_code = model.zfault_error_code;
      if (fault_out) {
        fault_out->faulted = true;
        fault_out->vector = (int)vec;
        fault_out->error_code = err_code;
        fault_out->faulting_rip = model.zRIP;
        fault_out->cr2 = model.zCR2;
        fault_out->dr6 = model.zDR6;
        fault_out->dr7 = model.zDR7;
        // The RFLAGS the model would have pushed: its flags at the fault,
        // with RF as deliver_exception establishes it for the image.
        u64 img = 0x2;
        img |= (u64)model.zCF << 0;
        img |= (u64)model.zPF << 2;
        img |= (u64)model.zAF << 4;
        img |= (u64)model.zZF << 6;
        img |= (u64)model.zSF << 7;
        img |= (u64)model.zTF << 8;
        img |= (u64)model.zIF_flag << 9;
        img |= (u64)model.zDF << 10;
        img |= (u64)model.zOF << 11;
        img |= (u64)model.zRF << 16;
        fault_out->rflags_image = img;
        fault_out->xfd_err = model.zIA32_XFD_ERR;
        // A tile load or store that faults on a row keeps the rows done
        // and records the row in TILECFG.start_row.
        if (amx_out) *amx_out = sail_amx_state(model);
        save_pages();
        ArchState state;
        read_vector_state(state);
        model.model_fini();
        return state;
      }
      *err += std::format("Sail: unexpected fault #{} (error {:#x}) at RIP={:#x}\n",
                          vec, err_code, (u64)model.zRIP);
      *err += "  code bytes:";
      for (size_t j = 0; j < tc.code.size(); j++)
        *err += std::format(" {:02x}", tc.code[j]);
      *err += "\n";
      model.model_fini();
      return {};
    }
    if (model.zsystem_state == x86::zSysHalted) goto done;
  }
  *err += "Sail: did not reach HLT within 1000 steps\n";
  model.model_fini();
  return {};

done:
  // In system mode an exception ends in the common handler.
  if (tc.system_mode && model.zRIP > COMMON_HANDLER &&
      model.zRIP <= COMMON_HANDLER + 0x100) {
    u64 vec_val, err_val, rip_val, rflags_val;
    memcpy(&vec_val, (void *)FAULT_INFO_ADDR, 8);
    memcpy(&err_val, (void *)(FAULT_INFO_ADDR + 8), 8);
    memcpy(&rip_val, (void *)(FAULT_INFO_ADDR + 16), 8);
    memcpy(&rflags_val, (void *)(FAULT_INFO_ADDR + 24), 8);
    if (fault_out) {
      fault_out->faulted = true;
      fault_out->vector = (int)vec_val;
      fault_out->error_code = err_val;
      fault_out->faulting_rip = rip_val;
      fault_out->cr2 = model.zCR2;
      fault_out->dr6 = model.zDR6;
      fault_out->dr7 = model.zDR7;
      fault_out->rflags_image = rflags_val;
    } else {
      *err += std::format("Sail: unexpected fault #{} (error {:#x}) at RIP={:#x}\n",
                          (i64)vec_val, err_val, rip_val);
    }
    save_pages();
    ArchState state;
    read_vector_state(state);
    model.model_fini();
    return state;
  }

  u64 rflags = model.zread_rflags(UNIT);
  save_pages();

  ArchState state = {
    .rax = model.zGPR.data[0],
    .rbx = model.zGPR.data[3],
    .rcx = model.zGPR.data[1],
    .rdx = model.zGPR.data[2],
    .rsi = model.zGPR.data[6],
    .rdi = model.zGPR.data[7],
    .rbp = model.zGPR.data[5],
    .rsp = model.zGPR.data[4],
    .r8  = model.zGPR.data[8],
    .r9  = model.zGPR.data[9],
    .r10 = model.zGPR.data[10],
    .r11 = model.zGPR.data[11],
    .r12 = model.zGPR.data[12],
    .r13 = model.zGPR.data[13],
    .r14 = model.zGPR.data[14],
    .r15 = model.zGPR.data[15],
    .rip = model.zRIP,
    .rflags = rflags,
  };

  state.mxcsr = model.mxcsr_state.mxcsr;
  read_vector_state(state);
  state.dr6 = model.zDR6;
  state.dr7 = model.zDR7;
  // x87 in FXSAVE's terms: ST(i) is physical register (TOP + i) mod 8, and
  // a register is valid unless its two-bit tag is 11b (empty).
  state.fcw = model.zx87_cw;
  state.fsw = model.zx87_sw;
  state.ftw = 0;
  for (int i = 0; i < 8; i++)
    if (((model.zx87_tw >> (2 * i)) & 3) != 3) state.ftw |= 1 << i;
  for (int i = 0; i < 8; i++) {
    u8 bytes[64];
    zmm_to_bytes(model.zx87_ST.data[(((state.fsw >> 11) & 7) + i) & 7], bytes);
    memcpy(state.st[i].data(), bytes, 10);
  }
  if (amx_out) *amx_out = sail_amx_state(model);

  model.model_fini();
  return state;
}

// The templates, in suite order.  Each is a kvm-tests-*.cpp file; the name
// identifies the file a case came from in the KVM_LIST output.
struct Template {
  const char *file;
  void (*add)(std::vector<TestCase> &);
};
static const Template TEMPLATES[] = {
  {"kvm-tests-baseline.cpp", add_baseline_tests},
  {"kvm-tests-sse.cpp", add_sse_tests},
  {"kvm-tests-misc.cpp", add_misc_instruction_tests},
  {"kvm-tests-x87-avx.cpp", add_x87_avx_tests},
  {"kvm-tests-x87-compat.cpp", add_x87_compat_tests},
  {"kvm-tests-x87-cc.cpp", add_x87_cc_tests},
  {"kvm-tests-fp-edge.cpp", add_fp_edge_tests},
  {"kvm-tests-encoding.cpp", add_encoding_tests},
  {"kvm-tests-alu.cpp", add_systematic_tests},
  {"kvm-tests-exception.cpp", add_exception_tests},
  {"kvm-tests-mmx.cpp", add_mmx_tests},
  {"kvm-tests-features.cpp", add_feature_tests},
  {"kvm-tests-compat.cpp", add_compat_tests},
  {"kvm-tests-compat-avx.cpp", add_compat_avx_tests},
  {"kvm-tests-xsave.cpp", add_xsave_tests},
  {"kvm-tests-avx-fp.cpp", add_avx_fp_tests},
  {"kvm-tests-avx-int.cpp", add_avx_int_tests},
  {"kvm-tests-avx-shift.cpp", add_avx_shift_tests},
  {"kvm-tests-avx-fma.cpp", add_avx_fma_tests},
  {"kvm-tests-avx-scalar.cpp", add_avx_scalar_tests},
  {"kvm-tests-avx-narrow.cpp", add_avx_narrow_tests},
  {"kvm-tests-avx-cmp.cpp", add_avx_cmp_tests},
  {"kvm-tests-avx-perm.cpp", add_avx_perm_tests},
  {"kvm-tests-avx-conv.cpp", add_avx_conv_tests},
  {"kvm-tests-avx-special.cpp", add_avx_special_tests},
  {"kvm-tests-avx-mov.cpp", add_avx_mov_tests},
  {"kvm-tests-avx-vex.cpp", add_avx_vex_only_tests},
  {"kvm-tests-avx-hi16.cpp", add_avx_hi16_tests},
  {"kvm-tests-system.cpp", add_system_tests},
  {"kvm-tests-hints.cpp", add_hint_tests},
  {"kvm-tests-waitpkg.cpp", add_waitpkg_tests},
  {"kvm-tests-cr0.cpp", add_cr0_tests},
  // AVX-512 FP16 (CPUID.(7,0):EDX[23]), whose cases run where the host has
  // it (Suite::host_runs), and Intel AMX (EDX[24]), whose template
  // constructs nothing on a host without it.  Kept last so the suite order
  // is the same on hosts with and without them.
  {"kvm-tests-avx-fp16.cpp", add_avx_fp16_tests},
  {"kvm-tests-amx.cpp", add_amx_tests},
};

// The cases this run selects.  A prefix argument and KVM_FILTERS=
// "prefix1;prefix2" (for bisecting interactions between tests) each select
// the categories that start with one of their prefixes; --category=NAME
// selects one category exactly, and --slice=K/N every Nth of the selected
// cases from the Kth on, which is how ctest runs the suite (see
// write_ctest_file).
static const char *g_filter;
static std::vector<std::string> g_filters;
static std::string g_category;
static unsigned g_slice = 0, g_slices = 1;
// --template=FILE (repeatable) constructs only the cases of those template
// files, which is all a run of their categories needs; variants need all.
static std::vector<std::string> g_templates;

static bool wanted_category(const std::string &category) {
  if (!g_category.empty() && category != g_category)
    return false;
  if (g_filter && category.compare(0, strlen(g_filter), g_filter) != 0)
    return false;
  if (g_filters.empty()) return true;
  for (const auto &f : g_filters)
    if (category.compare(0, f.size(), f) == 0) return true;
  return false;
}

// The templates' cases, built for each register fill.
struct Suite {
  std::vector<TestCase> tests;
  std::vector<const char *> origins;  // per case, the template file

  // Of the cases the templates construct, per Avx512Feature, those that
  // need it and those not run because the host lacks it, and per extension
  // the model does not implement, those not run because the host has it.
  std::array<size_t, AVX512_FEATURES> avx512_cases{}, avx512_not_run{};
  std::vector<std::pair<std::string, size_t>> unimplemented_not_run;

  // Whether the host runs a constructed case, counted as above.
  bool host_runs(const TestCase &tc) {
    u32 needs = avx512_case_features(tc);
    bool runs = true;
    for (unsigned f = 0; f < AVX512_FEATURES; f++) {
      if (!(needs >> f & 1)) continue;
      avx512_cases[f]++;
      if (!host_has(Avx512Feature(f))) {
        avx512_not_run[f]++;
        runs = false;
      }
    }
    if (const char *ext = host_unimplemented_extension(tc)) {
      auto it = std::find_if(unimplemented_not_run.begin(), unimplemented_not_run.end(),
                             [&](const auto &p) { return p.first == ext; });
      if (it == unimplemented_not_run.end())
        unimplemented_not_run.push_back({ext, 1});
      else
        it->second++;
      runs = false;
    }
    return runs;
  }

  // The variants of the cases (kvm-variants.cpp) that the run selects,
  // passed to fn one at a time: there are far more than a run needs.
  void for_each_variant(const std::function<void(TestCase &&)> &fn) const {
    ::for_each_variant(tests, wanted_category, fn);
  }
};

Suite build_suite() {
  Suite s;
  // Rebuild the inputs rather than replacing zero-valued fields afterward:
  // a test may deliberately supply zero as an operand or an exception trigger.
  for (u64 fill : {u64(0), ~u64(0)}) {
    initial_register_fill = fill;
    size_t first = s.tests.size();
    for (const Template &t : TEMPLATES) {
      if (!g_templates.empty() &&
          std::find(g_templates.begin(), g_templates.end(), t.file) == g_templates.end())
        continue;
      t.add(s.tests);
      s.origins.resize(s.tests.size(), t.file);
    }
    // A case of instructions the host does not run as the model does.
    size_t kept = first;
    for (size_t i = first; i < s.tests.size(); i++) {
      if (!s.host_runs(s.tests[i])) continue;
      if (kept != i) {
        s.tests[kept] = std::move(s.tests[i]);
        s.origins[kept] = s.origins[i];
      }
      kept++;
    }
    s.tests.resize(kept);
    s.origins.resize(kept);
    for (size_t i = first; i < s.tests.size(); i++)
      s.tests[i].name += fill ? " [initial fill=ones]" : " [initial fill=zero]";
  }
  initial_register_fill = 0;
  std::string not_run;
  for (unsigned f = 0; f < AVX512_FEATURES; f++)
    if (s.avx512_not_run[f])
      not_run += std::format(" {} ({})", avx512_feature_name(Avx512Feature(f)),
                             s.avx512_not_run[f]);
  if (!not_run.empty())
    fprintf(stderr, "Cases not run, the host lacks:%s\n", not_run.c_str());
  not_run.clear();
  for (const auto &[ext, n] : s.unimplemented_not_run)
    not_run += std::format(" {} ({})", ext, n);
  if (!not_run.empty())
    fprintf(stderr, "Cases not run, the host has what the model does not implement:%s\n",
            not_run.c_str());
  return s;
}

// KVM_LIST=<path>: write one tab-separated line per constructed case and
// exit without creating a VM or running the model.  The set of cases is the
// one this host would run: templates consult CPUID while constructing, and
// build_suite drops the cases of AVX-512 features the host lacks, so a case
// a host cannot run (AVX-512 FP16, VAES, AVX-VNNI, ...) is never listed.
// The header comments record the host so a listing can be told apart from
// one made elsewhere, and how many cases need each AVX-512 feature.  The
// selected categories are listed (wanted_category), by default all.
static int list_tests(const char *path) {
  Suite suite = build_suite();
  std::string body;
  size_t count = 0;
  auto list = [&](const TestCase &tc, const char *origin) {
    if (!wanted_category(tc.category)) return;
    // The fill is the suffix build_suite appended; print it as its own
    // column and strip it from the name.
    std::string name = tc.name;
    const char *fill = "zero";
    if (size_t p = name.rfind(" [initial fill="); p != std::string::npos) {
      if (name.compare(p, std::string::npos, " [initial fill=ones]") == 0) fill = "ones";
      name.erase(p);
    }
    for (char &ch : name)
      if (ch == '\t' || ch == '\n') ch = ' ';
    body += std::format("{}\t{}\t{}\t{}\t", origin, fill, tc.category, name);
    for (u8 byte : tc.code) body += std::format("{:02x}", byte);
    body += std::format("\t{:d}\t{:d}\t{}\t{}\t{:d}\t{:d}\t{:d}\t{:#x}\t{:d}\t{}\t{:#x}\t{:#x}\t",
                        tc.compat_mode, tc.expect_fault, tc.expected_vector,
                        tc.init_data.size(), tc.may_fault, tc.enable_paging, tc.system_mode,
                        tc.flags_mask, tc.approx_rel_tol != 0 || tc.approx_result_bits != 0,
                        tc.msrs.size(), tc.xcr0_override, tc.cr4_override);
    u32 needs = avx512_case_features(tc);
    const char *sep = "";
    for (unsigned f = 0; f < AVX512_FEATURES; f++)
      if (needs >> f & 1) {
        body += sep;
        body += avx512_feature_name(Avx512Feature(f));
        sep = ",";
      }
    body += "\n";
    count++;
  };
  for (size_t i = 0; i < suite.tests.size(); i++)
    list(suite.tests[i], suite.origins[i]);
  suite.for_each_variant([&](TestCase &&tc) { list(tc, "kvm-variants.cpp"); });

  FILE *out = strcmp(path, "-") == 0 ? stdout : fopen(path, "w");
  if (!out) {
    fprintf(stderr, "KVM_LIST: cannot open %s: %s\n", path, strerror(errno));
    return 1;
  }
  u32 a, b, c, d;
  char vendor[13] = {};
  __get_cpuid(0, &a, &b, &c, &d);
  memcpy(vendor + 0, &b, 4);
  memcpy(vendor + 4, &d, 4);
  memcpy(vendor + 8, &c, 4);
  fprintf(out, "# kvm_harness case listing: %zu cases (%zu per register fill)\n",
          count, count / 2);
  fprintf(out, "# host vendor: %s\n", vendor);
  fprintf(out, "# cases (of both fills, variants aside) that need each AVX-512 feature:");
  for (unsigned f = 0; f < AVX512_FEATURES; f++)
    fprintf(out, " %s %zu%s", avx512_feature_name(Avx512Feature(f)), suite.avx512_cases[f],
            host_has(Avx512Feature(f)) ? "" : " (not run: the host lacks it)");
  fprintf(out, "\n");
  for (const auto &[ext, n] : suite.unimplemented_not_run)
    fprintf(out, "# not run, of %s, which the host has and the model does not implement: %zu\n",
            ext.c_str(), n);
  fprintf(out, "template\tfill\tcategory\tname\tcode\tcompat_mode\texpect_fault\t"
               "expected_vector\tinit_data_len\tmay_fault\tenable_paging\t"
               "system_mode\tflags_mask\tapprox\tmsrs\txcr0_override\t"
               "cr4_override\tavx512_features\n");
  fwrite(body.data(), 1, body.size(), out);
  if (out != stdout) fclose(out);
  fprintf(stderr, "listed %zu cases to %s\n", count, path);
  return 0;
}

// What the cases the suite constructs, and the model's profile, depend on
// in the host: the guest's CPUID, the host's own for the same leaves (and
// leaf 14H, whose PTWRITE bit the guest gets from it), and MXCSR_MASK.  A
// hash of them, which the ctest script records (write_ctest_file) and
// kvm-tests.cmake compares with the host that runs ctest.
static u64 host_fingerprint() {
  u64 h = 0xcbf29ce484222325;  // FNV-1a
  auto mix = [&](u32 v) {
    for (int i = 0; i < 4; i++, v >>= 8) h = (h ^ (v & 0xFF)) * 0x100000001b3;
  };
  // The cases follow the guest's CPUID, host_has (the host's bits where
  // the guest has them), the leaves a template reads on the host itself
  // (07H and 14H) and MXCSR_MASK.  The host's other bits are left out, and
  // so are the fields that differ between its logical processors, which
  // KVM_GET_SUPPORTED_CPUID passes through from the one it runs on: the
  // initial APIC ID (01H:EBX[31:24]), the x2APIC ID (0BH and 1FH:EDX),
  // the core type (1AH:EAX) and the extended APIC, core and node IDs
  // (8000001EH).  They would change the fingerprint from run to run.
  for (const kvm_cpuid_entry2 &e : guest_cpuid_entries()) {
    std::array<u32, 4> guest = {e.eax, e.ebx, e.ecx, e.edx};
    switch (e.function) {
    case 0x1: guest[CPUID_EBX] &= 0x00FFFFFF; break;
    case 0xB: case 0x1F: guest[CPUID_EDX] = 0; break;
    case 0x1A: guest[CPUID_EAX] = 0; break;
    case 0x8000001E: guest = {}; break;
    }
    for (u32 v : {e.function, e.index, e.flags}) mix(v);
    std::array<u32, 4> host = host_cpuid(e.function, e.index);
    for (int r = 0; r < 4; r++) {
      mix(guest[r]);
      mix(host[r] & guest[r]);
    }
  }
  for (std::pair<u32, u32> leaf : {std::pair<u32, u32>{7, 0}, {7, 1}, {0x14, 0}})
    for (u32 v : host_cpuid(leaf.first, leaf.second)) mix(v);
  mix(host_mxcsr_mask());
  return h;
}

// KVM_CTEST=<path>: write the suite's ctest entries as a CTest script and
// exit.  Each category gets an entry that selects it exactly, split into
// slices of at most CTEST_SLICE cases so that no entry runs for more than a
// few seconds.  The build writes the script after linking the harness
// (kvm/CMakeLists.txt), so the entries follow the templates and variants
// with no list to keep in step, and each case runs in exactly one entry.
// The cases are those of this host: the script records its fingerprint,
// and ctest on a host with another has kvm-tests.cmake write the script
// anew.  Every entry is skipped (77) where KVM cannot run, and without
// /dev/kvm the script has a single entry, which is.
static int write_ctest_file(const char *path) {
  constexpr size_t CTEST_SLICE = 1500;
  Suite suite;
  if (!guest_cpuid_entries().empty())
    suite = build_suite();
  std::vector<std::string> categories;
  std::unordered_map<std::string, size_t> count;
  std::unordered_map<std::string, std::vector<std::string>> files;  // of a template's category
  auto add = [&](const TestCase &tc, const char *file) {
    if (count[tc.category]++ == 0) categories.push_back(tc.category);
    auto &f = files[tc.category];
    if (file && std::find(f.begin(), f.end(), file) == f.end()) f.push_back(file);
  };
  for (size_t i = 0; i < suite.tests.size(); i++) add(suite.tests[i], suite.origins[i]);
  suite.for_each_variant([&](TestCase &&tc) { add(tc, nullptr); });

  char exe[4096];
  ssize_t len = readlink("/proc/self/exe", exe, sizeof(exe) - 1);
  if (len < 0) {
    perror("readlink /proc/self/exe");
    return 1;
  }
  exe[len] = '\0';
  FILE *out = fopen(path, "w");
  if (!out) {
    fprintf(stderr, "KVM_CTEST: cannot open %s: %s\n", path, strerror(errno));
    return 1;
  }
  fprintf(out, "# Written by %s (KVM_CTEST).\n", exe);
  fprintf(out, "# host: %016lx\n", host_fingerprint());
  auto entry = [&](const std::string &test, const std::string &args) {
    fprintf(out, "add_test([==[%s]==] [==[%s]==]%s)\n", test.c_str(), exe, args.c_str());
    fprintf(out, "set_tests_properties([==[%s]==] PROPERTIES SKIP_RETURN_CODE 77)\n",
            test.c_str());
  };
  if (categories.empty())
    entry("kvm_unavailable", " [==[--check-kvm]==]");
  for (const std::string &cat : categories) {
    std::string name = "kvm_" + cat;
    for (char &ch : name)
      if (ch == ' ' || ch == '/') ch = '_';
    std::string templates;
    for (const std::string &f : files[cat]) templates += " [==[--template=" + f + "]==]";
    size_t slices = (count[cat] + CTEST_SLICE - 1) / CTEST_SLICE;
    for (size_t k = 0; k < slices; k++)
      entry(slices == 1 ? name : std::format("{}_{}of{}", name, k + 1, slices),
            std::format(" [==[--category={}]==] [==[--slice={}/{}]==]{}", cat, k, slices,
                        templates));
  }
  fclose(out);
  return 0;
}



// Compares the exceptions the two sides took.
static bool compare_faults(const TestCase &tc, KvmVm &vm, const FaultInfo &kvm_fault,
                           const FaultInfo &sail_fault) {
  bool ok = true;
  // IA32_XFD_ERR, which an XFD #NM loads (SDM Vol.1 §13.14).
  if (host_has(feature::XFD)) {
    u64 kvm_xfd_err = vm.read_msr(0x1C5);
    if (kvm_xfd_err != sail_fault.xfd_err) {
      fprintf(stderr, "  MISMATCH IA32_XFD_ERR: kvm=0x%lx sail=0x%lx\n",
              kvm_xfd_err, sail_fault.xfd_err);
      ok = false;
    }
  }
  if (kvm_fault.vector != sail_fault.vector) {
    fprintf(stderr, "  MISMATCH vector: kvm=%d sail=%d\n",
            kvm_fault.vector, sail_fault.vector);
    ok = false;
  }
  if ((kvm_fault.error_code ^ sail_fault.error_code) & ~tc.error_code_undefined) {
    fprintf(stderr, "  MISMATCH error_code: kvm=0x%lx sail=0x%lx\n",
            kvm_fault.error_code, sail_fault.error_code);
    ok = false;
  }
  if (kvm_fault.faulting_rip != sail_fault.faulting_rip) {
    fprintf(stderr, "  MISMATCH RIP: kvm=0x%lx sail=0x%lx\n",
            kvm_fault.faulting_rip, sail_fault.faulting_rip);
    ok = false;
  }
  if ((kvm_fault.dr6 ^ sail_fault.dr6) & DR6_CMP_MASK & ~tc.undefined.dr6) {
    fprintf(stderr, "  MISMATCH DR6: kvm=0x%lx sail=0x%lx\n",
            kvm_fault.dr6, sail_fault.dr6);
    ok = false;
  }
  if ((kvm_fault.rflags_image ^ sail_fault.rflags_image) & RFLAGS_IMAGE_MASK
      & ~tc.rflags_image_ignore) {
    fprintf(stderr, "  MISMATCH pushed RFLAGS: kvm=0x%lx sail=0x%lx\n",
            kvm_fault.rflags_image, sail_fault.rflags_image);
    ok = false;
  }
  if (kvm_fault.dr7 != sail_fault.dr7) {
    fprintf(stderr, "  MISMATCH DR7: kvm=0x%lx sail=0x%lx\n",
            kvm_fault.dr7, sail_fault.dr7);
    ok = false;
  }
  if (kvm_fault.cr2 != sail_fault.cr2) {
    fprintf(stderr, "  MISMATCH CR2: kvm=0x%lx sail=0x%lx\n",
            kvm_fault.cr2, sail_fault.cr2);
    ok = false;
  }
  if (tc.expected_vector >= 0 && kvm_fault.vector != tc.expected_vector) {
    fprintf(stderr, "  UNEXPECTED vector: got %d expected %d\n",
            kvm_fault.vector, tc.expected_vector);
    ok = false;
  }
  return ok;
}

void clear_undefined(ArchState &s, const UndefinedState &u, bool compat_mode) {
  u64 *gprs[16] = {&s.rax, &s.rcx, &s.rdx, &s.rbx, &s.rsp, &s.rbp, &s.rsi, &s.rdi,
                   &s.r8,  &s.r9,  &s.r10, &s.r11, &s.r12, &s.r13, &s.r14, &s.r15};
  for (int i = 0; i < 16; i++)
    *gprs[i] &= ~(u.gpr[i] | (compat_mode && i < 8 ? 0xFFFFFFFF00000000ULL : 0));
  for (int i = 0; i < 32; i++)
    for (int q = 0; q < 8; q++) s.xmm[i].q[q] &= ~u.zmm[i][q];
  for (int i = 0; i < 8; i++) s.kregs[i] &= ~u.kregs[i];
  s.fcw &= ~u.fcw;
  s.mxcsr &= ~u.mxcsr;
  s.dr6 &= ~u.dr6;
}

static void undefined_bytes(TestCase &tc, unsigned off, unsigned len, u8 bits = 0xFF) {
  for (unsigned i = 0; i < len; i++)
    tc.data_undefined.push_back({u16(off + i), bits});
}

void x87_cw_undefined(TestCase &tc, u16 off) {
  undefined_bytes(tc, off, 1, 0xC0);
  undefined_bytes(tc, off + 1, 1, 0xE0);
}

// Whether `open` leaves all of FOP, FIP, FCS, FDP and FDS open on this
// host: after FFREE and the like, and in an image of FXSAVE, or of XSAVE
// on a host without RstrFpErrPtrs, with FSW.ES = 0.
static bool x87_pointers_open(unsigned open) {
  return (open & (X87_FXSAVE_NO_ES | X87_STACK_CONTROL)) ||
         ((open & X87_XSAVE_NO_ES) && !host_has(feature::RSTR_FP_ERR_PTRS));
}

void x87_env_undefined(TestCase &tc, u16 off, unsigned open, bool o16) {
  // The reserved high halves of the FCW, FSW, FTW and FDS doublewords
  // ("Reserved, IGN", APM Vol.2 Figure 11-4).  The 16-bit format is all
  // words, with no reserved fields and no FOP.
  if (!o16)
    for (unsigned half : {0x02, 0x06, 0x0A, 0x1A})
      undefined_bytes(tc, off + half, 2);
  if (open & X87_CW_LOADED)
    x87_cw_undefined(tc, off);
  if ((open & X87_XSAVE_NO_ES) && host_has(feature::RSTR_FP_ERR_PTRS))
    open &= ~X87_XSAVE_NO_ES;  // XRSTOR loaded the pointers
  bool all = x87_pointers_open(open);
  bool selectors = !host_has(feature::FCS_FDS_DEPRECATION);
  if (all)
    undefined_bytes(tc, off + (o16 ? 0x06 : 0x0C), o16 ? 2 : 4);  // FIP
  if (!o16 && (all || (open & X87_NO_UNMASKED))) {
    undefined_bytes(tc, off + 0x12, 1);        // FOP[7:0]
    undefined_bytes(tc, off + 0x13, 1, 0x07);  // FOP[10:8]
  }
  if (selectors && (all || (open & (X87_LONG_MODE | X87_NO_DATA))))
    undefined_bytes(tc, off + (o16 ? 0x0C : 0x18), 2);  // FDS
  if (selectors && (all || (open & X87_LONG_MODE)))
    undefined_bytes(tc, off + (o16 ? 0x08 : 0x10), 2);  // FCS
  if (all || (open & X87_NO_DATA))
    undefined_bytes(tc, off + (o16 ? 0x0A : 0x14), o16 ? 2 : 4);  // FDP
}

void fxsave_x87_undefined(TestCase &tc, u16 off, unsigned open, bool w) {
  // Byte 5 is "Rsvd" in the SDM; "(Byte 05h contains the value 00h.)" in
  // the APM (Vol.2 p.363).  FOP bits 15:11 are reserved (SDM FXSAVE), as
  // are bytes 0Eh-0Fh and 16h-17h of the 32-bit format and the last six
  // bytes of each register (both manuals).
  undefined_bytes(tc, off + 0x05, 1);
  undefined_bytes(tc, off + 0x07, 1, 0xF8);
  if (!w) {
    undefined_bytes(tc, off + 0x0E, 2);
    undefined_bytes(tc, off + 0x16, 2);
  }
  for (unsigned i = 0; i < 8; i++) {
    undefined_bytes(tc, off + 0x20 + 16 * i + 10, 6);
    if (open & X87_MMX)
      undefined_bytes(tc, off + 0x20 + 16 * i + 8, 2);
  }
  if (open & X87_CW_LOADED)
    x87_cw_undefined(tc, off);
  // An XSAVE with RstrFpErrPtrs zeroes the pointer fields "if there is no
  // pending #MF" (APM Vol.2 §11.5.10).
  if ((open & X87_XSAVE_NO_ES) && host_has(feature::RSTR_FP_ERR_PTRS))
    return;
  bool all = x87_pointers_open(open);
  bool selectors = !w && !host_has(feature::FCS_FDS_DEPRECATION);
  if (all || (open & X87_NO_UNMASKED)) {
    undefined_bytes(tc, off + 0x06, 1);        // FOP[7:0]
    undefined_bytes(tc, off + 0x07, 1, 0x07);  // FOP[10:8]
  }
  if (all)
    undefined_bytes(tc, off + 0x08, w ? 8 : 4);  // FIP
  if (selectors && (all || (open & (X87_LONG_MODE | X87_NO_DATA))))
    undefined_bytes(tc, off + 0x14, 2);  // FDS
  if (selectors && (all || (open & X87_LONG_MODE)))
    undefined_bytes(tc, off + 0x0C, 2);  // FCS
  if (all || (open & X87_NO_DATA))
    undefined_bytes(tc, off + 0x10, w ? 8 : 4);  // FDP
}

enum class CaseResult { Pass, Deviation, Fail, Skip };

// The case without state in the vector components the guest's XCR0 lacks
// (bits 255:128 of YMM0-15 without AVX; bits 511:256, ZMM16-31 and the
// opmask registers without AVX-512), which the guest does not have and
// reads as zeros: the model starts with zeros there as well.  `copy`
// holds the case when it changes.
static const TestCase &without_absent_state(const TestCase &tc, TestCase &copy) {
  u64 x = guest_xcr0();
  if ((x & 0xE4) == 0xE4)
    return tc;
  copy = tc;
  for (int i = 0; i < 32; i++)
    for (int q = 0; q < 8; q++)
      if (!(i < 16 ? q < 2 || (q < 4 ? x & 0x4 : x & 0x40) : x & 0x80))
        copy.initial.xmm[i].q[q] = 0;
  if (!(x & 0x20))
    copy.initial.kregs.fill(0);
  return copy;
}

// Runs one case on both sides and compares the outcome: the exception for
// a run that faults, the architectural state for one that completes, and
// in either case the memory the run may have written.  A mismatch is a
// known deviation if `dev`, the case's entry for this host, covers it
// (KnownDeviation::model_outcome and host_outcome), and a failure
// otherwise; a harness or model error is always a failure.  A case whose
// state KVM rejects is skipped: the host cannot run it.
static CaseResult run_case(KvmVm &vm, const TestCase &orig, const KnownDeviation *dev) {
  TestCase copy;
  const TestCase &tc = without_absent_state(orig, copy);
  if (std::string why = vm.load_test(tc); !why.empty()) {
    fprintf(stderr, "CANNOT RUN on this host: %s (%s)\n", tc.name.c_str(), why.c_str());
    return CaseResult::Skip;
  }

  std::string err;
  ArchState kvm_state, sail_state;
  FaultInfo kvm_fault, sail_fault;
  MemPages kvm_mem, sail_mem;
  AmxState sail_amx;
  bool amx = test_has_amx(tc);
  bool fault_allowed = tc.expect_fault || tc.may_fault || !tc.allowed_outcomes.empty();

  if (!vm.run_test_any(&kvm_state, &kvm_fault, &err)) {
    bool covered = dev && dev->host_outcome == HOST_CANNOT_RUN;
    fprintf(stderr, "%s%s: %s\n", err.c_str(), covered ? "KNOWN DEVIATION" : "FAIL",
            tc.name.c_str());
    return covered ? CaseResult::Deviation : CaseResult::Fail;
  }
  vm.read_pages(&kvm_mem);
  sail_state = run_sail(tc, &sail_mem, fault_allowed ? &sail_fault : nullptr, &err,
                        amx ? &sail_amx : nullptr);
  for (auto [offset, bits] : tc.data_undefined) {
    kvm_mem.data[offset] &= ~bits;
    sail_mem.data[offset] &= ~bits;
  }

  bool ok = err.empty();
  if (kvm_fault.faulted && !fault_allowed) {
    fprintf(stderr, "  KVM: unexpected fault #%d (error %#lx) at RIP=%#lx\n",
            kvm_fault.vector, kvm_fault.error_code, kvm_fault.faulting_rip);
    ok = false;
  }
  if (tc.expect_fault && !kvm_fault.faulted) {
    fprintf(stderr, "  KVM: expected fault but none occurred\n");
    ok = false;
  }
  if (tc.expect_fault && !sail_fault.faulted && err.empty()) {
    fprintf(stderr, "  Sail: expected fault but none occurred\n");
    ok = false;
  }
  // A variant (may_fault) inherits its case's allowed outcomes, but its
  // encoding is another one, which may take an outcome outside them (an
  // undefined opcode under a prefix may be a defined instruction): there
  // the model's outcome is the expected one as for any variant, and the
  // allowed outcomes only let the two sides differ within them.
  auto outcome = [](const FaultInfo &f) { return f.faulted ? f.vector : -1; };
  auto allowed = [&](int o) { return std::ranges::count(tc.allowed_outcomes, o) > 0; };
  int kvm_out = outcome(kvm_fault), sail_out = outcome(sail_fault);
  bool open = !tc.allowed_outcomes.empty() && allowed(kvm_out) && allowed(sail_out);
  if (tc.may_fault && kvm_fault.faulted != sail_fault.faulted && !open && err.empty()) {
    fprintf(stderr, "  MISMATCH outcome: kvm %s, sail %s\n",
            kvm_fault.faulted ? "faulted" : "completed",
            sail_fault.faulted ? "faulted" : "completed");
    ok = false;
  }
  if (!tc.allowed_outcomes.empty() && err.empty()) {
    if (!open && !tc.may_fault) {
      fprintf(stderr, "  OUTCOME not allowed: kvm %d, sail %d (-1: completed)\n",
              kvm_out, sail_out);
      ok = false;
    } else if (open && kvm_out != sail_out) {
      return CaseResult::Pass;
    }
  }
  if (!err.empty())
    fprintf(stderr, "%s", err.c_str());

  bool differ = kvm_out != sail_out ||
                (kvm_fault.faulted && kvm_fault.faulting_rip != sail_fault.faulting_rip);
  auto fixed = [](int want, int got) { return want == ANY_OUTCOME || want == got; };
  bool covered = dev && err.empty() &&
                 ((dev->model_outcome == ANY_OUTCOME && dev->host_outcome == ANY_OUTCOME) ||
                  (differ && fixed(dev->model_outcome, sail_out) &&
                   fixed(dev->host_outcome, kvm_out)));
  const char *verdict = covered ? "KNOWN DEVIATION" : "FAIL";
  CaseResult mismatch = covered ? CaseResult::Deviation : CaseResult::Fail;

  if (ok && kvm_fault.faulted) {
    // The tile state a faulting tile load or store leaves behind.
    ok = compare_faults(tc, vm, kvm_fault, sail_fault);
    if (amx && !vm.read_amx().compare(sail_amx)) ok = false;
    clear_undefined(kvm_state, tc.undefined, tc.compat_mode);
    clear_undefined(sail_state, tc.undefined, tc.compat_mode);
    if (!compare_vector_state(kvm_state, sail_state)) ok = false;
    // The handlers push their frame on their own stack (IST1), so the
    // test's pages hold only what its instructions wrote.
    if (!compare_page("data", kvm_mem.data, sail_mem.data)) ok = false;
    if (!compare_page("stack", kvm_mem.stack, sail_mem.stack)) ok = false;
    if (!ok)
      fprintf(stderr, "%s: %s (kvm: #%d err=0x%lx rip=0x%lx, sail: #%d err=0x%lx rip=0x%lx)\n",
              verdict, tc.name.c_str(),
              kvm_fault.vector, kvm_fault.error_code, kvm_fault.faulting_rip,
              sail_fault.vector, sail_fault.error_code, sail_fault.faulting_rip);
    return ok ? CaseResult::Pass : mismatch;
  }

  if (ok) {
    clear_undefined(kvm_state, tc.undefined, tc.compat_mode);
    clear_undefined(sail_state, tc.undefined, tc.compat_mode);
    ok = kvm_state.compare(sail_state, tc.flags_mask, tc.approx_rel_tol,
                           tc.approx_elem_bits, tc.approx_result_bits, tc.approx_reg);
    if (amx && !vm.read_amx().compare(sail_amx)) ok = false;
    if (!compare_page("data", kvm_mem.data, sail_mem.data)) ok = false;
    if (!compare_page("stack", kvm_mem.stack, sail_mem.stack)) ok = false;
  }
  const std::vector<u64> &sail_io = x86::x86_externals_port_io();
  bool io_ok = vm.io_log == sail_io;
  if (!ok || !io_ok) {
    fprintf(stderr, "%s: %s\n", verdict, tc.name.c_str());
    kvm_state.print("KVM");
    sail_state.print("Sail");
    if (!io_ok) {
      fprintf(stderr, "  PORT I/O MISMATCH:\n");
      print_port_io("KVM ", vm.io_log);
      print_port_io("Sail", sail_io);
    }
    return mismatch;
  }
  return CaseResult::Pass;
}

// Exit status of a run that has nothing to compare: no KVM, or no case
// selected or runnable on this host.  ctest reports it as skipped
// (SKIP_RETURN_CODE in write_ctest_file).
static constexpr int EXIT_SKIP = 77;

int main(int argc, char **argv) {
  bool check_kvm = false;
  for (int i = 1; i < argc; i++) {
    std::string arg = argv[i];
    if (arg == "--host-fingerprint") {
      printf("%016lx\n", host_fingerprint());
      return 0;
    } else if (arg == "--check-kvm") {
      check_kvm = true;
    } else if (arg.starts_with("--category=")) {
      g_category = arg.substr(11);
    } else if (arg.starts_with("--template=")) {
      g_templates.push_back(arg.substr(11));
    } else if (arg.starts_with("--host-lacks=")) {
      if (!parse_avx512_feature(arg.substr(13), &g_host_lacks)) return 1;
    } else if (arg.starts_with("--model-lacks=")) {
      if (!parse_avx512_feature(arg.substr(14), &g_model_lacks)) return 1;
    } else if (arg.starts_with("--slice=")) {
      if (sscanf(argv[i] + 8, "%u/%u", &g_slice, &g_slices) != 2 || g_slice >= g_slices) {
        fprintf(stderr, "bad %s: expected --slice=K/N with K < N\n", argv[i]);
        return 1;
      }
    } else {
      g_filter = argv[i];
    }
  }
  if (const char *env = getenv("KVM_FILTERS")) {
    std::string s = env;
    size_t start = 0;
    while (start <= s.size()) {
      size_t end = s.find(';', start);
      if (end == std::string::npos) end = s.size();
      if (end > start) g_filters.push_back(s.substr(start, end - start));
      start = end + 1;
    }
  }

  if (const char *path = getenv("KVM_CTEST"))
    return write_ctest_file(path);

  print_host_identity();

  if (const char *path = getenv("KVM_LIST"))
    return list_tests(path);

  if (guest_cpuid_entries().empty()) {
    fprintf(stderr, "KVM is not available (/dev/kvm): nothing to run\n");
    return EXIT_SKIP;
  }
  if (check_kvm) {
    fprintf(stderr, "KVM is available, but the ctest entries were written without it: "
            "run ctest again to write them for this host\n");
    return 1;
  }
  auto vm = std::make_unique<KvmVm>();
  if (!vm->init()) {
    fprintf(stderr, "environment error: KVM rejects the harness's VM setup\n");
    return 1;
  }
  fprintf(stderr, "guest XCR0 %#lx, CR4 %#lx, MXCSR_MASK %#x\n", guest_xcr0_supported(),
          guest_cr4(), host_mxcsr_mask());

  Suite suite = build_suite();
  int passed = 0;
  int deviations = 0;
  int failed = 0;
  int skipped = 0;
  std::string last_cat;
  bool vm_lost = false;
  size_t selected = 0;

  auto run = [&](const TestCase &tc) {
    if (vm_lost || !wanted_category(tc.category) || selected++ % g_slices != g_slice)
      return;
    if (tc.category != last_cat) {
      last_cat = tc.category;
      fprintf(stderr, "Testing %s ...\n", last_cat.c_str());
    }
    // KVM_VERBOSE: name each case before it runs, to locate a case that
    // kills the process (the model reads guest memory through the host
    // address space).
    if (getenv("KVM_VERBOSE"))
      fprintf(stderr, "  case: %s\n", tc.name.c_str());
    const KnownDeviation *dev = known_deviation(tc.name);
    CaseResult result = run_case(*vm, tc, dev);
    if (result == CaseResult::Pass) {
      passed++;
    } else if (result == CaseResult::Deviation) {
      fprintf(stderr, "  (%s)\n", dev->reason);
      deviations++;
    } else if (result == CaseResult::Skip) {
      skipped++;
    } else {
      failed++;
    }

    // A triple fault or odd exit can leave the VCPU in a state KVM cannot
    // continue from; rebuild the VM so later tests start clean.
    if (vm->poisoned) {
      vm = std::make_unique<KvmVm>();
      if (!vm->init()) {
        fprintf(stderr, "Failed to re-initialize KVM VM after poisoned run\n");
        vm_lost = true;
      }
    }
  };
  for (const TestCase &tc : suite.tests)
    run(tc);
  suite.for_each_variant([&](TestCase &&tc) { run(tc); });
  if (vm_lost)
    return 1;

  fprintf(stderr, "%d passed, %d known deviations, %d failed out of %d tests",
          passed, deviations, failed, passed + deviations + failed);
  if (skipped)
    fprintf(stderr, "; %d the host cannot run", skipped);
  fprintf(stderr, "\n");
  if (failed > 0)
    return 1;
  return passed + deviations == 0 ? EXIT_SKIP : 0;
}
