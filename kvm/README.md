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
