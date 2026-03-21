// KVM-based SMM (System Management Mode) test.
//
// Injects an SMI into a KVM guest and dumps the SMRAM state save area
// to establish ground truth for the Sail model's SMM implementation.
//
// Usage: ./kvm_test_smm
//
// This test verifies the SMRAM state save map layout (SDM Table 34-3)
// by comparing the saved state against known register values.

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <linux/kvm.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef unsigned long long u64;

// Memory layout (all identity-mapped):
//   0x00000 - 0x00FFF  PML4
//   0x01000 - 0x01FFF  PDPT
//   0x02000 - 0x02FFF  PD
//   0x03000 - 0x03FFF  GDT
//   0x10000 - 0x10FFF  Test code
//   0x30000 - 0x3FFFF  SMRAM (default SMBASE=0x30000)
//     0x38000          SMI handler entry (SMBASE + 0x8000)
//     0x3FE00          State save area start (SMBASE + 0x8000 + 0x7E00)
static constexpr u64 MEM_SIZE     = 4 * 1024 * 1024;  // 4MB
static constexpr u64 PML4_ADDR    = 0x00000;
static constexpr u64 PDPT_ADDR    = 0x01000;
static constexpr u64 PD_ADDR      = 0x02000;
static constexpr u64 GDT_ADDR     = 0x03000;
static constexpr u64 CODE_ADDR    = 0x10000;
static constexpr u64 SMBASE       = 0x30000;
static constexpr u64 SMI_ENTRY    = SMBASE + 0x8000;     // SMI handler entry
static constexpr u64 STATE_BASE   = SMBASE + 0x8000;     // State save area base

// SMRAM state save offsets for Intel 64 (SDM Table 34-3)
// Offsets are relative to SMBASE + 0x8000
static constexpr u16 OFF_CR0      = 0x7FF8;
static constexpr u16 OFF_CR3      = 0x7FF0;
static constexpr u16 OFF_RFLAGS   = 0x7FE8;
static constexpr u16 OFF_EFER     = 0x7FE0;
static constexpr u16 OFF_RIP      = 0x7FD8;
static constexpr u16 OFF_DR6      = 0x7FD0;
static constexpr u16 OFF_DR7      = 0x7FC8;
static constexpr u16 OFF_TR_SEL   = 0x7FC4;
static constexpr u16 OFF_LDTR_SEL = 0x7FC0;
static constexpr u16 OFF_GS_SEL   = 0x7FBC;
static constexpr u16 OFF_FS_SEL   = 0x7FB8;
static constexpr u16 OFF_DS_SEL   = 0x7FB4;
static constexpr u16 OFF_SS_SEL   = 0x7FB0;
static constexpr u16 OFF_CS_SEL   = 0x7FAC;
static constexpr u16 OFF_ES_SEL   = 0x7FA8;
static constexpr u16 OFF_RDI      = 0x7F94;
static constexpr u16 OFF_RSI      = 0x7F8C;
static constexpr u16 OFF_RBP      = 0x7F84;
static constexpr u16 OFF_RSP      = 0x7F7C;
static constexpr u16 OFF_RBX      = 0x7F74;
static constexpr u16 OFF_RDX      = 0x7F6C;
static constexpr u16 OFF_RCX      = 0x7F64;
static constexpr u16 OFF_RAX      = 0x7F5C;
static constexpr u16 OFF_R8       = 0x7F54;
static constexpr u16 OFF_R9       = 0x7F4C;
static constexpr u16 OFF_R10      = 0x7F44;
static constexpr u16 OFF_R11      = 0x7F3C;
static constexpr u16 OFF_R12      = 0x7F34;
static constexpr u16 OFF_R13      = 0x7F2C;
static constexpr u16 OFF_R14      = 0x7F24;
static constexpr u16 OFF_R15      = 0x7F1C;
static constexpr u16 OFF_HALT     = 0x7F02;
static constexpr u16 OFF_IO_RESTART = 0x7F00;
static constexpr u16 OFF_SMM_REV  = 0x7EFC;
static constexpr u16 OFF_SMBASE   = 0x7EF8;

static u64 read_smram_u64(u8 *mem, u16 offset) {
  u64 val;
  memcpy(&val, mem + STATE_BASE + offset, 8);
  return val;
}

static u32 read_smram_u32(u8 *mem, u16 offset) {
  u32 val;
  memcpy(&val, mem + STATE_BASE + offset, 4);
  return val;
}

static u16 read_smram_u16(u8 *mem, u16 offset) {
  u16 val;
  memcpy(&val, mem + STATE_BASE + offset, 2);
  return val;
}

int main() {
  printf("SMM Test: Inject SMI, dump SMRAM state save area\n\n");

  // Open KVM
  int kvm_fd = open("/dev/kvm", O_RDWR | O_CLOEXEC);
  if (kvm_fd < 0) { perror("/dev/kvm"); return 1; }

  int vm_fd = ioctl(kvm_fd, KVM_CREATE_VM, 0UL);
  if (vm_fd < 0) { perror("KVM_CREATE_VM"); return 1; }

  // Allocate guest memory
  u8 *mem = (u8 *)mmap(nullptr, MEM_SIZE, PROT_READ | PROT_WRITE,
                        MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (mem == MAP_FAILED) { perror("mmap"); return 1; }
  memset(mem, 0, MEM_SIZE);

  struct kvm_userspace_memory_region region = {};
  region.slot = 0;
  region.guest_phys_addr = 0;
  region.memory_size = MEM_SIZE;
  region.userspace_addr = (u64)mem;
  if (ioctl(vm_fd, KVM_SET_USER_MEMORY_REGION, &region) < 0) {
    perror("KVM_SET_USER_MEMORY_REGION"); return 1;
  }

  // Check and enable SMM support
  int smm_cap = ioctl(kvm_fd, KVM_CHECK_EXTENSION, KVM_CAP_X86_SMM);
  if (smm_cap <= 0) {
    fprintf(stderr, "KVM_CAP_X86_SMM not supported\n");
    return 1;
  }
  printf("KVM SMM support: %s\n", smm_cap ? "yes" : "no");

  // Create vCPU
  int vcpu_fd = ioctl(vm_fd, KVM_CREATE_VCPU, 0UL);
  if (vcpu_fd < 0) { perror("KVM_CREATE_VCPU"); return 1; }

  int mmap_size = ioctl(kvm_fd, KVM_GET_VCPU_MMAP_SIZE, 0);
  struct kvm_run *run = (struct kvm_run *)mmap(nullptr, mmap_size,
    PROT_READ | PROT_WRITE, MAP_SHARED, vcpu_fd, 0);

  // Set up identity-mapped page tables (4-level, 2MB pages)
  u64 *pml4 = (u64 *)(mem + PML4_ADDR);
  pml4[0] = PDPT_ADDR | 0x03;
  u64 *pdpt = (u64 *)(mem + PDPT_ADDR);
  pdpt[0] = PD_ADDR | 0x03;
  u64 *pd = (u64 *)(mem + PD_ADDR);
  pd[0] = 0x0 | 0x83;  // 2MB page, present + writable + PS
  pd[1] = 0x200000 | 0x83;

  // GDT: null, code64, data
  u64 *gdt = (u64 *)(mem + GDT_ADDR);
  gdt[0] = 0;
  gdt[1] = 0x00AF9A000000FFFFULL;  // 64-bit code, DPL=0
  gdt[2] = 0x00CF92000000FFFFULL;  // 32-bit data, DPL=0

  // Test code: set known register values, then loop forever (JMP $)
  // The SMI will be injected while executing the loop.
  u8 *code = mem + CODE_ADDR;
  int p = 0;
  // mov rax, 0xDEADBEEF11111111
  code[p++] = 0x48; code[p++] = 0xB8;
  u64 rax_val = 0xDEADBEEF11111111ULL;
  memcpy(code + p, &rax_val, 8); p += 8;
  // mov rbx, 0x2222222222222222
  code[p++] = 0x48; code[p++] = 0xBB;
  u64 rbx_val = 0x2222222222222222ULL;
  memcpy(code + p, &rbx_val, 8); p += 8;
  // mov rcx, 0x3333333333333333
  code[p++] = 0x48; code[p++] = 0xB9;
  u64 rcx_val = 0x3333333333333333ULL;
  memcpy(code + p, &rcx_val, 8); p += 8;
  // mov rdx, 0x4444444444444444
  code[p++] = 0x48; code[p++] = 0xBA;
  u64 rdx_val = 0x4444444444444444ULL;
  memcpy(code + p, &rdx_val, 8); p += 8;
  // OUT 0x80, AL (port 0x80 = POST debug, causes KVM_EXIT_IO)
  code[p++] = 0xE6; code[p++] = 0x80;

  // SMI handler at SMBASE + 0x8000: just RSM (0F AA)
  // After SMI saves state, RSM restores it and returns to HLT
  mem[SMI_ENTRY]     = 0x0F;
  mem[SMI_ENTRY + 1] = 0xAA;  // RSM

  // Set up long mode
  struct kvm_sregs sregs;
  ioctl(vcpu_fd, KVM_GET_SREGS, &sregs);

  sregs.cr0 = 0x80050033;  // PE + MP + ET + NE + WP + PG
  sregs.cr3 = PML4_ADDR;
  sregs.cr4 = 0x00000620;  // PAE + OSFXSR + OSXMMEXCPT
  sregs.efer = 0x00000D01;  // SCE + LME + LMA + NXE

  sregs.cs.base = 0; sregs.cs.limit = 0xFFFFFFFF;
  sregs.cs.selector = 0x08; sregs.cs.type = 0x0B;
  sregs.cs.present = 1; sregs.cs.dpl = 0; sregs.cs.db = 0;
  sregs.cs.s = 1; sregs.cs.l = 1; sregs.cs.g = 1;

  auto setup_ds = [](struct kvm_segment &seg) {
    seg.base = 0; seg.limit = 0xFFFFFFFF;
    seg.selector = 0x10; seg.type = 0x03;
    seg.present = 1; seg.dpl = 0; seg.db = 1;
    seg.s = 1; seg.l = 0; seg.g = 1;
  };
  setup_ds(sregs.ds); setup_ds(sregs.es);
  setup_ds(sregs.fs); setup_ds(sregs.gs);
  setup_ds(sregs.ss);

  sregs.gdt.base = GDT_ADDR; sregs.gdt.limit = 0x1F;
  sregs.idt.base = 0; sregs.idt.limit = 0;

  ioctl(vcpu_fd, KVM_SET_SREGS, &sregs);

  // Set GPRs with known values
  struct kvm_regs regs = {};
  regs.rip = CODE_ADDR;
  regs.rsp = 0x1F000;
  regs.rflags = 0x2;
  ioctl(vcpu_fd, KVM_SET_REGS, &regs);

  // Run until OUT instruction (executes MOV instructions, then OUT)
  if (ioctl(vcpu_fd, KVM_RUN, 0) < 0) { perror("KVM_RUN"); return 1; }
  if (run->exit_reason != KVM_EXIT_IO) {
    fprintf(stderr, "Expected IO exit, got exit reason %d\n", run->exit_reason);
    if (run->exit_reason == KVM_EXIT_SHUTDOWN)
      fprintf(stderr, "  (triple fault / shutdown)\n");
    return 1;
  }

  // Verify registers are set
  ioctl(vcpu_fd, KVM_GET_REGS, &regs);
  printf("Pre-SMI state:\n");
  printf("  RIP=0x%llx RAX=0x%llx RBX=0x%llx\n", regs.rip, regs.rax, regs.rbx);
  printf("  RCX=0x%llx RDX=0x%llx RSP=0x%llx\n", regs.rcx, regs.rdx, regs.rsp);

  // Clear entire memory to 0xCC to detect what gets written by SMI
  // But preserve the test code, page tables, and GDT
  memset(mem + 0x20000, 0xCC, MEM_SIZE - 0x20000);

  // Place HLT at SMI entry point instead of RSM — just to verify SMI delivery
  for (u64 base = 0x20000; base < MEM_SIZE; base += 0x10000) {
    mem[base + 0x8000] = 0xF4;  // HLT (instead of RSM, to test SMI entry)
  }

  // Inject SMI
  printf("\nInjecting SMI...\n");
  if (ioctl(vcpu_fd, KVM_SMI, 0) < 0) {
    perror("KVM_SMI");
    return 1;
  }

  // Run — KVM will deliver the SMI, save state to SMRAM, jump to handler.
  // Our handler is just RSM, which restores state and returns.
  // After RSM, execution resumes and we should get another IO exit or HLT.
  int smm_result = ioctl(vcpu_fd, KVM_RUN, 0);
  if (smm_result < 0) {
    perror("KVM_RUN (SMM)");
    printf("(continuing to dump SMRAM despite error)\n");
  }

  printf("Exit reason after SMI+RSM: %d", run->exit_reason);
  if (run->exit_reason == KVM_EXIT_HLT) printf(" (HLT)\n");
  else if (run->exit_reason == KVM_EXIT_IO) printf(" (IO)\n");
  else if (run->exit_reason == KVM_EXIT_SHUTDOWN) printf(" (SHUTDOWN)\n");
  else if (run->exit_reason == KVM_EXIT_INTERNAL_ERROR)
    printf(" (INTERNAL_ERROR suberror=%d)\n", run->internal.suberror);
  else printf("\n");

  // Now dump the SMRAM state save area
  printf("\n=== SMRAM State Save Area (Intel 64 format) ===\n");
  printf("Offsets relative to SMBASE + 0x8000 = 0x%lx\n\n", (unsigned long)STATE_BASE);

  // Control registers
  printf("CR0      (7FF8h): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_CR0));
  printf("CR3      (7FF0h): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_CR3));
  printf("RFLAGS   (7FE8h): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_RFLAGS));
  printf("EFER     (7FE0h): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_EFER));
  printf("RIP      (7FD8h): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_RIP));
  printf("DR6      (7FD0h): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_DR6));
  printf("DR7      (7FC8h): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_DR7));

  // Segment selectors
  printf("\nSegment selectors (32-bit fields):\n");
  printf("TR SEL   (7FC4h): 0x%08x\n", read_smram_u32(mem, OFF_TR_SEL));
  printf("LDTR SEL (7FC0h): 0x%08x\n", read_smram_u32(mem, OFF_LDTR_SEL));
  printf("GS SEL   (7FBCh): 0x%08x\n", read_smram_u32(mem, OFF_GS_SEL));
  printf("FS SEL   (7FB8h): 0x%08x\n", read_smram_u32(mem, OFF_FS_SEL));
  printf("DS SEL   (7FB4h): 0x%08x\n", read_smram_u32(mem, OFF_DS_SEL));
  printf("SS SEL   (7FB0h): 0x%08x\n", read_smram_u32(mem, OFF_SS_SEL));
  printf("CS SEL   (7FACh): 0x%08x\n", read_smram_u32(mem, OFF_CS_SEL));
  printf("ES SEL   (7FA8h): 0x%08x\n", read_smram_u32(mem, OFF_ES_SEL));

  // GPRs
  printf("\nGeneral-purpose registers (64-bit):\n");
  printf("RAX      (7F5Ch): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_RAX));
  printf("RBX      (7F74h): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_RBX));
  printf("RCX      (7F64h): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_RCX));
  printf("RDX      (7F6Ch): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_RDX));
  printf("RSP      (7F7Ch): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_RSP));
  printf("RBP      (7F84h): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_RBP));
  printf("RSI      (7F8Ch): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_RSI));
  printf("RDI      (7F94h): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_RDI));
  printf("R8       (7F54h): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_R8));
  printf("R9       (7F4Ch): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_R9));
  printf("R10      (7F44h): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_R10));
  printf("R11      (7F3Ch): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_R11));
  printf("R12      (7F34h): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_R12));
  printf("R13      (7F2Ch): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_R13));
  printf("R14      (7F24h): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_R14));
  printf("R15      (7F1Ch): 0x%016llx\n", (unsigned long long)read_smram_u64(mem, OFF_R15));

  // SMM-specific fields
  printf("\nSMM fields:\n");
  printf("Auto HALT (7F02h): 0x%04x\n", read_smram_u16(mem, OFF_HALT));
  printf("IO Restart(7F00h): 0x%04x\n", read_smram_u16(mem, OFF_IO_RESTART));
  printf("SMM Rev   (7EFCh): 0x%08x\n", read_smram_u32(mem, OFF_SMM_REV));
  printf("SMBASE    (7EF8h): 0x%08x\n", read_smram_u32(mem, OFF_SMBASE));

  // Verify key values
  printf("\n=== Verification ===\n");
  int errors = 0;
  auto check = [&](const char *name, u64 got, u64 expected) {
    if (got != expected) {
      printf("FAIL: %s = 0x%llx, expected 0x%llx\n", name,
             (unsigned long long)got, (unsigned long long)expected);
      errors++;
    } else {
      printf("OK:   %s = 0x%llx\n", name, (unsigned long long)got);
    }
  };

  check("RAX", read_smram_u64(mem, OFF_RAX), rax_val);
  check("RBX", read_smram_u64(mem, OFF_RBX), rbx_val);
  check("RCX", read_smram_u64(mem, OFF_RCX), rcx_val);
  check("RDX", read_smram_u64(mem, OFF_RDX), rdx_val);
  check("CS SEL", read_smram_u32(mem, OFF_CS_SEL), 0x08);
  check("DS SEL", read_smram_u32(mem, OFF_DS_SEL), 0x10);
  check("SMBASE", read_smram_u32(mem, OFF_SMBASE), SMBASE);

  // Dump raw SMRAM hex for detailed analysis
  printf("\n=== Raw SMRAM dump (last 512 bytes of state save area) ===\n");
  for (int row = 0; row < 32; row++) {
    u16 off = 0x7E00 + row * 16;
    printf("  %04x: ", off);
    for (int col = 0; col < 16; col++)
      printf("%02x ", mem[STATE_BASE + off + col]);
    printf("\n");
  }

  printf("\n%d errors\n", errors);

  munmap(run, mmap_size);
  munmap(mem, MEM_SIZE);
  close(vcpu_fd);
  close(vm_fd);
  close(kvm_fd);
  return errors ? 1 : 0;
}
