// BoringSSL assembly optimization equivalence tests.
// Each pair of test functions encodes original vs optimized instruction sequences.
// Isla symbolically executes both, then Z3 proves UNSAT (= equivalent for all inputs).

// ============================================================================
// 1. MD5 Round 2: G function optimization
// ============================================================================
// Original: G(b,c,d) = (b & d) | (c & ~d)  [6 instrs]
// Optimized: G(b,c,d) = c ^ (d & (b ^ c))  [4 instrs]
// Inputs: ebx=b (GPR[3]), ecx=c (GPR[1]), edx=d (GPR[2])

val test_md5_g_orig : unit -> bits(64)
function test_md5_g_orig() = {
  // movl %edx, %r11d       [41 89 D3]
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4F4D38941);
  // movl %edx, %r12d       [41 89 D4]
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4F4D48941);
  // notl %r11d              [41 F7 D3]
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4F4D3F741);
  // andl %ebx, %r12d       [41 21 DC]
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4F4DC2141);
  // andl %ecx, %r11d       [41 21 CB]
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4F4CB2141);
  // orl  %r11d, %r12d      [45 09 DC]
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4F4DC0945);
  GPR[12]
}

val test_md5_g_opt : unit -> bits(64)
function test_md5_g_opt() = {
  // movl %ebx, %r11d       [41 89 DB]
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4F4DB8941);
  // xorl %ecx, %r11d       [41 31 CB]
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4F4CB3141);
  // andl %edx, %r11d       [41 21 D3]
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4F4D32141);
  // xorl %ecx, %r11d       [41 31 CB]
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4F4CB3141);
  GPR[11]
}

// ============================================================================
// 2. FIAT mulx preserves rdx
// ============================================================================
// mulx does NOT modify rdx (implicit source). The FIAT compiler doesn't
// know this, so it inserts redundant reloads. Prove rdx is unchanged.
// Encoding: mulx r10, rax, r8 = VEX.NDS.LZ.F2.0F38.W1 F6 /r
//   C4 42 FB F6 D0  (5 bytes)

val test_mulx_rdx_after : unit -> bits(64)
function test_mulx_rdx_after() = {
  // mulx r10, rax, r8       [C4 42 FB F6 D0]
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4D0F6FB42C4);
  GPR[2]  // rdx — should be unchanged
}

val test_rdx_identity : unit -> bits(64)
function test_rdx_identity() = {
  GPR[2]  // rdx — no instruction executed
}

// ============================================================================
// 3. AES-NI domain: xorps == pxor on XMM registers
// ============================================================================
// xorps is float-domain, pxor is integer-domain. Both compute bitwise XOR.
// Replacing xorps with pxor avoids a domain-crossing penalty before aesenc.
// xorps xmm0, xmm1: 0F 57 C1 (3 bytes)
// pxor  xmm0, xmm1: 66 0F EF C1 (4 bytes)

val test_xorps_xmm : unit -> bits(512)
function test_xorps_xmm() = {
  // xorps %xmm1, %xmm0     [0F 57 C1]
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4F4C1570F);
  ZMM[0]
}

val test_pxor_xmm : unit -> bits(512)
function test_pxor_xmm() = {
  // pxor %xmm1, %xmm0      [66 0F EF C1]
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4C1EF0F66);
  ZMM[0]
}

// ============================================================================
// 4. xorl %eax,%eax == xorq %rax,%rax (zeroing idiom)
// ============================================================================
// xorl %eax,%eax: 31 C0 (2 bytes) — canonical zeroing, proper idiom
// xorq %rax,%rax: 48 31 C0 (3 bytes) — wastes REX.W byte
// Both zero rax and set flags identically.

val test_xor32_zero : unit -> bits(64)
function test_xor32_zero() = {
  // xorl %eax, %eax         [31 C0]
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4F4F4C031);
  GPR[0]
}

val test_xor64_zero : unit -> bits(64)
function test_xor64_zero() = {
  // xorq %rax, %rax         [48 31 C0]
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4F4C03148);
  GPR[0]
}

// ============================================================================
// 5. cmpq $0,%rcx == testq %rcx,%rcx (zero test)
// ============================================================================
// cmpq $0,%rcx: 48 83 F9 00 (4 bytes)
// testq %rcx,%rcx: 48 85 C9 (3 bytes)
// Both set ZF=1 iff rcx==0, and set SF, CF=0, OF=0 identically.
// Return ZF @ SF @ CF @ OF @ PF packed as bits.

val test_cmpq_zero : unit -> bits(5)
function test_cmpq_zero() = {
  // cmpq $0, %rcx           [48 83 F9 00]
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F400F98348);
  ZF @ SF @ CF @ OF @ PF
}

val test_testq_self : unit -> bits(5)
function test_testq_self() = {
  // testq %rcx, %rcx        [48 85 C9]
  setup_and_exec(0xF4F4F4F4F4F4F4F4F4F4F4F4C98548);
  ZF @ SF @ CF @ OF @ PF
}
