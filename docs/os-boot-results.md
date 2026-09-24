# Operating-system boot results

Worktree: `sail-x86-os`. All disk images used for writes are copies under
`build/os-boot`; original media under `/home/ruiu/os-images` are read only.
The machine has one CPU, xAPIC, a 24-input I/O APIC, SeaBIOS MP/ACPI tables,
a PIIX4 PM timer, two primary IDE disks, an ATAPI CD-ROM, Bochs VBE and
planar VGA. It has no HPET or additional CPUs.

## Final status

| OS | Farthest observed progress | Remaining blocker |
|---|---|---|
| xv6 | Serial `$` shell; filesystem on IDE slave | None for the requested boot |
| Linux i386 | Serial `sail#` shell | None for the requested boot |
| Linux amd64 | `sail#` through BIOS/ISO with ACPI and I/O APIC, and by direct bzImage boot | Neither command line needs `noapic nolapic` |
| Haiku | VBE 1024x768 boot logo, three icons lit | No desktop or COM1 output within the budget |
| ReactOS | FreeLoader setup hive and kernel initialization | Aborted on 108-byte x87 save; C++ memory limit fixed and regression-tested, full retry still needed |
| FreeBSD | CD Loader 1.2 and BTX entry | Fails before loader prompt; virtual-8086 boot path remains unsupported |
| Windows 3.1 | Express Setup and first-stage file copy | Invalid Opcode when starting graphical setup; no Windows PNG |
| Windows 95 | Setup from FreeDOS hard disk | ScanDisk R6002; no graphical screen or Windows PNG |

The APIC/IOAPIC, IDE slave, MP/ACPI firmware, VBE/PNG and planar VGA work
is committed separately, along with the boot fixes. The only Sail model
changes are the SDM-cited CR8/APIC alias and real-mode IRET NT handling,
each with an instruction regression in its own commit. The final C++ x87
memory-capacity fix passes aligned and noncontiguous-page save/restore tests.
All 14 system/device tests pass after that fix; the basic suite contains
62 test cases. BIOS graphics fixtures separately validate modes 12h, 13h
and VBE 101h. Those test patterns are not Windows screenshots.

Cumulative measured boot-attempt wall time: xv6 6.21 min, Linux 51.91 min,
Haiku 57.79 min, ReactOS 52.83 min, FreeBSD 4.69 min, Windows 3.1 58.38 min,
and Windows 95 58.38 min. Attempts ran concurrently. Each attempt below
records its exact command and last serial output, including silent consoles.

## Reproduction and measurement

Build the emulator and firmware from the repository root:

```sh
cmake -B build
cmake --build build -j128 --target sail-x86-system
system-emu/mk-freedos.sh build
```

SeaBIOS 1.16.3 uses `CONFIG_MPTABLE=y`, `CONFIG_ACPI=y`,
`CONFIG_ACPI_DSDT=y`; SeaVGABIOS uses `CONFIG_VGA_BOCHS=y`,
`CONFIG_VGA_BOCHS_STDVGA=y`, `CONFIG_VGA_VBE=y`, `CONFIG_VGA_PCI=y`.
PCI functions are ISA at 00:01.0, IDE at 00:01.1 and PM at 00:01.3.
The supplied SDM revision 090 numbers its APIC chapter **13** (chapter 12
in older editions). The CR8/APIC alias follows SDM Vol.3A sections 13.8.6–13.8.6.1 and has a guest-instruction regression.

`system-emu/run-boot.py` records the exact emulator/runner commands,
monotonic wall time, exit status, serial output and final instruction count
in `build/os-boot/NAME.{json,serial,stderr}`. The count is the emulator's
step count, including interrupt entries; HLT clock advancement does not add
instructions. Wall time includes diagnostic capture at termination.
`SIGUSR1` dumps CPU/APIC/PIC and VGA text, and optionally guest RAM.
`SIGUSR2` writes `framebuffer.png`; `SAIL_X86_FRAMEBUFFER` selects a path.
The runner saves graphical captures as `build/os-boot/NAME.png`.

`-kbd` routes stdin to the emulated keyboard. `Ctrl-a s` switches input to
COM1 and `Ctrl-a k` switches it back. This permits a BIOS loader to switch
to a serial console without restarting the emulator.

## Device validation

```sh
cmake --build build -j128 --target system_test_basic system_test_paging \
  system_test_exceptions system_test_a20 system_test_vmx system_test_ide \
  system_test_apic system_test_fw_cfg system_test_vbe system_test_vga \
  system_test_apic_cpu system_test_keyboard system_test_rtc
ctest --test-dir build -R '^system_' --output-on-failure
```

All 14 system/device/PNG tests pass. Coverage includes APIC priorities, self-IPIs,
timer modes/divisors, edge/level routing and EOI; independent IDE master/slave
transfers; fw_cfg topology; PM timer/ACPI mode; PCI BAR remapping; framebuffer
formats/banking/offsets; PNG CRC and decompression; VGA latches/write modes,
chain-4 and palettes; SMRAM and option-ROM shadow separation; keyboard
output-port/A20 commands; RTC periodic, update and alarm interrupts; and
CPU interrupt dispatch and CR8/APIC aliasing; real-mode IRET with NT set;
and 108-byte x87 saves/restores across noncontiguous pages.

## Prepared images

The xv6 boot and filesystem images are copied to `build/os-boot/xv6.img`
and `build/os-boot/xv6-fs.img` before attaching them as writable disks.

The Linux APIC test kernel is built from Linux 6.19.6 using
`system-emu/mk-linux.sh`'s tiny configuration plus `CONFIG_SMP=y`,
`CONFIG_ACPI=y`, `CONFIG_PCI=y`, `CONFIG_X86_LOCAL_APIC=y` and
`CONFIG_X86_IO_APIC=y`, with 128 build jobs. It retains that script's existing
deterministic boot RNG patch. The test packages the 32-bit initramfs supplied in
`/home/ruiu/os-images/linux-i386`; the kernel enables IA32 emulation.
A small test ISO uses ISOLINUX/ldlinux.c32 extracted from the supplied Alpine
ISO and the new kernel, so Linux can discover the firmware APIC tables.
Its kernel command line is:

```text
console=ttyS0,115200 earlyprintk=serial,ttyS0,115200 tsc=reliable nokaslr norandmaps loglevel=7 rdinit=/init
```

Windows 3.1 setup files were extracted from `win31.iso` with xorriso and
copied with mtools into `C:\WIN31` on `build/os-boot/win31.img`, a copy of
`build/freedos.img` (FAT16 partition offset 1048576). AUTOEXEC.BAT changes
to that directory and runs SETUP. Windows 95 has a separate 512 MB disk
with one FAT16 partition, starting at sector 2048; its supplied CD boots an
MS-DOS floppy image which loads HIMEM/CD-ROM support and starts OEMSETUP.

## Boot attempts

SeaBIOS uses `CONFIG_USE_SMM=n` and `CONFIG_CALL32_SMM=n`: its QEMU SMM
trampoline expects a different save-state layout. The emulator implements
FADT ACPI enable/disable commands in its PM device. This preserves the
firmware's MP/ACPI tables without changing the Intel SMM model to match QEMU.


### xv6-01

Stopped during SeaBIOS SMM relocation before disk boot. Last firmware debug output: `WARNING - internal error detected at handle_smi:87!`. Stopped manually after collecting CPU state.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name xv6-01 --timeout 300 --expect '\$ ' -- build/system-emu/sail-x86-system -ips 4 -b build/bios.bin -hda build/os-boot/xv6.img -hdb build/os-boot/xv6-fs.img
```

Wall time: **109.418 s**. Instructions: **37,869,036**.

Last serial output:

```text
(no serial output)
```

### xv6-02

**Reached the serial `$` shell.** The kernel enabled its local APIC periodic timer and I/O APIC, and mounted the filesystem from the primary IDE slave.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name xv6-02 --timeout 300 --expect '\$ ' -- build/system-emu/sail-x86-system -ips 4 -b build/bios.bin -hda build/os-boot/xv6.img -hdb build/os-boot/xv6-fs.img
```

Wall time: **263.322 s**. Instructions: **20,156,878**.

Last serial output:

```text
xv6...
cpu0: starting 0
sb: size 1000 nblocks 941 ninodes 200 nlog 30 logstart 2 inodestart 32 bmap start 58
init: starting sh
$
```

### linux-apic-01

Reached the 64-bit kernel, MADT discovery, symmetric I/O APIC routing (timer pin 2), ACPI interpreter, PCI enumeration and initramfs unpacking. The 900-second bound expired before a shell. This used the pre-RTC-fix emulator.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name linux-apic-01 --timeout 900 --expect 'sail# ' -- build/system-emu/sail-x86-system -ips 4 -b build/bios.bin -cdrom build/os-boot/linux-apic.iso -boot d
```

Wall time: **900.844 s**. Instructions: **153,048,662**.

Last serial output:

```text
pci 0000:00:02.0: vgaarb: VGA device added: decodes=io+mem,owns=io+mem,locks=none
vgaarb: loaded
clocksource: Switched to clocksource tsc-early
ACPI: Failed to create genetlink family for ACPI event
pnp: PnP ACPI init
pnp: PnP ACPI: found 4 devices
clocksource: acpi_pm: mask: 0xffffff max_cycles: 0xffffff, max_idle_ns: 2085701024 ns
pci_bus 0000:00: resource 4 [io  0x0000-0x0cf7 window]
pci_bus 0000:00: resource 5 [io  0x0d00-0xffff window]
pci_bus 0000:00: resource 6 [mem 0x000a0000-0x000bffff window]
pci_bus 0000:00: resource 7 [mem 0x80000000-0xfebfffff window]
pci 0000:00:01.0: PIIX3: Enabling Passive Release
pci 0000:00:00.0: Limiting direct PCI/PCI transfers
PCI: CLS 0 bytes, default 64
Unpacking initramfs...
RAPL PMU: API unit is 2^-32 Joules, 0 fixed counters, 10737418240 ms ovfl timer
```

### linux-i386-01

**Reached the serial `sail#` shell.** This is the supplied 32-bit kernel and initramfs, with an explicit command line omitting APIC-disabling flags. The supplied kernel itself is uniprocessor without APIC support; the separate 64-bit test exercises APICs.

```sh
system-emu/run-boot.py --name linux-i386-01 --timeout 900 --expect 'sail# ' -- build/system-emu/sail-x86-system -ips 4 -a 'console=ttyS0 earlyprintk=serial,ttyS0 tsc=reliable nokaslr norandmaps rdinit=/init' -i /home/ruiu/os-images/linux-i386/initramfs-i386.cpio /home/ruiu/os-images/linux-i386/bzImage-i386
```

Wall time: **328.832 s**. Instructions: **55,971,204**.

Last serial output:

```text
microcode: Current revision: 0x00000000
input: AT Translated Set 2 keyboard as /devices/platform/i8042/serio0/input/input0
sched_clock: Marking stable (10453434250, 29533000)->(10485958500, -2991250)
Freeing unused kernel image (initmem) memory: 196K
Write protecting kernel text and read-only data: 1632k
Run /init as init process

========================================
 Sail x86-64 Emulator - Linux Console
========================================

Type 'help' for a list of built-in commands.
Press Ctrl-a x to exit the emulator.


sail#
```

### freebsd-01

Reached CD Loader 1.2 and **Starting the BTX loader**, then ceased making boot progress. No loader prompt or serial console appeared, so the scheduled `set console=comconsole` and `boot -s` did not take effect. The final CPU ran through zero-filled memory in protected mode. Stopped manually for diagnosis.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name freebsd-01 --timeout 900 --send 45:3 --send '75:set console=comconsole\n' --send '90:\x01sboot -s\n' -- build/system-emu/sail-x86-system -ips 4 -kbd -b build/bios.bin -cdrom /home/ruiu/os-images/FreeBSD-14.5-RELEASE-amd64-disc1.iso -boot d
```

Wall time: **163.759 s**. Instructions: **22,728,435**.

Last serial output:

```text
(no serial output)
```

### freebsd-trace-02

Diagnostic trace: bounded at 5,000,000 instructions, still in SeaBIOS. No serial output.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=0 SAIL_X86_TRACE_END=5000000 SAIL_X86_TRACE_STEP=100000 system-emu/run-boot.py --name freebsd-trace-02 --timeout 180 -- build/system-emu/sail-x86-system -ips 4 -b build/bios.bin -cdrom /home/ruiu/os-images/FreeBSD-14.5-RELEASE-amd64-disc1.iso -boot d
```

Wall time: **13.608 s**. Instructions: **5,000,000**.

Last serial output:

```text
(no serial output)
```

### freebsd-trace-03

Diagnostic trace: BTX starts around 6,100,000 instructions, then execution escapes to zero-filled memory. No serial output.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=5000000 SAIL_X86_TRACE_END=8000000 SAIL_X86_TRACE_STEP=10000 system-emu/run-boot.py --name freebsd-trace-03 --timeout 180 -- build/system-emu/sail-x86-system -ips 4 -b build/bios.bin -cdrom /home/ruiu/os-images/FreeBSD-14.5-RELEASE-amd64-disc1.iso -boot d
```

Wall time: **39.032 s**. Instructions: **8,000,000**.

Last serial output:

```text
(no serial output)
```

### freebsd-trace-04

Diagnostic trace: BTX exception formatting returns at instruction 6,114,173 from CS:EIP `0008:000094cf` with SS=`ffff`, ESP=`fffe757b`; RET transfers to `0080bd32`, then executes zero bytes. The model has no virtual-8086 return path in its IRETD implementation, which BTX requires. No model workaround was added.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=6110000 SAIL_X86_TRACE_END=6120000 SAIL_X86_TRACE_STEP=1 system-emu/run-boot.py --name freebsd-trace-04 --timeout 180 -- build/system-emu/sail-x86-system -ips 4 -b build/bios.bin -cdrom /home/ruiu/os-images/FreeBSD-14.5-RELEASE-amd64-disc1.iso -boot d
```

Wall time: **27.026 s**. Instructions: **6,120,000**.

Last serial output:

```text
(no serial output)
```

### haiku-01

Reached **64-bit kernel code** and selected **VBE 1024x768x32** (mode 144h). The captured image was black: duplicate VGA ROM initialization advertised E0000000 while BAR0 was FD000000. This is fixed by commit `6f5546d`. COM1 remained silent. The supervisor was paused at 818.4 seconds while the guest continued decompressing, then resumed to collect this result; effective duration was 1135 seconds, within the OS budget.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name haiku-01 --timeout 900 -- build/system-emu/sail-x86-system -ips 4 -b build/bios.bin -cdrom /home/ruiu/os-images/haiku-r1beta5-x86_64-anyboot.iso -boot d
```

Wall time: **1134.972 s**. Instructions: **175,736,527**.

Last serial output:

```text
(no serial output)
```

### reactos-01

The supplied ISO defaults to **Live (Debug)**, despite its bootcd filename. Reached ReactOS kernel CPU-feature reporting and a VGA request to connect a debugger on COM1. Only RTC IRQ 8 was unmasked in the final state; the static CMOS device supplied no periodic interrupts. Stopped manually.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name reactos-01 --timeout 900 --send '30:\n' -- build/system-emu/sail-x86-system -ips 4 -kbd -b build/bios.bin -cdrom /home/ruiu/os-images/reactos-bootcd-0.4.17-dev-915-g3f5fd48-x86-gcc-lin-dbg.iso -boot d
```

Wall time: **308.531 s**. Instructions: **67,301,977**.

Last serial output:

```text
(/srv/buildbot/worker_data/Build_GCCLin_x86/build/boot/freeldr/freeldr/arch/i386/hwpci.c:111) err: No valid routing table found!
(ntoskrnl/kd64/kdinit.c:94) -----------------------------------------------------
(ntoskrnl/kd64/kdinit.c:95) ReactOS 0.4.17-x86-dev (Build 20260924-0.4.17-dev-915-g3f5fd48) (Commit 3f5fd48b637f96ce589886dc1548b8e9ffb42448)
(ntoskrnl/kd64/kdinit.c:96) 1 System Processor [256 MB Memory]
(ntoskrnl/kd64/kdinit.c:100) Command Line: DEBUG DEBUGPORT=COM1 BAUDRATE=115200 SOS FASTDETECT MININT
(ntoskrnl/kd64/kdinit.c:103) ARC Paths: multi(0)disk(0)cdrom(96) \ multi(0)disk(0)cdrom(96) \reactos\
(ntoskrnl/ke/i386/cpu.c:356) Supported CPU features: KF_RDTSC KF_CR4 KF_CMOV KF_GLOBAL_PAGE KF_LARGE_PAGE KF_MTRR KF_CMPXCHG8B KF_MMX KF_WORKING_PTE KF_PAT KF_FXSR KF_FAST_SYSCALL KF_XMMI KF_XMMI64 KF_NX_BIT X86_FEATURE_PAE X86_FEATURE_APIC
(ntoskrnl/ke/i386/cpu.c:652) Prefetch Cache: 64 bytes	L2 Cache: 0 bytes	L2 Cache Line: 64 bytes	L2 Cache Associativity: 0
```

### reactos-setup-02

Local ISO selects **ReactOS Setup (Text Mode)** with `/NODEBUG /NOGUIBOOT /SIFOPTIONSOVERRIDE`. Loaded the setup system hive and entered kernel code; timed out with only RTC IRQ 8 unmasked. The subsequent RTC device fix targets this calibration wait. No setup selection screen yet.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name reactos-setup-02 --timeout 900 --send '30:\n' -- build/system-emu/sail-x86-system -ips 4 -kbd -b build/bios.bin -cdrom build/os-boot/reactos-setup.iso -boot d
```

Wall time: **900.483 s**. Instructions: **219,066,326**.

Last serial output:

```text
(/srv/buildbot/worker_data/Build_GCCLin_x86/build/boot/freeldr/freeldr/arch/i386/hwpci.c:111) err: No valid routing table found!
```

### win31-01

FreeDOS booted from the hard disk and Windows Setup displayed **Installing XMS memory manager...**. No graphical screen. Stopped manually after diagnosis.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name win31-01 --timeout 900 --send '90:\n' --send '150:\n' --send '210:\n' -- build/system-emu/sail-x86-system -ips 4 -kbd -b build/bios.bin -hda build/os-boot/win31.img -cdrom /home/ruiu/os-images/win31.iso -boot c
```

Wall time: **656.856 s**. Instructions: **121,442,750**.

Last serial output:

```text
(no serial output)
```

### win31-02

Retried with 32 MB and 8042 output-port/A20 support. Reached the same **Installing XMS memory manager...** text screen; stopped manually.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name win31-02 --timeout 900 --send '60:\n' --send '120:\n' --send '180:\n' -- build/system-emu/sail-x86-system -ips 4 -m 32 -kbd -b build/bios.bin -hda build/os-boot/win31.img -cdrom /home/ruiu/os-images/win31.iso -boot c
```

Wall time: **557.434 s**. Instructions: **104,596,510**.

Last serial output:

```text
(no serial output)
```

### win31-himem-03

Preloaded the supplied Windows 95 floppy HIMEM.SYS through FreeDOS FDCONFIG.SYS, using 16 MB. Stalled during DOS driver initialization before Setup. This run predates the RTC interrupt fix; stopped manually.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name win31-himem-03 --timeout 900 --send '60:\n' --send '120:\n' --send '180:\n' -- build/system-emu/sail-x86-system -ips 4 -m 16 -kbd -b build/bios.bin -hda build/os-boot/win31-himem.img -boot c
```

Wall time: **396.488 s**. Instructions: **73,434,957**.

Last serial output:

```text
(no serial output)
```

### win95-01

The original CD booted its MS-DOS startup image and printed **Starting Windows 95...**, then requested the command interpreter at `A>`. No graphical screen. Also supplied `a:\command.com` through the keyboard at runtime; it did not advance. Stopped manually.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name win95-01 --timeout 900 --send '60:\n' --send '120:\n' --send '180:\n' -- build/system-emu/sail-x86-system -ips 4 -kbd -b build/bios.bin -hda build/os-boot/win95.img -cdrom /home/ruiu/os-images/win95.iso -boot d
```

Wall time: **657.643 s**. Instructions: **115,028,097**.

Last serial output:

```text
(no serial output)
```

### win95-floppy-02

Retried the CD boot image as a physical floppy with the original CD attached and 64 MB RAM. Again reached **Type the name of the Command Interpreter ... A>**; stopped manually.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name win95-floppy-02 --timeout 900 --send '60:\n' --send '120:\n' --send '180:\n' -- build/system-emu/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/win95-boot.img -hda build/os-boot/win95.img -cdrom /home/ruiu/os-images/win95.iso -boot a
```

Wall time: **558.044 s**. Instructions: **100,950,710**.

Last serial output:

```text
(no serial output)
```

## BIOS graphics integration

```sh
python3 system-emu/tests/boot-graphics.py
```

All three BIOS-driven fixtures pass pixel/row checks after the duplicate-ROM
fix: mode 12h at 640x480 (eight test colors), mode 13h at 320x200 (two
colors), and VBE 101h at 640x480 (four colors). PNGs are
`build/os-boot/bios-mode12.png`, `bios-mode13.png`, and `bios-mode101.png`.
These are diagnostic test patterns, not OS screenshots. The fixtures print
`GRAPHICS READY` and deliberately halt with IF clear to trigger capture.
Their simulator exit status 1 is expected; validation checks the marker
and the actual PNG pixels.

### linux-apic-02

**Reached the serial `sail#` shell with local APIC, I/O APIC and ACPI enabled.**
Linux enumerates IOAPIC GSI 0–23, routes the timer through pin 2, reports
`APIC: Switch to symmetric I/O mode setup`, and uses ACPI IRQ routing.
The command line contains neither `noapic` nor `nolapic`.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name linux-apic-02 --timeout 1800 --expect 'sail# ' -- build/system-emu/sail-x86-system -ips 20 -m 64 -b build/bios.bin -cdrom build/os-boot/linux-apic.iso -boot d
```

Wall time: **1135.057 s**. Instructions: **175,907,340**.

Last serial output:

```text
microcode: Current revision: 0x00000000
IPI shorthand broadcast: enabled
sched_clock: Marking stable (16160969400, 10641050)->(6478759450, 9692851000)
Freeing unused kernel image (initmem) memory: 736K
Write protecting the kernel read-only data: 8192k
Freeing unused kernel image (text/rodata gap) memory: 1404K
Freeing unused kernel image (rodata/data gap) memory: 1292K
Run /init as init process

========================================
 Sail x86-64 Emulator - Linux Console
========================================

Type 'help' for a list of built-in commands.
Press Ctrl-a x to exit the emulator.


sail# 
```

### haiku-02

**Reached the graphical Haiku boot logo at 1024x768x32 and 64-bit kernel code.**
The PCI ROM fix makes the framebuffer visible. The boot icons remain gray;
no desktop or COM1 output yet. Stopped to retry with the RTC device.

![Haiku boot logo](os-boot/haiku-boot-logo.png)

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name haiku-02 --timeout 1900 -- build/system-emu/sail-x86-system -ips 4 -m 1024 -b build/bios.bin -cdrom /home/ruiu/os-images/haiku-r1beta5-x86_64-anyboot.iso -boot d
```

Wall time: **1007.848 s**. Instructions: **177,550,506**.

Last serial output:

```text
(no serial output)
```

### win31-rtc-04

Retried FreeDOS with the preloaded Microsoft HIMEM driver and the new RTC device. It remained in real-mode BIOS interrupt stubs during driver initialization, before Windows Setup. The later IRET regression exposed a real-mode NT handling error.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name win31-rtc-04 --timeout 900 --send '60:\n' --send '120:\n' --send '180:\n' -- build/system-emu/sail-x86-system -ips 4 -m 16 -kbd -b build/bios.bin -hda build/os-boot/win31-himem.img -boot c
```

Wall time: **900.466 s**. Instructions: **161,686,646**.

Last serial output:

```text
(no serial output)
```

### win95-rtc-03

Retried the original bootable Windows 95 CD with RTC interrupts. MS-DOS still requested the command interpreter (`Type the name of the Command Interpreter ... A>`), although COMMAND.COM is present on its boot image. No graphical screen.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name win95-rtc-03 --timeout 600 --send '60:\n' --send '120:\n' -- build/system-emu/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95.img -cdrom /home/ruiu/os-images/win95.iso -boot d
```

Wall time: **600.504 s**. Instructions: **104,834,774**.

Last serial output:

```text
(no serial output)
```

### win95-freedos-04

Retried Windows 95 from a FreeDOS hard disk containing HIMEM.SYS and the complete WIN95 directory copied from the CD. AUTOEXEC invokes SETUP. It stalled in BIOS interrupt stubs during HIMEM initialization, before SETUP; no graphical screen.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name win95-freedos-04 --timeout 900 --send '90:\n' --send '150:\n' --send '210:\n' -- build/system-emu/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-freedos.img -boot c
```

Wall time: **900.401 s**. Instructions: **167,204,216**.

Last serial output:

```text
(no serial output)
```

### linux-direct-apic-03

**Reached the serial `sail#` shell using the new default command line.**
Direct bzImage boot also works after removing `noapic nolapic` from both
default command lines. The BIOS/ISO run above separately verifies ACPI
tables and I/O APIC routing.

```sh
system-emu/run-boot.py --name linux-direct-apic-03 --timeout 900 --expect 'sail# ' -- build/system-emu/sail-x86-system -ips 20 -m 64 -i /home/ruiu/os-images/linux-i386/initramfs-i386.cpio build/bzImage
```

Wall time: **749.601 s**. Instructions: **80,070,604**.

Last serial output:

```text
Freeing initrd memory: 1740K
Serial: 8250/16550 driver, 4 ports, IRQ sharing disabled
serial8250: ttyS0 at I/O 0x3f8 (irq = 4, base_baud = 115200) is a 16550A
i8042: PNP: No PS/2 controller found.
i8042: Probing ports directly.
serio: i8042 KBD port at 0x60,0x64 irq 1
intel_pstate: CPU model not supported
input: AT Translated Set 2 keyboard as /devices/platform/i8042/serio0/input/input0
microcode: Current revision: 0x00000000
IPI shorthand broadcast: enabled
sched_clock: Marking stable (2936289150, 7823600)->(2945838300, -1725550)
Freeing unused kernel image (initmem) memory: 736K
Write protecting the kernel read-only data: 8192k
Freeing unused kernel image (text/rodata gap) memory: 1404K
Freeing unused kernel image (rodata/data gap) memory: 1292K
Run /init as init process

========================================
 Sail x86-64 Emulator - Linux Console
========================================

Type 'help' for a list of built-in commands.
Press Ctrl-a x to exit the emulator.


sail# \x1b[6n
```

### freebsd-final-05

Retested with the final RTC and real-mode IRET fixes. BTX still fails before the loader prompt and executes zero-filled memory with `SS=ffff`, `ESP=fffe757f`. Stopped at the configured trace limit. This remains an unsupported boot path; the model has no complete virtual-8086 IRET/interrupt support.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=6000000 SAIL_X86_TRACE_END=8000000 SAIL_X86_TRACE_STEP=100000 system-emu/run-boot.py --name freebsd-final-05 --timeout 180 -- build/system-emu/sail-x86-system -ips 4 -kbd -b build/bios.bin -cdrom /home/ruiu/os-images/FreeBSD-14.5-RELEASE-amd64-disc1.iso -boot d
```

Wall time: **38.244 s**. Instructions: **8,000,000**.

Last serial output:

```text
(no serial output)
```

### win95-iret-05

Retried the original CD after the real-mode NT/IRET fix. It still requests the command interpreter at `A>` instead of starting Setup. Stopped manually to try the installer from the prepared FreeDOS disk.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name win95-iret-05 --timeout 500 --send '60:\n' --send '120:\n' --send '180:\n' -- build/system-emu/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95.img -cdrom /home/ruiu/os-images/win95.iso -boot d
```

Wall time: **151.548 s**. Instructions: **29,880,425**.

Last serial output:

```text
(no serial output)
```

### haiku-rtc-03

Reached the 1024x768x32 Haiku logo with **three boot icons lit**, farther than the pre-RTC run. COM1 remained silent and no desktop appeared. The 1100-second supervisor was temporarily suspended to allow up to 1400 seconds; it resumed when the other final run ended and collected this result.

![Haiku boot progress with RTC](os-boot/haiku-rtc-progress.png)

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name haiku-rtc-03 --timeout 1100 -- build/system-emu/sail-x86-system -ips 4 -m 1024 -b build/bios.bin -cdrom /home/ruiu/os-images/haiku-r1beta5-x86_64-anyboot.iso -boot d
```

Wall time: **1324.351 s**. Instructions: **181,639,311**.

Last serial output:

```text
(no serial output)
```

### reactos-rtc-03

With RTC interrupts, advanced farther into kernel initialization and spent substantial time scanning the HAL PCI name database. The host then aborted with **`z__write_mem: nbytes=108 > 64`** while the guest saved x87 state. There was no text setup welcome screen. Commit `430779d` fixes all four system memory helpers and adds an aligned/noncontiguous-page FNSAVE/FRSTOR regression; that test passes. A full boot with this last fix has not been repeated, since reaching the failure already consumed most of this OS budget. The supervisor was temporarily suspended to permit up to 2300 seconds, then resumed to collect the abort. The instruction count below is the **last captured sample, a lower bound**, because SIGABRT bypassed the final counter print.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name reactos-rtc-03 --timeout 1700 --send '30:\n' -- build/system-emu/sail-x86-system -ips 4 -m 128 -kbd -b build/bios.bin -cdrom build/os-boot/reactos-setup.iso -boot d
```

Wall time: **1960.637 s**. Instructions: **380,279,608**.

Last serial output:

```text
(/srv/buildbot/worker_data/Build_GCCLin_x86/build/boot/freeldr/freeldr/arch/i386/hwpci.c:111) err: No valid routing table found!
```

### win95-iret-freedos-06

The IRET fix allows HIMEM and FreeDOS startup to complete, and **Windows 95 Setup starts**. Its ScanDisk stage reports **`run-time error R6002 - floating-point support not loaded`**, then asks to quit Setup. The supplied `SETUP.TXT` documents `setup /is`; this command was sent at the keyboard after an attempt to exit Setup, but the last visible screen remained the error and no graphical screen appeared. This is a failed graphics boot, not a completed Windows installation. The 500-second supervisor was temporarily suspended to permit 631 seconds, keeping cumulative Windows 95 boot time below about one hour.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name win95-iret-freedos-06 --timeout 500 --send '60:\n' --send '120:\n' --send '180:\n' --send '240:\n' --send '300:\n' --send '360:\n' -- build/system-emu/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-freedos.img -boot c
```

Wall time: **634.899 s**. Instructions: **113,627,584**.

Last serial output:

```text
(no serial output)
```

Additional keyboard input, seconds from emulator launch:

- 271.610 s: `<Enter>` — Continue the Windows 95 Setup system check.
- 319.010 s: `<Enter>` — Exit Setup after ScanDisk R6002; SETUP.TXT documents retrying with /IS.
- 344.210 s: `setup /is<Enter>` — Retry with the ScanDisk bypass documented in the supplied SETUP.TXT.

### win31-iret-05

The SDM-backed real-mode IRET fix unblocks HIMEM. Windows 3.1 Setup reaches the Express Setup choice, copies the first-stage files, then reports **Invalid Opcode** while starting Windows for graphical setup. At the returned `C:\WINDOWS>` prompt, `win /s` reports **Bad command or filename**; this installation has not produced a runnable WIN.COM. No graphical Windows screen or Windows PNG was obtained. The 500-second supervisor was temporarily suspended to allow 988 seconds, keeping cumulative Windows 3.1 boot time below about one hour.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name win31-iret-05 --timeout 500 --send '60:\n' --send '120:\n' --send '180:\n' -- build/system-emu/sail-x86-system -ips 4 -m 16 -kbd -b build/bios.bin -hda build/os-boot/win31-himem.img -boot c
```

Wall time: **991.583 s**. Instructions: **160,730,983**.

Last serial output:

```text
(no serial output)
```

Last VGA text:

```text
Invalid Opcode at 0B3E 0078 0046 3579 2C70 3540 004A 42B0 42B0 0100 00DB 1FFE 0000
C:\WINDOWS>win /s
Bad command or filename - "win".
```

Additional keyboard input, seconds from emulator launch:

- 226.940 s: `<Enter>`.
- 861.680 s: `win /s<Enter>`.
