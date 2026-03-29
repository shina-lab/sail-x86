#ifndef KVM_AVX_ENCODER_H
#define KVM_AVX_ENCODER_H

#include "kvm-harness.h"
#include <cstring>
#include <string>
#include <vector>

// =========================================================================
// EVEX instruction encoder for test generation
// =========================================================================

struct Evex {
  int mm = 1;       // map: 1=0F, 2=0F38, 3=0F3A
  int pp = 0;       // prefix: 0=NP, 1=66, 2=F3, 3=F2
  bool W = false;   // REX.W
  int LL = 0;       // vector length: 0=128, 1=256, 2=512
  int aaa = 0;      // mask register k0-k7
  bool z = false;   // zeroing masking
  bool b = false;   // broadcast / SAE / ER
  int reg = 0;      // modrm.reg (destination, 0-31)
  int vvvv = 0;     // vvvvv source register (0-31, NOT inverted)
  int rm = 0;       // modrm.rm (source, 0-31)
  u8 opcode = 0;

  // Build the 4-byte EVEX prefix.
  void build_prefix(std::vector<u8> &out) const {
    u8 R  = (reg < 8)   ? 1 : 0;
    u8 X  = 1;  // default for reg-reg (no SIB)
    u8 B  = (rm < 8)    ? 1 : 0;
    u8 Rp = (reg < 16)  ? 1 : 0;
    u8 Vp = (vvvv < 16) ? 1 : 0;

    u8 p0 = (R << 7) | (X << 6) | (B << 5) | (Rp << 4) | (mm & 0x7);
    u8 p1 = ((W ? 1 : 0) << 7) | ((~vvvv & 0xF) << 3) | (1 << 2) | (pp & 0x3);
    u8 p2 = ((z ? 1 : 0) << 7) | ((LL & 0x3) << 5) | ((this->b ? 1 : 0) << 4) | (Vp << 3) | (aaa & 0x7);

    out.push_back(0x62);
    out.push_back(p0);
    out.push_back(p1);
    out.push_back(p2);
  }

  // reg-reg: EVEX prefix + opcode + modrm(mod=11)
  std::vector<u8> encode_rr() const {
    std::vector<u8> v;
    build_prefix(v);
    v.push_back(opcode);
    v.push_back(0xC0 | ((reg & 7) << 3) | (rm & 7));
    return v;
  }

  // reg-reg with immediate byte
  std::vector<u8> encode_rr_imm(u8 imm) const {
    auto v = encode_rr();
    v.push_back(imm);
    return v;
  }

  // reg <- [rdi]: EVEX prefix + opcode + modrm(mod=00, rm=7 for rdi)
  std::vector<u8> encode_rm_mem() const {
    std::vector<u8> v;
    // For memory operand [rdi], rm field in modrm is 7, mod=00
    // But EVEX.B must reflect the actual rm register (rdi=7, fits in 3 bits)
    Evex tmp = *this;
    tmp.rm = 7;  // rdi
    tmp.build_prefix(v);
    v.push_back(opcode);
    v.push_back(0x00 | ((reg & 7) << 3) | 7);  // mod=00, rm=111 (rdi)
    return v;
  }

  // reg <- [rdi] with immediate
  std::vector<u8> encode_rm_mem_imm(u8 imm) const {
    auto v = encode_rm_mem();
    v.push_back(imm);
    return v;
  }

  // [rdi] <- reg: EVEX prefix + opcode + modrm(mod=00, rm=7)
  // For store instructions where reg field is the source
  std::vector<u8> encode_mr_mem() const {
    return encode_rm_mem();  // same encoding, semantics differ
  }

  // reg <- broadcast [rdi]: same as rm_mem but with EVEX.b=1
  std::vector<u8> encode_rm_bcast() const {
    Evex tmp = *this;
    tmp.b = true;
    return tmp.encode_rm_mem();
  }

  // reg <- broadcast [rdi] with immediate
  std::vector<u8> encode_rm_bcast_imm(u8 imm) const {
    Evex tmp = *this;
    tmp.b = true;
    return tmp.encode_rm_mem_imm(imm);
  }
};

// =========================================================================
// VEX instruction encoder (for VEX-only instructions)
// =========================================================================

struct Vex {
  int mm = 1;       // map: 1=0F, 2=0F38, 3=0F3A
  int pp = 0;       // prefix: 0=NP, 1=66, 2=F3, 3=F2
  bool W = false;   // REX.W
  bool L = false;   // 0=128, 1=256
  int reg = 0;      // modrm.reg (0-15)
  int vvvv = 0;     // vvvvv (0-15, NOT inverted)
  int rm = 0;       // modrm.rm (0-15)
  u8 opcode = 0;

  std::vector<u8> encode_rr() const {
    std::vector<u8> v;
    bool need_3byte = (mm != 1) || W || (rm >= 8) || (reg >= 8);
    if (need_3byte) {
      // 3-byte VEX: C4 [RXBmmmmm] [WvvvvLpp]
      u8 R = (reg < 8) ? 1 : 0;
      u8 X = 1;  // no SIB
      u8 B = (rm < 8) ? 1 : 0;
      v.push_back(0xC4);
      v.push_back((R << 7) | (X << 6) | (B << 5) | (mm & 0x1F));
      v.push_back(((W ? 1 : 0) << 7) | ((~vvvv & 0xF) << 3) | ((L ? 1 : 0) << 2) | (pp & 0x3));
    } else {
      // 2-byte VEX: C5 [RvvvvLpp]
      u8 R = (reg < 8) ? 1 : 0;
      v.push_back(0xC5);
      v.push_back((R << 7) | ((~vvvv & 0xF) << 3) | ((L ? 1 : 0) << 2) | (pp & 0x3));
    }
    v.push_back(opcode);
    v.push_back(0xC0 | ((reg & 7) << 3) | (rm & 7));
    return v;
  }

  std::vector<u8> encode_rr_imm(u8 imm) const {
    auto v = encode_rr();
    v.push_back(imm);
    return v;
  }

  std::vector<u8> encode_rm_mem() const {
    std::vector<u8> v;
    bool need_3byte = (mm != 1) || W || (reg >= 8);
    if (need_3byte) {
      u8 R = (reg < 8) ? 1 : 0;
      v.push_back(0xC4);
      v.push_back((R << 7) | (1 << 6) | (1 << 5) | (mm & 0x1F));  // X=1, B=1 (rdi<8)
      v.push_back(((W ? 1 : 0) << 7) | ((~vvvv & 0xF) << 3) | ((L ? 1 : 0) << 2) | (pp & 0x3));
    } else {
      u8 R = (reg < 8) ? 1 : 0;
      v.push_back(0xC5);
      v.push_back((R << 7) | ((~vvvv & 0xF) << 3) | ((L ? 1 : 0) << 2) | (pp & 0x3));
    }
    v.push_back(opcode);
    v.push_back(0x00 | ((reg & 7) << 3) | 7);  // mod=00, rm=111 (rdi)
    return v;
  }

  std::vector<u8> encode_rm_mem_imm(u8 imm) const {
    auto v = encode_rm_mem();
    v.push_back(imm);
    return v;
  }
};

// =========================================================================
// Code generation helpers
// =========================================================================

// Encode "MOV eax, imm32; KMOVW k1, eax" to set mask register k1
static inline std::vector<u8> set_kmask(u32 mask_val) {
  return {
    0xB8, u8(mask_val), u8(mask_val >> 8), u8(mask_val >> 16), u8(mask_val >> 24),
    0xC5, 0xF8, 0x92, 0xC8  // KMOVW k1, eax
  };
}

// Concatenate two code sequences
static inline std::vector<u8> concat(std::vector<u8> a, const std::vector<u8> &c) {
  a.insert(a.end(), c.begin(), c.end());
  return a;
}

// =========================================================================
// Test generation helpers
// =========================================================================

// Add tests for a reg-reg EVEX instruction at all three VLs
// with no mask, zeroing mask, and merging mask.
static inline void add_evex_rr_tests(
    std::vector<TestCase> &tests,
    const std::string &cat,
    const char *mnemonic,
    Evex base,
    ArchState init,
    u32 xmm_cmp,
    u32 kmask_val = 0
) {
  const char *vl_name[] = {"xmm", "ymm", "zmm"};
  const int vl_bits[] = {128, 256, 512};

  for (int ll = 0; ll <= 2; ll++) {
    std::string suffix = std::string(vl_name[ll]) + " (VL" + std::to_string(vl_bits[ll]) + ")";
    base.LL = ll;

    // No mask
    base.aaa = 0; base.z = false;
    tests.push_back({std::string(mnemonic) + " " + suffix,
                     cat, base.encode_rr(), init, FL_NONE, xmm_cmp, false});

    if (kmask_val) {
      // Zeroing mask
      base.aaa = 1; base.z = true;
      tests.push_back({std::string(mnemonic) + " " + suffix + " {k1}{z}",
                       cat, concat(set_kmask(kmask_val), base.encode_rr()), init, FL_NONE, xmm_cmp, false});

      // Merging mask
      base.aaa = 1; base.z = false;
      tests.push_back({std::string(mnemonic) + " " + suffix + " {k1}",
                       cat, concat(set_kmask(kmask_val), base.encode_rr()), init, FL_NONE, xmm_cmp, false});
    }
  }
}

// Add tests for approximate instructions (VRCP14, VRSQRT14) with tolerance comparison.
// SDM specifies < 2^-14 relative error for these instructions.
static inline void add_evex_rr_approx_tests(
    std::vector<TestCase> &tests,
    const std::string &cat,
    const char *mnemonic,
    Evex base,
    ArchState init,
    u32 xmm_cmp,
    int elem_bits,  // 32 or 64
    double rel_tol = 6.2e-5  // 2^-14 ≈ 6.1e-5, use slightly larger
) {
  const char *vl_name[] = {"xmm", "ymm", "zmm"};
  const int vl_bits[] = {128, 256, 512};
  for (int ll = 0; ll <= 2; ll++) {
    std::string suffix = std::string(vl_name[ll]) + " (VL" + std::to_string(vl_bits[ll]) + ")";
    base.LL = ll; base.aaa = 0; base.z = false;
    TestCase tc = {std::string(mnemonic) + " " + suffix, cat, base.encode_rr(), init, FL_NONE, xmm_cmp, false};
    tc.approx_rel_tol = rel_tol;
    tc.approx_elem_bits = elem_bits;
    tests.push_back(std::move(tc));
  }
}

// Add tests for reg <- [rdi] memory source at all three VLs with masking.
// Caller must set init.rdi = DATA_ADDR and provide init_data.
static inline void add_evex_rm_tests(
    std::vector<TestCase> &tests,
    const std::string &cat,
    const char *mnemonic,
    Evex base,
    ArchState init,
    u32 xmm_cmp,
    std::vector<u8> init_data,
    u32 kmask_val = 0
) {
  const char *vl_name[] = {"xmm", "ymm", "zmm"};
  const int vl_bits[] = {128, 256, 512};

  for (int ll = 0; ll <= 2; ll++) {
    std::string suffix = std::string(vl_name[ll]) + " [mem] (VL" + std::to_string(vl_bits[ll]) + ")";
    base.LL = ll;

    // No mask
    base.aaa = 0; base.z = false;
    {
      TestCase tc = {std::string(mnemonic) + " " + suffix, cat, base.encode_rm_mem(), init, FL_NONE, xmm_cmp, false};
      tc.init_data = init_data;
      tests.push_back(std::move(tc));
    }

    if (kmask_val) {
      base.aaa = 1; base.z = true;
      {
        TestCase tc = {std::string(mnemonic) + " " + suffix + " {k1}{z}", cat,
                       concat(set_kmask(kmask_val), base.encode_rm_mem()), init, FL_NONE, xmm_cmp, false};
        tc.init_data = init_data;
        tests.push_back(std::move(tc));
      }
    }
  }
}

// Add broadcast-from-memory tests at all three VLs.
static inline void add_evex_bcast_tests(
    std::vector<TestCase> &tests,
    const std::string &cat,
    const char *mnemonic,
    Evex base,
    ArchState init,
    u32 xmm_cmp,
    std::vector<u8> init_data
) {
  const char *vl_name[] = {"xmm", "ymm", "zmm"};
  const int vl_bits[] = {128, 256, 512};

  for (int ll = 0; ll <= 2; ll++) {
    std::string suffix = std::string(vl_name[ll]) + " {1toN} (VL" + std::to_string(vl_bits[ll]) + ")";
    base.LL = ll;
    base.aaa = 0; base.z = false;
    TestCase tc = {std::string(mnemonic) + " " + suffix, cat, base.encode_rm_bcast(), init, FL_NONE, xmm_cmp, false};
    tc.init_data = init_data;
    tests.push_back(std::move(tc));
  }
}

#endif // KVM_AVX_ENCODER_H
