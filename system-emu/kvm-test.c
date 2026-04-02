// Minimal KVM selftest for the Sail x86 system emulator.
//
// Creates a VM via /dev/kvm with a 64-bit long-mode guest. The guest
// has its own page tables (CR3 → PML4 → PDPT → PD) that map guest
// virtual addresses to guest physical addresses. KVM uses EPT to
// translate guest physical addresses to host physical addresses —
// this is the standard two-level address translation that real
// hypervisors use.
//
// Guest code at GVA 0x400000 (mapped to GPA 0x10000 via guest PTs):
//   out 0x10, al   → VM exit (I/O), KVM returns KVM_EXIT_IO
//   hlt            → VM exit (HLT), KVM returns KVM_EXIT_HLT
//
// Build: gcc -static -o kvm-test kvm-test.c
// Run inside the emulator's Linux: /bin/kvm-test

#include <fcntl.h>
#include <linux/kvm.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

// Guest physical memory layout (2MB, backed by host mmap):
//   GPA 0x00000 - page tables (PML4, PDPT, PD at 0x1000, 0x2000, 0x3000)
//   GPA 0x04000 - GDT
//   GPA 0x10000 - guest code (mapped at GVA 0x400000 by guest PTs)
//   GPA 0x1F000 - guest stack top (mapped at GVA 0x401000)
#define GUEST_MEM_SIZE  (2 * 1024 * 1024)

// Guest physical addresses
#define GPA_PML4   0x1000
#define GPA_PDPT   0x2000
#define GPA_PD     0x3000
#define GPA_GDT    0x4000
#define GPA_CODE   0x10000
#define GPA_DATA   0x18000
#define GPA_STACK  0x1F000

// Guest virtual addresses (non-identity-mapped)
// Guest PD[2] maps GVA 0x400000-0x5FFFFF → GPA 0x000000-0x1FFFFF
#define GVA_BASE   0x400000
#define GVA_DATA   (GVA_BASE + GPA_DATA)   // 0x418000
#define GVA_STACK  (GVA_BASE + GPA_STACK)  // 0x41F000

// Guest code (64-bit):
//   mov dword ptr [0x418000], 0xDEADBEEF  -> memory write via guest PTs + EPT
//   mov eax, dword ptr [0x418000]         -> memory read via guest PTs + EPT
//   out 0x10, al                          -> KVM_EXIT_IO (AL = 0xEF)
//   hlt                                   -> KVM_EXIT_HLT
static const uint8_t guest_code[] = {
    0xC7, 0x04, 0x25,                          // mov dword ptr [imm32], imm32
    (GVA_DATA >> 0) & 0xFF,                    //   address low
    (GVA_DATA >> 8) & 0xFF,
    (GVA_DATA >> 16) & 0xFF,
    (GVA_DATA >> 24) & 0xFF,                   //   address high
    0xEF, 0xBE, 0xAD, 0xDE,                    //   value = 0xDEADBEEF
    0x8B, 0x04, 0x25,                          // mov eax, dword ptr [imm32]
    (GVA_DATA >> 0) & 0xFF,
    (GVA_DATA >> 8) & 0xFF,
    (GVA_DATA >> 16) & 0xFF,
    (GVA_DATA >> 24) & 0xFF,
    0xE6, 0x10,                                // out 0x10, al (AL = 0xEF)
    0xF4,                                      // hlt
};

static void die(const char *msg) {
    perror(msg);
    exit(1);
}

// Set up guest page tables mapping:
//   GVA 0x400000 (2MB) → GPA 0x00000 (2MB page)
// This is a non-identity mapping: virtual != physical.
static void setup_guest_page_tables(uint8_t *mem) {
    uint64_t *pml4 = (uint64_t *)(mem + GPA_PML4);
    uint64_t *pdpt = (uint64_t *)(mem + GPA_PDPT);
    uint64_t *pd   = (uint64_t *)(mem + GPA_PD);

    memset(pml4, 0, 0x1000);
    memset(pdpt, 0, 0x1000);
    memset(pd,   0, 0x1000);

    // PML4[0] → PDPT (covers GVA 0x000000000 - 0x7FFFFFFFFF)
    pml4[0] = GPA_PDPT | 0x03;  // present + writable

    // PDPT[0] → PD (covers GVA 0x000000000 - 0x03FFFFFFF)
    pdpt[0] = GPA_PD | 0x03;

    // PD[2] → 2MB page at GPA 0x00000 (covers GVA 0x400000 - 0x5FFFFF)
    // This is the key non-identity mapping: GVA 0x400000 → GPA 0x00000
    pd[2] = 0x00000000 | 0x83;  // GPA 0, present + writable + PS (2MB)
}

// Set up a minimal GDT at GPA_GDT
static void setup_guest_gdt(uint8_t *mem) {
    uint64_t *gdt = (uint64_t *)(mem + GPA_GDT);
    gdt[0] = 0;                   // null descriptor
    gdt[1] = 0x00AF9A000000FFFFULL; // 64-bit code: L=1, D=0, P=1, S=1, type=0xA
    gdt[2] = 0x00CF92000000FFFFULL; // 64-bit data: D=1, P=1, S=1, type=0x2
}

static void setup_sregs(uint8_t *mem, struct kvm_sregs *sregs) {
    setup_guest_page_tables(mem);
    setup_guest_gdt(mem);

    sregs->cr3 = GPA_PML4;
    sregs->cr4 = (1UL << 5);                        // PAE
    sregs->cr0 = (1UL << 0) | (1UL << 5) | (1UL << 31); // PE + NE + PG
    sregs->efer = (1UL << 8) | (1UL << 10);         // LME + LMA

    // CS: 64-bit code segment (GDT entry 1, selector 0x08)
    sregs->cs.base = 0;
    sregs->cs.limit = 0xFFFFFFFF;
    sregs->cs.selector = 0x08;
    sregs->cs.type = 0xA;
    sregs->cs.present = 1;
    sregs->cs.dpl = 0;
    sregs->cs.db = 0;
    sregs->cs.s = 1;
    sregs->cs.l = 1;
    sregs->cs.g = 1;

    // Data segments (GDT entry 2, selector 0x10)
    struct kvm_segment data_seg = {
        .base = 0, .limit = 0xFFFFFFFF, .selector = 0x10,
        .type = 0x2, .present = 1, .dpl = 0, .db = 1, .s = 1, .l = 0, .g = 1,
    };
    sregs->ds = data_seg;
    sregs->es = data_seg;
    sregs->ss = data_seg;
    sregs->fs = data_seg;
    sregs->gs = data_seg;

    sregs->gdt.base = GPA_GDT;
    sregs->gdt.limit = 3 * 8 - 1;
    sregs->idt.base = 0;
    sregs->idt.limit = 0;
}

int main(void) {
    int kvm_fd, vm_fd, vcpu_fd;
    struct kvm_sregs sregs;
    struct kvm_regs regs;
    struct kvm_run *run;
    size_t run_size;
    uint8_t *mem;
    int ret;

    printf("=== KVM VMX Test ===\n");

    kvm_fd = open("/dev/kvm", O_RDWR);
    if (kvm_fd < 0) die("open /dev/kvm");

    ret = ioctl(kvm_fd, KVM_GET_API_VERSION, 0);
    if (ret < 0) die("KVM_GET_API_VERSION");
    printf("KVM API version: %d\n", ret);

    vm_fd = ioctl(kvm_fd, KVM_CREATE_VM, 0);
    if (vm_fd < 0) die("KVM_CREATE_VM");

    // Allocate guest physical memory
    mem = mmap(NULL, GUEST_MEM_SIZE, PROT_READ | PROT_WRITE,
               MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mem == MAP_FAILED) die("mmap");
    memset(mem, 0, GUEST_MEM_SIZE);

    // Place guest code at GPA_CODE. The guest PTs map
    // GVA 0x400000 → GPA 0x00000 (2MB page), so guest fetches
    // instructions from GVA (GVA_BASE + GPA_CODE) = 0x410000.
    memcpy(mem + GPA_CODE, guest_code, sizeof(guest_code));

    struct kvm_userspace_memory_region region = {
        .slot = 0,
        .guest_phys_addr = 0,
        .memory_size = GUEST_MEM_SIZE,
        .userspace_addr = (uint64_t)mem,
    };
    ret = ioctl(vm_fd, KVM_SET_USER_MEMORY_REGION, &region);
    if (ret < 0) die("KVM_SET_USER_MEMORY_REGION");

    vcpu_fd = ioctl(vm_fd, KVM_CREATE_VCPU, 0);
    if (vcpu_fd < 0) die("KVM_CREATE_VCPU");

    run_size = ioctl(kvm_fd, KVM_GET_VCPU_MMAP_SIZE, 0);
    if ((int)run_size < 0) die("KVM_GET_VCPU_MMAP_SIZE");
    run = mmap(NULL, run_size, PROT_READ | PROT_WRITE, MAP_SHARED, vcpu_fd, 0);
    if (run == MAP_FAILED) die("mmap vcpu");

    // Set up 64-bit long mode with guest page tables
    ret = ioctl(vcpu_fd, KVM_GET_SREGS, &sregs);
    if (ret < 0) die("KVM_GET_SREGS");
    setup_sregs(mem, &sregs);
    ret = ioctl(vcpu_fd, KVM_SET_SREGS, &sregs);
    if (ret < 0) die("KVM_SET_SREGS");

    // RIP = GVA_BASE + GPA_CODE = 0x410000 (→ GPA 0x10000 via guest PTs)
    memset(&regs, 0, sizeof(regs));
    regs.rip = GVA_BASE + GPA_CODE;
    regs.rsp = GVA_STACK;
    regs.rflags = 0x2;
    ret = ioctl(vcpu_fd, KVM_SET_REGS, &regs);
    if (ret < 0) die("KVM_SET_REGS");

    printf("Guest: 64-bit, RIP=0x%llx (GVA→GPA 0x%x)\n",
           (unsigned long long)regs.rip, GPA_CODE);

    // Run the guest
    int exits = 0;
    int pass = 1;
    while (1) {
        ret = ioctl(vcpu_fd, KVM_RUN, 0);
        if (ret < 0) {
            perror("KVM_RUN");
            pass = 0;
            break;
        }
        exits++;

        switch (run->exit_reason) {
        case KVM_EXIT_IO: {
            uint8_t data = *(uint8_t *)((uint8_t *)run + run->io.data_offset);
            printf("Exit #%d: IO port=0x%x dir=%s size=%d data=0x%02x\n",
                   exits, run->io.port,
                   run->io.direction == KVM_EXIT_IO_OUT ? "out" : "in",
                   run->io.size, data);
            if (run->io.port != 0x10 || run->io.direction != KVM_EXIT_IO_OUT
                || data != 0xEF) {
                printf("  FAIL: expected OUT 0x10, 0xEF\n");
                pass = 0;
            }
            break;
        }

        case KVM_EXIT_HLT:
            printf("Exit #%d: HLT\n", exits);
            goto done;

        case KVM_EXIT_INTERNAL_ERROR:
            printf("Exit #%d: INTERNAL_ERROR suberror=%d\n",
                   exits, run->internal.suberror);
            pass = 0;
            goto done;

        case KVM_EXIT_SHUTDOWN:
            printf("Exit #%d: SHUTDOWN\n", exits);
            pass = 0;
            goto done;

        case KVM_EXIT_FAIL_ENTRY:
            printf("Exit #%d: FAIL_ENTRY reason=0x%llx\n",
                   exits,
                   (unsigned long long)run->fail_entry.hardware_entry_failure_reason);
            pass = 0;
            goto done;

        default:
            printf("Exit #%d: reason=%d\n", exits, run->exit_reason);
            if (exits > 20) {
                printf("Too many exits, aborting\n");
                pass = 0;
                goto done;
            }
            break;
        }
    }

done:
    // Verify: the guest wrote 0xDEADBEEF to GVA 0x418000, which maps
    // to GPA 0x18000 via guest page tables. KVM+EPT translated that
    // to the host mmap region at offset 0x18000.
    {
        uint32_t val = *(uint32_t *)(mem + GPA_DATA);
        printf("Host check: mem[GPA 0x%x] = 0x%08x", GPA_DATA, val);
        if (val == 0xDEADBEEF) {
            printf(" (correct)\n");
        } else {
            printf(" (FAIL: expected 0xDEADBEEF)\n");
            pass = 0;
        }
    }

    close(vcpu_fd);
    close(vm_fd);
    close(kvm_fd);
    munmap(mem, GUEST_MEM_SIZE);

    if (pass) {
        printf("\n=== PASS ===\n");
    } else {
        printf("\n=== FAIL ===\n");
    }
    return !pass;
}
