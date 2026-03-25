// Equivalence proof: compress store offset accumulator → popcount
//
// Old code:
//   var off = 0;
//   foreach (i from 0 to N) {
//     if mask[i] == 0b1 then {
//       write_mem(addr + off, elem[i]);
//       off = off + elem_size;
//     }
//   }
//
// New code:
//   foreach (i from 0 to N) {
//     if mask[i] == 0b1 then {
//       let off = popcount(mask[(i-1)..0]) * elem_size;
//       write_mem(addr + off, elem[i]);
//     }
//   }
//
// The offset for element i is the number of set bits below position i,
// times the element size. popcount(mask & ((1 << i) - 1)) gives this.
//
// Proof: for each active element i, the accumulated offset equals
// popcount of mask bits below i, times elem_size.

$include "../model/prelude.sail"

type qword = bits(64)

val popcount16 : bits(16) -> range(0, 16)
function popcount16(v) = {
  let x1 : qword = zero_extend(v);
  let x2 = (x1 & 0x5555555555555555) + ((x1 >> 1) & 0x5555555555555555);
  let x3 = (x2 & 0x3333333333333333) + ((x2 >> 2) & 0x3333333333333333);
  let x4 = (x3 & 0x0f0f0f0f0f0f0f0f) + ((x3 >> 4) & 0x0f0f0f0f0f0f0f0f);
  let x5 = (x4 & 0x00ff00ff00ff00ff) + ((x4 >> 8) & 0x00ff00ff00ff00ff);
  let x6 = (x5 & 0x0000ffff0000ffff) + ((x5 >> 16) & 0x0000ffff0000ffff);
  let x7 = (x6 & 0x00000000ffffffff) + ((x6 >> 32) & 0x00000000ffffffff);
  let x = unsigned(x7);
  assert(x <= 16);
  x
}

// Prove for 4 elements: accumulator offset matches popcount-based offset
$property
function prop_compress_offset_4(mask : bits(4)) -> bool = {
  // Old: accumulate offset
  var off0 : int = 0;
  var off1 : int = 0;
  var off2 : int = 0;
  var off3 : int = 0;
  var acc : int = 0;
  foreach (i from 0 to 3) {
    if mask[i] == 0b1 then {
      if i == 0 then off0 = acc;
      if i == 1 then off1 = acc;
      if i == 2 then off2 = acc;
      if i == 3 then off3 = acc;
      acc = acc + 1
    }
  };
  // New: popcount of lower bits
  let pc0 = popcount16(zero_extend(mask) & 0x0000);  // bits below 0: none
  let pc1 = popcount16(zero_extend(mask) & 0x0001);  // bits below 1: bit 0
  let pc2 = popcount16(zero_extend(mask) & 0x0003);  // bits below 2: bits 0-1
  let pc3 = popcount16(zero_extend(mask) & 0x0007);  // bits below 3: bits 0-2
  // For active elements, offsets must match
  (mask[0] == 0b0 | off0 == pc0) &
  (mask[1] == 0b0 | off1 == pc1) &
  (mask[2] == 0b0 | off2 == pc2) &
  (mask[3] == 0b0 | off3 == pc3)
}
