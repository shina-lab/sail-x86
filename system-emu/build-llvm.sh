#!/bin/bash
# Build the system emulator with sail-llvm (sailc) instead of the official
# Sail compiler.  The generated emulator runs about twenty times faster
# (paper: Linux to a shell in 33 s against 681 s), which matters for boot
# attempts that take 10^8 instructions.
#
# Usage: system-emu/build-llvm.sh [OUT_DIR]      (default: build/llvm)
# Result: OUT_DIR/sail-x86-system, same command line as the CMake binary.
# Requires: $SAIL_LLVM (default ~/sail-llvm) built, clang++ >= 18.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
out=${1:-$here/build/llvm}
sail_llvm=${SAIL_LLVM:-$HOME/sail-llvm}
mkdir -p "$out"
echo "sailc: compiling model ..." >&2
"$sail_llvm/build/sailc" --cpp -O3 --mcpu=native \
    --cpp-namespace x86 \
    --cpp-class-name Model \
    --cpp-derive-from "public X86PlatformBase" \
    --c-header-include x86-platform-base.h \
    -o "$out/sail_x86_model" \
    "$here/model/x86.sail_project"
echo "clang++: linking emulator ..." >&2
clang++ -std=c++20 -O3 -march=native -Wno-unused-parameter \
    -I"$out" \
    -I"$sail_llvm/runtime/sail_llvm_rt/include" \
    -I"$here/system-emu" \
    -I"$here/emu-shared" \
    $(pkg-config --cflags ncursesw) \
    "$here/system-emu/x86-system-sim.cpp" \
    "$here/system-emu/x86-externals.cpp" \
    "$here/system-emu/x86-phys-mem.cpp" \
    "$here/emu-shared/x86-externals-common.cpp" \
    "$out/sail_x86_model.o" \
    "$sail_llvm/build/runtime/sail_llvm_rt/libsail_llvm_rt.a" \
    $(pkg-config --libs ncursesw) \
    -o "$out/sail-x86-system"
echo "built $out/sail-x86-system" >&2
