# Alpine Linux 3.24.2 (virt) from CD-ROM — 2026-09-25

Image: `alpine-virt-3.24.2-x86_64.iso` (69,206,016 bytes, sha256
3ab424762af704b2c2a9e57df1dc37f982af260071504d977f2fb96822e7130b),
kernel 6.18.52-0-virt (HZ=1000, tickless, SMP build, ISOLINUX 6.04-pre1).

Emulator: `system-emu/` at d2a8d70 linked against the model at 98eafe6
compiled with sail-llvm (`sailc --cpp -O3 --mcpu=native`, 24 s), SeaBIOS
1.16.3 built by `mk-freedos.sh` with CONFIG_CDROM_BOOT=y, CONFIG_CDROM_EMU=y,
CONFIG_SERIAL=y.  Host: Threadripper 7980X.

    sail-x86-system -m 512 -ips 20 -b bios.bin -cdrom alpine-virt-3.24.2-x86_64.iso

and at the ISOLINUX `boot:` prompt (echoed on the serial console; the ISO's
syslinux.cfg has `SERIAL 0 115200`):

    /boot/vmlinuz-virt initrd=/boot/initramfs-virt console=ttyS0
        modules=loop,squashfs,sd-mod,usb-storage noapic nolapic tsc=reliable nokaslr

`noapic nolapic` because the platform has no local APIC or I/O APIC;
`-ips 20` because at the default 1 MIPS a HZ=1000 kernel never leaves its
timer interrupt.

## How far it gets

| milestone (serial console)                          | wall time | guest time |
|-----------------------------------------------------|-----------|------------|
| SeaBIOS boots the El Torito image, ISOLINUX prompt  | 2.5 s     |            |
| kernel + initramfs (12.6 MB + 9.8 MB) read by PIO   | ~130 s    |            |
| `Linux version 6.18.52-0-virt`                      | 135 s     | 0 s        |
| `printk: legacy console [ttyS0] enabled`            |           | 83 s (*)   |
| `ata2.00: ATAPI: Sail-x86 CD-ROM, 1.0, max PIO4`    |           | 21.6 s     |
| `scsi 1:0:0:0: CD-ROM SAIL Sail-x86 CD-ROM 1.0`     |           | 21.6 s     |
| `Run /init as init process`, `Alpine Init 3.14.1`   | ~8 min    | 56 s       |
| `sr 1:0:0:0: [sr0] scsi3-mmc drive`, cdrom driver   | ~9 min    | 66.5 s     |
| `Mounting boot media:` (nlplug-findfs)              | stays here |           |

(*) guest time restarts when the kernel switches clocksource.

Instruction counts: 2,189,593,529 when stopped after 25 min of wall time
(run 9); 2,277,987,704 after 27 min (run 10, with `debug_init`).  The
kernel boot to `/init` is ~2.1 G instructions; after that the guest is
almost always halted.

The CD-ROM device is exercised end to end: SeaBIOS reads the boot
catalog and ISOLINUX by PACKET READ(10) in 2048-byte DRQ blocks, ISOLINUX
reads 22 MB through INT 13h, libata probes the drive (IDENTIFY PACKET
DEVICE, SET FEATURES), the sr driver opens it (TEST UNIT READY, INQUIRY,
READ CAPACITY, READ TOC formats 0/1 with MSF, GET CONFIGURATION, MODE
SENSE(10) page 2Ah; READ DISC INFORMATION and GET EVENT STATUS
NOTIFICATION answered CHECK CONDITION and REQUEST SENSE), and
nlplug-findfs's blkid probe reads 361 sectors of the ISO with 8192-byte
DRQ blocks and interrupts per block.

## Where it stops, and why

nlplug-findfs (`-d` output with `debug_init`) replays every coldplug
uevent through `/sbin/mdev`, one child at a time: ~700 events for this
kernel.  Each spawn takes about 100 s of wall time while the CPU sits in
`pv_native_safe_halt` (SIGUSR1 samples; 2.78 M instructions in 10 s of
wall time), so the whole pass would take many hours; three earlier runs
were stopped at this point after 10-25 minutes before the cause was
clear.  The kernel is healthy: the PIT is in one-shot mode, the TSC is
the clocksource, timers expire, and the device has no outstanding
command.  What each mdev child waits ~100 s of guest time for is the
open question; it is not the CD-ROM (no command is pending) and not the
CPU (it is halted).  Candidates: the halted-loop timing (`poll` at 1 ms
per PIT tick and the TSC stepped by one tick, added in d2a8d70) still not
matching what a tickless kernel expects, or a slow path in fork/exec at
this emulation speed.  `SIGUSR1` and `SAIL_X86_IDE_TRACE` are the tools.

## Last 30 serial lines (run 9)

    [   21.710261] IPI shorthand broadcast: enabled
    [   22.149612] sched_clock: Marking stable (22081170800, 67882200)->(22156031750, -6978750)
    [   23.269440] registered taskstats version 1
    [   23.295760] Loading compiled-in X.509 certificates
    [   52.427583] Freeing initrd memory: 9612K
    [   53.861552] Loaded X.509 cert 'alpinelinux.org: Alpine Linux kernel key: d76a695f66ad9cd28f5c22a8508f36e91f521f7a'
    [   54.419800] Demotion targets for Node 0: null
    [   54.429680] Key type .fscrypt registered
    [   54.430447] Key type fscrypt-provisioning registered
    [   55.935870] Freeing unused kernel image (initmem) memory: 3008K
    [   55.947518] Write protecting the kernel read-only data: 26624k
    [   56.078194] Freeing unused kernel image (text/rodata gap) memory: 1692K
    [   56.106734] Freeing unused kernel image (rodata/data gap) memory: 368K
    [   56.109744] rodata_test: all tests were successful
    [   56.117661] Run /init as init process
    [   57.797781] Alpine Init 3.14.1-r0
    Alpine Init 3.14.1-r0
    [   57.847428] Loading boot drivers...
     * Loading boot drivers: [   58.858663] loop: module loaded
    [   59.341750] squashfs: version 4.0 (2009/01/31) Phillip Lougher
    [   61.381624] usbcore: registered new interface driver usbfs
    [   61.384406] usbcore: registered new interface driver hub
    [   61.386464] usbcore: registered new device driver usb
    [   61.969155] usbcore: registered new interface driver usb-storage
    [   62.046478] Loading boot drivers: ok.
    ok.
    [   62.262919] Mounting boot media...
     * Mounting boot media: [   66.499451] sr 1:0:0:0: [sr0] scsi3-mmc drive: 4x/4x xa/form2 tray
    [   66.502337] cdrom: Uniform CD-ROM driver Revision: 3.20
    sail-x86-system: exited after 2189593529 instructions

## What the platform still lacks for other guests

- No local APIC (0xFEE00000 reads 0xFF; CPUID.1:EDX still advertises
  APIC) and no I/O APIC, MP table or ACPI tables (SeaBIOS is built with
  CONFIG_ACPI=n, CONFIG_MPTABLE=n): Linux needs `noapic nolapic`; xv6,
  FreeBSD and Windows want at least a LAPIC and an MP table or ACPI.
- VGA text mode only: no VBE, no planar/graphics modes (Haiku, Windows).
- One CD-ROM (secondary master) and one hard disk (primary master); no
  slaves, no DMA (SeaBIOS CONFIG_ATA_DMA=n, PCI BAR4 zero).
- Virtual CPU speed is `-ips`; the halted-wait loop advances one PIT tick
  (1 ms) per millisecond of wall time.
- ATAPI: READ CD, READ SUB-CHANNEL, MECHANISM STATUS, GET EVENT STATUS
  NOTIFICATION, READ DISC INFORMATION and MODE SENSE(6) answer CHECK
  CONDITION (ILLEGAL REQUEST); Linux copes, other guests may want them.
