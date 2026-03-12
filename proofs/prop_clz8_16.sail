$include "../model/prelude.sail"

type byte = bits(8)
type word = bits(16)

val pc8 : byte -> range(0, 8)
function pc8(v) =
  unsigned(v[0..0]) + unsigned(v[1..1]) + unsigned(v[2..2]) + unsigned(v[3..3]) +
  unsigned(v[4..4]) + unsigned(v[5..5]) + unsigned(v[6..6]) + unsigned(v[7..7])

val pc16 : word -> range(0, 16)
function pc16(v) = pc8(v[7..0]) + pc8(v[15..8])

// --- CLZ8 ---

val clz8_ref : byte -> byte
function clz8_ref(v) =
  if v[7] == bitone then 0x00
  else if v[6] == bitone then 0x01
  else if v[5] == bitone then 0x02
  else if v[4] == bitone then 0x03
  else if v[3] == bitone then 0x04
  else if v[2] == bitone then 0x05
  else if v[1] == bitone then 0x06
  else if v[0] == bitone then 0x07
  else 0x08

val clz8_new : byte -> byte
function clz8_new(v) = {
  let x1 : byte = v  | (v  >> 1);
  let x2 : byte = x1 | (x1 >> 2);
  let x3 : byte = x2 | (x2 >> 4);
  to_bits(8, 8 - pc8(x3))
}

$property
function prop_clz8(v : byte) -> bool =
  clz8_ref(v) == clz8_new(v)

// --- CLZ16 ---

val clz16_ref : word -> word
function clz16_ref(v) =
  if v[15] == bitone then 0x0000
  else if v[14] == bitone then 0x0001
  else if v[13] == bitone then 0x0002
  else if v[12] == bitone then 0x0003
  else if v[11] == bitone then 0x0004
  else if v[10] == bitone then 0x0005
  else if v[9]  == bitone then 0x0006
  else if v[8]  == bitone then 0x0007
  else if v[7]  == bitone then 0x0008
  else if v[6]  == bitone then 0x0009
  else if v[5]  == bitone then 0x000A
  else if v[4]  == bitone then 0x000B
  else if v[3]  == bitone then 0x000C
  else if v[2]  == bitone then 0x000D
  else if v[1]  == bitone then 0x000E
  else if v[0]  == bitone then 0x000F
  else 0x0010

val clz16_new : word -> word
function clz16_new(v) = {
  let x1 : word = v  | (v  >> 1);
  let x2 : word = x1 | (x1 >> 2);
  let x3 : word = x2 | (x2 >> 4);
  let x4 : word = x3 | (x3 >> 8);
  to_bits(16, 16 - pc16(x4))
}

$property
function prop_clz16(v : word) -> bool =
  clz16_ref(v) == clz16_new(v)
