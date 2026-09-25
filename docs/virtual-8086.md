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
SMM/RSM preserves the VM86 context, and VMX can enter a VM86 guest and
save its context on exit, with the required fixed segment-cache checks.

IN, OUT, INS and OUTS consult the TSS I/O permission bitmap even at
IOPL 3. Privileged instructions fault at CPL 3; ARPL and the descriptor
query/task-register instructions are invalid in virtual-8086 mode.

CR4.VME enables virtual interrupt handling. At IOPL below 3, CLI/STI
operate on VIF, and 16-bit PUSHF/POPF/IRET translate between VIF and the
stack image's IF. STI, POPF and IRET check VIP; POPF and IRET also reject
setting TF. 32-bit PUSHFD/POPFD/IRETD still trap at insufficient IOPL.
An enabled pending virtual interrupt (VIF=VIP=1) faults before execution.
INT imm8 can use the TSS interrupt-redirection bitmap to call a handler through
the virtual IVT at linear address zero, without leaving virtual-8086
mode. INT3 and INTO continue through the protected-mode IDT.

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

Validation on 2026-09-25: all 368 differential cases passed on an AMD
Ryzen Threadripper 7980X and an Intel Xeon Platinum 8562Y+. These include
16/32-bit monitor stacks, expand-down stacks and a zero initial SP.
The separate SMM/RSM, VM-entry/exit and STI interrupt-ordering tests pass.
A full build succeeded, and `ctest -j128 -LE boot` passed 257 of 259 tests.
The two failures, `system_basic` (the `push_ds_pop_es_32bit` case) and
`x87-test` (22.0 / 7.0), also reproduce in a clean build of the baseline
commit `464391f`, before the virtual-8086 changes.

References: Intel SDM Vol.3B, Chapter 23 (8086 Emulation), and Vol.2,
IRET, INT, PUSHF, POPF, CLI, STI, IN, OUT, INS and OUTS.
