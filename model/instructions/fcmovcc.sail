// FCMOVcc — Floating-Point Conditional Move
//
// Tests EFLAGS condition codes and moves ST(i) to ST(0) if condition is true.
// Conditions test CF, ZF, PF from the integer EFLAGS register.

// FCMOVB ST(0), ST(i) — Move if below (CF=1).
val exec_fcmovb : int -> ExecutionResult
function exec_fcmovb(i) = {
  if CF == bitone then __x87_write_st(0, __x87_read_st(i));
  Ok(())
}

// FCMOVE ST(0), ST(i) — Move if equal (ZF=1).
val exec_fcmove : int -> ExecutionResult
function exec_fcmove(i) = {
  if ZF == bitone then __x87_write_st(0, __x87_read_st(i));
  Ok(())
}

// FCMOVBE ST(0), ST(i) — Move if below or equal (CF=1 or ZF=1).
val exec_fcmovbe : int -> ExecutionResult
function exec_fcmovbe(i) = {
  if CF == bitone | ZF == bitone then __x87_write_st(0, __x87_read_st(i));
  Ok(())
}

// FCMOVU ST(0), ST(i) — Move if unordered (PF=1).
val exec_fcmovu : int -> ExecutionResult
function exec_fcmovu(i) = {
  if PF == bitone then __x87_write_st(0, __x87_read_st(i));
  Ok(())
}

// FCMOVNB ST(0), ST(i) — Move if not below (CF=0).
val exec_fcmovnb : int -> ExecutionResult
function exec_fcmovnb(i) = {
  if CF == bitzero then __x87_write_st(0, __x87_read_st(i));
  Ok(())
}

// FCMOVNE ST(0), ST(i) — Move if not equal (ZF=0).
val exec_fcmovne : int -> ExecutionResult
function exec_fcmovne(i) = {
  if ZF == bitzero then __x87_write_st(0, __x87_read_st(i));
  Ok(())
}

// FCMOVNBE ST(0), ST(i) — Move if not below or equal (CF=0 and ZF=0).
val exec_fcmovnbe : int -> ExecutionResult
function exec_fcmovnbe(i) = {
  if CF == bitzero & ZF == bitzero then __x87_write_st(0, __x87_read_st(i));
  Ok(())
}

// FCMOVNU ST(0), ST(i) — Move if not unordered (PF=0).
val exec_fcmovnu : int -> ExecutionResult
function exec_fcmovnu(i) = {
  if PF == bitzero then __x87_write_st(0, __x87_read_st(i));
  Ok(())
}
