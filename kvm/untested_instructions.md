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
- [x] IMUL (2/3-operand)
- [x] MOVSXD
- [ ] POP
- [ ] ENTER
- [ ] LEAVE
- [ ] IN
- [ ] OUT
- [ ] LOOP/LOOPcc

## Control Flow

- [x] CALL
- [x] RET
- [x] JMP
- [x] Jcc (JE, JL, etc.)
- [ ] LOOP
- [ ] LOOPcc

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
- [ ] SETcc (all condition codes)

## 2-Byte Opcode Instructions (0F xx)

- [x] CMOVcc (CMOVB, CMOVE, CMOVG, CMOVL)
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
- [ ] SYSCALL
- [ ] CPUID
- [ ] RDTSC
- [ ] XGETBV
- [ ] UD2
- [ ] CMPXCHG8B/CMPXCHG16B
- [ ] MOVNTI
- [ ] FXSAVE
- [ ] FXRSTOR
- [ ] LDMXCSR
- [ ] STMXCSR
- [ ] LFENCE
- [ ] MFENCE
- [ ] SFENCE
- [ ] EMMS
- [ ] CMOVcc (remaining: CMOVNB, CMOVNE, CMOVGE, CMOVLE, CMOVS, CMOVNS, CMOVP, CMOVNP, CMOVA, CMOVBE)

## SSE/SSE2 Floating-Point Arithmetic

- [x] ADDPS
- [x] ADDPD
- [x] ADDSS
- [x] ADDSD
- [x] SUBPS
- [x] SUBPD
- [x] SUBSS
- [x] SUBSD
- [x] MULPS
- [x] MULPD
- [x] MULSS
- [x] MULSD
- [x] DIVPS
- [x] DIVPD
- [x] DIVSS
- [x] DIVSD
- [x] MINPS
- [x] MAXPS
- [x] MINPD
- [x] MINSS
- [x] MINSD
- [x] MAXPD
- [x] MAXSS
- [x] MAXSD
- [x] SQRTPS
- [x] SQRTPD
- [x] SQRTSS
- [x] SQRTSD
- [~] RSQRTPS (approximate — cannot compare exactly)
- [~] RSQRTSS (approximate — cannot compare exactly)
- [~] RCPPS (approximate — cannot compare exactly)
- [~] RCPSS (approximate — cannot compare exactly)

## SSE/SSE2 Floating-Point Comparison

- [x] UCOMISS
- [x] UCOMISD
- [x] CMPPS (EQ, LT, LE)
- [x] CMPPD (EQ, LT)
- [x] CMPSS (EQ)
- [x] CMPSD (LT)
- [ ] COMISS
- [ ] COMISD

## SSE/SSE2 Floating-Point Data Movement

- [x] MOVAPS
- [x] MOVUPS
- [x] MOVD
- [x] MOVQ
- [x] MOVAPD
- [x] MOVUPD
- [x] MOVDQA
- [x] MOVDQU
- [ ] MOVLPS
- [ ] MOVLPD
- [ ] MOVHLPS
- [ ] MOVSS
- [ ] MOVSD (SSE move, not string)
- [ ] MOVHPS
- [ ] MOVHPD
- [ ] MOVLHPS

## SSE/SSE2 Floating-Point Logical & Shuffle

- [x] SHUFPS
- [x] UNPCKLPS
- [x] UNPCKHPS
- [x] SHUFPD
- [x] UNPCKLPD
- [x] UNPCKHPD
- [x] ANDPS
- [x] ANDPD
- [x] ANDNPS
- [x] ANDNPD
- [x] ORPS
- [x] ORPD
- [x] XORPS
- [x] XORPD

## SSE/SSE2 Conversion

- [x] CVTPS2DQ
- [x] CVTTPS2DQ
- [x] CVTDQ2PS
- [ ] CVTDQ2PD
- [ ] CVTPD2DQ
- [ ] CVTTPD2DQ
- [ ] CVTPS2PD
- [ ] CVTPD2PS
- [ ] CVTSS2SD
- [ ] CVTSD2SS
- [ ] CVTSS2SI
- [ ] CVTSD2SI
- [ ] CVTSI2SS
- [ ] CVTSI2SD
- [ ] CVTTSS2SI
- [ ] CVTTSD2SI

## SSE3/SSSE3

- [ ] MOVSLDUP
- [ ] MOVSHDUP
- [ ] MOVDDUP
- [ ] HADDPS
- [ ] HADDPD
- [ ] HSUBPS
- [ ] HSUBPD
- [ ] ADDSUBPS
- [ ] ADDSUBPD
- [ ] PSHUFB
- [ ] PHADDW
- [ ] PHADDD
- [ ] PHADDSW
- [ ] PHSUBW
- [ ] PHSUBD
- [ ] PHSUBSW
- [ ] PMADDUBSW
- [ ] PMULHRSW
- [ ] PABSB
- [ ] PABSW
- [ ] PABSD
- [ ] PSIGNB
- [ ] PSIGNW
- [ ] PSIGND
- [ ] PALIGNR

## SSE/SSE2 Packed Integer Arithmetic

- [x] PADDB
- [x] PADDW
- [x] PADDD
- [x] PADDQ
- [x] PSUBB
- [x] PSUBW
- [x] PSUBD
- [x] PSUBQ
- [x] PADDSB
- [x] PADDSW
- [x] PADDUSB
- [x] PADDUSW
- [x] PSUBSB
- [x] PSUBSW
- [x] PSUBUSB
- [x] PSUBUSW
- [x] PMULLW
- [x] PMULHW
- [x] PMULHUW
- [x] PMULUDQ
- [x] PMADDWD
- [x] PSADBW
- [x] PAVGB
- [x] PAVGW

## SSE/SSE2 Packed Integer Comparison

- [x] PCMPEQB
- [x] PCMPEQW
- [x] PCMPEQD
- [x] PCMPGTB
- [x] PCMPGTW
- [x] PCMPGTD

## SSE/SSE2 Packed Integer Logical & Shift

- [x] PAND
- [x] POR
- [x] PXOR
- [x] PANDN
- [x] PSLLW
- [x] PSLLD
- [x] PSLLQ
- [x] PSRLW
- [x] PSRLD
- [x] PSRLQ
- [x] PSRAW
- [x] PSRAD
- [ ] PSLLDQ
- [ ] PSRLDQ

## SSE/SSE2 Packed Integer Data Movement

- [x] PACKSSWB
- [x] PACKSSDW
- [x] PACKUSWB
- [x] PUNPCKLBW
- [x] PUNPCKLWD
- [x] PUNPCKLDQ
- [x] PUNPCKLQDQ
- [x] PUNPCKHBW
- [x] PUNPCKHWD
- [x] PUNPCKHDQ
- [x] PUNPCKHQDQ
- [x] PSHUFD
- [x] PSHUFHW
- [x] PSHUFLW

## SSE4.1

- [ ] PMAXSB
- [ ] PMAXSW
- [ ] PMAXSD
- [ ] PMAXUB
- [ ] PMAXUW
- [ ] PMAXUD
- [ ] PMINSB
- [ ] PMINSW
- [ ] PMINSD
- [ ] PMINUB
- [ ] PMINUW
- [ ] PMINUD
- [ ] PMULLD
- [ ] PACKUSDW
- [ ] PCMPEQQ
- [ ] PINSRB
- [ ] PINSRD/PINSRQ
- [ ] PINSRW
- [ ] PEXTRB
- [ ] PEXTRD/PEXTRQ
- [ ] PEXTRW
- [ ] EXTRACTPS
- [ ] INSERTPS
- [ ] BLENDPS
- [ ] BLENDPD
- [ ] BLENDVPS
- [ ] BLENDVPD
- [ ] PBLENDW
- [ ] PBLENDVB
- [ ] DPPS
- [ ] DPPD
- [ ] ROUNDPS
- [ ] ROUNDPD
- [ ] ROUNDSS
- [ ] ROUNDSD
- [ ] MPSADBW
- [ ] PTEST
- [ ] PMOVSX (all variants)
- [ ] PMOVZX (all variants)
- [ ] MOVNTDQA

## SSE4.2

- [ ] PCMPESTRI
- [ ] PCMPESTRM
- [ ] PCMPISTRI
- [ ] PCMPISTRM
- [ ] PCMPGTQ
- [ ] CRC32

## AES-NI & PCLMUL

- [ ] AESIMC
- [ ] AESENC
- [ ] AESENCLAST
- [ ] AESDEC
- [ ] AESDECLAST
- [ ] AESKEYGENASSIST
- [ ] PCLMULQDQ

## AVX (VEX-encoded) - None tested

- [ ] VADDPS/PD/SS/SD
- [ ] VSUBPS/PD/SS/SD
- [ ] VMULPS/PD/SS/SD
- [ ] VDIVPS/PD/SS/SD
- [ ] VMINPS/PD/SS/SD
- [ ] VMAXPS/PD/SS/SD
- [ ] VSQRTPS/PD/SS/SD
- [ ] VRSQRTPS/SS
- [ ] VRCPPS/SS
- [ ] VCMPPS/PD/SS/SD
- [ ] VSHUFPS/PD
- [ ] VUNPCKLPS/PD
- [ ] VUNPCKHPS/PD
- [ ] VMOVUPS/UPD/APS/APD/DQA/DQU
- [ ] VMOVLPS/LPD/HLPS
- [ ] VMOVSLDUP/SHDUP/DDUP
- [ ] VANDPS/PD
- [ ] VANDNPS/PD
- [ ] VORPS/PD
- [ ] VXORPS/PD
- [ ] VCVTDQ2PS/PD
- [ ] VCVTPS2DQ/PD
- [ ] VCVTPD2DQ/PS
- [ ] VCVTTPS2DQ
- [ ] VCVTTPD2DQ
- [ ] VPADDB/W/D/Q
- [ ] VPSUBB/W/D/Q
- [ ] VPCMPEQD
- [ ] VPINSRW
- [ ] VBROADCAST
- [ ] VINSERTF128
- [ ] VEXTRACTF128
- [ ] VFMADD132PS/PD/SS/SD (and all FMA variants)

## AVX-512 (EVEX-encoded) - None tested

- [ ] All EVEX arithmetic instructions
- [ ] All EVEX FMA instructions
- [ ] All EVEX permutation/gather/scatter instructions
- [ ] All EVEX integer instructions
- [ ] All EVEX floating-point instructions

## x87 FPU - None tested

- [ ] FLD/FST/FSTP (all variants)
- [ ] FADD/FSUB/FMUL/FDIV (all variants)
- [ ] FSUBR/FDIVR
- [ ] FSIN/FCOS/FTAN/FATAN
- [ ] FSQRT/FABS/FCHS
- [ ] FCOM/FCOMP/FUCOM/FUCOMP/FUCOMI/FUCOMIP
- [ ] FLDCW/FSTCW/FSTSW
- [ ] FXCH/FFREE/FINCSTP/FDECSTP
- [ ] FRNDINT/FSCALE/FXTRACT
- [ ] FPREM/FPREM1
- [ ] FYL2X/FYL2XP1
- [ ] F2XM1
- [ ] FBLD/FBSTP
- [ ] FLDZ/FLD1/FLDPI/FLDL2E/FLDL2T/FLDLN2/FLDLG2
- [ ] FIST/FISTP/FISTTP
- [ ] FINIT/FCLEX
- [ ] FXAM/FTST

## String Instructions - None tested

- [ ] MOVSB/MOVSW/MOVSD/MOVSQ (with REP)
- [ ] STOSB/STOSW/STOSD/STOSQ (with REP)
- [ ] LODSB/LODSW/LODSD/LODSQ
- [ ] CMPSB/CMPSW/CMPSD/CMPSQ (with REP/REPNE)
- [ ] SCASB/SCASW/SCASD/SCASQ (with REP/REPNE)

## Bugs Found

- **PMULLW/PMULHW opcode swap** (fixed): Opcodes 0F D5 and 0F E5 had swapped
  implementations — PMULLW (low) was on 0xE5 and PMULHW (high) was on 0xD5,
  but the Intel SDM specifies PMULLW=0xD5 and PMULHW=0xE5.

## Summary

| Category                  | Tested | Total | Coverage |
|---------------------------|--------|-------|----------|
| ALU & Data Movement       | 20     | 25    | 80%      |
| Control Flow              | 5      | 7     | 71%      |
| Shifts & Rotates          | 7      | 7     | 100%     |
| Multiply & Divide         | 4      | 4     | 100%     |
| Flags & Sign Extension    | 8      | 9     | 89%      |
| 2-Byte (0F) Instructions  | 16     | 27    | 59%      |
| SSE FP Arithmetic         | 24     | 28    | 86%      |
| SSE FP Compare            | 8      | 10    | 80%      |
| SSE FP Data Movement      | 8      | 16    | 50%      |
| SSE FP Logical & Shuffle  | 14     | 14    | 100%     |
| SSE Conversion            | 3      | 16    | 19%      |
| SSE3/SSSE3                | 0      | 24    | 0%       |
| SSE Packed Int Arithmetic  | 24     | 24    | 100%     |
| SSE Packed Int Compare     | 6      | 6     | 100%     |
| SSE Packed Int Logical     | 12     | 14    | 86%      |
| SSE Packed Int Data Move   | 14     | 14    | 100%     |
| SSE4.1                    | 0      | 37    | 0%       |
| SSE4.2                    | 0      | 6     | 0%       |
| AES-NI & PCLMUL           | 0      | 7     | 0%       |
| AVX (VEX)                 | 0      | 35+   | 0%       |
| AVX-512 (EVEX)            | 0      | 30+   | 0%       |
| x87 FPU                   | 0      | 80+   | 0%       |
| String Instructions        | 0      | 5     | 0%       |
| **Total**                 | **~173**| **~450+** | **~38%** |
