#include "kvm-harness.h"

void add_misc_instruction_tests(std::vector<TestCase> &tests) {
  std::string cat;

  auto add = [&](const std::string &name, std::vector<u8> code, ArchState init,
                 u64 mask = FL_ALL) {
    tests.push_back({name, cat, std::move(code), init, mask});
  };

  auto add_mem = [&](const std::string &name, std::vector<u8> code, ArchState init,
                     u64 mask, std::vector<u8> data, size_t cmp_len) {
    tests.push_back({name, cat, std::move(code), init, mask, 0, false, std::move(data), cmp_len});
  };

  auto add_xmm = [&](const std::string &name, std::vector<u8> code, ArchState init,
                      u32 xmm_cmp) {
    tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
  };

  // =====================================================================
  // 26. SSE4.2 instructions
  // =====================================================================
  cat = "SSE4.2";

  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x0001020304050607, 0x08090A0B0C0D0E0F);

    // PCMPGTQ XMM0, XMM1: 66 0F 38 37 C1
    add_xmm("pcmpgtq xmm0,xmm1", {0x66, 0x0F, 0x38, 0x37, 0xC1}, s, 0x3);
  }

  // PCMPISTRI — implicit-length string compare
  {
    ArchState s;
    s.rflags = 0x2;
    // "Hello\0\0..." in xmm0
    s.xmm[0] = xmm_from_u64(0x0000006F6C6C6548, 0);
    // "Hello\0\0..." in xmm1
    s.xmm[1] = xmm_from_u64(0x0000006F6C6C6548, 0);

    // PCMPISTRI XMM0, XMM1, 0x08 (equal each, unsigned byte): 66 0F 3A 63 C1 08
    // Result in ECX (index of first mismatch/match)
    tests.push_back({"pcmpistri eq", cat, {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x08},
                      s, FL_ALL, 0x0, false});

    // Different strings
    s.xmm[1] = xmm_from_u64(0x0000006F6C6C6549, 0);  // "Iello\0..."
    tests.push_back({"pcmpistri ne", cat, {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x08},
                      s, FL_ALL, 0x0, false});
  }

  // PCMPISTRM — implicit-length string compare, result in XMM0
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0000006F6C6C6548, 0);
    s.xmm[1] = xmm_from_u64(0x0000006F6C6C6548, 0);

    // PCMPISTRM XMM0, XMM1, 0x08 (equal each): 66 0F 3A 62 C1 08
    add_xmm("pcmpistrm eq", {0x66, 0x0F, 0x3A, 0x62, 0xC1, 0x08}, s, 0x1);
  }

  // PCMPESTRI — explicit-length string compare (length in EAX/EDX)
  {
    ArchState s;
    s.rflags = 0x2;
    s.rax = 5;  // length of string in xmm0
    s.rdx = 5;  // length of string in xmm1
    s.xmm[0] = xmm_from_u64(0x0000006F6C6C6548, 0);
    s.xmm[1] = xmm_from_u64(0x0000006F6C6C6548, 0);

    // PCMPESTRI XMM0, XMM1, 0x08: 66 0F 3A 61 C1 08
    tests.push_back({"pcmpestri eq", cat, {0x66, 0x0F, 0x3A, 0x61, 0xC1, 0x08},
                      s, FL_ALL, 0x0, false});
  }

  // PCMPESTRM — explicit-length, result in XMM0
  {
    ArchState s;
    s.rflags = 0x2;
    s.rax = 5;
    s.rdx = 5;
    s.xmm[0] = xmm_from_u64(0x0000006F6C6C6548, 0);
    s.xmm[1] = xmm_from_u64(0x0000006F6C6C6548, 0);

    // PCMPESTRM XMM0, XMM1, 0x08: 66 0F 3A 60 C1 08
    add_xmm("pcmpestrm eq", {0x66, 0x0F, 0x3A, 0x60, 0xC1, 0x08}, s, 0x1);
  }

  // CRC32
  {
    ArchState s;
    s.rflags = 0x2;
    s.rax = 0;         // initial CRC
    s.rcx = 0x12345678;

    // CRC32 EAX, CL: F2 0F 38 F0 C1 (8-bit operand)
    tests.push_back({"crc32 eax,cl", cat, {0xF2, 0x0F, 0x38, 0xF0, 0xC1},
                      s, FL_ALL, 0x0, false});
    // CRC32 EAX, ECX: F2 0F 38 F1 C1 (32-bit operand)
    tests.push_back({"crc32 eax,ecx", cat, {0xF2, 0x0F, 0x38, 0xF1, 0xC1},
                      s, FL_ALL, 0x0, false});
  }

  // =====================================================================
  // 27. AES-NI & PCLMUL
  // =====================================================================
  cat = "AES";

  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // AESENC XMM0, XMM1: 66 0F 38 DC C1
    add_xmm("aesenc xmm0,xmm1", {0x66, 0x0F, 0x38, 0xDC, 0xC1}, s, 0x3);
    // AESENCLAST XMM0, XMM1: 66 0F 38 DD C1
    add_xmm("aesenclast xmm0,xmm1", {0x66, 0x0F, 0x38, 0xDD, 0xC1}, s, 0x3);
    // AESDEC XMM0, XMM1: 66 0F 38 DE C1
    add_xmm("aesdec xmm0,xmm1", {0x66, 0x0F, 0x38, 0xDE, 0xC1}, s, 0x3);
    // AESDECLAST XMM0, XMM1: 66 0F 38 DF C1
    add_xmm("aesdeclast xmm0,xmm1", {0x66, 0x0F, 0x38, 0xDF, 0xC1}, s, 0x3);
    // AESIMC XMM1, XMM0: 66 0F 38 DB C8
    add_xmm("aesimc xmm1,xmm0", {0x66, 0x0F, 0x38, 0xDB, 0xC8}, s, 0x2);
    // AESKEYGENASSIST XMM1, XMM0, 0x01: 66 0F 3A DF C8 01
    add_xmm("aeskeygenassist xmm1,xmm0,0x01", {0x66, 0x0F, 0x3A, 0xDF, 0xC8, 0x01}, s, 0x2);
    // PCLMULQDQ XMM0, XMM1, 0x00: 66 0F 3A 44 C1 00
    add_xmm("pclmulqdq xmm0,xmm1,0x00", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x00}, s, 0x3);
  }

  // =====================================================================
  // 28. SETcc — all condition codes
  // =====================================================================
  cat = "SETcc";
  {
    // Test with flags: CF=0, ZF=1, SF=1, OF=0, PF=1
    ArchState s;
    s.rax = 0xFFFFFFFFFFFFFFFF;  // pre-fill so we see zero-extension
    s.rflags = 0x2 | FL_ZF | FL_SF | FL_PF;

    // SETcc AL: 0F 9x C0 (mod=11, rm=rax)
    add("seto al",   {0x0F, 0x90, 0xC0}, s, FL_ALL);  // OF=0 → 0
    add("setno al",  {0x0F, 0x91, 0xC0}, s, FL_ALL);  // !OF → 1
    add("setb al",   {0x0F, 0x92, 0xC0}, s, FL_ALL);  // CF=0 → 0
    add("setnb al",  {0x0F, 0x93, 0xC0}, s, FL_ALL);  // !CF → 1
    add("sete al",   {0x0F, 0x94, 0xC0}, s, FL_ALL);  // ZF=1 → 1
    add("setne al",  {0x0F, 0x95, 0xC0}, s, FL_ALL);  // !ZF → 0
    add("setbe al",  {0x0F, 0x96, 0xC0}, s, FL_ALL);  // CF|ZF → 1
    add("setnbe al", {0x0F, 0x97, 0xC0}, s, FL_ALL);  // !CF&!ZF → 0
    add("sets al",   {0x0F, 0x98, 0xC0}, s, FL_ALL);  // SF=1 → 1
    add("setns al",  {0x0F, 0x99, 0xC0}, s, FL_ALL);  // !SF → 0
    add("setp al",   {0x0F, 0x9A, 0xC0}, s, FL_ALL);  // PF=1 → 1
    add("setnp al",  {0x0F, 0x9B, 0xC0}, s, FL_ALL);  // !PF → 0
    add("setl al",   {0x0F, 0x9C, 0xC0}, s, FL_ALL);  // SF!=OF → 1
    add("setnl al",  {0x0F, 0x9D, 0xC0}, s, FL_ALL);  // SF==OF → 0
    add("setle al",  {0x0F, 0x9E, 0xC0}, s, FL_ALL);  // ZF|(SF!=OF) → 1
    add("setnle al", {0x0F, 0x9F, 0xC0}, s, FL_ALL);  // !ZF&(SF==OF) → 0

    // Second set with different flags: CF=1, ZF=0, SF=0, OF=1
    s.rflags = 0x2 | FL_CF | FL_OF;
    add("seto al (OF=1)",  {0x0F, 0x90, 0xC0}, s, FL_ALL);
    add("setb al (CF=1)",  {0x0F, 0x92, 0xC0}, s, FL_ALL);
    add("setl al (SF=OF)", {0x0F, 0x9C, 0xC0}, s, FL_ALL);  // SF=0,OF=1 → 1
  }

  // =====================================================================
  // 29. Remaining CMOVcc variants
  // =====================================================================
  cat = "CMOVcc";
  {
    ArchState s;
    s.rax = 0x1111111111111111;
    s.rbx = 0x2222222222222222;
    s.rflags = 0x2 | FL_ZF | FL_SF | FL_PF;

    // CMOVcc RAX, RBX: 48 0F 4x C3
    add("cmovnb rax,rbx",  {0x48, 0x0F, 0x43, 0xC3}, s, FL_ALL);  // !CF → taken
    add("cmovne rax,rbx",  {0x48, 0x0F, 0x45, 0xC3}, s, FL_ALL);  // !ZF → not taken
    add("cmovbe rax,rbx",  {0x48, 0x0F, 0x46, 0xC3}, s, FL_ALL);  // CF|ZF → taken
    add("cmova rax,rbx",   {0x48, 0x0F, 0x47, 0xC3}, s, FL_ALL);  // !CF&!ZF → not taken
    add("cmovs rax,rbx",   {0x48, 0x0F, 0x48, 0xC3}, s, FL_ALL);  // SF → taken
    add("cmovns rax,rbx",  {0x48, 0x0F, 0x49, 0xC3}, s, FL_ALL);  // !SF → not taken
    add("cmovp rax,rbx",   {0x48, 0x0F, 0x4A, 0xC3}, s, FL_ALL);  // PF → taken
    add("cmovnp rax,rbx",  {0x48, 0x0F, 0x4B, 0xC3}, s, FL_ALL);  // !PF → not taken
    add("cmovge rax,rbx",  {0x48, 0x0F, 0x4D, 0xC3}, s, FL_ALL);  // SF==OF → not taken
    add("cmovle rax,rbx",  {0x48, 0x0F, 0x4E, 0xC3}, s, FL_ALL);  // ZF|(SF!=OF) → taken
  }

  // =====================================================================
  // 30. POP register
  // =====================================================================
  cat = "POP";
  {
    // PUSH RAX; POP RBX — tests POP reg
    ArchState s;
    s.rax = 0xDEADBEEFCAFEBABE;
    s.rbx = 0;
    s.rsp = 0x20000;
    s.rflags = 0x2;
    // PUSH RAX (50); POP RBX (5B)
    add("push rax; pop rbx", {0x50, 0x5B}, s, FL_ALL);

    // PUSH imm32; POP RAX — tests POP with sign-extended immediate
    s.rax = 0;
    // PUSH 0x42 (6A 42); POP RAX (58)
    add("push 0x42; pop rax", {0x6A, 0x42, 0x58}, s, FL_ALL);
  }

  // =====================================================================
  // 31. LEAVE
  // =====================================================================
  cat = "LEAVE";
  {
    // Set up: RSP=0x1FF00, RBP=0x1FFF0 with a value at [RBP]
    // LEAVE does: RSP = RBP; POP RBP
    ArchState s;
    s.rsp = 0x1FF00;
    s.rbp = 0x1FFF0;
    s.rflags = 0x2;
    // Use PUSH/LEAVE sequence: PUSH saves RBP on stack, then LEAVE restores it.
    // PUSH RBP (55); MOV RBP,RSP (48 89 E5); LEAVE (C9)
    add("push rbp; mov rbp,rsp; leave", {0x55, 0x48, 0x89, 0xE5, 0xC9}, s, FL_ALL);
  }

  // =====================================================================
  // 32. LOOP/LOOPcc
  // =====================================================================
  cat = "LOOP";
  {
    // LOOP with RCX=3: loop back to add 1 to RAX three times
    // Layout: INC RAX (48 FF C0) + LOOP -5 (E2 FB)
    ArchState s;
    s.rax = 0;
    s.rcx = 3;
    s.rflags = 0x2;
    // INC RAX; LOOP -5 (back to INC)
    add("loop rcx=3", {0x48, 0xFF, 0xC0, 0xE2, 0xFB}, s, FL_ALL);

    // LOOP with RCX=1: loop body executes once then falls through
    s.rcx = 1;
    add("loop rcx=1", {0x48, 0xFF, 0xC0, 0xE2, 0xFB}, s, FL_ALL);
  }

  // =====================================================================
  // 33. CMPXCHG8B/CMPXCHG16B
  // =====================================================================
  cat = "CMPXCHG8B";
  {
    // CMPXCHG8B [RDI]: 0F C7 0F (mod=00, reg=1, rm=rdi)
    // Compare EDX:EAX with m64. If equal, set ZF and store ECX:EBX.
    // Otherwise, load m64 into EDX:EAX.

    // Case 1: match (EDX:EAX == m64)
    ArchState s;
    s.rdi = DATA_ADDR;
    s.rax = 0x44332211;
    s.rdx = 0x88776655;
    s.rbx = 0xDDCCBBAA;
    s.rcx = 0x11223344;
    s.rflags = 0x2;
    u8 val[] = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88};
    add_mem("cmpxchg8b match", {0x0F, 0xC7, 0x0F}, s, FL_ALL,
            {val, val + 8}, 8);

    // Case 2: no match
    s.rax = 0x00000000;
    s.rdx = 0x00000000;
    add_mem("cmpxchg8b no match", {0x0F, 0xC7, 0x0F}, s, FL_ALL,
            {val, val + 8}, 8);
  }

  // =====================================================================
  // 34. MOVNTI
  // =====================================================================
  cat = "MOVNTI";
  {
    // MOVNTI [RDI], EAX: 0F C3 07
    ArchState s;
    s.rdi = DATA_ADDR;
    s.rax = 0xDEADBEEF12345678;
    s.rflags = 0x2;
    add_mem("movnti [rdi],eax", {0x0F, 0xC3, 0x07}, s, FL_ALL, {}, 4);

    // MOVNTI [RDI], RAX: 48 0F C3 07
    add_mem("movnti [rdi],rax", {0x48, 0x0F, 0xC3, 0x07}, s, FL_ALL, {}, 8);
  }

  // =====================================================================
  // 35. LDMXCSR/STMXCSR
  // =====================================================================
  cat = "LDMXCSR";
  {
    // STMXCSR [RDI]: 0F AE 1F (mod=00, reg=3, rm=rdi)
    ArchState s;
    s.rdi = DATA_ADDR;
    s.rflags = 0x2;
    add_mem("stmxcsr [rdi]", {0x0F, 0xAE, 0x1F}, s, FL_ALL, {}, 4);

    // LDMXCSR [RDI]: 0F AE 17 (mod=00, reg=2, rm=rdi)
    // Load MXCSR with default value 0x1F80
    u8 mxcsr[] = {0x80, 0x1F, 0x00, 0x00};
    add_mem("ldmxcsr [rdi]", {0x0F, 0xAE, 0x17}, s, FL_ALL,
            {mxcsr, mxcsr + 4}, 0);
  }

  // =====================================================================
  // 36. Fences (LFENCE/MFENCE/SFENCE) — these are NOPs for our model
  // =====================================================================
  cat = "Fences";
  {
    ArchState s;
    s.rax = 42;
    s.rflags = 0x2;
    // LFENCE: 0F AE E8
    add("lfence", {0x0F, 0xAE, 0xE8}, s, FL_ALL);
    // MFENCE: 0F AE F0
    add("mfence", {0x0F, 0xAE, 0xF0}, s, FL_ALL);
    // SFENCE: 0F AE F8
    add("sfence", {0x0F, 0xAE, 0xF8}, s, FL_ALL);
  }

  // =====================================================================
  // 37. SSE3 FP — MOVSLDUP, MOVSHDUP, MOVDDUP, HADDPS/PD, HSUBPS/PD,
  //     ADDSUBPS/PD
  // =====================================================================
  cat = "SSE3";
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // MOVSLDUP XMM2, XMM0: F3 0F 12 D0 — duplicates even-indexed floats
    add_xmm("movsldup xmm2,xmm0", {0xF3, 0x0F, 0x12, 0xD0}, s, 0x4);

    // MOVSHDUP XMM2, XMM0: F3 0F 16 D0 — duplicates odd-indexed floats
    add_xmm("movshdup xmm2,xmm0", {0xF3, 0x0F, 0x16, 0xD0}, s, 0x4);

    // HADDPS XMM0, XMM1: F2 0F 7C C1
    add_xmm("haddps xmm0,xmm1", {0xF2, 0x0F, 0x7C, 0xC1}, s, 0x3);

    // HSUBPS XMM0, XMM1: F2 0F 7D C1
    add_xmm("hsubps xmm0,xmm1", {0xF2, 0x0F, 0x7D, 0xC1}, s, 0x3);

    // ADDSUBPS XMM0, XMM1: F2 0F D0 C1
    add_xmm("addsubps xmm0,xmm1", {0xF2, 0x0F, 0xD0, 0xC1}, s, 0x3);
  }
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f64(1.5, 2.5);
    s.xmm[1] = xmm_from_f64(3.0, 4.0);

    // MOVDDUP XMM2, XMM0: F2 0F 12 D0 — duplicate low double
    add_xmm("movddup xmm2,xmm0", {0xF2, 0x0F, 0x12, 0xD0}, s, 0x4);

    // HADDPD XMM0, XMM1: 66 0F 7C C1
    add_xmm("haddpd xmm0,xmm1", {0x66, 0x0F, 0x7C, 0xC1}, s, 0x3);

    // HSUBPD XMM0, XMM1: 66 0F 7D C1
    add_xmm("hsubpd xmm0,xmm1", {0x66, 0x0F, 0x7D, 0xC1}, s, 0x3);

    // ADDSUBPD XMM0, XMM1: 66 0F D0 C1
    add_xmm("addsubpd xmm0,xmm1", {0x66, 0x0F, 0xD0, 0xC1}, s, 0x3);
  }

  // =====================================================================
  // 38. SSE4.1 remaining — BLENDVPS, BLENDVPD, PBLENDVB, PHMINPOSUW
  // =====================================================================
  cat = "SSE4.1v";
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    // XMM0 is implicit mask for BLENDVPS
    // Use a mask where high bit of each dword selects from xmm1
    // Mask in xmm0: float with sign bit set = select from src2
    // We need xmm0 as both dest and mask, so we use different regs:
    // BLENDVPS XMM2, XMM1, <XMM0>: 66 0F 38 14 D1
    s.xmm[2] = xmm_from_f32(100.0f, 200.0f, 300.0f, 400.0f);
    // Set mask: element 0 and 2 have sign bit set (negative)
    s.xmm[0] = xmm_from_f32(-1.0f, 1.0f, -1.0f, 1.0f);
    add_xmm("blendvps xmm2,xmm1,xmm0", {0x66, 0x0F, 0x38, 0x14, 0xD1}, s, 0x7);

    // BLENDVPD XMM2, XMM1, <XMM0>: 66 0F 38 15 D1
    s.xmm[0] = xmm_from_f64(-1.0, 1.0);  // mask: select low from src2
    s.xmm[1] = xmm_from_f64(10.0, 20.0);
    s.xmm[2] = xmm_from_f64(100.0, 200.0);
    add_xmm("blendvpd xmm2,xmm1,xmm0", {0x66, 0x0F, 0x38, 0x15, 0xD1}, s, 0x7);

    // PBLENDVB XMM2, XMM1, <XMM0>: 66 0F 38 10 D1
    s.xmm[0] = xmm_from_u64(0xFF00FF00FF00FF00, 0x00FF00FF00FF00FF);
    s.xmm[1] = xmm_from_u64(0x1111111111111111, 0x2222222222222222);
    s.xmm[2] = xmm_from_u64(0xAAAAAAAAAAAAAAAA, 0xBBBBBBBBBBBBBBBB);
    add_xmm("pblendvb xmm2,xmm1,xmm0", {0x66, 0x0F, 0x38, 0x10, 0xD1}, s, 0x7);
  }
  {
    // PHMINPOSUW XMM0, XMM1: 66 0F 38 41 C1
    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0005000300070001, 0x0009000200040008);
    add_xmm("phminposuw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x41, 0xC1}, s, 0x3);
  }

  // =====================================================================
  // 39. MOVLPS/MOVHPS memory forms
  // =====================================================================
  cat = "MOVxPS";
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);

    // MOVLPS [RDI], XMM0: 0F 13 07 — store low 64 bits to memory
    tests.push_back({"movlps [rdi],xmm0", cat, {0x0F, 0x13, 0x07},
                      s, FL_ALL, 0x0, false, {}, 8});

    // MOVHPS [RDI], XMM0: 0F 17 07 — store high 64 bits to memory
    tests.push_back({"movhps [rdi],xmm0", cat, {0x0F, 0x17, 0x07},
                      s, FL_ALL, 0x0, false, {}, 8});

    // MOVLPS XMM0, [RDI]: 0F 12 07 — load 64 bits into low half
    u8 data[] = {0x00, 0x00, 0x80, 0x41, 0x00, 0x00, 0x00, 0x42};  // 16.0f, 32.0f
    tests.push_back({"movlps xmm0,[rdi]", cat, {0x0F, 0x12, 0x07},
                      s, FL_ALL, 0x1, false, {data, data + 8}, 0});

    // MOVHPS XMM0, [RDI]: 0F 16 07 — load 64 bits into high half
    tests.push_back({"movhps xmm0,[rdi]", cat, {0x0F, 0x16, 0x07},
                      s, FL_ALL, 0x1, false, {data, data + 8}, 0});

    // MOVLPD [RDI], XMM0: 66 0F 13 07
    s.xmm[0] = xmm_from_f64(1.5, 2.5);
    tests.push_back({"movlpd [rdi],xmm0", cat, {0x66, 0x0F, 0x13, 0x07},
                      s, FL_ALL, 0x0, false, {}, 8});

    // MOVHPD [RDI], XMM0: 66 0F 17 07
    tests.push_back({"movhpd [rdi],xmm0", cat, {0x66, 0x0F, 0x17, 0x07},
                      s, FL_ALL, 0x0, false, {}, 8});
  }

  // =====================================================================
  // 40. String instructions with REP
  // =====================================================================
  cat = "String";
  {
    // REP STOSB: fill RCX bytes at [RDI] with AL
    ArchState s;
    s.rflags = 0x2;  // DF=0 (forward)
    s.rdi = DATA_ADDR;
    s.rax = 0x42;
    s.rcx = 8;
    tests.push_back({"rep stosb", cat, {0xF3, 0xAA},
                      s, FL_ALL, 0, false, {}, 8});

    // REP STOSD: fill RCX dwords at [RDI] with EAX
    s.rax = 0xDEADBEEF;
    s.rcx = 2;
    tests.push_back({"rep stosd", cat, {0xF3, 0xAB},
                      s, FL_ALL, 0, false, {}, 8});

    // REP STOSQ: fill RCX qwords at [RDI] with RAX
    s.rax = 0x123456789ABCDEF0;
    s.rcx = 1;
    tests.push_back({"rep stosq", cat, {0xF3, 0x48, 0xAB},
                      s, FL_ALL, 0, false, {}, 8});

    // REP MOVSB: copy RCX bytes from [RSI] to [RDI]
    s.rsi = DATA_ADDR;
    s.rdi = DATA_ADDR + 32;
    s.rcx = 8;
    u8 src_data[] = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88};
    // We put src data at DATA_ADDR, copy to DATA_ADDR+32
    tests.push_back({"rep movsb", cat, {0xF3, 0xA4},
                      s, FL_ALL, 0, false, {src_data, src_data + 8}, 40});

    // LODSQ: load [RSI] into RAX
    s.rsi = DATA_ADDR;
    s.rdi = 0;
    s.rcx = 0;
    s.rax = 0;
    tests.push_back({"lodsq", cat, {0x48, 0xAD},
                      s, FL_ALL, 0, false, {src_data, src_data + 8}, 0});

    // SCASB: compare AL with [RDI], set flags
    s.rdi = DATA_ADDR;
    s.rax = 0x11;
    tests.push_back({"scasb (match)", cat, {0xAE},
                      s, FL_ALL, 0, false, {src_data, src_data + 8}, 0});

    s.rax = 0xFF;
    tests.push_back({"scasb (no match)", cat, {0xAE},
                      s, FL_ALL, 0, false, {src_data, src_data + 8}, 0});

    // CMPSB: compare [RSI] with [RDI]
    s.rsi = DATA_ADDR;
    s.rdi = DATA_ADDR;
    s.rax = 0;
    tests.push_back({"cmpsb (equal)", cat, {0xA6},
                      s, FL_ALL, 0, false, {src_data, src_data + 8}, 0});
  }

  // =====================================================================
  // 41. EMMS
  // =====================================================================
  cat = "EMMS";
  {
    ArchState s;
    s.rflags = 0x2;
    // EMMS: 0F 77
    add("emms", {0x0F, 0x77}, s, FL_ALL);
  }

  // =====================================================================
  // 42. MOVNTDQA (SSE4.1 streaming load)
  // =====================================================================
  cat = "SSE4.1v";
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    // 16 bytes of test data (aligned)
    u8 data[] = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10};
    // MOVNTDQA XMM0, [RDI]: 66 0F 38 2A 07
    tests.push_back({"movntdqa xmm0,[rdi]", cat, {0x66, 0x0F, 0x38, 0x2A, 0x07},
                      s, FL_ALL, 0x1, false, {data, data + 16}, 0});
  }

  // =====================================================================
  // 43. SHA extensions
  // =====================================================================
  cat = "SHA";

  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x6A09E667BB67AE85, 0x3C6EF372A54FF53A);
    s.xmm[1] = xmm_from_u64(0x510E527F9B05688C, 0x1F83D9AB5BE0CD19);
    s.xmm[2] = xmm_from_u64(0x428A2F9871374491, 0xB5C0FBCFE9B5DBA5);

    // SHA1RNDS4 XMM0, XMM1, 0: NP 0F 3A CC C1 00
    add_xmm("sha1rnds4 xmm0,xmm1,0", {0x0F, 0x3A, 0xCC, 0xC1, 0x00}, s, 0x3);
    // SHA1RNDS4 XMM0, XMM1, 1: NP 0F 3A CC C1 01
    add_xmm("sha1rnds4 xmm0,xmm1,1", {0x0F, 0x3A, 0xCC, 0xC1, 0x01}, s, 0x3);
    // SHA1RNDS4 XMM0, XMM1, 2: NP 0F 3A CC C1 02
    add_xmm("sha1rnds4 xmm0,xmm1,2", {0x0F, 0x3A, 0xCC, 0xC1, 0x02}, s, 0x3);
    // SHA1RNDS4 XMM0, XMM1, 3: NP 0F 3A CC C1 03
    add_xmm("sha1rnds4 xmm0,xmm1,3", {0x0F, 0x3A, 0xCC, 0xC1, 0x03}, s, 0x3);

    // SHA1NEXTE XMM0, XMM1: NP 0F 38 C8 C1
    add_xmm("sha1nexte xmm0,xmm1", {0x0F, 0x38, 0xC8, 0xC1}, s, 0x3);

    // SHA1MSG1 XMM0, XMM1: NP 0F 38 C9 C1
    add_xmm("sha1msg1 xmm0,xmm1", {0x0F, 0x38, 0xC9, 0xC1}, s, 0x3);

    // SHA1MSG2 XMM0, XMM1: NP 0F 38 CA C1
    add_xmm("sha1msg2 xmm0,xmm1", {0x0F, 0x38, 0xCA, 0xC1}, s, 0x3);

    // SHA256RNDS2 XMM0, XMM1, <XMM0>: NP 0F 38 CB C1
    // Implicit operand is XMM0 (low 64 bits)
    add_xmm("sha256rnds2 xmm0,xmm1", {0x0F, 0x38, 0xCB, 0xC1}, s, 0x3);

    // SHA256RNDS2 with different XMM0 content: use XMM2 as dest to isolate
    // SHA256RNDS2 XMM2, XMM1, <XMM0>: NP 0F 38 CB D1
    add_xmm("sha256rnds2 xmm2,xmm1,<xmm0>", {0x0F, 0x38, 0xCB, 0xD1}, s, 0x7);

    // SHA256MSG1 XMM0, XMM1: NP 0F 38 CC C1
    add_xmm("sha256msg1 xmm0,xmm1", {0x0F, 0x38, 0xCC, 0xC1}, s, 0x3);

    // SHA256MSG2 XMM0, XMM1: NP 0F 38 CD C1
    add_xmm("sha256msg2 xmm0,xmm1", {0x0F, 0x38, 0xCD, 0xC1}, s, 0x3);
  }
}

