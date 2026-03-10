// Isla footprint entry point for sail-x86-from-acl2 model.
// Spliced in to provide symbolic execution entry point.

val isla_reset_registers = pure "reset_registers" : unit -> unit

val isla_footprint : bits(120) -> bool

function isla_footprint(opcode) = {
  try {
    isla_reset_registers();
    app_view = true;
    ms_reg = false;
    fault_reg = false;
    log_register_writes = false;

    x86_fetch_decode_execute();
    not_bool(ms() | fault())
  } catch {
    _ => false
  }
}
