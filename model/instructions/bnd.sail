// BND (MPX) Instructions — Intel Memory Protection Extensions (deprecated)
// BNDCL, BNDCU, BNDCN, BNDLDX, BNDMK, BNDMOV, BNDSTX
//
// MPX is a deprecated feature. All BND instructions are modeled as
// external functions.

val __bndcl : (qword, qword) -> ExecutionResult
val __bndcu : (qword, qword) -> ExecutionResult
val __bndcn : (qword, qword) -> ExecutionResult
val __bndldx : (qword, qword) -> ExecutionResult
val __bndmk : (qword, qword) -> ExecutionResult
val __bndmov_load : (qword, qword) -> ExecutionResult
val __bndmov_store : (qword, qword) -> ExecutionResult
val __bndstx : (qword, qword) -> ExecutionResult

// BNDCL — Check Lower Bound
val exec_bndcl : (qword, qword) -> ExecutionResult
function exec_bndcl(bnd, addr) = __bndcl(bnd, addr)

// BNDCU — Check Upper Bound (one's complement)
val exec_bndcu : (qword, qword) -> ExecutionResult
function exec_bndcu(bnd, addr) = __bndcu(bnd, addr)

// BNDCN — Check Upper Bound (not one's complement)
val exec_bndcn : (qword, qword) -> ExecutionResult
function exec_bndcn(bnd, addr) = __bndcn(bnd, addr)

// BNDLDX — Load Extended Bounds Using Address Translation
val exec_bndldx : (qword, qword) -> ExecutionResult
function exec_bndldx(bnd, addr) = __bndldx(bnd, addr)

// BNDMK — Make Bounds
val exec_bndmk : (qword, qword) -> ExecutionResult
function exec_bndmk(bnd, addr) = __bndmk(bnd, addr)

// BNDMOV — Move Bounds (load form)
val exec_bndmov_load : (qword, qword) -> ExecutionResult
function exec_bndmov_load(bnd, addr) = __bndmov_load(bnd, addr)

// BNDMOV — Move Bounds (store form)
val exec_bndmov_store : (qword, qword) -> ExecutionResult
function exec_bndmov_store(bnd, addr) = __bndmov_store(bnd, addr)

// BNDSTX — Store Extended Bounds Using Address Translation
val exec_bndstx : (qword, qword) -> ExecutionResult
function exec_bndstx(bnd, addr) = __bndstx(bnd, addr)
