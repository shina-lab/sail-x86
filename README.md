# sail-x86

A formal specification of the x86-64 instruction set written in
[Sail](https://github.com/rems-project/sail), based on the behavior
described in the
[Intel Software Developer's Manual](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html)
(SDM). Includes a user-mode Linux emulator that runs x86-64 ELF
binaries by interpreting each instruction through the Sail model.

The specification aims to faithfully capture the documented instruction
semantics, including preserving undefined behavior where the manual
says results are undefined (e.g., flags after certain shift counts).

## Status

The specification covers the general-purpose, SSE, SSE2, SSE3, SSSE3,
SSE4.1, SSE4.2, AES-NI, AVX/AVX2 (128-bit and 256-bit VEX-encoded),
and x87 FPU instruction sets — enough to run real-world programs
including coreutils, Python, and Clang through the emulator. AVX-512,
EVEX-encoded instructions, and system-level instructions (VMX, SGX,
etc.) are defined as stubs that raise #UD.

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

## Running

```
./build/c_emulator/sail_x86_sim <elf-binary> [args...]
```

Both statically and dynamically linked x86-64 ELF binaries are
supported. The emulator interprets each instruction through the Sail
model and emulates Linux syscalls.

```
$ ./build/c_emulator/sail_x86_sim /bin/ls /
bin  boot  dev  etc  home  lib  ...
$ ./build/c_emulator/sail_x86_sim /usr/bin/python3 -c "print('hello')"
hello
```

Pass `-d` for a debug trace of each instruction.

## Testing

```
cd build && ctest
```

## Project structure

- `model/` — Sail specification (~400 files)
  - `core/` — types, registers, memory, flags, floating-point externals
  - `decode/` — instruction decoder (prefix, ModR/M, opcode maps)
  - `instructions/` — per-instruction semantics
  - `prelude/` — Sail prelude
- `c_emulator/` — user-mode Linux emulator in C++
  - `x86_sim.cpp` — main entry point and execution loop
  - `x86_elf.cpp` — ELF loader (static and dynamic)
  - `x86_syscall.cpp` — Linux syscall emulation
  - `x86_externals.cpp` — external function implementations (FP, x87, SSE4.2, AES-NI, FXSAVE/FXRSTOR)
  - `x86_platform_base.h` — platform state (x87 FPU, MXCSR)
- `test/` — test programs
- `sail_runtime/` — build rules for the Sail C runtime library
