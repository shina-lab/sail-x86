// AMX — Advanced Matrix Extensions
//
// AMX instructions operate on tile registers which are not part of our
// register infrastructure. All AMX instructions are modeled as external.

// STTILECFG — Store Tile Configuration
// Stores the tile configuration from the TILECFG register to memory.
val __sttilecfg : unit -> zmmword

val exec_sttilecfg : unit -> zmmword
function exec_sttilecfg() = __sttilecfg()

// TDPBF16PS — Dot Product of BF16 Pairs Accumulated into Packed Single Precision
val __tdpbf16ps : (byte, byte, byte) -> ExecutionResult

val exec_tdpbf16ps : (byte, byte, byte) -> ExecutionResult
function exec_tdpbf16ps(dst, src1, src2) = __tdpbf16ps(dst, src1, src2)

// TDPBSSD — Dot Product of Signed Bytes Accumulated into Signed Dwords
val __tdpbssd : (byte, byte, byte) -> ExecutionResult

val exec_tdpbssd : (byte, byte, byte) -> ExecutionResult
function exec_tdpbssd(dst, src1, src2) = __tdpbssd(dst, src1, src2)

// TDPBSUD — Dot Product of Signed/Unsigned Bytes Accumulated into Signed Dwords
val __tdpbsud : (byte, byte, byte) -> ExecutionResult

val exec_tdpbsud : (byte, byte, byte) -> ExecutionResult
function exec_tdpbsud(dst, src1, src2) = __tdpbsud(dst, src1, src2)

// TDPBUSD — Dot Product of Unsigned/Signed Bytes Accumulated into Signed Dwords
val __tdpbusd : (byte, byte, byte) -> ExecutionResult

val exec_tdpbusd : (byte, byte, byte) -> ExecutionResult
function exec_tdpbusd(dst, src1, src2) = __tdpbusd(dst, src1, src2)

// TDPBUUD — Dot Product of Unsigned Bytes Accumulated into Unsigned Dwords
val __tdpbuud : (byte, byte, byte) -> ExecutionResult

val exec_tdpbuud : (byte, byte, byte) -> ExecutionResult
function exec_tdpbuud(dst, src1, src2) = __tdpbuud(dst, src1, src2)

// TILELOADD — Load Tile
// Loads a tile from memory using a stride specified in a register.
val __tileloadd : (byte, qword, qword) -> ExecutionResult

val exec_tileloadd : (byte, qword, qword) -> ExecutionResult
function exec_tileloadd(dst, base, stride) = __tileloadd(dst, base, stride)

// TILELOADDT1 — Load Tile (with hint)
// Same as TILELOADD but with a non-temporal cache hint.
val __tileloaddt1 : (byte, qword, qword) -> ExecutionResult

val exec_tileloaddt1 : (byte, qword, qword) -> ExecutionResult
function exec_tileloaddt1(dst, base, stride) = __tileloaddt1(dst, base, stride)

// TILERELEASE — Release Tile
// Marks all tiles as not in use, invalidating tile state.
val __tilerelease : unit -> unit

val exec_tilerelease : unit -> ExecutionResult
function exec_tilerelease() = {
  __tilerelease();
  Ok(())
}

// TILESTORED — Store Tile
// Stores a tile to memory using a stride specified in a register.
val __tilestored : (byte, qword, qword) -> ExecutionResult

val exec_tilestored : (byte, qword, qword) -> ExecutionResult
function exec_tilestored(src, base, stride) = __tilestored(src, base, stride)

// TILEZERO — Zero Tile
// Zeros the destination tile.
val __tilezero : byte -> unit

val exec_tilezero : byte -> ExecutionResult
function exec_tilezero(dst) = {
  __tilezero(dst);
  Ok(())
}
