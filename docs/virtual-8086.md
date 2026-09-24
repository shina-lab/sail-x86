# Virtual-8086 mode

The model enters virtual-8086 mode through a 32-bit IRET at CPL 0 with
EFLAGS.VM set in the return frame. CS, SS, ES, DS, FS and GS then use
8086-style addressing (base = selector * 16, limit = 65535), with 16-bit
default operand, address and stack sizes. The 66H and 67H prefixes select
32-bit operands and addresses. Paging remains enabled as configured by
the monitor; virtual-8086 accesses have user privilege (CPL 3).

Exceptions and interrupts through 16/32-bit interrupt or trap gates enter
a protected-mode ring-0 handler on the TSS's SS0:ESP0 stack. The frame
includes GS, FS, DS and ES as well as SS, ESP, EFLAGS, CS and EIP, with an
error code where appropriate. IRETD restores this frame. Hardware task
switches and task gates remain outside the model's existing support.

IN, OUT, INS and OUTS consult the TSS I/O permission bitmap even at
IOPL 3. Privileged instructions fault at CPL 3; ARPL and the descriptor
query/task-register instructions are invalid in virtual-8086 mode.

`kvm_vm86` runs short programs through the same IRETD entry on the Sail
system model and a KVM virtual CPU. Each run starts with independent
memory and a fresh VM. It compares general-purpose registers, EFLAGS,
segment selectors, CR2, the saved interrupt frame and application memory.
The unused register background is tested with both zero and one bits.
The tests also require the expected exit vector and error code, so an
unexpected fault on both sides does not count as success.

```
cmake --build build -j128 --target kvm_vm86
ctest --test-dir build -R '^(system_vm86|kvm_vm86)$' --output-on-failure
```

`system_vm86` runs the expected-result checks without KVM; `kvm_vm86`
additionally compares with hardware and skips when `/dev/kvm` is absent.
The host may run a 64-bit kernel: the guest uses legacy protected mode,
with IA32_EFER.LMA clear. Virtual-8086 mode is unavailable in IA-32e mode.

References: Intel SDM Vol.3B, Chapter 23 (8086 Emulation), and Vol.2,
IRET, INT, PUSHF, POPF, CLI, STI, IN, OUT, INS and OUTS.
