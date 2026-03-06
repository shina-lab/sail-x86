// RDSEED — Read Random SEED
//
// Loads a hardware-generated random seed into destination.
// CF=1 if seed available, CF=0 if not (dest set to 0).
// OF, SF, ZF, AF, PF cleared.

val __rdseed16 : unit -> option(word)
val __rdseed32 : unit -> option(dword)
val __rdseed64 : unit -> option(qword)

val exec_rdseed : (gpr_idx, OperandSize) -> ExecutionResult
function exec_rdseed(dst, os) = {
  match os {
    OS16 => match __rdseed16() {
      Some(v) => { write_gpr16(dst, v); CF = bitone; },
      None()  => { write_gpr16(dst, zeros()); CF = bitzero; },
    },
    OS32 => match __rdseed32() {
      Some(v) => { write_gpr32(dst, v); CF = bitone; },
      None()  => { write_gpr32(dst, zeros()); CF = bitzero; },
    },
    OS64 => match __rdseed64() {
      Some(v) => { write_gpr64(dst, v); CF = bitone; },
      None()  => { write_gpr64(dst, zeros()); CF = bitzero; },
    },
    _ => (),
  };
  OF = bitzero;
  SF = bitzero;
  ZF = bitzero;
  AF = bitzero;
  PF = bitzero;
  Ok(())
}
