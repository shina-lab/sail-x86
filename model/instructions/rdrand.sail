// RDRAND — Read Random Number
//
// Loads a hardware-generated random number into destination.
// CF=1 if random data available, CF=0 if not (dest set to 0).
// OF, SF, ZF, AF, PF cleared.

val __rdrand16 : unit -> option(word)
val __rdrand32 : unit -> option(dword)
val __rdrand64 : unit -> option(qword)

val exec_rdrand : (gpr_idx, OperandSize) -> ExecutionResult
function exec_rdrand(dst, os) = {
  match os {
    OS16 => match __rdrand16() {
      Some(v) => { write_gpr16(dst, v); CF = bitone; },
      None()  => { write_gpr16(dst, zeros()); CF = bitzero; },
    },
    OS32 => match __rdrand32() {
      Some(v) => { write_gpr32(dst, v); CF = bitone; },
      None()  => { write_gpr32(dst, zeros()); CF = bitzero; },
    },
    OS64 => match __rdrand64() {
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
