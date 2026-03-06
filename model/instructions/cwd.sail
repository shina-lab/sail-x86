// CWD/CDQ/CQO — Convert Word/Doubleword/Quadword
//
// Sign-extends AX into DX:AX, EAX into EDX:EAX, or RAX into RDX:RAX.
// No flags affected.

val exec_cwd : OperandSize -> ExecutionResult
function exec_cwd(os) = {
  match os {
    OS16 => {
      let ax : word = read_gpr16(RAX);
      let ext : dword = sign_extend(ax);
      write_gpr16(RDX, ext[31..16])
    },
    OS32 => {
      let eax : dword = read_gpr32(RAX);
      let ext : qword = sign_extend(eax);
      write_gpr32(RDX, ext[63..32])
    },
    OS64 => {
      let rax : qword = read_gpr64(RAX);
      if rax[63] == bitone then
        write_gpr64(RDX, ones())
      else
        write_gpr64(RDX, zeros())
    },
    _ => (),
  };
  Ok(())
}
