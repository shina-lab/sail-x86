$include "../model/prelude.sail"

type dword = bits(32)
type qword = bits(64)

val pc8 : bits(8) -> range(0, 8)
function pc8(v) =
  unsigned(v[0..0]) + unsigned(v[1..1]) + unsigned(v[2..2]) + unsigned(v[3..3]) +
  unsigned(v[4..4]) + unsigned(v[5..5]) + unsigned(v[6..6]) + unsigned(v[7..7])

val pc16 : bits(16) -> range(0, 16)
function pc16(v) = pc8(v[7..0]) + pc8(v[15..8])

val pc32 : dword -> range(0, 32)
function pc32(v) = pc16(v[15..0]) + pc16(v[31..16])

val pc64 : qword -> range(0, 64)
function pc64(v) = pc32(v[31..0]) + pc32(v[63..32])

// Reference: chain of bit tests
val clz64_ref : qword -> qword
function clz64_ref(v) =
  if v[63] == bitone then 0x0000000000000000
  else if v[62] == bitone then 0x0000000000000001
  else if v[61] == bitone then 0x0000000000000002
  else if v[60] == bitone then 0x0000000000000003
  else if v[59] == bitone then 0x0000000000000004
  else if v[58] == bitone then 0x0000000000000005
  else if v[57] == bitone then 0x0000000000000006
  else if v[56] == bitone then 0x0000000000000007
  else if v[55] == bitone then 0x0000000000000008
  else if v[54] == bitone then 0x0000000000000009
  else if v[53] == bitone then 0x000000000000000A
  else if v[52] == bitone then 0x000000000000000B
  else if v[51] == bitone then 0x000000000000000C
  else if v[50] == bitone then 0x000000000000000D
  else if v[49] == bitone then 0x000000000000000E
  else if v[48] == bitone then 0x000000000000000F
  else if v[47] == bitone then 0x0000000000000010
  else if v[46] == bitone then 0x0000000000000011
  else if v[45] == bitone then 0x0000000000000012
  else if v[44] == bitone then 0x0000000000000013
  else if v[43] == bitone then 0x0000000000000014
  else if v[42] == bitone then 0x0000000000000015
  else if v[41] == bitone then 0x0000000000000016
  else if v[40] == bitone then 0x0000000000000017
  else if v[39] == bitone then 0x0000000000000018
  else if v[38] == bitone then 0x0000000000000019
  else if v[37] == bitone then 0x000000000000001A
  else if v[36] == bitone then 0x000000000000001B
  else if v[35] == bitone then 0x000000000000001C
  else if v[34] == bitone then 0x000000000000001D
  else if v[33] == bitone then 0x000000000000001E
  else if v[32] == bitone then 0x000000000000001F
  else if v[31] == bitone then 0x0000000000000020
  else if v[30] == bitone then 0x0000000000000021
  else if v[29] == bitone then 0x0000000000000022
  else if v[28] == bitone then 0x0000000000000023
  else if v[27] == bitone then 0x0000000000000024
  else if v[26] == bitone then 0x0000000000000025
  else if v[25] == bitone then 0x0000000000000026
  else if v[24] == bitone then 0x0000000000000027
  else if v[23] == bitone then 0x0000000000000028
  else if v[22] == bitone then 0x0000000000000029
  else if v[21] == bitone then 0x000000000000002A
  else if v[20] == bitone then 0x000000000000002B
  else if v[19] == bitone then 0x000000000000002C
  else if v[18] == bitone then 0x000000000000002D
  else if v[17] == bitone then 0x000000000000002E
  else if v[16] == bitone then 0x000000000000002F
  else if v[15] == bitone then 0x0000000000000030
  else if v[14] == bitone then 0x0000000000000031
  else if v[13] == bitone then 0x0000000000000032
  else if v[12] == bitone then 0x0000000000000033
  else if v[11] == bitone then 0x0000000000000034
  else if v[10] == bitone then 0x0000000000000035
  else if v[9]  == bitone then 0x0000000000000036
  else if v[8]  == bitone then 0x0000000000000037
  else if v[7]  == bitone then 0x0000000000000038
  else if v[6]  == bitone then 0x0000000000000039
  else if v[5]  == bitone then 0x000000000000003A
  else if v[4]  == bitone then 0x000000000000003B
  else if v[3]  == bitone then 0x000000000000003C
  else if v[2]  == bitone then 0x000000000000003D
  else if v[1]  == bitone then 0x000000000000003E
  else if v[0]  == bitone then 0x000000000000003F
  else 0x0000000000000040

// Branchless: smear + popcount
val clz64_new : qword -> qword
function clz64_new(v) = {
  let x1 : qword = v  | (v  >> 1);
  let x2 : qword = x1 | (x1 >> 2);
  let x3 : qword = x2 | (x2 >> 4);
  let x4 : qword = x3 | (x3 >> 8);
  let x5 : qword = x4 | (x4 >> 16);
  let x6 : qword = x5 | (x5 >> 32);
  to_bits(64, 64 - pc64(x6))
}

$property
function prop_clz64(v : qword) -> bool =
  clz64_ref(v) == clz64_new(v)
