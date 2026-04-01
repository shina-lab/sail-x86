// Minimal KVM selftest for the Sail x86 system emulator.
//
// Exercises the VMX specification by creating a VM via /dev/kvm,
// running a trivial guest (CPUID + HLT), and verifying the exits.
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

#define GUEST_ADDR 0x1000

// Tiny guest code (real mode, loaded at 0x1000):
//   mov ax, 0x1234
//   cpuid           -> KVM_EXIT_UNKNOWN or handled by KVM
//   out 0x10, al    -> KVM_EXIT_IO (port 0x10, direction=out, size=1)
//   hlt             -> KVM_EXIT_HLT
static const uint8_t guest_code[] = {
    0xB8, 0x34, 0x12,       // mov ax, 0x1234
    0x0F, 0xA2,             // cpuid
    0xE6, 0x10,             // out 0x10, al
    0xF4,                   // hlt
};

static void die(const char *msg) {
    perror(msg);
    exit(1);
}

int main(void) {
    int kvm_fd, vm_fd, vcpu_fd;
    struct kvm_sregs sregs;
    struct kvm_regs regs;
    struct kvm_run *run;
    size_t run_size;
    void *mem;
    int ret;

    printf("=== KVM VMX Test ===\n");

    // 1. Open /dev/kvm
    kvm_fd = open("/dev/kvm", O_RDWR);
    if (kvm_fd < 0) die("open /dev/kvm");

    ret = ioctl(kvm_fd, KVM_GET_API_VERSION, 0);
    if (ret < 0) die("KVM_GET_API_VERSION");
    printf("KVM API version: %d\n", ret);
    if (ret != 12) {
        fprintf(stderr, "Unexpected KVM API version %d (expected 12)\n", ret);
        return 1;
    }

    // 2. Create VM
    vm_fd = ioctl(kvm_fd, KVM_CREATE_VM, 0);
    if (vm_fd < 0) die("KVM_CREATE_VM");
    printf("VM created (fd=%d)\n", vm_fd);

    // 3. Set up guest memory (1 page = 4KB)
    mem = mmap(NULL, 0x1000, PROT_READ | PROT_WRITE,
               MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mem == MAP_FAILED) die("mmap");
    memcpy(mem, guest_code, sizeof(guest_code));

    struct kvm_userspace_memory_region region = {
        .slot = 0,
        .flags = 0,
        .guest_phys_addr = GUEST_ADDR,
        .memory_size = 0x1000,
        .userspace_addr = (uint64_t)mem,
    };
    ret = ioctl(vm_fd, KVM_SET_USER_MEMORY_REGION, &region);
    if (ret < 0) die("KVM_SET_USER_MEMORY_REGION");
    printf("Guest memory set up at GPA 0x%x\n", GUEST_ADDR);

    // 4. Create vCPU
    vcpu_fd = ioctl(vm_fd, KVM_CREATE_VCPU, 0);
    if (vcpu_fd < 0) die("KVM_CREATE_VCPU");

    run_size = ioctl(kvm_fd, KVM_GET_VCPU_MMAP_SIZE, 0);
    if ((int)run_size < 0) die("KVM_GET_VCPU_MMAP_SIZE");
    run = mmap(NULL, run_size, PROT_READ | PROT_WRITE, MAP_SHARED, vcpu_fd, 0);
    if (run == MAP_FAILED) die("mmap vcpu");
    printf("vCPU created, run struct at %p (%zu bytes)\n", run, run_size);

    // 5. Set up sregs: real mode, CS:IP = 0x0000:0x1000
    ret = ioctl(vcpu_fd, KVM_GET_SREGS, &sregs);
    if (ret < 0) die("KVM_GET_SREGS");
    sregs.cs.base = 0;
    sregs.cs.selector = 0;
    ret = ioctl(vcpu_fd, KVM_SET_SREGS, &sregs);
    if (ret < 0) die("KVM_SET_SREGS");

    // 6. Set up regs: RIP = GUEST_ADDR, RFLAGS = 0x2
    memset(&regs, 0, sizeof(regs));
    regs.rip = GUEST_ADDR;
    regs.rflags = 0x2;
    ret = ioctl(vcpu_fd, KVM_SET_REGS, &regs);
    if (ret < 0) die("KVM_SET_REGS");

    // 7. Run guest in a loop
    int exits = 0;
    int pass = 1;
    while (1) {
        ret = ioctl(vcpu_fd, KVM_RUN, 0);
        if (ret < 0) die("KVM_RUN");
        exits++;

        switch (run->exit_reason) {
        case KVM_EXIT_IO:
            printf("Exit #%d: KVM_EXIT_IO port=0x%x dir=%s size=%d data=0x%02x\n",
                   exits, run->io.port,
                   run->io.direction == KVM_EXIT_IO_OUT ? "out" : "in",
                   run->io.size,
                   *(uint8_t *)((uint8_t *)run + run->io.data_offset));
            if (run->io.port != 0x10 || run->io.direction != KVM_EXIT_IO_OUT) {
                printf("  FAIL: unexpected I/O exit\n");
                pass = 0;
            }
            break;

        case KVM_EXIT_HLT:
            printf("Exit #%d: KVM_EXIT_HLT\n", exits);
            goto done;

        default:
            printf("Exit #%d: unexpected exit_reason=%d\n", exits, run->exit_reason);
            pass = 0;
            goto done;
        }
    }

done:
    // Verify final register state
    ret = ioctl(vcpu_fd, KVM_GET_REGS, &regs);
    if (ret < 0) die("KVM_GET_REGS");
    printf("Final RIP=0x%llx\n", (unsigned long long)regs.rip);

    close(vcpu_fd);
    close(vm_fd);
    close(kvm_fd);
    munmap(mem, 0x1000);

    if (pass) {
        printf("\n=== PASS ===\n");
        return 0;
    } else {
        printf("\n=== FAIL ===\n");
        return 1;
    }
}
