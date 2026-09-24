// Intel AMX (AMX-TILE, AMX-INT8, AMX-BF16): LDTILECFG, STTILECFG,
// TILERELEASE, TILEZERO, TILELOADD/TILELOADDT1, TILESTORED, the TDPB*D
// byte dot products and TDPBF16PS.  Constructed only where the host has
// AMX-TILE (CPUID.(7,0):EDX[24]); the templates were run against an Intel
// Xeon Platinum 8562Y+ (Emerald Rapids).
//
// Every test enables the tile components in XCR0 (bits 17 and 18) through
// xcr0_override, which also makes the harness compare the TILECFG image and
// all eight tiles after the run.  Tests start in the INIT tile state, load a
// configuration from DATA_ADDR and tile data from the rest of the page:
//   0x000  tile configuration (64 bytes)          [rdi]
//   0x040  STTILECFG output, or a second configuration  [rax]
//   0x100  tile A source (16 rows x 64 bytes)        [rsi + rcx]
//   0x500  tile B source                             [rdx + rcx]
//   0x900  tile C source, and TILESTORED destination  [rbx + rcx]
// with rcx the row stride.  The whole page is compared where a test stores.

#include "kvm-harness.h"
#include <array>
#include <cpuid.h>

namespace {

constexpr u64 AMX_XCR0 = 0xE7 | (3ULL << 17);  // x87, SSE, AVX, AVX-512, TILECFG, TILEDATA
constexpr size_t PAGE = 0x1000;
constexpr size_t CFG_OFF = 0x000, CFG2_OFF = 0x040, A_OFF = 0x100, B_OFF = 0x500, C_OFF = 0x900;
enum Gpr { RAX = 0, RCX = 1, RDX = 2, RBX = 3, RSP = 4, RBP = 5, RSI = 6, RDI = 7 };

// A three-byte VEX prefix for map 0F38 with the AMX fields: pp selects the
// instruction, vvvv the third tile operand of the TMUL instructions.  R, X
// and B extend modrm.reg, SIB.index and the base; L and W are 0 for every
// AMX encoding (the tests below try 1 to see what the hardware does).
struct AmxEnc {
  int pp = 0;
  int vvvv = 0;
  bool R = false, X = false, B = false, W = false, L = false;
  u8 opcode = 0;
  std::vector<u8> bytes(u8 modrm, std::initializer_list<u8> tail = {}) const {
    std::vector<u8> v = {0xC4,
                         u8((R ? 0 : 0x80) | (X ? 0 : 0x40) | (B ? 0 : 0x20) | 0x02),
                         u8((W ? 0x80 : 0) | ((~vvvv & 0xF) << 3) | (L ? 0x04 : 0) | (pp & 3)),
                         opcode, modrm};
    v.insert(v.end(), tail);
    return v;
  }
};

// LDTILECFG [rdi]: VEX.128.NP.0F38.W0 49 /0 with mod = 00, rm = rdi.
std::vector<u8> ldtilecfg_rdi() { return AmxEnc{.pp = 0, .opcode = 0x49}.bytes(0x07); }
// LDTILECFG [rax]
std::vector<u8> ldtilecfg_rax() { return AmxEnc{.pp = 0, .opcode = 0x49}.bytes(0x00); }
// STTILECFG [rax]: VEX.128.66.0F38.W0 49 /0
std::vector<u8> sttilecfg_rax() { return AmxEnc{.pp = 1, .opcode = 0x49}.bytes(0x00); }
// TILERELEASE: VEX.128.NP.0F38.W0 49 C0
std::vector<u8> tilerelease() { return AmxEnc{.pp = 0, .opcode = 0x49}.bytes(0xC0); }
// TILEZERO tmm: VEX.128.F2.0F38.W0 49 11:rrr:000
std::vector<u8> tilezero(int t) { return AmxEnc{.pp = 3, .opcode = 0x49}.bytes(u8(0xC0 | (t << 3))); }

u8 sib(int scale, int index, int base) {
  int ss = scale == 8 ? 3 : scale == 4 ? 2 : scale == 2 ? 1 : 0;
  return u8((ss << 6) | (index << 3) | base);
}

// TILELOADD tmm, [base + index * scale]: VEX.128.F2.0F38.W0 4B !(11):rrr:100;
// TILELOADDT1 is the 66 form.  index = RSP encodes no index (stride 0).
std::vector<u8> tileloadd(int t, int base, int index, int scale = 1, bool t1 = false) {
  return AmxEnc{.pp = t1 ? 1 : 3, .opcode = 0x4B}.bytes(u8(0x04 | (t << 3)), {sib(scale, index, base)});
}
// TILESTORED [base + index * scale], tmm: VEX.128.F3.0F38.W0 4B
std::vector<u8> tilestored(int t, int base, int index, int scale = 1) {
  return AmxEnc{.pp = 2, .opcode = 0x4B}.bytes(u8(0x04 | (t << 3)), {sib(scale, index, base)});
}
// TDPBSSD (F2) / TDPBSUD (F3) / TDPBUSD (66) / TDPBUUD (NP) tmm_d, tmm_a, tmm_b:
// VEX.128.pp.0F38.W0 5E 11:ddd:aaa with vvvv = b.  The letters give the
// signedness of A (ModRM:r/m) and B (VEX.vvvv).
enum Dpb { SSD, SUD, USD, UUD };
std::vector<u8> tdpb(Dpb kind, int d, int a, int b) {
  static const int pp[] = {3, 2, 1, 0};
  return AmxEnc{.pp = pp[kind], .vvvv = b, .opcode = 0x5E}.bytes(u8(0xC0 | (d << 3) | a));
}
// TDPBF16PS tmm_d, tmm_a, tmm_b: VEX.128.F3.0F38.W0 5C 11:ddd:aaa, vvvv = b
std::vector<u8> tdpbf16ps(int d, int a, int b) {
  return AmxEnc{.pp = 2, .vvvv = b, .opcode = 0x5C}.bytes(u8(0xC0 | (d << 3) | a));
}

std::vector<u8> cat(std::initializer_list<std::vector<u8>> parts) {
  std::vector<u8> v;
  for (const auto &p : parts) v.insert(v.end(), p.begin(), p.end());
  return v;
}

// The 64-byte LDTILECFG image (SDM Table 1-50).
std::vector<u8> tilecfg(u8 palette, u8 start_row, std::array<u16, 8> colsb, std::array<u8, 8> rows) {
  std::vector<u8> c(64, 0);
  c[0] = palette;
  c[1] = start_row;
  for (int n = 0; n < 8; n++) {
    memcpy(c.data() + 16 + 2 * n, &colsb[n], 2);
    c[48 + n] = rows[n];
  }
  return c;
}

// All eight tiles at their largest shape, 16 rows by 64 bytes.
std::vector<u8> cfg_full() {
  return tilecfg(1, 0, {64, 64, 64, 64, 64, 64, 64, 64}, {16, 16, 16, 16, 16, 16, 16, 16});
}

// Byte patterns for the tile sources; every row and every column differ.
void fill_bytes(std::vector<u8> &data, size_t off, int rows, int colsb, u8 (*f)(int r, int c)) {
  for (int r = 0; r < rows; r++)
    for (int c = 0; c < colsb; c++)
      data[off + r * 64 + c] = f(r, c);
}
void fill_words(std::vector<u8> &data, size_t off, int rows, int cols, u16 (*f)(int r, int c)) {
  for (int r = 0; r < rows; r++)
    for (int c = 0; c < cols; c++) {
      u16 v = f(r, c);
      memcpy(data.data() + off + r * 64 + 2 * c, &v, 2);
    }
}
void fill_dwords(std::vector<u8> &data, size_t off, int rows, int cols, u32 (*f)(int r, int c)) {
  for (int r = 0; r < rows; r++)
    for (int c = 0; c < cols; c++) {
      u32 v = f(r, c);
      memcpy(data.data() + off + r * 64 + 4 * c, &v, 4);
    }
}

u8 pat_a(int r, int c) { return u8(r * 13 + c * 7 + 0x71); }
u8 pat_b(int r, int c) { return u8(c * 29 + r * 3 + 0x90); }
u32 pat_c(int r, int c) { return u32(0x10000 * r - 1000 * c + 5); }

// BF16 values with short mantissas: the dot products below stay exact.
u16 bf16_a(int r, int c) {
  static const u16 t[] = {0x3F80, 0x4000, 0xBFC0, 0x3F00, 0x4040, 0xBE80, 0x4080, 0xBF80};
  return t[(r + c) & 7];   // 1, 2, -1.5, 0.5, 3, -0.25, 4, -1
}
u16 bf16_b(int r, int c) {
  static const u16 t[] = {0x3F00, 0xBF80, 0x4000, 0x3F80, 0xBFC0, 0x4040, 0xBE80, 0x3E80};
  return t[(2 * r + c) & 7]; // 0.5, -1, 2, 1, -1.5, 3, -0.25, 0.25
}
u32 f32_c(int r, int c) {
  float f = float(r - 3 * c) * 0.5f;
  u32 u; memcpy(&u, &f, 4); return u;
}

// Data page: configuration at 0, A/B/C sources of the given shapes.
struct Page {
  std::vector<u8> data = std::vector<u8>(PAGE, 0);
  void cfg(const std::vector<u8> &c, size_t off = CFG_OFF) { memcpy(data.data() + off, c.data(), 64); }
};

}  // namespace

void add_amx_tests(std::vector<TestCase> &tests) {
  u32 a7, b7, c7, d7;
  __cpuid_count(7, 0, a7, b7, c7, d7);
  if (!(d7 & (1u << 24))) return;  // no AMX-TILE
  const bool has_int8 = d7 & (1u << 25);
  const bool has_bf16 = d7 & (1u << 22);

  std::string category;
  const ArchState base_regs = {
    .rax = DATA_ADDR + CFG2_OFF, .rbx = DATA_ADDR + C_OFF, .rcx = 64,
    .rdx = DATA_ADDR + B_OFF, .rsi = DATA_ADDR + A_OFF, .rdi = DATA_ADDR + CFG_OFF,
  };

  // regs replaces base_regs where a test needs other register values.
  auto add = [&](const std::string &name, std::vector<u8> code, const Page &page,
                 size_t compare_len = 0, const ArchState *regs = nullptr, u64 xcr0 = AMX_XCR0) {
    TestCase tc;
    tc.name = name;
    tc.category = category;
    tc.code = std::move(code);
    tc.initial = regs ? *regs : base_regs;
    tc.flags_mask = FL_ALL;
    tc.xcr0_override = xcr0;
    tc.init_data = page.data;
    tc.compare_data_len = compare_len;
    tests.push_back(std::move(tc));
  };
  auto add_fault = [&](const std::string &name, std::vector<u8> code, const Page &page, int vec,
                       u64 xcr0 = AMX_XCR0) {
    TestCase tc;
    tc.name = name;
    tc.category = category;
    tc.code = std::move(code);
    tc.initial = base_regs;
    tc.flags_mask = FL_ALL;
    tc.expect_fault = true;
    tc.expected_vector = vec;
    tc.xcr0_override = xcr0;
    tc.init_data = page.data;
    tests.push_back(std::move(tc));
  };

  // =====================================================================
  // LDTILECFG, STTILECFG, TILERELEASE, TILEZERO
  // =====================================================================
  category = "AMX config";
  {
    Page p; p.cfg(cfg_full());
    add("ldtilecfg full; sttilecfg", cat({ldtilecfg_rdi(), sttilecfg_rax()}), p, 0x80);
  }
  {
    // Mixed shapes, including an invalid tile (3) and a colsb that is not a
    // multiple of 4 (tile 7), which LDTILECFG accepts.
    Page p; p.cfg(tilecfg(1, 0, {64, 12, 4, 0, 32, 64, 8, 6}, {16, 3, 1, 0, 8, 2, 16, 1}));
    add("ldtilecfg mixed shapes; sttilecfg", cat({ldtilecfg_rdi(), sttilecfg_rax()}), p, 0x80);
  }
  {
    // start_row is loaded as given.
    Page p; p.cfg(tilecfg(1, 5, {64, 64, 64, 64, 64, 64, 64, 64}, {16, 16, 16, 16, 16, 16, 16, 16}));
    add("ldtilecfg start_row=5; sttilecfg", cat({ldtilecfg_rdi(), sttilecfg_rax()}), p, 0x80);
  }
  {
    // Only the palette-1 tiles that are configured need be described; a
    // configuration with every tile invalid is legal (TILES_CONFIGURED = 1).
    Page p; p.cfg(tilecfg(1, 0, {0, 0, 0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0, 0, 0}));
    add("ldtilecfg palette 1 with no valid tile; sttilecfg", cat({ldtilecfg_rdi(), sttilecfg_rax()}), p, 0x80);
  }
  {
    // Palette 0 returns configured tiles to INIT; STTILECFG then writes zeros.
    Page p; p.cfg(cfg_full()); p.cfg(tilecfg(0, 0, {}, {}), CFG2_OFF);
    add("ldtilecfg full; ldtilecfg palette 0; sttilecfg",
        cat({ldtilecfg_rdi(), ldtilecfg_rax(), sttilecfg_rax()}), p, 0x80);
  }
  {
    // Palette 0 with nonzero configuration bytes: whether LDTILECFG checks
    // them for the INIT palette (the SDM pseudocode's indentation is
    // ambiguous).  The model does not, following the outer "if palette != 0".
    Page p; p.cfg(tilecfg(0, 0, {64, 64, 0, 0, 0, 0, 0, 0}, {16, 16, 0, 0, 0, 0, 0, 0}));
    add("ldtilecfg palette 0 with nonzero shapes", ldtilecfg_rdi(), p);
  }
  {
    Page p; p.cfg(cfg_full());
    add("ldtilecfg; tilerelease; sttilecfg", cat({ldtilecfg_rdi(), tilerelease(), sttilecfg_rax()}), p, 0x80);
  }
  {
    Page p;
    add("sttilecfg unconfigured", sttilecfg_rax(), p, 0x80);
    add("tilerelease unconfigured", tilerelease(), p);
  }
  {
    // Loading a second configuration zeroes the tiles.
    Page p; p.cfg(cfg_full());
    p.cfg(tilecfg(1, 0, {16, 16, 0, 0, 0, 0, 0, 0}, {2, 2, 0, 0, 0, 0, 0, 0}), CFG2_OFF);
    fill_bytes(p.data, A_OFF, 16, 64, pat_a);
    add("ldtilecfg; tileloadd tmm0; ldtilecfg (new shapes)",
        cat({ldtilecfg_rdi(), tileloadd(0, RSI, RCX), ldtilecfg_rax()}), p);
  }
  {
    Page p; p.cfg(cfg_full());
    fill_bytes(p.data, A_OFF, 16, 64, pat_a);
    add("tileloadd tmm0, tmm1; tilezero tmm0",
        cat({ldtilecfg_rdi(), tileloadd(0, RSI, RCX), tileloadd(1, RSI, RCX), tilezero(0)}), p);
    add("tileloadd tmm7; tilezero tmm7", cat({ldtilecfg_rdi(), tileloadd(7, RSI, RCX), tilezero(7)}), p);
  }

  // =====================================================================
  // TILELOADD, TILELOADDT1, TILESTORED
  // =====================================================================
  category = "AMX tile load/store";
  {
    Page p; p.cfg(cfg_full());
    fill_bytes(p.data, A_OFF, 16, 64, pat_a);
    fill_bytes(p.data, B_OFF, 16, 64, pat_b);
    add("tileloadd tmm0 full (stride 64)", cat({ldtilecfg_rdi(), tileloadd(0, RSI, RCX)}), p);
    add("tileloaddt1 tmm3 full", cat({ldtilecfg_rdi(), tileloadd(3, RDX, RCX, 1, true)}), p);
    add("tileloadd all eight tiles",
        cat({ldtilecfg_rdi(), tileloadd(0, RSI, RCX), tileloadd(1, RDX, RCX), tileloadd(2, RSI, RCX),
             tileloadd(3, RDX, RCX), tileloadd(4, RSI, RCX), tileloadd(5, RDX, RCX),
             tileloadd(6, RSI, RCX), tileloadd(7, RDX, RCX)}), p);
    // rcx = 32 with scale 2: the same 64-byte stride through the SIB scale.
    ArchState r = base_regs; r.rcx = 32;
    add("tileloadd tmm1 stride via scale 2", cat({ldtilecfg_rdi(), tileloadd(1, RSI, RCX, 2)}), p, 0, &r);
    // Stride 128: every other source row.
    r = base_regs; r.rcx = 128;
    add("tileloadd tmm2 stride 128", cat({ldtilecfg_rdi(), tileloadd(2, RSI, RCX)}), p, 0, &r);
    // No index register: stride 0, every row is row 0.
    add("tileloadd tmm4 no index (stride 0)", cat({ldtilecfg_rdi(), tileloadd(4, RSI, RSP)}), p);
    // Stride 16 with 64-byte rows: overlapping source rows.
    r = base_regs; r.rcx = 16;
    add("tileloadd tmm5 stride 16 (overlapping rows)", cat({ldtilecfg_rdi(), tileloadd(5, RSI, RCX)}), p, 0, &r);
    // Store the loaded tile back over the C region.
    add("tileloadd tmm0; tilestored full", cat({ldtilecfg_rdi(), tileloadd(0, RSI, RCX), tilestored(0, RBX, RCX)}), p, PAGE);
    // Loaded with stride 64 from A, stored with stride 128 over A and B
    // (the last row ends at 0x100 + 15 * 128 + 64, inside the page).
    r = base_regs; r.rdx = 128;
    add("tileloadd tmm0; tilestored stride 128",
        cat({ldtilecfg_rdi(), tileloadd(0, RSI, RCX), tilestored(0, RSI, RDX)}), p, PAGE, &r);
  }
  {
    // Small shapes: bytes beyond colsb and rows beyond rows are zero in the
    // tile; TILESTORED writes only colsb bytes of rows rows.
    Page p; p.cfg(tilecfg(1, 0, {12, 4, 60, 64, 8, 32, 20, 16}, {3, 1, 16, 1, 16, 5, 2, 16}));
    fill_bytes(p.data, A_OFF, 16, 64, pat_a);
    fill_bytes(p.data, C_OFF, 16, 64, pat_b);
    add("tileloadd small shapes (all tiles)",
        cat({ldtilecfg_rdi(), tileloadd(0, RSI, RCX), tileloadd(1, RSI, RCX), tileloadd(2, RSI, RCX),
             tileloadd(3, RSI, RCX), tileloadd(4, RSI, RCX), tileloadd(5, RSI, RCX),
             tileloadd(6, RSI, RCX), tileloadd(7, RSI, RCX)}), p);
    add("tileloadd 3x12; tilestored into a filled area",
        cat({ldtilecfg_rdi(), tileloadd(0, RSI, RCX), tilestored(0, RBX, RCX)}), p, PAGE);
    add("tileloadd 5x32; tilestored into a filled area",
        cat({ldtilecfg_rdi(), tileloadd(5, RSI, RCX), tilestored(5, RBX, RCX)}), p, PAGE);
    add("tileloadd 16x60; tilestored", cat({ldtilecfg_rdi(), tileloadd(2, RSI, RCX), tilestored(2, RBX, RCX)}), p, PAGE);
  }
  {
    // TILECFG.start_row = 4: the load fills rows 4-15 and leaves rows 0-3
    // as they were, then clears start_row, so the next load takes every
    // row.
    Page p; p.cfg(tilecfg(1, 4, {64, 64, 64, 64, 64, 64, 64, 64}, {16, 16, 16, 16, 16, 16, 16, 16}));
    fill_bytes(p.data, A_OFF, 16, 64, pat_a);
    add("ldtilecfg start_row=4; tileloadd tmm0; tileloadd tmm1",
        cat({ldtilecfg_rdi(), tileloadd(0, RSI, RCX), tileloadd(1, RSI, RCX)}), p);
    // With start_row = 4, TILESTORED writes rows 4-15 only.
    fill_bytes(p.data, C_OFF, 16, 64, pat_b);
    add("ldtilecfg start_row=4; tilestored tmm0 (zero tile) rows 4-15",
        cat({ldtilecfg_rdi(), tilestored(0, RBX, RCX)}), p, PAGE);
  }
  {
    // A tile load that faults on its third row: rows 0 and 1 are kept and
    // TILECFG.start_row records row 2 for the restart.  The rows sit just
    // below the 2 MB identity mapping (the guest's memory), written by the
    // test itself; row 2 is unmapped, so its read is #PF.
    Page p; p.cfg(cfg_full());
    ArchState r = base_regs;
    r.rsi = 0x1FFF80;   // rows at 0x1FFF80 and 0x1FFFC0; row 2 at 0x200000
    r.rdi = 0x1FFF80;
    r.rcx = 16;         // 16 qwords of the pattern
    r.rax = 0x0123456789ABCDEFULL;
    r.rdx = 64;         // stride
    TestCase tc;
    tc.name = "tileloadd faulting on row 2 (#PF): rows 0-1 kept, start_row = 2";
    tc.category = category;
    // LDTILECFG needs the configuration: it is at rdi in the other tests;
    // here r8 points at it and the pattern store uses rdi.
    r.r8 = DATA_ADDR + CFG_OFF;
    tc.code = cat({AmxEnc{.pp = 0, .B = true, .opcode = 0x49}.bytes(0x00),  // LDTILECFG [r8]
                   {0xF3, 0x48, 0xAB},                                        // rep stosq
                   tileloadd(0, RSI, RDX)});
    tc.initial = r;
    tc.flags_mask = FL_ALL;
    tc.expect_fault = true;
    tc.expected_vector = 14;
    tc.xcr0_override = AMX_XCR0;
    tc.enable_paging = true;
    tc.init_data = p.data;
    tests.push_back(std::move(tc));
  }

  // =====================================================================
  // TDPBSSD / TDPBSUD / TDPBUSD / TDPBUUD
  // =====================================================================
  if (has_int8) {
    category = "AMX INT8";
    struct { Dpb kind; const char *name; } kinds[] = {
      {SSD, "tdpbssd"}, {SUD, "tdpbsud"}, {USD, "tdpbusd"}, {UUD, "tdpbuud"},
    };
    {
      // C[16][16] += A[16][16 dwords of 4 bytes] * B[16][16]: the full TMUL.
      Page p; p.cfg(cfg_full());
      fill_dwords(p.data, C_OFF, 16, 16, pat_c);
      fill_bytes(p.data, A_OFF, 16, 64, pat_a);
      fill_bytes(p.data, B_OFF, 16, 64, pat_b);
      for (auto k : kinds) {
        add(std::string(k.name) + " tmm0, tmm1, tmm2 (16x16x16)",
            cat({ldtilecfg_rdi(), tileloadd(0, RBX, RCX), tileloadd(1, RSI, RCX), tileloadd(2, RDX, RCX),
                 tdpb(k.kind, 0, 1, 2), tilestored(0, RBX, RCX)}), p, PAGE);
      }
      // Accumulate twice, and into tile 7 from tiles 3 and 5.
      add("tdpbssd twice (accumulation)",
          cat({ldtilecfg_rdi(), tileloadd(7, RBX, RCX), tileloadd(3, RSI, RCX), tileloadd(5, RDX, RCX),
               tdpb(SSD, 7, 3, 5), tdpb(SSD, 7, 3, 5)}), p);
      add("tdpbuud tmm7, tmm3, tmm5 then tdpbusd tmm7, tmm5, tmm3",
          cat({ldtilecfg_rdi(), tileloadd(7, RBX, RCX), tileloadd(3, RSI, RCX), tileloadd(5, RDX, RCX),
               tdpb(UUD, 7, 3, 5), tdpb(USD, 7, 5, 3)}), p);
    }
    {
      // Small shapes: C 2x5 dwords (colsb 20), A 2x3 dwords (colsb 12),
      // B 3x5 dwords (rows 3, colsb 20); C's bytes beyond 20 and rows beyond 2
      // are zero afterwards.
      Page p; p.cfg(tilecfg(1, 0, {20, 12, 20, 0, 0, 0, 0, 0}, {2, 2, 3, 0, 0, 0, 0, 0}));
      fill_dwords(p.data, C_OFF, 16, 16, pat_c);
      fill_bytes(p.data, A_OFF, 16, 64, pat_a);
      fill_bytes(p.data, B_OFF, 16, 64, pat_b);
      for (auto k : kinds) {
        add(std::string(k.name) + " tmm0, tmm1, tmm2 (M=2 K=3 N=5)",
            cat({ldtilecfg_rdi(), tileloadd(0, RBX, RCX), tileloadd(1, RSI, RCX), tileloadd(2, RDX, RCX),
                 tdpb(k.kind, 0, 1, 2), tilestored(0, RBX, RCX)}), p, PAGE);
      }
    }
    {
      // K = 1 with extreme bytes: 0x80 * 0x80 and 0xFF * 0xFF under each
      // signedness; C starts at the wrap boundaries.
      Page p; p.cfg(tilecfg(1, 0, {8, 4, 8, 0, 0, 0, 0, 0}, {2, 2, 1, 0, 0, 0, 0, 0}));
      static const u32 c_init[2][2] = {{0x7FFFFFFF, 0x80000000}, {0xFFFFFFFF, 0x00000001}};
      for (int r = 0; r < 2; r++) for (int c = 0; c < 2; c++)
        memcpy(p.data.data() + C_OFF + r * 64 + 4 * c, &c_init[r][c], 4);
      static const u8 a_init[2][4] = {{0x80, 0x7F, 0xFF, 0x01}, {0x80, 0x80, 0x80, 0x80}};
      memcpy(p.data.data() + A_OFF, a_init[0], 4);
      memcpy(p.data.data() + A_OFF + 64, a_init[1], 4);
      static const u8 b_init[8] = {0x80, 0x7F, 0xFF, 0x01, 0xFF, 0xFF, 0xFF, 0xFF};
      memcpy(p.data.data() + B_OFF, b_init, 8);
      for (auto k : kinds) {
        add(std::string(k.name) + " extreme bytes (M=2 K=1 N=2)",
            cat({ldtilecfg_rdi(), tileloadd(0, RBX, RCX), tileloadd(1, RSI, RCX), tileloadd(2, RDX, RCX),
                 tdpb(k.kind, 0, 1, 2)}), p);
      }
    }
  }

  // =====================================================================
  // TDPBF16PS
  // =====================================================================
  if (has_bf16) {
    category = "AMX BF16";
    {
      Page p; p.cfg(cfg_full());
      fill_dwords(p.data, C_OFF, 16, 16, f32_c);
      fill_words(p.data, A_OFF, 16, 32, bf16_a);
      fill_words(p.data, B_OFF, 16, 32, bf16_b);
      add("tdpbf16ps tmm0, tmm1, tmm2 (16x16x16 pairs, exact values)",
          cat({ldtilecfg_rdi(), tileloadd(0, RBX, RCX), tileloadd(1, RSI, RCX), tileloadd(2, RDX, RCX),
               tdpbf16ps(0, 1, 2), tilestored(0, RBX, RCX)}), p, PAGE);
      add("tdpbf16ps twice (accumulation)",
          cat({ldtilecfg_rdi(), tileloadd(6, RBX, RCX), tileloadd(4, RSI, RCX), tileloadd(2, RDX, RCX),
               tdpbf16ps(6, 4, 2), tdpbf16ps(6, 4, 2)}), p);
    }
    {
      // Small shapes: C 3x4 (colsb 16), A 3x2 pairs (colsb 8), B 2x4 (rows 2, colsb 16).
      Page p; p.cfg(tilecfg(1, 0, {16, 8, 16, 0, 0, 0, 0, 0}, {3, 3, 2, 0, 0, 0, 0, 0}));
      fill_dwords(p.data, C_OFF, 16, 16, f32_c);
      fill_words(p.data, A_OFF, 16, 32, bf16_a);
      fill_words(p.data, B_OFF, 16, 32, bf16_b);
      add("tdpbf16ps (M=3 K=2 N=4)",
          cat({ldtilecfg_rdi(), tileloadd(0, RBX, RCX), tileloadd(1, RSI, RCX), tileloadd(2, RDX, RCX),
               tdpbf16ps(0, 1, 2), tilestored(0, RBX, RCX)}), p, PAGE);
    }
    {
      // Special values: a BF16 denormal (treated as zero), quiet and
      // signaling NaNs, infinities of both signs and -0, against ones.
      Page p; p.cfg(tilecfg(1, 0, {16, 16, 16, 0, 0, 0, 0, 0}, {2, 2, 4, 0, 0, 0, 0, 0}));
      static const u16 a_sp[2][8] = {
        {0x0001, 0x3F80, 0x7FC0, 0x3F80, 0x7F80, 0x3F80, 0xFF80, 0x3F80},
        {0x8000, 0x3F80, 0x7F81, 0x0000, 0x7F80, 0xFF80, 0x0080, 0x3F80},
      };
      for (int r = 0; r < 2; r++) memcpy(p.data.data() + A_OFF + 64 * r, a_sp[r], 16);
      for (int r = 0; r < 4; r++) for (int c = 0; c < 8; c++) {
        u16 one = 0x3F80;
        memcpy(p.data.data() + B_OFF + 64 * r + 2 * c, &one, 2);
      }
      add("tdpbf16ps special values (denormal, NaN, inf, -0)",
          cat({ldtilecfg_rdi(), tileloadd(0, RBX, RCX), tileloadd(1, RSI, RCX), tileloadd(2, RDX, RCX),
               tdpbf16ps(0, 1, 2)}), p);
    }
    {
      // Rounding order: even and odd products are summed separately, the two
      // sums added, then added to C (SDM pseudocode).  A = (2^24, 1), B =
      // (1, 1), C = -2^24: the pseudocode gives 2^24 + 1 -> 2^24 (RNE), then
      // -2^24 + 2^24 = 0; an exact accumulation would give 1.
      Page p; p.cfg(tilecfg(1, 0, {4, 4, 4, 0, 0, 0, 0, 0}, {1, 1, 1, 0, 0, 0, 0, 0}));
      static const u16 a_pair[2] = {0x4B80, 0x3F80};   // 2^24, 1.0
      static const u16 b_pair[2] = {0x3F80, 0x3F80};   // 1.0, 1.0
      const u32 c_val = 0xCB800000;                    // -2^24
      memcpy(p.data.data() + A_OFF, a_pair, 4);
      memcpy(p.data.data() + B_OFF, b_pair, 4);
      memcpy(p.data.data() + C_OFF, &c_val, 4);
      add("tdpbf16ps rounding order (2^24 + 1 - 2^24)",
          cat({ldtilecfg_rdi(), tileloadd(0, RBX, RCX), tileloadd(1, RSI, RCX), tileloadd(2, RDX, RCX),
               tdpbf16ps(0, 1, 2)}), p);
      // Two K steps: (2^24, 0) then (1, 0) with C = -2^24: the even sum is
      // 2^24 + 1 -> 2^24 before C is added, so 0 again, unless the products
      // are accumulated into C one at a time (then 1).
      Page q; q.cfg(tilecfg(1, 0, {4, 8, 4, 0, 0, 0, 0, 0}, {1, 1, 2, 0, 0, 0, 0, 0}));
      static const u16 a_two[4] = {0x4B80, 0x0000, 0x3F80, 0x0000};
      memcpy(q.data.data() + A_OFF, a_two, 8);
      memcpy(q.data.data() + B_OFF, b_pair, 4);
      memcpy(q.data.data() + B_OFF + 64, b_pair, 4);
      memcpy(q.data.data() + C_OFF, &c_val, 4);
      add("tdpbf16ps rounding order over K (2^24, then 1, C = -2^24)",
          cat({ldtilecfg_rdi(), tileloadd(0, RBX, RCX), tileloadd(1, RSI, RCX), tileloadd(2, RDX, RCX),
               tdpbf16ps(0, 1, 2)}), q);
    }
  }

  // =====================================================================
  // Faults: the AMX exception classes (SDM Vol.2 Table 1-67)
  // =====================================================================
  category = "AMX faults";
  {
    Page p;
    // LDTILECFG configuration checks: #GP(0)
    p.cfg(tilecfg(2, 0, {64, 64, 64, 64, 64, 64, 64, 64}, {16, 16, 16, 16, 16, 16, 16, 16}));
    add_fault("ldtilecfg palette 2 #GP", ldtilecfg_rdi(), p, 13);
    p.cfg(tilecfg(1, 0, {68, 0, 0, 0, 0, 0, 0, 0}, {16, 0, 0, 0, 0, 0, 0, 0}));
    add_fault("ldtilecfg colsb 68 #GP", ldtilecfg_rdi(), p, 13);
    p.cfg(tilecfg(1, 0, {64, 0, 0, 0, 0, 0, 0, 0}, {17, 0, 0, 0, 0, 0, 0, 0}));
    add_fault("ldtilecfg rows 17 #GP", ldtilecfg_rdi(), p, 13);
    p.cfg(tilecfg(1, 0, {64, 0, 0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0, 0, 0}));
    add_fault("ldtilecfg rows 0 with colsb 64 #GP", ldtilecfg_rdi(), p, 13);
    p.cfg(tilecfg(1, 0, {0, 0, 0, 0, 0, 0, 0, 0}, {16, 0, 0, 0, 0, 0, 0, 0}));
    add_fault("ldtilecfg colsb 0 with rows 16 #GP", ldtilecfg_rdi(), p, 13);
    p.cfg(cfg_full()); p.data[CFG_OFF + 2] = 1;
    add_fault("ldtilecfg reserved byte 2 #GP", ldtilecfg_rdi(), p, 13);
    p.cfg(cfg_full()); p.data[CFG_OFF + 40] = 1;
    add_fault("ldtilecfg reserved byte 40 #GP", ldtilecfg_rdi(), p, 13);
    p.cfg(cfg_full()); p.data[CFG_OFF + 63] = 0x80;
    add_fault("ldtilecfg reserved byte 63 #GP", ldtilecfg_rdi(), p, 13);
  }
  {
    // #UD: unconfigured tiles, invalid tiles, tile numbers >= 8, shapes
    Page p; p.cfg(tilecfg(1, 0, {64, 64, 6, 0, 20, 12, 16, 16}, {16, 8, 1, 0, 2, 2, 3, 3}));
    fill_bytes(p.data, A_OFF, 16, 64, pat_a);
    add_fault("tilezero unconfigured #UD", tilezero(0), p, 6);
    add_fault("tileloadd unconfigured #UD", tileloadd(0, RSI, RCX), p, 6);
    add_fault("tilestored unconfigured #UD", tilestored(0, RBX, RCX), p, 6);
    add_fault("tilezero invalid tile 3 #UD", cat({ldtilecfg_rdi(), tilezero(3)}), p, 6);
    add_fault("tileloadd invalid tile 3 #UD", cat({ldtilecfg_rdi(), tileloadd(3, RSI, RCX)}), p, 6);
    add_fault("tileloadd colsb 6 (not a multiple of 4) #UD", cat({ldtilecfg_rdi(), tileloadd(2, RSI, RCX)}), p, 6);
    add_fault("tilestored colsb 6 #UD", cat({ldtilecfg_rdi(), tilestored(2, RBX, RCX)}), p, 6);
    // VEX.R names tmm8
    add_fault("tilezero tmm8 (VEX.R) #UD",
              cat({ldtilecfg_rdi(), AmxEnc{.pp = 3, .R = true, .opcode = 0x49}.bytes(0xC0)}), p, 6);
    add_fault("tileloadd tmm8 (VEX.R) #UD",
              cat({ldtilecfg_rdi(), AmxEnc{.pp = 3, .R = true, .opcode = 0x4B}.bytes(0x04, {sib(1, RCX, RSI)})}), p, 6);
    // TILELOADD without SIB (rm = rdi) and with a register operand
    add_fault("tileloadd without SIB #UD", cat({ldtilecfg_rdi(), AmxEnc{.pp = 3, .opcode = 0x4B}.bytes(0x07)}), p, 6);
    add_fault("tileloadd mod=11 #UD", cat({ldtilecfg_rdi(), AmxEnc{.pp = 3, .opcode = 0x4B}.bytes(0xC1)}), p, 6);
    // LDTILECFG/STTILECFG with a register operand, TILERELEASE with rm != 0,
    // TILEZERO with rm != 0, the NP form of 4B
    add_fault("ldtilecfg mod=11 rm=1 #UD", AmxEnc{.pp = 0, .opcode = 0x49}.bytes(0xC1), p, 6);
    add_fault("sttilecfg mod=11 #UD", AmxEnc{.pp = 1, .opcode = 0x49}.bytes(0xC0), p, 6);
    add_fault("tilezero rm=1 #UD", cat({ldtilecfg_rdi(), AmxEnc{.pp = 3, .opcode = 0x49}.bytes(0xC1)}), p, 6);
    add_fault("0F38 4B NP #UD", cat({ldtilecfg_rdi(), AmxEnc{.pp = 0, .opcode = 0x4B}.bytes(0x04, {sib(1, RCX, RSI)})}), p, 6);
    add_fault("ldtilecfg reg=1 #UD", AmxEnc{.pp = 0, .opcode = 0x49}.bytes(0x0F), p, 6);
    // VEX.vvvv must be 1111b where there is no third operand
    add_fault("ldtilecfg vvvv=1 #UD", AmxEnc{.pp = 0, .vvvv = 1, .opcode = 0x49}.bytes(0x07), p, 6);
    add_fault("tilezero vvvv=2 #UD", cat({ldtilecfg_rdi(), AmxEnc{.pp = 3, .vvvv = 2, .opcode = 0x49}.bytes(0xC0)}), p, 6);
    add_fault("tilerelease vvvv=3 #UD", AmxEnc{.pp = 0, .vvvv = 3, .opcode = 0x49}.bytes(0xC0), p, 6);
    // VEX.L = 1 and VEX.W = 1 on VEX.128.W0-only encodings
    add_fault("tilezero VEX.L=1 #UD", cat({ldtilecfg_rdi(), AmxEnc{.pp = 3, .L = true, .opcode = 0x49}.bytes(0xC0)}), p, 6);
    add_fault("tilezero VEX.W=1 #UD", cat({ldtilecfg_rdi(), AmxEnc{.pp = 3, .W = true, .opcode = 0x49}.bytes(0xC0)}), p, 6);
    add_fault("tilerelease VEX.L=1 #UD", AmxEnc{.pp = 0, .L = true, .opcode = 0x49}.bytes(0xC0), p, 6);
    add_fault("ldtilecfg VEX.W=1 #UD", AmxEnc{.pp = 0, .W = true, .opcode = 0x49}.bytes(0x07), p, 6);
    // start_row beyond the tile: rows 3 configured, start_row 3 (tile 6 has
    // rows 3, tile 7 too)
    Page s; s.cfg(tilecfg(1, 3, {16, 16, 0, 0, 0, 0, 0, 0}, {3, 4, 0, 0, 0, 0, 0, 0}));
    add_fault("tileloadd with start_row = rows #UD", cat({ldtilecfg_rdi(), tileloadd(0, RSI, RCX)}), s, 6);
    add_fault("tilestored with start_row = rows #UD", cat({ldtilecfg_rdi(), tilestored(0, RBX, RCX)}), s, 6);
    // Not in 64-bit mode: TILERELEASE and LDTILECFG in compatibility mode
    {
      TestCase tc;
      tc.name = "tilerelease in compatibility mode #UD";
      tc.category = category;
      tc.code = tilerelease();
      tc.initial = base_regs;
      tc.flags_mask = FL_ALL;
      tc.expect_fault = true;
      tc.expected_vector = 6;
      tc.xcr0_override = AMX_XCR0;
      tc.compat_mode = true;
      tests.push_back(tc);
      tc.name = "ldtilecfg in compatibility mode #UD";
      tc.code = ldtilecfg_rdi();
      tc.init_data = p.data;
      tests.push_back(tc);
    }
  }
  {
    // XCR0 without the tile components (the guest's default XCR0)
    Page p; p.cfg(cfg_full());
    add_fault("ldtilecfg with XCR0[18:17] = 0 #UD", ldtilecfg_rdi(), p, 6, 0xE7);
    add_fault("tilerelease with XCR0[18:17] = 0 #UD", tilerelease(), p, 6, 0xE7);
    add_fault("tilezero with XCR0[18:17] = 0 #UD", tilezero(0), p, 6, 0xE7);
    // CR4.OSXSAVE clear (0x10620 = the guest's CR4 without bit 18)
    {
      TestCase tc;
      tc.name = "tilerelease with OSXSAVE = 0 #UD";
      tc.category = category;
      tc.code = tilerelease();
      tc.initial = base_regs;
      tc.flags_mask = FL_ALL;
      tc.expect_fault = true;
      tc.expected_vector = 6;
      tc.xcr0_override = AMX_XCR0;
      tc.cr4_override = 0x10620;
      tests.push_back(std::move(tc));
    }
  }
  if (has_int8) {
    // TMUL shape checks (AMX-E4)
    Page p; p.cfg(tilecfg(1, 0, {64, 64, 64, 32, 64, 6, 0, 64}, {16, 16, 16, 16, 8, 1, 0, 16}));
    add_fault("tdpbssd unconfigured #UD", tdpb(SSD, 0, 1, 2), p, 6);
    add_fault("tdpbssd srcdest == src1 #UD", cat({ldtilecfg_rdi(), tdpb(SSD, 0, 0, 2)}), p, 6);
    add_fault("tdpbssd src1 == src2 #UD", cat({ldtilecfg_rdi(), tdpb(SSD, 0, 1, 1)}), p, 6);
    add_fault("tdpbssd srcdest == src2 #UD", cat({ldtilecfg_rdi(), tdpb(SSD, 2, 1, 2)}), p, 6);
    add_fault("tdpbssd C.colsb != B.colsb #UD", cat({ldtilecfg_rdi(), tdpb(SSD, 0, 1, 3)}), p, 6);
    add_fault("tdpbssd C.rows != A.rows #UD", cat({ldtilecfg_rdi(), tdpb(SSD, 0, 4, 2)}), p, 6);
    add_fault("tdpbssd A.colsb/4 != B.rows #UD", cat({ldtilecfg_rdi(), tdpb(SSD, 0, 3, 2)}), p, 6);
    add_fault("tdpbssd invalid tile 6 #UD", cat({ldtilecfg_rdi(), tdpb(SSD, 0, 1, 6)}), p, 6);
    add_fault("tdpbssd colsb 6 #UD", cat({ldtilecfg_rdi(), tdpb(SSD, 5, 1, 2)}), p, 6);
    add_fault("tdpbssd tmm8 as src2 (vvvv) #UD", cat({ldtilecfg_rdi(), AmxEnc{.pp = 3, .vvvv = 8, .opcode = 0x5E}.bytes(0xC1)}), p, 6);
    add_fault("tdpbssd tmm8 as src1 (VEX.B) #UD", cat({ldtilecfg_rdi(), AmxEnc{.pp = 3, .vvvv = 2, .B = true, .opcode = 0x5E}.bytes(0xC1)}), p, 6);
    add_fault("tdpbssd memory operand #UD", cat({ldtilecfg_rdi(), AmxEnc{.pp = 3, .vvvv = 2, .opcode = 0x5E}.bytes(0x07)}), p, 6);
    add_fault("tdpbssd VEX.L=1 #UD", cat({ldtilecfg_rdi(), AmxEnc{.pp = 3, .vvvv = 2, .L = true, .opcode = 0x5E}.bytes(0xC1)}), p, 6);
    add_fault("tdpbssd VEX.W=1 #UD", cat({ldtilecfg_rdi(), AmxEnc{.pp = 3, .vvvv = 2, .W = true, .opcode = 0x5E}.bytes(0xC1)}), p, 6);
  }
  if (has_bf16) {
    Page p; p.cfg(tilecfg(1, 0, {64, 64, 64, 32, 0, 0, 0, 0}, {16, 16, 16, 16, 0, 0, 0, 0}));
    add_fault("tdpbf16ps unconfigured #UD", tdpbf16ps(0, 1, 2), p, 6);
    add_fault("tdpbf16ps C.colsb != B.colsb #UD", cat({ldtilecfg_rdi(), tdpbf16ps(0, 1, 3)}), p, 6);
    add_fault("tdpbf16ps srcdest == src1 #UD", cat({ldtilecfg_rdi(), tdpbf16ps(1, 1, 2)}), p, 6);
    // 0F38 5C with the F2 prefix is TDPFP16PS (AMX-FP16), absent here
    add_fault("0F38 5C F2 (TDPFP16PS, not supported) #UD",
              cat({ldtilecfg_rdi(), AmxEnc{.pp = 3, .vvvv = 2, .opcode = 0x5C}.bytes(0xC1)}), p, 6);
  }
}
