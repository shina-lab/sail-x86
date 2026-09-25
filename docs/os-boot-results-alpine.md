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

In progress. ISOLINUX accepted the command at 3.704 s and is loading the
unmodified kernel and initramfs from the original read-only ISO.
