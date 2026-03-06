// PEXTRB — Extract Byte (SSE4.1)
// PEXTRD — Extract Dword (SSE4.1)
// PEXTRQ — Extract Qword (SSE4.1)
// No flags affected.

val extract_byte_from_xmm : (xmmword, byte) -> byte
function extract_byte_from_xmm(s, imm8) = {
  let sel : range(0, 15) = unsigned(imm8[3..0]);
  match sel {
    0  => s[7..0],
    1  => s[15..8],
    2  => s[23..16],
    3  => s[31..24],
    4  => s[39..32],
    5  => s[47..40],
    6  => s[55..48],
    7  => s[63..56],
    8  => s[71..64],
    9  => s[79..72],
    10 => s[87..80],
    11 => s[95..88],
    12 => s[103..96],
    13 => s[111..104],
    14 => s[119..112],
    15 => s[127..120]
  }
}

val extract_dword_from_xmm : (xmmword, byte) -> dword
function extract_dword_from_xmm(s, imm8) = {
  let sel : range(0, 3) = unsigned(imm8[1..0]);
  match sel {
    0 => s[31..0],
    1 => s[63..32],
    2 => s[95..64],
    3 => s[127..96]
  }
}

val extract_qword_from_xmm : (xmmword, byte) -> qword
function extract_qword_from_xmm(s, imm8) = {
  let sel : range(0, 1) = unsigned(imm8[0..0]);
  match sel {
    0 => s[63..0],
    1 => s[127..64]
  }
}
