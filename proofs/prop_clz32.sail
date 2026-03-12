$include "../model/prelude.sail"

type dword = bits(32)

val pc8 : bits(8) -> range(0, 8)
function pc8(v) =
  unsigned(v[0..0]) + unsigned(v[1..1]) + unsigned(v[2..2]) + unsigned(v[3..3]) +
  unsigned(v[4..4]) + unsigned(v[5..5]) + unsigned(v[6..6]) + unsigned(v[7..7])

val pc16 : bits(16) -> range(0, 16)
function pc16(v) = pc8(v[7..0]) + pc8(v[15..8])

val pc32 : dword -> range(0, 32)
function pc32(v) = pc16(v[15..0]) + pc16(v[31..16])

// Reference: chain of bit tests (unambiguous specification)
val clz32_ref : dword -> dword
function clz32_ref(v) =
  if v[31] == bitone then 0x00000000
  else if v[30] == bitone then 0x00000001
  else if v[29] == bitone then 0x00000002
  else if v[28] == bitone then 0x00000003
  else if v[27] == bitone then 0x00000004
  else if v[26] == bitone then 0x00000005
  else if v[25] == bitone then 0x00000006
  else if v[24] == bitone then 0x00000007
  else if v[23] == bitone then 0x00000008
  else if v[22] == bitone then 0x00000009
  else if v[21] == bitone then 0x0000000A
  else if v[20] == bitone then 0x0000000B
  else if v[19] == bitone then 0x0000000C
  else if v[18] == bitone then 0x0000000D
  else if v[17] == bitone then 0x0000000E
  else if v[16] == bitone then 0x0000000F
  else if v[15] == bitone then 0x00000010
  else if v[14] == bitone then 0x00000011
  else if v[13] == bitone then 0x00000012
  else if v[12] == bitone then 0x00000013
  else if v[11] == bitone then 0x00000014
  else if v[10] == bitone then 0x00000015
  else if v[9]  == bitone then 0x00000016
  else if v[8]  == bitone then 0x00000017
  else if v[7]  == bitone then 0x00000018
  else if v[6]  == bitone then 0x00000019
  else if v[5]  == bitone then 0x0000001A
  else if v[4]  == bitone then 0x0000001B
  else if v[3]  == bitone then 0x0000001C
  else if v[2]  == bitone then 0x0000001D
  else if v[1]  == bitone then 0x0000001E
  else if v[0]  == bitone then 0x0000001F
  else 0x00000020

// Branchless: smear + popcount
val clz32_new : dword -> dword
function clz32_new(v) = {
  let x1 : dword = v  | (v  >> 1);
  let x2 : dword = x1 | (x1 >> 2);
  let x3 : dword = x2 | (x2 >> 4);
  let x4 : dword = x3 | (x3 >> 8);
  let x5 : dword = x4 | (x4 >> 16);
  to_bits(32, 32 - pc32(x5))
}

$property
function prop_clz32(v : dword) -> bool =
  clz32_ref(v) == clz32_new(v)
