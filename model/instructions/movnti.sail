// MOVNTI — Store Doubleword/Quadword Using Non-Temporal Hint
//
// MOVNTI is semantically equivalent to a regular MOV store. The
// non-temporal hint tells the processor to minimize cache pollution,
// but this has no architectural effect on program-visible state.
// The decoder handles addressing; these functions simply pass through
// the value to be stored.

val exec_movnti32 : dword -> dword
function exec_movnti32(val32) = val32

val exec_movnti64 : qword -> qword
function exec_movnti64(val64) = val64
