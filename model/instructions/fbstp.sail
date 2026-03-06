// FBSTP — Store BCD Integer and Pop
//
// Converts ST(0) to an 80-bit packed BCD value, stores it to memory,
// and pops the register stack.

val exec_fbstp : unit -> fp80
function exec_fbstp() = {
  let v : fp80 = __x87_pop();
  __f80_to_bcd(v)
}
