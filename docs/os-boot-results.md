# Operating-system boot results

Worktree: `sail-x86-os`. All disk images used for writes are copies under
`build/os-boot`; original media under `/home/ruiu/os-images` are read only.
The machine has one CPU, xAPIC, a 24-input I/O APIC, SeaBIOS MP/ACPI tables,
a PIIX4 PM timer, two primary IDE disks, an ATAPI CD-ROM, Bochs VBE and
planar VGA. It has no HPET or additional CPUs.

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
cmake --build build -j128 --target system_test_apic system_test_ide \
  system_test_fw_cfg system_test_vbe system_test_vga
ctest --test-dir build -R 'system_(apic|ide|fw_cfg|vbe|vga|png)$' --output-on-failure
```

All six device/PNG tests pass. Coverage includes APIC priorities, self-IPIs,
timer modes/divisors, edge/level routing and EOI; independent IDE master/slave
transfers; fw_cfg topology; PM timer/ACPI mode; PCI BAR remapping; framebuffer
formats/banking/offsets; PNG CRC and decompression; VGA latches/write modes,
chain-4 and palettes; SMRAM and option-ROM shadow separation.

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
