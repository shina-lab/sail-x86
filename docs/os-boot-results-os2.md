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
