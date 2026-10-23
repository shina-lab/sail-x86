// Known deviations of the test hosts from the manuals.
//
// The model follows the Intel SDM, and the AMD APM where the two manuals
// define different behaviour for AMD processors; a case expects what the
// manuals give, the same on every host.  The hardware is only the test
// environment: where a host does something else, the case keeps its
// expectation and is listed here with the reason, so that the difference
// stays on record rather than being copied into the model or hidden by a
// host-specific expectation.  A listed case that mismatches is reported as
// a known deviation, not a failure; one that matches passes as usual.
//
// Each entry names the host vendor, the case, and what the hardware does
// against what the manuals say, with section and page.  A '*' in the name
// matches any characters: a trailing one also matches the case's variants,
// whose names extend the base name with " [detail]", and "*[detail]*" one
// kind of variant of every case.  Where the host takes another outcome
// than the manuals give, the entry names the model's outcome, which is
// theirs, or the host's, or both, and covers only a run whose outcomes
// differ so: a variant of the kind that completes on both sides, or faults
// alike on both, is still compared and fails as usual.  Where the host
// passes over a fault the manuals give (#UD for a reserved encoding, say),
// the entry names the model's alone, for the host then does what the
// case's instructions go on to do: completes, or faults at a later one, or
// faults otherwise.  HOST_CANNOT_RUN marks a case that KVM on the host
// cannot run at all; the entry's reason says why.

#include "kvm-harness.h"
#include <cpuid.h>

namespace {

// The outcomes the entries name.
constexpr int COMPLETES = -1, DB = 1, UD = 6, GP = 13;

// The reasons of the gather entries, which share them.
const char *const GATHER_VEX_UPPER =
    "An Emerald Rapids clears the destination above VL when a gather faults on an element "
    "after loading one below it (and leaves it when the first element faults).  The SDM's "
    "Operation clears DEST[MAXVL-1:VL] after the last element, and \"a fault exits the "
    "instruction\" at the load before it (VPGATHERDD etc., Vol.2C p.5-552); the description "
    "lets a fault leave only the gathered elements: \"partially updated; those elements that "
    "have been gathered are placed into the destination register and have their mask bits set "
    "to zero\" (p.5-551), the rest as before the instruction (Vol.3A §7.5, p.7-5).  Only the "
    "parts that \"do not correspond to any elements\", above the dword elements of qword "
    "indices, may be zeroed \"even if the instruction triggers an exception\" (p.5-551).";
const char *const GATHER_EVEX_UPPER =
    "An Emerald Rapids clears the destination above VL when a gather faults on an element "
    "after loading one below it.  The SDM's Operation clears DEST[MAXVL-1:VL] after the loop "
    "(VPGATHERDD etc., Vol.2C p.5-549); the description lets a fault leave only the gathered "
    "elements: \"partially updated; those elements that have been gathered are placed into "
    "the destination register and have their mask bits set to zero\" (p.5-548), the rest as "
    "before the instruction (Vol.3A §7.5, p.7-5).  Only where \"the data element size is less "
    "than the index element size\" may the higher part be zeroed \"even if the instruction "
    "triggers an exception\" (p.5-548).";
const char *const GATHER_EVEX_UPPER_AMD =
    "Zen 4 clears the destination above VL when an EVEX gather faults on an element after "
    "loading one below it.  The SDM's Operation clears DEST[MAXVL-1:VL] after the loop "
    "(VPGATHERDD etc., Vol.2C p.5-549), and its description lets a fault leave only the "
    "gathered elements (p.5-548; the rest as before the instruction, Vol.3A §7.5, p.7-5).  "
    "The APM says only that \"the destination register and the mask operand may be observed "
    "as partially updated.  Elements that have been loaded will have their mask elements set "
    "to zero\" (Vol.4 VPGATHERDD p.1397, VGATHERDPD p.1158), nothing of the bits above VL, so "
    "the model has the SDM's rule on both vendors.";

// The reason of the VEX instructions without an SSE form under CR0.EM.
const char *const VEX_NO_SSE_FORM_EM =
    "Zen 4 executes a VEX instruction without a legacy SSE form with CR0.EM = 1; APM Vol.2 "
    "§8.2.7 (p.252) gives #UD for \"any SSE instruction (uses ZMM/YMM/XMM registers)\" when "
    "CR0.EM = 1, and of the classes of these instructions (Vol.4 Table 3-1, \"Legacy Type "
    "—\") 4G, 4H and 4H-1 list \"CR0.EM = 1\" under #UD (pp.1831-1833, VTESTPS, VPERMD, "
    "VPERMQ), while the others (VPBLENDD, VPSLLVD, VINSERTI128, VBROADCASTSS, VZEROUPPER) "
    "do not name EM, which leaves §8.2.7.";

const std::vector<KnownDeviation> DEVIATIONS = {
    // {amd, "case name", "reason"[, model outcome[, host outcome]]},

    // CR0.EM and CR0.TS (kvm-tests-cr0.cpp)
    {true, "vpaddd zmm0,zmm1,zmm2 [EM]*",
     "Zen 4 executes an EVEX instruction with CR0.EM = 1; APM Vol.4 §3.2.1 (p. 1878), the "
     "control register exceptions of the AVX512 instructions, lists \"CR0.EM = 1\" under "
     "\"Invalid opcode, #UD\", as Vol.2 §8.2.7 (p. 252) does for \"any SSE instruction (uses "
     "ZMM/YMM/XMM registers)\"", UD},
    {true, "vpaddd zmm0,zmm1,zmm2 [EM MP]*",
     "Zen 4 executes an EVEX instruction with CR0.EM = 1; APM Vol.4 §3.2.1 (p. 1878) lists "
     "\"CR0.EM = 1\" under \"Invalid opcode, #UD\" for the AVX512 instructions", UD},
    {true, "kmovw k1,k2 [EM]*",
     "Zen 4 executes VEX KMOVW with CR0.EM = 1; the APM's KMOVW page (Vol.4 p. 212) says "
     "\"Exceptions for AVX512 instructions are enumerated in Section 3.2\", and §3.2.1 "
     "(p. 1878) lists \"CR0.EM = 1\" under \"Invalid opcode, #UD\"", UD},
    {true, "kmovw k1,k2 [EM MP]*",
     "Zen 4 executes VEX KMOVW with CR0.EM = 1; the APM's KMOVW page (Vol.4 p. 212) refers to "
     "§3.2, whose §3.2.1 (p. 1878) lists \"CR0.EM = 1\" under \"Invalid opcode, #UD\"", UD},
    {true, "vtestps xmm1,xmm2 [EM*", VEX_NO_SSE_FORM_EM, UD},
    {true, "vpermd ymm0,ymm1,ymm2 [EM*", VEX_NO_SSE_FORM_EM, UD},
    {true, "vpermq ymm0,ymm1,1Bh [EM*", VEX_NO_SSE_FORM_EM, UD},
    {true, "vpblendd ymm0,ymm1,ymm2,55h [EM*", VEX_NO_SSE_FORM_EM, UD},
    {true, "vpsllvd ymm0,ymm1,ymm2 [EM*", VEX_NO_SSE_FORM_EM, UD},
    {true, "vinserti128 ymm0,ymm1,xmm2,1 [EM*", VEX_NO_SSE_FORM_EM, UD},
    {true, "vbroadcastss ymm0,xmm1 [EM*", VEX_NO_SSE_FORM_EM, UD},
    {true, "vzeroupper [EM*", VEX_NO_SSE_FORM_EM, UD},

    // x87 stack faults and condition codes (kvm-tests-x87-cc.cpp)
    {false, "fsincos 2^63, ST(7) full (out of range*",
     "An Emerald Rapids treats a source of 2^63 (out of range) with ST(7) full as a stack "
     "overflow: masked it pushes the indefinite as both results with C2 = 0, unmasked it sets "
     "IE, SF and ES.  The SDM pushes only in range (FSINCOS Operation, Vol.2A p.3-383: \"IF "
     "ST(0) < 2^63 THEN ... TOP := TOP - 1; ... ELSE (* Source operand out of range *) C2 := "
     "1;\"), and \"The instruction does not raise an exception when the source operand is out "
     "of range\" (Description, p.3-382)."},
    {false, "fptan 2^63, ST(7) full (out of range*",
     "An Emerald Rapids treats a source of 2^63 (out of range) with ST(7) full as a stack "
     "overflow: masked it pushes the indefinite as both results with C2 = 0, unmasked it sets "
     "IE, SF and ES.  The SDM pushes only in range (FPTAN Operation, Vol.2A p.3-371: \"IF "
     "ST(0) < 2^63 THEN ... TOP := TOP - 1; ST(0) := 1.0; ELSE (* Source operand is "
     "out-of-range *) C2 := 1;\"), and \"The instruction does not raise an exception when the "
     "source operand is out of range\" (Description, p.3-370)."},
    {true, "fsincos 2^63, ST(7) full (out of range*",
     "A Zen 4 treats a source of 2^63 (out of range) with ST(7) full as a stack overflow: "
     "masked it pushes the indefinite as both results with C2 = 0, unmasked it sets IE, SF and "
     "ES.  The APM: \"If the source operand is outside this range, the instruction sets the C2 "
     "bit in the x87 status word to 1 and does not change the value in ST(0)\" (Vol.5 FSINCOS, "
     "p.298), so it loads no register and cannot overflow the stack."},
    {true, "fptan 2^63, ST(7) full (out of range*",
     "A Zen 4 treats a source of 2^63 (out of range) with ST(7) full as a stack overflow: "
     "masked it pushes the indefinite as both results with C2 = 0, unmasked it sets IE, SF and "
     "ES.  The APM: \"If the source value lies outside the specified range, the instruction "
     "sets the C2 bit of the x87 status word to 1 and does not change the value in ST(0)\" "
     "(Vol.5 FPTAN, p.286), so it loads no register and cannot overflow the stack."},
    {false, "fcomi st(0),st(1) (unmasked underflow, flags clear)*",
     "An Emerald Rapids sets ZF, PF and CF to unordered (111) on an unmasked stack underflow.  "
     "The SDM: an unmasked invalid-operation exception is detected before the operation, and "
     "\"the destination operand has not yet been updated, and appears as if the offending "
     "instruction has not been executed\" (Vol.1 §4.9.2, p.4-25); FCOMI's destination is ZF, "
     "PF and CF (Vol.2A FCOMI, p.3-327)."},
    {false, "fcomip st(0),st(1) (unmasked underflow, flags clear)*",
     "An Emerald Rapids sets ZF, PF and CF to unordered (111) on an unmasked stack underflow; "
     "the SDM leaves the destination unchanged (Vol.1 §4.9.2, p.4-25), as for FCOMI."},
    {false, "fucomi st(0),st(1) (unmasked underflow, flags clear)*",
     "An Emerald Rapids sets ZF, PF and CF to unordered (111) on an unmasked stack underflow; "
     "the SDM leaves the destination unchanged (Vol.1 §4.9.2, p.4-25), as for FCOMI."},
    {false, "fucomip st(0),st(1) (unmasked underflow, flags clear)*",
     "An Emerald Rapids sets ZF, PF and CF to unordered (111) on an unmasked stack underflow; "
     "the SDM leaves the destination unchanged (Vol.1 §4.9.2, p.4-25), as for FCOMI."},
    {true, "fcomi st(0),st(1) (unmasked underflow, flags clear)*",
     "A Zen 4 sets ZF, PF and CF to unordered (111) on an unmasked stack underflow.  The APM: "
     "\"Set IE and ES flags, and call the #MF service routine. The destination and the TOP are "
     "not changed.\" (Vol.1 Table 6-22, p.337); FCOMI's destination is ZF, PF and CF (Vol.5 "
     "FCOMI, p.237)."},
    {true, "fcomip st(0),st(1) (unmasked underflow, flags clear)*",
     "A Zen 4 sets ZF, PF and CF to unordered (111) on an unmasked stack underflow; the APM "
     "leaves the destination unchanged (Vol.1 Table 6-22, p.337), as for FCOMI."},
    {true, "fucomi st(0),st(1) (unmasked underflow, flags clear)*",
     "A Zen 4 sets ZF, PF and CF to unordered (111) on an unmasked stack underflow; the APM "
     "leaves the destination unchanged (Vol.1 Table 6-22, p.337), as for FCOMI."},
    {true, "fucomip st(0),st(1) (unmasked underflow, flags clear)*",
     "A Zen 4 sets ZF, PF and CF to unordered (111) on an unmasked stack underflow; the APM "
     "leaves the destination unchanged (Vol.1 Table 6-22, p.337), as for FCOMI."},
    {false, "fcmovb st(0),st(1), ST(0) empty*",
     "An Emerald Rapids raises a stack underflow for FCMOVcc with ST(0), its destination, empty, "
     "whether or not the condition holds: masked it writes the indefinite to ST(0), unmasked it "
     "sets IE, SF and ES.  The SDM: \"The source operand is always in the ST(i) register and the "
     "destination operand is always ST(0)\" (Vol.2A FCMOVcc, p.3-322), and a stack underflow is "
     "when \"An instruction references an empty x87 FPU register as a source operand\" (Vol.1 "
     "§8.5.1.1, p.8-26)."},

    // System instructions, the MOV SS shadow, INT1 (sysmisc)
    {true, "int1 (F1) trap, RIP past the instruction*",
     "KVM on AMD (SVM) delivers the #DB of INT1 with the INT1's own RIP; the silicon "
     "pushes the next RIP natively (the RIP a SIGTRAP handler sees).  INT1 is a trap: "
     "SDM Vol.2A INT1, \"Generate debug trap\"; APM Vol.2 §8.2.2 p.249, \"the saved "
     "instruction pointer points to the instruction after the one that caused the #DB\"."},
    {true, "insn bp on the instruction after mov ss (suppressed)*",
     "A Zen 4 takes the instruction breakpoint on the instruction after MOV SS (also "
     "natively, with a ptrace-armed DR0).  The APM does \"not allow external interrupts "
     "or debug exceptions to occur until the instruction immediately following the MOV "
     "SS or POP SS instruction completes execution\" (Vol.2 §8.1.4 p.245); the SDM "
     "suppresses the breakpoint \"as if EFLAGS.RF were 1\" (Vol.3A §7.8.3 p.7-8).",
     COMPLETES, DB},

    // Interrupts from virtual-8086 mode (test-vm86.cpp)
    {true, "vm86: 16-bit monitor stack: ESP[31:16] from ESP0*",
     "A Zen 4 entering a 16-bit monitor stack from virtual-8086 mode loads SP from the TSS "
     "and keeps the interrupted ESP's bits 31:16 (0x1234 here, against ESP0's 0x5678).  The "
     "APM loads all of ESP0: \"temp_SS_desc:temp_RSP = READ_INNER_LEVEL_SP(CPL, temp_ist); "
     "RSP = temp_RSP\" (Vol.3 INT p.199), with \"temp_RSP = READ_MEM.d [tss:new_cpl*8+4]\" "
     "(p.74); so does the SDM: \"ESP := NewESP\" (Vol.2A INT n, 3-476)."},
    {false, "vm86: 16-bit monitor stack: ESP[31:16] from ESP0*",
     "An Emerald Rapids entering a 16-bit monitor stack from virtual-8086 mode loads SP from "
     "the TSS and keeps the interrupted ESP's bits 31:16 (0x1234 here, against ESP0's 0x5678).  "
     "The SDM loads all of ESP0: \"NewESP := 4 bytes loaded from (current TSS base + 4)\" and "
     "\"ESP := NewESP\" (Vol.2A INT n, INTERRUPT-FROM-VIRTUAL-8086-MODE, 3-476); so does the "
     "APM: \"RSP = temp_RSP\" from \"READ_MEM.d [tss:new_cpl*8+4]\" (Vol.3 INT p.199, p.74)."},

    // Gathers and scatters (kvm-tests-avx-vex.cpp, kvm-tests-avx-special.cpp)
    {false, "VPGATHERDD xmm element *", GATHER_VEX_UPPER},
    {false, "VPGATHERDD ymm element *", GATHER_VEX_UPPER},
    {false, "VPGATHERDQ xmm element *", GATHER_VEX_UPPER},
    {false, "VPGATHERDQ ymm element *", GATHER_VEX_UPPER},
    {false, "VPGATHERQQ xmm element *", GATHER_VEX_UPPER},
    {false, "VPGATHERQQ ymm element *", GATHER_VEX_UPPER},
    {false, "VGATHERDPS xmm element *", GATHER_VEX_UPPER},
    {false, "VGATHERDPS ymm element *", GATHER_VEX_UPPER},
    {false, "VGATHERDPD xmm element *", GATHER_VEX_UPPER},
    {false, "VGATHERDPD ymm element *", GATHER_VEX_UPPER},
    {false, "VGATHERQPD xmm element *", GATHER_VEX_UPPER},
    {false, "VGATHERQPD ymm element *", GATHER_VEX_UPPER},
    {false, "VPGATHERDD xmm{k1} element *", GATHER_EVEX_UPPER},
    {false, "VPGATHERDD ymm{k1} element *", GATHER_EVEX_UPPER},
    {false, "VPGATHERDQ xmm{k1} element *", GATHER_EVEX_UPPER},
    {false, "VPGATHERDQ ymm{k1} element *", GATHER_EVEX_UPPER},
    {false, "VPGATHERQQ xmm{k1} element *", GATHER_EVEX_UPPER},
    {false, "VPGATHERQQ ymm{k1} element *", GATHER_EVEX_UPPER},
    {false, "VGATHERDPS xmm{k1} element *", GATHER_EVEX_UPPER},
    {false, "VGATHERDPS ymm{k1} element *", GATHER_EVEX_UPPER},
    {false, "VGATHERDPD xmm{k1} element *", GATHER_EVEX_UPPER},
    {false, "VGATHERDPD ymm{k1} element *", GATHER_EVEX_UPPER},
    {false, "VGATHERQPD xmm{k1} element *", GATHER_EVEX_UPPER},
    {false, "VGATHERQPD ymm{k1} element *", GATHER_EVEX_UPPER},
    {true, "VPGATHERDD xmm{k1} element *", GATHER_EVEX_UPPER_AMD},
    {true, "VPGATHERDD ymm{k1} element *", GATHER_EVEX_UPPER_AMD},
    {true, "VPGATHERDQ xmm{k1} element *", GATHER_EVEX_UPPER_AMD},
    {true, "VPGATHERDQ ymm{k1} element *", GATHER_EVEX_UPPER_AMD},
    {true, "VPGATHERQQ xmm{k1} element *", GATHER_EVEX_UPPER_AMD},
    {true, "VPGATHERQQ ymm{k1} element *", GATHER_EVEX_UPPER_AMD},
    {true, "VGATHERDPS xmm{k1} element *", GATHER_EVEX_UPPER_AMD},
    {true, "VGATHERDPS ymm{k1} element *", GATHER_EVEX_UPPER_AMD},
    {true, "VGATHERDPD xmm{k1} element *", GATHER_EVEX_UPPER_AMD},
    {true, "VGATHERDPD ymm{k1} element *", GATHER_EVEX_UPPER_AMD},
    {true, "VGATHERQPD xmm{k1} element *", GATHER_EVEX_UPPER_AMD},
    {true, "VGATHERQPD ymm{k1} element *", GATHER_EVEX_UPPER_AMD},
    {true, "*(#DB in lieu)*",
     "Zen 4 delivers the #DB of a data breakpoint that a completed gather or scatter element "
     "hit, in lieu of the later element's fault, with RFLAGS.RF = 0 in the pushed image; "
     "\"in this case, the RF flag is set so that an instruction breakpoint is not "
     "re-triggered when the instruction execution is resumed\" (APM Vol.4 VPGATHERDD "
     "p.1397, VPSCATTERDD p.1573); \"EFLAG.RF is set to one\" (SDM Vol.2C VPGATHERDD "
     "p.5-551)."},

    // VEX and EVEX encodings (evex).
    {false, "Masked-off misaligned EVEX *",
     "Emerald Rapids runs a misaligned VMOVAPS/VMOVAPD/VMOVDQA32/VMOVDQA64 whose writemask "
     "selects no element, without #GP; the alignment #GP of class E1 has no fault "
     "suppression: SDM Vol.2A Table 2-46 (p.2-49), \"EVEX.512: Memory operand is not 64-byte "
     "aligned\" (the other memory faults: \"If fault suppression not set, and ...\"); APM "
     "Vol.4 MOVAPS (p.284), \"A memory operand that is not aligned causes a "
     "general-protection exception\"", GP},
    {true, "Masked-off misaligned EVEX *",
     "Zen 4 runs a misaligned VMOVAPS/VMOVAPD/VMOVDQA32/VMOVDQA64 whose writemask selects no "
     "element, without #GP; the alignment #GP of class E1 has no fault suppression: SDM "
     "Vol.2A Table 2-46 (p.2-49), \"EVEX.512: Memory operand is not 64-byte aligned\" (the "
     "other memory faults: \"If fault suppression not set, and ...\"); APM Vol.4 MOVAPS "
     "(p.284), \"A memory operand that is not aligned causes a general-protection "
     "exception\"", GP},
    {true, "vmovdqa32 xmm0,xmm1 EVEX.V'̄=0*",
     "Zen 4 runs VMOVDQA32 with EVEX.V'̄ = 0 in compatibility mode; #UD in both manuals: SDM "
     "Vol.2A Table 2-41 (p.2-44), \"EVEX.V' | Otherwise | If 0 | If 0\"; APM Vol.4 §3.2.4 "
     "(p.1880), \"EVEX.V' != 1 | Single source operand instructions | #UD3 | #UD\"", UD},
    {true, "vpgatherdd zmm0{k1},[edi+zmm2*4] EVEX.V'̄=0*",
     "Zen 4 runs VPGATHERDD with EVEX.V'̄ = 0 in compatibility mode; #UD in both manuals: SDM "
     "Vol.2A Table 2-41 (p.2-44), \"EVEX.V' | Encodes ZMM/YMM/XMM | None (valid) | If 0\"; APM "
     "Vol.4 §3.2.4 (p.1880), \"EVEX.V' != 1 | ... | #UD3 | #UD\", whose note 3 exempts VSIB "
     "in 64-bit mode only", UD},
    {true, "vpxord xmm0,xmm1,xmm2 EVEX.V'̄=0*",
     "Zen 4 ignores EVEX.V'̄ = 0 in compatibility mode where EVEX.vvvv names a register; SDM "
     "Vol.2A Table 2-41 (p.2-44): \"EVEX.V' | Encodes ZMM/YMM/XMM | None (valid) | If 0\" "
     "(#UD outside 64-bit mode); the APM has no rule for it (Vol.4 §3.2.4)", UD},
    {true, "vpxord zmm0,zmm1,zmm2 EVEX.V'̄=0*",
     "Zen 4 ignores EVEX.V'̄ = 0 in compatibility mode where EVEX.vvvv names a register; SDM "
     "Vol.2A Table 2-41 (p.2-44): \"EVEX.V' | Encodes ZMM/YMM/XMM | None (valid) | If 0\" "
     "(#UD outside 64-bit mode); the APM has no rule for it (Vol.4 §3.2.4)", UD},
    {true, "vpxord xmm0,xmm1,xmm2 EVEX.V'̄=0 vvvv bit 3*",
     "Zen 4 ignores EVEX.V'̄ = 0 in compatibility mode where EVEX.vvvv names a register; SDM "
     "Vol.2A Table 2-41 (p.2-44): \"EVEX.V' | Encodes ZMM/YMM/XMM | None (valid) | If 0\" "
     "(#UD outside 64-bit mode); the APM has no rule for it (Vol.4 §3.2.4)", UD},
    {true, "vpextrq eax,xmm1,1 W1*",
     "Zen 4 faults on VEX VPEXTRQ (W1) in compatibility mode; both manuals make it VPEXTRD: SDM "
     "Vol.2B PEXTRQ (4-286) note 2, \"VEX.W/EVEX.W in non-64 bit is ignored; the instructions "
     "behaves as if the W0 version is used\"; APM Vol.4 VPEXTRD (p.479), \"x.1111.0.01 16 /r "
     "ib\", \"only available in non-64-bit modes\".  (The EVEX case of this name runs.)",
     COMPLETES, UD},
    {true, "vpextrq eax,xmm1,1 W1 [edi]*",
     "Zen 4 faults on VEX VPEXTRQ (W1) in compatibility mode; both manuals make it VPEXTRD: SDM "
     "Vol.2B PEXTRQ (4-286) note 2, \"VEX.W/EVEX.W in non-64 bit is ignored; the instructions "
     "behaves as if the W0 version is used\"; APM Vol.4 VPEXTRD (p.479), \"x.1111.0.01 16 /r "
     "ib\", \"only available in non-64-bit modes\"",
     COMPLETES, UD},
    {true, "vpextrq eax,xmm1,3 W1*",
     "Zen 4 faults on VEX VPEXTRQ (W1) in compatibility mode; both manuals make it VPEXTRD: SDM "
     "Vol.2B PEXTRQ (4-286) note 2, \"VEX.W/EVEX.W in non-64 bit is ignored; the instructions "
     "behaves as if the W0 version is used\"; APM Vol.4 VPEXTRD (p.479), \"x.1111.0.01 16 /r "
     "ib\", \"only available in non-64-bit modes\".  (The EVEX case of this name runs.)",
     COMPLETES, UD},
    {true, "vpextrq eax,xmm1,3 W1 [edi]*",
     "Zen 4 faults on VEX VPEXTRQ (W1) in compatibility mode; both manuals make it VPEXTRD: SDM "
     "Vol.2B PEXTRQ (4-286) note 2, \"VEX.W/EVEX.W in non-64 bit is ignored; the instructions "
     "behaves as if the W0 version is used\"; APM Vol.4 VPEXTRD (p.479), \"x.1111.0.01 16 /r "
     "ib\", \"only available in non-64-bit modes\"",
     COMPLETES, UD},
    {true, "kmovq k1,eax W1*",
     "Zen 4 runs KMOVQ k1, eax (VEX.W1) in compatibility mode as a 64-bit move, k1[63:32] = "
     "RAX[63:32]; the manuals allow #UD or KMOVD, which zeroes k1[63:32]: SDM Vol.2A KMOVQ "
     "(3-517) \"V/I\" and (3-518) \"VEX.W can only be used to modify the size of the GPR "
     "operand in 64b mode\"; APM Vol.4 KMOVQ (p.211), \"These encodings are only available in "
     "64-bit mode\", and §3.2.5 (p.1881), \"Undefined cases of a value of VEX.W\" \"may cause a "
     "#UD\""},
    {true, "*[EVEX.b]*",
     "Zen 4 ignores EVEX.b in the register form of an instruction with neither {er} nor {sae}; "
     "#UD in both manuals: APM Vol.4 §3.2.4 (p.1880), \"EVEX.b == 1 | Non-Memory instructions "
     "that specify neither {er} nor {sae} | #UD | #UD\"; SDM Vol.2A Table 2-43 (p.2-45), valid "
     "only for \"Reg-reg, FP instructions with rounding semantic\", \"Other reg-reg, FP "
     "instructions that can cause #XM\" and reg-mem broadcasts, \"If EVEX.b = 1\" otherwise.  "
     "(The variant sets EVEX.b in every form, also where it is valid.)", UD},
    {true, "*{1toN}* [memory r/m as register]*",
     "Zen 4 ignores EVEX.b in the register form of an instruction with neither {er} nor {sae} "
     "(the variant keeps the broadcast's EVEX.b); #UD in both manuals: APM Vol.4 §3.2.4 "
     "(p.1880), \"EVEX.b == 1 | Non-Memory instructions that specify neither {er} nor {sae} | "
     "#UD | #UD\"; SDM Vol.2A Table 2-43 (p.2-45), valid only for \"Reg-reg, FP instructions "
     "with rounding semantic\", \"Other reg-reg, FP instructions that can cause #XM\" and "
     "reg-mem broadcasts, \"If EVEX.b = 1\" otherwise", UD},
    {true, "*[EVEX.z]*",
     "Zen 4 ignores EVEX.z in a form without masking (VAESENC and VPCLMULQDQ among them) unless "
     "the zeroing would apply to an opmask or memory operand; #UD in both manuals: APM Vol.4 "
     "§3.2.4 (p.1879), \"EVEX.z == 1 && EVEX.aaa == 000b | All instructions | #UD | #UD\"; SDM "
     "Vol.2A Table 2-42 (p.2-44), \"EVEX.z | Instructions with EVEX.aaa = 000b. | If EVEX.z != "
     "0\".  (The variant sets EVEX.z in every form, also where it is valid.)", UD},
    {true, "*[opmask field bit 3 set]*",
     "Zen 4 ignores VEX.R̄ = 0 with an opmask register in ModRM.reg, and bit 3 of a VEX.vvvv "
     "that names one: APM Vol.4 §3.2.5 (p.1880), \"VEX.R == 0 | When ModR/M.reg specifies a K "
     "register | #UD\"; SDM Vol.2A Table 2-41 (p.2-44), \"EVEX.R | ModRM.reg encodes k-reg | If "
     "EVEX.R = 0\", note 1, \"This table also represents VEX restrictions\", and Table 2-42 "
     "(p.2-44), \"K-regs are instruction operands not mask control. | If vvvv = 0xxxb\".  (The "
     "variant sets bit 3 of the opmask fields of every instruction of its case, also of the VEX "
     "KMOV that sets up a mask.)", UD},

    // x87 state: instruction and data pointers, state images
    {false, "x87 pointers after f*",
     "Emerald Rapids stores the address of FFREE, FINCSTP, FDECSTP or FNOP as the last "
     "instruction pointer (FIP); the SDM lists the four with the x87 FPU control "
     "instructions (Vol.1 §8.3.11 p.8-23), and the pointers are those of the last "
     "non-control instruction (§8.1.8 p.8-9)"},
    {false, "ffreep st(1) (last-instruction pointers)*",
     "Emerald Rapids stores the address of FFREEP (DF C0+i) as FIP; DF C0+i \"behaves "
     "the same as FFREE ... with the addition of an x87 stack POP\" (SDM Vol.3B §25.18.9 "
     "p.25-15), a control instruction (Vol.1 §8.3.11 p.8-23) that leaves the pointers "
     "alone (§8.1.8)"},
    {true, "fxrstor [rdi] (FSW.ES = 0); fnstenv: the x87 pointers*",
     "Zen 4 loads FOP, FIP, FDP and the selectors from an FXRSTOR image with FSW.ES = 0 "
     "(the model's earlier AMD rule, from commit adb9d3c's checks on a Zen 4); \"FXRSTOR "
     "does not restore the x87 error pointers ... except when FXRSTOR sets FSW.ES=1 after "
     "recomputing it\" (APM Vol.5 FXRSTOR p.24)"},
    {true, "fxsave [rdi] with CR4.OSFXSR = 0*",
     "Zen 4 saves MXCSR with CR4.OSFXSR = 0; \"If the operating-system FXSAVE/FXRSTOR "
     "support bit (OSFXSR) of CR4 is cleared to 0, FXSAVE does not save the image of "
     "XMM0–XMM15 or MXCSR\" (APM Vol.5 FXSAVE p.26)"},
    {true, "fxrstor [rdi] with CR4.OSFXSR = 0*",
     "Zen 4 loads MXCSR with CR4.OSFXSR = 0; \"If the operating-system FXSAVE/FXRSTOR "
     "support bit (OSFXSR) of CR4 is cleared to 0, the saved image of XMM0–XMM15 and MXCSR "
     "is not loaded into the processor\" (APM Vol.5 FXRSTOR p.24)"},
};

bool host_is_amd() {
  u32 a, b, c, d;
  __get_cpuid(0, &a, &b, &c, &d);
  return b == 0x68747541;  // "Auth" of AuthenticAMD
}

bool matches(const char *pattern, const char *name) {
  if (*pattern == '*')
    return matches(pattern + 1, name) || (*name && matches(pattern, name + 1));
  if (!*pattern) return !*name;
  return *pattern == *name && matches(pattern + 1, name + 1);
}

}  // namespace

const KnownDeviation *known_deviation(const std::string &case_name) {
  static const bool amd = host_is_amd();
  for (const KnownDeviation &d : DEVIATIONS)
    if (d.amd == amd && matches(d.name, case_name.c_str()))
      return &d;
  return nullptr;
}
