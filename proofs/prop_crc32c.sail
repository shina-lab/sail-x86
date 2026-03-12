$include "../model/prelude.sail"

type byte = bits(8)
type dword = bits(32)

// Reference: branchy version
val crc32c_ref : (dword, byte) -> dword
function crc32c_ref(crc, data) = {
  var c : dword = crc ^ zero_extend(data);
  foreach (i from 0 to 7) {
    if c[0] == bitone then {
      c = (0b0 @ c[31..1]) ^ 0x82F63B78
    } else {
      c = 0b0 @ c[31..1]
    }
  };
  c
}

// Branchless: conditional XOR via mask
val crc32c_new : (dword, byte) -> dword
function crc32c_new(crc, data) = {
  var c : dword = crc ^ zero_extend(data);
  foreach (i from 0 to 7) {
    c = (0b0 @ c[31..1]) ^ (replicate_bits(c[0..0], 32) & 0x82F63B78)
  };
  c
}

$property
function prop_crc32c(crc : dword, data : byte) -> bool =
  crc32c_ref(crc, data) == crc32c_new(crc, data)
