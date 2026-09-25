# OS/2 Warp 4 boot results

Worktree `sail-x86-os7`, branch `os-boot-os2`, starting at `18e90a9`.
Session started 2026-09-25 01:19 UTC. Builds and system tests use
**sail-llvm only**; no official Sail compiler, CMake model target or CTest.


Current result at 2026-09-25 04:15 UTC: **native first-stage installation
completed** on the fresh IDE disk. The checkpoint is
`build/os-boot/os2-hdd-first-stage.img`. Native IDE boot runs CHKDSK, then
traps in SINGLEQ$ while cleaning up an earlier initialization failure.
Full installation and the Workplace Shell have **not** been reached in Sail.
A separate KVM reference boot of a checkpoint copy reaches graphical Setup.

## Media and platform

The original `/home/ruiu/os-images/ibm-os2-warp-version-4.iso` is opened
read-only by the emulator's ATAPI device. It contains a High Sierra
filesystem, volume `OS2WARP4`, rather than ISO 9660. xorriso did not read
its directory tree, and 7-Zip recognized an embedded ZIP instead of the CD.
[The extraction helper](os-boot/os2-extract-media.py) reads High Sierra
directory records and extracts the three unmodified 1.44 MB CD-install
diskettes: `DISK0.DSK`, `DISK1_CD.DSK`, and `DISK2.DSK`.

Contrary to the initial platform description, this checkout already has
an i8272/82077-style floppy model and `-fda`. This lets the Warp CD remain
attached as the secondary IDE master throughout diskette boot.
The guest has 64 MB RAM, one CPU, a fresh 512 MiB primary-master IDE disk,
SeaBIOS, VGA/VBE, and the existing PIC/APIC/COM1 devices.

```sh
python3 docs/os-boot/os2-extract-media.py \
  /home/ruiu/os-images/ibm-os2-warp-version-4.iso build/os-boot/os2-diskettes
cp build/os-boot/os2-diskettes/DISK0.DSK build/os-boot/os2-floppy.img
truncate -s 536870912 build/os-boot/os2-hdd.img
bash system-emu/build-llvm.sh
```

The installed runner is not executable, so commands invoke it with
`python3 system-emu/run-boot.py`. Raw logs, RAM snapshots and writable
media stay under `build/os-boot/`. Curated PNGs and diagnostic logs are
under `docs/os-boot/`.

## Validation and disk changes

The system suites are compiled with `clang++ -std=c++20 -O2 -march=native`,
including `build/llvm`, `system-emu`, `emu-shared`, and
`/home/ruiu/sail-llvm/runtime/sail_llvm_rt/include`. Each test links
`build/llvm/sail_x86_model.o`, the three platform sources
(`system-emu/x86-externals.cpp`, `system-emu/x86-phys-mem.cpp`,
`emu-shared/x86-externals-common.cpp`), and the sail-llvm runtime archive
`/home/ruiu/sail-llvm/build/runtime/sail_llvm_rt/libsail_llvm_rt.a`.
The existing `build-tests.py` from the read-only worktree B was copied
into this worktree's `build/os-boot/`, with log names changed to `os2-system-*`.
It compiles three platform objects concurrently, then the system suites
with at most 14 concurrent processes.

`585bffd` adds **Ctrl-a f** to reopen the configured `-fda` image and assert
its disk-change latch. Replace the private image at a disk prompt, then
send `\x01f` followed by Enter. The old disk remains attached if opening
the replacement fails. The regression checks sector contents before/after
replacement, disk-change clearing on seek, and failure preservation:

```sh
clang++ -std=c++20 -O2 -Isystem-emu -Iemu-shared \
  system-emu/tests/test-floppy.cpp -o build/llvm/system_test_floppy
build/llvm/system_test_floppy
```

Source CD SHA-256:
`a91d2c9ea556e7708d21771a20afcdb0b6134f6857131b9ab6adc2559e564555`.

`4ed9280` implements ATA RECALIBRATE, which IBM1S506 uses before
probing disk geometry. The pre-fix trace returned ABRT repeatedly.
The device test covers all 16 aliases, IRQ acknowledgement/masking, and
ATAPI rejection. All eight IDE tests pass. Reference:
[ATA draft, §8.21](https://files.mpoli.fi/unpacked/hardware/hdd/other/ata-2.zip/ata-2.txt).

The [control helper](os-boot/os2-control.py) records live keyboard input,
media swaps, and signal captures in each attempt's `.inputs` file. For example:

```sh
python3 docs/os-boot/os2-control.py os2-install swap build/os-boot/os2-diskettes/DISK1_CD.DSK
python3 docs/os-boot/os2-control.py os2-install dump
```

## Model fixes

* `773fd08`: instruction fetch now truncates CS.base + EIP to 32 bits
  outside 64-bit mode (Intel SDM rev.090 Vol.3A §§3.4, 5.1.1). The loader
  uses a nonzero CS base and negative EIP; the previous sum read above
  4 GiB and recursively faulted. Four instruction regressions cover
  protected/compatibility modes and 16/32-bit code. They fail before the
  fix; all 14 system suites pass afterward, including 80 basic cases.
  [Validation](os-boot/os2-tests-fetch.txt).

* `a67a497`: expand-down data segments accept offsets above the lower
  limit, through the 16/32-bit upper bound selected by B (SDM Vol.3A
  §§3.4.5, 6.3). The regression checks SS/DS and both boundaries; it fails
  before the fix. All 14 suites pass afterward, including 81 basic cases.
  Diskette 0 now reaches the Diskette 1 prompt.
  [Validation](os-boot/os2-tests-expand.txt).
  [Diskette 1 prompt](os-boot/os2-diskette-1-prompt.png).

[Initial loader screenshot](os-boot/os2-initial-loader.png).
[Initial CPU and device dumps](os-boot/os2-loader-faults.txt).

## Attempts

All serial consoles in the initial loader attempts were silent.
Instruction counts include interrupt entries, as measured by the runner.




<!-- Generated attempts -->

### os2-01

Triple fault in the loader: non-wrapping CS.base + EIP reads above 4 GiB.

```sh
SAIL_X86_BIOS_DEBUG=1 python3 system-emu/run-boot.py --name os2-01 --timeout 1200 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **2.202 s**. Instructions: **11,240,659**.
Result: `exit`, exit `146`. Serial: silent.

### os2-02-trace

Trace of recursive instruction-fetch faults.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=11239000 SAIL_X86_TRACE_END=11240660 python3 system-emu/run-boot.py --name os2-02-trace --timeout 120 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **2.201 s**. Instructions: **11,240,659**.
Result: `exit`, exit `146`. Serial: silent.

### os2-03-entry

Earlier trace confirms repeated entry to the same exception handler.

```sh
SAIL_X86_TRACE_START=11236000 SAIL_X86_TRACE_END=11237000 python3 system-emu/run-boot.py --name os2-03-entry --timeout 120 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **2.202 s**. Instructions: **11,237,000**.
Result: `exit`, exit `0`. Serial: silent.

### os2-04-fetch

With fetch wrapping fixed, paging starts; a valid expand-down stack access faults and recursively faults in the handler.

```sh
SAIL_X86_BIOS_DEBUG=1 python3 system-emu/run-boot.py --name os2-04-fetch --timeout 1800 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **2.202 s**. Instructions: **12,141,618**.
Result: `exit`, exit `146`. Serial: silent.

### os2-05-paging

Instruction trace: TEST byte [ESP+12h],2 at 0160:fff53c67 faults on an expand-down stack with limit 3fffh.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_TRACE_START=12141520 SAIL_X86_TRACE_END=12141620 python3 system-emu/run-boot.py --name os2-05-paging --timeout 120 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **2.401 s**. Instructions: **12,141,618**.
Result: `exit`, exit `146`. Serial: silent.

### os2-06-stack

First stack-fault entry and 64-instruction history captured; initial fault is at fffb82dch.

```sh
SAIL_X86_TRACE_ADDRESS=0xfff53987 SAIL_X86_TRACE_ADDRESS_STEPS=10 python3 system-emu/run-boot.py --name os2-06-stack --timeout 120 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **2.402 s**. Instructions: **12,137,143**.
Result: `exit`, exit `0`. Serial: silent.

### os2-07-expand

Diskette 0 boots to the Diskette 1 prompt. Stopped to add floppy media replacement.

```sh
SAIL_X86_BIOS_DEBUG=1 python3 system-emu/run-boot.py --name os2-07-expand --timeout 1800 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **31.010 s**. Instructions: **13,259,930**.
Result: `exit`, exit `0`. Serial: silent.


Manual inputs:



### os2-08-disks

Loads Diskette 1, shows Warp splash, accepts Diskette 2, then reports that OS/2 cannot operate the hard disk or diskette drive. Manual swaps are recorded below.

```sh
SAIL_X86_BIOS_DEBUG=1 python3 system-emu/run-boot.py --name os2-08-disks --timeout 1800 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **157.863 s**. Instructions: **382,713,929**.
Result: `exit`, exit `0`. Serial: silent.


Manual inputs:

* 2026-09-25T01:29:34.740804+00:00: swap ['build/os-boot/os2-diskettes/DISK1_CD.DSK']
* 2026-09-25T01:31:14.264547+00:00: swap ['build/os-boot/os2-diskettes/DISK2.DSK']

### os2-09-device-trace

Stopped at Diskette 1: this process launched the previous emulator while the diagnostic build was finishing, so no FDC trace was available.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_FLOPPY_TRACE=1 SAIL_X86_IDE_TRACE=1 python3 system-emu/run-boot.py --name os2-09-device-trace --timeout 1800 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **25.212 s**. Instructions: **13,214,130**.
Result: `exit`, exit `0`. Serial: silent.


Manual inputs:



### os2-10-device-trace

Reproduces drive failure after Diskette 2. IDE trace shows repeated RECALIBRATE 10h returning status 41h (DRDY|ERR) and ABRT. Diskette DMA transfers through the loader complete.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_FLOPPY_TRACE=1 SAIL_X86_IDE_TRACE=1 python3 system-emu/run-boot.py --name os2-10-device-trace --timeout 1800 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **165.863 s**. Instructions: **351,691,043**.
Result: `exit`, exit `0`. Serial: silent.


Manual inputs:

* 2026-09-25T01:33:06.001226+00:00: swap ['build/os-boot/os2-diskettes/DISK1_CD.DSK']
* 2026-09-25T01:34:57.846209+00:00: swap ['build/os-boot/os2-diskettes/DISK2.DSK']

### os2-11-recal

ATA recalibration succeeds and sector zero is read; READ VERIFY 40h is still rejected during the last-cylinder probe. Diskette 2 again ends at the drive error.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_FLOPPY_TRACE=1 SAIL_X86_IDE_TRACE=1 python3 system-emu/run-boot.py --name os2-11-recal --timeout 1800 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **221.503 s**. Instructions: **412,397,390**.
Result: `exit`, exit `0`. Serial: silent.


Manual inputs:

* 2026-09-25T01:36:41.894853+00:00: swap ['build/os-boot/os2-diskettes/DISK1_CD.DSK']
* 2026-09-25T01:39:09.377333+00:00: swap ['build/os-boot/os2-diskettes/DISK2.DSK']

### os2-12-verify

RECALIBRATE and READ VERIFY now complete. The IDE disk is probed successfully, but the same boot-drive error remains after Diskette 2. Further FDC port tracing follows.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_FLOPPY_TRACE=1 SAIL_X86_IDE_TRACE=1 python3 system-emu/run-boot.py --name os2-12-verify --timeout 1800 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **151.657 s**. Instructions: **446,285,663**.
Result: `exit`, exit `0`. Serial: silent.


Manual inputs:

* 2026-09-25T01:40:18.676125+00:00: swap ['build/os-boot/os2-diskettes/DISK1_CD.DSK']
* 2026-09-25T01:41:31.842964+00:00: swap ['build/os-boot/os2-diskettes/DISK2.DSK']

### os2-13-fdc-io

Port tracing shows the native floppy driver sends VERSION (10h), but the controller wrongly waits for eight parameter bytes, consuming later SPECIFY and RECALIBRATE commands. BIOS diskette reads continue; native drive initialization fails.

```sh
system-emu/run-boot.py --name os2-13-fdc-io --timeout 1800 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **187.08 s**. Instructions: **544,113,227**.
Result: `exit`, exit `0`. Serial: two form feeds only.

### os2-14-error-entry

An address-triggered trace captures entry to the kernel drive-error path at linear ffe28555h after Diskette 2. The native FDC VERSION probe is still malformed.

```sh
system-emu/run-boot.py --name os2-14-error-entry --timeout 1800 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **77.03 s**. Instructions: **166,313,751**.
Result: `exit`, exit `0`. Serial: two form feeds only.

## Resumed session (2026-09-25 01:52 UTC)

Reviewed and retained the pending FDC port-write trace and controller-state
dump; neither changes device behavior. Retained the input-control helper,
Diskette 2/drive-error screenshots, ATA regression logs and attempts 8–14.
The emulator was rebuilt first using `bash system-emu/build-llvm.sh` with
sail-llvm commit `54a10b8`; no official Sail compiler was used. A new sparse
512 MiB disk, `build/os-boot/os2-resume-hdd.img`, starts this session's install.

### FDC VERSION command framing

The fresh rebuild reproduces the drive error (`os2-15-rebuilt`).
The native floppy driver sends `10h` and then SPECIFY/RECALIBRATE.
The controller incorrectly treated VERSION as a nine-byte command:
`10 03 df 02 07 00 03 df 02`, swallowing the later commands.
Implement the one-byte command, returning `90h` without IRQ, and make
invalid opcodes return `80h` immediately. This follows the Intel
[82077AA datasheet, table 5-1 and §5.2.8](https://ardent-tool.com/datasheets/Intel_82077AA.pdf).
The regression fails before the fix and passes afterward, checking MSR,
response, no IRQ and correct framing of following SPECIFY/SEEK commands.
[Validation](os-boot/os2-test-version.txt).

### os2-15-rebuilt

Unmodified diskettes and fresh 512 MiB IDE disk, using the newly rebuilt
emulator. Reproduces the same drive error; FDC command framing is the
next confirmed defect. [PNG](os-boot/os2-15-rebuilt.png).

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_FLOPPY_TRACE=1 SAIL_X86_IDE_TRACE=1 system-emu/run-boot.py --name os2-15-rebuilt --timeout 600 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-resume-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **111.246 s**. Instructions: **396,923,941**.
Result: `exit`, exit `0`. Serial: two form feeds only.

### os2-16-version

FDC VERSION succeeds; CONFIGURE and LOCK are issued. Native floppy reads begin after Diskette 2. The drive error is replaced by TRAP 000e at 0160:fff53343, CR2=00005e58: EDI lost its high bits across a 16-bit LDS.
[PNG](os-boot/os2-16-trap000e.png).

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_FLOPPY_TRACE=1 SAIL_X86_IDE_TRACE=1 system-emu/run-boot.py --name os2-16-version --timeout 1200 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-resume-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **101.834 s**. Instructions: **322,851,633**.
Result: `exit`, exit `0`. Serial: two form feeds only.

### os2-17-trap-entry

An event-triggered trace confirms the failing pointer came from 16-bit LDS in the kernel, followed by LEA EDX,[EDI+16h]. read_far_pointer returns a qword and the instruction writes all 64 bits, clearing EDI[31:16].
[PNG](os-boot/os2-17-trap-entry.png).

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_FLOPPY_TRACE=1 SAIL_X86_IDE_TRACE=1 SAIL_X86_TRACE_EVENT_ADDRESS=0xfff53343 system-emu/run-boot.py --name os2-17-trap-entry --timeout 300 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-resume-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **116.645 s**. Instructions: **419,926,205**.
Result: `exit`, exit `0`. Serial: two form feeds only.

### Far-pointer load destination width

`LDS`, `LES`, `LFS`, `LGS`, and `LSS` must commit only the operand-sized
offset, after selector validation (Intel SDM rev.090 Vol.2A pp.3-540–3-542;
Vol.1 §3.4.1.1). The common memory helper deliberately returns a qword for
far-control transfers, but using it directly as the GPR write erased the
high bits on 16-bit loads. Slice to the decoded operand width.
The instruction regression covers all five opcodes in 16/32-bit code and
LSS/LFS/LGS in 64-bit code, including all valid destination widths and
invalid-selector restart with unchanged GPR/segment state (58 cases).

The regression fails before the fix; all 15 sail-llvm system suites pass
afterward (81 basic tests). [Validation](os-boot/os2-tests-far-load.txt).
[Exception trace](os-boot/os2-far-load-trace.txt).

### os2-18-far-load

The three original diskettes boot to the installer [welcome screen](os-boot/os2-installer-welcome.png).
Enter continues; Easy Installation is selected. Disk initialization then loops
on INITIALIZE DEVICE PARAMETERS / SET MULTIPLE MODE, with `C6h count=01h`
returning ABRT. No sectors have been written to the fresh disk yet.
[Stopped screen](os-boot/os2-18-set-multiple.png).

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_FLOPPY_TRACE=1 SAIL_X86_IDE_TRACE=1 system-emu/run-boot.py --name os2-18-far-load --timeout 1800 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-resume-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **205.679 s**. Instructions: **188,848,883**.
Result: `exit`, exit `0`. Serial: two form feeds only.

### ATA multiple-sector commands

The disk advertises maximum block count 1 in IDENTIFY word 47, but did not
implement C4h/C5h/C6h. Implement enable/disable, reject unsupported settings
while disabling MULTIPLE, expose the current setting in IDENTIFY word 59,
and reuse the sector PIO protocol for the advertised one-sector blocks.
Software reset restores the disabled default unless SET FEATURES 66h has
disabled reverting to defaults; CCh restores that behavior.
Reference: [ATA-2 draft §§8.10.21, 8.18, 8.23–8.24, 8.31](https://files.mpoli.fi/unpacked/hardware/hdd/other/ata-2.zip/ata-2.txt).

All 10 IDE tests pass. The new test fails against the prior header and
checks enable/disable, invalid counts, IDENTIFY, multi-sector reads/writes,
256-sector reads, interrupt phases, nIEN, reset/default behavior and ATAPI
rejection. [Validation](os-boot/os2-test-multiple.txt). All 15 system suites also pass
after the ATA change ([full validation](os-boot/os2-tests-multiple-all.txt)).

### os2-19-multiple

With ATA MULTIPLE implemented, Easy Installation automatically partitions
the fresh IDE disk. The active type-07 partition spans sectors 63–1033199
(504.5 MiB). [Partition complete](os-boot/os2-partition-complete.png).
A sparse snapshot is retained at `build/os-boot/os2-hdd-partitioned.img`.
Reinserted DISK0 and pressed Enter for the requested restart; the emulator
handles the guest reset and boots the same three installation diskettes.

After the restart, the installer recognizes the primary partition, but automatic
formatting reports a generic Format Error. [Error](os-boot/os2-format-error.png),
[INSTALL.LOG viewer](os-boot/os2-format-install-log.png). The IDE trace no longer
contains rejected MULTIPLE commands. A command-prompt attempt follows to
obtain FORMAT's own diagnostic.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_FLOPPY_TRACE=1 SAIL_X86_IDE_TRACE=1 system-emu/run-boot.py --name os2-19-multiple --timeout 2400 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-resume-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **276.495 s**. Final boot instruction count: **186,618,299**
(the emulator resets its counter on guest reboot). Exit `0`.
Serial: form feeds only.

### os2-20-format-shell

Booted the partitioned disk with the original diskettes and used F3 at Welcome
to open the native [OS/2 command prompt](os-boot/os2-command-prompt.png).
The formatter is on the CD under `D:\OS2IMAGE\DISK_3`, not on Diskette 2.
`FORMAT C: /FS:HPFS` completes successfully; label `WARP4`, 516568 KiB
total and 509236 KiB available.
[Format complete](os-boot/os2-hpfs-format-complete.png). A snapshot is saved
as `build/os-boot/os2-hdd-formatted.img`. RAM strings show the failed
automatic attempt used `C: /FS:FAT`; its FAT-specific failure is diagnosed below. Continuing the installation on HPFS.

After exiting the command prompt, selected Advanced Installation, accepted
C:, kept the existing format, and selected the default PS/2 pointing device.
The installer writes its first files, then reports SYS3176 (illegal instruction).
Its message catalog is unavailable, so the register-report menu also returns
SYS0318. [Stopped screen](os-boot/os2-installer-3176.png).
The failed disk is preserved as `build/os-boot/os2-hdd-3176.img`; the next
attempt starts from the successful HPFS-format snapshot with exception tracing.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_FLOPPY_TRACE=1 SAIL_X86_IDE_TRACE=1 system-emu/run-boot.py --name os2-20-format-shell --timeout 1800 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-resume-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **770.690 s**. Instructions: **597,581,865**. Exit `0`.
Serial: two form feeds only.

A QEMU TCG control was launched with a separate partitioned-disk copy and
read-only source media, then stopped during diskette boot once the direct
HPFS format succeeded in Sail. It did not format or install the guest disk
and is not evidence for completion.

### os2-21-fat-diagnostic

An independent copy of the original partitioned disk reproduces the automatic
formatter's error from the command prompt with
`D:\OS2IMAGE\DISK_3\FORMAT C: /FS:FAT`. The exact diagnostic is SYS1274:
the partition exceeds 2048 MB **or extends beyond cylinder 1023**. This
504.5 MiB partition ends at sector 1033199; with 16 heads and 63 sectors
per track its last cylinder is 1024. This is a guest FAT formatting
restriction, not a CPU/device error. HPFS successfully formats that same
partition. [Diagnostic PNG](os-boot/os2-fat-cylinder-limit.png).

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_FLOPPY_TRACE=1 SAIL_X86_IDE_TRACE=1 system-emu/run-boot.py --name os2-21-fat-diagnostic --timeout 1200 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-fat-floppy.img -hda build/os-boot/os2-fat-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **137.041 s**. Instructions: **176,706,841**.
Exit `0`. Serial: form feeds only. Diagnostic disk and
floppy images are separate from the active HPFS installation.


### os2-22-illegal

Repeated Advanced Installation from the clean HPFS snapshot with a trace on
OS/2's #UD handler. The first #UD is at `005b:00010646`, bytes `82 3a 00`
(`CMP byte [EDX],0`), in the installer's 32-bit runtime. Opcode 82h is absent
from the decoder. Other instructions in this routine also use 82h.
[Exception trace](os-boot/os2-opcode82-trace.txt).

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_FLOPPY_TRACE=1 SAIL_X86_IDE_TRACE=1 SAIL_X86_TRACE_ADDRESS=0xfff5388c system-emu/run-boot.py --name os2-22-illegal --timeout 1800 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-install-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

Wall: **260.898 s**. Instructions: **527,640,435**. Exit `0`.
Serial: two form feeds only.

### Legacy immediate Group 1 alias

Intel SDM rev.090 Vol.3B §25.15 explicitly defines opcode 82h as the
corresponding byte Group 1 instruction encoded by 80h outside 64-bit mode;
64-bit mode must raise #UD. Share the existing 80h implementation, retaining
its LOCK restrictions and rejecting 82h in 64-bit mode before operand fetch.

The new regression checks all eight ALU operations with explicit results
and defined arithmetic flags, register and memory operands, no prefix/66h/LOCK,
real mode, 16/32-bit protected and compatibility code, and 64-bit rejection.
It also checks fault restart, unchanged operands and adjacent bytes. The
288-case regression fails before the fix.
All 15 system suites pass after rebuilding (82 basic tests).
[Validation](os-boot/os2-tests-opcode82.txt).


### os2-23-opcode82

Restarted from `os2-hdd-formatted.img`, booted all three installation diskettes,
and repeated Advanced Installation with the existing HPFS format and default
PS/2 device. The installer passes the former SYS3176 stop and begins
[copying system files from the CD](os-boot/os2-copying-system-files.png).
Exception tracing is still enabled; no #UD has occurred.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_FLOPPY_TRACE=1 SAIL_X86_IDE_TRACE=1 SAIL_X86_TRACE_ADDRESS=0xfff5388c system-emu/run-boot.py --name os2-23-opcode82 --timeout 2400 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-floppy.img -hda build/os-boot/os2-install-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```

After copying numbered sets 3–11 and the boot-disk files, installation stopped
with [SYS3175](os-boot/os2-installer-3175.png). A RAM-resident exception record
identifies `C0000005`, `EIP=1bf91209`, an attempted read from `00000120`.
The instruction is `CMP ECX,[EAX]` in the exception-chain unlink routine;
its chain has become invalid. This does not by itself identify where the
corruption occurred. The failed disk is preserved as `os2-hdd-3175.img`.

Wall: **1295.735 s**. Instructions: **2,945,519,648**. Exit `0`.
Serial: two form feeds only.

### F2 string repetition

Resident OS/2 code includes `F2 MOVSB` at linear `1bfa33dd`, `F2 MOVSW`
at `1bfa880a`, and `F2 STOSW` at `1bfb93a4`. The current model ignores
F2 on these opcodes and executes a single element. Intel SDM rev.090
Vol.2A §2.1.1 defines both F2/F3 repeat prefixes for string and I/O
instructions; Vol.1 §7.3.9.2 limits ZF-conditioned repetition to CMPS/SCAS.

Reviewed and imported the existing fix and regressions from repository
commit `115a374`. Its real-mode matrix fails against this branch's old
sail-llvm object, including the zero-count case executing a forbidden element.
The connection to SYS3175 remains a hypothesis until a fixed-model retry.
All 15 system suites pass after rebuilding (83 basic tests); all 416 VM86
comparisons against KVM pass. [Validation](os-boot/os2-tests-f2.txt).

### os2-24-access

A diagnostic repeat on the partially populated disk uses
`SAIL_X86_TRACE_EVENT_ADDRESS=0x1bf91209` to capture the invalid chain's
last execution path. It uses the **pre-F2-fix** emulator, the same three
boot diskettes and Advanced Installation with no reformatting.

### os2-25-partial-ide

An independent copy of the failed disk boots from IDE far enough to run
[HPFS CHKDSK](os-boot/os2-partial-ide-chkdsk.png). It has not completed
installation. This diagnostic also uses the pre-F2-fix emulator and was
stopped before a retry with the corrected model.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_FLOPPY_TRACE=1 SAIL_X86_IDE_TRACE=1 SAIL_X86_TRACE_ADDRESS=0xfff5388c system-emu/run-boot.py --name os2-25-partial-ide --timeout 600 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -hda build/os-boot/os2-partial-boot-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot c
```

Wall: **156.218 s**. Instructions: **368,027,496**. Exit `0`.


### os2-26-f2-ide

Booting an independent copy of the SYS3175 disk with the F2-corrected model,
from IDE, with the CD attached read-only. This is a recovery/diagnostic path;
installation did not finish in the earlier attempt.

CHKDSK completes, but a later exception-chain walk reads `4f5c3a43`
(the bytes `C:\O`) as a pointer at `1bf91209`. Thus F2 repetition alone does
not explain this recovery-path corruption. Error handling then reaches
[SINGLEQ$ TRAP 000d](os-boot/os2-singleq-trap000d.png), at
`03f8:0971` / linear `fe100971`: `MOV EBX,ES:[SI]`, with null ES.
The clean installation retry remains necessary to distinguish CPU errors
from the incomplete disk's state.

Wall: **407.271 s**. Instructions: **1,743,915,600**. Exit `0`.

### os2-27-f2-install

Repeating the complete installation from the clean HPFS snapshot using the
F2-corrected model, a separate private floppy image and IDE disk. The original
CD and all extracted source diskettes remain unchanged. Select Advanced,
accept C:, retain HPFS and select the default PS/2 pointing device.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_FLOPPY_TRACE=1 SAIL_X86_IDE_TRACE=1 SAIL_X86_TRACE_EVENT_ADDRESS=0x1bf91209 system-emu/run-boot.py --name os2-27-f2-install --timeout 4500 -- build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin -fda build/os-boot/os2-f2-floppy.img -hda build/os-boot/os2-f2-install-hdd.img -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot a
```


### os2-28-chain

An independent partial-disk clone is booted with an instruction trace beginning
at `005b:1fe2fa64` and ending 15000 steps later. It captures exception-handler
registration, but kernel work consumes the window before the later fault.
Raw trace, RAM and PNG are `build/os-boot/os2-28-chain.*`.

### os2-29-chain-full

Repeat the same deterministic IDE boot with a 500000-step window from
`1fe2fa64`, filtered by `SAIL_X86_TRACE_CS=0x5b`. This opt-in host diagnostic
restricts register output to the requested selector without changing execution
or the trace stop count, so the user-runtime path can span intervening kernel
calls without an enormous register log.


The copy-only diagnostic attempts 24 and 27 were stopped after the
operand-width defect below was reproduced. Their writable images and raw
logs are preserved; neither is a completed installation.
[Attempt 24 screen](os-boot/os2-24-copy-diagnostic.png),
[attempt 27 screen](os-boot/os2-27-before-double-shift.png).

`os2-24-access`: **1253.151 s**, **2,992,363,565** instructions, exit `0`.

`os2-27-f2-install`: **977.242 s**, **2,400,445,708** instructions, exit `0`.

`os2-28-chain`: **172.264 s**, **417,862,997** instructions, exit `0`.

`os2-29-chain-full`: **165.661 s**, **418,347,997** instructions, exit `0`.


### Double-shift operand widths

A reduced `SHRD dword [EBP-0Ch],ECX,5` probe changes eight bytes rather than
four: `04bbbbccaaa5a0ff` becomes `00000000d5552d07`. The neighboring dword
must remain `04bbbbcc`. A 16-bit register destination also loses its upper
bits. Make both operand reads and the write explicitly use `os` for all
four SHLD/SHRD encodings, as specified by Intel SDM rev.090 Vol.2B
pp.4-639–4-644 (and Vol.1 §3.4.1.1 for partial GPR writes).

OS/2's API thunk uses these instructions beside stack-resident bookkeeping
for exception-handler registration. The longer trace shows valid registration
followed by invalid links; [selected trace](os-boot/os2-double-shift-trace.txt).
The new regression checks 64 cases across 16/32/64-bit operands, immediate
and CL counts, left/right shifts, zero counts, GPR preservation, adjacent
memory and narrow destinations ending exactly at a segment limit. It fails
before the fix. All 15 sail-llvm system suites pass afterward (84 basic tests).
A repeat of the reduced probe now retains `04bbbbcc`.

The CS filter is verified by attempt 29: 8032 register snapshots inside the
500000-step window all have CS=005b; the final unfiltered state dump occurs
at the requested stop count.

### os2-30-double-shift-install

Restarted the full installation from `os2-hdd-formatted.img` with both F2 and
double-shift fixes. The private disk is `os2-fixed-install-hdd.img` and the
private floppy is `os2-f2-floppy.img`. Original media remain read-only.

**First stage completed at 03:42 UTC.** The guest copied data sets 3–11 and
the three boot diskettes, installed the installation program, checked the
workstation configuration, and requested a restart with the diskette removed.
The previous `SYS3175` failure and its `1bf91209` event did not recur.
[Restart prompt](os-boot/os2-first-stage-complete.png),
[state log](os-boot/os2-first-stage-complete.txt),
[configuration detection](os-boot/os2-config-check.png).

The emulator was stopped at that prompt and flushed the writable disk.
`build/os-boot/os2-hdd-first-stage.img` preserves the completed first stage.
A separate copy, `os2-phase2-hdd.img`, is used for the IDE boot in attempt 35.
This is first-stage completion, not yet a completed OS installation.

Attempt 30: **1332.723 s**, **3,149,375,326** instructions, exit `0`.

### os2-31-fixed-ide

Independently booting a new copy of `os2-hdd-3175.img` as
`os2-fixed-ide-hdd.img` with both fixes to check the earlier runtime failure.


All **480 VM86/KVM comparisons** pass, including 64 added SHLD/SHRD
comparisons of registers and memory with immediate/CL and zero/nonzero counts.
[Validation](os-boot/os2-tests-double-shift.txt).

The corrected partial-disk boot no longer triggers the event trace at
`1bf91209`, but it still reaches [SINGLEQ$ TRAP 000d](os-boot/os2-singleq-after-double-shift.png)
at `03f8:0971` with ES=0. This is being diagnosed separately; the clean
installation retry continues.

Attempt 31: **284.458 s**, **1,119,324,120** instructions, exit `0`.


### os2-32-singleq

Fresh clone of the partial disk, traced at driver entry `fe1008f9` for
3000 instructions to locate where the ES input pointer becomes null.

The [entry trace](os-boot/os2-singleq-trace.txt) shows that the IOCTL request
already contains `0003:0000` for both parameter and data pointers. The driver
normalizes these null selectors to zero, then `LES SI,[BP+8]` loads ES=0.
The later read at `03f8:0971` correctly faults. No new architectural violation
has been isolated from this trace; this disk was copied by an earlier model
and its installation never completed.

Attempt 32: **166.277 s**, **417,749,161** instructions, exit `0`.

### os2-33-singleq-caller

Another clone of the partial disk, `os2-singleq-caller-hdd.img`, traced from
instruction 417500000 to 417750000 with `SAIL_X86_TRACE_CS=0x5b` to examine
the user-mode caller that constructs this request. The clean installation
in attempt 30 continues independently.

This window contained no CS=005b instructions: execution was already in
other segments. It therefore did not expose the caller and did not justify
a change. Stopped after **166.891 s**, **417,750,000** instructions, exit `0`.

### os2-34-singleq-kernel

A fresh clone, `os2-singleq-kernel-hdd.img`, traces all code segments between
instructions 417700000 and 417746161 to inspect the request construction.

All 46162 snapshots landed in the post-trap `1000:3b86/3b87` loop. Instruction
counts from the earlier run did not align with this run, so this trace adds
no evidence about request construction. Use an address trigger or a physical
write trace for a further diagnostic, rather than reusing these counts.

Attempt 34: **166.082 s**, **417,746,161** instructions, exit `0`.

At 03:40 UTC, attempt 30 passed the previous SYS3175 stopping point and
reached [Installing the OS/2 Warp Installation program](os-boot/os2-install-program.png)
after copying data sets 3–11 and the three boot diskettes. The event trace
at `1bf91209` has not fired in this clean run. The completed first stage and its preserved disk are recorded under attempt 30.

### os2-35-phase2

Boot the completed first-stage disk copy with no floppy attached. The CD
remains read-only. Keyboard input will continue the installer.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_IDE_TRACE=1 \
SAIL_X86_TRACE_EVENT_ADDRESS=0x971 \
python3 system-emu/run-boot.py --name os2-35-phase2 --timeout 1800 -- \
  build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin \
  -hda build/os-boot/os2-phase2-hdd.img \
  -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot c
```

CHKDSK finishes with 967 user files (37086 KiB), 40 directories, and
472056 KiB free. Boot then reproduces the same [SINGLEQ$ trap](os-boot/os2-phase2-singleq.png)
at `03f8:0971`, ES=0. The [state log](os-boot/os2-phase2-singleq.txt) records
this stop on the completed first-stage installation. Thus incomplete
installation of the older diagnostic disk does not explain the remaining
blocker. The request pointers again read `0003:0000` at linear
`9bd240c1` and `9bd240c5` (physical `00f4f0c1` and `00f4f0c5`).

Attempt 35: **239.092 s**, **863,822,679** instructions, exit `0`.

### os2-36-packet-watch

Rebuild with sail-llvm after adding CS:RIP to the opt-in physical-write
trace. Watch physical `00f4f0c1` on another first-stage disk copy and stop
one instruction after entry at `fe1008f9`. This avoids dependence on an
instruction count from an earlier run.

The watch identifies `STOSW` at `0140:140c` as the writer of the null
parameter pointer; the kernel is translating a null argument supplied by
user space. Attempt 36: **170.670 s**, **423,810,890** instructions, exit `0`.

### os2-37-ioctl-trace and the KVM reference

Trace all segments from instruction 423770000 to 423811130 on another
first-stage clone, with the same BIOS/IDE tracing settings as attempt 35.
The raw trace has 41131 snapshots; 2918 use flat user CS=005b.
Attempt 37: **173.873 s**, **423,811,130** instructions, exit `0`.

The [selected trace and reference state](os-boot/os2-singleq-cleanup-comparison.txt)
show that `005b:1feab557` deliberately calls DosDevIOCtl with category 3,
function 0x73 and null parameter/data buffers. This is downstream of
`1fec0bd8`, an exit-list cleanup callback, through `1fec0c27 -> 1feab3ec`.
SINGLEQ's initialization flag at DS:004a is still zero; the trap is a
secondary failure during cleanup. The original reason for exiting remains
unresolved. Do not bypass the driver's null-segment fault.

For comparison, boot a **copy** of the same first-stage checkpoint under
QEMU 11.0.2/KVM, with `-cpu pentium3 -m 64`, IDE disk and read-only CD,
`-L /home/ruiu/bin/qemu/share/qemu`, and `-boot c`. It reaches
[graphical OS/2 Setup and Installation](os-boot/os2-qemu-reference-phase2.png).
This verifies the checkpoint's usability; it is not Sail boot success.
A second reference copy, stopped by GDB at `fe1128f9`, enters SINGLEQ
first from `005b:1feac0c2` with a **20-byte non-null** parameter buffer
at `0027:f8b8` (linear `0004f8b8`). The buffer describes the
`1fd90000` and `1fed0000` regions. This earlier initialization must be
compared with Sail before changing the driver-facing device behavior.

### Descriptor accessed bits and os2-38-accessed

Comparison of the segment caches exposed a separate architectural error:
loading a code/data segment did not set the descriptor's accessed bit.
Intel SDM revision 090, Vol. 3A §3.4.5.1 (pp. 3-12–3-13) specifies this
side effect; Vol. 3A §4.6 specifies implicit supervisor page accesses and
CR0.WP. The model now sets A for its implemented descriptor loads, before
committing the selector/cache. Implicit writes bypass U/S but respect WP,
report supervisor write page faults, and update page dirty bits. They do
not create user-accessible TLB entries. RETF, call/interrupt gates, monitor
entry, and IRET paths apply the same operation. An outer IRETD stack
descriptor write is prepared before CS changes so a #PF preserves the
interrupted architectural state.

The [regression log](os-boot/os2-accessed-validation.txt) includes the
failing-before case (descriptor 0x92 remained unchanged, expected 0x93).
The final regression covers GDT/LDT loads of five data segments, WP/A-bit
combinations at CPL 3, the IRETD fault ordering, and a far JMP: 16 cases.
All **15 system suites pass**, including **85 basic tests**. Two additional
VM86 monitor tests compare the CS/SS descriptor writes with KVM for
16/32-bit gates under two initial memory fills. The final model passes
**484 KVM comparisons, zero failures**, after recompiling the harness
against the same sail-llvm model object used by the final system tests.

The sail-llvm rebuild is in `build/os-boot/os2-accessed-final-build.log`;
no official Sail compiler was used. The opt-in physical-write diagnostic
now prints CS:RIP, validated by `build/os-boot/os2-watch-probe.txt`, which
made the packet writer above identifiable.

Attempt 38 boots another first-stage clone with the accessed-bit fix.
It produces the [same SINGLEQ$ stop](os-boot/os2-accessed-singleq.png),
now with correct cached access types (CS=9b, SS=97, DS=93). This correction
is independently justified, but does not resolve the original failure.
Attempt 38: **229.287 s**, **777,438,816** instructions, exit `0`.

The source ISO SHA-256 was rechecked at 04:15 UTC and still equals the
original value recorded above. All reference boots use separate disk
copies; the native completed first-stage checkpoint is preserved.

### os2-39-earlier-exit

Boot the final accessed-bit model on another checkpoint clone. Trace
CS=005b from instructions 423000000 through 423770000. This produces
17159 user snapshots and [locates an earlier transition](os-boot/os2-earlier-exit-trace.txt):
`1fe78bfa -> 1fea3534 -> 1fea355f`, then a far jump to `febf:00a9`.
The first observed exit callback is `1fec0534` at instruction 423727188.
The intervening execution changes privilege level: flat CS=005b is a
conforming DPL-2 segment, and runs as selector 005a at CPL 2. The CS=005b
filter therefore omits the driver-side work. A full-segment trace follows.
[Screen at trace stop](os-boot/os2-earlier-exit.png).

Attempt 39: **171.078 s**, **423,770,000** instructions, exit `0`.

### Preserved checkpoint and next boot

`build/os-boot/os2-hdd-first-stage.img` is 536870912 bytes and SHA-256
`2aa5948cc9a9dcad517aac984f840b831dcf5d3fb1ddb13dc88cf823dc1ab59b`.
It was installed by Sail, including native partitioning and HPFS formatting.
The QEMU reference disks are separate copies. Both reference VMs were
stopped after their screenshots and RAM snapshots were saved.

To resume native IDE boot without altering the checkpoint:

```sh
cp --reflink=auto build/os-boot/os2-hdd-first-stage.img build/os-boot/os2-next-hdd.img
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_IDE_TRACE=1 \
python3 system-emu/run-boot.py --name os2-next --timeout 1800 -- \
  build/llvm/sail-x86-system -ips 4 -m 64 -kbd -b build/bios.bin \
  -hda build/os-boot/os2-next-hdd.img \
  -cdrom /home/ruiu/os-images/ibm-os2-warp-version-4.iso -boot c
```

Every model/device correction in this session has regression evidence in
the same commit. The pending FDC diagnostics from the interrupted session
were reviewed and retained in `bc262e1`. All compilation used sail-llvm;
no official Sail compiler or generated-model CMake/CTest target was run.

### os2-40-driver-thunk: original #GP isolated

The final full-segment trace spans 423280680–423727200, following the
CPL-2 display-driver call omitted by attempt 39. It identifies the original
fault at **005a:1fea35d7**, `66 EA 0000 980B` (`JMP 0b98:0000`).
GDT entry 0b98 is a present DPL-3 16-bit call gate targeting `fec6:0224`,
a DPL-2 code segment containing `RETF`. The emulator rejects all system
descriptors in far JMP, so this valid gate raises #GP and invokes the
exit callbacks that later trigger the secondary SINGLEQ$ trap.
[Fault trace](os-boot/os2-jmp-gate-trace.txt),
[screen at trace stop](os-boot/os2-driver-thunk.png).

Attempt 40: **196.482 s**, **423,727,200** instructions, exit `0`.

Intel SDM revision 090 Vol. 2A, JMP **CALL-GATE**, pp. 3-509–3-510,
explicitly permits JMP through 16/32-bit call gates with the appropriate
gate privilege/presence and destination-code checks. Unlike CALL, it
cannot switch privilege to a nonconforming destination, and it neither
reads a TSS stack nor pushes a frame. The gate width supplies the offset;
the instruction's offset and gate parameter count are ignored.

The new regression fails before the model change. It covers 16/32-bit
gates, 16/32-bit instruction operands, direct/indirect encodings, ignored
operand offsets and parameter counts, stack preservation, accessed bits,
and eight privilege/presence/type/limit variants (16 total cases).
The model change is restricted to legacy call gates; long-mode call
gates and task switches are outside this correction.

After the call-gate fix, all **15 system suites pass**, including
**86 basic tests**, and the rebuilt harness passes **484 KVM comparisons**.
[Failing-before and passing-after validation](os-boot/os2-jmp-gate-validation.txt).
Historical basic-test counts above are corrected to match their logs:
the old test wrapper increments its pass counter even after an assertion
reports failure, so adding its printed pass and fail totals overcounts.
