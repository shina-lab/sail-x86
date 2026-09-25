# OS/2 Warp 4 boot results

Worktree `sail-x86-os7`, branch `os-boot-os2`, starting at `18e90a9`.
Session started 2026-09-25 01:19 UTC. Builds and system tests use
**sail-llvm only**; no official Sail compiler, CMake model target or CTest.

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
afterward (82 basic tests). [Validation](os-boot/os2-tests-far-load.txt).
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
rejection. [Validation](os-boot/os2-test-multiple.txt).
