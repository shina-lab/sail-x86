// VMX (Virtual Machine Extensions) Instructions
//
// VMCALL, VMCLEAR, VMFUNC, VMLAUNCH, VMRESUME, VMPTRLD, VMPTRST,
// VMREAD, VMWRITE, VMXOFF, VMXON
//
// All VMX instructions are privileged operations that interact with
// processor virtualization state (VMCS, VMX root/non-root operation).
// Modeled as external functions since they require access to
// implementation-specific VMX state.

// External VMX operation primitives.
// Each returns a status indicating success or the appropriate fault.
val __vmx_vmcall : unit -> ExecutionResult
val __vmx_vmclear : qword -> ExecutionResult
val __vmx_vmfunc : unit -> ExecutionResult
val __vmx_vmlaunch : unit -> ExecutionResult
val __vmx_vmresume : unit -> ExecutionResult
val __vmx_vmptrld : qword -> ExecutionResult
val __vmx_vmptrst : unit -> (ExecutionResult, qword)
val __vmx_vmread : qword -> (ExecutionResult, qword)
val __vmx_vmwrite : (qword, qword) -> ExecutionResult
val __vmx_vmxoff : unit -> ExecutionResult
val __vmx_vmxon : qword -> ExecutionResult

// VMCALL — Call to VM Monitor
// Causes a VM exit to the VMM. Used by guest software to request VMM service.
val exec_vmcall : unit -> ExecutionResult
function exec_vmcall() = __vmx_vmcall()

// VMCLEAR — Clear Virtual-Machine Control Structure
// Ensures that VMCS data for the specified VMCS region is copied to memory.
// Operand is a 64-bit memory address of the VMCS region.
val exec_vmclear : qword -> ExecutionResult
function exec_vmclear(addr) = __vmx_vmclear(addr)

// VMFUNC — Invoke VM Function
// Invokes a VM function specified in EAX. Available in VMX non-root operation.
val exec_vmfunc : unit -> ExecutionResult
function exec_vmfunc() = __vmx_vmfunc()

// VMLAUNCH — Launch Virtual Machine
// Launches a virtual machine managed by the current VMCS.
// Enters VMX non-root operation for the first time.
val exec_vmlaunch : unit -> ExecutionResult
function exec_vmlaunch() = __vmx_vmlaunch()

// VMRESUME — Resume Virtual Machine
// Resumes a virtual machine managed by the current VMCS.
// Re-enters VMX non-root operation after a VM exit.
val exec_vmresume : unit -> ExecutionResult
function exec_vmresume() = __vmx_vmresume()

// VMPTRLD — Load Pointer to Virtual-Machine Control Structure
// Marks the VMCS at the specified address as active and current.
// Operand is a 64-bit memory address of the VMCS region.
val exec_vmptrld : qword -> ExecutionResult
function exec_vmptrld(addr) = __vmx_vmptrld(addr)

// VMPTRST — Store Pointer to Virtual-Machine Control Structure
// Stores the address of the current VMCS to a 64-bit memory location.
val exec_vmptrst : qword -> ExecutionResult
function exec_vmptrst(_) = {
  let (result, _vmcs_ptr) = __vmx_vmptrst();
  result
}

// VMREAD — Read Field from Virtual-Machine Control Structure
// Reads a specified field from the current VMCS.
// Source operand (r64/m64) identifies the VMCS field by encoding.
// CF and ZF indicate success/failure.
val exec_vmread : (gpr_idx, qword) -> ExecutionResult
function exec_vmread(dst, field_encoding) = {
  let (result, value) = __vmx_vmread(field_encoding);
  match result {
    Ok(()) => {
      write_gpr64(dst, value);
      Ok(())
    },
    _ => result,
  }
}

// VMWRITE — Write Field to Virtual-Machine Control Structure
// Writes a value to a specified field of the current VMCS.
// First operand is VMCS field encoding, second is the value to write.
// CF and ZF indicate success/failure.
val exec_vmwrite : (qword, qword) -> ExecutionResult
function exec_vmwrite(field_encoding, value) = __vmx_vmwrite(field_encoding, value)

// VMXOFF — Leave VMX Operation
// Causes the processor to leave VMX operation (exits VMX root operation).
val exec_vmxoff : unit -> ExecutionResult
function exec_vmxoff() = __vmx_vmxoff()

// VMXON — Enter VMX Operation
// Puts the processor in VMX root operation (enables VMX).
// Operand is a 64-bit memory address of the VMXON region.
val exec_vmxon : qword -> ExecutionResult
function exec_vmxon(addr) = __vmx_vmxon(addr)
