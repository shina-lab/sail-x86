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

// IRET within virtual-8086 mode cannot leave it or change IOPL/VIF/VIP.
// Unlike POPF, IRET still traps at IOPL < 3 with CR4.VME set (Vol.2 IRET).
val iret_in_vm86 : forall 'os, 'os in {16, 32}. int('os) -> unit
function iret_in_vm86(os) = {
  if IOPL != 0b11 then raise_GP0();
  let ip : qword = zero_extend(pop(os));
  let cs : word = pop(os)[15..0];
  var flags : qword = zero_extend(pop(os));
  if unsigned(ip) > 65535 then raise_GP0();
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
    let permissions : word = read_mem_implicit(TR_base + to_bits(64, offset));
    let mask : word = (0x0001 << nbytes) - 1;
    if ((permissions >> unsigned(port[2..0])) & mask) != zeros() then raise_GP0()
  }
}
