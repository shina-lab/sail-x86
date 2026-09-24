#include "kvm-harness.h"

void add_compat_tests(std::vector<TestCase> &tests) {
  std::string cat;

  // Helper: add a normal compat-mode test
  auto add = [&](const std::string &name, std::vector<u8> code, ArchState init,
                 u64 mask = FL_ALL) {
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = std::move(code);
    tc.initial = init;
    tc.flags_mask = mask;
    tc.compat_mode = true;
    tests.push_back(std::move(tc));
  };

  // Helper: compat test with memory data
  auto add_mem = [&](const std::string &name, std::vector<u8> code, ArchState init,
                     u64 mask, std::vector<u8> data, size_t cmp_len) {
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = std::move(code);
    tc.initial = init;
    tc.flags_mask = mask;
    tc.init_data = std::move(data);
    tc.compare_data_len = cmp_len;
    tc.compat_mode = true;
    tests.push_back(std::move(tc));
  };

  // Helper: compat test comparing XMM registers
  auto add_xmm = [&](const std::string &name, std::vector<u8> code, ArchState init,
                      u32 xmm_cmp) {
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = std::move(code);
    tc.initial = init;
    tc.flags_mask = FL_ALL;
    tc.xmm_mask = xmm_cmp;
    tc.compat_mode = true;
    tests.push_back(std::move(tc));
  };

  // =====================================================================
  // Compat Operand Size
  // SDM Table 3-3: CS.D=1 -> default operand=32, 66h -> 16
  // =====================================================================
  cat = "Compat";
  {
    ArchState s = {};
    s.rax = 0x00000010;
    s.rbx = 0x00000003;
    s.rcx = 0x00000005;
    s.rdx = 0x00000007;
    s.rflags = initial_flags();

    // ADD EAX, EBX: 01 D8 (default 32-bit operand)
    add("compat add eax,ebx", {0x01, 0xD8}, with_gpr_inputs(s, {&ArchState::rax, &ArchState::rbx}));
    // ADD AX, BX (66h prefix -> 16-bit)
    add("compat add ax,bx (66h)", {0x66, 0x01, 0xD8},
        with_gpr_inputs(s, {&ArchState::rax, &ArchState::rbx}));
    // SUB ECX, EDX: 29 D1
    add("compat sub ecx,edx", {0x29, 0xD1}, with_gpr_inputs(s, {&ArchState::rcx, &ArchState::rdx}));
    // AND EAX, imm32: 25 FF 00 00 00
    add("compat and eax,imm32", {0x25, 0xFF, 0x00, 0x00, 0x00}, with_gpr_inputs(s, {&ArchState::rax}));
    // CMP EAX, EBX: 39 D8
    add("compat cmp eax,ebx", {0x39, 0xD8}, with_gpr_inputs(s, {&ArchState::rax, &ArchState::rbx}));
    // TEST EAX, EBX: 85 D8
    add("compat test eax,ebx", {0x85, 0xD8}, with_gpr_inputs(s, {&ArchState::rax, &ArchState::rbx}));
    // MOV EAX, imm32: B8 78 56 34 12
    add("compat mov eax,imm32", {0xB8, 0x78, 0x56, 0x34, 0x12}, with_gpr_inputs(s, {}), FL_ALL);
    // MOV AX, imm16 (66h): 66 B8 34 12
    add("compat mov ax,imm16 (66h)", {0x66, 0xB8, 0x34, 0x12}, with_gpr_inputs(s, {}), FL_ALL);
    // XOR EAX, EAX: 31 C0
    add("compat xor eax,eax", {0x31, 0xC0}, with_gpr_inputs(s, {}));
    // IMUL EAX, EBX, imm8: 6B C3 05
    add("compat imul eax,ebx,imm8", {0x6B, 0xC3, 0x05}, with_gpr_inputs(s, {&ArchState::rbx}), FL_CF_OF);
    // NOT EAX: F7 D0
    add("compat not eax", {0xF7, 0xD0}, with_gpr_inputs(s, {&ArchState::rax}), FL_ALL);
    // NEG ECX: F7 D9
    add("compat neg ecx", {0xF7, 0xD9}, with_gpr_inputs(s, {&ArchState::rcx}));
    // MOVZX EAX, BL: 0F B6 C3
    add("compat movzx eax,bl", {0x0F, 0xB6, 0xC3}, with_gpr_inputs(s, {&ArchState::rbx}), FL_ALL);
    // MOVSX EAX, BX: 0F BF C3
    add("compat movsx eax,bx", {0x0F, 0xBF, 0xC3}, with_gpr_inputs(s, {&ArchState::rbx}), FL_ALL);
    // BSWAP EAX: 0F C8
    {
      ArchState bs = {};
      bs.rax = 0x12345678;
      bs.rflags = initial_flags();
      add("compat bswap eax", {0x0F, 0xC8}, bs, FL_ALL);
    }
    // CDQ: 99 (sign-extend EAX -> EDX:EAX)
    {
      ArchState cdq = {};
      cdq.rax = 0x80000001;
      cdq.rflags = initial_flags();
      add("compat cdq (negative)", {0x99}, cdq, FL_ALL);

      ArchState cdq_pos = {};
      cdq_pos.rax = 0x7FFFFFFF;
      cdq_pos.rflags = initial_flags();
      add("compat cdq (positive)", {0x99}, cdq_pos, FL_ALL);
    }
    // LEA EAX, [EBX+ECX*4]: 8D 04 8B
    {
      ArchState lea = {};
      lea.rbx = 0x1000;
      lea.rcx = 0x10;
      lea.rflags = initial_flags();
      add("compat lea eax,[ebx+ecx*4]", {0x8D, 0x04, 0x8B}, lea, FL_ALL);
    }
    // OR EAX, EBX: 09 D8
    add("compat or eax,ebx", {0x09, 0xD8}, with_gpr_inputs(s, {&ArchState::rax, &ArchState::rbx}));
    // XOR ECX, EDX: 31 D1
    add("compat xor ecx,edx", {0x31, 0xD1}, with_gpr_inputs(s, {&ArchState::rcx, &ArchState::rdx}));
    // ADD EAX, imm8 (sign-ext): 83 C0 0A
    add("compat add eax,imm8", {0x83, 0xC0, 0x0A}, with_gpr_inputs(s, {&ArchState::rax}));
    // SUB EAX, imm8: 83 E8 05
    add("compat sub eax,imm8", {0x83, 0xE8, 0x05}, with_gpr_inputs(s, {&ArchState::rax}));
    // CMP EAX, imm8: 83 F8 10
    add("compat cmp eax,imm8", {0x83, 0xF8, 0x10}, with_gpr_inputs(s, {&ArchState::rax}));
  }

  // =====================================================================
  // Compat Address Size
  // SDM §3.3.7, Table 3-3: default address = 32, zero-extended to 64-bit
  // =====================================================================
  // --- Address Size ---
  {
    // MOV EAX, [EBX]: 8B 03
    {
      ArchState s = {};
      s.rbx = DATA_ADDR;
      s.rflags = initial_flags();
      std::vector<u8> data(8, 0);
      u32 val = 0xDEADBEEF;
      memcpy(data.data(), &val, 4);
      add_mem("compat mov eax,[ebx]", {0x8B, 0x03}, s, FL_ALL, data, 0);
    }
    // MOV EAX, [EBX+ECX*4]: 8B 04 8B (SIB)
    {
      ArchState s = {};
      s.rbx = DATA_ADDR;
      s.rcx = 2;
      s.rflags = initial_flags();
      std::vector<u8> data(16, 0);
      u32 val = 0xCAFEBABE;
      memcpy(data.data() + 8, &val, 4);  // at offset 8 = ecx*4
      add_mem("compat mov eax,[ebx+ecx*4]", {0x8B, 0x04, 0x8B}, s, FL_ALL, data, 0);
    }
    // MOV EAX, [EBP+8]: 8B 45 08
    {
      ArchState s = {};
      s.rbp = DATA_ADDR;
      s.rflags = initial_flags();
      std::vector<u8> data(16, 0);
      u32 val = 0x11223344;
      memcpy(data.data() + 8, &val, 4);
      add_mem("compat mov eax,[ebp+8]", {0x8B, 0x45, 0x08}, s, FL_ALL, data, 0);
    }
    // MOV EAX, [ESP+4]: 8B 44 24 04 (SIB with ESP base)
    {
      ArchState s = {};
      s.rsp = DATA_ADDR;
      s.rflags = initial_flags();
      std::vector<u8> data(16, 0);
      u32 val = 0x55667788;
      memcpy(data.data() + 4, &val, 4);
      add_mem("compat mov eax,[esp+4]", {0x8B, 0x44, 0x24, 0x04}, s, FL_ALL, data, 0);
    }
    // MOV EAX, [disp32]: 8B 05 00 10 01 00  (mod=00, rm=5 = [disp32], NOT [RIP+disp32])
    {
      ArchState s = {};
      std::vector<u8> data(8, 0);
      u32 val = 0xABCD1234;
      memcpy(data.data(), &val, 4);
      // disp32 = DATA_ADDR = 0x11000
      add_mem("compat mov eax,[disp32]",
              {0x8B, 0x05,
               (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
               (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24)},
              s, FL_ALL, data, 0);
    }
    // MOV [EBX], EAX: 89 03 (store via 32-bit addr)
    {
      ArchState s = {};
      s.rax = 0xFEEDFACE;
      s.rbx = DATA_ADDR;
      s.rflags = initial_flags();
      add_mem("compat mov [ebx],eax", {0x89, 0x03}, s, FL_ALL, {}, 4);
    }
    // MOV [EBX+ECX*8+4], EDX: 89 54 CB 04
    {
      ArchState s = {};
      s.rbx = DATA_ADDR;
      s.rcx = 1;
      s.rdx = 0x99887766;
      s.rflags = initial_flags();
      // Store at DATA_ADDR + 1*8 + 4 = DATA_ADDR + 12
      add_mem("compat mov [ebx+ecx*8+4],edx", {0x89, 0x54, 0xCB, 0x04}, s, FL_ALL, {}, 16);
    }
    // MOV EAX, [EBX+disp32]: 8B 83 00 01 00 00
    {
      ArchState s = {};
      s.rbx = DATA_ADDR;
      s.rflags = initial_flags();
      std::vector<u8> data(0x108, 0);
      u32 val = 0x44332211;
      memcpy(data.data() + 0x100, &val, 4);
      add_mem("compat mov eax,[ebx+disp32]", {0x8B, 0x83, 0x00, 0x01, 0x00, 0x00},
              s, FL_ALL, data, 0);
    }
  }

  // =====================================================================
  // Compat RIP-relative Absent
  // SDM §3.5.1: mod=00 rm=101 = [disp32] in compat mode, NOT [RIP+disp32]
  // =====================================================================
  // --- RIP-relative Absent ---
  {
    // LEA EAX, [disp32]: 8D 05 <disp32>
    // In compat mode: EAX = disp32 (absolute)
    // In 64-bit mode this would be RIP-relative
    ArchState s = {};
    add("compat lea eax,[disp32]",
        {0x8D, 0x05,
         (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
         (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24)},
        s, FL_ALL);
  }

  // =====================================================================
  // Compat Stack Operations
  // PUSH/POP use ESP (32-bit), default push size = 32-bit
  // =====================================================================
  // --- Stack Operations ---
  {
    // PUSH EAX (50): pushes 4 bytes, ESP -= 4
    {
      ArchState s = {};
      s.rax = 0x12345678;
      s.rflags = initial_flags();
      add("compat push eax", {0x50}, s, FL_ALL);
    }
    // PUSH EAX + POP EBX: ESP unchanged, EBX = original EAX
    {
      ArchState s = {};
      s.rax = 0xAABBCCDD;
      s.rflags = initial_flags();
      add("compat push eax; pop ebx", {0x50, 0x5B}, s, FL_ALL);
    }
    // PUSH imm32: 68 78 56 34 12
    {
      ArchState s = {};
      add("compat push imm32", {0x68, 0x78, 0x56, 0x34, 0x12}, s, FL_ALL);
    }
    // PUSH imm32 + POP EAX: EAX gets the pushed immediate
    {
      ArchState s = {};
      add("compat push imm32; pop eax", {0x68, 0x78, 0x56, 0x34, 0x12, 0x58}, s, FL_ALL);
    }
    // PUSH imm8 (sign-extended): 6A 42
    {
      ArchState s = {};
      add("compat push imm8; pop eax", {0x6A, 0x42, 0x58}, s, FL_ALL);
    }
    // PUSH imm8 negative (sign-extended): 6A FE -> pushes 0xFFFFFFFE
    {
      ArchState s = {};
      add("compat push imm8 neg; pop eax", {0x6A, 0xFE, 0x58}, s, FL_ALL);
    }
    // PUSH AX (66h prefix): 16-bit push, ESP -= 2
    {
      ArchState s = {};
      s.rax = 0x12345678;
      s.rflags = initial_flags();
      add("compat push ax (66h)", {0x66, 0x50}, s, FL_ALL);
    }
    // PUSH AX + POP AX (66h): round-trip 16-bit
    {
      ArchState s = {};
      s.rax = 0xAABBCCDD;
      s.rflags = initial_flags();
      add("compat push ax; pop bx (66h)", {0x66, 0x50, 0x66, 0x5B}, s, FL_ALL);
    }
    // PUSHFD (9C) + POPFD (9D): push/pop EFLAGS
    {
      ArchState s = {};
      s.rflags = 0x2 | FL_CF | FL_ZF;
      add("compat pushfd; popfd", {0x9C, 0x9D}, s, FL_ALL);
    }
    // PUSH [EBX] (FF /6): push memory via 32-bit address
    {
      ArchState s = {};
      s.rbx = DATA_ADDR;
      s.rflags = initial_flags();
      std::vector<u8> data(8, 0);
      u32 val = 0xDEAD1234;
      memcpy(data.data(), &val, 4);
      // PUSH [EBX] then POP EAX to verify value
      add_mem("compat push [ebx]; pop eax", {0xFF, 0x33, 0x58}, s, FL_ALL, data, 0);
    }
  }

  // =====================================================================
  // Compat Control Flow
  // CALL pushes 32-bit EIP, RET pops 32-bit EIP
  // =====================================================================
  // --- Control Flow ---
  {
    // CALL rel32 + RET: E8 02 00 00 00 EB 01 C3
    // CALL target = offset 7 (C3=RET). RET returns to offset 5 (EB 01 = JMP +1 -> HLT)
    {
      ArchState s = {};
      add("compat call rel32; ret", {0xE8, 0x02, 0x00, 0x00, 0x00, 0xEB, 0x01, 0xC3}, s, FL_ALL);
    }
    // JMP rel8: EB 02 CC CC -> jumps over 2 INT3 bytes
    {
      ArchState s = {};
      add("compat jmp rel8", {0xEB, 0x00}, s, FL_ALL);  // JMP +0 = next insn
    }
    // JMP rel32: E9 00 00 00 00 -> jumps to next instruction
    {
      ArchState s = {};
      add("compat jmp rel32", {0xE9, 0x00, 0x00, 0x00, 0x00}, s, FL_ALL);
    }
    // JZ taken (ZF=1): 74 00 -> jump to next insn
    {
      ArchState s = {};
      s.rflags = initial_flags(FL_ZF, FL_ZF);
      add("compat jz taken", {0x74, 0x00}, s, FL_ALL);
    }
    // JZ not taken (ZF=0): 74 00
    {
      ArchState s = {};
      s.rflags = initial_flags(FL_ZF, 0);
      add("compat jz not taken", {0x74, 0x00}, s, FL_ALL);
    }
    // JNZ taken (ZF=0): 75 00
    {
      ArchState s = {};
      s.rflags = initial_flags(FL_ZF, 0);
      add("compat jnz taken", {0x75, 0x00}, s, FL_ALL);
    }
    // LOOP: E2 FE with ECX=1 -> ECX becomes 0, loop not taken
    {
      ArchState s = {};
      s.rcx = 1;
      s.rflags = initial_flags();
      add("compat loop ecx=1", {0xE2, 0xFE}, s, FL_ALL);
    }
    // LOOP with ECX=2: ECX becomes 1, loop taken (infinite loop unless we break)
    // Skip this test — would loop forever.

    // CALL [EAX] (indirect call via register): FF D0
    // Set EAX to address of RET instruction, which is at CODE_ADDR + code_offset
    // Code: FF D0 EB 01 C3 (CALL [EAX], JMP +1 to skip RET, RET at offset 4)
    // Actually CALL [EAX] means call *EAX (the value in EAX is the target address)
    // Wait: FF /2 with ModRM D0 = mod=11, reg=010 (/2=CALL), rm=000 (EAX)
    // This is CALL EAX (register indirect)
    {
      ArchState s = {};
      // EAX points to the RET instruction at CODE_ADDR + 4
      s.rax = CODE_ADDR + 4;
      s.rflags = initial_flags();
      // FF D0: CALL EAX; EB 01: JMP +1 (skip RET); C3: RET
      add("compat call eax; ret", {0xFF, 0xD0, 0xEB, 0x01, 0xC3}, s, FL_ALL);
    }
    // JMP EAX (indirect): FF E0 (mod=11, reg=100 (/4=JMP), rm=000 (EAX))
    {
      ArchState s = {};
      // EAX points to the HLT which the harness appends at CODE_ADDR + 2
      s.rax = CODE_ADDR + 2;
      s.rflags = initial_flags();
      add("compat jmp eax", {0xFF, 0xE0}, s, FL_ALL);
    }
  }

  // =====================================================================
  // Compat INC/DEC Single-Byte
  // Opcodes 0x40-0x4F are INC/DEC r32 (not REX prefix) in compat mode
  // =====================================================================
  // --- INC/DEC Single-Byte ---
  {
    // INC/DEC set OF, SF, ZF, AF, PF but NOT CF
    u64 inc_mask = FL_ALL;

    ArchState s = {};
    s.rax = 0x00000041;
    s.rbx = 0x00000042;
    s.rcx = 0x00000043;
    s.rdx = 0x00000044;
    s.rsp = STACK_TOP;
    s.rbp = 0x00000045;
    s.rsi = 0x00000046;
    s.rdi = 0x00000047;
    s.rflags = initial_flags();

    // INC EAX (40)
    add("compat inc eax (40)", {0x40}, with_gpr_inputs(s, {&ArchState::rax}), inc_mask);
    // INC ECX (41)
    add("compat inc ecx (41)", {0x41}, with_gpr_inputs(s, {&ArchState::rcx}), inc_mask);
    // INC EDX (42)
    add("compat inc edx (42)", {0x42}, with_gpr_inputs(s, {&ArchState::rdx}), inc_mask);
    // INC EBX (43)
    add("compat inc ebx (43)", {0x43}, with_gpr_inputs(s, {&ArchState::rbx}), inc_mask);
    // INC ESP (44) — careful with stack tests after this
    {
      ArchState se = {};
      se.rsp = 0x10;
      se.rflags = initial_flags();
      add("compat inc esp (44)", {0x44}, se, inc_mask);
    }
    // INC EBP (45)
    add("compat inc ebp (45)", {0x45}, with_gpr_inputs(s, {&ArchState::rbp}), inc_mask);
    // INC ESI (46)
    add("compat inc esi (46)", {0x46}, with_gpr_inputs(s, {&ArchState::rsi}), inc_mask);
    // INC EDI (47)
    add("compat inc edi (47)", {0x47}, with_gpr_inputs(s, {&ArchState::rdi}), inc_mask);

    // DEC EAX (48)
    add("compat dec eax (48)", {0x48}, with_gpr_inputs(s, {&ArchState::rax}), inc_mask);
    // DEC ECX (49)
    add("compat dec ecx (49)", {0x49}, with_gpr_inputs(s, {&ArchState::rcx}), inc_mask);
    // DEC EDX (4A)
    add("compat dec edx (4A)", {0x4A}, with_gpr_inputs(s, {&ArchState::rdx}), inc_mask);
    // DEC EBX (4B)
    add("compat dec ebx (4B)", {0x4B}, with_gpr_inputs(s, {&ArchState::rbx}), inc_mask);
    // DEC EBP (4D)
    add("compat dec ebp (4D)", {0x4D}, with_gpr_inputs(s, {&ArchState::rbp}), inc_mask);
    // DEC ESI (4E)
    add("compat dec esi (4E)", {0x4E}, with_gpr_inputs(s, {&ArchState::rsi}), inc_mask);
    // DEC EDI (4F)
    add("compat dec edi (4F)", {0x4F}, with_gpr_inputs(s, {&ArchState::rdi}), inc_mask);

    // INC AX (66 40): 66h prefix -> 16-bit INC
    add("compat inc ax (66 40)", {0x66, 0x40}, with_gpr_inputs(s, {&ArchState::rax}), inc_mask);
    // DEC AX (66 48): 66h prefix -> 16-bit DEC
    add("compat dec ax (66 48)", {0x66, 0x48}, with_gpr_inputs(s, {&ArchState::rax}), inc_mask);

    // INC from max: overflow detection
    {
      ArchState ov = {};
      ov.rax = 0x7FFFFFFF;
      ov.rflags = initial_flags();
      add("compat inc eax (OF)", {0x40}, ov, inc_mask);
    }
    // INC from -1: zero flag
    {
      ArchState z = {};
      z.rax = 0xFFFFFFFF;
      z.rflags = initial_flags();
      add("compat inc eax (ZF)", {0x40}, z, inc_mask);
    }
    // DEC from 0: underflow
    {
      ArchState u = {};
      u.rax = 0;
      add("compat dec eax (borrow)", {0x48}, u, inc_mask);
    }
    // DEC from INT_MIN: overflow
    {
      ArchState ov = {};
      ov.rax = 0x80000000;
      ov.rflags = initial_flags();
      add("compat dec eax (OF)", {0x48}, ov, inc_mask);
    }
  }

  // =====================================================================
  // Compat Flags
  // Arithmetic flags with 32-bit operands
  // =====================================================================
  // --- Flags ---
  {
    // ADD that overflows 32-bit: 0x7FFFFFFF + 1 -> OF set
    {
      ArchState s = {};
      s.rax = 0x7FFFFFFF;
      s.rbx = 1;
      s.rflags = initial_flags();
      add("compat add overflow 32", {0x01, 0xD8}, s);
    }
    // ADD that carries: 0xFFFFFFFF + 1 -> CF set
    {
      ArchState s = {};
      s.rax = 0xFFFFFFFF;
      s.rbx = 1;
      s.rflags = initial_flags();
      add("compat add carry 32", {0x01, 0xD8}, s);
    }
    // SUB to zero: ZF set
    {
      ArchState s = {};
      s.rax = 42;
      s.rbx = 42;
      s.rflags = initial_flags();
      add("compat sub zero 32", {0x29, 0xD8}, s);
    }
    // CMP negative result: SF set
    {
      ArchState s = {};
      s.rax = 5;
      s.rbx = 10;
      s.rflags = initial_flags();
      add("compat cmp negative 32", {0x39, 0xD8}, s);
    }
    // AND with parity: PF
    {
      ArchState s = {};
      s.rax = 0xFF;
      s.rbx = 0x0F;
      s.rflags = initial_flags();
      add("compat and parity 32", {0x21, 0xD8}, s);
    }
    // SHR with carry out: CF from shift
    {
      ArchState s = {};
      s.rax = 0x03;
      s.rflags = initial_flags();
      // SHR EAX, 1: D1 E8 (AF undefined for shifts)
      add("compat shr carry 32", {0xD1, 0xE8}, s, FL_NO_AF);
    }
    // SHL with carry out: CF from shift
    {
      ArchState s = {};
      s.rax = 0x80000000;
      s.rflags = initial_flags();
      // SHL EAX, 1: D1 E0 (AF undefined for shifts)
      add("compat shl carry 32", {0xD1, 0xE0}, s, FL_NO_AF);
    }
  }

  // TODO: SYSCALL #UD — needs EFER.SCE=1 and KVM compat mode investigation
  // TODO: ARPL (0x63) — valid in compat mode (not #UD), needs proper implementation

  // =====================================================================
  // Compat Shifts and Rotates
  // =====================================================================
  // --- Shifts and Rotates ---
  {
    ArchState s = {};
    s.rax = 0x12345678;
    s.rbx = 0x9ABCDEF0;
    s.rcx = 4;
    s.rflags = initial_flags();

    // SHL EAX, 1: D1 E0 (AF undefined for shifts)
    add("compat shl eax,1", {0xD1, 0xE0}, with_gpr_inputs(s, {&ArchState::rax}), FL_NO_AF);
    // SHR EAX, CL: D3 E8
    add("compat shr eax,cl", {0xD3, 0xE8},
        with_gpr_inputs(s, {&ArchState::rax, &ArchState::rcx}), FL_NO_AF_OF);
    // SAR EAX, imm8=3: C1 F8 03
    add("compat sar eax,3", {0xC1, 0xF8, 0x03}, with_gpr_inputs(s, {&ArchState::rax}), FL_NO_AF_OF);
    // ROL EAX, 1: D1 C0
    add("compat rol eax,1", {0xD1, 0xC0}, with_gpr_inputs(s, {&ArchState::rax}), FL_ALL);
    // ROR EAX, CL: D3 C8
    add("compat ror eax,cl", {0xD3, 0xC8},
        with_gpr_inputs(s, {&ArchState::rax, &ArchState::rcx}), FL_ALL & ~FL_OF);
    // SHLD EAX, EBX, imm8=4: 0F A4 D8 04 (AF, OF undefined for count > 1)
    add("compat shld eax,ebx,4", {0x0F, 0xA4, 0xD8, 0x04},
        with_gpr_inputs(s, {&ArchState::rax, &ArchState::rbx}), FL_NO_AF_OF);
    // SHRD EAX, EBX, CL: 0F AD D8
    add("compat shrd eax,ebx,cl", {0x0F, 0xAD, 0xD8}, s, FL_NO_AF_OF);
  }

  // =====================================================================
  // Compat Bit Operations
  // =====================================================================
  // --- Bit Operations ---
  {
    ArchState s = {};
    s.rax = 0x12345678;
    s.rbx = 0x00000005;
    s.rflags = initial_flags();

    // BT EAX, imm8=5: 0F BA E0 05
    add("compat bt eax,5", {0x0F, 0xBA, 0xE0, 0x05}, with_gpr_inputs(s, {&ArchState::rax}), FL_CF_ZF);
    // BTS EAX, EBX: 0F AB D8
    add("compat bts eax,ebx", {0x0F, 0xAB, 0xD8}, s, FL_CF_ZF);
    // BSF EAX, EBX: 0F BC C3
    {
      ArchState bs = {};
      bs.rbx = 0x00001000;
      bs.rflags = initial_flags();
      add("compat bsf eax,ebx", {0x0F, 0xBC, 0xC3}, bs, FL_ZF);
    }
    // BSR EAX, EBX: 0F BD C3
    {
      ArchState bs = {};
      bs.rbx = 0x00001000;
      bs.rflags = initial_flags();
      add("compat bsr eax,ebx", {0x0F, 0xBD, 0xC3}, bs, FL_ZF);
    }
    // POPCNT EAX, EBX: F3 0F B8 C3
    {
      ArchState pc = {};
      pc.rbx = 0x12345678;
      pc.rflags = initial_flags();
      add("compat popcnt eax,ebx", {0xF3, 0x0F, 0xB8, 0xC3}, pc, FL_ALL);
    }
  }

  // =====================================================================
  // Compat String Operations
  // Uses ESI/EDI (32-bit), ECX count
  // =====================================================================
  // --- String Operations ---
  {
    // REP STOSB: fill memory at EDI with AL, ECX times
    {
      ArchState s = {};
      s.rax = 0x42;        // AL = 0x42
      s.rcx = 8;           // count
      s.rdi = DATA_ADDR;   // destination
      s.rflags = initial_flags();      // DF=0 -> forward
      add_mem("compat rep stosb", {0xF3, 0xAA}, s, FL_ALL, {}, 8);
    }
    // REP MOVSB: copy ECX bytes from ESI to EDI
    {
      ArchState s = {};
      s.rcx = 4;
      s.rsi = DATA_ADDR;       // source
      s.rdi = DATA_ADDR + 16;  // destination
      s.rflags = initial_flags();
      std::vector<u8> data(32, 0);
      data[0] = 0x11; data[1] = 0x22; data[2] = 0x33; data[3] = 0x44;
      add_mem("compat rep movsb", {0xF3, 0xA4}, s, FL_ALL, data, 20);
    }
    // CMPSB: compare byte at ESI with byte at EDI
    {
      ArchState s = {};
      s.rsi = DATA_ADDR;
      s.rdi = DATA_ADDR + 4;
      s.rflags = initial_flags();
      std::vector<u8> data(8, 0);
      data[0] = 0x42;
      data[4] = 0x42;  // same value -> ZF=1
      add_mem("compat cmpsb (equal)", {0xA6}, s, FL_ALL, data, 0);
    }
    // SCASB: compare AL with byte at EDI
    {
      ArchState s = {};
      s.rax = 0x42;
      s.rdi = DATA_ADDR;
      s.rflags = initial_flags();
      std::vector<u8> data(4, 0);
      data[0] = 0x42;
      add_mem("compat scasb (equal)", {0xAE}, s, FL_ALL, data, 0);
    }
  }

  // =====================================================================
  // Compat Multiply/Divide
  // =====================================================================
  // --- Multiply/Divide ---
  {
    // MUL EBX: EDX:EAX = EAX * EBX (unsigned)
    {
      ArchState s = {};
      s.rax = 100;
      s.rbx = 200;
      s.rflags = initial_flags();
      // F7 E3: MUL EBX (mod=11, reg=100=/4=MUL, rm=011=EBX)
      add("compat mul ebx", {0xF7, 0xE3}, s, FL_CF_OF);
    }
    // IMUL EBX: EDX:EAX = EAX * EBX (signed)
    {
      ArchState s = {};
      s.rax = (u64)(u32)(-50);
      s.rbx = 3;
      s.rflags = initial_flags();
      // F7 EB: IMUL EBX (mod=11, reg=101=/5=IMUL, rm=011=EBX)
      add("compat imul ebx", {0xF7, 0xEB}, s, FL_CF_OF);
    }
    // DIV EBX: EAX = EDX:EAX / EBX, EDX = remainder
    {
      ArchState s = {};
      s.rax = 1000;
      s.rdx = 0;
      s.rbx = 7;
      s.rflags = initial_flags();
      // F7 F3: DIV EBX (mod=11, reg=110=/6=DIV, rm=011=EBX)
      add("compat div ebx", {0xF7, 0xF3}, s, FL_NONE);
    }
    // IDIV EBX: signed divide
    {
      ArchState s = {};
      s.rax = (u64)(u32)(-100);
      s.rdx = 0xFFFFFFFF;  // sign-extend
      s.rbx = 7;
      s.rflags = initial_flags();
      // F7 FB: IDIV EBX (mod=11, reg=111=/7=IDIV, rm=011=EBX)
      add("compat idiv ebx", {0xF7, 0xFB}, s, FL_NONE);
    }
    // MUL with overflow: EDX should be non-zero
    {
      ArchState s = {};
      s.rax = 0x10000;
      s.rbx = 0x10000;
      s.rflags = initial_flags();
      add("compat mul ebx (overflow)", {0xF7, 0xE3}, s, FL_CF_OF);
    }
  }

  // =====================================================================
  // Compat CMOVcc/SETcc
  // =====================================================================
  // --- CMOVcc/SETcc ---
  {
    // CMOVZ EAX, EBX: 0F 44 C3 (ZF=1 -> move)
    {
      ArchState s = {};
      s.rax = 0x11111111;
      s.rbx = 0x22222222;
      s.rflags = initial_flags(FL_ZF, FL_ZF);
      add("compat cmovz eax,ebx (taken)", {0x0F, 0x44, 0xC3},
          with_gpr_inputs(s, {&ArchState::rbx}), FL_ALL);
    }
    // CMOVZ EAX, EBX: 0F 44 C3 (ZF=0 -> no move)
    {
      ArchState s = {};
      s.rax = 0x11111111;
      s.rbx = 0x22222222;
      s.rflags = initial_flags(FL_ZF, 0);
      add("compat cmovz eax,ebx (not taken)", {0x0F, 0x44, 0xC3},
          with_gpr_inputs(s, {&ArchState::rbx}), FL_ALL);
    }
    // SETZ AL: 0F 94 C0 (ZF=1 -> AL=1)
    {
      ArchState s = {};
      s.rax = 0xDEADBEEF;
      s.rflags = initial_flags(FL_ZF, FL_ZF);
      add("compat setz al (ZF=1)", {0x0F, 0x94, 0xC0}, with_gpr_inputs(s, {}), FL_ALL);
    }
    // SETZ AL: ZF=0 -> AL=0
    {
      ArchState s = {};
      s.rax = 0xDEADBEEF;
      s.rflags = initial_flags(FL_ZF, 0);
      add("compat setz al (ZF=0)", {0x0F, 0x94, 0xC0}, with_gpr_inputs(s, {}), FL_ALL);
    }
  }

  // =====================================================================
  // Compat XCHG/XADD/CMPXCHG
  // =====================================================================
  // --- XCHG/XADD/CMPXCHG ---
  {
    // XCHG EAX, EBX: 93 (single-byte XCHG with EAX)
    {
      ArchState s = {};
      s.rax = 0x11111111;
      s.rbx = 0x22222222;
      s.rflags = initial_flags();
      add("compat xchg eax,ebx", {0x93}, s, FL_ALL);
    }
    // XADD [mem], EAX: 0F C1 03 (mod=00, rm=EBX)
    {
      ArchState s = {};
      s.rax = 5;
      s.rbx = DATA_ADDR;
      s.rflags = initial_flags();
      std::vector<u8> data(8, 0);
      u32 val = 10;
      memcpy(data.data(), &val, 4);
      add_mem("compat xadd [ebx],eax", {0x0F, 0xC1, 0x03}, s, FL_ALL, data, 4);
    }
    // CMPXCHG [mem], EBX: 0F B1 1B (mod=00, rm=EBX) — wait, this uses EBX as both
    // Let's use: CMPXCHG [EDI], EBX
    // 0F B1 1F: mod=00, reg=011(EBX), rm=111(EDI)
    {
      ArchState s = {};
      s.rax = 10;  // comparand
      s.rbx = 20;  // new value
      s.rdi = DATA_ADDR;
      s.rflags = initial_flags();
      std::vector<u8> data(8, 0);
      u32 val = 10;  // matches EAX -> exchange happens
      memcpy(data.data(), &val, 4);
      add_mem("compat cmpxchg [edi],ebx (match)", {0x0F, 0xB1, 0x1F}, s, FL_ALL, data, 4);
    }
    {
      ArchState s = {};
      s.rax = 10;  // comparand
      s.rbx = 20;  // new value
      s.rdi = DATA_ADDR;
      s.rflags = initial_flags();
      std::vector<u8> data(8, 0);
      u32 val = 99;  // does NOT match EAX -> no exchange, EAX loaded with [EDI]
      memcpy(data.data(), &val, 4);
      add_mem("compat cmpxchg [edi],ebx (no match)", {0x0F, 0xB1, 0x1F}, s, FL_ALL, data, 4);
    }
  }

  // =====================================================================
  // Compat SSE/SSE2
  // Legacy SSE in compat mode with 32-bit addressing
  // =====================================================================
  // --- SSE/SSE2 ---
  {
    // ADDPS XMM0, XMM1: 0F 58 C1
    {
      ArchState s = {};
      s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);
      add_xmm("compat addps xmm0,xmm1", {0x0F, 0x58, 0xC1}, s, 0x3);
    }
    // ADDPD XMM0, [EAX]: 66 0F 58 00 (mod=00, rm=000(EAX))
    {
      ArchState s = {};
      s.rax = DATA_ADDR;
      s.rflags = initial_flags();
      s.xmm[0] = xmm_from_f64(1.0, 2.0);
      // Store 3.0 and 4.0 at DATA_ADDR
      std::vector<u8> data(16, 0);
      double v1 = 3.0, v2 = 4.0;
      memcpy(data.data(), &v1, 8);
      memcpy(data.data() + 8, &v2, 8);
      TestCase tc;
      tc.name = "compat addpd xmm0,[eax]";
      tc.category = cat;
      tc.code = {0x66, 0x0F, 0x58, 0x00};
      tc.initial = s;
      tc.flags_mask = FL_ALL;
      tc.xmm_mask = 0x1;
      tc.init_data = data;
      tc.compat_mode = true;
      tests.push_back(std::move(tc));
    }
    // MOVAPS [EAX], XMM0: 0F 29 00 (store via 32-bit addr)
    {
      ArchState s = {};
      s.rax = DATA_ADDR;
      s.rflags = initial_flags();
      s.xmm[0] = xmm_from_f32(1.5f, 2.5f, 3.5f, 4.5f);
      add_mem("compat movaps [eax],xmm0", {0x0F, 0x29, 0x00}, s, FL_ALL, {}, 16);
    }
  }

  // =====================================================================
  // Compat Write to 32-bit Register
  // SDM §3.4.1.1: Writing 32-bit register zero-extends to 64-bit
  // =====================================================================
  // --- Write to 32-bit Register ---
  {
    // MOV EAX, 1 with upper RAX bits set: upper 32 bits should clear
    {
      ArchState s = {};
      s.rax = 0xDEADBEEF00000000ULL;
      s.rflags = initial_flags();
      // MOV EAX, 1: B8 01 00 00 00
      add("compat mov eax,1 (upper cleared)", {0xB8, 0x01, 0x00, 0x00, 0x00},
          with_gpr_inputs(s, {}), FL_ALL);
    }
    // ADD EAX, 0 with upper RAX set
    {
      ArchState s = {};
      s.rax = 0xDEADBEEF00000005ULL;
      s.rbx = 0;
      s.rflags = initial_flags();
      add("compat add eax,0 (upper cleared)", {0x01, 0xD8}, s);
    }
    // XOR EAX, EAX with upper RAX set
    {
      ArchState s = {};
      s.rax = 0xFFFFFFFFFFFFFFFFULL;
      s.rflags = initial_flags();
      add("compat xor eax,eax (upper cleared)", {0x31, 0xC0}, with_gpr_inputs(s, {}));
    }
    // INC EAX (40h) with upper RAX set
    {
      ArchState s = {};
      s.rax = 0xDEADBEEF00000001ULL;
      s.rflags = initial_flags();
      add("compat inc eax (upper cleared)", {0x40}, s, FL_ALL);
    }
    // MOV to 16-bit: should NOT clear upper bits
    {
      ArchState s = {};
      s.rax = 0xDEADBEEF12340000ULL;
      s.rbx = 0x5678;
      s.rflags = initial_flags();
      // MOV AX, BX: 66 89 D8 (mov r/m16, r16 with ModRM D8 = mod=11, reg=BX, rm=AX)
      add("compat mov ax,bx (upper preserved)", {0x66, 0x89, 0xD8},
          with_gpr_inputs(s, {&ArchState::rbx}), FL_ALL);
    }
    // MOV to 8-bit: should NOT clear upper bits
    {
      ArchState s = {};
      s.rax = 0xDEADBEEF12345600ULL;
      s.rbx = 0x78;
      s.rflags = initial_flags();
      // MOV AL, BL: 88 D8
      add("compat mov al,bl (upper preserved)", {0x88, 0xD8},
          with_gpr_inputs(s, {&ArchState::rbx}), FL_ALL);
    }
  }

  // =====================================================================
  // Compat Upper RSP Behavior
  // When upper RSP bits are set, PUSH/POP should use only ESP
  // =====================================================================
  // --- Upper RSP Behavior ---
  {
    // PUSH with upper RSP bits set: only ESP used
    {
      ArchState s = {};
      s.rax = 0x12345678;
      s.rsp = STACK_TOP;  // Clean ESP, upper bits 0
      s.rflags = initial_flags();
      // PUSH EAX + POP EBX round-trip
      add("compat push/pop with clean rsp", {0x50, 0x5B}, s, FL_ALL);
    }
  }

  // =====================================================================
  // Compat PUSH/POP Segment
  // =====================================================================
  // --- PUSH/POP Segment ---
  {
    // PUSH FS (0F A0) + POP FS (0F A1)
    {
      ArchState s = {};
      add("compat push fs; pop fs", {0x0F, 0xA0, 0x0F, 0xA1}, s, FL_ALL);
    }
    // PUSH GS (0F A8) + POP GS (0F A9)
    {
      ArchState s = {};
      add("compat push gs; pop gs", {0x0F, 0xA8, 0x0F, 0xA9}, s, FL_ALL);
    }
  }

  // =====================================================================
  // Compat VEX in 32-bit mode
  // VEX is valid when C4/C5 byte2 has mod=11 (R/X/B must be 1 = no R8-R15)
  // =====================================================================
  // --- VEX in 32-bit mode ---
  {
    // VADDPS XMM0, XMM1, XMM2: C5 F0 58 C2
    // VEX.R=1, VEX.vvvv=0001 (XMM1), L=0 (128), pp=00
    {
      ArchState s = {};
      s.xmm[0] = {};
      s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      s.xmm[2] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
      add_xmm("compat vaddps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x58, 0xC2}, with_vector_inputs(s, 0x6), 0x7);
    }
    // VADDPS YMM0, YMM1, YMM2: C5 F4 58 C2 (L=1 for 256-bit)
    {
      ArchState s = {};
      s.xmm[0] = {};
      s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      s.xmm[2] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
      add_xmm("compat vaddps ymm0,ymm1,ymm2", {0xC5, 0xF4, 0x58, 0xC2}, with_vector_inputs(s, 0x6), 0x7);
    }
  }

  // =====================================================================
  // Mode Transition Tests
  // Verify that IRET/SYSRET correctly switch cur_mode.
  // These start in 64-bit mode (compat_mode=false) and transition
  // to compat mode mid-test via IRET.
  // =====================================================================

  // --- IRET 64-bit -> compat mode ---
  // Build an IRET frame at DATA_ADDR targeting CS=0x48 (compat).
  // After IRETQ, 0x40 should be decoded as INC EAX (compat mode),
  // not as a REX prefix (64-bit mode). If cur_mode isn't updated,
  // 0x40 is a no-op REX and RAX stays unchanged.
  {
    // Code layout:
    //   offset  0: mov rsp, DATA_ADDR  (48 BC <imm64>) — 10 bytes
    //   offset 10: iretq               (48 CF)         — 2 bytes
    //   offset 12: inc eax             (40)            — compat mode target
    //   offset 13: (HLT appended by harness)
    u64 compat_rip = CODE_ADDR + 12;
    std::vector<u8> code = {
      0x48, 0xBC,  // mov rsp, imm64
      (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
      (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
      0x00, 0x00, 0x00, 0x00,
      0x48, 0xCF,  // iretq
      0x40,        // INC EAX (compat) / REX (64-bit no-op)
    };

    // IRET frame at DATA_ADDR: RIP, CS, RFLAGS, RSP, SS (each 8 bytes)
    std::vector<u8> data(40, 0);
    u64 iret_rip = compat_rip;
    u64 iret_cs  = 0x48;   // 32-bit compat code segment
    u64 iret_rfl = 0x02;
    u64 iret_rsp = STACK_TOP;
    u64 iret_ss  = 0x10;   // data segment
    memcpy(data.data() +  0, &iret_rip, 8);
    memcpy(data.data() +  8, &iret_cs, 8);
    memcpy(data.data() + 16, &iret_rfl, 8);
    memcpy(data.data() + 24, &iret_rsp, 8);
    memcpy(data.data() + 32, &iret_ss, 8);

    // Start in 64-bit mode with RAX=0x41. After INC EAX, RAX should be 0x42.
    // If mode switch fails, 0x40 is REX prefix (no-op) and RAX stays 0x41.
    TestCase tc;
    tc.name = "iret 64->compat: INC EAX via 0x40";
    tc.category = cat;
    tc.code = code;
    tc.initial = {};
    tc.initial.rax = 0x41;
    tc.initial.rflags = initial_flags();
    tc.flags_mask = FL_ALL;
    tc.init_data = data;
    tc.compat_mode = false;  // starts in 64-bit mode
    tests.push_back(std::move(tc));
  }

  // Same test but verify DEC via 0x48 (which is REX.W in 64-bit mode).
  // In compat mode: DEC EAX. In 64-bit mode: REX.W prefix (no-op by itself).
  {
    u64 compat_rip = CODE_ADDR + 12;
    std::vector<u8> code = {
      0x48, 0xBC,
      (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
      (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
      0x00, 0x00, 0x00, 0x00,
      0x48, 0xCF,  // iretq
      0x48,        // DEC EAX (compat) / REX.W (64-bit)
    };

    std::vector<u8> data(40, 0);
    u64 iret_rip = compat_rip;
    u64 iret_cs  = 0x48;
    u64 iret_rfl = 0x02;
    u64 iret_rsp = STACK_TOP;
    u64 iret_ss  = 0x10;
    memcpy(data.data() +  0, &iret_rip, 8);
    memcpy(data.data() +  8, &iret_cs, 8);
    memcpy(data.data() + 16, &iret_rfl, 8);
    memcpy(data.data() + 24, &iret_rsp, 8);
    memcpy(data.data() + 32, &iret_ss, 8);

    TestCase tc;
    tc.name = "iret 64->compat: DEC EAX via 0x48";
    tc.category = cat;
    tc.code = code;
    tc.initial = {};
    tc.initial.rax = 0x41;
    tc.initial.rflags = initial_flags();
    tc.flags_mask = FL_ALL;
    tc.init_data = data;
    tc.compat_mode = false;
    tests.push_back(std::move(tc));
  }

  // IRET 64->compat: verify 32-bit address size (mod=00 rm=5 is [disp32] not [RIP+disp32])
  {
    // After IRET to compat mode, MOV EAX,[disp32] should use absolute addressing.
    // disp32 = DATA_ADDR+40 (past the IRET frame). Store a known value there.
    u64 compat_rip = CODE_ADDR + 12;
    u64 load_addr = DATA_ADDR + 40;
    std::vector<u8> code = {
      0x48, 0xBC,
      (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
      (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
      0x00, 0x00, 0x00, 0x00,
      0x48, 0xCF,  // iretq
      // Compat code: MOV EAX, [disp32]  (8B 05 <disp32>)
      0x8B, 0x05,
      (u8)(load_addr), (u8)(load_addr >> 8),
      (u8)(load_addr >> 16), (u8)(load_addr >> 24),
    };

    std::vector<u8> data(48, 0);
    u64 iret_rip = compat_rip;
    u64 iret_cs  = 0x48;
    u64 iret_rfl = 0x02;
    u64 iret_rsp = STACK_TOP;
    u64 iret_ss  = 0x10;
    memcpy(data.data() +  0, &iret_rip, 8);
    memcpy(data.data() +  8, &iret_cs, 8);
    memcpy(data.data() + 16, &iret_rfl, 8);
    memcpy(data.data() + 24, &iret_rsp, 8);
    memcpy(data.data() + 32, &iret_ss, 8);
    // Known value at DATA_ADDR+40
    u32 magic = 0xCAFE1234;
    memcpy(data.data() + 40, &magic, 4);

    TestCase tc;
    tc.name = "iret 64->compat: MOV EAX,[disp32] absolute";
    tc.category = cat;
    tc.code = code;
    tc.initial = {};
    tc.initial.rflags = initial_flags();
    tc.flags_mask = FL_ALL;
    tc.init_data = data;
    tc.compat_mode = false;
    tests.push_back(std::move(tc));
  }

  // --- LEA in compat mode ---
  // LEA computes the effective address without adding segment base.
  // With flat segments (base=0), LEA [EBP+ECX*4+0x10] should return
  // EBP + ECX*4 + 0x10.
  {
    ArchState s = {};
    s.rbp = 0x1000;
    s.rcx = 0x20;
    s.rflags = initial_flags();
    // LEA EAX, [EBP+ECX*4+0x10] = 8D 44 8D 10
    add("compat lea eax,[ebp+ecx*4+0x10]",
        {0x8D, 0x44, 0x8D, 0x10}, s, FL_ALL);
  }

  // --- Memory load/store in compat mode ---
  // MOV EAX, [EDI] where EDI points to data area
  {
    ArchState s = {};
    s.rdi = DATA_ADDR;
    s.rflags = initial_flags();
    std::vector<u8> data(8, 0);
    u32 magic = 0xDEADBEEF;
    memcpy(data.data(), &magic, 4);
    add_mem("compat mov eax,[edi]", {0x8B, 0x07}, s, FL_ALL, data, 0);
  }

  // --- 32-bit push/pop in compat mode ---
  {
    ArchState s = {};
    s.rax = 0x12345678;
    s.rflags = initial_flags();
    // PUSH EAX; POP EBX  (50 5B)
    add("compat push eax; pop ebx", {0x50, 0x5B}, s, FL_ALL);
  }

  // --- IRET CPL 0 -> CPL 3 (user mode) with 64-bit CS ---
  // This tests that the GDT descriptor read during IRET happens before
  // the CPL change. If cur_cpl is set to 3 before reading the GDT,
  // the mem_read32 of the supervisor-only GDT page faults (#PF).
  // The user-mode code does UD2 to trigger #UD, which the IDT handler
  // catches and HLTs. We verify we get #UD (vector 6), not #PF (vector 14).
  {
    // Code layout (64-bit mode):
    //   offset  0: mov rsp, DATA_ADDR  (48 BC <imm64>) — 10 bytes
    //   offset 10: iretq               (48 CF)         — 2 bytes
    //   offset 12: ud2                  (0F 0B)         — user-mode target
    u64 user_rip = CODE_ADDR + 12;
    std::vector<u8> code = {
      0x48, 0xBC,
      (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
      (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
      0x00, 0x00, 0x00, 0x00,
      0x48, 0xCF,  // iretq
      0x0F, 0x0B,  // ud2 (at CPL 3)
    };

    // IRET frame: RIP, CS, RFLAGS, RSP, SS
    std::vector<u8> data(40, 0);
    u64 iret_rip = user_rip;
    u64 iret_cs  = 0x53;       // 64-bit user code (DPL=3, RPL=3)
    u64 iret_rfl = 0x02;
    u64 iret_rsp = STACK_TOP;
    u64 iret_ss  = 0x5B;       // user data (DPL=3, RPL=3)
    memcpy(data.data() +  0, &iret_rip, 8);
    memcpy(data.data() +  8, &iret_cs, 8);
    memcpy(data.data() + 16, &iret_rfl, 8);
    memcpy(data.data() + 24, &iret_rsp, 8);
    memcpy(data.data() + 32, &iret_ss, 8);

    TestCase tc;
    tc.name = "iret 64->user64: GDT read before CPL change";
    tc.category = cat;
    tc.code = code;
    tc.initial = {};
    tc.initial.rflags = initial_flags();
    tc.flags_mask = FL_ALL;
    tc.init_data = data;
    tc.expect_fault = true;
    tc.expected_vector = 6;  // #UD from ud2, NOT #PF from GDT read
    tc.compat_mode = false;
    tests.push_back(std::move(tc));
  }

  // =====================================================================
  // BCD Instructions (DAA, DAS, AAA, AAS, AAM, AAD)
  // These are invalid in 64-bit mode; must run in compat mode.
  // OF is undefined for DAA/DAS; OF/SF/ZF/PF are undefined for AAA/AAS.
  // =====================================================================
  cat = "BCD";
  {
    // Flag masks for BCD instructions
    constexpr u64 FL_DAA_DAS = FL_CF | FL_AF | FL_SF | FL_ZF | FL_PF;  // OF undefined
    constexpr u64 FL_AAA_AAS = FL_CF | FL_AF;  // OF, SF, ZF, PF undefined
    constexpr u64 FL_AAM_AAD = FL_SF | FL_ZF | FL_PF;  // OF, AF, CF undefined

    // --- DAA (opcode 0x27) ---
    // SDM example: AL=AEh, AF=0, CF=0 -> AL=14h, AF=1, CF=1
    {
      ArchState s = {};
      s.rax = 0xAE;
      s.rflags = initial_flags(FL_CF | FL_AF, 0);
      add("daa AE -> 14h CF=1 AF=1", {0x27}, s, FL_DAA_DAS);
    }
    // AL=0x79, AF=0, CF=0 -> low nibble 9, no adjust for low nibble
    // 0x79 > 0x99 -> no high nibble adjust either; result=0x79
    {
      ArchState s = {};
      s.rax = 0x79;
      s.rflags = initial_flags(FL_CF | FL_AF, 0);
      add("daa 79 -> 79", {0x27}, s, FL_DAA_DAS);
    }
    // AL=0x09 with AF=1: low nibble adjust -> 0x0F
    {
      ArchState s = {};
      s.rax = 0x09;
      s.rflags = initial_flags(FL_CF | FL_AF, FL_AF);
      add("daa 09 AF=1 -> 0F", {0x27}, s, FL_DAA_DAS);
    }
    // AL=0x9A: low nibble > 9 -> AL=A0h, AF=1; A0>99 with old_CF=0? old_AL=9A>99 -> +60 -> result=00, CF=1
    {
      ArchState s = {};
      s.rax = 0x9A;
      s.rflags = initial_flags(FL_CF | FL_AF, 0);
      add("daa 9A -> 00 CF=1", {0x27}, s, FL_DAA_DAS);
    }
    // AL=0x00 with CF=1: high nibble adjust -> +60h -> 60h, CF=1
    {
      ArchState s = {};
      s.rax = 0x00;
      s.rflags = initial_flags(FL_CF | FL_AF, FL_CF);
      add("daa 00 CF=1 -> 60", {0x27}, s, FL_DAA_DAS);
    }
    // AL=0xFF with CF=0, AF=0: low>9 -> +6=05, carry=1; old_AL=FF>99 -> +60=65, CF=1
    {
      ArchState s = {};
      s.rax = 0xFF;
      s.rflags = initial_flags(FL_CF | FL_AF, 0);
      add("daa FF -> 65 CF=1", {0x27}, s, FL_DAA_DAS);
    }
    // AL=0x73, AF=0, CF=0: no adjustments
    {
      ArchState s = {};
      s.rax = 0x73;
      s.rflags = initial_flags(FL_CF | FL_AF, 0);
      add("daa 73 -> 73", {0x27}, s, FL_DAA_DAS);
    }

    // --- DAS (opcode 0x2F) ---
    // AL=0x35 with CF=0, AF=0: no adjustments
    {
      ArchState s = {};
      s.rax = 0x35;
      s.rflags = initial_flags(FL_CF | FL_AF, 0);
      add("das 35 -> 35", {0x2F}, s, FL_DAA_DAS);
    }
    // AL=0x00 with CF=1: old_CF=1 -> -60h = A0h, CF=1
    {
      ArchState s = {};
      s.rax = 0x00;
      s.rflags = initial_flags(FL_CF | FL_AF, FL_CF);
      add("das 00 CF=1 -> A0", {0x2F}, s, FL_DAA_DAS);
    }
    // AL=0x0A: low nibble > 9 -> -6 = 04, AF=1
    {
      ArchState s = {};
      s.rax = 0x0A;
      s.rflags = initial_flags(FL_CF | FL_AF, 0);
      add("das 0A -> 04", {0x2F}, s, FL_DAA_DAS);
    }
    // AL=0xFF with CF=0, AF=0: low>9 -> -6=F9, borrow=0 (FF-6=F9, no borrow)
    // old_AL=FF > 99 -> -60=99, CF=1
    {
      ArchState s = {};
      s.rax = 0xFF;
      s.rflags = initial_flags(FL_CF | FL_AF, 0);
      add("das FF -> 99", {0x2F}, s, FL_DAA_DAS);
    }
    // AL=0x05, AF=1 -> -6 = FF (borrow), CF=old_CF|borrow=1; old_AL=05 <= 99 -> no high adj
    {
      ArchState s = {};
      s.rax = 0x05;
      s.rflags = initial_flags(FL_CF | FL_AF, FL_AF);
      add("das 05 AF=1 -> FF CF=1", {0x2F}, s, FL_DAA_DAS);
    }

    // --- AAA (opcode 0x37) ---
    // AX=0x0109: low nibble 9 <= 9, AF=0 -> no adjust, AL=09&0F=09
    {
      ArchState s = {};
      s.rax = 0x0109;
      s.rflags = initial_flags(FL_AF, 0);
      add("aaa AX=0109 -> AX=0109", {0x37}, s, FL_AAA_AAS);
    }
    // AX=0x010A: low nibble A > 9 -> AX+=106h=0210h, AL&=0F -> AL=00, AH=02
    {
      ArchState s = {};
      s.rax = 0x010A;
      s.rflags = initial_flags(FL_AF, 0);
      add("aaa AX=010A -> AX=0200", {0x37}, s, FL_AAA_AAS);
    }
    // AX=0x0005 with AF=1 -> AX+=106h=010Bh, AL&=0F -> AL=0B, AH=01
    {
      ArchState s = {};
      s.rax = 0x0005;
      s.rflags = initial_flags(FL_AF, FL_AF);
      add("aaa AX=0005 AF=1 -> AX=010B", {0x37}, s, FL_AAA_AAS);
    }
    // AX=0xFF0F with AF=0: low nibble F > 9 -> AX+=106h=0015h, AL&=0F -> AL=05, AH=00
    {
      ArchState s = {};
      s.rax = 0xFF0F;
      s.rflags = initial_flags(FL_AF, 0);
      add("aaa AX=FF0F -> AX=0005", {0x37}, s, FL_AAA_AAS);
    }

    // --- AAS (opcode 0x3F) ---
    // AX=0x0109: low nibble 9, AF=0 -> no adjust, AL&=0F -> AL=09
    {
      ArchState s = {};
      s.rax = 0x0109;
      s.rflags = initial_flags(FL_AF, 0);
      add("aas AX=0109 -> AX=0109", {0x3F}, s, FL_AAA_AAS);
    }
    // AX=0x020A: low nibble A > 9 -> AX-=6=0204, AH-=1=0104, AL&=0F=04
    {
      ArchState s = {};
      s.rax = 0x020A;
      s.rflags = initial_flags(FL_AF, 0);
      add("aas AX=020A -> AX=0104", {0x3F}, s, FL_AAA_AAS);
    }
    // AX=0x0100 with AF=1 -> AX-=6=00FA, AH-=1=FFFA, AL&=0F=0A -> AX=FF0A
    {
      ArchState s = {};
      s.rax = 0x0100;
      s.rflags = initial_flags(FL_AF, FL_AF);
      add("aas AX=0100 AF=1 -> AX=FF0A", {0x3F}, s, FL_AAA_AAS);
    }

    // --- AAM (opcode 0xD4 imm8) ---
    // Standard AAM (imm8=0x0A): AL=35 -> AH=35/10=3, AL=35%10=5 -> AX=0305
    {
      ArchState s = {};
      s.rax = 0x23;  // 35 decimal
      s.rflags = initial_flags();
      add("aam 0A AL=23h(35) -> AX=0305", {0xD4, 0x0A}, s, FL_AAM_AAD);
    }
    // AAM with AL=0: AH=0, AL=0
    {
      ArchState s = {};
      s.rax = 0x00;
      s.rflags = initial_flags();
      add("aam 0A AL=00 -> AX=0000", {0xD4, 0x0A}, s, FL_AAM_AAD);
    }
    // AAM with AL=FF (255): AH=255/10=25, AL=255%10=5 -> AH=0x19, AL=0x05
    {
      ArchState s = {};
      s.rax = 0xFF;
      s.rflags = initial_flags();
      add("aam 0A AL=FF -> AX=1905", {0xD4, 0x0A}, s, FL_AAM_AAD);
    }
    // AAM with non-standard base (imm8=0x10): AL=0x37 -> AH=0x37/16=3, AL=0x37%16=7
    {
      ArchState s = {};
      s.rax = 0x37;
      s.rflags = initial_flags();
      add("aam 10 AL=37h -> AX=0307", {0xD4, 0x10}, s, FL_AAM_AAD);
    }
    // AAM with imm8=0: should #DE
    {
      TestCase tc;
      tc.name = "aam 00 -> #DE";
      tc.category = cat;
      tc.code = {0xD4, 0x00};
      tc.initial = {};
      tc.initial.rflags = initial_flags();
      tc.flags_mask = FL_ALL;
      tc.compat_mode = true;
      tc.expect_fault = true;
      tc.expected_vector = 0;  // #DE = vector 0
      tests.push_back(std::move(tc));
    }

    // --- AAD (opcode 0xD5 imm8) ---
    // Standard AAD (imm8=0x0A): AX=0305 -> AL=(5+3*10)&FF=35=0x23, AH=0
    {
      ArchState s = {};
      s.rax = 0x0305;
      s.rflags = initial_flags();
      add("aad 0A AX=0305 -> AL=23h", {0xD5, 0x0A}, s, FL_AAM_AAD);
    }
    // AAD with AX=0000 -> AL=0, AH=0
    {
      ArchState s = {};
      s.rax = 0x0000;
      s.rflags = initial_flags();
      add("aad 0A AX=0000 -> AL=00", {0xD5, 0x0A}, s, FL_AAM_AAD);
    }
    // AAD with AX=0901 -> AL=(1+9*10)&FF=91=0x5B, AH=0
    {
      ArchState s = {};
      s.rax = 0x0901;
      s.rflags = initial_flags();
      add("aad 0A AX=0901 -> AL=5Bh", {0xD5, 0x0A}, s, FL_AAM_AAD);
    }
    // AAD with non-standard base (imm8=0x10): AX=0305 -> AL=(5+3*16)&FF=53=0x35, AH=0
    {
      ArchState s = {};
      s.rax = 0x0305;
      s.rflags = initial_flags();
      add("aad 10 AX=0305 -> AL=35h", {0xD5, 0x10}, s, FL_AAM_AAD);
    }
    // AAD overflow: AX=FF01 -> AL=(1+255*10)&FF=(2551)&FF=0xF7, AH=0
    {
      ArchState s = {};
      s.rax = 0xFF01;
      s.rflags = initial_flags();
      add("aad 0A AX=FF01 -> AL=F7h", {0xD5, 0x0A}, s, FL_AAM_AAD);
    }
  }

  // =====================================================================
  // RETF — Far return in compatibility mode (same-privilege)
  // CS selector 0x48 = 32-bit code segment (CS.D=1).
  // =====================================================================
  cat = "RETF compat";

  // Compat RETF (CB) — 32-bit operand size (default, CS.D=1)
  // Stack: [EIP (4)] [CS (4)]
  // Use push to build the stack frame (push is 32-bit in compat mode).
  // push 0x48           ; 6A 48  — CS selector
  // push <eip>          ; 68 xx xx xx xx — return EIP
  // retf                ; CB
  // HLT                 ; F4
  // Offsets: push(2) + push(5) + retf(1) = 8. HLT at offset 8.
  {
    u32 compat_code = 0x10000;
    u32 ret_eip = compat_code + 8;
    ArchState s = {};
    s.rsp = STACK_TOP;
    s.rflags = initial_flags();
    add("compat retf (32-bit opsize)",
        {0x6A, 0x48,                              // push 0x48 (CS)
         0x68,                                     // push imm32 (EIP)
           (u8)(ret_eip), (u8)(ret_eip>>8),
           (u8)(ret_eip>>16), (u8)(ret_eip>>24),
         0xCB,                                    // retf
         0xF4},                                   // HLT
        s, FL_ALL);
  }

  // Compat RETF imm16=0x08 (CA 08 00) — 32-bit opsize, skip 8 extra bytes
  // Stack: [EIP (4)] [CS (4)] [padding (8)]
  // sub esp, 8          ; 83 EC 08  — padding for imm16
  // push 0x48           ; 6A 48  — CS selector
  // push <eip>          ; 68 xx xx xx xx — return EIP
  // retf 0x0008         ; CA 08 00
  // HLT
  // Offsets: sub(3) + push(2) + push(5) + retf(3) = 13. HLT at offset 13.
  {
    u32 compat_code = 0x10000;
    u32 ret_eip = compat_code + 13;
    ArchState s = {};
    s.rsp = STACK_TOP;
    s.rflags = initial_flags();
    add("compat retf imm16=0x08 (32-bit opsize)",
        {0x83, 0xEC, 0x08,                       // sub esp, 8 (padding)
         0x6A, 0x48,                              // push 0x48 (CS)
         0x68,                                     // push imm32 (EIP)
           (u8)(ret_eip), (u8)(ret_eip>>8),
           (u8)(ret_eip>>16), (u8)(ret_eip>>24),
         0xCA, 0x08, 0x00,                        // retf 0x0008
         0xF4},                                   // HLT
        s, FL_ALL);
  }

  // Compat RETF imm16=0 (CA 00 00) — should behave like plain RETF
  // push 0x48           ; 6A 48  — CS
  // push <eip>          ; 68 xx xx xx xx — EIP
  // retf 0x0000         ; CA 00 00
  // HLT
  // Offsets: push(2) + push(5) + retf(3) = 10. HLT at offset 10.
  {
    u32 compat_code = 0x10000;
    u32 ret_eip = compat_code + 10;
    ArchState s = {};
    s.rsp = STACK_TOP;
    s.rflags = initial_flags();
    add("compat retf imm16=0 (32-bit opsize)",
        {0x6A, 0x48,                              // push 0x48 (CS)
         0x68,                                     // push imm32 (EIP)
           (u8)(ret_eip), (u8)(ret_eip>>8),
           (u8)(ret_eip>>16), (u8)(ret_eip>>24),
         0xCA, 0x00, 0x00,                        // retf 0x0000
         0xF4},                                   // HLT
        s, FL_ALL);
  }

  // =====================================================================
  // ENTER/LEAVE — 32-bit compat mode
  // In compat mode (CS.D=1): default operand size=32, 66h->16
  // StackAddrSize=32 (uses ESP), push/pop size follows operand size.
  // =====================================================================
  cat = "Compat";
  {
    // ENTER 0, 0: push EBP, set EBP=ESP (no allocation)
    {
      ArchState s = {};
      s.rbp = 0xDEADBEEF;
      s.rflags = initial_flags();
      add("compat enter 0,0", {0xC8, 0x00, 0x00, 0x00}, s, FL_ALL);
    }

    // ENTER 16, 0: push EBP, set EBP=ESP, sub ESP,16
    {
      ArchState s = {};
      s.rbp = 0xDEADBEEF;
      s.rflags = initial_flags();
      add("compat enter 16,0", {0xC8, 0x10, 0x00, 0x00}, s, FL_ALL);
    }

    // ENTER 0, 1: nesting level 1
    {
      ArchState s = {};
      s.rbp = STACK_TOP - 64;
      s.rflags = initial_flags();
      add("compat enter 0,1", {0xC8, 0x00, 0x00, 0x01}, s, FL_ALL);
    }

    // ENTER 8, 2: nesting level 2
    {
      ArchState s = {};
      s.rbp = STACK_TOP - 64;
      s.rflags = initial_flags();
      add("compat enter 8,2", {0xC8, 0x08, 0x00, 0x02}, s, FL_ALL);
    }

    // ENTER with large allocation: ENTER 256, 0
    {
      ArchState s = {};
      s.rbp = 0x11223344;
      s.rflags = initial_flags();
      add("compat enter 256,0", {0xC8, 0x00, 0x01, 0x00}, s, FL_ALL);
    }

    // 66h ENTER 0, 0: 16-bit operand size in compat mode
    {
      ArchState s = {};
      s.rbp = 0xAABBCCDD;
      s.rflags = initial_flags();
      add("compat enter 0,0 (66h)", {0x66, 0xC8, 0x00, 0x00, 0x00}, s, FL_ALL);
    }

    // 66h ENTER 8, 0: 16-bit push + allocation
    {
      ArchState s = {};
      s.rbp = 0xAABBCCDD;
      s.rflags = initial_flags();
      add("compat enter 8,0 (66h)", {0x66, 0xC8, 0x08, 0x00, 0x00}, s, FL_ALL);
    }

    // 66h ENTER 0, 1: 16-bit with nesting level 1
    {
      ArchState s = {};
      s.rbp = STACK_TOP - 64;
      s.rflags = initial_flags();
      add("compat enter 0,1 (66h)", {0x66, 0xC8, 0x00, 0x00, 0x01}, s, FL_ALL);
    }
  }

  cat = "Compat";
  {
    // LEAVE: ESP = EBP, POP EBP (32-bit)
    {
      ArchState s = {};
      s.rbp = DATA_ADDR;
      s.rflags = initial_flags();
      std::vector<u8> data(16, 0);
      u32 saved_ebp = 0x12345678;
      memcpy(data.data(), &saved_ebp, 4);
      add_mem("compat leave", {0xC9}, s, FL_ALL, std::move(data), 0);
    }

    // 66h LEAVE: 16-bit operand size, POP BP (16-bit)
    {
      ArchState s = {};
      s.rbp = DATA_ADDR;
      s.rflags = initial_flags();
      std::vector<u8> data(16, 0);
      data[0] = 0x78; data[1] = 0x56;
      add_mem("compat leave (66h)", {0x66, 0xC9}, s, FL_ALL, std::move(data), 0);
    }

    // ENTER/LEAVE round-trip (32-bit)
    {
      ArchState s = {};
      s.rbp = 0xDEADBEEF;
      s.rflags = initial_flags();
      add("compat enter 0,0; leave", {0xC8, 0x00, 0x00, 0x00, 0xC9}, s, FL_ALL);
    }

    // ENTER/LEAVE round-trip (16-bit)
    {
      ArchState s = {};
      s.rbp = STACK_TOP - 128;
      s.rflags = initial_flags();
      add("compat enter 0,0; leave (66h)", {0x66, 0xC8, 0x00, 0x00, 0x00, 0x66, 0xC9}, s, FL_ALL);
    }
  }

  // =====================================================================
  // 62h in compatibility mode: EVEX vs. BOUND disambiguation
  //
  // SDM Vol.2 §2.7.11.2 (opcode-independent): outside 64-bit mode, 62h
  // is an EVEX prefix iff the next byte's top two bits (EVEX.R̄X̄) are
  // 11b; otherwise it is BOUND's ModR/M.  Nothing exercised this before:
  // the model used to decode 62h as BOUND unconditionally outside 64-bit
  // mode.  These cases compare both legs against silicon, plus the
  // legacy-mode EVEX bit rules (B̄/R'̄ and vvvv's top bit ignored).
  // =====================================================================
  cat = "Compat EVEX";
  {
    auto fill = [](ZmmVal &v, u64 seed) {
      for (int i = 0; i < 8; i++) v.q[i] = seed * (i + 1);
    };
    ArchState s = {};
    fill(s.xmm[1], 0x1111111122223333ULL);
    fill(s.xmm[2], 0x0F0F5A5AC3C36969ULL);

    // EVEX vpxord xmm0,xmm1,xmm2 — canonical legacy-legal encoding
    // (62 F1 75 08 EF C2: R̄X̄=11, B̄=1, R'̄=1, v̄v̄v̄v̄=~1, V'̄=1)
    add_xmm("compat evex vpxord xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xEF, 0xC2}, s, 0x7);

    // EVEX vpaddd zmm0,zmm1,zmm2 — 512-bit in compatibility mode
    add_xmm("compat evex vpaddd zmm0,zmm1,zmm2",
            {0x62, 0xF1, 0x75, 0x48, 0xFE, 0xC2}, s, 0x7);

    // EVEX.B̄=0: ignored outside 64-bit mode (cannot extend rm), so this
    // must behave exactly like the B̄=1 encoding above
    add_xmm("compat evex vpxord (B'=0 ignored)",
            {0x62, 0xD1, 0x75, 0x08, 0xEF, 0xC2}, s, 0x7);

    // v̄v̄v̄v̄ top bit (P[14]) = 0: ignored outside 64-bit mode, so vvvv
    // reads as 1 (xmm1), not 9
    add_xmm("compat evex vpxord (vvvv bit3 ignored)",
            {0x62, 0xF1, 0x35, 0x08, 0xEF, 0xC2}, s, 0x7);

    // EVEX.V'̄=0 outside 64-bit mode: SDM Vol.2 Table 2-41 says #UD, and
    // the model follows the SDM.  The AMD Zen 4 development host was
    // observed to IGNORE V'̄ here instead (encoding 62 F1 75 00 EF C2
    // executed as VPXORD, no fault) — a vendor divergence on the SDM's
    // side of the model, so it cannot be asserted differentially on
    // this host.  Recorded for re-adjudication on Intel silicon.

    // BOUND (mod≠11): in-bounds executes with no architectural effect
    {
      ArchState b = {};
      b.rax = 5;
      b.rdi = DATA_ADDR;
      b.rflags = initial_flags();
      std::vector<u8> bounds = {0x00, 0x00, 0x00, 0x00,   // lower = 0
                                0x0A, 0x00, 0x00, 0x00};  // upper = 10
      add_mem("compat bound eax,[rdi] in bounds", {0x62, 0x07}, b,
              FL_ALL, bounds, 8);
    }

    // BOUND out of bounds raises #BR (vector 5)
    {
      TestCase tc;
      tc.name = "compat bound eax,[rdi] out of bounds (#BR)";
      tc.category = cat;
      tc.code = {0x62, 0x07};
      tc.initial = {};
      tc.initial.rax = 99;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rflags = initial_flags();
      tc.flags_mask = FL_ALL;
      tc.init_data = {0x00, 0x00, 0x00, 0x00, 0x0A, 0x00, 0x00, 0x00};
      tc.expect_fault = true;
      tc.expected_vector = 5;
      tc.compat_mode = true;
      tests.push_back(std::move(tc));
    }
  }

  // Instructions that exist only outside 64-bit mode.  The guest's segment
  // registers hold CS=0x48 (32-bit code) and 0x10 (flat data) elsewhere; the
  // GDT also offers 0x38 (read-only data), 0x40 (execute-only code), 0x08
  // (64-bit code), 0x18 (the TSS), and 0x53/0x5B (user code/data).
  auto add_fault = [&](const std::string &name, std::vector<u8> code, ArchState init,
                       int vec) {
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = std::move(code);
    tc.initial = init;
    tc.expect_fault = true;
    tc.expected_vector = vec;
    tc.compat_mode = true;
    tests.push_back(std::move(tc));
  };

  // =====================================================================
  // PUSH/POP of segment registers (06/07, 0E, 16/17, 1E/1F)
  // =====================================================================
  cat = "Compat segment push/pop";
  {
    struct { const char *name; u8 op; } pushes[] = {
      {"es", 0x06}, {"cs", 0x0E}, {"ss", 0x16}, {"ds", 0x1E},
    };
    for (auto &p : pushes) {
      // A 32-bit push may write the selector as a 16-bit move; the stack
      // page starts zeroed, so popping it back reads the same value either
      // way, and ESP shows the slot size.
      add(std::format("compat push {}", p.name), {p.op}, ArchState{});
      add(std::format("compat push {}; pop eax", p.name), {p.op, 0x58}, ArchState{});
      add(std::format("compat push {} (66h); pop ax", p.name), {0x66, p.op, 0x66, 0x58}, ArchState{});
    }
    // POP loads the selector; MOV r32,Sreg reads it back
    add("compat push 0x38; pop es; mov eax,es", {0x68, 0x38, 0x00, 0x00, 0x00, 0x07, 0x8C, 0xC0}, ArchState{});
    add("compat push 0x38; pop ds; mov eax,ds", {0x68, 0x38, 0x00, 0x00, 0x00, 0x1F, 0x8C, 0xD8}, ArchState{});
    add("compat push 0x10; pop ss; mov eax,ss", {0x68, 0x10, 0x00, 0x00, 0x00, 0x17, 0x8C, 0xD0}, ArchState{});
    add("compat push 0x5b; pop es; mov eax,es", {0x68, 0x5B, 0x00, 0x00, 0x00, 0x07, 0x8C, 0xC0}, ArchState{});
    add("compat push 0; pop es (null); mov eax,es", {0x6A, 0x00, 0x07, 0x8C, 0xC0}, ArchState{});
    add("compat push 0; pop ds (null); mov eax,ds", {0x6A, 0x00, 0x1F, 0x8C, 0xD8}, ArchState{});
    add("compat push 0x38 (66h); pop ds (66h); mov eax,ds",
        {0x66, 0x68, 0x38, 0x00, 0x66, 0x1F, 0x8C, 0xD8}, ArchState{});
    add("compat push 0x10 (66h); pop ss (66h); mov eax,ss",
        {0x66, 0x68, 0x10, 0x00, 0x66, 0x17, 0x8C, 0xD0}, ArchState{});
    // A pop into SS is followed by a memory access through the new stack
    add("compat pop ss; push eax; pop ebx",
        {0x68, 0x10, 0x00, 0x00, 0x00, 0x17, 0x50, 0x5B}, ArchState{.rax = 0x12345678});
    // A readable code segment may be loaded into a data-segment register
    add("compat push 0x48; pop ds (readable code); mov eax,ds",
        {0x68, 0x48, 0x00, 0x00, 0x00, 0x1F, 0x8C, 0xD8}, ArchState{});
    // Selector checks of the segment load (SDM Vol.2B POP, Operation):
    // #GP(0) for a null SS, otherwise #GP with the selector's index as the
    // error code.
    add_fault("compat pop ss (null) #GP", {0x6A, 0x00, 0x17}, ArchState{}, 13);
    add_fault("compat pop ss (0x38 read-only) #GP", {0x68, 0x38, 0x00, 0x00, 0x00, 0x17}, ArchState{}, 13);
    add_fault("compat pop ss (0x48 code) #GP", {0x68, 0x48, 0x00, 0x00, 0x00, 0x17}, ArchState{}, 13);
    add_fault("compat pop ss (0x5b DPL 3) #GP", {0x68, 0x5B, 0x00, 0x00, 0x00, 0x17}, ArchState{}, 13);
    add_fault("compat pop ss (0x13, RPL 3) #GP", {0x68, 0x13, 0x00, 0x00, 0x00, 0x17}, ArchState{}, 13);
    add_fault("compat pop ds (0x40 execute-only) #GP", {0x68, 0x40, 0x00, 0x00, 0x00, 0x1F}, ArchState{}, 13);
    add_fault("compat pop ds (0x39, RPL 1 > DPL 0) #GP", {0x68, 0x39, 0x00, 0x00, 0x00, 0x1F}, ArchState{}, 13);
    add_fault("compat pop es (0x18 TSS) #GP", {0x68, 0x18, 0x00, 0x00, 0x00, 0x07}, ArchState{}, 13);
    add_fault("compat pop ds (0x100 beyond GDT) #GP", {0x68, 0x00, 0x01, 0x00, 0x00, 0x1F}, ArchState{}, 13);
    add_fault("compat pop es (0x28 gate) #GP", {0x68, 0x28, 0x00, 0x00, 0x00, 0x07}, ArchState{}, 13);
    // MOV Sreg,r/m16 and LDS/LES run the same checks
    add_fault("compat mov ss,ax (0x38 read-only) #GP", {0x66, 0xB8, 0x38, 0x00, 0x8E, 0xD0}, ArchState{}, 13);
    add_fault("compat mov ds,ax (0x18 TSS) #GP", {0x66, 0xB8, 0x18, 0x00, 0x8E, 0xD8}, ArchState{}, 13);
    {
      // LDS eax,[edi]: pointer 0x00000010:0x40 loads the execute-only segment
      TestCase tc;
      tc.name = "compat lds eax,[edi] (0x40 execute-only) #GP";
      tc.category = cat;
      tc.code = {0xC5, 0x07};
      tc.initial = {.rdi = DATA_ADDR};
      tc.init_data = {0x10, 0x00, 0x00, 0x00, 0x40, 0x00};
      tc.expect_fault = true;
      tc.expected_vector = 13;
      tc.compat_mode = true;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // PUSHA/PUSHAD and POPA/POPAD (60/61)
  // =====================================================================
  cat = "Compat PUSHA/POPA";
  {
    ArchState s;
    s.rax = 0x11111111; s.rcx = 0x22222222; s.rdx = 0x33333333; s.rbx = 0x44444444;
    s.rbp = 0x55555555; s.rsi = 0x66666666; s.rdi = 0x77777777;
    add("compat pushad", {0x60}, s);
    // The pops reveal the push order: EDI is on top, then ESI, EBP, the
    // original ESP, EBX, EDX, ECX (EAX stays on the stack).
    add("compat pushad; pop eax,ecx,edx,ebx,ebp,esi,edi",
        {0x60, 0x58, 0x59, 0x5A, 0x5B, 0x5D, 0x5E, 0x5F}, s);
    add("compat pushad; popad", {0x60, 0x61}, s);
    add("compat pushaw", {0x66, 0x60}, s);
    add("compat pushaw; pop ax,cx,dx,bx,bp,si,di",
        {0x66, 0x60, 0x66, 0x58, 0x66, 0x59, 0x66, 0x5A, 0x66, 0x5B,
         0x66, 0x5D, 0x66, 0x5E, 0x66, 0x5F}, s);
    add("compat pushaw; popaw", {0x66, 0x60, 0x66, 0x61}, s);
    // POPAD from eight pushed immediates: EDI=8th... the fourth (ESP) is skipped
    std::vector<u8> code;
    for (u32 v = 1; v <= 8; v++)
      code.insert(code.end(), {0x68, u8(v), u8(v << 4), u8(v << 4 | v), u8(0xA0 + v)});
    code.push_back(0x61);
    add("compat push x8; popad", code, ArchState{});
    std::vector<u8> code16;
    for (u32 v = 1; v <= 8; v++)
      code16.insert(code16.end(), {0x66, 0x68, u8(v), u8(0xB0 + v)});
    code16.insert(code16.end(), {0x66, 0x61});
    add("compat push x8 (66h); popaw", code16, ArchState{});
  }

  // =====================================================================
  // Far JMP and far CALL with an immediate pointer (EA, 9A).  The 7-byte
  // instruction is followed by the harness's HLT at CODE_ADDR + 7, or by
  // "inc eax" (40) which in 64-bit code is a REX prefix on the HLT: the
  // increment therefore shows whether the new CS kept 32-bit mode.
  // =====================================================================
  cat = "Compat far transfer";
  {
    auto ptr = [](u8 op, u32 off, u16 sel) {
      return std::vector<u8>{op, u8(off), u8(off >> 8), u8(off >> 16), u8(off >> 24), u8(sel), u8(sel >> 8)};
    };
    auto with_inc = [](std::vector<u8> v) { v.push_back(0x40); return v; };
    ArchState s;
    s.rax = 0x10;
    add("compat jmp far 0x48:hlt", ptr(0xEA, CODE_ADDR + 7, 0x48), s);
    add("compat jmp far 0x48:inc eax", with_inc(ptr(0xEA, CODE_ADDR + 7, 0x48)), s);
    add("compat call far 0x48:hlt", ptr(0x9A, CODE_ADDR + 7, 0x48), s);
    add("compat call far 0x48:inc eax", with_inc(ptr(0x9A, CODE_ADDR + 7, 0x48)), s);
    // Entering 64-bit code: the model switches on CS.L only under
    // EFER.LMA, which run_sail sets (with the guest's CR0 and CR3) for
    // paging-enabled tests.
    for (u8 op : {u8(0xEA), u8(0x9A)}) {
      TestCase tc;
      tc.name = std::format("compat {} far 0x08:inc eax (enters 64-bit code)", op == 0xEA ? "jmp" : "call");
      tc.category = cat;
      tc.code = with_inc(ptr(op, CODE_ADDR + 7, 0x08));
      tc.initial = s;
      tc.compat_mode = true;
      tc.enable_paging = true;
      tests.push_back(std::move(tc));
    }
    // call far to a callee that returns with RETF; the caller then runs on
    //   0: 9A <+10> 48 00   7: 40 (inc eax)   8: EB 02 (to the HLT at 12)
    //  10: 40 (inc eax)    11: CB (retf)
    {
      std::vector<u8> code = ptr(0x9A, CODE_ADDR + 10, 0x48);
      code.insert(code.end(), {0x40, 0xEB, 0x02, 0x40, 0xCB});
      add("compat call far 0x48; retf; inc eax", code, s);
    }
    // the far pointer's selector is checked before anything is pushed
    add_fault("compat jmp far null selector #GP(0)", ptr(0xEA, CODE_ADDR + 7, 0x0000), s, 13);
    add_fault("compat jmp far 0x10 (data segment) #GP", ptr(0xEA, CODE_ADDR + 7, 0x10), s, 13);
    add_fault("compat jmp far 0x100 (beyond GDT) #GP", ptr(0xEA, CODE_ADDR + 7, 0x100), s, 13);
    add_fault("compat call far null selector #GP(0)", ptr(0x9A, CODE_ADDR + 7, 0x0000), s, 13);
    add_fault("compat call far 0x10 (data segment) #GP", ptr(0x9A, CODE_ADDR + 7, 0x10), s, 13);
    // The error code carries the selector's index and TI bit only (SDM
    // Vol.3A §7.13): 0x50 for the DPL 3 code selector 0x53.
    add_fault("compat jmp far 0x53 (DPL 3 code) #GP", ptr(0xEA, CODE_ADDR + 7, 0x53), s, 13);
    add_fault("compat call far 0x53 (DPL 3 code) #GP", ptr(0x9A, CODE_ADDR + 7, 0x53), s, 13);
  }

  // =====================================================================
  // ARPL r/m16, r16 (63 /r): outside 64-bit mode opcode 63 is ARPL, not
  // MOVSXD.  ZF := DEST.RPL < SRC.RPL, and if so DEST.RPL := SRC.RPL; the
  // other flags and the upper bits of a register destination are kept.
  // =====================================================================
  cat = "Compat ARPL";
  {
    struct { u32 dest, src; } cases[] = {
      {0x0010, 0x0013}, {0x0013, 0x0010}, {0x0011, 0x0011}, {0x0012, 0x0013},
      {0x0011, 0x0010}, {0xFFFC, 0x0002}, {0x12340000, 0x00000003}, {0x0000FFFF, 0xFFFF0000},
    };
    for (auto &c : cases) {
      // ARPL ax,cx: 63 C8 (mod=11, reg=cx, rm=ax)
      ArchState s;
      s.rax = c.dest;
      s.rcx = c.src;
      add(std::format("compat arpl ax,cx ({:#x}, {:#x})", c.dest, c.src), {0x63, 0xC8}, s);
      // ARPL [ebx],cx: 63 0B, the destination in memory
      ArchState m;
      m.rbx = DATA_ADDR;
      m.rcx = c.src;
      std::vector<u8> data(4, 0);
      memcpy(data.data(), &c.dest, 2);
      add_mem(std::format("compat arpl [ebx],cx ({:#x}, {:#x})", c.dest & 0xFFFF, c.src),
              {0x63, 0x0B}, m, FL_ALL, data, 4);
    }
    // The operands are 16 bits whatever the operand-size prefix says
    ArchState p;
    p.rax = 0x12340001;
    p.rcx = 0x00000003;
    add("compat arpl ax,cx (66h)", {0x66, 0x63, 0xC8}, p);
  }

  // =====================================================================
  // INTO (CE) and SALC (D6)
  // =====================================================================
  cat = "Compat INTO/SALC";
  {
    ArchState s;
    s.rflags = initial_flags(FL_OF, 0);
    add("compat into OF=0", {0xCE}, s);
    ArchState t;
    t.rflags = initial_flags(FL_OF, FL_OF);
    add_fault("compat into OF=1 #OF", {0xCE}, t, 4);
    for (int cf = 0; cf <= 1; cf++) {
      ArchState c;
      c.rflags = initial_flags(FL_CF, cf ? FL_CF : 0);
      add(std::format("compat salc CF={}", cf), {0xD6}, c);
    }
  }
}
