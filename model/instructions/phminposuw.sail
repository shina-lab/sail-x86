// PHMINPOSUW — Packed Horizontal Minimum of Unsigned Words (SSE4.1)
// Finds the minimum unsigned word and its index. No flags affected.

val exec_phminposuw : (simd_idx, xmmword) -> ExecutionResult
function exec_phminposuw(dst, src) = {
  let s : xmmword = src;
  let w0 : word = s[15..0];
  let w1 : word = s[31..16];
  let w2 : word = s[47..32];
  let w3 : word = s[63..48];
  let w4 : word = s[79..64];
  let w5 : word = s[95..80];
  let w6 : word = s[111..96];
  let w7 : word = s[127..112];
  // Find minimum value and index (lowest index wins on tie)
  let min_val : word = w0;
  let min_idx : word = 0x0000;
  let (min_val, min_idx) = if unsigned(w1) < unsigned(min_val) then (w1, 0x0001) else (min_val, min_idx);
  let (min_val, min_idx) = if unsigned(w2) < unsigned(min_val) then (w2, 0x0002) else (min_val, min_idx);
  let (min_val, min_idx) = if unsigned(w3) < unsigned(min_val) then (w3, 0x0003) else (min_val, min_idx);
  let (min_val, min_idx) = if unsigned(w4) < unsigned(min_val) then (w4, 0x0004) else (min_val, min_idx);
  let (min_val, min_idx) = if unsigned(w5) < unsigned(min_val) then (w5, 0x0005) else (min_val, min_idx);
  let (min_val, min_idx) = if unsigned(w6) < unsigned(min_val) then (w6, 0x0006) else (min_val, min_idx);
  let (min_val, min_idx) = if unsigned(w7) < unsigned(min_val) then (w7, 0x0007) else (min_val, min_idx);
  write_xmm_legacy(dst, zeros(96) @ min_idx @ min_val);
  Ok(())
}
