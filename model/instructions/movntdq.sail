// MOVNTDQ — Store Packed Integers Using Non-Temporal Hint
// MOVNTPD — Store Packed Double-FP Using Non-Temporal Hint
// MOVNTPS — Store Packed Single-FP Using Non-Temporal Hint
// MOVNTQ — Store of Quadword Using Non-Temporal Hint
//
// Non-temporal stores are semantically equivalent to regular stores for
// spec purposes. The non-temporal hint tells the processor to minimize
// cache pollution but has no effect on program-visible state.
// The decoder handles addressing; these functions simply pass through
// the 128-bit or 64-bit value to be stored.

val exec_movntdq : (xmmword) -> xmmword
function exec_movntdq(src) = src

val exec_movntpd : (xmmword) -> xmmword
function exec_movntpd(src) = src

val exec_movntps : (xmmword) -> xmmword
function exec_movntps(src) = src

val exec_movntq : (xmmword) -> qword
function exec_movntq(src) = src[63..0]
