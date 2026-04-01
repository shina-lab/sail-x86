// Minimal KVM selftest for the Sail x86 system emulator.
//
// Sets up a protected-mode guest (required since we don't support EPT/
// unrestricted guest). The guest executes OUT + HLT to cause VM exits.
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

// Guest physical memory layout (2MB total):
//   0x00000000 - 0x00000FFF: GDT + IDT (page 0)
//   0x00001000 - 0x00001FFF: Page tables (PML4)
//   0x00002000 - 0x00002FFF: Page tables (PDPT)
//   0x00003000 - 0x00003FFF: Page tables (PD)
//   0x00010000 - 0x00010FFF: Guest code
//   0x00080000 - 0x0008FFFF: Guest stack
#define GUEST_MEM_SIZE  (2 * 1024 * 1024)
#define GDT_ADDR        0x0000
#define PML4_ADDR       0x1000
#define PDPT_ADDR       0x2000
#define PD_ADDR         0x3000
#define CODE_ADDR       0x10000
#define STACK_ADDR      0x80000

// Guest code (64-bit long mode):
//   out 0x10, al     -> KVM_EXIT_IO
//   hlt              -> KVM_EXIT_HLT
static const uint8_t guest_code[] = {
    0xE6, 0x10,             // out 0x10, al
    0xF4,                   // hlt
};

// GDT entries
struct gdt_entry {
    uint16_t limit_lo;
    uint16_t base_lo;
    uint8_t  base_mid;
    uint8_t  access;
    uint8_t  flags_limit_hi;
    uint8_t  base_hi;
} __attribute__((packed));

static void die(const char *msg) {
    perror(msg);
    exit(1);
}

static void setup_long_mode(uint8_t *mem, struct kvm_sregs *sregs) {
    // --- GDT ---
    // Entry 0: null
    // Entry 1 (0x08): 64-bit code segment (L=1, D=0)
    // Entry 2 (0x10): 64-bit data segment
    struct gdt_entry *gdt = (struct gdt_entry *)(mem + GDT_ADDR);
    memset(gdt, 0, 3 * sizeof(*gdt));

    // Code segment: base=0, limit=0xFFFFF, type=0xA (exec/read), S=1, DPL=0, P=1, L=1, G=1
    gdt[1].limit_lo = 0xFFFF;
    gdt[1].access = 0x9A;         // P=1, DPL=0, S=1, type=0xA (exec/read)
    gdt[1].flags_limit_hi = 0xAF; // G=1, L=1, D=0, limit[19:16]=0xF

    // Data segment: base=0, limit=0xFFFFF, type=0x2 (read/write), S=1, DPL=0, P=1, G=1
    gdt[2].limit_lo = 0xFFFF;
    gdt[2].access = 0x92;         // P=1, DPL=0, S=1, type=0x2 (read/write)
    gdt[2].flags_limit_hi = 0xCF; // G=1, D=1, limit[19:16]=0xF

    // --- Page tables (identity map first 2MB) ---
    uint64_t *pml4 = (uint64_t *)(mem + PML4_ADDR);
    uint64_t *pdpt = (uint64_t *)(mem + PDPT_ADDR);
    uint64_t *pd   = (uint64_t *)(mem + PD_ADDR);

    memset(pml4, 0, 0x1000);
    memset(pdpt, 0, 0x1000);
    memset(pd,   0, 0x1000);

    pml4[0] = PDPT_ADDR | 0x03;   // present + writable
    pdpt[0] = PD_ADDR   | 0x03;
    pd[0]   = 0x00000000 | 0x83;  // 2MB page, present + writable + PS

    // --- Set up sregs ---
    sregs->cr3 = PML4_ADDR;
    sregs->cr4 = (1UL << 5);   // PAE
    sregs->cr0 = (1UL << 0) | (1UL << 31) | (1UL << 5); // PE + PG + NE
    sregs->efer = (1UL << 8) | (1UL << 10); // LME + LMA

    // CS: 64-bit code segment
    sregs->cs.base = 0;
    sregs->cs.limit = 0xFFFFFFFF;
    sregs->cs.selector = 0x08;
    sregs->cs.type = 0xA;    // exec/read
    sregs->cs.present = 1;
    sregs->cs.dpl = 0;
    sregs->cs.db = 0;        // D=0 for 64-bit
    sregs->cs.s = 1;
    sregs->cs.l = 1;         // L=1 for 64-bit
    sregs->cs.g = 1;

    // DS/ES/SS: data segments
    struct kvm_segment data_seg = {
        .base = 0,
        .limit = 0xFFFFFFFF,
        .selector = 0x10,
        .type = 0x2,     // read/write
        .present = 1,
        .dpl = 0,
        .db = 1,
        .s = 1,
        .l = 0,
        .g = 1,
    };
    sregs->ds = data_seg;
    sregs->es = data_seg;
    sregs->ss = data_seg;
    sregs->fs = data_seg;
    sregs->gs = data_seg;

    // GDT register
    sregs->gdt.base = GDT_ADDR;
    sregs->gdt.limit = 3 * 8 - 1;

    // IDT (empty, but set up to avoid issues)
    sregs->idt.base = GDT_ADDR + 0x100;
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

    // 1. Open /dev/kvm
    kvm_fd = open("/dev/kvm", O_RDWR);
    if (kvm_fd < 0) die("open /dev/kvm");

    ret = ioctl(kvm_fd, KVM_GET_API_VERSION, 0);
    if (ret < 0) die("KVM_GET_API_VERSION");
    printf("KVM API version: %d\n", ret);

    // 2. Create VM
    vm_fd = ioctl(kvm_fd, KVM_CREATE_VM, 0);
    if (vm_fd < 0) die("KVM_CREATE_VM");
    printf("VM created\n");

    // 3. Set up guest memory
    mem = mmap(NULL, GUEST_MEM_SIZE, PROT_READ | PROT_WRITE,
               MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mem == MAP_FAILED) die("mmap");
    memset(mem, 0, GUEST_MEM_SIZE);
    memcpy(mem + CODE_ADDR, guest_code, sizeof(guest_code));

    struct kvm_userspace_memory_region region = {
        .slot = 0,
        .flags = 0,
        .guest_phys_addr = 0,
        .memory_size = GUEST_MEM_SIZE,
        .userspace_addr = (uint64_t)mem,
    };
    ret = ioctl(vm_fd, KVM_SET_USER_MEMORY_REGION, &region);
    if (ret < 0) die("KVM_SET_USER_MEMORY_REGION");

    // 4. Create vCPU
    vcpu_fd = ioctl(vm_fd, KVM_CREATE_VCPU, 0);
    if (vcpu_fd < 0) die("KVM_CREATE_VCPU");

    run_size = ioctl(kvm_fd, KVM_GET_VCPU_MMAP_SIZE, 0);
    if ((int)run_size < 0) die("KVM_GET_VCPU_MMAP_SIZE");
    run = mmap(NULL, run_size, PROT_READ | PROT_WRITE, MAP_SHARED, vcpu_fd, 0);
    if (run == MAP_FAILED) die("mmap vcpu");

    // 5. Set up long mode
    ret = ioctl(vcpu_fd, KVM_GET_SREGS, &sregs);
    if (ret < 0) die("KVM_GET_SREGS");
    setup_long_mode(mem, &sregs);
    ret = ioctl(vcpu_fd, KVM_SET_SREGS, &sregs);
    if (ret < 0) die("KVM_SET_SREGS");

    // 6. Set up regs
    memset(&regs, 0, sizeof(regs));
    regs.rip = CODE_ADDR;
    regs.rsp = STACK_ADDR;
    regs.rflags = 0x2;
    regs.rax = 0x42;  // Value that will be OUT'd
    ret = ioctl(vcpu_fd, KVM_SET_REGS, &regs);
    if (ret < 0) die("KVM_SET_REGS");

    printf("Guest set up in 64-bit long mode, RIP=0x%x\n", CODE_ADDR);

    // 7. Run guest
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
        case KVM_EXIT_IO:
            printf("Exit #%d: IO port=0x%x dir=%s size=%d data=0x%02x\n",
                   exits, run->io.port,
                   run->io.direction == KVM_EXIT_IO_OUT ? "out" : "in",
                   run->io.size,
                   *(uint8_t *)((uint8_t *)run + run->io.data_offset));
            if (run->io.port != 0x10 || run->io.direction != KVM_EXIT_IO_OUT) {
                printf("  UNEXPECTED I/O\n");
                pass = 0;
            }
            break;

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
                   exits, (unsigned long long)run->fail_entry.hardware_entry_failure_reason);
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
    close(vcpu_fd);
    close(vm_fd);
    close(kvm_fd);
    munmap(mem, GUEST_MEM_SIZE);

    if (pass) {
        printf("\n=== PASS ===\n");
        return 0;
    } else {
        printf("\n=== FAIL ===\n");
        return 1;
    }
}
