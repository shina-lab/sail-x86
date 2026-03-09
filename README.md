# sail-x86

This repo contains a comprehensive formal specification of the x86-64
instruction set written in the
[Sail](https://github.com/rems-project/sail) ISA specification
language, based on the
[Intel Software Developer's Manual](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html)
(SDM) and actual hardware behavior. Our goal is to provide an
authoritative, machine-readable formalization of x86-64 for researchers
and practitioners who need to formally verify software or hardware
targeting the architecture.

## Status

The specification covers the general-purpose, SSE, SSE2, SSE3, SSSE3,
SSE4.1, SSE4.2, AES-NI, AVX/AVX2, AVX-512/EVEX, and x87 FPU
instruction sets. Virtualization (VMX) and enclave (SGX) instructions
are not yet implemented.

The Sail model can be compiled to C++ using the Sail compiler and serves
as the CPU core in two emulators: a user-mode emulator that runs real
Linux x86-64 binaries (coreutils, Python, Clang), and a system-level
emulator that boots the Linux kernel to an interactive shell. The
emulators provide the scaffolding not covered by the ISA specification
itself — memory, peripherals, syscall emulation.

## Building

Prerequisites:

- [Sail](https://github.com/rems-project/sail) 0.20+
- GMP (`sudo apt install libgmp-dev`)
- CMake 3.20+
- GCC or Clang with C++23 support

```
mkdir build && cd build
cmake ..
make -j$(nproc)
```

## User-mode emulator

```
./build/usermode-emu/sail_x86_sim <elf-binary> [args...]
```

Both statically and dynamically linked x86-64 ELF binaries are
supported. The emulator interprets each instruction through the Sail
model and emulates Linux syscalls.

```
$ ./build/usermode-emu/sail_x86_sim /bin/ls /
bin  boot  dev  etc  home  lib  ...
$ ./build/usermode-emu/sail_x86_sim /usr/bin/python3 -c "print('hello')"
hello
```

Pass `-d` for a debug trace of each instruction.

## System emulator (Linux boot)

The system emulator loads an uncompressed vmlinux ELF directly and
boots Linux with an initramfs to an interactive serial console.

To download the Linux kernel source, build it with a minimal
configuration, build a BusyBox initramfs, and print the boot command:

```
cd build
make linux
```

This requires `curl`, `busybox-static`, and `fakeroot` in addition to
the standard kernel build tools. The kernel source is downloaded
automatically.

To run the emulator manually:

```
./build/system-emu/sail_x86_system -i initramfs.cpio.gz vmlinux
```

## Testing

```
cd build && ctest -j$(nproc) --output-on-failure
```

## Project structure

- `model/` — Sail specification (~40 files)
  - Instruction decoder (prefix, ModR/M, opcode maps)
  - Per-instruction semantics (ALU, SSE, AVX, x87, system)
  - Types, registers, memory, flags, floating-point externals
- `usermode-emu/` — user-mode Linux emulator in C++
  - ELF loader, Linux syscall emulation, execution loop
- `system-emu/` — system-level emulator in C++
  - Physical memory, device emulation (UART, PIT, PIC)
  - Paging, interrupt/exception delivery
  - Scripts to build a minimal Linux kernel and initramfs
- `emu-shared/` — code shared between both emulators
- `kvm/` — KVM-based differential tests against real hardware
- `test/` — test programs
