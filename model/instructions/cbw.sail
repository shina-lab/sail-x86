// CBW/CWDE/CDQE — Convert Byte/Word/Doubleword to Word/Doubleword/Quadword
//
// Sign-extends AL -> AX, AX -> EAX, or EAX -> RAX. No flags affected.

val exec_cbw : OperandSize -> ExecutionResult
function exec_cbw(os) = {
  match os {
    OS16 => {
      let al : byte = read_gpr8l(RAX);
      write_gpr16(RAX, sign_extend(al))
    },
    OS32 => {
      let ax : word = read_gpr16(RAX);
      write_gpr32(RAX, sign_extend(ax))
    },
    OS64 => {
      let eax : dword = read_gpr32(RAX);
      write_gpr64(RAX, sign_extend(eax))
    },
    _ => (),
  };
  Ok(())
}
