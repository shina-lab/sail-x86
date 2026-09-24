#include "kvm-avx-encoder.h"

void add_avx_shift_tests(std::vector<TestCase> &tests) {
  std::string cat = "AVX shift";

  auto zmm_to_data = [](const ZmmVal &v) {
    std::vector<u8> d(64);
    memcpy(d.data(), v.q, 64);
    return d;
  };

  auto fill_dwords = [](ZmmVal &v, u32 start, u32 step) {
    for (int i = 0; i < 16; i++) v.set<u32>(i, start + i * step);
  };

  auto fill_qwords = [](ZmmVal &v, u64 start, u64 step) {
    for (int i = 0; i < 8; i++) v.q[i] = start + i * step;
  };

  auto fill_words = [](ZmmVal &v, u16 start, u16 step) {
    for (int i = 0; i < 32; i++) v.set<u16>(i, start + i * step);
  };

  // Binary shift by xmm count: dst = vvvv shift rm (count in low 64 bits of rm)
  auto add_shift_reg = [&](const char *name, int pp, bool W, u8 opcode,
                            ArchState s, u32 kmask) {
    Evex e;
    e.mm = 1; e.pp = pp; e.W = W; e.opcode = opcode;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, name, e, s, 0x6, kmask);
  };

  // Shift by immediate: opcode /digit with imm8
  // These use modrm.reg as opcode extension, rm as source
  auto add_shift_imm = [&](const char *name, bool W, u8 opcode, int reg_ext,
                             ArchState s, u32 kmask, u8 imm) {
    s = with_vector_inputs(s, 0x2);
    Evex e;
    e.mm = 1; e.pp = 1; e.W = W; e.opcode = opcode;
    e.reg = reg_ext;  // opcode extension in reg field
    e.vvvv = 0;       // destination = vvvv
    e.rm = 1;         // source
    // For shift-by-imm, the encoding is: EVEX opcode modrm imm8
    // reg field = opcode extension, rm = source, vvvv = destination
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl_name[] = {"xmm", "ymm", "zmm"};
      e.LL = ll;

      // No mask
      e.aaa = 0; e.z = false;
      tests.push_back({
        std::string(name) + " " + vl_name[ll] + " imm=" + std::to_string(imm),
        cat, e.encode_rr_imm(imm), s, FL_ALL, 0x3, false
      });

      // Zeroing mask
      if (kmask) {
        e.aaa = 1; e.z = true;
        tests.push_back({
          std::string(name) + " " + vl_name[ll] + " imm=" + std::to_string(imm) + " {k1}{z}",
          cat, concat(set_kmask(kmask), e.encode_rr_imm(imm)), s, FL_ALL, 0x3, false
        });
      }
    }
  };

  // Variable shift: dst = vvvv shift rm (per-element count in rm)
  auto add_var_shift = [&](const char *name, int mm, bool W, u8 opcode,
                            ArchState s, u32 kmask) {
    Evex e;
    e.mm = mm; e.pp = 1; e.W = W; e.opcode = opcode;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, name, e, s, 0x6, kmask);

    ArchState sm = s;
    sm.rdi = DATA_ADDR;
    add_evex_rm_tests(tests, cat, name, e, sm, 0x2, zmm_to_data(s.xmm[2]), kmask);
  };

  std::vector<u8> adata(64, 0x42);
  auto add_vok = [&](const std::string &name, std::vector<u8> code) {
    TestCase tc; tc.name = name; tc.category = cat;
    tc.code = std::move(code);
    tc.initial = {.rdi = DATA_ADDR + 1, .rflags = 0x2};
    tc.initial.xmm[1] = xmm_from_u64(0, 0); // input; the count comes from memory
    tc.xmm_mask = 0x1; tc.init_data = adata;
    tests.push_back(std::move(tc));
  };

  // ---- Shift by xmm count (count in low 64-bit of xmm2) ----
  // VPSLLW: 66 0F F1, WIG   VPSRLW: 66 0F D1, WIG   VPSRAW: 66 0F E1, WIG
  // VPSLLD: 66 0F F2, W0    VPSRLD: 66 0F D2, W0    VPSRAD: 66 0F E2, W0
  // VPSLLQ: 66 0F F3, W1    VPSRLQ: 66 0F D3, W1    VPSRAQ: 66 0F E2, W1
  {
    ArchState sw; sw.rflags = 0x2;
    fill_words(sw.xmm[1], 0x8001, 0x100);
    sw.xmm[2] = xmm_from_u64(4, 0);  // shift count = 4
    for (int i = 0; i < 8; i++) sw.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    add_shift_reg("VPSLLW", 1, false, 0xF1, sw, 0x55555555);
    add_shift_reg("VPSRLW", 1, false, 0xD1, sw, 0x55555555);
    add_shift_reg("VPSRAW", 1, false, 0xE1, sw, 0x55555555);
    // VEX shift-by-count misaligned (count from [rdi])
    { Vex v; v.mm = 1; v.pp = 1; v.W = false; v.reg = 0; v.vvvv = 1; v.L = false;
      v.opcode = 0xF1; add_vok("VPSLLW xmm,[rdi] misaligned", v.encode_rm_mem());
      v.opcode = 0xD1; add_vok("VPSRLW xmm,[rdi] misaligned", v.encode_rm_mem());
      v.opcode = 0xE1; add_vok("VPSRAW xmm,[rdi] misaligned", v.encode_rm_mem()); }
  }
  {
    ArchState sd; sd.rflags = 0x2;
    fill_dwords(sd.xmm[1], 0x80000001, 0x11111111);
    sd.xmm[2] = xmm_from_u64(8, 0);
    for (int i = 0; i < 8; i++) sd.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    add_shift_reg("VPSLLD", 1, false, 0xF2, sd, 0xAAAA);
    add_shift_reg("VPSRLD", 1, false, 0xD2, sd, 0xAAAA);
    { Vex v; v.mm = 1; v.pp = 1; v.W = false; v.reg = 0; v.vvvv = 1; v.L = false;
      v.opcode = 0xF2; add_vok("VPSLLD xmm,[rdi] misaligned", v.encode_rm_mem());
      v.opcode = 0xD2; add_vok("VPSRLD xmm,[rdi] misaligned", v.encode_rm_mem());
      v.opcode = 0xE2; add_vok("VPSRAD xmm,[rdi] misaligned", v.encode_rm_mem()); }
    add_shift_reg("VPSRAD", 1, false, 0xE2, sd, 0xAAAA);
  }
  {
    ArchState sq; sq.rflags = 0x2;
    fill_qwords(sq.xmm[1], 0x8000000000000001ULL, 0x1111111111111111ULL);
    sq.xmm[2] = xmm_from_u64(16, 0);
    for (int i = 0; i < 8; i++) sq.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    add_shift_reg("VPSLLQ", 1, true, 0xF3, sq, 0x55);
    add_shift_reg("VPSRLQ", 1, true, 0xD3, sq, 0x55);
    add_shift_reg("VPSRAQ", 1, true, 0xE2, sq, 0x55);  // same opcode as VPSRAD, W1
    { Vex v; v.mm = 1; v.pp = 1; v.W = false; v.reg = 0; v.vvvv = 1; v.L = false;
      v.opcode = 0xF3; add_vok("VPSLLQ xmm,[rdi] misaligned", v.encode_rm_mem());
      v.opcode = 0xD3; add_vok("VPSRLQ xmm,[rdi] misaligned", v.encode_rm_mem()); }
  }

  // Register counts use all 64 bits. Large counts must sign-fill without
  // constructing an intermediate bitvector as large as the count itself.
  for (u64 count : {0ULL, 15ULL, 16ULL, 31ULL, 32ULL, 63ULL, 64ULL,
                    1ULL << 32, ~0ULL}) {
    ArchState s = {.rflags = 0x2};
    for (u64 &word : s.xmm[1].q)
      word = 0x800180017FFE7FFEULL;
    s.xmm[2] = xmm_from_u64(count, 0);
    std::string suffix = " count=" + std::to_string(count);
    add_shift_reg(("VPSRAW" + suffix).c_str(), 1, false, 0xE1, s, 0);
    add_shift_reg(("VPSRAD" + suffix).c_str(), 1, false, 0xE2, s, 0);
    add_shift_reg(("VPSRAQ" + suffix).c_str(), 1, true, 0xE2, s, 0);
  }

  // ---- Shift by immediate ----
  // VPSLLW imm: 66 0F 71 /6 ib    VPSRLW imm: 66 0F 71 /2 ib    VPSRAW imm: 66 0F 71 /4 ib
  // VPSLLD imm: 66 0F 72 /6 ib    VPSRLD imm: 66 0F 72 /2 ib    VPSRAD imm: 66 0F 72 /4 ib
  // VPSLLQ imm: 66 0F 73 /6 ib    VPSRLQ imm: 66 0F 73 /2 ib    VPSRAQ imm: 66 0F 72 /4 W1 ib
  {
    ArchState sw; sw.rflags = 0x2;
    fill_words(sw.xmm[1], 0x8001, 0x100);
    for (int i = 0; i < 8; i++) sw.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    add_shift_imm("VPSLLW", false, 0x71, 6, sw, 0x55555555, 4);
    add_shift_imm("VPSRLW", false, 0x71, 2, sw, 0x55555555, 4);
    add_shift_imm("VPSRAW", false, 0x71, 4, sw, 0x55555555, 4);
  }
  {
    ArchState sd; sd.rflags = 0x2;
    fill_dwords(sd.xmm[1], 0x80000001, 0x11111111);
    for (int i = 0; i < 8; i++) sd.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    add_shift_imm("VPSLLD", false, 0x72, 6, sd, 0xAAAA, 8);
    add_shift_imm("VPSRLD", false, 0x72, 2, sd, 0xAAAA, 8);
    add_shift_imm("VPSRAD", false, 0x72, 4, sd, 0xAAAA, 8);
  }
  {
    ArchState sq; sq.rflags = 0x2;
    fill_qwords(sq.xmm[1], 0x8000000000000001ULL, 0x1111111111111111ULL);
    for (int i = 0; i < 8; i++) sq.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    add_shift_imm("VPSLLQ", true, 0x73, 6, sq, 0x55, 16);
    add_shift_imm("VPSRLQ", true, 0x73, 2, sq, 0x55, 16);
    add_shift_imm("VPSRAQ", true, 0x72, 4, sq, 0x55, 16);  // W1
  }

  // ---- Byte shift (VPSLLDQ / VPSRLDQ) ----
  // VPSLLDQ: 66 0F 73 /7 ib    VPSRLDQ: 66 0F 73 /3 ib
  {
    ArchState s; s.rflags = 0x2;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = i + 1;
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    add_shift_imm("VPSLLDQ", false, 0x73, 7, s, 0, 4);
    add_shift_imm("VPSRLDQ", false, 0x73, 3, s, 0, 4);
  }

  // ---- Variable shifts (per-element count in xmm2) ----
  // VPSLLVW: 66 0F38 12, W1   VPSRLVW: 66 0F38 10, W1   VPSRAVW: 66 0F38 11, W1
  // VPSLLVD: 66 0F38 47, W0   VPSRLVD: 66 0F38 45, W0   VPSRAVD: 66 0F38 46, W0
  // VPSLLVQ: 66 0F38 47, W1   VPSRLVQ: 66 0F38 45, W1   VPSRAVQ: 66 0F38 46, W1
  {
    ArchState sw; sw.rflags = 0x2;
    fill_words(sw.xmm[1], 0x8001, 0x100);
    // Per-element shift counts: 0,1,2,3,4,...
    for (int i = 0; i < 32; i++) sw.xmm[2].set<u16>(i, i % 16);
    for (int i = 0; i < 8; i++) sw.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    add_var_shift("VPSLLVW", 2, true, 0x12, sw, 0x55555555);
    add_var_shift("VPSRLVW", 2, true, 0x10, sw, 0x55555555);
    add_var_shift("VPSRAVW", 2, true, 0x11, sw, 0x55555555);
  }
  {
    ArchState sd; sd.rflags = 0x2;
    fill_dwords(sd.xmm[1], 0x80000001, 0x11111111);
    for (int i = 0; i < 16; i++) sd.xmm[2].set<u32>(i, i % 32);
    for (int i = 0; i < 8; i++) sd.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    add_var_shift("VPSLLVD", 2, false, 0x47, sd, 0xAAAA);
    add_var_shift("VPSRLVD", 2, false, 0x45, sd, 0xAAAA);
    add_var_shift("VPSRAVD", 2, false, 0x46, sd, 0xAAAA);
    // VEX variable shift misaligned
    { Vex v; v.mm = 2; v.pp = 1; v.W = false; v.reg = 0; v.vvvv = 1; v.L = false;
      v.opcode = 0x47; add_vok("VPSLLVD xmm,[rdi] misaligned", v.encode_rm_mem());
      v.opcode = 0x45; add_vok("VPSRLVD xmm,[rdi] misaligned", v.encode_rm_mem());
      v.opcode = 0x46; add_vok("VPSRAVD xmm,[rdi] misaligned", v.encode_rm_mem()); }
  }
  {
    ArchState sq; sq.rflags = 0x2;
    fill_qwords(sq.xmm[1], 0x8000000000000001ULL, 0x1111111111111111ULL);
    for (int i = 0; i < 8; i++) sq.xmm[2].q[i] = i * 8;
    for (int i = 0; i < 8; i++) sq.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    add_var_shift("VPSLLVQ", 2, true, 0x47, sq, 0x55);
    add_var_shift("VPSRLVQ", 2, true, 0x45, sq, 0x55);
    add_var_shift("VPSRAVQ", 2, true, 0x46, sq, 0x55);
    { Vex v; v.mm = 2; v.pp = 1; v.W = true; v.reg = 0; v.vvvv = 1; v.L = false;
      v.opcode = 0x47; add_vok("VPSLLVQ xmm,[rdi] misaligned", v.encode_rm_mem());
      v.opcode = 0x45; add_vok("VPSRLVQ xmm,[rdi] misaligned", v.encode_rm_mem()); }
  }

  // ---- Rotate by immediate (AVX-512 VBMI2) ----
  // VPROLD: 66 0F 72 /1 ib, W0    VPROLQ: 66 0F 72 /1 ib, W1
  // VPRORD: 66 0F 72 /0 ib, W0    VPRORQ: 66 0F 72 /0 ib, W1
  {
    ArchState sd; sd.rflags = 0x2;
    fill_dwords(sd.xmm[1], 0x80000001, 0x11111111);
    for (int i = 0; i < 8; i++) sd.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    add_shift_imm("VPROLD", false, 0x72, 1, sd, 0xAAAA, 5);
    add_shift_imm("VPRORD", false, 0x72, 0, sd, 0xAAAA, 5);
  }
  {
    ArchState sq; sq.rflags = 0x2;
    fill_qwords(sq.xmm[1], 0x8000000000000001ULL, 0x1111111111111111ULL);
    for (int i = 0; i < 8; i++) sq.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    add_shift_imm("VPROLQ", true, 0x72, 1, sq, 0x55, 13);
    add_shift_imm("VPRORQ", true, 0x72, 0, sq, 0x55, 13);
  }

  // ---- Variable rotate (AVX-512) ----
  // VPROLVD: 66 0F38 15, W0   VPROLVQ: 66 0F38 15, W1
  // VPRORVD: 66 0F38 14, W0   VPRORVQ: 66 0F38 14, W1
  {
    ArchState sd; sd.rflags = 0x2;
    fill_dwords(sd.xmm[1], 0x80000001, 0x11111111);
    for (int i = 0; i < 16; i++) sd.xmm[2].set<u32>(i, (i * 3) % 32);
    for (int i = 0; i < 8; i++) sd.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    add_var_shift("VPROLVD", 2, false, 0x15, sd, 0xAAAA);
    add_var_shift("VPRORVD", 2, false, 0x14, sd, 0xAAAA);
  }
  {
    ArchState sq; sq.rflags = 0x2;
    fill_qwords(sq.xmm[1], 0x8000000000000001ULL, 0x1111111111111111ULL);
    for (int i = 0; i < 8; i++) sq.xmm[2].q[i] = (i * 7) % 64;
    for (int i = 0; i < 8; i++) sq.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    add_var_shift("VPROLVQ", 2, true, 0x15, sq, 0x55);
    add_var_shift("VPRORVQ", 2, true, 0x14, sq, 0x55);
  }
}
