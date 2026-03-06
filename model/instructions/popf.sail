// POPF/POPFD/POPFQ — Pop Stack Into EFLAGS Register
//
// Pops flags from stack. In 64-bit mode at CPL=0, all flags except
// VIP, VIF, VM are loaded. At CPL>0, IOPL is not modified.
// Simplified model: assumes CPL=0.

val exec_popf : OperandSize -> ExecutionResult
function exec_popf(os) = {
  match os {
    OS16 => {
      let v : word = pop16();
      CF = v[0];
      PF = v[2];
      AF = v[4];
      ZF = v[6];
      SF = v[7];
      TF = v[8];
      IF_flag = v[9];
      DF = v[10];
      OF = v[11];
    },
    OS64 => {
      let v : qword = pop64();
      CF = v[0];
      PF = v[2];
      AF = v[4];
      ZF = v[6];
      SF = v[7];
      TF = v[8];
      IF_flag = v[9];
      DF = v[10];
      OF = v[11];
      IOPL = v[13..12];
    },
    _ => (),
  };
  Ok(())
}
