// VPERMT2* — Full Permute From Two Tables Overwriting a Table (AVX-512)
// Modeled as external functions (no YMM/ZMM infrastructure).

val __vpermt2b : unit -> ExecutionResult
val exec_vpermt2b : unit -> ExecutionResult
function exec_vpermt2b() = __vpermt2b()

val __vpermt2w : unit -> ExecutionResult
val exec_vpermt2w : unit -> ExecutionResult
function exec_vpermt2w() = __vpermt2w()

val __vpermt2d : unit -> ExecutionResult
val exec_vpermt2d : unit -> ExecutionResult
function exec_vpermt2d() = __vpermt2d()

val __vpermt2q : unit -> ExecutionResult
val exec_vpermt2q : unit -> ExecutionResult
function exec_vpermt2q() = __vpermt2q()

val __vpermt2ps : unit -> ExecutionResult
val exec_vpermt2ps : unit -> ExecutionResult
function exec_vpermt2ps() = __vpermt2ps()

val __vpermt2pd : unit -> ExecutionResult
val exec_vpermt2pd : unit -> ExecutionResult
function exec_vpermt2pd() = __vpermt2pd()
