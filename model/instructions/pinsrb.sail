// PINSRB — Insert Byte (SSE4.1)
// PINSRD — Insert Dword (SSE4.1)
// PINSRQ — Insert Qword (SSE4.1)
// No flags affected.

val insert_byte : (xmmword, byte, range(0, 15)) -> xmmword
function insert_byte(v, b, sel) = {
  match sel {
    0  => v[127..8] @ b,
    1  => v[127..16] @ b @ v[7..0],
    2  => v[127..24] @ b @ v[15..0],
    3  => v[127..32] @ b @ v[23..0],
    4  => v[127..40] @ b @ v[31..0],
    5  => v[127..48] @ b @ v[39..0],
    6  => v[127..56] @ b @ v[47..0],
    7  => v[127..64] @ b @ v[55..0],
    8  => v[127..72] @ b @ v[63..0],
    9  => v[127..80] @ b @ v[71..0],
    10 => v[127..88] @ b @ v[79..0],
    11 => v[127..96] @ b @ v[87..0],
    12 => v[127..104] @ b @ v[95..0],
    13 => v[127..112] @ b @ v[103..0],
    14 => v[127..120] @ b @ v[111..0],
    15 => b @ v[119..0]
  }
}

val exec_pinsrb : (simd_idx, byte, byte) -> ExecutionResult
function exec_pinsrb(dst, val8, imm8) = {
  let v : xmmword = read_xmm(dst);
  let sel : range(0, 15) = unsigned(imm8[3..0]);
  let r : xmmword = insert_byte(v, val8, sel);
  write_xmm_legacy(dst, r);
  Ok(())
}

val insert_dword : (xmmword, dword, range(0, 3)) -> xmmword
function insert_dword(v, d, sel) = {
  match sel {
    0 => v[127..32] @ d,
    1 => v[127..64] @ d @ v[31..0],
    2 => v[127..96] @ d @ v[63..0],
    3 => d @ v[95..0]
  }
}

val exec_pinsrd : (simd_idx, dword, byte) -> ExecutionResult
function exec_pinsrd(dst, val32, imm8) = {
  let v : xmmword = read_xmm(dst);
  let sel : range(0, 3) = unsigned(imm8[1..0]);
  let r : xmmword = insert_dword(v, val32, sel);
  write_xmm_legacy(dst, r);
  Ok(())
}

val exec_pinsrq : (simd_idx, qword, byte) -> ExecutionResult
function exec_pinsrq(dst, val64, imm8) = {
  let v : xmmword = read_xmm(dst);
  let sel : range(0, 1) = unsigned(imm8[0..0]);
  let r : xmmword = match sel {
    0 => v[127..64] @ val64,
    1 => val64 @ v[63..0]
  };
  write_xmm_legacy(dst, r);
  Ok(())
}
