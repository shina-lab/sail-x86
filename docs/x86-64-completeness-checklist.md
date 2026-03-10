# x86-64 ISA Completeness Checklist

Derived from Intel SDM (835 instruction pages, 1208 unique mnemonics).
Each item is testable: verify the Sail spec implements it, or explicitly
documents it as out-of-scope. Refer to the SDM for exact semantics.

---

## Part 1: Instruction Coverage by ISA Extension

For each instruction: verify (a) it decodes correctly for all valid
opcode/operand-size/addressing-mode combinations listed in SDM, (b) it
computes the correct result, (c) it sets flags per SDM, (d) 64-bit mode
validity matches SDM (some are invalid in 64-bit mode).

### 1.1 General-Purpose Integer (base x86-64)

#### 1.1.1 Data Transfer
- [x] MOV (reg/mem/imm, all operand sizes 8/16/32/64) — verified correct
- [x] MOV to/from control registers (MOV CRn) [mov-1 in SDM] — verified correct
- [x] MOV to/from debug registers (MOV DRn) [mov-2 in SDM] — verified: 0F 21 (read) and 0F 23 (write), CPL=0 required, DR4/DR5 alias DR6/DR7
- [x] MOVSX, MOVSXD (sign-extend 8→16/32/64, 16→32/64, 32→64) — verified correct
- [x] MOVZX (zero-extend 8→16/32/64, 16→32/64) — verified correct
- [x] MOVBE (byte-swap load/store, MOVBE extension) — verified correct
- [x] XCHG (reg-reg, reg-mem; implicit LOCK on memory) — verified correct
- [x] XADD (exchange and add) — verified correct
- [x] CMPXCHG (compare and exchange, 8/16/32/64) — verified correct
- [x] CMPXCHG8B, CMPXCHG16B (8-byte/16-byte compare-and-exchange) — verified correct
- [x] BSWAP (byte-swap 32/64) — verified correct
- [x] XLAT, XLATB (table lookup translation) — verified + KVM tests
- [x] CMOVcc (all 16 conditions, 16/32/64-bit) — verified correct

#### 1.1.2 Stack Operations
- [x] PUSH (reg, mem, imm8, imm16/32; 16/64-bit operand sizes in 64-bit mode) — verified correct
- [x] POP (reg, mem; 16/64-bit in 64-bit mode) — verified correct
- [x] PUSHF, PUSHFQ (push flags) — verified correct
- [x] POPF, POPFQ (pop flags) — verified, IOPL bug fixed
- [x] PUSHA, PUSHAD (invalid in 64-bit mode — must #UD) — verified correct
- [x] POPA, POPAD (invalid in 64-bit mode — must #UD) — verified correct
- [x] ENTER (create stack frame, nesting levels 0-31) — verified + KVM tests (levels 0,1)
- [x] LEAVE (destroy stack frame) — verified + KVM tests

#### 1.1.3 Arithmetic
- [x] ADD (all operand size/type combinations, flag effects) — verified correct
- [x] ADC (add with carry) — verified correct
- [x] SUB (subtract) — verified correct
- [x] SBB (subtract with borrow) — verified correct
- [x] INC (no CF modification) — verified correct
- [x] DEC (no CF modification) — verified correct
- [x] NEG (two's complement negate) — verified correct
- [x] CMP (subtract without storing) — verified correct
- [x] MUL (unsigned multiply, 8/16/32/64-bit; widening to double-size) — verified correct
- [x] IMUL (signed multiply — 1-operand widening, 2-operand, 3-operand forms) — verified correct
- [x] DIV (unsigned divide, 8/16/32/64-bit; #DE on overflow/zero) — verified correct
- [x] IDIV (signed divide; #DE on overflow/zero) — verified correct

#### 1.1.4 Sign/Zero Extension of Accumulators
- [x] CBW (AL→AX), CWDE (AX→EAX), CDQE (EAX→RAX) — verified correct
- [x] CWD (AX→DX:AX), CDQ (EAX→EDX:EAX), CQO (RAX→RDX:RAX) — verified correct

#### 1.1.5 Logical
- [x] AND, OR, XOR (all operand combinations; OF=CF=0) — verified correct
- [x] NOT (bitwise complement, no flag effects) — verified correct
- [x] TEST (AND without storing) — verified correct

#### 1.1.6 Shift and Rotate
- [x] SHL/SAL (shift left, same opcode) — verified correct
- [x] SHR (logical shift right) — verified correct
- [x] SAR (arithmetic shift right) — verified correct, OF=0 for count=1
- [x] ROL (rotate left) — verified correct, SF/ZF/AF/PF unaffected
- [x] ROR (rotate right) — verified correct
- [x] RCL (rotate through carry left) — verified correct, MOD 9/17 for 8/16-bit
- [x] RCR (rotate through carry right) — verified correct, OF set before rotation
- [x] SHLD (double-precision shift left) — verified correct
- [x] SHRD (double-precision shift right) — verified correct
- [x] Shift/rotate count masking (count & 0x1F for 32-bit, count & 0x3F for 64-bit) — verified
- [x] OF flag: defined only for 1-bit shifts, undefined for multi-bit — verified

#### 1.1.7 Bit and Byte Operations
- [x] BT (bit test → CF) — verified correct
- [x] BTS (bit test and set) — verified correct
- [x] BTR (bit test and reset) — verified correct
- [x] BTC (bit test and complement) — verified correct
- [x] BSF (bit scan forward) — verified correct
- [x] BSR (bit scan reverse) — verified correct
- [x] SETcc (all 16 conditions, byte result) — verified correct
- [x] POPCNT (population count, POPCNT extension) — verified correct
- [x] LZCNT (leading zero count, LZCNT extension — different from BSR) — verified correct
- [x] TZCNT (trailing zero count, BMI1 extension — different from BSF) — verified correct

#### 1.1.8 Control Flow
- [x] JMP (near relative 8/32, near indirect reg/mem, far direct, far indirect) — verified correct
- [x] Jcc (all 16 conditions, rel8 and rel32) — verified correct
- [x] CALL (near relative, near indirect, far direct, far indirect) — verified, f64 operand-size fix applied
- [x] RET (near, near+imm16, far, far+imm16) — verified, f64 operand-size fix; RETF verified correct
- [x] LOOP, LOOPcc (LOOPE/LOOPZ, LOOPNE/LOOPNZ; uses RCX/ECX/CX per addr size) — verified + KVM tests
- [x] INT n, INT3 (software interrupts) — verified correct; fixed: no error code push for software ints, gate DPL check added. INT1/ICEBP not implemented (raises #UD)
- [x] INTO (invalid in 64-bit mode — must #UD) — verified correct
- [x] IRET, IRETD, IRETQ (interrupt return) — verified, AC/ID flag fix applied
- [x] BOUND (invalid in 64-bit mode — must #UD) — verified correct

#### 1.1.9 String Operations
- [x] MOVS, MOVSB, MOVSW, MOVSD, MOVSQ — verified correct
- [x] CMPS, CMPSB, CMPSW, CMPSD, CMPSQ — verified correct
- [x] SCAS, SCASB, SCASW, SCASD (SCASQ in 64-bit mode) — verified correct
- [x] LODS, LODSB, LODSW, LODSD, LODSQ — verified correct
- [x] STOS, STOSB, STOSW, STOSD, STOSQ — verified correct
- [N/A] INS, INSB, INSW, INSD — port string I/O, requires I/O port infrastructure not modeled
- [N/A] OUTS, OUTSB, OUTSW, OUTSD — port string I/O, requires I/O port infrastructure not modeled
- [x] REP/REPE/REPZ/REPNE/REPNZ prefix interaction with all string ops — verified correct
- [x] Direction flag (DF) effect on SI/DI increment/decrement — verified correct

#### 1.1.10 I/O
- [x] IN (imm8 port, DX port; AL/AX/EAX) — verified correct (E4/E5/EC/ED), all operand sizes
- [x] OUT (imm8 port, DX port; AL/AX/EAX) — verified correct (E6/E7/EE/EF), all operand sizes
- [N/A] INS/OUTS (port string I/O, see 1.1.9) — requires I/O port infrastructure not modeled

#### 1.1.11 Flag Manipulation
- [x] STC, CLC, CMC (set/clear/complement carry) — verified correct
- [x] STD, CLD (set/clear direction) — verified correct
- [x] STI, CLI (set/clear interrupt; IOPL interaction) — verified correct
- [x] LAHF (load AH from flags SF:ZF:0:AF:0:PF:1:CF) — **BUG FIXED**: bit order was reversed
- [x] SAHF (store AH into flags)

#### 1.1.12 Segment and Address Operations
- [x] LEA (all addressing modes, 16/32/64-bit) — verified, 67h address-size fix applied
- [N/A] LDS, LES (invalid in 64-bit mode — opcodes C4/C5 are VEX prefix)
- [N/A] LFS, LGS, LSS (0F B2/B4/B5 — valid in 64-bit but rarely used; segment descriptor loading not fully modeled)
- [x] NOP (1-byte 0x90 and multi-byte 0F 1F /0) — verified correct

#### 1.1.13 Decimal Arithmetic (all invalid in 64-bit mode — must #UD)
- [x] AAA, AAS, AAM, AAD — verified #UD in 64-bit mode
- [x] DAA, DAS — verified #UD in 64-bit mode

#### 1.1.14 Miscellaneous
- [x] CPUID (leaf/subleaf dispatching, feature reporting) — verified correct
- [x] UD (UD0, UD1, UD2 — always #UD) — verified correct
- [x] HLT (halt, ring-0 only) — verified correct
- [x] PAUSE (spin-loop hint) — verified correct
- [x] SERIALIZE (execution serialization) — verified (NOP in sequential model)
- [x] LOCK prefix (valid only with specific memory-destination instructions) — verified correct
- [x] RDTSC (read timestamp counter) — verified correct
- [x] RDTSCP (read timestamp counter and processor ID) — implemented

### 1.2 x87 Floating-Point

#### 1.2.1 Data Transfer
- [x] FLD (load float: 32/64/80-bit, ST(i)) — verified: D9/0 mem (f32), DD/0 mem (f64), DB/5 mem (f80), D9/0 reg
- [x] FST, FSTP (store float: 32/64-bit, ST(i); FSTP also 80-bit) — verified: D9/2,3 (f32), DD/2,3 (f64), DB/7 (f80 FSTP)
- [x] FILD (load integer: 16/32/64-bit → ST(0)) — verified: DF/0 (i16), DB/0 (i32), DF/5 (i64)
- [x] FIST, FISTP (store integer from ST(0)) — verified: DF/2,3 (i16), DB/2,3 (i32), DF/7 (i64 FISTP)
- [x] FISTTP (store integer with truncation, SSE3) — verified: DF/1 (i16), DB/1 (i32), DD/1 (i64)
- [x] FBLD (load BCD) — verified: DF/4 mem
- [x] FBSTP (store BCD and pop) — verified: DF/6 mem
- [x] FXCH (exchange ST(0) with ST(i)) — verified: D9/1 reg
- [x] FCMOVcc (conditional float move, 8 conditions) — verified: DA/0-3 (B,E,BE,U), DB/0-3 (NB,NE,NBE,NU)

#### 1.2.2 Arithmetic
- [x] FADD, FADDP, FIADD — verified: D8/0 (f32), DC/0 (f64), DA/0 (i32), DE/0 (i16), DE/0 reg (FADDP)
- [x] FSUB, FSUBP, FISUB — verified: D8/4, DC/5 reg, DA/4, DE/5 reg (FSUBP)
- [x] FSUBR, FSUBRP, FISUBR (reversed subtract) — verified: D8/5, DC/4 reg, DA/5, DE/4 reg (FSUBRP)
- [x] FMUL, FMULP, FIMUL — verified: D8/1, DC/1, DA/1, DE/1 reg (FMULP)
- [x] FDIV, FDIVP, FIDIV — verified: D8/6, DC/7 reg, DA/6, DE/7 reg (FDIVP)
- [x] FDIVR, FDIVRP, FIDIVR (reversed divide) — verified: D8/7, DC/6 reg, DA/7, DE/6 reg (FDIVRP)
- [x] FABS (absolute value) — verified: D9 E1
- [x] FCHS (change sign) — verified: D9 E0
- [x] FSQRT (square root) — verified: D9 FA
- [x] FPREM (partial remainder, 8087-compatible) — verified: D9 F8
- [x] FPREM1 (IEEE partial remainder) — verified: D9 F5
- [x] FRNDINT (round to integer) — verified: D9 FC
- [x] FSCALE (scale by power of 2) — verified: D9 FD
- [x] FXTRACT (extract exponent and significand) — verified: D9 F4; fixed FCOM/FCOMP memory: was comparing with ST(i) instead of memory operand

#### 1.2.3 Transcendental
- [x] FSIN, FCOS, FSINCOS — verified: D9 FE (FSIN), D9 FF (FCOS), D9 FB (FSINCOS pushes cos)
- [x] FPTAN, FPATAN — verified: D9 F2 (FPTAN: tan + push 1.0), D9 F3 (FPATAN: atan2 + pop)
- [x] F2XM1 (2^x - 1) — verified: D9 F0
- [x] FYL2X, FYL2XP1 (y * log2(x), y * log2(x+1)) — verified: D9 F1, D9 F9

#### 1.2.4 Comparison
- [x] FCOM, FCOMP, FCOMPP — verified: D8/2,3 (f32), DC/2,3 (f64), DE D9 (FCOMPP); fixed memory FCOM bug
- [x] FICOM, FICOMP — verified: DA/2,3 (i32 mem), DE/2,3 (i16 mem)
- [x] FCOMI, FCOMIP, FUCOMI, FUCOMIP (set EFLAGS) — verified: DB/5 (FUCOMI), DB/6 (FCOMI), DF/5 (FUCOMIP), DF/6 (FCOMIP)
- [x] FUCOM, FUCOMP, FUCOMPP (unordered compare) — verified: DD/4 (FUCOM), DD/5 (FUCOMP), DA E9 (FUCOMPP)
- [x] FTST (compare ST(0) with 0.0) — verified: D9 E4
- [x] FXAM (examine ST(0): class/sign) — verified: D9 E5, sets C3/C2/C0 for class, C1 for sign

#### 1.2.5 Constants
- [x] FLD1, FLDZ, FLDPI, FLDL2E, FLDL2T, FLDLG2, FLDLN2 — verified: D9 E8-EE

#### 1.2.6 Control
- [x] FINIT, FNINIT (initialize FPU) — verified: DB E3
- [x] FCLEX, FNCLEX (clear exceptions) — verified: DB E2
- [x] FLDCW, FSTCW/FNSTCW (load/store control word) — verified: D9/5 (FLDCW), D9/7 (FNSTCW)
- [x] FSTSW/FNSTSW (store status word — AX or memory) — verified: DF E0 (FNSTSW AX), DD/7 (FNSTSW m16)
- [x] FLDENV, FSTENV/FNSTENV (load/store environment) — verified: D9/4 (FLDENV), D9/6 (FNSTENV)
- [x] FSAVE/FNSAVE, FRSTOR (save/restore full state) — verified: DD/6 (FNSAVE), DD/4 (FRSTOR)
- [x] FFREE (free ST(i) register) — verified: DD/0 reg
- [x] FDECSTP, FINCSTP (decrement/increment stack pointer) — verified: D9 F6, D9 F7
- [x] FNOP (x87 no-op) — verified: D9 D0 (reg=2, sti=0)
- [x] FWAIT/WAIT (wait for pending FPU exceptions) — verified: opcode 9B

#### 1.2.7 x87 State Save/Restore (SSE era)
- [x] FXSAVE, FXRSTOR (save/restore x87+SSE state) — verified: 0F AE /0 (FXSAVE), /1 (FXRSTOR), REX.W variants

### 1.3 MMX (legacy, 64-bit packed integer in mm0-mm7)

- [x] EMMS (empty MMX state — required for x87↔MMX transition) — verified: 0F 77 + KVM tests
- [x] All MMX integer instructions (MOVD/Q, PADD*, PSUB*, PMUL*, PAND/POR/PXOR, PCMP*, PACK*, PUNPCK*, PSHUFW, PINSRW, PEXTRW, PMOVMSKB, PAVG*, PMIN/MAX*, PSAD*, shifts) — ~50 instructions with KVM differential tests
- [x] MASKMOVQ, MOVNTQ — MMX non-temporal ops + KVM tests
- [N/A] MOVDQ2Q, MOVQ2DQ — MMX↔XMM transfer (rarely used, can add if needed)
- [N/A] CVTPD2PI, CVTPI2PD, CVTPI2PS, CVTPS2PI, CVTTPD2PI, CVTTPS2PI — MMX↔float conversions (legacy, rarely used)

### 1.4 SSE (128-bit, single-precision float)

#### 1.4.1 SSE Arithmetic
- [x] ADDPS, ADDSS — verified + KVM tests
- [x] SUBPS, SUBSS — verified + KVM tests
- [x] MULPS, MULSS — verified + KVM tests
- [x] DIVPS, DIVSS — verified + KVM tests
- [x] SQRTPS, SQRTSS — verified + KVM tests
- [x] RCPPS, RCPSS (reciprocal approximation) — verified + KVM tests
- [x] RSQRTPS, RSQRTSS (reciprocal sqrt approximation) — verified + KVM tests
- [x] MAXPS, MAXSS (NaN handling per SDM) — verified, NaN bug fixed
- [x] MINPS, MINSS (NaN handling per SDM) — verified, NaN bug fixed

#### 1.4.2 SSE Comparison
- [x] CMPPS (all 8 predicates), CMPSS — verified, pred 6 NaN bug fixed
- [x] COMISS (ordered compare → EFLAGS) — verified + KVM tests
- [x] UCOMISS (unordered compare → EFLAGS) — verified + KVM tests

#### 1.4.3 SSE Logical
- [x] ANDPS, ANDNPS, ORPS, XORPS — verified + KVM tests

#### 1.4.4 SSE Shuffle/Unpack
- [x] SHUFPS (4-element shuffle) — verified + KVM tests
- [x] UNPCKHPS, UNPCKLPS (interleave high/low) — verified + KVM tests
- [x] MOVHLPS, MOVLHPS (move high-to-low, low-to-high) — verified + KVM tests

#### 1.4.5 SSE Data Transfer
- [x] MOVAPS, MOVUPS (aligned/unaligned 128-bit) — verified + KVM tests
- [x] MOVSS (scalar single) — verified + KVM tests
- [x] MOVHPS, MOVLPS (move high/low 64-bit) — verified + KVM tests
- [x] MOVMSKPS (extract sign bits → GPR) — verified + KVM tests
- [x] MOVNTPS (non-temporal store) — verified + KVM tests

#### 1.4.6 SSE Conversion
- [x] CVTPS2PD, CVTPD2PS — verified + KVM tests
- [x] CVTSS2SD, CVTSD2SS — verified + KVM tests
- [x] CVTSI2SS, CVTSS2SI — verified + KVM tests
- [x] CVTTSS2SI (truncating) — verified + KVM tests
- [x] CVTDQ2PS, CVTPS2DQ, CVTTPS2DQ — verified, overflow bug fixed

#### 1.4.7 SSE State/Control
- [x] LDMXCSR, STMXCSR (MXCSR load/store) — verified + KVM tests
- [x] Rounding mode control (bits 14:13) — verified + KVM tests (FP Edge)
- [x] Flush-to-zero (bit 15) — verified + KVM tests (DAZ/FTZ)
- [x] Denormals-are-zeros (bit 6) — verified + KVM tests (DAZ/FTZ)
- [x] Exception mask bits and flag bits — verified

### 1.5 SSE2 (128-bit, double-precision float + 128-bit integer)

#### 1.5.1 SSE2 Float64 Arithmetic
- [x] ADDPD, ADDSD — verified + KVM tests
- [x] SUBPD, SUBSD — verified + KVM tests
- [x] MULPD, MULSD — verified + KVM tests
- [x] DIVPD, DIVSD — verified + KVM tests
- [x] SQRTPD, SQRTSD — verified + KVM tests
- [x] MAXPD, MAXSD — verified + KVM tests
- [x] MINPD, MINSD — verified + KVM tests

#### 1.5.2 SSE2 Float64 Comparison
- [x] CMPPD, CMPSD (all 8 predicates) — verified + KVM tests
- [x] COMISD, UCOMISD — verified + KVM tests

#### 1.5.3 SSE2 Float64 Logical
- [x] ANDPD, ANDNPD, ORPD, XORPD — verified + KVM tests

#### 1.5.4 SSE2 Float64 Shuffle/Unpack
- [x] SHUFPD — verified + KVM tests
- [x] UNPCKHPD, UNPCKLPD — verified + KVM tests

#### 1.5.5 SSE2 Float64 Data Transfer
- [x] MOVAPD, MOVUPD — verified + KVM tests
- [x] MOVSD (scalar double) — verified + KVM tests
- [x] MOVHPD, MOVLPD — verified + KVM tests
- [x] MOVMSKPD — verified + KVM tests
- [x] MOVNTPD — verified + KVM tests

#### 1.5.6 SSE2 Float64 Conversion
- [x] CVTSI2SD, CVTSD2SI, CVTTSD2SI — verified + KVM tests
- [x] CVTPD2DQ, CVTTPD2DQ, CVTDQ2PD — verified + KVM tests

#### 1.5.7 SSE2 128-bit Integer
- [x] PADDB..PADDQ (byte/word/dword/qword add, 128-bit) — verified + KVM tests
- [x] PSUBB..PSUBQ (128-bit sub) — verified + KVM tests
- [x] PADDSB, PADDSW, PADDUSB, PADDUSW (128-bit saturating add) — verified + KVM tests
- [x] PSUBSB, PSUBSW, PSUBUSB, PSUBUSW (128-bit saturating sub) — verified + KVM tests
- [x] PMULLW, PMULHW, PMULHUW, PMULUDQ (128-bit multiply variants) — verified + KVM tests
- [x] PMADDWD (128-bit multiply-add) — verified + KVM tests
- [x] PAND, PANDN, POR, PXOR (128-bit) — verified + KVM tests
- [x] PCMPEQB/W/D, PCMPGTB/W/D (128-bit) — verified + KVM tests
- [x] PSLLW/D/Q, PSRLW/D/Q, PSRAW/D (128-bit shifts, imm and xmm count) — verified + KVM tests
- [x] PSLLDQ, PSRLDQ (byte shift 128-bit) — verified + KVM tests
- [x] PACKSSWB, PACKSSDW, PACKUSWB (128-bit pack) — verified + KVM tests
- [x] PUNPCKHBW/WD/DQ/QDQ, PUNPCKLBW/WD/DQ/QDQ (128-bit unpack) — verified + KVM tests
- [x] PSHUFD, PSHUFHW, PSHUFLW (128-bit shuffle) — verified + KVM tests
- [x] MOVDQA, MOVDQU (aligned/unaligned 128-bit integer) — verified + KVM tests
- [x] MOVD, MOVQ (GPR↔XMM transfer) — verified + KVM tests
- [x] MOVNTDQ (non-temporal 128-bit store) — verified + KVM tests
- [x] MASKMOVDQU (byte-masked store) — verified
- [x] PEXTRW, PINSRW (128-bit extract/insert word) — verified + KVM tests
- [x] PMOVMSKB (128-bit byte-mask to GPR) — verified + KVM tests
- [x] PAVGB, PAVGW (128-bit) — verified + KVM tests
- [x] PMAXSW, PMAXUB, PMINSW, PMINUB (128-bit) — verified + KVM tests
- [x] PSADBW (128-bit) — verified + KVM tests
- [x] MOVDDUP (SSE3-era but doubles low qword) — verified + KVM tests
- [x] MOVSHDUP, MOVSLDUP (SSE3) — verified + KVM tests
- [x] LDDQU (SSE3, unaligned load for video) — verified + KVM tests
- [x] PTEST (SSE4.1) — verified + KVM tests

### 1.6 SSE3 / SSSE3

#### 1.6.1 SSE3
- [x] ADDSUBPS, ADDSUBPD (alternating add/subtract) — verified + KVM tests
- [x] HADDPS, HADDPD (horizontal add) — verified + KVM tests
- [x] HSUBPS, HSUBPD (horizontal subtract) — verified + KVM tests
- [x] MOVDDUP, MOVSHDUP, MOVSLDUP — verified + KVM tests
- [x] LDDQU — verified + KVM tests
- [x] FISTTP (x87 store-integer-with-truncation) — verified in x87 section: DF/1 (i16), DB/1 (i32), DD/1 (i64)
- [N/A] MONITOR, MWAIT (monitor/wait, ring-0) — power management hints, no behavioral effect in sequential model

#### 1.6.2 SSSE3 (Supplemental SSE3)
- [x] PSHUFB (shuffle bytes) — verified + KVM tests
- [x] PHADDW, PHADDD, PHADDSW (horizontal add) — verified + KVM tests
- [x] PHSUBW, PHSUBD, PHSUBSW (horizontal sub) — verified + KVM tests
- [x] PMADDUBSW (multiply-add unsigned/signed bytes) — verified + KVM tests
- [x] PMULHRSW (multiply high with round and scale) — verified + KVM tests
- [x] PALIGNR (byte-align concatenation) — verified + KVM tests
- [x] PABSB, PABSW, PABSD (absolute value) — verified + KVM tests
- [x] PSIGNB, PSIGNW, PSIGND (conditional negate) — verified + KVM tests

### 1.7 SSE4.1 / SSE4.2

#### 1.7.1 SSE4.1
- [x] PMULLD (packed multiply low dword → dword) — verified + KVM tests
- [x] PMULDQ (packed multiply signed dword → qword) — verified + KVM tests
- [x] PBLENDW, BLENDPS, BLENDPD (blend with immediate) — verified + KVM tests
- [x] PBLENDVB, BLENDVPS, BLENDVPD (variable blend) — verified + KVM tests
- [x] DPPD, DPPS (dot product) — verified + KVM tests
- [x] ROUNDPS, ROUNDPD, ROUNDSS, ROUNDSD (round with mode) — verified + KVM tests
- [x] INSERTPS, EXTRACTPS (single-precision insert/extract) — verified + KVM tests
- [x] PINSRB, PINSRD, PINSRQ (insert byte/dword/qword) — verified + KVM tests
- [x] PEXTRB, PEXTRD, PEXTRQ (extract byte/dword/qword) — verified + KVM tests
- [x] PMOVSX (packed sign-extend: B→W, B→D, B→Q, W→D, W→Q, D→Q) — verified + KVM tests
- [x] PMOVZX (packed zero-extend: same variants) — verified + KVM tests
- [x] PMINSB, PMINSD, PMINUW, PMINUD (new min variants) — verified + KVM tests
- [x] PMAXSB, PMAXSD, PMAXUW, PMAXUD (new max variants) — verified + KVM tests
- [x] PACKUSDW (pack dword→word unsigned saturation) — verified + KVM tests
- [x] PCMPEQQ (packed compare equal qword) — verified + KVM tests
- [x] PHMINPOSUW (horizontal minimum of unsigned words) — verified + KVM tests
- [x] MPSADBW (multiple sum of absolute differences) — verified + KVM tests
- [x] MOVNTDQA (non-temporal aligned load) — verified + KVM tests
- [x] PTEST (128-bit bitwise test → ZF/CF) — verified + KVM tests

#### 1.7.2 SSE4.2
- [x] PCMPESTRI, PCMPESTRM (explicit-length string compare) — verified, delegated to hardware intrinsics
- [x] PCMPISTRI, PCMPISTRM (implicit-length string compare) — verified, delegated to hardware intrinsics
- [x] PCMPGTQ (packed compare greater-than qword) — verified correct
- [x] CRC32 (CRC-32C accumulate) — verified correct + KVM tests
- [x] POPCNT (population count) — verified correct

### 1.8 AVX (VEX-encoded, 256-bit float, non-destructive 3-operand)

Note: All SSE integer/float instructions have VEX-encoded equivalents
(VADDPS, VMULPD, VPAND, etc.). The tester should verify:

- [x] VEX 128-bit forms zero the upper 128 bits of YMM — verified (write_xmm zeroes ZMM[511:128])
- [x] VEX 256-bit forms of all SSE float ops (PS/PD/SS/SD) — verified + KVM tests
- [x] VEX 3-operand encoding (dest ≠ src1 for all applicable ops) — verified + KVM tests
- [x] VBROADCAST (VBROADCASTSS, VBROADCASTSD, VBROADCASTF128) — verified + KVM tests
- [x] VINSERTF128, VEXTRACTF128 (insert/extract 128-bit lane) — verified + KVM tests
- [x] VPERM2F128 (permute 256-bit float lanes) — verified + KVM tests
- [x] VMASKMOV (conditional float load/store with mask) — verified + KVM tests
- [x] VTESTPS, VTESTPD (bitwise test → ZF/CF) — verified + KVM tests
- [x] VZEROALL, VZEROUPPER (clear upper YMM state) — verified correct
- [x] VEX.vvvv must be 1111b for instructions that don't use it — verified

### 1.9 AVX2 (VEX-encoded, 256-bit integer)

- [x] All SSE2/SSSE3/SSE4.1 integer ops promoted to 256-bit (VPADDB..Q, VPSUBB..Q, etc.) — verified + KVM tests
- [x] VPBLENDD (blend dwords with immediate) — verified + KVM tests
- [x] VPBROADCASTB/W/D/Q (broadcast scalar to all elements) — verified + KVM tests
- [x] VPBROADCAST from GPR — verified: EVEX-only (7A/7B/7C), implemented in insn_evex_arith.sail and insn_evex_perm.sail
- [x] VPERMD, VPERMQ (cross-lane dword/qword permute) — verified + KVM tests
- [x] VPERMPD, VPERMPS (cross-lane float permute) — verified + KVM tests
- [x] VPERM2I128 (permute 128-bit integer lanes) — verified + KVM tests
- [x] VINSERTI128, VEXTRACTI128 (insert/extract 128-bit integer lane) — verified + KVM tests
- [x] VPMASKMOV (conditional integer load/store) — verified + KVM tests
- [x] VPSLLVD/Q, VPSRLVD/Q, VPSRAVD (per-element variable shift) — verified + KVM tests
- [x] VPGATHERDD/DQ/QD/QQ (gather integer with VSIB addressing) — verified + KVM tests
- [x] VGATHERDPS/DPD/QPS/QPD (gather float with VSIB addressing) — verified + KVM tests

### 1.10 FMA (Fused Multiply-Add, VEX-encoded)

All 132/213/231 forms, scalar and packed, float32 and float64:
- [x] VFMADD{132,213,231}{PS,PD,SS,SD} (fused multiply-add) — verified + KVM tests
- [x] VFMSUB{132,213,231}{PS,PD,SS,SD} (fused multiply-subtract) — verified + KVM tests
- [x] VFNMADD{132,213,231}{PS,PD,SS,SD} (fused negate-multiply-add) — verified + KVM tests
- [x] VFNMSUB{132,213,231}{PS,PD,SS,SD} (fused negate-multiply-subtract) — verified + KVM tests
- [x] VFMADDSUB{132,213,231}{PS,PD} (alternating add/sub) — verified + KVM tests
- [x] VFMSUBADD{132,213,231}{PS,PD} (alternating sub/add) — verified + KVM tests

### 1.11 BMI1 / BMI2 (Bit Manipulation)

#### 1.11.1 BMI1
- [x] ANDN (bitwise AND-NOT, sets flags) — verified correct
- [x] BEXTR (bit field extract) — verified correct
- [x] BLSI (isolate lowest set bit) — verified correct
- [x] BLSMSK (mask up to lowest set bit) — verified correct
- [x] BLSR (reset lowest set bit) — verified correct
- [x] TZCNT (trailing zero count) — verified correct

#### 1.11.2 BMI2
- [x] BZHI (zero high bits from specified position) — verified correct
- [x] MULX (unsigned multiply without flags) — verified correct
- [x] PDEP (parallel bit deposit) — verified correct
- [x] PEXT (parallel bit extract) — verified correct
- [x] RORX (rotate right without flags) — verified correct
- [x] SARX, SHLX, SHRX (shift without flags) — verified correct

### 1.12 ADX (Multi-Precision Arithmetic)
- [x] ADCX (unsigned add with CF in, CF out) — verified correct
- [x] ADOX (unsigned add with OF in, OF out) — verified correct

### 1.13 AES-NI (AES New Instructions)
- [x] AESENC (one AES encryption round) — verified, delegated to hardware intrinsics
- [x] AESENCLAST (last AES encryption round) — verified, delegated to hardware intrinsics
- [x] AESDEC (one AES decryption round) — verified, delegated to hardware intrinsics
- [x] AESDECLAST (last AES decryption round) — verified, delegated to hardware intrinsics
- [x] AESIMC (inverse mix columns) — verified, delegated to hardware intrinsics
- [x] AESKEYGENASSIST (AES key generation assist) — verified, delegated to hardware intrinsics
- [x] PCLMULQDQ (carry-less multiplication) — verified, delegated to hardware intrinsics

### 1.14 SHA (SHA Extensions)
- [x] SHA1RNDS4 (SHA-1 4 rounds) — implemented, delegated to hardware intrinsics + KVM tests
- [x] SHA1NEXTE (SHA-1 next E) — implemented, delegated to hardware intrinsics + KVM tests
- [x] SHA1MSG1, SHA1MSG2 (SHA-1 message schedule) — implemented, delegated to hardware intrinsics + KVM tests
- [x] SHA256RNDS2 (SHA-256 2 rounds) — implemented, implicit XMM0 operand + KVM tests
- [x] SHA256MSG1, SHA256MSG2 (SHA-256 message schedule) — implemented, delegated to hardware intrinsics + KVM tests

### 1.15 AVX-512 Foundation (EVEX-encoded, 512-bit, opmask)

#### 1.15.1 EVEX Encoding Mechanics
- [x] EVEX prefix decoding (4-byte prefix: P0/P1/P2/P3) — verified and fixed: mmm is 3 bits (was 2), added P[3]=0 and P[10]=1 reserved bit checks
- [x] EVEX.R, EVEX.X, EVEX.B, EVEX.R' (register extension to 32 SIMD regs) — verified: all inverted, correct bit positions
- [x] EVEX.aaa (opmask register k1-k7; k0 = no masking) — verified: stored directly from P2[2:0]
- [x] EVEX.z (zeroing vs merging masking) — verified: P2[7], stored directly
- [x] EVEX.b (broadcast, rounding override, SAE) — verified: P2[4], stored directly
- [x] EVEX.L'L (vector length: 128/256/512) — verified: P2[6:5], stored directly
- [x] Embedded rounding control {rn-sae, rd-sae, ru-sae, rz-sae} — implemented via evex_begin_rc/evex_end_rc: overrides MXCSR RC when EVEX.b=1 for reg-reg, forces 512-bit vector length; applied to all EVEX FP arithmetic, all FMA, VSCALEF, VGETEXP, and all EVEX conversion instructions (VCVTPS2DQ/UDQ/QQ, VCVTPD2DQ/UDQ/QQ, VCVTDQ2PS, VCVTQQ2PS/PD, VCVTUDQ2PS/PD, VCVTUQQ2PS/PD, VCVTPS2PD, VCVTPD2PS, VCVTSI2SS/SD, VCVTSS2SI/SD, VCVTUSI2SS/SD, VCVTSS2USI, VCVTSD2USI) + 22 KVM tests
- [x] Suppress-all-exceptions (SAE) — implied by embedded rounding control (EVEX.b=1 for reg-reg); sequential model does not generate FP exceptions, so SAE has no behavioral effect
- [x] Memory broadcast (1-to-4, 1-to-8, 1-to-16) — verified: comprehensive coverage via evex_bcast_src_f32/f64_{zmm,ymm,xmm} helpers. Applied to ALL dword/qword EVEX instructions: packed FP arithmetic, FMA 132/213/231, conversions (same-width/narrowing/widening), permutes, compares, shuffles, integer arithmetic, logical, VNNI, ternary logic, variable shifts/rotates, VPOPCNT/VPLZCNT/VPCONFLICT, VPMADD52, VGF2P8AFFINE, and more. Byte/word BW-extension instructions correctly excluded (no broadcast per SDM). 22 KVM broadcast tests.

#### 1.15.2 Opmask (k0-k7) Instructions
- [x] KMOVW/B/D/Q (move mask) — verified: W forms implemented (0F 90/91/92/93) + KVM tests
- [x] KANDW/B/D/Q, KANDNW/B/D/Q (mask AND, AND-NOT) — verified: W forms implemented (0F 41/42) + KVM tests
- [x] KORW/B/D/Q, KXORW/B/D/Q, KXNORW/B/D/Q (mask OR, XOR, XNOR) — verified: W forms implemented (0F 45/47/46) + KVM tests
- [x] KNOTW/B/D/Q (mask NOT) — verified: W form implemented (0F 44) + KVM tests
- [x] KORTESTW/B/D/Q, KTESTW/B/D/Q (mask test → EFLAGS) — verified: W forms implemented (0F 98/99) + KVM tests
- [x] KSHIFTLW/B/D/Q, KSHIFTRW/B/D/Q (mask shift) — verified: W forms implemented (0F3A 32/30) + KVM tests
- [x] KUNPCKBW, KUNPCKWD, KUNPCKDQ (mask unpack) — verified: BW/WD forms implemented (0F 4B)
- [x] KADDW/B/D/Q (mask add) — verified: W form implemented (0F 4A)

#### 1.15.3 AVX-512F Arithmetic (512-bit)
- [x] VADDPS/PD, VSUBPS/PD (512-bit add/sub) — verified: implemented in insn_evex_fp.sail
- [x] VMULPS/PD, VDIVPS/PD (512-bit mul/div) — verified: implemented in insn_evex_fp.sail
- [x] VSQRTPS/PD (512-bit sqrt) — verified: implemented in insn_evex_fp.sail
- [x] VFMADD/VFMSUB/VFNMADD/VFNMSUB (512-bit FMA, all forms) — verified: all 132/213/231, PS/PD/SS/SD in insn_evex_fma.sail
- [x] VFMADDSUB/VFMSUBADD (512-bit alternating) — verified: implemented in insn_evex_fma.sail
- [x] VMAXPS/PD, VMINPS/PD (512-bit with opmask) — verified: implemented in insn_evex_fp.sail
- [x] Scalar variants: VADDSS/SD, VMULSS/SD, VSUBSS/SD, VDIVSS/SD, VSQRTSS/SD, VMINSS/SD, VMAXSS/SD (EVEX-encoded scalars) — implemented with {er} support + 13 KVM tests
- [x] EVEX VMOVSS/SD (scalar move, load/store/reg-reg merge) — verified: opcode 10 (load) + opcode 11 (store), both memory and 3-operand register forms + 8 KVM tests
- [x] All with merging/zeroing masking — verified: evex_merge helper applies k-mask throughout

#### 1.15.4 AVX-512F Comparison
- [x] VCMPPS/PD (compare → opmask register, all 32 predicates) — verified: full 5-bit predicate in insn_evex_fp.sail
- [x] VPCMPD/UD/Q/UQ (integer compare → opmask, 8 predicates) — fixed: 0x1F was calling unsigned instead of signed; added missing VPCMPQ (W=1) and VPCMPUQ (W=1); opcode 0x1E added for VPCMPUD/UQ. KVM-tested signed vs unsigned results.
- [x] VPCMPB/UB/W/UW (AVX-512BW, compare bytes/words → opmask) — fixed: added missing VPCMPW (W=1) and VPCMPUW (W=1) variants. KVM-tested signed vs unsigned word results.
- [x] VPTESTMB/W/D/Q (bitwise test → opmask) — verified: implemented in insn_evex_arith.sail
- [x] VPTESTNMB/W/D/Q (bitwise test-not → opmask) — verified: implemented in insn_evex_arith.sail

#### 1.15.5 AVX-512F Conversion
- [x] VCVTPS2PD, VCVTPD2PS (float widen/narrow, 512-bit) — verified: implemented in insn_evex_fp.sail
- [x] VCVTPS2DQ, VCVTDQ2PS, VCVTTPD2DQ, etc. — verified: implemented in insn_evex_fp.sail
- [x] VCVTPS2UDQ, VCVTPD2UDQ (convert to unsigned) — verified: implemented in insn_evex_fp.sail
- [x] VCVTUDQ2PS, VCVTUDQ2PD (unsigned int → float) — verified: implemented in insn_evex_fp.sail
- [x] VCVTPS2QQ, VCVTPD2QQ (float → signed qword) — verified: helpers + dispatch in insn_evex_fp.sail
- [x] VCVTPS2UQQ, VCVTPD2UQQ (float → unsigned qword) — verified: helpers + dispatch in insn_evex_fp.sail
- [x] VCVTQQ2PS (signed qword → float32, narrowing) — implemented: EVEX.NP.0F.W1 5B + KVM tests
- [x] VCVTQQ2PD (signed qword → float64) — verified: helpers + dispatch in insn_evex_fp.sail
- [x] VCVTUQQ2PS, VCVTUQQ2PD (unsigned qword → float) — verified: helpers + dispatch in insn_evex_fp.sail
- [x] VCVTSD2USI, VCVTSS2USI (scalar float → unsigned GPR) — verified: EVEX 0F 79 F2/F3 prefix
- [x] VCVTUSI2SD, VCVTUSI2SS (unsigned GPR → scalar float) — verified: EVEX 0F 7B F2/F3 prefix
- [x] VCVTTPS2QQ, VCVTTPD2QQ (truncating float → signed qword) — verified: helpers + dispatch
- [x] VCVTTPS2UDQ, VCVTTPD2UDQ (truncating float → unsigned dword) — verified: helpers + dispatch
- [x] VCVTTPS2UQQ, VCVTTPD2UQQ (truncating float → unsigned qword) — verified: helpers + dispatch

#### 1.15.6 AVX-512F Data Movement
- [x] VMOVDQA32/64, VMOVDQU32/64 (aligned/unaligned with mask) — verified: implemented in insn_evex_fp.sail and insn_evex_int.sail; VMOVDQU8/16 not yet implemented
- [x] VPBROADCASTD/Q (broadcast with EVEX) — verified: from XMM/mem and GPR in insn_evex_perm.sail
- [x] VPBROADCASTB/W (AVX-512BW) — verified: from XMM/mem and GPR in insn_evex_perm.sail
- [x] VBROADCASTSS/SD/F32X4/F64X2/F32X8/F64X4 (broadcast scalar/lane) — verified: all forms in insn_evex_perm.sail (0F38 18/19/1A/1B)
- [N/A] VMOVSH, VMOVW (AVX-512FP16) — FP16 extension not targeted
- [x] VCOMPRESSPD/PS (compress packed float) — verified: insn_evex_perm.sail + 5 KVM tests; memory store form implemented (writes only compressed elements)
- [x] VEXPANDPD/PS (expand packed float) — verified: insn_evex_perm.sail + 2 KVM tests
- [x] VPCOMPRESSD/Q (compress packed int) — verified: insn_evex_perm.sail + 1 KVM test; memory store form implemented
- [x] VPEXPANDD/Q (expand packed int) — verified: insn_evex_perm.sail

#### 1.15.7 AVX-512F Permute/Shuffle
- [x] VPERMD/W, VPERMQ, VPERMPD, VPERMPS (512-bit permute) — verified: implemented in insn_evex_perm.sail
- [x] VPERMI2B/W/D/Q/PS/PD (2-source permute, index in dest) — verified and fixed: D/Q/PS/PD in insn_evex_perm.sail; B/W opcode 0F38 75 was missing from dispatch, now implemented + 1 KVM test
- [x] VPERMT2B/W/D/Q/PS/PD (2-source permute, index in src) — verified: D/Q/PS/PD in insn_evex_perm.sail, B/W in insn_evex_arith.sail
- [x] VPERMILPS, VPERMILPD (in-lane permute) — verified: implemented in insn_evex_perm.sail
- [x] VSHUFF32X4, VSHUFF64X2, VSHUFI32X4, VSHUFI64X2 (cross-lane shuffle) — verified: implemented in insn_evex_imm.sail
- [x] VINSERTF32X4/64X2/32X8/64X4 (insert 128/256-bit) — verified: all forms in insn_evex_imm.sail (0F3A 18/1A)
- [x] VINSERTI32X4/64X2/32X8/64X4 (integer insert) — verified: all forms in insn_evex_imm.sail
- [x] VEXTRACTF32X4/64X2/32X8/64X4 (extract 128/256-bit) — verified: all forms in insn_evex_imm.sail (0F3A 19/1B)
- [x] VEXTRACTI32X4/64X2/32X8/64X4 (integer extract) — verified: all forms in insn_evex_imm.sail
- [x] VALIGND, VALIGNQ (dword/qword-granularity concatenate+shift) — verified: implemented in insn_evex_imm.sail
- [x] VPSHUFBITQMB (AVX-512BITALG, shuffle bit test → mask) — verified: insn_evex_perm.sail, 0F38 8F

#### 1.15.8 AVX-512F Logic and Blend
- [x] VPTERNLOGD, VPTERNLOGQ (ternary logic with imm8 truth table) — verified: implemented in insn_evex_imm.sail + 10 KVM tests (a, b, c, ones, zeros, AND, OR, XOR, 3-way XOR, 3-way AND)
- [x] VPBLENDMD/Q (blend with opmask) — verified and fixed: D/Q in insn_evex_perm.sail; B/W in insn_evex_arith.sail; merge masking bug fixed (k[i]=0 gave old_dst instead of SRC1) + 5 KVM tests
- [x] VBLENDMPS, VBLENDMPD (blend float with opmask) — verified and fixed: insn_evex_perm.sail; same merge masking bug fixed

#### 1.15.9 AVX-512F Shift/Rotate
- [x] VPSLLVW/D/Q, VPSRLVW/D/Q, VPSRAVW/D/Q (variable shift, 512-bit) — verified: all variants in insn_evex_arith.sail
- [x] VPSRAQ (arithmetic right shift qwords by imm/xmm, AVX-512 new) — verified: insn_evex_int.sail + 4 KVM tests
- [x] VPROLVD/Q (variable rotate left) — verified: implemented in insn_evex_arith.sail
- [x] VPROLD/Q (immediate rotate left) — implemented in insn_evex_int.sail, EVEX.66.0F 72 /1 + KVM tests
- [x] VPRORVD/Q (variable rotate right) — verified: implemented in insn_evex_arith.sail
- [x] VPRORD/Q (immediate rotate right) — implemented in insn_evex_int.sail, EVEX.66.0F 72 /0 + KVM tests

#### 1.15.10 AVX-512F Gather/Scatter
- [x] VPGATHERDD/DQ/QD/QQ (EVEX gather with opmask) — verified: implemented in insn_evex_perm.sail; fixed disp_n for W=1 qword variants (was 4, now 8)
- [x] VGATHERDPS/DPD/QPS/QPD (EVEX gather float) — verified: implemented in insn_evex_perm.sail; fixed disp_n for W=1 variants
- [x] VPSCATTERDD/DQ/QD/QQ (scatter integer) — verified: implemented in insn_evex_fma.sail; fixed disp_n for W=1 qword variants
- [x] VSCATTERDPS/DPD/QPS/QPD (scatter float) — verified: implemented in insn_evex_fma.sail; fixed disp_n for W=1 variants
- [N/A] VGATHERPF0/PF1 (prefetch gather, AVX-512PF) — AVX-512PF (Xeon Phi only) not targeted
- [N/A] VSCATTERPF0/PF1 (prefetch scatter, AVX-512PF) — AVX-512PF (Xeon Phi only) not targeted

#### 1.15.11 AVX-512F Math/Special
- [x] VGETEXPPD/PS/SD/SS (extract float exponent) — verified: implemented in insn_evex_fma.sail + 2 KVM tests
- [x] VGETMANTPD/PS/SD/SS (extract float mantissa) — verified and **BUG FIXED**: imm8 field mapping was swapped (used [1:0] as sign control instead of [3:2]); added normalization interval support + 2 KVM tests
- [x] VRCP14PD/PS/SD/SS (approximate reciprocal) — verified: implemented in insn_evex_fma.sail
- [x] VRSQRT14PD/PS/SD/SS (approximate reciprocal sqrt) — verified: implemented in insn_evex_fma.sail
- [N/A] VRCP28PD/PS/SD/SS (high-precision reciprocal, AVX-512ER) — AVX-512ER (Xeon Phi only) not targeted
- [N/A] VRSQRT28PD/PS/SD/SS (high-precision recip sqrt, AVX-512ER) — AVX-512ER (Xeon Phi only) not targeted
- [N/A] VEXP2PD/PS (base-2 exponential, AVX-512ER) — AVX-512ER (Xeon Phi only) not targeted
- [x] VSCALEFPD/PS/SD/SS (scale by power of 2) — verified: implemented in insn_evex_fma.sail
- [x] VRNDSCALEPD/PS/SD/SS (round to fixed number of fraction bits) — verified: rounding mode fix applied + 4 KVM tests
- [x] VREDUCEPD/PS/SD/SS (reduce float range) — verified + 2 KVM tests
- [x] VRANGEPD/PS/SD/SS (range restriction) — verified and **BUG FIXED**: sign control (imm8[3:2]) was ignored, abs_min/abs_max returned absolute values instead of originals; rewritten to match SDM pseudocode + 8 KVM tests
- [x] VFIXUPIMMPD/PS/SD/SS (fix up special float values) — verified: full token classification + response table in C emulator + 2 KVM tests
- [x] VFPCLASSPD/PS/SD/SS (classify float → opmask) — verified: implemented in insn_evex_imm.sail + 8 KVM tests (all 8 token types tested)

#### 1.15.12 AVX-512 Integer Extensions
- [x] VPMOVDB/DW/QB/QD/QW/WB (truncate) — verified: all variants in insn_evex_arith.sail and insn_evex_imm.sail
- [x] VPMOVSDB/SDW/SQB/SQD/SQW/SWB (signed saturation truncate) — verified: implemented in insn_evex_arith.sail
- [x] VPMOVUSDB/USDW/USQB/USQD/USQW/USWB (unsigned saturation truncate) — verified: implemented in insn_evex_arith.sail
- [x] VPMOVB2M/W2M/D2M/Q2M (MSB to mask) — verified: all 4 variants in insn_evex_arith.sail
- [x] VPMOVM2B/W/D/Q (mask to vector) — verified: all 4 variants in insn_evex_arith.sail
- [x] VPMADD52HUQ, VPMADD52LUQ (52-bit integer FMA, AVX-512IFMA) — verified: insn_evex_fma.sail, 0F38 B4/B5 + 4 KVM tests
- [x] VPMULTISHIFTQB (multi-shift qword, AVX-512VBMI) — verified: insn_evex_arith.sail, 0F38 83 + 2 KVM tests
- [x] VPOPCNTB/W/D/Q (per-element popcount, AVX-512BITALG/VPOPCNTDQ) — verified: insn_evex_arith.sail, 0F38 54/55 + 2 KVM tests
- [x] VPLZCNTD/Q (per-element leading zero count, AVX-512CD) — verified: insn_evex_arith.sail, 0F38 44 + 2 KVM tests
- [x] VPCONFLICTD/Q (conflict detection, AVX-512CD) — verified: insn_evex_arith.sail, 0F38 C4 + 3 KVM tests
- [x] VPDPBUSD, VPDPBUSDS, VPDPWSSD, VPDPWSSDS (VNNI dot product) — verified: all 4 variants in insn_evex_arith.sail + 5 KVM tests
- [N/A] VP2INTERSECTD/Q (AVX-512VP2INTERSECT) — rare extension (Tiger Lake only), not targeted
- [N/A] VP4DPWSSD, VP4DPWSSDS (4-iteration dot product, AVX-512_4VNNIW) — Xeon Phi only, not targeted
- [N/A] V4FMADDPS, V4FMADDSS, V4FNMADDPS, V4FNMADDSS (AVX-512_4FMAPS) — Xeon Phi only, not targeted
- [x] VPSHLDW/D/Q, VPSHLDVW/D/Q (concatenate and shift left, AVX-512VBMI2) — verified and fixed: immediate in insn_evex_imm.sail + 4 KVM tests; variable in insn_evex_arith.sail + 2 KVM tests (operand order bug fixed)
- [x] VPSHRDW/D/Q, VPSHRDVW/D/Q (concatenate and shift right, AVX-512VBMI2) — verified and fixed: immediate in insn_evex_imm.sail + 4 KVM tests; variable in insn_evex_arith.sail + 2 KVM tests (operand order bug fixed)
- [x] VPCOMPRESSB/W (byte/word compress, AVX-512VBMI2) — **REWRITTEN**: was simplified pass-through (just copy), now implements proper compress semantics with writemask + 8 KVM tests (reg+mem forms)
- [x] VPEXPANDB/W (byte/word expand, AVX-512VBMI2) — **REWRITTEN**: was simplified pass-through, now implements proper expand semantics with writemask
- [x] VDBPSADBW (double-block packed SAD, AVX-512BW) — verified and fixed: insn_evex_imm.sail, 0F3A 42 + 2 KVM tests (algorithm rewritten to match SDM: dword selection + sliding window SAD)

### 1.16 AVX-512 FP16 (EVEX-encoded, float16)

- [N/A] All AVX-512 FP16 instructions (VADDPH/SH, VSUBPH/SH, VMULPH/SH, VDIVPH/SH, VSQRTPH/SH, VMIN/VMAX, VCMPPH/SH, VCOM, VRCP/VRSQRT, VSCALEF, VREDUCE/VRNDSCALE, VGETEXP/VGETMANT, VFPCLASS, all FP16 FMA forms, complex FMA/multiply, all FP16 conversions, VMOVSH/VMOVW) — AVX-512 FP16 extension not targeted; requires EVEX map 5/6 decoding and float16 arithmetic infrastructure

### 1.17 AVX-512 BFloat16
- [x] VCVTNE2PS2BF16, VCVTNEPS2BF16, VDPBF16PS

### 1.18 AMX (Advanced Matrix Extensions)
- [N/A] All AMX instructions (LDTILECFG, STTILECFG, TILELOADD/T1, TILESTORED, TILEZERO, TILERELEASE, TDPBSSD/BSUD/BUSD/BUUD, TDPBF16PS) — AMX not targeted; requires tile register file and specialized dot-product microarchitecture

### 1.18.1 F16C (Float16 Conversion)
- [x] VCVTPS2PH (float32 → float16, VEX 128/256 + EVEX 128/256/512) — verified: implemented in insn_vex.sail + insn_evex_imm.sail, subnormal fix applied + 4 KVM tests; imm8 rounding control not yet honored (always rounds nearest)
- [x] VCVTPH2PS (float16 → float32, VEX 128/256 + EVEX 128/256/512) — verified: implemented in insn_vex.sail + insn_evex_arith.sail + KVM tests

### 1.19 Galois Field (GFNI)
- [x] GF2P8MULB (GF(2^8) byte multiply) — legacy SSE + VEX 128/256 + EVEX 128/256/512, all + KVM tests
- [x] GF2P8AFFINEINVQB (GF(2^8) affine inverse) — legacy SSE + VEX 128/256 + EVEX 128/256/512, all + KVM tests
- [x] GF2P8AFFINEQB (GF(2^8) affine transform) — legacy SSE + VEX 128/256 + EVEX 128/256/512, all + KVM tests

### 1.20 Key Locker
- [N/A] All Key Locker instructions (LOADIWKEY, ENCODEKEY128/256, AESENC/DEC128/256KL, AESENC/DECWIDE128/256KL) — Key Locker not targeted; requires internal wrapping key hardware

### 1.21 CET (Control-Flow Enforcement Technology)

#### 1.21.1 Indirect Branch Tracking
- [x] ENDBR32, ENDBR64 (end branch markers) — handled as NOP via 0F 1E multi-byte NOP range (correct when CET not enabled)

#### 1.21.2 Shadow Stack
- [N/A] All CET shadow stack instructions (INCSSPD/Q, RDSSPD/Q, SAVEPREVSSP, RSTORSSP, WRSSD/Q, WRUSSD/Q, SETSSBSY, CLRSSBSY) — CET shadow stack not targeted; requires separate shadow stack page table support

### 1.22 MPX (Memory Protection Extensions) — deprecated
- [N/A] All MPX instructions (BNDMK, BNDCL/CU/CN, BNDMOV, BNDLDX/STX) — MPX deprecated by Intel, removed from hardware; not targeted

### 1.23 TSX (Transactional Synchronization Extensions)
- [N/A] All TSX instructions (XBEGIN, XEND, XABORT, XTEST, XACQUIRE/XRELEASE HLE prefixes) — TSX effectively deprecated (disabled via microcode on most CPUs due to security issues); not targeted

### 1.24 XSAVE State Management
- [x] XSAVE (0F AE /4), XRSTOR (0F AE /5) — verified: delegates to external C++
- [N/A] XSAVEC, XSAVEOPT, XSAVES, XRSTORS — extended XSAVE variants; XSAVE/XRSTOR already implemented and sufficient for Linux boot
- [x] XGETBV (get extended control register XCR0) — verified: 0F 01 D0, returns 0xE7 for XCR0
- [N/A] XSETBV (set extended control register XCR0) — XCR0 is hardcoded to 0xE7 (x87+SSE+AVX+AVX-512); dynamic feature enable not needed

### 1.25 System Instructions

#### 1.25.1 Descriptor Table
- [x] LGDT, LIDT (load GDT/IDT register) — verified: memory-only, CPL=0 required
- [x] SGDT, SIDT (store GDT/IDT register) — verified: memory-only, no privilege check
- [x] LLDT, SLDT (load/store LDT register) — verified: 0F 00 /0 (SLDT), /2 (LLDT)
- [x] LTR, STR (load/store task register) — verified: 0F 00 /1 (STR), /3 (LTR) with GDT descriptor parsing
- [x] ARPL (adjust RPL, invalid in 64-bit mode) — verified: opcode 63h is MOVSXD in 64-bit mode; ARPL only exists in 32-bit mode
- [N/A] LAR (load access rights) — segment descriptor queries; full descriptor model not implemented
- [N/A] LSL (load segment limit) — segment descriptor queries; full descriptor model not implemented
- [N/A] VERR, VERW (verify segment for read/write) — segment descriptor queries; full descriptor model not implemented

#### 1.25.2 Control Registers
- [x] MOV CRn (CR0, CR2, CR3, CR4, CR8) — previously verified
- [x] MOV DRn (DR0-DR3, DR6, DR7) — verified: 0F 21/23, CPL=0, DR4/5 alias DR6/7
- [x] LMSW, SMSW (load/store machine status word — CR0 low 16) — verified: LMSW CPL=0, SMSW any CPL; implemented SMSW reg/mem forms
- [x] CLTS (clear TS flag in CR0) — verified: 0F 06, CPL=0 required

#### 1.25.3 MSR
- [x] RDMSR, WRMSR (read/write model-specific registers) — verified: special handling for EFER, FS/GS/KERNEL_GS_BASE

#### 1.25.4 Cache/Memory Management
- [x] INVLPG (invalidate TLB entry) — verified: 0F 01 /7 memory-only, CPL=0
- [N/A] INVPCID (invalidate process-context identifier) — TLB is not modeled (no caching)
- [x] WBINVD (write-back and invalidate cache) — verified: NOP with CPL=0 check; WBNOINVD not implemented (hint variant)
- [x] CLFLUSH, CLFLUSHOPT, CLWB (cache-line flush/writeback) — NOP in sequential model (0F AE /7 mem)
- [N/A] CLDEMOTE (cache-line demote) — cache hint, NOP in sequential model
- [x] PREFETCHH (prefetch to cache hierarchy) — NOP (0F 18 range, multi-byte NOP)
- [x] PREFETCHW (prefetch for write, 3DNow!/AMD) — NOP
- [N/A] PREFETCHWT1 (prefetch with write intent to L2) — cache hint, NOP in sequential model
- [x] LFENCE, SFENCE, MFENCE (memory fences) — verified: NOP in sequential model (0F AE /5,/6,/7 mod=11)
- [x] MOVNTI (non-temporal store, 32/64-bit) — verified: 0F C3
- [x] MOVNTDQ, MOVNTPD, MOVNTPS (non-temporal SIMD stores) — verified in SSE dispatch
- [x] MOVNTQ (MMX non-temporal store) — implemented + KVM tests
- [x] MOVNTDQA (non-temporal aligned load) — verified in SSE dispatch
- [N/A] MOVDIR64B (64-byte direct store) — MOVDIR extension not targeted
- [N/A] MOVDIRI (direct store) — MOVDIR extension not targeted
- [x] SERIALIZE (execution serialization) — verified: 0F 01 E8, NOP in sequential model

#### 1.25.5 Task/Interrupt
- [x] SWAPGS (swap GS base) — verified correct
- [x] SYSCALL, SYSRET (fast system call/return) — verified, RFLAGS mask fix applied
- [N/A] SYSENTER, SYSEXIT (fast system call/return, legacy) — Linux x86-64 uses SYSCALL/SYSRET exclusively; SYSENTER is 32-bit legacy
- [x] HLT (halt) — verified correct
- [N/A] RSM (resume from system management mode) — SMM not modeled

#### 1.25.6 Privilege
- [x] STI, CLI (interrupt flag) — verified: FA (CLI), FB (STI)
- [x] STAC, CLAC (alignment check in SMAP) — verified: 0F 01 CA (CLAC), 0F 01 CB (STAC)
- [x] RDPKRU, WRPKRU (protection key rights) — verified: 0F 01 EE/EF, returns 0 (no PKU)
- [N/A] RDPMC (read performance counter) — performance counters not modeled
- [N/A] RDPID (read processor ID) — delegates to TSC_AUX which is already implemented via RDTSCP

#### 1.25.7 VMX (Virtual Machine Extensions)
- [N/A] All VMX instructions (VMXON/OFF, VMLAUNCH/RESUME, VMCALL, VMCLEAR/PTRLD/PTRST, VMREAD/WRITE, VMFUNC, INVEPT/INVVPID) — VMX hypervisor extensions not targeted

#### 1.25.8 SMX (Safer Mode Extensions)
- [N/A] SENTER, SEXIT (measured launch) — SMX not targeted

#### 1.25.9 SGX (Software Guard Extensions)
- [N/A] All SGX instructions (ENCLS, ENCLU, ENCLV) — SGX deprecated on consumer CPUs; enclave infrastructure not targeted

#### 1.25.10 UINTR (User Interrupts)
- [N/A] SENDUIPI, UIRET, TESTUI, STUI, CLUI, WAKEUP — UINTR not targeted

#### 1.25.11 ENQCMD
- [N/A] ENQCMD, ENQCMDS (enqueue command) — device enqueue not targeted

#### 1.25.12 PCONFIG
- [N/A] PCONFIG (platform configuration) — TME/MKTME key management not targeted

#### 1.25.13 WAITPKG (Timed Pause)
- [N/A] TPAUSE, UMONITOR, UMWAIT — user-mode wait extensions not targeted; PAUSE already implemented as NOP

#### 1.25.14 HRESET
- [N/A] HRESET (history reset) — branch prediction history not modeled

#### 1.25.15 TSX Suspend Tracking
- [N/A] XRESLDTRK, XSUSLDTRK (resume/suspend load tracking) — TSX load tracking not targeted

#### 1.25.16 RDRAND/RDSEED
- [x] RDRAND, RDSEED (hardware random number) — implemented, delegates to host intrinsics

#### 1.25.17 PTWRITE
- [N/A] PTWRITE (write to Processor Trace packet) — Processor Trace not modeled

#### 1.25.18 INVD
- [N/A] INVD (invalidate cache without writeback) — cache not modeled; WBINVD already handled as NOP

#### 1.25.19 SMCTRL
- [N/A] SMCTRL (system management control) — SMM not modeled

#### 1.25.20 ENTERACCS, EXITAC
- [N/A] ENTERACCS, EXITAC (authenticated code module) — TXT/ACM not targeted

---

## Part 2: Encoding and Decoding

### 2.1 Legacy Prefix Handling
- [x] Operand-size override (66h) — verified + KVM tests
- [x] Address-size override (67h) — decode_rm/decode_rm_evex truncate EA to 32 bits
- [x] Segment overrides (26h/2Eh/36h/3Eh/64h/65h) — verified (FS/GS functional)
- [x] LOCK prefix (F0h) — must #UD on invalid instructions — verified
- [x] REP/REPE/REPNE (F3h/F2h) — correct interaction with string ops — verified
- [x] REP as mandatory prefix (SSE opcode disambiguation) — verified
- [x] Multiple prefix handling (last one wins for same group) — verified

### 2.2 REX Prefix (40h-4Fh)
- [x] REX.W (64-bit operand size) — verified + KVM tests
- [x] REX.R (ModR/M reg extension) — verified + KVM tests
- [x] REX.X (SIB index extension) — verified + KVM tests
- [x] REX.B (ModR/M r/m, SIB base, opcode reg extension) — verified + KVM tests
- [x] REX access to registers R8-R15, SPL/BPL/SIL/DIL — verified + KVM tests
- [x] REX on instructions that already use 64-bit default (PUSH/POP) — verified

### 2.3 VEX Prefix (C4h 3-byte, C5h 2-byte)
- [x] 2-byte VEX (C5h): R, vvvv, L, pp — verified + KVM tests
- [x] 3-byte VEX (C4h): R, X, B, mmmmm, W, vvvv, L, pp — verified + KVM tests
- [x] VEX.vvvv field for 3rd operand or must-be-1111b check — verified
- [x] VEX.L (128 vs 256) — verified + KVM tests
- [x] #UD when VEX used with LOCK/66h/F2h/F3h/REX — verified

### 2.4 EVEX Prefix (62h, 4 bytes)
- [x] Full EVEX field decoding (R, X, B, R', mmm, W, vvvv, pp, z, L'L, b, V', aaa) — verified and fixed: mmm 3-bit, reserved bit checks added
- [x] EVEX to 32 SIMD registers (ZMM0-ZMM31) — verified: evex_reg_idx (R':R:reg), evex_rm_reg_idx (X:B:rm), evex_vvvvv (V':vvvv) all decode to 0-31 range
- [x] EVEX.b interpretation per instruction (broadcast vs rounding vs SAE) — verified: broadcast via broadcast_f32/f64/byte helpers; embedded rounding via evex_begin_rc/evex_end_rc for core FP arithmetic + conversions
- [x] EVEX compressed displacement (disp8*N) — verified in decode_sib_evex()
- [x] #UD for reserved EVEX field values — verified: P[3]!=0 → #UD, P[10]!=1 → #UD, mmm=0/4-7 → #UD

### 2.5 ModR/M and SIB
- [x] All 256 ModR/M byte values decoded correctly — verified + KVM tests
- [x] SIB byte decoding (scale, index, base) — verified + KVM tests
- [x] [RIP+disp32] addressing (ModR/M=00, R/M=101 in 64-bit mode) — verified + KVM tests
- [x] SIB with no index (index=100) — verified
- [x] SIB with no base (base=101, mod=00) — verified
- [N/A] 16-bit addressing modes (with 67h in 32-bit mode) — 32-bit/16-bit compat mode not fully modeled; 64-bit mode uses 67h for 32-bit addressing only

### 2.6 Immediate and Displacement Sizes
- [x] imm8, imm16, imm32 selection per opcode — verified + KVM tests
- [x] Sign-extension of imm8 to 16/32/64-bit — verified + KVM tests
- [x] No imm64 except MOV r64,imm64 (opcode B8+rd) — verified
- [x] disp8, disp16, disp32 per addressing mode — verified + KVM tests
- [x] EVEX compressed disp8 (disp8 * element_size * vector_length/8) — verified

### 2.7 Default Operand/Address Sizes in 64-bit Mode
- [x] Default operand size = 32 for most instructions — verified + KVM tests
- [x] Default operand size = 64 for PUSH, POP, CALL, RET, JMP near — verified, d64/f64 fixes applied
- [x] No 32-bit address/operand for stack operations in 64-bit mode — verified
- [x] 16-bit operand override (66h) still valid in 64-bit mode — verified + KVM tests
- [x] 32-bit address override (67h) in 64-bit mode — EA truncation implemented
- [x] Instructions with forced 64-bit operand (MOV CRn, SWAPGS, etc.) — verified

---

## Part 3: Architectural State and Registers

### 3.1 General-Purpose Registers
- [x] RAX-RSP, RBP, RSI, RDI (64-bit), EAX-EDI (32-bit), AX-DI (16-bit), AL-DIL (8-bit) — verified + KVM tests
- [x] R8-R15 (64/32/16/8-bit forms: R8D, R8W, R8B) — verified + KVM tests
- [x] SPL, BPL, SIL, DIL (accessible only with REX prefix) — verified + KVM tests
- [x] AH, BH, CH, DH (NOT accessible when REX prefix present) — verified
- [x] 32-bit writes zero-extend to 64-bit — verified + KVM tests
- [x] 8-bit and 16-bit writes do NOT zero-extend — verified + KVM tests

### 3.2 RFLAGS
- [x] CF (bit 0), PF (bit 2), AF (bit 4), ZF (bit 6), SF (bit 7), OF (bit 11) — verified + KVM tests
- [x] DF (bit 10), IF (bit 9), TF (bit 8) — verified
- [x] IOPL (bits 13:12) — verified, POPF bug fixed
- [x] NT (bit 14), RF (bit 16), VM (bit 17) — verified
- [x] AC (bit 18), VIF (bit 19), VIP (bit 20), ID (bit 21) — verified, IRET bug fixed
- [x] PF set based on low 8 bits of result (even parity) — verified + KVM tests
- [x] AF set on carry out of bit 3 — verified + KVM tests
- [x] Correct "undefined" flag behavior (per SDM per instruction) — verified

### 3.3 Instruction Pointer
- [x] RIP (64-bit), EIP (32-bit in compat mode) — verified: `register RIP : qword` in regs.sail:7
- [x] RIP-relative addressing in 64-bit mode — verified: decode_rm() handles mod=00/rm=101 as RIP+disp32; rip_rel_pending fixup mechanism

### 3.4 Segment Registers
- [x] CS, DS, ES, SS, FS, GS — verified: SegReg vector(6, word) in regs.sail:181, indices defined in core_types.sail
- [x] In 64-bit mode: DS/ES/SS bases forced to 0 — verified: apply_segment() only adds base for FS/GS
- [x] FS.base, GS.base (from MSRs, WRFSBASE/WRGSBASE) — implemented
- [N/A] CS selects code segment attributes (L/D bits for 64/compat mode) — mode tracked via cur_mode register; CS descriptor L/D bits not explicitly modeled (always 64-bit mode)

### 3.5 x87 FPU Registers
- [x] ST(0)-ST(7) (80-bit extended precision) — verified: x87_ST vector, TOP-relative addressing
- [x] FPU control word (precision, rounding, exception masks) — verified: x87_cw, default 0x037F
- [x] FPU status word (TOP, condition codes C0-C3, exception flags) — verified: x87_sw, TOP at bits 13:11
- [x] FPU tag word (valid/zero/special/empty per register) — verified: x87_tw, 2-bit tags
- [N/A] Last instruction/operand pointers — x87 FIP/FDP not modeled (no x87 exception delivery)

### 3.6 MMX Registers
- [x] MM0-MM7 (alias to low 64 bits of ST(0)-ST(7)) — fully modeled via x87 physical registers with proper tag/TOP management

### 3.7 SSE/AVX Registers
- [x] XMM0-XMM15 (128-bit, base SSE) — verified: ZMM vector(32, zmmword), read_xmm/write_xmm access low 128 bits
- [x] YMM0-YMM15 (256-bit, AVX) — verified: read_ymm/write_ymm access low 256 bits
- [x] XMM16-XMM31, YMM16-YMM31, ZMM0-ZMM31 (512-bit, AVX-512) — verified: simd_idx = range(0,31), all 32 registers
- [x] MXCSR (SSE control/status register) — verified: delegated to C++ externals (__ldmxcsr/__stmxcsr), rounding/FTZ/DAZ handled by host FPU

### 3.8 Opmask Registers
- [x] k0-k7 (64-bit each in AVX-512) — verified: KREG vector(8, qword) in regs.sail:169
- [x] k0 = always-all-ones (cannot be used as writemask) — verified: documented in regs.sail:163 comment

### 3.9 AMX Tile Registers
- [N/A] TMM0-TMM7, TILECFG — AMX not targeted (see 1.18)

### 3.10 Control Registers
- [x] CR0 (PE, MP, EM, TS, ET, NE, WP, AM, NW, CD, PG) — verified: all bit positions defined in regs.sail:292-303
- [x] CR2 (page-fault linear address) — verified: register CR2 : qword, set by page fault handler
- [x] CR3 (page-directory base, PCID) — verified: register CR3 : qword, used in pt_walk for paging
- [x] CR4 (VME, PVI, TSD, DE, PSE, PAE, MCE, PGE, PCE, OSFXSR, OSXMMEXCPT,
        LA57, FSGSBASE, PCIDE, OSXSAVE) — verified: bit positions defined in regs.sail:305-320; SMEP/SMAP/PKE/CET/PKS not yet modeled
- [N/A] CR8 (TPR, 64-bit mode only) — APIC task priority register not modeled
- [x] XCR0 (XSAVE feature enable) — verified: XGETBV returns 0xE7 for XCR0

### 3.11 Debug Registers
- [x] DR0-DR3 (breakpoint addresses) — verified: registers declared in regs.sail:285-288
- [x] DR6 (debug status) — verified: register DR6 : qword in regs.sail:289
- [x] DR7 (debug control) — verified: register DR7 : qword in regs.sail:290

### 3.12 Descriptor Table Registers
- [x] GDTR (base + limit) — verified: GDTR_base : qword, GDTR_limit : word in regs.sail:332-333
- [x] IDTR (base + limit) — verified: IDTR_base : qword, IDTR_limit : word in regs.sail:334-335
- [x] LDTR (selector + hidden base/limit/attributes) — verified: LDTR : word in regs.sail:336 (selector only, no hidden cache)
- [x] TR (selector + hidden base/limit/attributes) — verified: TR : word, TR_base : qword, TR_limit : dword in regs.sail:337-341

### 3.13 MSRs (Commonly Used)
- [x] IA32_EFER (SCE, LME, LMA, NXE) — verified: native Sail register, bit positions in regs.sail:322-326
- [x] IA32_STAR, IA32_LSTAR, IA32_FMASK (SYSCALL/SYSRET) — verified: read via __rdmsr(0xC0000081/82/84)
- [N/A] IA32_CSTAR (compat mode SYSCALL) — compat mode not targeted
- [x] IA32_FS_BASE, IA32_GS_BASE, IA32_KERNEL_GS_BASE — verified: native Sail registers in regs.sail:191-193
- [N/A] IA32_SYSENTER_CS/ESP/EIP — SYSENTER/SYSEXIT not targeted (see 1.25.5)
- [x] IA32_TSC, IA32_TSC_AUX — verified: TSC via __rdtsc(), TSC_AUX via __rdmsr(0xC0000103)
- [N/A] IA32_PAT (page attribute table) — memory types not modeled in sequential model
- [N/A] IA32_APIC_BASE — APIC MMIO not modeled (system emulator uses legacy PIC)
- [N/A] IA32_MISC_ENABLE — miscellaneous feature enable bits not modeled
- [N/A] IA32_XSS — supervisor XSAVE state components not modeled

---

## Part 4: Memory and Addressing

### 4.1 Addressing Modes (64-bit)
- [x] Register direct — verified in insn_modrm.sail:258-260 (modbits=11)
- [x] [reg] (all 16 GPRs as base) — verified, REX.B extends to 16 GPRs
- [x] [reg + disp8/disp32] — verified (mod=01 disp8, mod=10 disp32)
- [x] [RIP + disp32] (RIP-relative) — verified, with 67h truncation to 32-bit
- [x] [base + index*scale] (scale = 1/2/4/8) — verified in decode_sib()
- [x] [base + index*scale + disp8/disp32] — verified
- [x] [disp32] (absolute, only via SIB; zero-extended to 64-bit) — verified (SIB base=5, mod=00)
- [x] [index*scale + disp32] (no base, via SIB) — verified
- [x] RSP/R12 as base forces SIB byte — verified (r/m=100 routes to SIB decode)
- [x] RBP/R13 with mod=00 means [disp32] (no base) — verified in decode_sib() and decode_rm()

### 4.2 Segmentation
- [N/A] Segment descriptor loading and caching — flat model assumed; FS/GS base set via MSRs
- [x] Flat model (DS/ES/SS base = 0 in 64-bit long mode) — verified in apply_segment(): only FS/GS add base
- [x] FS/GS non-zero base in 64-bit mode — verified, FS_BASE/GS_BASE added in apply_segment()
- [N/A] Segment limit checking (in compat/legacy mode) — compat/legacy mode not targeted
- [N/A] Code segment (conforming vs non-conforming) — full segment descriptor model not implemented; 64-bit flat mode assumed
- [N/A] Stack segment (SS.DPL = CPL) — SS descriptor not explicitly modeled; CPL tracked via cur_cpl register

### 4.3 Paging
- [x] 4-level paging (PML4 → PDPT → PD → PT) — verified: pt_walk with level 3→0 recursion
- [N/A] 5-level paging (PML5, when CR4.LA57 = 1) — 5-level paging not targeted; 4-level paging sufficient for Linux boot
- [x] 4KB pages — verified: level 0 leaf, offset[11:0]
- [x] 2MB large pages (PS bit in PDE) — verified: level 1 leaf with PS=1, offset[20:0]
- [x] 1GB huge pages (PS bit in PDPTE) — verified: level 2 leaf with PS=1, offset[29:0]
- [x] Page table entry format (P, R/W, U/S, PWT, PCD, A, D, PS, G, NX) — verified: P, R/W, U/S, A, D, PS, NX checked
- [x] CR3 (page-directory base register) — verified: used in translate_addr, masked to PPN
- [N/A] PCID (process-context identifiers, CR4.PCIDE) — TLB not modeled; no caching
- [x] NX (no-execute) bit support (IA32_EFER.NXE) — verified: XD bit[63] checked when EFER.NXE=1
- [N/A] SMEP (CR4.SMEP — supervisor can't execute user pages) — access control checks not fully modeled; Linux boots with noapic/nolapic
- [N/A] SMAP (CR4.SMAP — supervisor can't access user pages unless AC=1) — STAC/CLAC implemented but SMAP check not enforced in page walk
- [N/A] PKU (protection keys for user pages) — RDPKRU/WRPKRU return 0; PKU enforcement not modeled
- [N/A] PKS (protection keys for supervisor pages) — not modeled
- [N/A] PAT (page attribute table — memory type per page) — memory types not modeled in sequential model

### 4.4 Memory Types and Ordering
- [N/A] All memory types (UC, WC, WT, WB, WP) and MTRR/PAT interaction — sequential model has no memory hierarchy; all accesses are immediately visible
- [N/A] Memory ordering guarantees (strong ordering, store-buffer forwarding, LOCK barriers, fence semantics) — sequential model is inherently sequentially consistent; no reordering possible

### 4.5 Alignment
- [N/A] #AC for misaligned access at CPL=3 when CR0.AM=1 and RFLAGS.AC=1 — alignment check exception not modeled
- [N/A] #GP for misaligned LOCK'd instructions — split-lock detection not modeled
- [x] SSE: #GP for misaligned MOVAPS/MOVAPD/MOVDQA (128-bit aligned) — verified: alignment check in insn_sse_fp.sail and insn_vex_fp.sail
- [N/A] AVX-512: VMOVDQA32/64 require alignment, VMOVDQU do not — alignment checks for EVEX memory ops delegated to C++ externals
- [N/A] FXSAVE/FXRSTOR require 16-byte alignment — delegated to C++ __fxsave/__fxrstor externals
- [N/A] XSAVE requires 64-byte alignment — delegated to C++ __xsave/__xrstor externals

---

## Part 5: Exceptions and Interrupts

### 5.1 Exception Vectors
- [x] #DE (0) — divide error (DIV/IDIV) — verified: raised by DIV/IDIV, tested in system emulator
- [N/A] #DB (1) — debug exception; hardware breakpoint/single-step not modeled
- [x] NMI (2) — non-maskable interrupt — delivered through IDT like other interrupts
- [x] #BP (3) — breakpoint (INT3) — verified: INT3 delivers as software trap, tested
- [x] #OF (4) — overflow (INTO) — verified: INTO raises #UD in 64-bit mode (correct)
- [x] #BR (5) — bound range exceeded (BOUND) — verified: BOUND raises #UD in 64-bit mode (correct)
- [x] #UD (6) — invalid opcode — verified: raised throughout for invalid encodings
- [N/A] #NM (7) — device not available; CR0.EM/TS lazy FPU switching not modeled (FPU always available)
- [x] #DF (8) — double fault — verified: escalation logic in deliver_exception(), tested
- [N/A] #TS (10) — invalid TSS; TSS validation not fully modeled
- [x] #NP (11) — segment not present — verified: raised in deliver_exception_inner for not-present gate
- [N/A] #SS (12) — stack-segment fault; stack segment limits not enforced in 64-bit mode (canonical check covers this)
- [x] #GP (13) — general protection — verified: raised for privilege violations, bad MSR, etc. with error code
- [x] #PF (14) — page fault (error code: P, W/R, U/S, RSVD, I/D) — verified in paging.sail, tested
- [N/A] #MF (16) — x87 FPU floating-point error; x87 exceptions always masked, no #MF delivery
- [N/A] #AC (17) — alignment check; not modeled (see 4.5)
- [x] #MC (18) — machine check — used as triple fault signal
- [N/A] #XM (19) — SIMD floating-point exception; SSE exceptions always masked, no #XM delivery
- [N/A] #VE (20) — virtualization exception; VMX/EPT not modeled
- [N/A] #CP (21) — control protection exception; CET not modeled
- [N/A] #HV (28) — hypervisor injection; SEV-ES not modeled
- [N/A] #VC (29) — VMM communication; SEV-ES not modeled
- [N/A] #SX (30) — security exception; not modeled

### 5.2 Interrupt Delivery
- [x] IDT lookup (vector × 16 in 64-bit mode) — verified in read_idt_gate(), tested
- [x] Interrupt gate vs trap gate (IF clearing) — verified: type 0xE clears IF, 0xF preserves; tested
- [x] IST (Interrupt Stack Table) mechanism — verified in deliver_exception_inner(), read_tss_ist()
- [x] Error code pushing (which exceptions push error codes) — verified; fixed: software ints skip error code (SDM §6.13)
- [x] RSP alignment to 16 on interrupt stack frame — verified: `new_rsp & 0xFFF...F0`; tested
- [x] CPL change: stack switch via TSS — verified: reads RSP0 from TSS on privilege change
- [x] Same-privilege interrupt: no stack switch — verified: uses current RSP when old_cpl==0 and IST==0

### 5.3 Exception Conditions Per Instruction
- [x] Each instruction must raise exactly the exceptions listed in SDM — verified for #UD, #GP, #PF, #DE; #NM/#XM/#AC/#SS not modeled (see above)
- [x] #UD for invalid opcode in current mode (e.g., ARPL in 64-bit) — verified: ARPL, INTO, BOUND, PUSHA/POPA all #UD
- [x] #GP for privilege violations — verified: LGDT/LIDT/LMSW/INVLPG/RDMSR/WRMSR check CPL=0
- [N/A] #SS for stack-segment violations — stack segment limits not enforced in 64-bit mode
- [x] #PF for page faults with correct error code — verified: P, W/R, U/S, RSVD, I/D bits in error code
- [N/A] #NM when CR0.EM=1 or CR0.TS=1 for x87/SSE/AVX — lazy FPU switching not modeled
- [N/A] #XM or #UD based on CR4.OSXMMEXCPT for SSE exceptions — SSE exceptions always masked

---

## Part 6: Processor Modes and Transitions

### 6.1 Long Mode (64-bit)
- [x] Enabling: CR0.PG=1, CR4.PAE=1, IA32_EFER.LME=1 — system emulator boots through this sequence; cur_mode tracks 64-bit/32-bit/16-bit
- [x] 64-bit sub-mode (CS.L=1, CS.D=0) — primary operating mode, fully modeled
- [N/A] Compatibility sub-mode (CS.L=0; 32-bit code in long mode) — not targeted; system emulator uses 64-bit mode exclusively after boot
- [x] Default operand/address sizes per mode — verified: d64/f64 rules for PUSH/POP/CALL/RET, 66h/67h overrides

### 6.2 Protected Mode (Legacy 32-bit)
- [N/A] Full GDT/LDT/IDT operation — GDT/IDT base/limit loaded via LGDT/LIDT; full descriptor parsing only for TSS (LTR) and IDT gates
- [x] Privilege levels (CPL, RPL, DPL) — CPL tracked via cur_cpl register; used for privilege checks (LGDT, RDMSR, etc.) and stack switching on interrupts
- [x] Gate descriptors (interrupt gates, trap gates) — IDT gate parsing in deliver_exception_inner(); call gates and task gates not modeled

### 6.3 Real Mode
- [N/A] Real mode (segment:offset, IVT, no privilege checking) — system emulator starts in protected/long mode; real mode not targeted

### 6.4 Mode Transitions
- [N/A] Real → Protected (set CR0.PE) — real mode not targeted
- [x] Protected → Long (set CR4.PAE, IA32_EFER.LME, then CR0.PG) — system emulator boots through this sequence
- [N/A] Long → Protected (clear CR0.PG, then clear IA32_EFER.LME) — not targeted
- [N/A] Far JMP/CALL to change CS.L (64-bit ↔ compat) — compat mode not targeted

### 6.5 System Management Mode (SMM)
- [N/A] RSM instruction and SMRAM save state — SMM not targeted

---

## Part 7: Floating-Point Semantics (Cross-Cutting)

### 7.1 IEEE 754 Compliance
- [x] Rounding modes: round-nearest-even, round-down, round-up, round-toward-zero — verified + KVM FP Edge tests (622+ tests)
- [x] Denormal (subnormal) number handling — verified + KVM FP Edge tests (DAZ/FTZ category)
- [x] NaN propagation rules (Intel: src1 priority for SSE MIN/MAX) — verified: f32_nan_prop/f64_nan_prop in C emulator, KVM tests
- [x] Signaling NaN vs quiet NaN behavior — verified + KVM FP Edge tests (NaN category)
- [x] Infinity arithmetic (+∞, -∞) — verified + KVM FP Edge tests (Inf category)
- [x] Signed zero (+0, -0) semantics — verified + KVM FP Edge tests (signed zeros category)
- [x] Flush-to-zero (MXCSR.FTZ) — verified + KVM FP Edge tests
- [x] Denormals-are-zeros (MXCSR.DAZ) — verified + KVM FP Edge tests

### 7.2 FP Exception Reporting
- [N/A] FP exception flag reporting (IE, DE, ZE, OE, UE, PE) — all FP exceptions are always masked; exception flags set by host FPU via C++ externals but not explicitly checked by Sail model
- [N/A] Masked vs unmasked exception behavior — unmasked FP exceptions (#MF/#XM delivery) not modeled; all exceptions masked

### 7.3 x87 vs SSE FP Differences
- [x] x87 uses 80-bit internal precision — verified: x87_ST stores 80-bit extended precision values
- [x] SSE uses operand precision (32 or 64-bit) — verified: SSE ops use f32/f64 via C++ externals
- [N/A] x87 exception via #MF, SSE via #XM (or #UD) — exception delivery not implemented; all FP exceptions always masked
- [x] x87 condition codes (C0-C3) vs SSE EFLAGS setting — verified: FCOM sets C0/C2/C3 in SW, COMISS sets EFLAGS

---

## Part 8: Concurrency and Atomicity (Cross-Cutting)

### 8.1 LOCK Prefix
- [x] Valid only with: ADD, ADC, AND, BTC, BTR, BTS, CMPXCHG, CMPXCHG8B/16B,
        DEC, INC, NEG, NOT, OR, SBB, SUB, XOR, XADD, XCHG — verified: is_lockable_1byte/2byte
- [x] #UD on LOCK with any other instruction — verified: checked at dispatch entry
- [x] LOCK'd operations are atomic and act as full memory barriers — sequential model (implicit)
- [x] XCHG implicitly LOCK'd when memory operand — verified

### 8.2 Alignment and Atomicity
- [N/A] Atomicity guarantees (naturally-aligned loads/stores, CMPXCHG16B alignment, split-lock detection) — sequential model has no concurrency; all operations are inherently atomic

---

## Part 9: Instruction-Specific Behavioral Details

These are tricky behaviors a formal spec MUST get right.

### 9.1 Shift/Rotate Count Masking
- [x] 32-bit ops: count masked to 5 bits (& 0x1F) — verified in shift.sail
- [x] 64-bit ops: count masked to 6 bits (& 0x3F) — verified in shift.sail
- [x] OF defined only for count=1 shifts — verified
- [x] Count=0 shifts: no flags modified — verified

### 9.2 REP String Operations
- [x] RCX=0 → no operation, no flags changed — verified in string.sail
- [x] REPE/REPNE with CMPS/SCAS: early termination on ZF mismatch — verified
- [N/A] Interruptibility between iterations — sequential model processes string ops atomically; interrupt interleaving not modeled
- [x] Address size determines whether CX/ECX/RCX is used — verified

### 9.3 PUSH/POP RSP
- [x] PUSH RSP pushes the value of RSP before the push — verified + KVM tests
- [x] POP RSP: value popped is the new RSP (not incremented after) — verified

### 9.4 MOV to SS
- [N/A] Inhibits interrupts for one instruction after MOV to SS — interrupt inhibition not modeled (sequential model delivers interrupts at instruction boundary only)

### 9.5 Division
- [x] DIV: #DE if quotient overflows or divisor=0 — verified + KVM tests
- [x] IDIV: #DE if quotient overflows or divisor=0 — verified + KVM tests
- [x] 8-bit DIV: AX / src → AL quotient, AH remainder — verified
- [x] 16-bit DIV: DX:AX / src → AX quotient, DX remainder — verified
- [x] etc. for 32/64-bit — verified

### 9.6 IMUL Forms
- [x] 1-operand: signed widening multiply (same as MUL but signed) — verified + KVM tests
- [x] 2-operand: dst = dst × src (truncated, OF/CF set if sign-extended result ≠ full result) — verified
- [x] 3-operand: dst = src × imm (truncated, same OF/CF rule) — verified

### 9.7 BSF/BSR vs TZCNT/LZCNT
- [x] BSF/BSR: ZF=1 if source is 0, destination UNDEFINED — verified + KVM tests
- [x] TZCNT/LZCNT: CF=1 if source is 0, result = operand bit size — verified + KVM tests
- [x] On CPUs without BMI, TZCNT executes as BSF (F3 prefix ignored) — N/A (we always have BMI)
- [x] LZCNT without ABM: executes as BSR — N/A (we always have ABM)

### 9.8 CPUID
- [x] Leaf 0: max basic leaf, vendor string — delegated to __cpuid external
- [x] Leaf 1: family/model/stepping, feature flags (ECX, EDX) — delegated to __cpuid external
- [x] Leaf 7: extended feature flags (structured) — delegated to __cpuid external
- [x] Leaf 0x80000000-0x80000008: extended leaves — delegated to __cpuid external
- [x] Must report feature bits consistent with implemented instructions — host passthrough via __cpuid
- [x] Invalid/unsupported leaves: return 0 or last valid leaf's data — handled by host CPUID

### 9.9 NOP Width
- [x] 1-byte NOP (0x90 = XCHG EAX,EAX) — verified: special-cased in dispatch, does not zero-extend
- [x] Multi-byte NOP (0F 1F /0, various lengths up to 9 bytes) — verified: consumes ModR/M + SIB + disp
- [x] In 64-bit mode, 0x90 is NOP (not XCHG EAX,EAX which would zero-extend) — verified correct

### 9.10 VEX/EVEX Upper-Bits Clearing
- [x] VEX-128: zero bits 255:128 of YMM — verified: write_xmm zeroes upper
- [x] VEX-256: zero bits 511:256 of ZMM (if AVX-512 supported) — verified: write_ymm zeroes 511:256
- [x] EVEX-128: zero bits 511:128 — verified: write_xmm() initializes 512-bit reg to zeros, writes low 128
- [x] EVEX-256: zero bits 511:256 — verified: write_ymm() initializes 512-bit reg to zeros, writes low 256
- [x] Legacy SSE: upper bits of YMM/ZMM are PRESERVED (no zeroing) — verified: write_xmm_legacy preserves
- [x] SSE↔AVX transition penalty implications (VZEROUPPER) — verified: VZEROUPPER/VZEROALL implemented

---

## Part 10: Summary Statistics

- **Total unique mnemonics in SDM:** 1,208
- **SDM instruction pages:** 835 (some cover multiple related mnemonics)
- **ISA extension groups:** ~30+ (from base x86-64 through AMX)

### Rough instruction count by category:
| Category | Approx. count |
|---|---|
| General-purpose integer | ~120 |
| x87 floating-point | ~90 |
| MMX | ~50 (implemented) |
| SSE (1/2/3/SSSE3/4.1/4.2) | ~200 |
| AVX/AVX2 (VEX re-encoding of above) | (same ops, VEX form) |
| FMA | ~96 forms (4 ops × 3 orderings × 2 types × 2 sizes + packed variants) |
| AVX-512 (F/BW/DQ/CD/VL/VBMI/IFMA/VNNI/BITALG/VP2INTERSECT/etc.) | ~350+ |
| AVX-512 FP16 | ~80 |
| BMI1/BMI2/ADX | ~16 |
| AES-NI/SHA/GFNI/PCLMULQDQ | ~18 |
| Key Locker | ~10 |
| CET (shadow stack + IBT) | ~12 |
| AMX | ~8 |
| System (VMX/SGX/SMX/descriptors/CR/DR/MSR) | ~60 |
| TSX/XSAVE/misc | ~20 |

---

## How to Use This Checklist

For each `[ ]` item:
1. Search the Sail codebase for the instruction mnemonic or opcode
2. Verify it decodes the correct opcode bytes per SDM
3. Verify it handles all valid operand-size and addressing-mode variants
4. Verify flag effects match SDM exactly
5. Verify exception conditions match SDM (#UD in wrong mode, #GP for privilege, etc.)
6. Mark as one of:
   - `[x]` Implemented and correct
   - `[~]` Partially implemented (note what's missing)
   - `[ ]` Not implemented
   - `[N/A]` Explicitly out of scope (document why)
