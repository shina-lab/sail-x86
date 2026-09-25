# Rewrite task for one batch of blocks

You are given a JSON file with straight-line x86-64 instruction sequences
("blocks") taken from hand-written assembly in production software.  For
every block, decide whether it can be replaced by an equivalent sequence
with **fewer instructions**, and if so write that sequence.

## What "equivalent" means

The rewrite runs from the same initial machine state as the original and
must leave the same values in

* every register named in `must_preserve_final_values_of`,
* every flag named in `flags_that_must_match` (CF, PF, ZF, SF, OF), and
* memory: it must perform the same stores (same addresses, same values)
  and it may load only from addresses the original loads from.

Everything else is free: any register or flag not listed may end with any
value, so those registers can be used as scratch, and the original's own
temporaries need not be reproduced.  Vector registers are compared at the
width given in `note` (an AVX-level block compares whole ymm registers, so
a legacy SSE instruction that leaves the upper half unchanged is not the
same as a VEX instruction that zeroes it).

Registers listed in `memory` hold addresses (a base register points to a
buffer, an index register holds an unknown index).  Do not change how
addresses are formed: use the same base and index registers with the same
displacements.  Do not use the stack or any other memory.

`constants` are the values the original loads through `[CONST_n]`; a
rewrite may use them with the same `[CONST_n]` operand syntax (for
example `paddw xmm2,XMMWORD PTR [CONST_2]`) and may also drop them.
Their bytes are given in little-endian order and decoded as 8, 16 and 32
bit elements.

## What instructions are allowed

Only instructions at or below `isa_level`, plus the listed
`extensions_also_allowed`.  Rewriting SSE2 code with SSSE3 or AVX
instructions is not an optimization of that code, it is a different code
path the project already dispatches separately, so it does not count.
Using older instructions is fine.  A rewrite that assembles only with a
newer instruction set is rejected automatically.

## What to write

Write one JSON object to the output path you were given, mapping every
block id to either

    {"rewrite": "instr\ninstr\n...", "saved": N, "why": "one or two sentences"}

or

    {"rewrite": null, "why": "one sentence on why the block is already tight"}

`rewrite` is Intel syntax, one instruction per line, exactly as objdump
prints it (destination first; `XMMWORD PTR`, `YMMWORD PTR`, `ZMMWORD PTR`,
`QWORD PTR`, `DWORD PTR` on memory operands; hexadecimal immediates are
fine).  `saved` is the number of instructions removed.  Include every
block id of the batch.

## How to work

Work from your knowledge of the instruction set; do not execute code.
Propose a rewrite when you believe it is correct; it will be checked
formally afterwards, and a wrong proposal is a useful data point, not a
failure.  But do not propose changes that merely rename registers or
reorder instructions without removing any, and do not propose a rewrite
you think is probably wrong.  Typical opportunities: an instruction whose
result is dead or recomputed, a copy that can be folded into a
three-operand VEX form, an operation with an identity or absorbing
operand, an unpack/shift/pack sequence that a single instruction performs,
arithmetic on widened lanes that can be done on the narrow lanes with
PAVGB/PMADDUBSW/PMULHRSW-style instructions, a mask built with several
instructions that a comparison produces directly, or a redundant zeroing
of an already-zero register.
