// Virtual-8086 execution and interrupt virtualization (SDM Vol.3B §23).
// VM is represented by cur_mode; VIF and VIP are independent EFLAGS bits.

// IRETD at CPL 0 is the non-task-switch entry to virtual-8086 mode.
// Read the complete frame before changing any segment or privilege state.
val iret_to_vm86 : (qword, word, qword) -> unit
function iret_to_vm86(ip, cs, flags) = {
  if EFER[10] == bitone then raise_GP0();
  let sp : dword = pop(32);
  let ss : word = pop(32)[15..0];
  let es : word = pop(32)[15..0];
  let ds : word = pop(32)[15..0];
  let fs : word = pop(32)[15..0];
  let gs : word = pop(32)[15..0];
  cur_mode = Virtual8086Mode;
  cur_cpl = 3;
  write_rflags(flags);
  RF = flags[16];
  VIF = flags[19];
  VIP = flags[20];
  load_vm86_segment(CS, cs);
  load_vm86_segment(SS, ss);
  load_vm86_segment(ES, es);
  load_vm86_segment(DS, ds);
  load_vm86_segment(FS, fs);
  load_vm86_segment(GS, gs);
  v(RSP) = sp;
  // IRETD entry loads the low 16 bits of EIP (checked on AMD and Intel).
  next_rip = Some(zero_extend(ip[15..0]))
}

// IRET within virtual-8086 mode cannot leave it or change IOPL/VIP.
// With VME, a 16-bit IRET virtualizes IF like POPF. This behavior is
// missing from Vol.2's IRET pseudocode, but occurs on both AMD and Intel.
val iret_in_vm86 : forall 'os, 'os in {16, 32}. int('os) -> unit
function iret_in_vm86(os) = {
  let virtualize = IOPL != 0b11;
  if virtualize & (CR4[0] == bitzero | os != 16) then raise_GP0();
  let ip : qword = zero_extend(pop(os));
  let cs : word = pop(os)[15..0];
  var flags : qword = zero_extend(pop(os));
  if unsigned(ip) > 65535 then raise_GP0();
  if virtualize then {
    if flags[8] == bitone | (VIP == bitone & flags[9] == bitone) then raise_GP0();
    VIF = flags[9];
    flags[9] = IF_flag
  };
  flags[13..12] = IOPL;
  if os == 16 then {
    flags[18] = AC_flag;
    flags[21] = ID
  };
  write_rflags(flags);
  if os == 32 then RF = flags[16];
  load_vm86_segment(CS, cs);
  next_rip = Some(ip)
}

// IN/OUT/INS/OUTS always consult the I/O map in virtual-8086 mode.
// In protected mode only CPL > IOPL requires it (SDM Vol.1 §20.5).
// Reading the map is an implicit supervisor access, not a user data load.
val check_io_permission : (word, range(1, 4)) -> unit
function check_io_permission(port, nbytes) = {
  if cur_mode != RealMode & (cur_mode == Virtual8086Mode | cur_cpl > unsigned(IOPL)) then {
    if unsigned(TR_limit) < 103 then raise_GP0();
    let map_base : word = read_mem_implicit(TR_base + 102);
    let offset = unsigned(map_base) + unsigned(port[15..3]);
    if offset + 1 > unsigned(TR_limit) then raise_GP0();
    let permissions : word = read_mem_implicit(TR_base + offset);
    let mask : word = (0x0001 << nbytes) - 1;
    if ((permissions >> unsigned(port[2..0])) & mask) != zeros() then raise_GP0()
  }
}

// CLI/STI at insufficient IOPL can operate on VIF instead of IF. VME
// applies in virtual-8086 mode, PVI at CPL 3 in the other protected modes.
val exec_interrupt_flag : bool -> unit
function exec_interrupt_flag(enable) = {
  if cur_mode == RealMode | cur_cpl <= unsigned(IOPL) then {
    if enable & IF_flag == bitzero then sti_shadow = 2;
    IF_flag = if enable then bitone else bitzero
  } else {
    let virtualize = cur_cpl == 3 &
      (if cur_mode == Virtual8086Mode then CR4[0] == bitone else CR4[1] == bitone);
    if ~(virtualize) | (enable & VIP == bitone) then raise_GP0();
    VIF = if enable then bitone else bitzero
  }
}

// Return true if INT imm8 was redirected through the virtual-8086 IVT.
// The redirection bitmap occupies the 32 bytes before the TSS I/O map.
// INT3, INTO and INT1 never use it (SDM Vol.3B §23.3.3).
val redirect_vm86_interrupt : (exception_vector, qword) -> bool
function redirect_vm86_interrupt(vec, return_ip) = {
  if cur_mode != Virtual8086Mode then return false;
  if CR4[0] == bitone then {
    if unsigned(TR_limit) < 103 then raise_GP0();
    let map_base : word = read_mem_implicit(TR_base + 102);
    let base : range(0, 65535) = unsigned(map_base);
    if base < 32 then raise_GP0();
    let vec_bits : byte = to_bits(8, vec);
    let offset = base - 32 + unsigned(vec_bits[7..3]);
    if offset > unsigned(TR_limit) then raise_GP0();
    let entry : byte = read_mem_implicit(TR_base + offset);
    if entry[unsigned(vec_bits[2..0])] == bitzero then {
      // The virtual IVT is at linear address zero, not IDTR.base, and
      // its implicit reads use supervisor privilege (Vol.3A §4.6).
      let target : dword = read_mem_implicit(to_bits(64, vec * 4));
      let bottom : word = v(16, RSP) - 6;
      check_seg_limit(SS, zero_extend(bottom), 6);
      var flags : word = read_rflags()[15..0];
      if IOPL != 0b11 then { flags[9] = VIF; flags[13..12] = 0b11 };
      push(flags);
      push(read_segreg(CS));
      push(return_ip[15..0]);
      if IOPL == 0b11 then IF_flag = bitzero else VIF = bitzero;
      TF = bitzero;
      load_vm86_segment(CS, target[31..16]);
      next_rip = Some(zero_extend(target[15..0]));
      event_delivered = true;
      return true
    }
  };
  if IOPL != 0b11 then raise_GP0();
  false
}
