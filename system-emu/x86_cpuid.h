#pragma once

#include "integers.h"

// CPUID leaf 1: EDX feature bits
static constexpr u32 CPUID_1_EDX_FPU   = 1 << 0;
static constexpr u32 CPUID_1_EDX_DE    = 1 << 2;
static constexpr u32 CPUID_1_EDX_PSE   = 1 << 3;
static constexpr u32 CPUID_1_EDX_TSC   = 1 << 4;
static constexpr u32 CPUID_1_EDX_MSR   = 1 << 5;
static constexpr u32 CPUID_1_EDX_PAE   = 1 << 6;
static constexpr u32 CPUID_1_EDX_MCE   = 1 << 7;
static constexpr u32 CPUID_1_EDX_CX8   = 1 << 8;
static constexpr u32 CPUID_1_EDX_APIC  = 1 << 9;
static constexpr u32 CPUID_1_EDX_SEP   = 1 << 11;
static constexpr u32 CPUID_1_EDX_MTRR  = 1 << 12;
static constexpr u32 CPUID_1_EDX_PGE   = 1 << 13;
static constexpr u32 CPUID_1_EDX_MCA   = 1 << 14;
static constexpr u32 CPUID_1_EDX_CMOV  = 1 << 15;
static constexpr u32 CPUID_1_EDX_PAT   = 1 << 16;
static constexpr u32 CPUID_1_EDX_PSE36 = 1 << 17;
static constexpr u32 CPUID_1_EDX_CLFSH = 1 << 19;
static constexpr u32 CPUID_1_EDX_MMX   = 1 << 23;
static constexpr u32 CPUID_1_EDX_FXSR  = 1 << 24;
static constexpr u32 CPUID_1_EDX_SSE   = 1 << 25;
static constexpr u32 CPUID_1_EDX_SSE2  = 1 << 26;

// CPUID leaf 1: ECX feature bits
static constexpr u32 CPUID_1_ECX_SSE3       = 1 << 0;
static constexpr u32 CPUID_1_ECX_PCLMULQDQ  = 1 << 1;
static constexpr u32 CPUID_1_ECX_SSSE3      = 1 << 9;
static constexpr u32 CPUID_1_ECX_CX16       = 1 << 13;
static constexpr u32 CPUID_1_ECX_SSE4_1     = 1 << 19;
static constexpr u32 CPUID_1_ECX_SSE4_2     = 1 << 20;
static constexpr u32 CPUID_1_ECX_POPCNT     = 1 << 23;
static constexpr u32 CPUID_1_ECX_AESNI      = 1 << 25;
static constexpr u32 CPUID_1_ECX_XSAVE      = 1 << 26;
static constexpr u32 CPUID_1_ECX_OSXSAVE    = 1 << 27;
static constexpr u32 CPUID_1_ECX_AVX        = 1 << 28;

// CPUID leaf 7, subleaf 0: EBX feature bits
static constexpr u32 CPUID_7_EBX_AVX2    = 1 << 5;
static constexpr u32 CPUID_7_EBX_ERMS    = 1 << 9;
static constexpr u32 CPUID_7_EBX_AVX512F = 1 << 16;
static constexpr u32 CPUID_7_EBX_AVX512DQ = 1 << 17;
static constexpr u32 CPUID_7_EBX_AVX512CD = 1 << 28;
static constexpr u32 CPUID_7_EBX_AVX512BW = 1 << 30;
static constexpr u32 CPUID_7_EBX_AVX512VL = 1u << 31;

// CPUID leaf 0x80000001: ECX feature bits
static constexpr u32 CPUID_EXT1_ECX_LAHF  = 1 << 0;
static constexpr u32 CPUID_EXT1_ECX_LZCNT = 1 << 5;

// CPUID leaf 0x80000001: EDX feature bits
static constexpr u32 CPUID_EXT1_EDX_SYSCALL = 1 << 11;
static constexpr u32 CPUID_EXT1_EDX_NX      = 1 << 20;
static constexpr u32 CPUID_EXT1_EDX_LM      = 1 << 29;

// Combined feature sets for our emulator (x86-64-v2 baseline).
static constexpr u32 EMU_CPUID_1_EDX =
  CPUID_1_EDX_FPU | CPUID_1_EDX_DE | CPUID_1_EDX_PSE | CPUID_1_EDX_TSC |
  CPUID_1_EDX_MSR | CPUID_1_EDX_PAE | CPUID_1_EDX_MCE | CPUID_1_EDX_CX8 |
  CPUID_1_EDX_APIC | CPUID_1_EDX_SEP | CPUID_1_EDX_MTRR | CPUID_1_EDX_PGE |
  CPUID_1_EDX_MCA | CPUID_1_EDX_CMOV | CPUID_1_EDX_PAT | CPUID_1_EDX_PSE36 |
  CPUID_1_EDX_CLFSH | CPUID_1_EDX_MMX | CPUID_1_EDX_FXSR |
  CPUID_1_EDX_SSE | CPUID_1_EDX_SSE2;

static constexpr u32 EMU_CPUID_1_ECX =
  CPUID_1_ECX_SSE3 | CPUID_1_ECX_PCLMULQDQ | CPUID_1_ECX_SSSE3 |
  CPUID_1_ECX_CX16 | CPUID_1_ECX_SSE4_1 | CPUID_1_ECX_SSE4_2 |
  CPUID_1_ECX_POPCNT | CPUID_1_ECX_AESNI |
  CPUID_1_ECX_XSAVE | CPUID_1_ECX_OSXSAVE | CPUID_1_ECX_AVX;

// Note: AVX-512 CPUID bits are defined above but not yet advertised.
// The EVEX decoder works for static binaries, but glibc's dynamic linker
// dispatches to AVX-512-optimized routines (memset, memcpy, etc.) that use
// many EVEX instructions we haven't implemented yet, causing #UD.
// Enable when AVX-512 coverage is more complete.
static constexpr u32 EMU_CPUID_7_EBX =
  CPUID_7_EBX_AVX2 | CPUID_7_EBX_ERMS |
  CPUID_7_EBX_AVX512F | CPUID_7_EBX_AVX512DQ |
  CPUID_7_EBX_AVX512CD | CPUID_7_EBX_AVX512BW | CPUID_7_EBX_AVX512VL;

static constexpr u32 EMU_CPUID_EXT1_ECX =
  CPUID_EXT1_ECX_LAHF | CPUID_EXT1_ECX_LZCNT;

static constexpr u32 EMU_CPUID_EXT1_EDX =
  CPUID_EXT1_EDX_SYSCALL | CPUID_EXT1_EDX_NX | CPUID_EXT1_EDX_LM;
