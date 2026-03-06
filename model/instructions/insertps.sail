// INSERTPS — Insert Scalar Single-FP (SSE4.1)
// Selects a float from src, inserts into dst at specified position, then zeroes selected lanes.
// No flags affected.

val exec_insertps : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_insertps(dst, src, imm8) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  // Select source float using imm8[7:6]
  let src_sel : range(0, 3) = unsigned(imm8[7..6]);
  let src_float : dword = b[(src_sel * 32 + 31) .. (src_sel * 32)];
  // Insert at destination position using imm8[5:4]
  let dst_sel : range(0, 3) = unsigned(imm8[5..4]);
  let t0 : dword = if dst_sel == 0 then src_float else a[31..0];
  let t1 : dword = if dst_sel == 1 then src_float else a[63..32];
  let t2 : dword = if dst_sel == 2 then src_float else a[95..64];
  let t3 : dword = if dst_sel == 3 then src_float else a[127..96];
  // Zero lanes indicated by imm8[3:0]
  let d0 : dword = if imm8[0] == bitone then 0x00000000 else t0;
  let d1 : dword = if imm8[1] == bitone then 0x00000000 else t1;
  let d2 : dword = if imm8[2] == bitone then 0x00000000 else t2;
  let d3 : dword = if imm8[3] == bitone then 0x00000000 else t3;
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}
