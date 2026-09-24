# Operating-system boots: worktree B

Worktree `/home/ruiu/sail-x86-os2`, branch `os-boot-b`, starting at
`365a211`. Work began 2026-09-24 21:51 UTC (September 25 in Japan).
All runs use the fast `build/llvm/sail-x86-system`, rebuilt with
`system-emu/build-llvm.sh` after emulator/model changes. Builds use at most
64 processes. Original media and the other worktree are read only.
No KVM harness, ReactOS, Windows 3.1, FreeBSD or virtual-8086 work is included.

## Status (investigation in progress)

| OS | Farthest progress | Current blocker |
|---|---|---|
| Windows 95 | ScanDisk repair screen; `SETUP /IS` copies files and enters protected mode | MS-DOS extender fault-handling loop, under investigation |
| Haiku R1 beta 5 x86-64 | Four boot icons lit; kernel reads boot CD through PCI IDE | Long run in progress; no normal COM1 output yet |

These are actual guest captures, not graphics test patterns:
[ScanDisk after XLAT fix](os-boot/b-win95-xlat-setup.png),
[Windows Setup after LMSW fix](os-boot/b-win95-lmsw.png), and
[Haiku after IDE fix](os-boot/b-haiku-pio.png).

## Windows 95 R6002 diagnosis

The proposed x87 checks all succeed. R6002 is also the runtime's fallback
for calling a floating-point formatter that was not linked into the
program. Here an incorrect XLAT result sends an ordinary string format
through that fallback. It does not indicate absent x87 hardware.

* BIOS equipment word at physical `0x410`: `0x0222`, coprocessor bit 1 set.
  SeaBIOS `mathcp_setup()` explicitly sets it.
* CR0 is `0x30`: EM=0, MP=0, NE=1, before and during the real-mode probe.
* `FNINIT; FNSTCW` stores `0x037f`; masking with `0x0f3f` gives the runtime's
  expected `0x033f`. `FNSTSW` reports zero. The runtime records an x87.
* The runtime installs INT 34h–3Bh at `4f4f:0833`, INT 3Ch at `4f4f:07fe`
  and INT 3Dh at `4f4f:082b` in the direct ScanDisk diagnostic image.
  An INT 37h fixup is observed at instruction 37,358,192. Its handler
  patches an INT-encoded instruction into NOP plus FILD; the FILD executes.
* At `4ae7:1c9a`, XLAT looks up the class of `%` while formatting
  `%c:\DRVSPACE.000`. DS=`56c0`, BX=`225c`, AL=`05`. The model reads physical
  `0x2261` (value `0x70`) instead of DS-relative `0x58e61` (value `0x01`).
  At instruction 37,702,513 the corrupted parser calls the floating-point
  stub through `[22d2]`; `4ae7:1772` loads error number 2, producing R6002.

`fa44d95` fixes XLAT to use DS or the selected segment override, truncate
the effective offset to the address size, and use normal segmented memory
access. Intel SDM revision 090 Vol.2D, XLAT/XLATB pp.6-37–6-38 and Vol.1
section 3.3.7 were read before changing the model. The same commit adds
regressions for nonzero DS, ES override, unsigned AL, register/flag
preservation, 16/32-bit offset wrap, and segment-limit faults. Both new
tests fail before the fix; all 64 basic cases pass afterward.

The next setup attempt reaches ScanDisk's report that `KERNEL.SYS` has an
incorrect file size. Subsequent diagnosis uses the CD's documented
`SETUP /IS` option on a separate local disk copy to skip ScanDisk.

## Windows 95 protected-mode entry

After file copying, `LMSW AX` at `558c:0adf` sets CR0.PE but the model's
separate execution-mode state remains real mode. The following far jump
to `0078:0b0e` consequently uses real-mode base `0x0780`, enters zero-filled
RAM and eventually raises invalid opcode. Trace instruction 108,919,071
identifies the mode-changing LMSW.

`3247480` makes LMSW enter protected mode when it sets PE in real mode.
Intel SDM revision 090 Vol.2A, LMSW pp.3-560–3-561 explicitly specifies this
transition. Its regressions cover register and memory operands, an
operand-size prefix, a subsequent far jump using a nonzero descriptor
base, ignored high source bits, sticky PE, and unchanged long mode.
The new protected-mode regression fails before the fix. All 14 C++ system
tests and the separate PNG test pass after it (66 basic cases).

## Haiku PCI IDE diagnosis

The first serial investigation enters Haiku's kernel debugger and reads
`syslog`. The kernel panics because it cannot find a boot partition.
The preceding device log identifies the cause:

```text
PCI-ATA: Controller detection failed! bus master base not configured
```

The emulated PIIX IDE function exposes no BAR4, so the Haiku PCI ATA driver
rejects the entire controller even though the disks advertise PIO only.
[Haiku's r1beta5 driver](https://github.com/haiku/haiku/blob/r1beta5/src/add-ons/kernel/busses/ata/generic_ide_pci/generic_ide_pci.cpp)
also checks the bus-master interrupt-status bit for PIO interrupts.

`cd45ba3` implements PIIX BAR4 and the command/status/PRDT registers,
including a latched interrupt indication for PIO and W1C acknowledgement.
Devices still advertise PIO only. The implementation follows the
[Intel PIIX datasheet](https://www.mouser.com/catalog/specsheets/intel%20corporation_29055002.pdf),
sections 2.3.9 and 2.7.1–2.7.3: the I/O base is 16 bits, the region is
16-byte aligned, and interrupt status latches an IDE interrupt edge.
It does not implement DMA transfers or advertise DMA capability.

SeaBIOS 1.16.3 initially mistakes this 16-bit I/O BAR's size for
`0xffff0010`, and aborts with insufficient PCI I/O space. The same commit
adds an idempotently applied firmware patch to mask I/O BAR sizes to 16
bits. Rebuilt firmware assigns BAR4 at `0xc000`. Device tests cover BAR
sizing/relocation/I/O enable, IRQ latching and clearing, channel isolation,
and register masks. A BIOS-level assembly fixture enumerates the BAR and
prints `IDE PCI BAR READY`; it passes on the fast binary.

After this fix, Haiku reaches four icons and issues repeated successful
ATAPI READ(10) requests. The previous three-icon/no-boot-partition failure
is resolved. Kernel output and the final boot outcome are still being
investigated.

## Image preparation and reproduction

`win95-freedos.img` is copied from the other worktree into `build/os-boot`
here. Its FAT16 partition begins at byte 1048576. Files are edited with
mtools only while no emulator is writing the image. `win95-diag.img` is a
copy whose AUTOEXEC runs `C:\WIN95\SCANDISK /TEXT /ALL`; an initial probe
used unsupported `/CHECKONLY` and exited without testing the failing path.
`win95-setup-is.img` is a separate copy whose AUTOEXEC runs `SETUP /IS`.
HIMEM.SYS remains loaded by FDCONFIG.SYS.

`haiku-b.iso` is copied from
`/home/ruiu/os-images/haiku-r1beta5-x86_64-anyboot.iso`. At byte `0xa600388`,
the 25-byte string `serial_debug_output false` is replaced with
`serial_debug_output true ` in the copy. This settings edit alone has not
enabled normal kernel logging, so it must not be treated as verified.
Kernel debugger output does reach COM1. Original media is unchanged.

The original local BIOS is retained as `build/os-boot/bios-before-io-bar.bin`.
SeaBIOS sources were copied from the other worktree and rebuilt locally;
the firmware used after `cd45ba3` includes the I/O BAR sizing patch.

The runner saves `.json`, `.stderr`, `.serial`, `.ram` and `.png` under
`build/os-boot`. SIGUSR1 captures live CPU/device state, RAM and screenshot.
Trace instruction counts include interrupt entries. Serial files can be
empty; firmware port-E9 logging is in stderr, not COM1. Manual inputs are
recorded in `.input.json` where available. Ctrl-a s switches stdin to
serial, and Ctrl-a k back to the keyboard.

## Attempts

The following section is updated from the runner's measured artifacts.

<!-- measured-attempts -->

### b-win95-baseline

Reproduces the R6002 screen with the initial binary and BIOS. Stops at the trace end.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=0 SAIL_X86_TRACE_END=120000000 SAIL_X86_TRACE_STEP=1000000 system-emu/run-boot.py --name b-win95-baseline --timeout 120 --send '15:\n' --send '30:\n' -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-freedos.img -boot c
```

Wall: **22.609 s**. Instructions: **120,000,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-haiku-menu

Initial space-key attempt does not enter the boot menu. Stopped manually to inspect image settings.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name b-haiku-menu --timeout 300 --send '1: ' --send '2: ' --send '3: ' --send '4: ' -- build/llvm/sail-x86-system -ips 4 -m 1024 -kbd -b build/bios.bin -cdrom build/os-boot/haiku-b.iso -boot d
```

Wall: **73.034 s**. Instructions: **254,259,077**. Runner result: `exit`, exit `0`.

Last serial output:

```text
<kernel_x86_64> arch_debug_call_with_fault_handler() + 0x1a
 1 ffffffff81ab49a0 (+  80) ffffffff800b04e8   <kernel_x86_64> debug_call_with_fault_handler() + 0x78
 2 ffffffff81ab4a00 (+  96) ffffffff800b1b94   <kernel_x86_64> _ZL20kernel_debugger_loopPKcS0_P13__va_list_tagi() + 0xf4
 3 ffffffff81ab4a50 (+  80) ffffffff800b1f2e   <kernel_x86_64> _ZL24kernel_debugger_internalPKcS0_P13__va_list_tagi() + 0x6e
 4 ffffffff81ab4b40 (+ 240) ffffffff800b22c7   <kernel_x86_64> panic() + 0xb7
 5 ffffffff81ab4f60 (+1056) ffffffff801093b7   <kernel_x86_64> vfs_mount_boot_file_system() + 0x167
 6 ffffffff81ab4fb0 (+  80) ffffffff80065aa9   <kernel_x86_64> _ZL5main2Pv() + 0x99
 7 ffffffff81ab4fd0 (+  32) ffffffff8008d0a6   <kernel_x86_64> _ZL19common_thread_entryPv() + 0x36
 8 0000000000000000 (+   0) ffffffff81ab4fe0   97:main2_14_kstack@0xffffffff81ab0000 + 0x4fe0
initial commands:  syslog | tail 15
PCI:   Capabilities: (not supported)
get_boot_partitions(): boot volume message:
KMessage: buffer: 0xffffffff821c18f8 (size/capacity: 315/315), flags: 0xa
  field: "booted from image" (BOOL): true
  field: "partition offset"  (LLNG): 0 (0x0)
  field: "boot method"       (LONG): 1 (0x1)
  field: "boot drive number" (LLNG): 0 (0x0)
  field: "disk identifier"   (RAWT): data at 0xffffffff821c19e4, 79 bytes
get_boot_partitions(): boot method type: 1
intel: ep_std_ops(0x1)
intel: ep_std_ops(0x2)
intel: pm_std_ops(0x1)
intel: pm_std_ops(0x2)
PCI-ATA: Controller detection failed! bus master base not configured
KDiskDeviceManager::InitialDeviceScan() returned error: No such file or directory
kdebug>
```

### b-win95-scandisk

Initial direct ScanDisk invocation uses unsupported /CHECKONLY; exits without reproducing R6002. The selected FPU address belongs to another load layout and is not reached.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=0 SAIL_X86_TRACE_END=70000000 SAIL_X86_TRACE_STEP=500000 SAIL_X86_TRACE_ADDRESS=0x52440 system-emu/run-boot.py --name b-win95-scandisk --timeout 100 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-diag.img -boot c
```

Wall: **13.208 s**. Instructions: **70,000,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-fpu-probe

Locates FNINIT at instruction 19,118,044. Still uses the non-reproducing /CHECKONLY invocation.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=0 SAIL_X86_TRACE_END=40000000 SAIL_X86_TRACE_STEP=1000000 SAIL_X86_TRACE_ADDRESS=0x4f5e0 system-emu/run-boot.py --name b-win95-fpu-probe --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-diag.img -boot c
```

Wall: **7.604 s**. Instructions: **40,000,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-fpu-trace

Single-step trace proves the x87 probe and interrupt-vector installation succeed.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=19118040 SAIL_X86_TRACE_END=19125000 SAIL_X86_TRACE_STEP=1 system-emu/run-boot.py --name b-win95-fpu-trace --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-diag.img -boot c
```

Wall: **3.802 s**. Instructions: **19,125,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-fixup-probe

The unsupported ScanDisk invocation does not exercise the selected interrupt fixup.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=19120000 SAIL_X86_TRACE_END=25000000 SAIL_X86_TRACE_STEP=10000 SAIL_X86_TRACE_ADDRESS=0x4fd23 system-emu/run-boot.py --name b-win95-fixup-probe --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-diag.img -boot c
```

Wall: **4.603 s**. Instructions: **25,000,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-scandisk-text

SCANDISK /TEXT /ALL reproduces R6002 and reaches the x87 INT fixup.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=0 SAIL_X86_TRACE_END=40000000 SAIL_X86_TRACE_STEP=1000000 SAIL_X86_TRACE_ADDRESS=0x4fd23 system-emu/run-boot.py --name b-win95-scandisk-text --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-diag.img -boot c
```

Wall: **7.603 s**. Instructions: **40,000,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-fixup-trace

Single-step trace proves the INT 37h fixup patches and executes FILD.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=37358170 SAIL_X86_TRACE_END=37370000 SAIL_X86_TRACE_STEP=1 system-emu/run-boot.py --name b-win95-fixup-trace --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-diag.img -boot c
```

Wall: **7.604 s**. Instructions: **37,370,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-haiku-serial

Three icons; kernel debugger reports no boot partitions. COM1 syslog identifies the missing IDE bus-master BAR. Stopped manually after diagnosis. After the logged Ctrl-a s/syslog input, q and `syslog | tail 120` were also sent while paging.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name b-haiku-serial --timeout 1800 -- build/llvm/sail-x86-system -ips 4 -m 1024 -kbd -b build/bios.bin -cdrom build/os-boot/haiku-b.iso -boot d
```

Wall: **266.896 s**. Instructions: **1,370,189,381**. Runner result: `exit`, exit `0`.

Last serial output:

```text
000, flags 00
PCI:   base reg 1: host 00000000, pci 00000000, size 00000000, flags 00
PCI:   base reg 2: host 00000000, pci 00000000, size 00000000, flags 00
PCI:   base reg 3: host 00000000, pci 00000000, size 00000000, flags 00
PCI:   base reg 4: host 00000000, pci 00000000, size 00000000, flags 00
PCI:   base reg 5: host 00000000, pci 00000000, size 00000000, flags 00
PCI:   Capabilities: (not supported)
PCI: [dom 0, bus  0] bus   0, device  1, function  0: vendor 8086, device 7000, revision 00
PCI:   class_base 06, class_function 01, class_api 00
PCI:   vendor 8086: Intel Corporation
PCI:   device 7000: 82371SB PIIX3 ISA [Natoma/Triton II]
PCI:   info: Bridge (ISA bridge)
PCI:   line_size 00, latency 00, header_type 80, BIST 00
PCI:   ROM base host 00000000, pci 00000000, size 00000000
PCI:   cardbus_CIS 00000000, subsystem_id 0000, subsystem_vendor_id 0000
PCI:   interrupt_line 00, interrupt_pin 00, min_grant 00, max_latency 00
PCI:   base reg 0: host 00000000, pci 00000000, size 00000000, flags 00
PCI:   base reg 1: host 00000000, pci 00000000, size 00000000, flags 00
PCI:   base reg 2: host 00000000, pci 00000000, size 00000000, flags 00
PCI:   base reg 3: host 00000000, pci 00000000, size 00000000, flags 00
PCI:   base reg 4: host 00000000, pci 00000000, size 00000000, flags 00
PCI:   base reg 5: host 00000000, pci 00000000, size 00000000, flags 00
PCI:   Capabilities: (not supported)
PCI: [dom 0, bus  0] bus   0, device  1, function  1: vendor 8086, device 7010, revision 00
PCI:   class_base 01, class_function 01, class_api 80
PCI:   vendor 8086: Intel Corporation
```

Additional manual inputs:

* 2026-09-24 21:55:33: `Ctrl-a s; syslog<Enter>`

### b-win95-format-probe

Locates the format parser XLAT at instruction 37,701,905.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=37000000 SAIL_X86_TRACE_END=40000000 SAIL_X86_TRACE_STEP=100000 SAIL_X86_TRACE_ADDRESS=0x4cb0a system-emu/run-boot.py --name b-win95-format-probe --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-diag.img -boot c
```

Wall: **7.604 s**. Instructions: **40,000,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-format-trace

Single-step trace ties the wrong XLAT lookup to the floating-point formatter stub and R6002.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=37701900 SAIL_X86_TRACE_END=37704000 SAIL_X86_TRACE_STEP=1 system-emu/run-boot.py --name b-win95-format-trace --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-diag.img -boot c
```

Wall: **7.004 s**. Instructions: **37,704,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-xlat-setup

After XLAT fix, ScanDisk reaches a repair dialog for KERNEL.SYS. Enter and f/Enter do not advance it. Stopped manually; no R6002. The final f/Enter input was not separately timestamped.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name b-win95-xlat-setup --timeout 900 --send '10:\n' --send '25:\n' --send '45:\n' -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-freedos.img -boot c
```

Wall: **176.868 s**. Instructions: **966,174,046**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

Additional manual inputs:

* 2026-09-24 22:02:33: `Enter: ScanDisk Fix It on local disk copy`

### b-haiku-ide-bar

New IDE BAR with old firmware: SeaBIOS rejects the miscalculated I/O resource size and exits. This motivates the firmware patch.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_IDE_TRACE=1 system-emu/run-boot.py --name b-haiku-ide-bar --timeout 1800 -- build/llvm/sail-x86-system -ips 4 -m 1024 -kbd -b build/bios.bin -cdrom build/os-boot/haiku-b.iso -boot d
```

Wall: **1.401 s**. Instructions: **126,997**. Runner result: `exit`, exit `1`.

Last serial output:

```text
(no serial output)
```

### b-win95-xlat-is

SETUP /IS skips ScanDisk, copies setup files, then prints Invalid Opcode. This is before the LMSW fix. Stopped after diagnosis.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_REAL_UD=1 system-emu/run-boot.py --name b-win95-xlat-is --timeout 900 --send '10:\n' --send '30:\n' -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-setup-is.img -boot c
```

Wall: **139.461 s**. Instructions: **686,423,081**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

Additional manual inputs:

* 2026-09-24 22:06:49 UTC: `setup /is\n`

### b-win95-ud-probe

The IVT6 trace captures LMSW setting CR0.PE without changing execution mode, followed by a far jump into the wrong memory.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=0 SAIL_X86_TRACE_END=200000000 SAIL_X86_TRACE_STEP=1000000 SAIL_X86_TRACE_ADDRESS=0x2042 system-emu/run-boot.py --name b-win95-ud-probe --timeout 120 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-setup-is.img -boot c
```

Wall: **40.221 s**. Instructions: **200,000,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-lmsw

After LMSW fix, execution enters protected mode. Remains in the MS-DOS extender error-formatting path; stopped manually for diagnosis.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_REAL_UD=1 system-emu/run-boot.py --name b-win95-lmsw --timeout 900 --send '15:\n' --send '45:\n' -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-setup-is.img -boot c
```

Wall: **312.390 s**. Instructions: **1,932,453,330**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-pm-loop

Instruction-window trace of the extender loop. The current code is formatting hexadecimal error information.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=130000000 SAIL_X86_TRACE_END=130000050 SAIL_X86_TRACE_STEP=1 system-emu/run-boot.py --name b-win95-pm-loop --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-setup-is.img -boot c
```

Wall: **28.016 s**. Instructions: **130,000,050**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-pm-fault

The selected address is not reached in this run; stops in a different protected-mode fault path at 0070:11f6.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=0 SAIL_X86_TRACE_END=150000000 SAIL_X86_TRACE_STEP=1000000 SAIL_X86_TRACE_ADDRESS=0x5a83d system-emu/run-boot.py --name b-win95-pm-fault --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-setup-is.img -boot c
```

Wall: **29.614 s**. Instructions: **150,000,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-haiku-debug-menu

Repeated space keys enter the Haiku boot loader. Manually navigated to the debug-options submenu; the 180-second bound expires there.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name b-haiku-debug-menu --timeout 180 --send '0.5: ' --send '1: ' --send '2: ' --send '3: ' --send '4: ' --send '5: ' --send '6: ' --send '7: ' --send '8: ' --send '9: ' --send '10: ' --send '12: ' --send '15: ' --send '18: ' --send '21: ' --send '24: ' -- build/llvm/sail-x86-system -ips 4 -m 1024 -kbd -b build/bios.bin -cdrom build/os-boot/haiku-b.iso -boot d
```

Wall: **180.738 s**. Instructions: **692,290,029**. Runner result: `timeout`, exit `0`.

Last serial output:

```text
(no serial output)
```

Additional manual inputs:

* 2026-09-24 22:19:12 UTC: `\x01d\x01d\n`
