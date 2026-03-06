// REP/REPE/REPZ/REPNE/REPNZ — Repeat String Operation Prefix
//
// REP: repeat while RCX != 0 (for MOVS, STOS, LODS, INS, OUTS).
// REPE/REPZ: also stop if ZF=0 after CMPS/SCAS.
// REPNE/REPNZ: also stop if ZF=1 after CMPS/SCAS.
// Address size (67h prefix) selects RCX vs ECX for the count register.

enum RepPrefix = { REP_none, REP_rep, REP_repe, REP_repne }

enum StringOp = { STR_movs, STR_stos, STR_lods, STR_cmps, STR_scas }

val exec_rep : (RepPrefix, StringOp, OperandSize, AddressSize) -> ExecutionResult
function exec_rep(prefix, op, os, asz) = {
  var done : bool = false;
  while ~(done) do {
    if read_count_reg(asz) == zeros() then
      done = true
    else {
      match op {
        STR_movs => { let _ = exec_movs(os, asz); () },
        STR_stos => { let _ = exec_stos(os, asz); () },
        STR_lods => { let _ = exec_lods(os, asz); () },
        STR_cmps => { let _ = exec_cmps(os, asz); () },
        STR_scas => { let _ = exec_scas(os, asz); () },
      };
      let cnt = read_count_reg(asz);
      write_count_reg(asz, cnt - 1);
      if read_count_reg(asz) == zeros() then
        done = true
      else match prefix {
        REP_repe  => if ZF == bitzero then done = true,
        REP_repne => if ZF == bitone then done = true,
        _         => (),
      };
    };
  };
  Ok(())
}
