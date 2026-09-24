# Task: boot more operating systems on the Sail x86-64 system emulator

You are working in a git worktree of sail-x86 (this directory). The Sail
model in model/ is compiled by the official Sail compiler into a C++
emulator (system-emu/, binary build/system-emu/sail-x86-system after
`cmake -B build && cmake --build build -j128 --target sail-x86-system`;
the first build compiles the whole model and takes several minutes). The
emulator boots a Linux bzImage directly (`sail-x86-system -i initramfs
bzImage`) or a BIOS image with disks (`-b build/bios.bin -hda disk.img
-fda floppy.img -cdrom image.iso -boot c|d`, `-vga` for the text display,
`-ips N` for the virtual CPU speed in MIPS, see `--help`). SeaBIOS is built
by system-emu/mk-freedos.sh (its .config is in that script; it also makes
build/freedos.img and build/vgabios.bin). Devices live in
system-emu/devices.h (UART, VGA text, 8259 PIC, PIT, keyboard, CMOS, PCI
config space with i440FX/PIIX3 IDE/VGA devices, fw_cfg, IDE with ATA disk
and ATAPI CD-ROM, DMA, floppy), port I/O is dispatched in
system-emu/x86-externals.cpp (z__port_in8/out8...), interrupts are polled
in z__check_pending_irq there, and system-emu/x86-system-sim.cpp parses
options and loads images. There is no local APIC, no I/O APIC, no HPET, no
ACPI or MP tables, and no graphics mode (text mode only). Linux is booted
with `noapic nolapic`.

Images are in /home/ruiu/os-images: alpine-virt-3.24.2-x86_64.iso (Linux,
already used for the CD-ROM work), reactos-bootcd-0.4.17-dev-*.iso
(ReactOS; its first-stage setup runs in text mode), FreeBSD-14.5-RELEASE-
amd64-disc1.iso, haiku-r1beta5-x86_64-anyboot.iso, xv6-public/ (built:
xv6.img is the boot disk, fs.img the file system; xv6 needs a local APIC,
an I/O APIC and an MP table, otherwise it panics "Expect to run on an
SMP"), win31.iso and win95.iso (Windows 3.1 and 95 install media; both
need a VGA graphics mode, Windows 3.1 also needs DOS, and FreeDOS is in
build/freedos.img), linux-i386/bzImage-i386 + initramfs-i386.cpio (a
32-bit kernel; boots with `-ips 4` or so).

Goal, in this order; report how far each OS gets even when it fails:

1. Local APIC (xAPIC at 0xFEE00000: ID, version, TPR, EOI, SVR, LVT timer
   with one-shot/periodic modes and the divide register, LVT LINT0/LINT1,
   ICR for self-IPI, ISR/IRR/TMR, ESR; x2APIC MSRs are optional) and I/O
   APIC (0xFEC00000, IOREGSEL/IOWIN, 24 redirection entries routing the
   PIC-level IRQs; masked entries; edge and level) in the C++ emulator,
   wired into z__check_pending_irq so that either the PIC or the APIC
   delivers external interrupts as Linux, xv6 and Windows expect. The
   model side already has IA32_APIC_BASE (system-emu/x86-externals.cpp
   z__rdmsr) and the CPU's interrupt entry; keep any change under model/
   to what the Intel SDM states (Vol. 3A chapter 12 for the APIC), cite
   the section in the commit message, and add a regression test. SeaBIOS:
   turn on CONFIG_MPTABLE=y (and CONFIG_ACPI=y if its built-in tables work
   without QEMU's fw_cfg tables; SeaBIOS builds a PIIX4-style DSDT itself
   when fw_cfg provides none) in mk-freedos.sh and rebuild bios.bin. Then
   boot xv6 (`-b build/bios.bin -hda xv6.img -hdb fs.img`, xv6 uses the
   second IDE drive for fs.img; add -hdb if the emulator lacks it) to its
   `$` shell prompt on the serial console, and check that Linux boots
   without `noapic nolapic`.

2. VBE linear framebuffer: implement the Bochs VBE "DISPI" interface
   (I/O ports 0x1CE index / 0x1CF data: ID, XRES, YRES, BPP, ENABLE,
   BANK, VIRT_WIDTH/HEIGHT, X/Y_OFFSET) with a linear framebuffer at the
   PCI VGA device's BAR (SeaVGABIOS's bochs-display/vgabios "stdvga" build
   expects LFB at 0xE0000000 or the BAR value; check which vgabios
   system-emu/mk-freedos.sh builds and choose the matching variant, the
   Bochs VBE one), plus a way to dump the framebuffer to a PNG
   (e.g. SIGUSR2 writes framebuffer.png; write a minimal PNG encoder or
   PPM). Then boot Haiku (anyboot ISO; its boot loader uses VBE; serial
   debug output on COM1 shows progress), ReactOS (BootCD: text-mode setup
   first; its LiveCD/GUI needs VBE), and FreeBSD disc1 (serial console:
   at the loader prompt `set console=comconsole` then `boot -s` for a
   single-user shell; the BTX loader runs BIOS calls in virtual-8086
   mode).

3. Planar VGA graphics (mode 12h 640x480x16 and mode 13h 320x200x256:
   sequencer map mask, graphics controller read/write modes, set/reset,
   bit mask, planar memory at 0xA0000, DAC palette) so that Windows 3.1
   (install from win31.iso onto the FreeDOS disk: `-cdrom win31.iso`
   with FreeDOS booted from -hda, then run SETUP; it needs a CD-ROM
   driver in DOS, or copy the files onto the disk image with mtools from
   the host instead) and Windows 95 (boot win95.iso: it is a bootable
   install CD) reach their first graphical screen; dump it to PNG.

Rules: work only in this worktree; commit each device or fix as its own
commit with a test where a test is feasible (system-emu/tests has device
tests; the KVM harness in kvm/ is for instruction behavior against real
hardware); never change model/*.sail unless the SDM text supports it (the
SDM text is at /tmp/claude-1000/-home-ruiu-papers-sail-x86/93122f0a-0514-47a5-9dbe-2d1377a6b02e/scratchpad/sdm/sdm-090.txt;
grep for section titles) and then commit the model change together with
its test; end every commit message with the line
`Co-Authored-By: Codex <noreply@openai.com>`. Do not spend more than
about an hour on any one OS; record the last serial output, instruction
count and wall time of each attempt in docs/os-boot-results.md (create
it) with the exact command lines, and commit that file too. Use up to 128
threads for builds. Do not touch anything outside this worktree except
reading /home/ruiu/os-images and the SDM text.
