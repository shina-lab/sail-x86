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
- [ ] MOVLPS/MOVLPD (memory forms)
- [ ] MOVHPS/MOVHPD (memory forms)

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

## SSSE3 (all tested)

- [x] PSHUFB
- [x] PHADDW/PHADDD/PHADDSW
- [x] PHSUBW/PHSUBD/PHSUBSW
- [x] PMADDUBSW/PMULHRSW
- [x] PABSB/PABSW/PABSD
- [x] PSIGNB/PSIGNW/PSIGND
- [x] PALIGNR
- [ ] MOVSLDUP/MOVSHDUP/MOVDDUP (SSE3 FP)
- [ ] HADDPS/HADDPD/HSUBPS/HSUBPD (SSE3 FP)
- [ ] ADDSUBPS/ADDSUBPD (SSE3 FP)

## SSE4.1 (all tested)

- [x] PMAXSB/PMAXSW/PMAXSD/PMAXUB/PMAXUW/PMAXUD
- [x] PMINSB/PMINSW/PMINSD/PMINUB/PMINUW/PMINUD
- [x] PMULLD/PACKUSDW/PCMPEQQ
- [x] PINSRB/PINSRD/PEXTRB/PEXTRD
- [x] EXTRACTPS/INSERTPS
- [x] BLENDPS/BLENDPD/PBLENDW
- [x] ROUNDPS/ROUNDPD/ROUNDSS/ROUNDSD
- [x] PTEST
- [x] PMOVZX (all 6 variants)
- [x] PMOVSX (all 6 variants)
- [x] DPPS/DPPD/MPSADBW
- [ ] BLENDVPS/BLENDVPD/PBLENDVB (variable blend — uses XMM0)
- [ ] PHMINPOSUW
- [ ] MOVNTDQA

## SSE4.2 (all tested)

- [x] PCMPGTQ
- [x] PCMPISTRI/PCMPISTRM
- [x] PCMPESTRI/PCMPESTRM
- [x] CRC32

## AES-NI & PCLMUL (all tested)

- [x] AESENC/AESENCLAST/AESDEC/AESDECLAST
- [x] AESIMC/AESKEYGENASSIST
- [x] PCLMULQDQ

## AVX (VEX-encoded) - None tested

- [ ] VADDPS/PD/SS/SD
- [ ] VSUBPS/PD/SS/SD
- [ ] VMULPS/PD/SS/SD
- [ ] VDIVPS/PD/SS/SD
- [ ] VMINPS/PD/SS/SD
- [ ] VMAXPS/PD/SS/SD
- [ ] VSQRTPS/PD/SS/SD
- [ ] VCMPPS/PD/SS/SD
- [ ] VSHUFPS/PD
- [ ] VUNPCKLPS/PD, VUNPCKHPS/PD
- [ ] VMOVUPS/UPD/APS/APD/DQA/DQU
- [ ] VANDPS/PD, VANDNPS/PD
- [ ] VORPS/PD, VXORPS/PD
- [ ] VCVTDQ2PS/PD, VCVTPS2DQ/PD, VCVTPD2DQ/PS
- [ ] VPADDB/W/D/Q, VPSUBB/W/D/Q
- [ ] VBROADCAST
- [ ] VINSERTF128/VEXTRACTF128
- [ ] VFMADD/VFMSUB/VFNMADD/VFNMSUB (all FMA variants)

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

## Bugs Found and Fixed

1. **PMULLW/PMULHW opcode swap**: Opcodes 0F D5 and 0F E5 had swapped
   implementations. Fixed to match SDM: PMULLW=0xD5, PMULHW=0xE5.

2. **PHSUBW/PHSUBD/PHSUBSW operand order**: Subtraction operands were
   reversed (high-low instead of low-high). Fixed to match SDM.

3. **AESENCLAST/AESDEC opcode swap**: Arms 221 (0xDD) and 222 (0xDE)
   had swapped function calls. Fixed: 0xDD=AESENCLAST, 0xDE=AESDEC.

4. **CRC32 not implemented**: Added CRC32C instruction (F2 0F 38 F0/F1)
   with all operand size variants.

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
| SSE FP Compare            | 8      | 8     | 100%     |
| SSE FP Data Movement      | 12     | 16    | 75%      |
| SSE FP Logical & Shuffle  | 14     | 14    | 100%     |
| SSE Conversion            | 16     | 16    | 100%     |
| SSE3 FP                   | 0      | 9     | 0%       |
| SSSE3 Integer             | 16     | 16    | 100%     |
| SSE Packed Int (all)      | 50+    | 50+   | 100%     |
| SSE4.1                    | 47     | 50    | 94%      |
| SSE4.2                    | 8      | 8     | 100%     |
| AES-NI & PCLMUL           | 7      | 7     | 100%     |
| AVX (VEX)                 | 0      | 35+   | 0%       |
| AVX-512 (EVEX)            | 0      | 30+   | 0%       |
| x87 FPU                   | 0      | 80+   | 0%       |
| String Instructions        | 0      | 5     | 0%       |
| **Total**                 | **~270**| **~450+** | **~60%** |
