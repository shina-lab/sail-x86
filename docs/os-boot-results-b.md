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
| Windows 95 | **Graphical Setup license agreement, then SU-0013** | FreeDOS startup disk rejected; Microsoft DOS retry in progress |
| Haiku R1 beta 5 x86-64 | **All seven icons and user-space debugger** after 30 minutes | `net_server` execution fault; later `package_daemon` heap assertion |

These are actual guest captures, not graphics test patterns:
[ScanDisk after XLAT fix](os-boot/b-win95-xlat-setup.png),
[Windows graphical Setup](os-boot/b-win95-graphical-welcome.png), and
[Haiku from IDE disk](os-boot/b-haiku-hdd-serial.png).

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

Three further protected-mode defects prevented graphical Setup:

* `2e614d3` implements legacy call gates. At `005b:0b79`, Setup calls a
  valid DPL3 16-bit gate targeting ring 0. Previously every system
  descriptor was rejected as a far-call target. The implementation reads
  the correct 16/32-bit TSS stack fields, uses the gate width for the frame,
  copies parameters, preserves segmented addressing, and validates gate,
  target and stack access. SDM Vol.2A CALL pp.3-130–3-133 and Vol.3A
  sections 10.2.4 and 10.6 specify the behavior. Tests cover both gate/TSS
  widths, ring 0/ring 1, same-level transfers and faults.
* `d015446` implements cached LDT state and selector TI handling. Setup
  creates selector `02ac` in its LDT, then loads ES. The old model looks up
  that index in the GDT and raises a spurious #GP. LLDT now validates and
  caches the LDT descriptor; segment loads, far transfers and descriptor
  queries use it. SDM Vol.2A LLDT pp.3-558–3-559 and Vol.3A sections 3.4.2
  and 3.5.1 specify this. Regressions check cached state, LAR/LSL/VERR/VERW,
  invalidation and LLDT faults.
* `ddc0aa8` fixes protected-mode interrupt frames. Setup's INT 21h points
  to a DPL3 handler; the model unconditionally switched to CPL0 and wrote
  a flat stack frame. The handler then failed on POP SS. The target code
  descriptor now chooses CPL, same-level interrupts retain SS, and inward
  transfers use the selected TSS stack and cached SS base. SDM Vol.3A
  section 7.12.1 and Vol.2A INT pp.3-472 onward specify this. Regressions
  cover both gate widths, mixed TSS widths, same/inward transfers, frame
  layout, IF, software interrupts without error codes and IRET round trips.

All 14 C++ system tests and PNG validation pass after these changes
(70 basic cases and 17 exception cases). The diagnostic-only commit
`09ea619` adds CPL, descriptor tables and segment caches to state dumps.
No virtual-8086 behavior was added or modified.

`b-win95-interrupt-stack` reaches a real 640x480 planar VGA Windows 95
Setup welcome dialog. [The PNG](os-boot/b-win95-graphical-welcome.png)
was captured at 273,538,881 instructions. COM1 is silent; the corresponding
[serial artifact](os-boot/b-win95-interrupt-stack.serial) is empty.

## Windows 95 demand loading and Microsoft DOS retry

`b-win95-install` reaches **100% of preparing the Setup Wizard**, then runs
through zero-filled memory. Selector `0dff` describes base `0x013e2940`,
limit `0x0da7`, access byte `0x7b`: it is **not present**. The old RETF
implementation installs this descriptor without raising #NP.

`364d664` implements the legacy protected-mode RET checks from SDM
Vol.2B pp.4-571–4-575, read before the change. It validates return CS
presence/type/privilege/limit before changing segments; outer returns also
validate SS, release parameters on both stacks and invalidate inaccessible
data selectors. Both new regression cases fail before the fix. All 14
C++ system tests and PNG validation pass afterward (72 basic cases).

With this change, `b-win95-retf` reaches the license agreement. After
acceptance, [Setup reports SU-0013](os-boot/b-win95-retf.png): it requires an
MS-DOS boot partition. COM1 remains silent. A separate local copy,
`win95-msdos.img`, is now being prepared using the Microsoft DOS boot image
from the supplied media. It successfully boots COMMAND.COM, unlike the
pre-fix attempts. `SYS C:` reports `System transferred`; no original image
or other worktree file is changed.

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

After this fix, Haiku reaches four icons and issues ATAPI READ(10)
requests. The full `b-haiku-pio` run lasts **1800.829 seconds** and executes
**1,393,832,701 instructions**. It is still loading from CD when the bound
expires. The previous three-icon/no-boot-partition failure is resolved.

The boot loader menu enables normal serial logging in `b-haiku-menu-serial`.
Space enters the menu; select Debug options, press **Enter** on Enable
serial debug output (Space does not toggle it), Escape back to the main
menu, then choose Continue booting. The kernel log shows BFS mounted and
packages being loaded, but reports `device still expects data transfer`
after each ATAPI block. Haiku's
[PIO transfer code](https://github.com/haiku/haiku/blob/r1beta5/src/add-ons/kernel/bus_managers/ata/ATAChannel.cpp)
waits up to one second for DRQ to clear at a phase boundary. The emulator
previously presented the next DRQ immediately in the last data-port read,
so the driver repeatedly paid that entire timeout.

`6d58284` adds a one-millisecond virtual busy interval between ATAPI data
phases. DRQ clears while BSY is set, then the device asserts the next
interrupt independently of status polling. Reset/new commands cancel the
pending phase. A timed regression verifies all block payloads, transitions,
interrupt/status latches and cancellation. All six IDE cases pass. This is
an emulator device-timing change, not a Sail instruction change.

As an independent check, `haiku-b-hdd.img` is a writable local copy of the
same anyboot media, attached as IDE master rather than CD-ROM. With serial
debugging enabled through the menu, it mounts BFS, loads packages, starts
user processes and reaches all seven boot icons. The full run lasts
**1800.732 seconds / 6,862,262,878 instructions**. Its final
[screen](os-boot/b-haiku-hdd-serial.png) is the user debugger for `net_server`.
The [serial log](os-boot/b-haiku-hdd-serial.serial) records an execution page
fault at `0x19dcc91a380`, reached from
`BNetworkSettings::_StartWatching + 0x68`. Later, `package_daemon` enters
the debugger on `getNumAvailable() < getNumBlocks()` in its heap allocator.
The underlying cause of these user-space failures is not established.

The first timed-phase CD run lasts **1800.859 seconds / 7,256,361,662
instructions**, reaches seven icons, then a white framebuffer. Its normal
serial logging was not enabled by the prematurely timed menu input.
`b61e0e6` adds opt-in IDE tracing of the first host status read after each
ATAPI phase. A new manually verified serial-enabled run finds most such
reads at 41.25 microseconds (BSY set, DRQ clear), but an outlier at
1.72425 milliseconds sees the next DRQ. The one-millisecond service time
therefore removes most repeated delays, not every possible timeout.

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
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=0 SAIL_X86_TRACE_STEP=1000000 SAIL_X86_TRACE_END=120000000 system-emu/run-boot.py --name b-win95-baseline --timeout 120 --send '15:\n' --send '30:\n' -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-freedos.img -boot c
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
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=0 SAIL_X86_TRACE_STEP=500000 SAIL_X86_TRACE_END=70000000 SAIL_X86_TRACE_ADDRESS=0x52440 system-emu/run-boot.py --name b-win95-scandisk --timeout 100 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-diag.img -boot c
```

Wall: **13.208 s**. Instructions: **70,000,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-fpu-probe

Locates FNINIT at instruction 19,118,044. Still uses the non-reproducing /CHECKONLY invocation.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=0 SAIL_X86_TRACE_STEP=1000000 SAIL_X86_TRACE_END=40000000 SAIL_X86_TRACE_ADDRESS=0x4f5e0 system-emu/run-boot.py --name b-win95-fpu-probe --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-diag.img -boot c
```

Wall: **7.604 s**. Instructions: **40,000,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-fpu-trace

Single-step trace proves the x87 probe and interrupt-vector installation succeed.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=19118040 SAIL_X86_TRACE_STEP=1 SAIL_X86_TRACE_END=19125000 system-emu/run-boot.py --name b-win95-fpu-trace --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-diag.img -boot c
```

Wall: **3.802 s**. Instructions: **19,125,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-fixup-probe

The unsupported ScanDisk invocation does not exercise the selected interrupt fixup.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=19120000 SAIL_X86_TRACE_STEP=10000 SAIL_X86_TRACE_END=25000000 SAIL_X86_TRACE_ADDRESS=0x4fd23 system-emu/run-boot.py --name b-win95-fixup-probe --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-diag.img -boot c
```

Wall: **4.603 s**. Instructions: **25,000,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-scandisk-text

SCANDISK /TEXT /ALL reproduces R6002 and reaches the x87 INT fixup.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=0 SAIL_X86_TRACE_STEP=1000000 SAIL_X86_TRACE_END=40000000 SAIL_X86_TRACE_ADDRESS=0x4fd23 system-emu/run-boot.py --name b-win95-scandisk-text --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-diag.img -boot c
```

Wall: **7.603 s**. Instructions: **40,000,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-fixup-trace

Single-step trace proves the INT 37h fixup patches and executes FILD.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=37358170 SAIL_X86_TRACE_STEP=1 SAIL_X86_TRACE_END=37370000 system-emu/run-boot.py --name b-win95-fixup-trace --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-diag.img -boot c
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
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=37000000 SAIL_X86_TRACE_STEP=100000 SAIL_X86_TRACE_END=40000000 SAIL_X86_TRACE_ADDRESS=0x4cb0a system-emu/run-boot.py --name b-win95-format-probe --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-diag.img -boot c
```

Wall: **7.604 s**. Instructions: **40,000,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-format-trace

Single-step trace ties the wrong XLAT lookup to the floating-point formatter stub and R6002.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=37701900 SAIL_X86_TRACE_STEP=1 SAIL_X86_TRACE_END=37704000 system-emu/run-boot.py --name b-win95-format-trace --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-diag.img -boot c
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
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=0 SAIL_X86_TRACE_STEP=1000000 SAIL_X86_TRACE_END=200000000 SAIL_X86_TRACE_ADDRESS=0x2042 system-emu/run-boot.py --name b-win95-ud-probe --timeout 120 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-setup-is.img -boot c
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
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=130000000 SAIL_X86_TRACE_STEP=1 SAIL_X86_TRACE_END=130000050 system-emu/run-boot.py --name b-win95-pm-loop --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-setup-is.img -boot c
```

Wall: **28.016 s**. Instructions: **130,000,050**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-pm-fault

The selected address is not reached in this run; stops in a different protected-mode fault path at 0070:11f6.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=0 SAIL_X86_TRACE_STEP=1000000 SAIL_X86_TRACE_END=150000000 SAIL_X86_TRACE_ADDRESS=0x5a83d system-emu/run-boot.py --name b-win95-pm-fault --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-setup-is.img -boot c
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

### b-win95-segments

Captures relocated extender code and GDT/IDT bases with the expanded CPU dump.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=0 SAIL_X86_TRACE_STEP=1000000 SAIL_X86_TRACE_END=125000000 system-emu/run-boot.py --name b-win95-segments --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-setup-is.img -boot c
```

Wall: **27.666 s**. Instructions: **125,000,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-gp-entry

First GP follows a valid call through a 16-bit gate at 005b:0b79. The fault handler then receives an incorrect stack because the model assumes a 32-bit TSS.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=0 SAIL_X86_TRACE_STEP=1000000 SAIL_X86_TRACE_END=115000000 SAIL_X86_TRACE_ADDRESS=0x318e77 system-emu/run-boot.py --name b-win95-gp-entry --timeout 90 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-setup-is.img -boot c
```

Wall: **22.811 s**. Instructions: **115,000,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-callgate

The call gate succeeds. A later MOV ES,AX using LDT selector 02ac faults because the model looks in the GDT. Guest exits with Unknown stack in fault dispatcher.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=0 SAIL_X86_TRACE_STEP=5000000 SAIL_X86_TRACE_END=250000000 SAIL_X86_TRACE_ADDRESS=0x318e77 system-emu/run-boot.py --name b-win95-callgate --timeout 180 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-setup-is.img -boot c
```

Wall: **53.819 s**. Instructions: **250,000,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-haiku-pio

Full 30-minute run with the IDE BAR fix: four boot icons, continuing CD reads, no COM1 output. The later serial-enabled run explains the repeated per-block delays.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_IDE_TRACE=1 system-emu/run-boot.py --name b-haiku-pio --timeout 1800 -- build/llvm/sail-x86-system -ips 4 -m 1024 -kbd -b build/bios.bin -cdrom build/os-boot/haiku-b.iso -boot d
```

Wall: **1800.829 s**. Instructions: **1,393,832,701**. Runner result: `timeout`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-ldt

LDT selectors now work. INT 21h incorrectly changes CPL3 to CPL0, and the DPL3 handler faults on POP SS.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=0 SAIL_X86_TRACE_STEP=5000000 SAIL_X86_TRACE_END=350000000 SAIL_X86_TRACE_ADDRESS=0x318e77 system-emu/run-boot.py --name b-win95-ldt --timeout 180 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-setup-is.img -boot c
```

Wall: **75.632 s**. Instructions: **350,000,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-win95-interrupt-stack

Reaches the graphical Windows 95 Setup welcome screen. Captured at 273,538,881 instructions; Enter continues Setup before the trace-end bound.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=0 SAIL_X86_TRACE_STEP=10000000 SAIL_X86_TRACE_END=400000000 SAIL_X86_TRACE_ADDRESS=0x318e77 system-emu/run-boot.py --name b-win95-interrupt-stack --timeout 180 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-setup-is.img -boot c
```

Wall: **85.445 s**. Instructions: **400,000,000**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

Additional manual inputs:

* 2026-09-24 22:41:09 UTC: `\n`

### b-xv6-regression

Regression boot after call-gate/LDT/interrupt fixes: reaches the xv6 shell prompt.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name b-xv6-regression --timeout 180 --expect '\$ ' -- build/llvm/sail-x86-system -ips 4 -b build/bios.bin -hda build/os-boot/xv6-b.img -hdb build/os-boot/xv6-b-fs.img
```

Wall: **9.939 s**. Instructions: **19,938,591**. Runner result: `expected output`, exit `0`.

Last serial output:

```text
xv6...
cpu0: starting 0
sb: size 1000 nblocks 941 ninodes 200 nlog 30 logstart 2 inodestart 32 bmap start 58
init: starting sh
$
```

### b-linux-regression

Regression boot after call-gate/LDT/interrupt fixes: 64-bit Linux 6.19.6 reaches sail# with ACPI/APIC enabled.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name b-linux-regression --timeout 300 --expect 'sail# ' -- build/llvm/sail-x86-system -ips 4 -b build/bios.bin -cdrom build/os-boot/linux-b-apic.iso -boot d
```

Wall: **50.559 s**. Instructions: **240,817,378**. Runner result: `expected output`, exit `0`.

Last serial output:

```text
:00: resource 7 [mem 0x80000000-0xfebfffff window]
pci 0000:00:01.0: PIIX3: Enabling Passive Release
pci 0000:00:00.0: Limiting direct PCI/PCI transfers
PCI: CLS 0 bytes, default 64
Unpacking initramfs...
RAPL PMU: API unit is 2^-32 Joules, 0 fixed counters, 10737418240 ms ovfl timer
clocksource: tsc: mask: 0xffffffffffffffff max_cycles: 0x1cd42e4dffb, max_idle_ns: 881590591483 ns
clocksource: Switched to clocksource tsc
workingset: timestamp_bits=62 max_order=16 bucket_order=0
input: Power Button as /devices/LNXSYSTM:00/LNXPWRBN:00/input/input0
ACPI: button: Power Button [PWRF]
Freeing initrd memory: 1740K
Serial: 8250/16550 driver, 4 ports, IRQ sharing disabled
serial8250: ttyS0 at I/O 0x3f8 (irq = 4, base_baud = 115200) is a 16550A
i8042: PNP: PS/2 Controller [PNP0303:KBD,PNP0f13:MOU] at 0x60,0x64 irq 1,12
serio: i8042 KBD port at 0x60,0x64 irq 1
intel_pstate: CPU model not supported
input: AT Translated Set 2 keyboard as /devices/platform/i8042/serio0/input/input1
microcode: Current revision: 0x00000000
IPI shorthand broadcast: enabled
sched_clock: Marking stable (105170339600, 68628500)->(44958163850, 60280804250)
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


sail# [6n
```

### b-linux-i386-regression

Regression boot after call-gate/LDT/interrupt fixes: 32-bit Linux reaches sail#.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name b-linux-i386-regression --timeout 300 --expect 'sail# ' -- build/llvm/sail-x86-system -ips 4 -i build/os-boot/initramfs-b-i386.cpio -a 'console=ttyS0 tsc=reliable random.trust_cpu=on rdinit=/init' build/os-boot/bzImage-b-i386
```

Wall: **17.226 s**. Instructions: **55,984,966**. Runner result: `expected output`, exit `0`.

Last serial output:

```text
: 1024 (order: 0, 4096 bytes, linear)
Performance Events: unsupported CPU family 6 model 94 no PMU driver, software events only.
signal: max sigframe size: 3616
Memory: 29764K/35448K available (1357K kernel code, 557K rwdata, 272K rodata, 196K init, 224K bss, 5388K reserved, 0K cma-reserved, 0K highmem)
devtmpfs: initialized
clocksource: jiffies: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 7645041785100000 ns
clocksource: pit: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 1601818034827 ns
clocksource: Switched to clocksource tsc-early
clocksource: tsc: mask: 0xffffffffffffffff max_cycles: 0x1cd42e4dffb, max_idle_ns: 881590591483 ns
clocksource: Switched to clocksource tsc
Unpacking initramfs...
platform rtc_cmos: registered platform RTC device (no PNP device found)
workingset: timestamp_bits=30 max_order=13 bucket_order=0
Freeing initrd memory: 1740K
Serial: 8250/16550 driver, 4 ports, IRQ sharing disabled
serial8250: ttyS0 at I/O 0x3f8 (irq = 4, base_baud = 115200) is a 16550A
serio: i8042 KBD port at 0x60,0x64 irq 1
microcode: Current revision: 0x00000000
input: AT Translated Set 2 keyboard as /devices/platform/i8042/serio0/input/input0
sched_clock: Marking stable (10385335325, 88047000)->(10474783075, -1400750)
Freeing unused kernel image (initmem) memory: 196K
Write protecting kernel text and read-only data: 1632k
Run /init as init process

========================================
 Sail x86-64 Emulator - Linux Console
========================================

Type 'help' for a list of built-in commands.
Press Ctrl-a x to exit the emulator.


sail# [6n
```

### b-haiku-menu-serial

Enables serial output through the boot loader menu. Kernel mounts the BFS boot partition and loads packages, but repeatedly waits one second for DRQ to clear between ATAPI phases.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name b-haiku-menu-serial --timeout 1800 --send '0.5: ' --send '1: ' --send '2: ' --send '3: ' --send '4: ' --send '5: ' --send '6: ' --send '7: ' --send '8: ' --send '9: ' --send '10: ' --send '12: ' --send '15: ' --send '18: ' --send '21: ' --send '24: ' --send '35:\x01d\x01d\n' --send '40: ' --send '45:\x1b' --send '50:\x01d\x01d\x01d\n' -- build/llvm/sail-x86-system -ips 4 -m 1024 -kbd -b build/bios.bin -cdrom build/os-boot/haiku-b.iso -boot d
```

Wall: **1800.791 s**. Instructions: **1,955,231,009**. Runner result: `timeout`, exit `0`.

Last serial output:

```text
tring(0xffffffff8287e198 ('<NULL>'), 'haiku-r1~beta5-x86_64           ', 21)
intel: pm_scan_partition(0, 0: 0, 1477246976, 2048)
intel: ep_std_ops(0x1)
intel: ep_identify_partition(0, 6291456, 1468006400, 2048)
intel: ep_std_ops(0x2)
intel: pm_identify_partition(0, 1: 6291456, 1468006400, 2048)
ata 1 error: device still expects data transfer
Last message repeated 15 times.
identify(0, 0xffffffff8287e150)
intel: ep_std_ops(0x1)
intel: ep_identify_partition(0, 1474297856, 2949120, 2048)
intel: ep_std_ops(0x2)
intel: pm_identify_partition(0, 2: 1474297856, 2949120, 2048)
ata 1 error: device still expects data transfer
Last message repeated 15 times.
identify(0, 0xffffffff8287e150)
Identified anyboot CD.
periph_check_capacity: TRIM: Setting trim support to disabled
periph_check_capacity: TRIM: Setting trim support to disabled
ata 1 error: device still expects data transfer
Last message repeated 31 times.
bfs: mounted "Haiku" (root node at 131072, device = /dev/disk/atapi/1/master/0)
Mounted boot partition: /dev/disk/atapi/1/master/0
ata 1 error: device still expects data transfer
Last message repeated 47 times.
unknown: [363319308:    14] Adding packages from "/boot/system/packages"
unknown: [363321822:    14] Failed to open packages activation file: No such file or directory
unknown: [363322982:    14] Loading packages from activation file failed. Loading all packages in packages directory.
ata 1 error: device still expects data transfer
Last message repeated 1071 times.
slab memory manager: created area 0xffffffff86801000 (193)
ata 1 error: device still expects data transfer
```

Additional manual inputs:

* 2026-09-24 22:21:43 UTC: `\x1b`
* 2026-09-24 22:22:10 UTC: `\x01u\n`
* 2026-09-24 22:22:49 UTC: `\n`
* 2026-09-24 22:23:08 UTC: `\x1b`
* 2026-09-24 22:23:27 UTC: `\x01d\x01d\x01d\x01d\x01d\n`

### b-win95-install

Graphical Setup reaches wizard preparation at 100%, then executes a not-present unloaded code segment (selector 0dff, base 013e2940, access 7b). Stopped manually for RETF diagnosis.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name b-win95-install --timeout 1800 --send '70:\n' -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-setup-is.img -boot c
```

Wall: **664.658 s**. Instructions: **2,812,085,353**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-haiku-hdd-serial

Full 30-minute run: all seven icons, user programs, then the net_server user debugger. Serial records an execution page fault in BNetworkSettings::_StartWatching and a later package_daemon heap assertion. No desktop.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name b-haiku-hdd-serial --timeout 1800 --send '0.5: ' --send '1: ' --send '2: ' --send '3: ' --send '4: ' --send '5: ' --send '6: ' --send '7: ' --send '8: ' --send '9: ' --send '10: ' --send '12: ' --send '15: ' --send '18: ' --send '21: ' --send '24: ' --send '35:\x01d\x01d\n' --send '40:\n' --send '45:\x1b' --send '50:\x01d\x01d\x01d\x01d\x01d\n' -- build/llvm/sail-x86-system -ips 4 -m 1024 -kbd -b build/bios.bin -hda build/os-boot/haiku-b-hdd.img -boot c
```

Wall: **1800.732 s**. Instructions: **6,862,262,878**. Runner result: `timeout`, exit `0`.

Last serial output:

```text
oot processing for packages dir /boot/home/config/packages.
package_daemon: [1644335768:    62] Volume::InitialVerify(0x11ff00347a20, (nil))
package_daemon: [1651486989:    62] Volume::InitialVerify(): volume at "/boot/home/config" is consistent
62: DEBUGGER: getNumAvailable() < getNumBlocks()
debug_server: Thread 62 entered the debugger: Debugger call: `getNumAvailable() < getNumBlocks()'
stack trace, current PC 0x14b025a9129  </boot/system/lib/libroot.so> _kern_debugger + 0x9:
  (0x7f887f7e7840)  0x14b0262ff0b  </boot/system/lib/libroot.so> _ZN8BPrivate9hoardHeap9freeBlockERPNS_5blockERPNS_10superblockEiPNS_11processHeapE + 0x48b
  (0x7f887f7e7890)  0x14b02630390  </boot/system/lib/libroot.so> _ZN8BPrivate11processHeap4freeEPv + 0xf0
  (0x7f887f7e78d0)  0x14b02631609  </boot/system/lib/libroot.so> free + 0x49
  (0x7f887f7e7900)  0xd0b35b1734  </boot/system/servers/package_daemon> _ZN11VolumeStateD2Ev + 0xe4
  (0x7f887f7e7940)  0xd0b359c4b2  </boot/system/servers/package_daemon> _ZN24CommitTransactionHandlerD2Ev + 0xb2
  (0x7f887f7e7990)  0xd0b35b129b  </boot/system/servers/package_daemon> _ZN6Volume18_CommitTransactionEP8BMessagePKN11BPackageKit8BPrivate22BActivationTransactionERKSt3setIP7PackageSt4lessIS9_ESaIS9_EESF_RNS2_24BCommitTransactionResultE + 0xbb
  (0x7f887f7e7c90)  0xd0b35b1356  </boot/system/servers/package_daemon> _ZN6Volume30HandleCommitTransactionRequestEP8BMessage + 0x76
  (0x7f887f7e7dc0)  0xd0b35abad9  </boot/system/servers/package_daemon> _ZN4Root10_JobRunnerEv + 0x19
  (0x7f887f7e7de0)  0x14b025a7e39  </boot/system/lib/libroot.so> thread_entry + 0x19
```

### b-haiku-phase-trace

IDE timing trace. Initial keys start at one second and miss the boot-menu latch; stopped manually to retry with earlier keys. First observed firmware status reads occur 1.25 microseconds after a packet phase; later reads occur at 41.25 microseconds.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_IDE_TRACE=1 system-emu/run-boot.py --name b-haiku-phase-trace --timeout 1800 --send '1: ' --send '2: ' --send '3: ' --send '4: ' --send '5: ' --send '6: ' --send '7: ' --send '8: ' --send '9: ' --send '10: ' --send '12: ' --send '15: ' --send '18: ' --send '21: ' --send '24: ' -- build/llvm/sail-x86-system -ips 4 -m 1024 -kbd -b build/bios.bin -cdrom build/os-boot/haiku-b.iso -boot d
```

Wall: **95.256 s**. Instructions: **335,980,930**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

Additional manual inputs:

* 2026-09-24 22:59:27 UTC: ` `

### b-win95-retf

With legacy RETF validation, advances past wizard preparation to the license agreement. Tab/Enter accepts, then Setup reports SU-0013: startup drive must be an MS-DOS boot partition. Stopped to try the supplied Microsoft DOS boot image on a separate disk copy.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=1100000000 SAIL_X86_TRACE_STEP=10000000 system-emu/run-boot.py --name b-win95-retf --timeout 1200 --send '70:\n' -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/win95-setup-is.img -boot c
```

Wall: **371.158 s**. Instructions: **1,850,687,097**. Runner result: `exit`, exit `0`.

Last serial output:

```text
(no serial output)
```

Additional manual inputs:

* 2026-09-24 22:58:04 UTC: `\n`
* 2026-09-24 23:00:33 UTC: `y\n`
* 2026-09-24 23:01:17 UTC: `\t\n`

### b-xv6-retf-regression

Regression boot after the RETF fix: xv6 shell prompt.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name b-xv6-retf-regression --timeout 180 --expect '\$ ' -- build/llvm/sail-x86-system -ips 4 -b build/bios.bin -hda build/os-boot/xv6-b.img -hdb build/os-boot/xv6-b-fs.img
```

Wall: **9.939 s**. Instructions: **19,586,253**. Runner result: `expected output`, exit `0`.

Last serial output:

```text
xv6...
cpu0: starting 0
sb: size 1000 nblocks 941 ninodes 200 nlog 30 logstart 2 inodestart 32 bmap start 58
init: starting sh
$
```

### b-haiku-atapi-busy

Full 30-minute CD run with timed ATAPI phases: seven icons and then a white framebuffer. Normal COM1 output was not enabled by the early automated menu sequence. First-status tracing and verified manual serial enable follow in another run.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name b-haiku-atapi-busy --timeout 1800 --send '0.5: ' --send '1: ' --send '2: ' --send '3: ' --send '4: ' --send '5: ' --send '6: ' --send '7: ' --send '8: ' --send '9: ' --send '10: ' --send '12: ' --send '15: ' --send '18: ' --send '21: ' --send '24: ' --send '35:\x01d\x01d\n' --send '40:\n' --send '45:\x1b' --send '50:\x01d\x01d\x01d\x01d\x01d\n' -- build/llvm/sail-x86-system -ips 4 -m 1024 -kbd -b build/bios.bin -cdrom build/os-boot/haiku-b.iso -boot d
```

Wall: **1800.859 s**. Instructions: **7,256,361,662**. Runner result: `timeout`, exit `0`.

Last serial output:

```text
(no serial output)
```

### b-linux-retf-regression

Outcome pending analysis.

```sh
SAIL_X86_BIOS_DEBUG=1 system-emu/run-boot.py --name b-linux-retf-regression --timeout 180 --expect 'sail# ' -- build/llvm/sail-x86-system -ips 4 -m 64 -b build/bios.bin -cdrom build/os-boot/linux-b-apic.iso -boot d
```

Wall: **51.748 s**. Instructions: **240,487,456**. Runner result: `expected output`, exit `0`.

Last serial output:

```text
:00: resource 7 [mem 0x80000000-0xfebfffff window]
pci 0000:00:01.0: PIIX3: Enabling Passive Release
pci 0000:00:00.0: Limiting direct PCI/PCI transfers
PCI: CLS 0 bytes, default 64
Unpacking initramfs...
RAPL PMU: API unit is 2^-32 Joules, 0 fixed counters, 10737418240 ms ovfl timer
clocksource: tsc: mask: 0xffffffffffffffff max_cycles: 0x1cd42e4dffb, max_idle_ns: 881590591483 ns
clocksource: Switched to clocksource tsc
workingset: timestamp_bits=62 max_order=14 bucket_order=0
input: Power Button as /devices/LNXSYSTM:00/LNXPWRBN:00/input/input0
ACPI: button: Power Button [PWRF]
Freeing initrd memory: 1740K
Serial: 8250/16550 driver, 4 ports, IRQ sharing disabled
serial8250: ttyS0 at I/O 0x3f8 (irq = 4, base_baud = 115200) is a 16550A
i8042: PNP: PS/2 Controller [PNP0303:KBD,PNP0f13:MOU] at 0x60,0x64 irq 1,12
serio: i8042 KBD port at 0x60,0x64 irq 1
intel_pstate: CPU model not supported
input: AT Translated Set 2 keyboard as /devices/platform/i8042/serio0/input/input1
microcode: Current revision: 0x00000000
IPI shorthand broadcast: enabled
sched_clock: Marking stable (104707085268, 72056500)->(44788250518, 59990891250)
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


sail# [6n
```
