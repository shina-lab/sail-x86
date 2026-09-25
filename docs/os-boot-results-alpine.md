# Alpine Linux 3.24.2 live-CD boot

Worktree `sail-x86-os4`, branch `os-boot-alpine`, starting at `18e90a9`.
Session date: 2026-09-25 UTC. Only the sail-llvm emulator is used; no
official Sail compiler, CMake model build, or CTest target is invoked.
Original media and other worktrees are read only. Each full boot attempt
has a 2,400-second wall limit; the session budget is about two hours.

## Platform and reproduction

The existing `build/llvm/sail-x86-system`, SeaBIOS `build/bios.bin`, and
SeaVGABIOS `build/vgabios.bin` are the supplied builds. RAM is 512 MiB,
virtual CPU speed 20 MIPS. The initial serial attempt retains the earlier
`noapic nolapic` options to compare with the previous boot-media stall.
`debug_init` enables initramfs shell and nlplug-findfs diagnostics.

SHA-256 before the attempts:

```text
3ab424762af704b2c2a9e57df1dc37f982af260071504d977f2fb96822e7130b  alpine-virt-3.24.2-x86_64.iso
983c060418c11d625cb53cb86856b8c413c8e578df148043202dabce2a6073eb  build/llvm/sail-x86-system
888830e2b45d64866b461ebfc27aaaa6fa60e993f557a8dd1cc5abad2bd36d44  build/bios.bin
62c8300e0fa564fd26b596fa4327b081fc159e828a0330ec45b61cd428919d55  build/vgabios.bin
```

Raw runner logs, input records and RAM snapshots are in `build/os-boot/`.
Preserved serial logs and PNGs are linked below. SIGUSR1 captures CPU,
interrupt controllers, timers, IDE state, VGA and RAM; SIGUSR2 captures
the VGA framebuffer. A serial console need not appear on that framebuffer.

## Attempts

### alpine-01: boot-prompt timing setup

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_IDE_TRACE=1 python3 system-emu/run-boot.py --name alpine-01 --timeout 2400 --expect ALPINE_BOOT_VERIFIED --send '5:/boot/vmlinuz-virt initrd=/boot/initramfs-virt console=ttyS0,115200 modules=loop,squashfs,sd-mod,usb-storage noapic nolapic tsc=reliable nokaslr debug_init\n' -- build/llvm/sail-x86-system -m 512 -ips 20 -b build/bios.bin -cdrom /home/ruiu/os-images/alpine-virt-3.24.2-x86_64.iso -boot d
```

Stopped manually after **96.269 s / 458,368,665 instructions**, exit 0.
The ISO's `TIMEOUT 10` is one second: the scheduled serial input missed
the prompt and the default entry started without the requested console.
This was an input-timing setup failure, not an observed guest failure.
Last serial output: `boot:`. [Serial](os-boot/alpine-01.serial),
[VGA PNG](os-boot/alpine-01.png), [runner record](os-boot/alpine-01.json).

### alpine-02: serial boot with init/IDE diagnostics

The [input controller](os-boot/alpine-console.py) starts the standard
runner and sends the kernel command line as soon as `boot:` appears.
It records each input and elapsed wall time, then waits for a root login
and runs `uname -a` and `mount`. The verification marker matches a whole
output line so that command echo cannot terminate the run prematurely.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_IDE_TRACE=1 python3 docs/os-boot/alpine-console.py --name alpine-02 --bootline '/boot/vmlinuz-virt initrd=/boot/initramfs-virt console=ttyS0,115200 modules=loop,squashfs,sd-mod,usb-storage noapic nolapic tsc=reliable nokaslr debug_init' -- build/llvm/sail-x86-system -m 512 -ips 20 -b build/bios.bin -cdrom /home/ruiu/os-images/alpine-virt-3.24.2-x86_64.iso -boot d
```

ISOLINUX accepted the command at 3.704 s. Linux reached `/init` at guest
58.003 s (about eight minutes wall time), then `Mounting boot media` at
guest 64.320 s. It completed 31 `mdev` children and stopped before the
32nd spawn. The last completed child was PID 702, event SEQNUM 692,
`ttyS2`. Stopped for the diagnosed model fix after **969.770 s /
2,490,233,931 instructions**, exit 0. No login or shell was reached.

[Serial](os-boot/alpine-02.serial), [VGA PNG](os-boot/alpine-02.png),
[runner record](os-boot/alpine-02.json), [inputs](os-boot/alpine-02.inputs.json),
[CPU/device state](os-boot/alpine-02-state.txt),
[task inspection](os-boot/alpine-02-tasks.txt).

### Diagnosed XADD restart defect — `23c4e2f`

The final snapshots show the CPU idling with interrupts enabled and the
PIT advancing. No IDE command is pending. PID 1 is waiting for its child;
`nlplug-findfs`'s main thread (446) is blocked in `fork()` on musl's random
lock, whose value is `0xffffffff`. Its remaining worker (447) is waiting
on the trigger condition variable. There is no live `mdev` child.

The snapshot uses the ISO's own System.map and BTF, inspected by
[inspect-alpine.py](os-boot/inspect-alpine.py). The stack listings are
candidate text addresses, not an ORC unwind; saved syscall frames identify
both futex waits. The main thread's libc base is `0x7fd70c685000`, its
saved userspace RIP is `base+0x66613` (the lock's futex syscall), and its
caller is `base+0x2fdba` (`fork`'s atfork-lock loop). Its loop index and
the pointer table identify `__random_lockptr` at `base+0xa7004`.

[musl's fork source](https://git.musl-libc.org/cgit/musl/tree/src/process/fork.c)
and the ISO's libc disassembly explain the failure: fork makes the lock
page copy-on-write; unlocking performs `LOCK XADD [lock], EAX` with
`EAX=0x7fffffff`. The model exchanged EAX with memory *before* attempting
the store. A write-protection page fault therefore left EAX changed.
The restarted instruction added the wrong value, corrupting the lock.
With lock value `0x80000001`, the faulty retry produces `2` instead of
`0`; repetition yields `2, 6, 14, ...`, explaining the 31 completed
children and the subsequent permanent lock wait. This is independent of
the CD-ROM implementation.

Intel SDM revision 090, **Vol.3A §7.5, Exception Classifications**, requires
faults to restore the state preceding the faulting instruction. **Vol.2D,
XADD, pp.6-26–6-27** specifies its result and page-fault exception.
The fix commits the memory store before the source register and flags.
It applies to byte, word, dword and qword memory operands.

The regression protects the destination page, checks unchanged source,
memory, RIP and arithmetic flags on `#PF`, repairs the PTE, then checks
the restarted result. Before the fix, the dword case changes RAX from
`0x123456787fffffff` to `0x80000001` on the fault.
[Failing result](os-boot/alpine-xadd-before.txt).

Validation uses only sail-llvm and clang++:

```sh
system-emu/build-llvm.sh
python3 docs/os-boot/build-alpine-tests.py
```

[Build](os-boot/alpine-xadd-build.txt); all **19 paging** cases
([log](os-boot/alpine-xadd-paging.txt)), **78 basic** cases
([log](os-boot/alpine-xadd-basic.txt)), and **26 exception** cases
([log](os-boot/alpine-xadd-exceptions.txt)) pass.
The new regression covers all four XADD widths.

Rebuilt emulator SHA-256:
`378aa1e2dd5e45e8dea3e1312c5dee2f5377be0b7b78994b61586b67e75c86d9`.

### alpine-03-xadd: retry with corrected XADD restart

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_IDE_TRACE=1 python3 docs/os-boot/alpine-console.py --name alpine-03-xadd --bootline '/boot/vmlinuz-virt initrd=/boot/initramfs-virt console=ttyS0,115200 modules=loop,squashfs,sd-mod,usb-storage noapic nolapic tsc=reliable nokaslr debug_init' -- build/llvm/sail-x86-system -m 512 -ips 20 -b build/bios.bin -cdrom /home/ruiu/os-images/alpine-virt-3.24.2-x86_64.iso -boot d
```

Interrupted when the preceding session reached its usage limit at
10:50 JST. Both the input controller and emulator were gone when work
resumed at 10:52 JST; no final runner JSON was written. The last serial
output records PID 768 / SEQNUM 766 being reaped, after **96** completed
`mdev` children, so the corrected XADD had passed the earlier 31-child
stall. The last available CPU/RAM snapshot is earlier, at **1,773,074,976
instructions**; it is not a final instruction count. No login or shell
was reached before interruption.

[Serial](os-boot/alpine-03-xadd.serial),
[VGA PNG](os-boot/alpine-03-xadd.png),
[last captured state](os-boot/alpine-03-xadd-state.txt),
[inputs](os-boot/alpine-03-xadd.inputs.json),
[controller note](os-boot/alpine-03-xadd.manual.json),
[progress observation](os-boot/alpine-03-xadd.observations.jsonl).

## Resumed session: 2026-09-25, 10:52 JST

The resumed session has an approximately 90-minute budget. Its first
build was `system-emu/build-llvm.sh`, using the corrected sail-llvm
checkout at `54a10b8` (polymorphic argument widths from extern parameter
types). No official Sail compiler or CMake/CTest model build was used.
The ISO and firmware hashes still match those recorded above, and the
CD-ROM device opens the ISO with `O_RDONLY`.

[Build log](os-boot/alpine-resume-build.txt). SHA-256:

```text
67215b2f00512e38b9a1232165d86ef4eff27153088cba382bf511738686984f  ~/sail-llvm/build/sailc
bf354a220fbfba4c6847c71a59734b60482f65ce865f41f8058de5f9ce5dc245  build/llvm/sail-x86-system
```

`python3 docs/os-boot/build-alpine-tests.py` rebuilt and passed all
**78 basic, 19 paging, and 26 exception cases**, including the XADD
restart regression for all four operand widths:
[basic](os-boot/alpine-resume-basic.txt),
[paging](os-boot/alpine-resume-paging.txt),
[exceptions](os-boot/alpine-resume-exceptions.txt).

### alpine-04-resume: fresh boot after sail-llvm rebuild

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_IDE_TRACE=1 python3 docs/os-boot/alpine-console.py --name alpine-04-resume --bootline '/boot/vmlinuz-virt initrd=/boot/initramfs-virt console=ttyS0,115200 modules=loop,squashfs,sd-mod,usb-storage noapic nolapic tsc=reliable nokaslr debug_init' -- build/llvm/sail-x86-system -m 512 -ips 20 -b build/bios.bin -cdrom /home/ruiu/os-images/alpine-virt-3.24.2-x86_64.iso -boot d
```

In progress with a fresh 2,400-second limit. The guest ISO, firmware,
kernel command line, RAM size and virtual CPU speed match alpine-03.
