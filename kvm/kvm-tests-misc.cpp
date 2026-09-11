#include "kvm-harness.h"
#include <cpuid.h>

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

    // MOVDIRI/MOVDIR64B: only test if the host CPU supports them
    // (CPUID leaf 7, ECX bit 27 = MOVDIRI, bit 28 = MOVDIR64B)
    u32 eax7, ebx7, ecx7, edx7;
    __cpuid_count(7, 0, eax7, ebx7, ecx7, edx7);

    if (ecx7 & (1u << 27)) {
      // MOVDIRI [RDI], EAX: NP 0F 38 F9 07
      add_mem("movdiri [rdi],eax", {0x0F, 0x38, 0xF9, 0x07}, s, FL_ALL, {}, 4);

      // MOVDIRI [RDI], RAX: NP REX.W 0F 38 F9 07
      add_mem("movdiri [rdi],rax", {0x48, 0x0F, 0x38, 0xF9, 0x07}, s, FL_ALL, {}, 8);

      // MOVDIRI [RDI], EBX: NP 0F 38 F9 1F
      s.rbx = 0xCAFEBABE;
      add_mem("movdiri [rdi],ebx", {0x0F, 0x38, 0xF9, 0x1F}, s, FL_ALL, {}, 4);

      // MOVDIRI [RDI], R8: REX.WR 0F 38 F9 07
      s.r8 = 0x0102030405060708;
      add_mem("movdiri [rdi],r8", {0x4C, 0x0F, 0x38, 0xF9, 0x07}, s, FL_ALL, {}, 8);
    }

    if (ecx7 & (1u << 28)) {
      // MOVDIR64B RAX, [RDI]: 66 0F 38 F8 07
      // reg=RAX holds destination address, r/m=[RDI] is source
      ArchState s2;
      s2.rflags = 0x2;
      s2.rdi = DATA_ADDR;         // source
      s2.rax = DATA_ADDR + 0x80;  // destination (64-byte aligned)

      std::vector<u8> data(256, 0);
      for (int i = 0; i < 64; i++)
        data[i] = (u8)(i + 1);

      tests.push_back({"movdir64b rax,[rdi]", cat, {0x66, 0x0F, 0x38, 0xF8, 0x07},
                        s2, FL_ALL, 0, false, data, 256});
    }
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

    // EMMS must set x87 tag word to all empty (0xFFFF).
    // Test: MOVD MM0,EAX (marks tags valid), then EMMS, then
    // FXSAVE [RDI] to capture state. Compare the saved area —
    // the abridged tag word at offset 4 should be 0xFF (all empty).
    // FXSAVE also stores MXCSR_MASK at bytes 28-31, which the SDM leaves
    // implementation specific: Intel parts report 0xFFFF, AMD parts
    // 0x2FFFF (bit 17 is AMD's misaligned-SSE mode).  Zero the field so
    // the image comparison does not depend on the host vendor.
    {
      std::vector<u8> init_data(512, 0);
      tests.push_back({"emms clears tags", cat,
        {0x0F, 0x6E, 0xC0,        // MOVD MM0, EAX (sets tag valid)
         0x0F, 0x77,              // EMMS (should set all tags empty)
         0x0F, 0xAE, 0x07,        // FXSAVE [RDI]
         0xC7, 0x47, 0x1C, 0x00, 0x00, 0x00, 0x00},  // MOV dword [RDI+28], 0
        {.rax = 0x42, .rdi = DATA_ADDR, .rflags = 0x2},
        FL_NONE, 0, false, init_data, 512});
    }
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
  // 43. GFNI (Galois Field New Instructions)
  // =====================================================================
  cat = "GFNI";

  {
    ArchState s;
    s.rflags = 0x2;
    // Use an 8x8 identity-like matrix in XMM1 and some data in XMM0
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x8040201008040201, 0x8040201008040201);

    // GF2P8MULB XMM0, XMM1: 66 0F 38 CF C1
    add_xmm("gf2p8mulb xmm0,xmm1", {0x66, 0x0F, 0x38, 0xCF, 0xC1}, s, 0x3);

    // GF2P8AFFINEQB XMM0, XMM1, 0x00: 66 0F 3A CE C1 00
    add_xmm("gf2p8affineqb xmm0,xmm1,0x00", {0x66, 0x0F, 0x3A, 0xCE, 0xC1, 0x00}, s, 0x3);
    // GF2P8AFFINEQB XMM0, XMM1, 0x55: 66 0F 3A CE C1 55
    add_xmm("gf2p8affineqb xmm0,xmm1,0x55", {0x66, 0x0F, 0x3A, 0xCE, 0xC1, 0x55}, s, 0x3);

    // GF2P8AFFINEINVQB XMM0, XMM1, 0x00: 66 0F 3A CF C1 00
    add_xmm("gf2p8affineinvqb xmm0,xmm1,0x00", {0x66, 0x0F, 0x3A, 0xCF, 0xC1, 0x00}, s, 0x3);
    // GF2P8AFFINEINVQB XMM0, XMM1, 0xAA: 66 0F 3A CF C1 AA
    add_xmm("gf2p8affineinvqb xmm0,xmm1,0xAA", {0x66, 0x0F, 0x3A, 0xCF, 0xC1, 0xAA}, s, 0x3);
  }

  // =====================================================================
  // 44. SHA extensions
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

  // =====================================================================
  // 45. FSGSBASE — RDFSBASE/WRFSBASE/RDGSBASE/WRGSBASE
  //     Requires CR4.FSGSBASE (bit 16) = 1
  // =====================================================================
  cat = "FSGSBASE";
  {
    // WRFSBASE RBX; RDFSBASE RAX — 64-bit round-trip
    // F3 REX.W 0F AE /2 = WRFSBASE r64 (F3 48 0F AE D3: mod=11, reg=010, rm=011=RBX)
    // F3 REX.W 0F AE /0 = RDFSBASE r64 (F3 48 0F AE C0: mod=11, reg=000, rm=000=RAX)
    {
      ArchState s;
      s.rflags = 0x2;
      s.rbx = 0x00007F0012345678;  // canonical user-space address
      add("rdfsbase64 round-trip",
          {0xF3, 0x48, 0x0F, 0xAE, 0xD3,   // WRFSBASE RBX
           0xF3, 0x48, 0x0F, 0xAE, 0xC0},   // RDFSBASE RAX
          s, FL_NONE);
    }

    // WRFSBASE EBX; RDFSBASE EAX — 32-bit round-trip (zero-extends)
    // F3 0F AE /2 = WRFSBASE r32 (F3 0F AE D3)
    // F3 0F AE /0 = RDFSBASE r32 (F3 0F AE C0)
    {
      ArchState s;
      s.rflags = 0x2;
      s.rbx = 0xDEADBEEF;  // only low 32 bits used
      add("rdfsbase32 round-trip",
          {0xF3, 0x0F, 0xAE, 0xD3,   // WRFSBASE EBX
           0xF3, 0x0F, 0xAE, 0xC0},   // RDFSBASE EAX
          s, FL_NONE);
    }

    // WRGSBASE RBX; RDGSBASE RAX — 64-bit GS round-trip
    // F3 REX.W 0F AE /3 = WRGSBASE r64 (F3 48 0F AE DB: reg=011, rm=011=RBX)
    // F3 REX.W 0F AE /1 = RDGSBASE r64 (F3 48 0F AE C8: reg=001, rm=000=RAX)
    {
      ArchState s;
      s.rflags = 0x2;
      s.rbx = 0x00007FFF87654321;
      add("rdgsbase64 round-trip",
          {0xF3, 0x48, 0x0F, 0xAE, 0xDB,   // WRGSBASE RBX
           0xF3, 0x48, 0x0F, 0xAE, 0xC8},   // RDGSBASE RAX
          s, FL_NONE);
    }

    // WRGSBASE EBX; RDGSBASE EAX — 32-bit GS round-trip
    {
      ArchState s;
      s.rflags = 0x2;
      s.rbx = 0xCAFEBABE;
      add("rdgsbase32 round-trip",
          {0xF3, 0x0F, 0xAE, 0xDB,   // WRGSBASE EBX
           0xF3, 0x0F, 0xAE, 0xC8},   // RDGSBASE EAX
          s, FL_NONE);
    }
  }

  // =====================================================================
  // XSAVE / XRSTOR
  //   XSAVE [RDI]: 0F AE /4 -> ModRM 00 100 111 = 0x27
  //   XRSTOR [RDI]: 0F AE /5 -> ModRM 00 101 111 = 0x2F
  //   EDX:EAX = component mask (bit 0 = x87, bit 1 = SSE)
  // =====================================================================
  {
    cat = "XSAVE/XRSTOR";

    // Round-trip: XSAVE then PXOR to clear XMMs, then XRSTOR to restore.
    // Verifies XMM0 and XMM1 survive the round-trip.
    {
      ArchState s;
      s.rax = 3;
      s.rdi = DATA_ADDR;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(0x1234567890ABCDEF, 0xFEDCBA0987654321);
      s.xmm[1] = xmm_from_u64(0xAAAABBBBCCCCDDDD, 0xEEEEFFFF00001111);
      std::vector<u8> code = {
        0x0F, 0xAE, 0x27,             // XSAVE [RDI]
        0x66, 0x0F, 0xEF, 0xC0,       // PXOR XMM0, XMM0
        0x66, 0x0F, 0xEF, 0xC9,       // PXOR XMM1, XMM1
        0x0F, 0xAE, 0x2F,             // XRSTOR [RDI]
      };
      TestCase tc;
      tc.name = "xsave+xrstor round-trip (mask=3)";
      tc.category = cat;
      tc.code = std::move(code);
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x3;
      tc.cmp_mxcsr = true;
      tc.init_data = std::vector<u8>(576, 0);
      tests.push_back(std::move(tc));
    }

    // Round-trip with mask=2 (SSE only): XMM regs should survive.
    {
      ArchState s;
      s.rax = 2;
      s.rdi = DATA_ADDR;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(0xCAFEBABE12345678, 0x9876543210FEDCBA);
      s.xmm[5] = xmm_from_u64(0xDEADBEEFDEADBEEF, 0xFACEFACEFACEFACE);
      std::vector<u8> code = {
        0x0F, 0xAE, 0x27,             // XSAVE [RDI]
        0x66, 0x0F, 0xEF, 0xC0,       // PXOR XMM0, XMM0
        0x66, 0x0F, 0xEF, 0xED,       // PXOR XMM5, XMM5
        0x0F, 0xAE, 0x2F,             // XRSTOR [RDI]
      };
      TestCase tc;
      tc.name = "xsave+xrstor round-trip (mask=2, SSE only)";
      tc.category = cat;
      tc.code = std::move(code);
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = (1 << 0) | (1 << 5);
      tc.cmp_mxcsr = true;
      tc.init_data = std::vector<u8>(576, 0);
      tests.push_back(std::move(tc));
    }

    // XRSTOR with XSTATE_BV=3: load XMM0 from pre-built XSAVE area.
    {
      ArchState s;
      s.rax = 3;
      s.rdi = DATA_ADDR;
      s.rflags = 0x2;
      std::vector<u8> init_data(576, 0);
      // FCW = 0x037F
      init_data[0] = 0x7F;
      init_data[1] = 0x03;
      // MXCSR = 0x1F80
      init_data[0x18] = 0x80;
      init_data[0x19] = 0x1F;
      // MXCSR_MASK = 0x0002FFFF
      init_data[0x1C] = 0xFF;
      init_data[0x1D] = 0xFF;
      init_data[0x1E] = 0x02;
      // XMM0 at offset 0xA0
      u64 xmm0_lo = 0xCAFEBABE12345678;
      u64 xmm0_hi = 0x9876543210FEDCBA;
      memcpy(init_data.data() + 0xA0, &xmm0_lo, 8);
      memcpy(init_data.data() + 0xA8, &xmm0_hi, 8);
      // XSTATE_BV = 3
      init_data[0x200] = 3;
      TestCase tc;
      tc.name = "xrstor restore (xstate_bv=3)";
      tc.category = cat;
      tc.code = {0x0F, 0xAE, 0x2F};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x1;
      tc.cmp_mxcsr = true;
      tc.init_data = std::move(init_data);
      tests.push_back(std::move(tc));
    }

    // XRSTOR with XSTATE_BV=0: SSE init path should zero XMM regs.
    {
      ArchState s;
      s.rax = 3;
      s.rdi = DATA_ADDR;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(0xDEADBEEFDEADBEEF, 0xDEADBEEFDEADBEEF);
      std::vector<u8> init_data(576, 0);
      // XSTATE_BV = 0 (all init)
      TestCase tc;
      tc.name = "xrstor init (xstate_bv=0)";
      tc.category = cat;
      tc.code = {0x0F, 0xAE, 0x2F};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x1;  // XMM0 should become zero
      tc.init_data = std::move(init_data);
      tests.push_back(std::move(tc));
    }

    // XRSTOR with XSTATE_BV=1 (x87 only): SSE init, XMMs zeroed.
    {
      ArchState s;
      s.rax = 3;
      s.rdi = DATA_ADDR;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(0x1111111111111111, 0x2222222222222222);
      std::vector<u8> init_data(576, 0);
      init_data[0] = 0x7F;
      init_data[1] = 0x03;
      init_data[0x18] = 0x80;
      init_data[0x19] = 0x1F;
      init_data[0x1C] = 0xFF;
      init_data[0x1D] = 0xFF;
      init_data[0x1E] = 0x02;
      // XSTATE_BV = 1 (x87 valid, SSE not)
      init_data[0x200] = 1;
      TestCase tc;
      tc.name = "xrstor partial (xstate_bv=1, SSE init)";
      tc.category = cat;
      tc.code = {0x0F, 0xAE, 0x2F};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x1;  // XMM0 should become zero
      tc.init_data = std::move(init_data);
      tests.push_back(std::move(tc));
    }

    // Round-trip with high XMM registers (XMM8-XMM15, needs REX).
    {
      ArchState s;
      s.rax = 3;
      s.rdi = DATA_ADDR;
      s.rflags = 0x2;
      s.xmm[8] = xmm_from_u64(0x8888888888888888, 0x9999999999999999);
      s.xmm[15] = xmm_from_u64(0xAAAAAAAAAAAAAAAA, 0xBBBBBBBBBBBBBBBB);
      // PXOR XMM8,XMM8: 66 45 0F EF C0
      // PXOR XMM15,XMM15: 66 45 0F EF FF
      std::vector<u8> code = {
        0x0F, 0xAE, 0x27,                   // XSAVE [RDI]
        0x66, 0x45, 0x0F, 0xEF, 0xC0,       // PXOR XMM8, XMM8
        0x66, 0x45, 0x0F, 0xEF, 0xFF,       // PXOR XMM15, XMM15
        0x0F, 0xAE, 0x2F,                   // XRSTOR [RDI]
      };
      TestCase tc;
      tc.name = "xsave+xrstor round-trip (high XMM regs)";
      tc.category = cat;
      tc.code = std::move(code);
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = (1 << 8) | (1 << 15);
      tc.init_data = std::vector<u8>(576, 0);
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // Tests moved from kvm-tests-vex.cpp (non-AVX)
  // =====================================================================

  // =====================================================================
  // BMI2 — bit manipulation instructions (GPR tests)
  // =====================================================================
  cat = "BMI2";
  {
    // BZHI eax, ecx, edx — zero high bits in ecx starting at bit position in edx
    // VEX.NDS.LZ.0F38.W0 F5 /r — C4 E2 68 F5 C1
    // reg=0(eax dest), rm=1(ecx src), vvvv=~2=1101(edx index)
    // byte2: W=0,vvvv=1101,L=0,pp=00 → 0x68
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0xDEADBEEF12345678;
      s.rdx = 16;
      // 32-bit: eax = ecx[31:0] with bits above 16 cleared = 0x5678
      tests.push_back({"bzhi eax,ecx,edx bit16", cat,
                       {0xC4, 0xE2, 0x68, 0xF5, 0xC1}, s,
                       FL_ZF | FL_SF | FL_CF | FL_OF});
    }
    // BZHI with zero index → result=0, ZF=1
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0xFFFFFFFF;
      s.rdx = 0;
      tests.push_back({"bzhi eax,ecx,edx bit0", cat,
                       {0xC4, 0xE2, 0x68, 0xF5, 0xC1}, s,
                       FL_ZF | FL_SF | FL_CF | FL_OF});
    }
    // BZHI 64-bit: rax, rcx, rdx
    // W=1: byte2 = 0b1_1101_0_00 = 0xE8
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0xFFFFFFFFFFFFFFFF;
      s.rdx = 32;
      tests.push_back({"bzhi rax,rcx,rdx bit32", cat,
                       {0xC4, 0xE2, 0xE8, 0xF5, 0xC1}, s,
                       FL_ZF | FL_SF | FL_CF | FL_OF});
    }
    // BZHI with index >= operand size → CF=1, result unchanged
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x12345678;
      s.rdx = 40;  // >= 32 for W0
      tests.push_back({"bzhi eax,ecx,edx overflow", cat,
                       {0xC4, 0xE2, 0x68, 0xF5, 0xC1}, s,
                       FL_ZF | FL_SF | FL_CF | FL_OF});
    }

    // PDEP eax, ecx, edx — parallel bit deposit
    // VEX.NDS.LZ.F2.0F38.W0 F5 /r — C4 E2 73 F5 C2
    // reg=0(eax dest), vvvv=~1=1110(ecx src), rm=2(edx mask)
    // byte2: W=0,vvvv=1110,L=0,pp=11(F2) → 0x73
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x000000FF;  // source bits
      s.rdx = 0x55555555;  // mask: every other bit
      tests.push_back({"pdep eax,ecx,edx", cat,
                       {0xC4, 0xE2, 0x73, 0xF5, 0xC2}, s, FL_NONE});
    }
    // PDEP 64-bit
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x00000000000000FF;
      s.rdx = 0x5555555555555555;
      // W=1: byte2 = 0b1_1110_0_11 = 0xF3
      tests.push_back({"pdep rax,rcx,rdx 64", cat,
                       {0xC4, 0xE2, 0xF3, 0xF5, 0xC2}, s, FL_NONE});
    }

    // PEXT eax, ecx, edx — parallel bit extract
    // VEX.NDS.LZ.F3.0F38.W0 F5 /r — C4 E2 72 F5 C2
    // byte2: W=0,vvvv=1110,L=0,pp=10(F3) → 0x72
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0xAAAAAAAA;  // source
      s.rdx = 0x55555555;  // mask: every other bit
      tests.push_back({"pext eax,ecx,edx", cat,
                       {0xC4, 0xE2, 0x72, 0xF5, 0xC2}, s, FL_NONE});
    }
    // PEXT 64-bit
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0xAAAAAAAAAAAAAAAA;
      s.rdx = 0x5555555555555555;
      // W=1: byte2 = 0b1_1110_0_10 = 0xF2
      tests.push_back({"pext rax,rcx,rdx 64", cat,
                       {0xC4, 0xE2, 0xF2, 0xF5, 0xC2}, s, FL_NONE});
    }

    // MULX ebx, eax, ecx — unsigned multiply EDX * ECX → EBX:EAX
    // VEX.NDD.LZ.F2.0F38.W0 F6 /r — C4 E2 7B F6 D9
    // reg=3(ebx hi), vvvv=~0=1111(eax lo), rm=1(ecx src)
    // byte2: W=0,vvvv=1111,L=0,pp=11(F2) → 0x7B
    // ModRM: mod=11, reg=011, rm=001 → 0xD9
    // Implicit src1 = EDX
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdx = 100;
      s.rcx = 200;
      tests.push_back({"mulx ebx,eax,ecx 100*200", cat,
                       {0xC4, 0xE2, 0x7B, 0xF6, 0xD9}, s, FL_NONE});
    }
    // MULX with large values to produce high part
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdx = 0xFFFFFFFF;
      s.rcx = 0xFFFFFFFF;
      tests.push_back({"mulx ebx,eax,ecx max32", cat,
                       {0xC4, 0xE2, 0x7B, 0xF6, 0xD9}, s, FL_NONE});
    }
    // MULX 64-bit: W=1, byte2 = 0b1_1111_0_11 = 0xFB
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdx = 0x100000000;
      s.rcx = 0x100000000;
      tests.push_back({"mulx rbx,rax,rcx 64", cat,
                       {0xC4, 0xE2, 0xFB, 0xF6, 0xD9}, s, FL_NONE});
    }

    // SARX eax, ecx, edx — arithmetic shift right without flags
    // VEX.NDS.LZ.F3.0F38.W0 F7 /r — C4 E2 6A F7 C1
    // reg=0(eax dest), rm=1(ecx src), vvvv=~2=1101(edx count)
    // byte2: W=0,vvvv=1101,L=0,pp=10(F3) → 0x6A
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x80000000;  // negative when treated as signed 32-bit
      s.rdx = 4;
      tests.push_back({"sarx eax,ecx,edx", cat,
                       {0xC4, 0xE2, 0x6A, 0xF7, 0xC1}, s, FL_NONE});
    }

    // SHLX eax, ecx, edx — logical shift left without flags
    // VEX.NDS.LZ.66.0F38.W0 F7 /r — C4 E2 69 F7 C1
    // byte2: W=0,vvvv=1101,L=0,pp=01(66) → 0x69
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x12345678;
      s.rdx = 8;
      tests.push_back({"shlx eax,ecx,edx", cat,
                       {0xC4, 0xE2, 0x69, 0xF7, 0xC1}, s, FL_NONE});
    }

    // SHRX eax, ecx, edx — logical shift right without flags
    // VEX.NDS.LZ.F2.0F38.W0 F7 /r — C4 E2 6B F7 C1
    // byte2: W=0,vvvv=1101,L=0,pp=11(F2) → 0x6B
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x12345678;
      s.rdx = 8;
      tests.push_back({"shrx eax,ecx,edx", cat,
                       {0xC4, 0xE2, 0x6B, 0xF7, 0xC1}, s, FL_NONE});
    }

    // SARX 64-bit: W=1, byte2 = 0b1_1101_0_10 = 0xEA
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x8000000000000000;
      s.rdx = 16;
      tests.push_back({"sarx rax,rcx,rdx 64", cat,
                       {0xC4, 0xE2, 0xEA, 0xF7, 0xC1}, s, FL_NONE});
    }

    // SHLX 64-bit: W=1, byte2 = 0b1_1101_0_01 = 0xE9
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x0000000000000001;
      s.rdx = 63;
      tests.push_back({"shlx rax,rcx,rdx 64", cat,
                       {0xC4, 0xE2, 0xE9, 0xF7, 0xC1}, s, FL_NONE});
    }

    // SHRX 64-bit: W=1, byte2 = 0b1_1101_0_11 = 0xEB
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x8000000000000000;
      s.rdx = 32;
      tests.push_back({"shrx rax,rcx,rdx 64", cat,
                       {0xC4, 0xE2, 0xEB, 0xF7, 0xC1}, s, FL_NONE});
    }

    // RORX eax, ecx, 4 — rotate right without flags
    // VEX.LZ.F2.0F3A.W0 F0 /r ib — C4 E3 7B F0 C1 04
    // byte1=0xE3 (mmmmm=00011=0F3A), byte2: W=0,vvvv=1111,L=0,pp=11(F2) → 0x7B
    // reg=0(eax dest), rm=1(ecx src), imm=4
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x12345678;
      tests.push_back({"rorx eax,ecx,4", cat,
                       {0xC4, 0xE3, 0x7B, 0xF0, 0xC1, 0x04}, s, FL_NONE});
    }
    // RORX 64-bit: W=1, byte2 = 0b1_1111_0_11 = 0xFB
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x123456789ABCDEF0;
      tests.push_back({"rorx rax,rcx,8 64", cat,
                       {0xC4, 0xE3, 0xFB, 0xF0, 0xC1, 0x08}, s, FL_NONE});
    }
  }
  // =====================================================================
  // Indirect JMP/CALL — register and memory operands
  // =====================================================================
  cat = "Indirect JMP";
  {
    // JMP rax: FF E0 — jump to rax (CODE_ADDR + 2 = right after the JMP)
    {
      TestCase tc;
      tc.name = "jmp rax";
      tc.category = cat;
      tc.code = {0xFF, 0xE0};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rax = CODE_ADDR + 2;  // target = after JMP
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // JMP rax skipping bytes: FF E0 CC CC (jump over INT3s)
    {
      TestCase tc;
      tc.name = "jmp rax (skip INT3)";
      tc.category = cat;
      tc.code = {0xFF, 0xE0, 0xCC, 0xCC};  // JMP rax, INT3, INT3
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rax = CODE_ADDR + 4;  // skip the INT3 bytes
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // JMP [rdi]: FF 27 — indirect through memory
    {
      TestCase tc;
      tc.name = "jmp [rdi]";
      tc.category = cat;
      tc.code = {0xFF, 0x27, 0xCC, 0xCC};  // JMP [rdi], INT3, INT3
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      // [DATA_ADDR] = CODE_ADDR + 4 (skip JMP and INT3s)
      u64 target = CODE_ADDR + 4;
      tc.init_data.resize(8);
      memcpy(tc.init_data.data(), &target, 8);
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // CALL rax: FF D0 — push return addr, jump to rax
    // target = CODE_ADDR + 2 (right after CALL), so RET addr = CODE_ADDR+2
    // RSP should decrease by 8
    {
      TestCase tc;
      tc.name = "call rax";
      tc.category = cat;
      tc.code = {0xFF, 0xD0};  // CALL rax
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rax = CODE_ADDR + 2;  // target = right after CALL (then HLT)
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // CALL [rdi]: FF 17 — indirect call through memory
    {
      TestCase tc;
      tc.name = "call [rdi]";
      tc.category = cat;
      tc.code = {0xFF, 0x17, 0xCC, 0xCC};  // CALL [rdi], INT3, INT3
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      u64 target2 = CODE_ADDR + 4;
      tc.init_data.resize(8);
      memcpy(tc.init_data.data(), &target2, 8);
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // CALL rax + RET: call to a RET instruction, verify round-trip.
    // Layout: CALL rax; NOP; NOP; NOP; HLT; RET
    // CALL pushes CODE_ADDR+2, jumps to CODE_ADDR+6 (RET).
    // RET pops CODE_ADDR+2, jumps there. NOPs then HLT.
    {
      TestCase tc;
      tc.name = "call rax + ret";
      tc.category = cat;
      tc.code = {0xFF, 0xD0,           // 0: CALL rax (2 bytes)
                 0x90, 0x90, 0x90,     // 2: NOP NOP NOP (landing pad)
                 0xF4,                 // 5: HLT (stop after return)
                 0xC3};                // 6: RET (target of CALL)
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rax = CODE_ADDR + 6;  // point to the RET
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // FP conversion edge cases
  // =====================================================================
  cat = "FP conv edge";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp = 0x1) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    ArchState s;
    s.rflags = 0x2;
    s.mxcsr = 0x1F80;  // default MXCSR

    // CVTPS2PD xmm0, xmm1: 0F 5A C1 (convert 2 floats → 2 doubles)
    // Denormal float: 0x00000001 = smallest subnormal
    s.xmm[1] = xmm_from_u32(0x00000001, 0x80000001, 0, 0);  // +denorm, -denorm
    add_xmm("cvtps2pd denormals", {0x0F, 0x5A, 0xC1}, s);

    // CVTPS2PD with NaN: 0x7FC00000 = quiet NaN, 0x7F800001 = signaling NaN
    s.xmm[1] = xmm_from_u32(0x7FC00000, 0x7F800001, 0, 0);
    add_xmm("cvtps2pd NaN", {0x0F, 0x5A, 0xC1}, s);

    // CVTPS2PD with Inf: 0x7F800000 = +Inf, 0xFF800000 = -Inf
    s.xmm[1] = xmm_from_u32(0x7F800000, 0xFF800000, 0, 0);
    add_xmm("cvtps2pd Inf", {0x0F, 0x5A, 0xC1}, s);

    // CVTPS2PD with -0: 0x80000000
    s.xmm[1] = xmm_from_u32(0x80000000, 0x00000000, 0, 0);  // -0, +0
    add_xmm("cvtps2pd neg zero", {0x0F, 0x5A, 0xC1}, s);

    // CVTPD2PS xmm0, xmm1: 66 0F 5A C1 (convert 2 doubles → 2 floats)
    // Large double that loses precision: 1.0 + 2^-24 (just beyond float precision)
    {
      double d1 = 1.0 + ldexp(1.0, -24);  // 1.0000000596... rounds to 1.0f
      double d2 = 1.0e38;                   // large but representable as float
      u64 b1, b2;
      memcpy(&b1, &d1, 8);
      memcpy(&b2, &d2, 8);
      s.xmm[1] = xmm_from_u64(b1, b2);
    }
    add_xmm("cvtpd2ps precision loss", {0x66, 0x0F, 0x5A, 0xC1}, s);

    // CVTSD2SS xmm0, xmm1: F2 0F 5A C1 (convert scalar double → scalar float)
    // Double that's too large for float: ~3.5e38 → +Inf
    {
      double big = 3.5e38;
      u64 bbig;
      memcpy(&bbig, &big, 8);
      s.xmm[0] = xmm_from_u32(0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF);
      s.xmm[1] = xmm_from_u64(bbig, 0);
    }
    add_xmm("cvtsd2ss overflow to inf", {0xF2, 0x0F, 0x5A, 0xC1}, s);

    // CVTSI2SS xmm0, eax: F3 0F 2A C0 (convert int32 → float)
    // Large integer that can't be exactly represented: 2^24 + 1 = 16777217
    s.xmm[0] = {};
    s.rax = 16777217;  // 2^24+1: rounds to 16777216.0f or 16777218.0f
    add_xmm("cvtsi2ss large int", {0xF3, 0x0F, 0x2A, 0xC0}, s);

    // CVTSI2SS xmm0, rax: F3 48 0F 2A C0 (convert int64 → float)
    s.rax = (1ULL << 53) + 1;  // just beyond double precision
    add_xmm("cvtsi2ss int64 rounding", {0xF3, 0x48, 0x0F, 0x2A, 0xC0}, s);

    // CVTSD2SS round-trip: double → float → double
    // Start with a double that's exactly representable as float
    {
      float f = 1.5f;
      double d = (double)f;
      u64 bd;
      memcpy(&bd, &d, 8);
      s.xmm[1] = xmm_from_u64(bd, 0);
      s.xmm[0] = {};
    }
    // CVTSD2SS xmm0, xmm1; CVTSS2SD xmm0, xmm0
    add_xmm("cvtsd2ss+cvtss2sd round-trip",
             {0xF2, 0x0F, 0x5A, 0xC1,   // cvtsd2ss xmm0, xmm1
              0xF3, 0x0F, 0x5A, 0xC0},  // cvtss2sd xmm0, xmm0
             s);
  }

  // =====================================================================
  // PUSH/POP memory operands
  // =====================================================================
  cat = "PUSH/POP mem";
  {
    // PUSH qword [rdi]: FF 37 — push value at [rdi] onto stack
    // Stack is verified by comparing RSP and the value pushed (read via POP rax)
    {
      TestCase tc;
      tc.name = "push qword [rdi]";
      tc.category = cat;
      // push qword [rdi]; pop rax (verify stack content)
      tc.code = {0xFF, 0x37,  // push qword [rdi]
                 0x58};        // pop rax
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      u64 val = 0xDEADBEEFCAFEBABEULL;
      tc.init_data.resize(8);
      memcpy(tc.init_data.data(), &val, 8);
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // POP qword [rdi]: 8F 07 — pop from stack into memory
    {
      TestCase tc;
      tc.name = "pop qword [rdi]";
      tc.category = cat;
      // push rax; pop qword [rdi]
      tc.code = {0x50,         // push rax
                 0x8F, 0x07};  // pop qword [rdi]
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0x123456789ABCDEF0ULL;
      tc.flags_mask = FL_NONE;
      tc.compare_data_len = 8;
      tests.push_back(std::move(tc));
    }

    // PUSH imm16: 66 68 imm16 — push 16-bit immediate
    // Verify stack content via pop
    {
      TestCase tc;
      tc.name = "push imm16 0x1234";
      tc.category = cat;
      // push 0x1234; pop rax
      tc.code = {0x66, 0x68, 0x34, 0x12,  // push 0x1234
                 0x66, 0x58};               // pop ax (16-bit)
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rax = 0;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // PUSH imm8: 6A imm8 — push sign-extended 8-bit immediate
    {
      TestCase tc;
      tc.name = "push imm8 0xFF (-1)";
      tc.category = cat;
      // push -1; pop rax
      tc.code = {0x6A, 0xFF,  // push -1 (sign-extended to 64-bit)
                 0x58};        // pop rax
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // PUSH imm32: 68 imm32 — push sign-extended 32-bit immediate
    {
      TestCase tc;
      tc.name = "push imm32 0x80000000";
      tc.category = cat;
      // push 0x80000000; pop rax (sign-extends to 0xFFFFFFFF80000000)
      tc.code = {0x68, 0x00, 0x00, 0x00, 0x80,  // push 0x80000000
                 0x58};                            // pop rax
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // LOCK prefix memory operations — read-modify-write on memory
  // =====================================================================
  cat = "LOCK mem";
  {
    // LOCK ADD [rdi], eax: F0 01 07  (32-bit)
    {
      TestCase tc;
      tc.name = "lock add [rdi],eax 32";
      tc.category = cat;
      tc.code = {0xF0, 0x01, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0x100;
      tc.init_data = {0x34, 0x12, 0x00, 0x00};  // [rdi] = 0x1234
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK ADD [rdi], rax: F0 48 01 07  (64-bit)
    {
      TestCase tc;
      tc.name = "lock add [rdi],rax 64";
      tc.category = cat;
      tc.code = {0xF0, 0x48, 0x01, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0x1000000000ULL;
      tc.init_data = {0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00};
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 8;
      tests.push_back(std::move(tc));
    }

    // LOCK SUB [rdi], ecx: F0 29 0F  (32-bit)
    {
      TestCase tc;
      tc.name = "lock sub [rdi],ecx 32";
      tc.category = cat;
      tc.code = {0xF0, 0x29, 0x0F};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rcx = 1;
      tc.init_data = {0x00, 0x00, 0x00, 0x00};  // 0 - 1 = underflow
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK OR [rdi], eax: F0 09 07  (32-bit)
    {
      TestCase tc;
      tc.name = "lock or [rdi],eax 32";
      tc.category = cat;
      tc.code = {0xF0, 0x09, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0xFF00FF00;
      tc.init_data = {0x0F, 0x0F, 0x0F, 0x0F};
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK AND [rdi], eax: F0 21 07  (32-bit)
    {
      TestCase tc;
      tc.name = "lock and [rdi],eax 32";
      tc.category = cat;
      tc.code = {0xF0, 0x21, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0xFF00FF00;
      tc.init_data = {0xAB, 0xCD, 0xEF, 0x12};
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK XOR [rdi], eax: F0 31 07  (32-bit)
    {
      TestCase tc;
      tc.name = "lock xor [rdi],eax 32";
      tc.category = cat;
      tc.code = {0xF0, 0x31, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0xFFFFFFFF;
      tc.init_data = {0xAA, 0x55, 0xAA, 0x55};
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK INC dword [rdi]: F0 FF 07
    {
      TestCase tc;
      tc.name = "lock inc dword [rdi]";
      tc.category = cat;
      tc.code = {0xF0, 0xFF, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.init_data = {0xFF, 0xFF, 0xFF, 0x7F};  // 0x7FFFFFFF → overflow
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK DEC dword [rdi]: F0 FF 0F
    {
      TestCase tc;
      tc.name = "lock dec dword [rdi]";
      tc.category = cat;
      tc.code = {0xF0, 0xFF, 0x0F};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.init_data = {0x00, 0x00, 0x00, 0x00};  // 0 → underflow
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK XADD [rdi], eax: F0 0F C1 07
    // Swaps src and dst, then adds. [rdi] += eax, eax gets old [rdi].
    {
      TestCase tc;
      tc.name = "lock xadd [rdi],eax 32";
      tc.category = cat;
      tc.code = {0xF0, 0x0F, 0xC1, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 10;
      tc.init_data = {0x05, 0x00, 0x00, 0x00};  // [rdi] = 5
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK BTS [rdi], eax: F0 0F AB 07
    // Set bit eax in [rdi], CF = old bit value
    {
      TestCase tc;
      tc.name = "lock bts [rdi],eax (bit 3)";
      tc.category = cat;
      tc.code = {0xF0, 0x0F, 0xAB, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 3;  // set bit 3
      tc.init_data = {0x00, 0x00, 0x00, 0x00};  // bit 3 was 0
      tc.flags_mask = FL_CF;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK BTR [rdi], eax: F0 0F B3 07
    // Reset bit eax in [rdi], CF = old bit value
    {
      TestCase tc;
      tc.name = "lock btr [rdi],eax (bit 7)";
      tc.category = cat;
      tc.code = {0xF0, 0x0F, 0xB3, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 7;  // reset bit 7
      tc.init_data = {0xFF, 0x00, 0x00, 0x00};  // bit 7 was 1
      tc.flags_mask = FL_CF;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK BTC [rdi], eax: F0 0F BB 07
    // Complement bit eax in [rdi], CF = old bit value
    {
      TestCase tc;
      tc.name = "lock btc [rdi],eax (bit 0)";
      tc.category = cat;
      tc.code = {0xF0, 0x0F, 0xBB, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0;  // toggle bit 0
      tc.init_data = {0x01, 0x00, 0x00, 0x00};  // bit 0 was 1 → 0
      tc.flags_mask = FL_CF;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // MOVQ store (66 0F D6) + VMOVQ store (VEX.128.66.0F D6)
  // =====================================================================
  cat = "MOVQ store";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0xDEADBEEFCAFEBABE, 0x1234567890ABCDEF);

    // 66 0F D6 C8: MOVQ xmm0, xmm1 (reg-reg: store low qword of xmm1 to xmm0, zero upper)
    // ModRM: mod=11, reg=1(src), rm=0(dst) → 0xC8
    add_xmm("movq xmm0,xmm1 (66 0F D6)", {0x66, 0x0F, 0xD6, 0xC8}, s, 0x3);

    // VEX.128.66.0F D6: VMOVQ xmm0, xmm1
    // 2-byte VEX: C5 [R̄.vvvv.L.pp]
    // R̄=1, vvvv=1111, L=0, pp=01(66) → 0xF9
    // C5 F9 D6 C8: VMOVQ xmm0, xmm1
    // reg=xmm1(1), rm=xmm0(0): ModRM = mod=11, reg=001, rm=000 → 0xC8
    add_xmm("vmovq xmm0,xmm1 (VEX D6)", {0xC5, 0xF9, 0xD6, 0xC8}, s, 0x3);
  }

  cat = "K-register ops";
  {
    auto add_flags = [&](const char *name, std::vector<u8> code, ArchState init) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL});
    };

    ArchState s;
    s.rflags = 0x2;

    // Set up k1=0xAAAA, k2=0x5555 via KMOVW from GPR
    // We pre-load k-registers using KMOV r32->k then do the operation and read back with KMOV k->r32
    // Since KVM runs all code together, we encode a sequence.

    // Test KORW k3, k1, k2 then KMOVW eax, k3
    // Load k1=0xAAAA: mov eax, 0xAAAA / kmovw k1, eax
    // Load k2=0x5555: mov eax, 0x5555 / kmovw k2, eax
    // KORW k3, k1, k2: C5 EC 45 DB (VEX.256.NP.0F 45: k3=modrm.reg(011), k1=vvvv(001), k2=rm(011))
    // Actually: VEX.NDS.LZ.0F. Let me encode properly.
    // KORW uses VEX.L1.NP.0F.W0 45 /r
    // k3, k1, k2: modrm = 0xCB (mod=11, reg=001(k1), rm=011(k3)) wait...
    // Encoding: KORW k1, k2, k3: reg=dst, vvvv=src1, rm=src2
    // VEX byte1: R̄=1, vvvv=~k1, L=1, pp=00 → 1.1100.1.00 = 0xE4
    // C5 E4 45 D9 = KORW k3, k3, k1? No, need to be more careful.

    // Let me use a simpler approach: just test KORTESTW since it sets flags
    // Load k1=0x5555 via mov eax, 0x5555 / C5 F8 92 C8 (kmovw k1, eax)
    // Load k2=0xAAAA via mov eax, 0xAAAA / C5 F8 92 D0 (kmovw k2, eax)
    // KORTESTW k1, k2: C5 F8 98 CA (VEX.LZ.NP.0F.W0 98, modrm=CA: reg=k1(001), rm=k2(010))
    s.rax = 0x5555;
    s.rdx = 0xAAAA;
    // mov eax, 0x5555 already set. Use: C5 F8 92 C8 = kmovw k1, eax
    // C5 F8 92 D2 = kmovw k2, edx
    // C5 F8 98 CA = kortestw k1, k2
    add_flags("kortestw k1(5555),k2(AAAA) -> k1|k2=FFFF",
      {0xC5, 0xF8, 0x92, 0xC8,  // kmovw k1, eax (0x5555)
       0xC5, 0xF8, 0x92, 0xD2,  // kmovw k2, edx (0xAAAA)
       0xC5, 0xF8, 0x98, 0xCA}, // kortestw k1, k2
      s);

    // KORTESTW with zero result
    s.rax = 0;
    s.rdx = 0;
    add_flags("kortestw k1(0),k2(0) -> ZF=1",
      {0xC5, 0xF8, 0x92, 0xC8,
       0xC5, 0xF8, 0x92, 0xD2,
       0xC5, 0xF8, 0x98, 0xCA},
      s);

    // KTESTW: k1&k2 and ~k1&k2
    s.rax = 0xFFFF;
    s.rdx = 0x00FF;
    add_flags("ktestw k1(FFFF),k2(00FF)",
      {0xC5, 0xF8, 0x92, 0xC8,
       0xC5, 0xF8, 0x92, 0xD2,
       0xC5, 0xF8, 0x99, 0xCA},
      s);

    s.rax = 0x0000;
    s.rdx = 0xFFFF;
    add_flags("ktestw k1(0),k2(FFFF) -> ZF=1",
      {0xC5, 0xF8, 0x92, 0xC8,
       0xC5, 0xF8, 0x92, 0xD2,
       0xC5, 0xF8, 0x99, 0xCA},
      s);

    // --- K-register logical operations ---
    // All use k1, k2 as inputs (loaded via XSAVE), k3 as output (read via KMOVW eax, k3).
    // KMOVW eax, k3 = C5 F8 93 C3

    // KANDW k3, k1, k2: VEX.L1.0F.W0 41 /r
    // k3=reg(011), vvvv=~k1=1110, k2=rm(010) → C5 EC 41 DA
    {
      TestCase tc;
      tc.name = "kandw k3,k1,k2: AAAA & 5555 = 0";
      tc.category = cat;
      tc.code = {0xC5, 0xF4, 0x41, 0xDA,   // kandw k3, k1, k2
                 0xC5, 0xF8, 0x93, 0xC3};   // kmovw eax, k3
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xAAAA;
      tc.initial.kregs[2] = 0x5555;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KANDW — overlapping bits
    {
      TestCase tc;
      tc.name = "kandw k3,k1,k2: FF00 & 0FF0 = 0F00";
      tc.category = cat;
      tc.code = {0xC5, 0xF4, 0x41, 0xDA,
                 0xC5, 0xF8, 0x93, 0xC3};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xFF00;
      tc.initial.kregs[2] = 0x0FF0;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KORW k3, k1, k2: VEX.L1.0F.W0 45 /r → C5 EC 45 DA
    {
      TestCase tc;
      tc.name = "korw k3,k1,k2: AAAA | 5555 = FFFF";
      tc.category = cat;
      tc.code = {0xC5, 0xF4, 0x45, 0xDA,
                 0xC5, 0xF8, 0x93, 0xC3};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xAAAA;
      tc.initial.kregs[2] = 0x5555;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KXORW k3, k1, k2: VEX.L1.0F.W0 47 /r → C5 EC 47 DA
    {
      TestCase tc;
      tc.name = "kxorw k3,k1,k2: FFFF ^ 00FF = FF00";
      tc.category = cat;
      tc.code = {0xC5, 0xF4, 0x47, 0xDA,
                 0xC5, 0xF8, 0x93, 0xC3};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xFFFF;
      tc.initial.kregs[2] = 0x00FF;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KANDNW k3, k1, k2: VEX.L1.0F.W0 42 /r → C5 EC 42 DA
    // result = ~k1 & k2
    {
      TestCase tc;
      tc.name = "kandnw k3,k1,k2: ~FF00 & 0FF0 = 00F0";
      tc.category = cat;
      tc.code = {0xC5, 0xF4, 0x42, 0xDA,
                 0xC5, 0xF8, 0x93, 0xC3};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xFF00;
      tc.initial.kregs[2] = 0x0FF0;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KXNORW k3, k1, k2: VEX.L1.0F.W0 46 /r → C5 EC 46 DA
    // result = ~(k1 ^ k2)
    {
      TestCase tc;
      tc.name = "kxnorw k3,k1,k2: ~(FF00^00FF) = 00FF (lower 16)";
      tc.category = cat;
      tc.code = {0xC5, 0xF4, 0x46, 0xDA,
                 0xC5, 0xF8, 0x93, 0xC3};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xFF00;
      tc.initial.kregs[2] = 0x00FF;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KNOTW k3, k1: VEX.L0.0F.W0 44 /r → C5 F8 44 D9
    // dst=k3(011), src=k1(001), vvvv=1111
    {
      TestCase tc;
      tc.name = "knotw k3,k1: ~AAAA = 5555";
      tc.category = cat;
      tc.code = {0xC5, 0xF8, 0x44, 0xD9,
                 0xC5, 0xF8, 0x93, 0xC3};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xAAAA;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KUNPCKBW k3, k1, k2: VEX.L1.0F.W0 4B /r → C5 F4 4B DA
    // result = k1[7:0] : k2[7:0] (concatenate low bytes)
    // Use KMOVW preamble to load k1, k2 (XSAVE may not load reliably for this).
    {
      TestCase tc;
      tc.name = "kunpckbw k3,k1,k2: AB:CD = ABCD";
      tc.category = cat;
      tc.code = {0xC5, 0xF8, 0x92, 0xC8,   // kmovw k1, eax (0xAB)
                 0xC5, 0xF8, 0x92, 0xD2,   // kmovw k2, edx (0xCD)
                 0xC5, 0xF5, 0x4B, 0xDA,   // kunpckbw k3, k1, k2 (VEX.L1.66.0F.W0)
                 0xC5, 0xF8, 0x93, 0xC3};  // kmovw eax, k3
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rax = 0xAB;
      tc.initial.rdx = 0xCD;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KMOVW k1, m16: VEX.L0.0F.W0 90 /r (memory load)
    // Load k1 from [DATA_ADDR] containing 0x1234
    {
      TestCase tc;
      tc.name = "kmovw k1,m16: load 1234h";
      tc.category = cat;
      // mov rdi, DATA_ADDR; kmovw k1, [rdi]; kmovw eax, k1
      tc.code = {0x48, 0xBF, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,  // mov rdi, 0x10000 (DATA_ADDR)
                 0xC5, 0xF8, 0x90, 0x0F,   // kmovw k1, [rdi]
                 0xC5, 0xF8, 0x93, 0xC1};  // kmovw eax, k1
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.init_data = {0x34, 0x12};  // 0x1234 in little-endian
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KMOVW m16, k1: VEX.L0.0F.W0 91 /r (memory store)
    {
      TestCase tc;
      tc.name = "kmovw m16,k1: store BEEF to mem";
      tc.category = cat;
      // mov rdi, DATA_ADDR; kmovw [rdi], k1
      tc.code = {0x48, 0xBF, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,  // mov rdi, DATA_ADDR
                 0xC5, 0xF8, 0x91, 0x0F};  // kmovw [rdi], k1
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xBEEF;
      tc.flags_mask = FL_NONE;
      tc.compare_data_len = 2;
      tests.push_back(std::move(tc));
    }
  }

  // K-register B/D/Q width tests
  {
    // KANDD k2, k2, k2 (dword AND): VEX.L1.66.0F.W1 41 /r
    // C4 E1 ED 41 D2: L=1, pp=01(66), W=1, vvvv=~k2=1101, opcode=41, modrm=D2(k2,k2)
    {
      TestCase tc;
      tc.name = "kandd k2,k2,k2 (32-bit)";
      tc.category = cat;
      tc.code = {0xC4, 0xE1, 0xED, 0x41, 0xD2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[2] = 0x00000000FFFF0000;
      tc.flags_mask = FL_NONE;
      tc.kreg_mask = (1 << 2);
      tests.push_back(std::move(tc));
    }

    // KMOVD EAX, k2 (F2+W0): C5 FB 93 C2
    {
      TestCase tc;
      tc.name = "kmovd eax,k2";
      tc.category = cat;
      tc.code = {0xC5, 0xFB, 0x93, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rax = 0xDEADDEADDEADDEAD;
      tc.initial.kregs[2] = 0x12345678;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // Vector memory stores — verify memory output
  // =====================================================================
  cat = "Vec stores";
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    s.xmm[0] = xmm_from_u64(0x1122334455667788ULL, 0x99AABBCCDDEEFF00ULL);
    s.xmm[1] = xmm_from_u64(0xAAAABBBBCCCCDDDDULL, 0xEEEEFFFF00001111ULL);

    // MOVAPS [rdi], xmm0: 0F 29 07
    {
      TestCase tc;
      tc.name = "movaps [rdi],xmm0";
      tc.category = cat;
      tc.code = {0x0F, 0x29, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // MOVUPS [rdi], xmm0: 0F 11 07
    {
      TestCase tc;
      tc.name = "movups [rdi],xmm0";
      tc.category = cat;
      tc.code = {0x0F, 0x11, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // MOVDQU [rdi], xmm0: F3 0F 7F 07
    {
      TestCase tc;
      tc.name = "movdqu [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xF3, 0x0F, 0x7F, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // MOVDQA [rdi], xmm0: 66 0F 7F 07
    {
      TestCase tc;
      tc.name = "movdqa [rdi],xmm0";
      tc.category = cat;
      tc.code = {0x66, 0x0F, 0x7F, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // MOVLPS [rdi], xmm0: 0F 13 07 (store low 64 bits)
    {
      TestCase tc;
      tc.name = "movlps [rdi],xmm0";
      tc.category = cat;
      tc.code = {0x0F, 0x13, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 8;
      tests.push_back(std::move(tc));
    }

    // MOVHPS [rdi], xmm0: 0F 17 07 (store high 64 bits)
    {
      TestCase tc;
      tc.name = "movhps [rdi],xmm0";
      tc.category = cat;
      tc.code = {0x0F, 0x17, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 8;
      tests.push_back(std::move(tc));
    }

    // MOVSS [rdi], xmm0: F3 0F 11 07 (store 32 bits)
    {
      TestCase tc;
      tc.name = "movss [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xF3, 0x0F, 0x11, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // MOVSD [rdi], xmm0: F2 0F 11 07 (store 64 bits)
    {
      TestCase tc;
      tc.name = "movsd [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xF2, 0x0F, 0x11, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 8;
      tests.push_back(std::move(tc));
    }

    // VMOVAPS [rdi], xmm0: C5 F8 29 07
    {
      TestCase tc;
      tc.name = "vmovaps [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xC5, 0xF8, 0x29, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // VMOVDQU [rdi], xmm0: C5 FA 7F 07
    {
      TestCase tc;
      tc.name = "vmovdqu [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xC5, 0xFA, 0x7F, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // VMOVAPS [rdi], ymm0: need to set up ymm0 first
    // Use VINSERTF128 ymm0, ymm0, xmm1, 1 (C4 E3 7D 18 C1 01) to set hi half
    {
      TestCase tc;
      tc.name = "vmovaps [rdi],ymm0 (32 bytes)";
      tc.category = cat;
      tc.code = {0xC4, 0xE3, 0x7D, 0x18, 0xC1, 0x01,  // vinsertf128 ymm0,ymm0,xmm1,1
                 0xC5, 0xFC, 0x29, 0x07};               // vmovaps [rdi], ymm0
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 32;
      tests.push_back(std::move(tc));
    }

    // VMOVDQU [rdi], ymm0: C5 FE 7F 07
    {
      TestCase tc;
      tc.name = "vmovdqu [rdi],ymm0 (32 bytes)";
      tc.category = cat;
      tc.code = {0xC4, 0xE3, 0x7D, 0x18, 0xC1, 0x01,  // vinsertf128 ymm0,ymm0,xmm1,1
                 0xC5, 0xFE, 0x7F, 0x07};               // vmovdqu [rdi], ymm0
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 32;
      tests.push_back(std::move(tc));
    }
  }

}
