# Differential test inputs

Each test must explicitly initialize the register values its instruction
sequence reads, including zero-valued inputs. Leave unrelated registers and
write-only destinations at their defaults. This lets the harness detect both
missing writes and unintended changes to preserved state.

The harness constructs every test twice. Unspecified GPRs, ZMM registers,
opmask registers, and arithmetic flags (CF, PF, AF, ZF, SF, OF) start with
either all zero bits or all one bits. Explicit inputs override that background
in both runs. The test name reports the fill used. RSP, RIP, control flags,
MXCSR, and debug controls retain valid execution defaults. Setting all of
RFLAGS would enable single stepping and other changes to the execution setup.

For example, a 64-bit unsigned division with a zero high dividend must specify
RDX, even though it happens to be zero in the first run:

```cpp
ArchState input = {.rax = 42, .rcx = 7, .rdx = 0};
```

Do not add an RDX initializer to the corresponding 8-bit division, whose
dividend is AX. Likewise, initialize a store's source register without setting
the destination of the corresponding load.

When several forms share an operand pool, use `with_gpr_inputs` or
`with_vector_inputs` to select the inputs of the individual form. A memory form
must not carry over a register operand used only by the register form. These
helpers select existing values; the pool still needs explicit assignments for
every selected input.

Flags are inputs at bit granularity. For ADC with an incoming carry of zero,
use `.rflags = initial_flags(FL_CF, 0)`. ADOX instead declares OF. Conditional
operations select the flags their condition reads with `condition_flags_mask`
and `with_flag_inputs`. Do not preset the entire flags register just to supply
one carry bit. Flags that an instruction only writes or preserves must follow
the background, including CF for INC/DEC and all flags for a zero-count shift.
LAHF and PUSHF need explicit flag inputs because they read flags as data.

An old destination can be an input: FMA and variable funnel shifts read it,
and merging masks use its masked-off elements. EVEX test helpers supply a
nonzero merging input only for the merging variant. Scalar AVX operations can
also copy upper XMM bits from a source, so those bits need explicit values.
Bits merely preserved in their original register can stay at the background.

Review implicit inputs as well as encoded operands. XSAVE reads every register
in the requested state components; `with_xsave_vector_inputs` initializes the
vector and opmask portions of those components before distinctive values are
added. Conversely, an invalid encoding or disabled feature can fault before
reading its apparent operands; those values need no initialization.

Use `ZmmVal::set<T>` or `memcpy` for element-sized writes. Casting the qword
storage to a word or dword pointer violates C++ aliasing rules and has caused
operand initialization to disappear in optimized builds.

# What a run compares

After a run that completes, the harness compares the general-purpose
registers, RIP, RFLAGS (less a test's undefined arithmetic flags), all 32 ZMM
registers, the opmask registers, DR6 and DR7, MXCSR, the x87 state, the whole
data page, and the whole stack page. After a run that faults, it compares the
exception (vector, error code, RIP, CR2, DR6, DR7, the pushed RFLAGS) and the
same two pages: the guest's exception handlers run on a stack of their own
(IST1), so delivery does not write the test's memory, nor depend on its RSP.
A test cannot narrow these comparisons except by declaring what its
instructions leave undefined: `flags_mask` for RFLAGS, and `data_undefined`
for bits it stores to the data page, such as an x87 status word with
undefined condition codes in an FSAVE image.

Two parts of the state are left out because the Sail model does not define
them. Floating-point arithmetic is supplied by externs, so the MXCSR exception
flags (bits 5:0) are not compared. For the x87 state, the harness compares the
control word, TOP, the tags, and the contents of the valid registers; the rest
of the status word holds the externs' exception flags and condition codes that
many instructions leave undefined.

# Variants

A test case fixes one value in each of several dimensions that the hardware
and the model must agree on throughout. `kvm-variants.cpp` decodes every
case's code and derives variants along those dimensions, so that coverage
does not rely on each test's author choosing the values that matter. Each
kind of variant is a category of its own (`Variant ...`):

- Memory operands. A `[reg]` or `[reg+disp]` operand is re-encoded with a
  disp8, a disp32, a SIB byte (R13 base, R12 index), RIP-relative addressing,
  and the 67h address-size prefix. Each encoding reaches the same address; for
  the forms with a displacement, the base register is adjusted before the
  instruction and restored after it. EVEX operands also get disp8 = +1 and -1
  over a data page that differs at every offset. These move the access by
  the instruction's disp8*N scale, which only the hardware decides.
- The imm8 control byte of the last SSE/AVX instruction, with every value of
  its low five bits, every value of its high nibble, and FFh.
- MXCSR.RC set to round down, round up, and round toward zero.
- Register numbers. Every register field is renumbered by flipping bit 3 (or,
  for EVEX-only code, bit 4), and the initial state is permuted to match.
  This exercises the REX, VEX and EVEX extension bits. A further kind sets
  those bits on opmask register fields, which have three-bit numbers: the
  hardware ignores them or raises #UD.
- Operand values. The vector registers, the opmask registers, and the data
  page are filled with pseudo-random bits.

The kinds above keep each instruction what it was. The kinds below change
one instruction of a case into another encoding, so that what is tested is
how the model decodes it: its other operand forms, the fields it does not
use, and the prefixes it does not take. The result may be another
instruction or #UD, and the hardware decides which.

- Register operands as memory operands. An r/m register operand becomes
  `[r]` for a register the code does not use, pointing into the data page
  where the register's initial value is stored. EVEX forms are also tried
  with EVEX.b (broadcast) and with disp8 = +1 and -1, which move the access
  by the disp8*N of the instruction's tuple type.
- Memory operands as register operands (mod = 11b), which an instruction
  without a register form, such as a gather or a non-temporal store, rejects.
- VEX and EVEX fields, one at a time: W, vvvv and V', L or L'L, pp, EVEX.b,
  z and aaa, and the bits EVEX fixes.
- Prefixes: 66h, F2h, F3h, LOCK, CS and FS overrides, and for legacy
  instructions REX, a flipped REX.W, and 66h with REX.W. An immediate whose
  size the prefix decides is extended or cut to match. F3h is not added
  where it makes UMONITOR (of MFENCE, TPAUSE or UMWAIT): its address would
  be unmapped, which is no case (see `kvm-tests-waitpkg.cpp`).

Variants run with the model translating through the guest's page tables, an
identity map of the low 2MB, so that an access outside it faults on both
sides rather than reaching the harness's own memory. The map leaves out the
first 64KB, which the harness process cannot map (`vm.mmap_min_addr`): an
access through a zeroed base register is a #PF on both sides. The guest's
page tables lie there, reached physically, and its descriptor tables and
exception handlers are above it, at the same addresses and with the same
contents as the model's.

Floating-point arithmetic is left to the model's externs, so the kinds that
change operand values, the rounding mode or the immediate leave it out, and
the EVEX disp8*N kind gives it data whose elements are positive normal
numbers. Approximate results keep their tolerance only for the template's
inputs, so the kinds that change inputs leave them out as well.

A variant may fault where its case does not, and the reverse. The model must do
whatever the hardware does. Cases with the same instruction forms (encoding,
opcode, prefixes, vector length, masking, operand kinds) get one set of
variants, from the first of them. Variants are constructed only for the
categories that a run selects. Some cases get no variants: compatibility-mode
cases, and cases whose code the decoder does not handle. A case with a
transfer of control or a RIP-relative operand gets only the variants that leave
instruction lengths unchanged.

# Running the suite

`kvm_harness PREFIX` runs the categories whose names start with the prefix.
ctest instead runs each category exactly once, through entries the harness
writes after every build (`KVM_CTEST=<file> kvm_harness`): one entry per
category, `--category=NAME`, split into `--slice=K/N` entries of at most 1500
cases so that each finishes in a few seconds, and passing `--template=FILE` so
that the run constructs only that template's cases. `KVM_LIST=<file>` lists
the selected cases without running them.

The model has the AVX-512 features of the host, each extension its own CPUID
bit, and a case runs only where the host has the features its instructions
need: AVX512F, the extension of each EVEX or opmask instruction, and AVX512VL
for a 128- or 256-bit form, which the harness reads from the encodings
(`avx512_case_features` in `kvm-variants.cpp`), so templates need no gates of
their own for them. `KVM_LIST` reports how many cases need each feature. To
check those gates against the model on a host that has the feature,
`--host-lacks=NAME` runs as a host without it would, the model lacking it and
the cases that need it not run, and every case must pass but the variants
whose encoding needs it (#UD on both sides of a host that lacks it);
`--model-lacks=NAME` clears it in the model only, and a case that needs it
must then fail with the model's #UD where the host executes it.
