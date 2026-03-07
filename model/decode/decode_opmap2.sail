// x86-64 Decoder — 2-Byte Opcode Map (0F xx) Dispatch
//
// Phase 2: CMOVcc, SETcc, Jcc rel32, MOVZX/SX, BSF/BSR, CMPXCHG, BT*,
// SHLD/SHRD, IMUL 2-op, BSWAP, XADD, etc.

val dispatch_opcode_2byte : (byte, Prefixes) -> ExecutionResult
function dispatch_opcode_2byte(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  match op {
    // 0F 38: 3-byte escape (SSSE3/SSE4/AES-NI)
    56 => {
      let opcode3 = fetch_byte();
      dispatch_opcode_3byte_38(opcode3, pfx)
    },
    // 0F 3A: 3-byte escape (SSE4/AES-NI with imm8)
    58 => {
      let opcode3 = fetch_byte();
      dispatch_opcode_3byte_3a(opcode3, pfx)
    },

    // SSE floating-point (data movement, arithmetic, conversion, comparison)
    op if 16 <= op & op <= 23 => dispatch_2byte_sse_fp(op, pfx),
    op if 40 <= op & op <= 47 => dispatch_2byte_sse_fp(op, pfx),
    op if 80 <= op & op <= 95 => dispatch_2byte_sse_fp(op, pfx),
    124 => dispatch_2byte_sse_fp(op, pfx),
    125 => dispatch_2byte_sse_fp(op, pfx),
    194 => dispatch_2byte_sse_fp(op, pfx),
    198 => dispatch_2byte_sse_fp(op, pfx),
    208 => dispatch_2byte_sse_fp(op, pfx),
    214 => dispatch_2byte_sse_fp(op, pfx),
    230 => dispatch_2byte_sse_fp(op, pfx),

    // SSE integer (packed integer arithmetic, logical, shift, pack/unpack)
    op if 96 <= op & op <= 118 => dispatch_2byte_sse_int(op, pfx),
    126 => dispatch_2byte_sse_int(op, pfx),
    127 => dispatch_2byte_sse_int(op, pfx),
    196 => dispatch_2byte_sse_int(op, pfx),
    197 => dispatch_2byte_sse_int(op, pfx),
    op if 209 <= op & op <= 213 => dispatch_2byte_sse_int(op, pfx),
    op if 215 <= op & op <= 229 => dispatch_2byte_sse_int(op, pfx),
    op if 231 <= op & op <= 255 => dispatch_2byte_sse_int(op, pfx),

    // GPR and system operations (everything else)
    _ => dispatch_2byte_gpr(op, pfx),
  }
}
