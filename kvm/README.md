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
data page, unless the test's stack is in the data page, where the guest's
exception handler pushes a frame the model does not. A test cannot narrow
these comparisons except by declaring what its instructions leave undefined:
`flags_mask` for RFLAGS, and `data_undefined` for bits it stores to the data
page, such as an x87 status word with undefined condition codes in an FSAVE
image.

Two parts of the state are left out because the Sail model does not define
them. Floating-point arithmetic is supplied by externs, so the MXCSR exception
flags (bits 5:0) are not compared. For the x87 state, the harness compares the
control word, TOP, the tags, and the contents of the valid registers; the rest
of the status word holds the externs' exception flags and condition codes that
many instructions leave undefined.

# Running the suite

`kvm_harness PREFIX` runs the categories whose names start with the prefix.
ctest instead runs each category exactly once, through entries the harness
writes after every build (`KVM_CTEST=<file> kvm_harness`): one entry per
category, `--category=NAME`, split into `--slice=K/N` entries of at most 1500
cases so that each finishes in a few seconds, and passing `--template=FILE` so
that the run constructs only that template's cases. `KVM_LIST=<file>` lists
the selected cases without running them.
