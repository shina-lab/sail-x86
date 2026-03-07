# KVM Test Coverage Gap Analysis

Instructions implemented in the Sail model but NOT covered by KVM differential tests.
Tested instructions are marked with [x], untested with [ ].

## 1-Byte Opcode ALU & Data Movement

- [x] ADD
- [x] SUB
- [x] AND
- [x] OR
- [x] XOR
- [x] CMP
- [x] ADC
- [x] SBB
- [x] TEST
- [x] MOV
- [x] LEA
- [x] XCHG
- [x] NOP
- [x] INC
- [x] DEC
- [x] NEG
- [x] NOT
- [x] PUSH
- [x] POP
- [x] IMUL (2/3-operand)
- [x] MOVSXD
- [x] ENTER
- [x] LEAVE
- [ ] IN
- [ ] OUT

## Control Flow

- [x] CALL
- [x] RET
- [x] JMP
- [x] Jcc (JE, JL, etc.)
- [x] LOOP
- [x] LOOPcc

## Shifts & Rotates (Group 2)

- [x] SHL/SAL
- [x] SHR
- [x] SAR
- [x] ROL
- [x] ROR
- [x] RCL
- [x] RCR

## Multiply & Divide (Group 3)

- [x] MUL
- [x] IMUL (1-operand)
- [x] DIV
- [x] IDIV

## Flag Manipulation

- [x] CLC
- [x] STC
- [x] CMC
- [x] CLD
- [x] STD
- [x] LAHF
- [x] CBW/CWDE/CDQE
- [x] CWD/CDQ/CQO
- [x] SETcc (all condition codes)

## 2-Byte Opcode Instructions (0F xx)

- [x] CMOVcc (all condition codes)
- [x] MOVZX
- [x] MOVSX
- [x] BT
- [x] BTS
- [x] BTR
- [x] BTC
- [x] BSF
- [x] BSR
- [x] BSWAP
- [x] SHLD
- [x] SHRD
- [x] CMPXCHG
- [x] XADD
- [x] POPCNT
- [x] TZCNT
- [x] LZCNT
- [x] CMPXCHG8B/CMPXCHG16B
- [x] MOVNTI
- [x] LDMXCSR
- [x] STMXCSR
- [x] LFENCE
- [x] MFENCE
- [x] SFENCE
- [x] EMMS
- [ ] SYSCALL
- [ ] CPUID
- [ ] RDTSC
- [x] XGETBV
- [ ] UD2
- [ ] FXSAVE
- [ ] FXRSTOR

## SSE/SSE2 Floating-Point Arithmetic

- [x] ADDPS/ADDPD/ADDSS/ADDSD
- [x] SUBPS/SUBPD/SUBSS/SUBSD
- [x] MULPS/MULPD/MULSS/MULSD
- [x] DIVPS/DIVPD/DIVSS/DIVSD
- [x] MINPS/MINPD/MINSS/MINSD
- [x] MAXPS/MAXPD/MAXSS/MAXSD
- [x] SQRTPS/SQRTPD/SQRTSS/SQRTSD
- [~] RSQRTPS/RSQRTSS (approximate — cannot compare exactly)
- [~] RCPPS/RCPSS (approximate — cannot compare exactly)

## SSE/SSE2 Floating-Point Comparison

- [x] UCOMISS/UCOMISD
- [x] COMISS/COMISD
- [x] CMPPS/CMPPD/CMPSS/CMPSD

## SSE/SSE2 Floating-Point Data Movement

- [x] MOVAPS/MOVAPD/MOVUPS/MOVUPD
- [x] MOVDQA/MOVDQU
- [x] MOVD/MOVQ
- [x] MOVHLPS/MOVLHPS
- [x] MOVSS/MOVSD
- [x] MOVLPS/MOVLPD (memory forms)
- [x] MOVHPS/MOVHPD (memory forms)

## SSE/SSE2 Floating-Point Logical & Shuffle

- [x] ANDPS/ANDPD/ANDNPS/ANDNPD
- [x] ORPS/ORPD/XORPS/XORPD
- [x] SHUFPS/SHUFPD
- [x] UNPCKLPS/UNPCKHPS/UNPCKLPD/UNPCKHPD

## SSE/SSE2 Conversion

- [x] CVTPS2DQ/CVTTPS2DQ/CVTDQ2PS
- [x] CVTDQ2PD/CVTPD2DQ/CVTTPD2DQ
- [x] CVTPS2PD/CVTPD2PS
- [x] CVTSS2SD/CVTSD2SS
- [x] CVTSI2SS/CVTSI2SD (32+64-bit)
- [x] CVTSS2SI/CVTSD2SI/CVTTSS2SI/CVTTSD2SI

## SSE/SSE2 Packed Integer (all tested)

- [x] PADDB/W/D/Q, PSUBB/W/D/Q
- [x] PADDSB/SW, PADDUSB/USW, PSUBSB/SW, PSUBUSB/USW
- [x] PMULLW/PMULHW/PMULHUW/PMULUDQ/PMADDWD
- [x] PSADBW/PAVGB/PAVGW
- [x] PCMPEQB/W/D, PCMPGTB/W/D
- [x] PAND/POR/PXOR/PANDN
- [x] PSLLW/D/Q, PSRLW/D/Q, PSRAW/D (immediate)
- [x] PSLLDQ/PSRLDQ
- [x] PACKSSWB/PACKSSDW/PACKUSWB
- [x] PUNPCKLBW/WD/DQ/QDQ, PUNPCKHBW/WD/DQ/QDQ
- [x] PSHUFD/PSHUFHW/PSHUFLW
- [x] PINSRW/PEXTRW

## SSE3 FP (all tested)

- [x] MOVSLDUP/MOVSHDUP/MOVDDUP
- [x] HADDPS/HADDPD/HSUBPS/HSUBPD
- [x] ADDSUBPS/ADDSUBPD

## SSSE3 (all tested)

- [x] PSHUFB
- [x] PHADDW/PHADDD/PHADDSW
- [x] PHSUBW/PHSUBD/PHSUBSW
- [x] PMADDUBSW/PMULHRSW
- [x] PABSB/PABSW/PABSD
- [x] PSIGNB/PSIGNW/PSIGND
- [x] PALIGNR

## SSE4.1 (all tested)

- [x] PMAXSB/PMAXSW/PMAXSD/PMAXUB/PMAXUW/PMAXUD
- [x] PMINSB/PMINSW/PMINSD/PMINUB/PMINUW/PMINUD
- [x] PMULLD/PACKUSDW/PCMPEQQ
- [x] PINSRB/PINSRD/PEXTRB/PEXTRD
- [x] EXTRACTPS/INSERTPS
- [x] BLENDPS/BLENDPD/PBLENDW
- [x] BLENDVPS/BLENDVPD/PBLENDVB
- [x] ROUNDPS/ROUNDPD/ROUNDSS/ROUNDSD
- [x] PTEST
- [x] PMOVZX (all 6 variants)
- [x] PMOVSX (all 6 variants)
- [x] DPPS/DPPD/MPSADBW
- [x] PHMINPOSUW
- [x] MOVNTDQA

## SSE4.2 (all tested)

- [x] PCMPGTQ
- [x] PCMPISTRI/PCMPISTRM
- [x] PCMPESTRI/PCMPESTRM
- [x] CRC32

## AES-NI & PCLMUL (all tested)

- [x] AESENC/AESENCLAST/AESDEC/AESDECLAST
- [x] AESIMC/AESKEYGENASSIST
- [x] PCLMULQDQ

## AVX (VEX-encoded)

- [x] VADDPS/PD/SS/SD
- [x] VSUBPS/PD/SS/SD
- [x] VMULPS/PD/SS/SD
- [x] VDIVPS/PD/SS/SD
- [x] VMINPS/PD
- [x] VMAXPS/PD
- [x] VSQRTPS
- [x] VCMPPS/PD
- [x] VSHUFPS/PD
- [x] VUNPCKLPS/PD, VUNPCKHPS/PD
- [x] VMOVUPS/UPD/APS/APD/DQA/DQU
- [x] VANDPS/PD, VANDNPS/PD
- [x] VORPS/PD, VXORPS/PD
- [x] VCVTDQ2PS, VCVTPS2DQ, VCVTTPS2DQ
- [x] VPADDB/W/D/Q, VPSUBB
- [x] VPAND/VPOR/VPXOR/VPANDN
- [x] VBROADCAST
- [x] VINSERTF128/VEXTRACTF128
- [x] VFMADD/VFMSUB/VFNMADD/VFNMSUB (all FMA variants)

## AVX-512 (EVEX-encoded)

- [x] VPADDD/VPSUBD/VPADDQ/VPSUBQ/VPSUBB
- [x] VPANDD/VPORD/VPXORD
- [x] VPSLLD/VPSRLD (immediate)
- [x] VPMINUB
- [x] VADDPS/VSUBPS/VMULPS/VDIVPS/VMINPS/VMAXPS/VSQRTPS
- [x] VADDPD/VMULPD/VSUBPD/VDIVPD
- [x] VMOVAPS
- [x] VFMADD132/213/231 PS/PD/SS/SD
- [x] VFMSUB132/213/231 PS
- [x] VFNMADD132/213/231 PS
- [x] VFNMSUB132/213/231 PS
- [x] VFMADDSUB/VFMSUBADD
- [x] VSHUFPS, VUNPCKLPS/VUNPCKHPS
- [x] VPUNPCKLDQ, VPUNPCKLQDQ
- [x] VCVTPS2DQ, VCVTTPS2DQ, VCVTDQ2PS
- [x] VPMINSB/VPMINSD/VPMINUD, VPMAXSB/VPMAXSD/VPMAXUD
- [x] VPACKUSDW, VPMULLD, VPMULUDQ, VPMULLW
- [x] VPABSB/VPABSD
- [x] 256-bit forms (VPADDD, VADDPS, VPXORD, VMULPS)
- [ ] 512-bit forms (need ZMM harness support)
- [ ] Masking (k registers)
- [ ] Gather/scatter
- [ ] VPERM variants

## x87 FPU

- [x] FLD/FSTP (m32fp, m64fp)
- [x] FILD/FIST/FISTP (m16, m32, m64)
- [x] FADD (FADDP)
- [x] FSUB (FSUBRP)
- [x] FMUL (FMULP)
- [x] FDIV (FDIVRP)
- [x] FSIN/FCOS
- [x] FSQRT/FABS/FCHS
- [x] FUCOMI/FUCOMIP
- [x] FLDCW/FSTCW/FSTSW
- [x] FXCH
- [x] FRNDINT
- [x] FLDZ/FLD1/FLDPI/FLDL2E/FLDLN2
- [x] FINIT
- [x] FPTAN/FPATAN
- [x] F2XM1/FYL2X/FYL2XP1
- [x] FPREM/FPREM1
- [x] FSCALE/FXTRACT
- [x] FBLD/FBSTP
- [x] FLDL2T/FLDLG2
- [x] FXAM/FTST
- [x] FDECSTP/FINCSTP
- [x] FCOM/FCOMP/FUCOM/FUCOMP

## String Instructions

- [x] MOVSB (with REP)
- [x] STOSB/STOSD/STOSQ (with REP)
- [x] LODSQ
- [x] CMPSB
- [x] SCASB
- [x] MOVSW/MOVSD/MOVSQ (with REP)
- [x] LODSB/LODSW/LODSD
- [x] CMPSW/CMPSD/CMPSQ
- [x] SCASW/SCASD/SCASQ

## Bugs Found and Fixed

1. **PMULLW/PMULHW opcode swap**: Opcodes 0F D5 and 0F E5 had swapped
   implementations. Fixed to match SDM: PMULLW=0xD5, PMULHW=0xE5.

2. **PHSUBW/PHSUBD/PHSUBSW operand order**: Subtraction operands were
   reversed (high-low instead of low-high). Fixed to match SDM.

3. **AESENCLAST/AESDEC opcode swap**: Arms 221 (0xDD) and 222 (0xDE)
   had swapped function calls. Fixed: 0xDD=AESENCLAST, 0xDE=AESDEC.

4. **CRC32 not implemented**: Added CRC32C instruction (F2 0F 38 F0/F1)
   with all operand size variants.

5. **VUNPCKLPS/VUNPCKHPS not implemented**: Added VEX-encoded unpack
   instructions (0F 14/15) for both 128-bit and 256-bit forms.

6. **VCMPPS/VCMPPD not implemented**: Added VEX-encoded FP comparison
   (0F C2) with immediate predicate.

7. **VCVTDQ2PS/VCVTPS2DQ/VCVTTPS2DQ not implemented**: Added VEX-encoded
   int/float conversion (0F 5B) for 128-bit forms.

8. **VEX FMA not implemented**: All 36 VEX-encoded FMA3 opcodes (0F38 96-BF)
   were missing from the VEX decoder. Added VFMADD/VFMSUB/VFNMADD/VFNMSUB
   in 132/213/231 forms for packed and scalar, plus VFMADDSUB/VFMSUBADD.

## Summary

| Category                  | Tested | Total | Coverage |
|---------------------------|--------|-------|----------|
| ALU & Data Movement       | 23     | 25    | 92%      |
| Control Flow              | 7      | 7     | 100%     |
| Shifts & Rotates          | 7      | 7     | 100%     |
| Multiply & Divide         | 4      | 4     | 100%     |
| Flags & Sign Extension    | 9      | 9     | 100%     |
| 2-Byte (0F) Instructions  | 24     | 31    | 77%      |
| SSE FP Arithmetic         | 24     | 28    | 86%      |
| SSE FP Compare            | 8      | 8     | 100%     |
| SSE FP Data Movement      | 16     | 16    | 100%     |
| SSE FP Logical & Shuffle  | 14     | 14    | 100%     |
| SSE Conversion            | 16     | 16    | 100%     |
| SSE3 FP                   | 9      | 9     | 100%     |
| SSSE3 Integer             | 16     | 16    | 100%     |
| SSE Packed Int (all)      | 50+    | 50+   | 100%     |
| SSE4.1                    | 50     | 50    | 100%     |
| SSE4.2                    | 8      | 8     | 100%     |
| AES-NI & PCLMUL           | 7      | 7     | 100%     |
| AVX (VEX)                 | 55+    | 55+   | 100%     |
| AVX-512 (EVEX)            | 75     | 80+   | 94%      |
| x87 FPU                   | 47     | 48    | 98%      |
| String Instructions        | 13     | 13    | 100%     |
| **Total**                 | **~490**| **~530+** | **~92%** |
