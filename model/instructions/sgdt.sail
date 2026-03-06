// SGDT — Store Global Descriptor Table Register
//
// Stores the content of the GDTR (limit and base address) to memory.
// In 64-bit mode, stores 2-byte limit + 8-byte base (10 bytes total).
// In 32-bit mode, stores 2-byte limit + 4-byte base (6 bytes total).
// No flags affected. Modeled as external since GDTR is system state.

val __sgdt : unit -> (word, qword)

val exec_sgdt : unit -> (word, qword)
function exec_sgdt() = __sgdt()
