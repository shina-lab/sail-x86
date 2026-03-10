# Formal Equivalence Verification: sail-x86 vs sail-x86-from-acl2

This directory contains formal proofs that the x86-64 instruction semantics
in sail-x86 (this repo) are equivalent to those in
[sail-x86-from-acl2](https://github.com/rems-project/sail-x86-from-acl2),
an independent Sail model auto-translated from the ACL2 x86isa project.

## Approach

We use Sail's built-in `--smt` backend to generate SMT-LIB2 formulas and
Z3 to prove equivalence. For each instruction operation:

1. Extract the flag/result computation from both models
2. Write a combined Sail file with both implementations
3. Add `$property`-annotated functions asserting equivalence
4. Run `sail --smt --smt-auto --smt-auto-solver z3` to verify

Z3 returns **UNSAT** if the models are equivalent for ALL possible inputs
(formal proof), or **SAT** with a counterexample if they differ.

## Results

| Property | Operands | Status |
|----------|----------|--------|
| ADD 64-bit | result, flags (CF,PF,AF,ZF,SF,OF) | UNSAT (equivalent) |
| SUB 64-bit | result, flags | UNSAT (equivalent) |
| AND 64-bit | result, flags (CF,OF cleared; AF=0) | UNSAT (equivalent) |
| OR 64-bit | result, flags | UNSAT (equivalent) |
| XOR 64-bit | result, flags | UNSAT (equivalent) |
| ADD 32-bit | result, flags | UNSAT (equivalent) |
| SUB 32-bit | result, flags | UNSAT (equivalent) |
| ADC 64-bit | result, flags (with carry input) | UNSAT (equivalent) |
| SBB 64-bit | result, flags (with borrow input) | UNSAT (equivalent) |

## Usage

```bash
# Run all equivalence proofs
./run_equiv.sh

# Run a specific check
sail --smt --smt-auto --smt-auto-solver z3 equiv_alu.sail
```

## Prerequisites

- Sail 0.20.1+ (`sail` on PATH)
- Z3 SMT solver (`z3` on PATH)

## Adding New Checks

Create a new `equiv_*.sail` file with `$property`-annotated functions.
The `run_equiv.sh` script automatically picks up all `equiv_*.sail` files.

Example pattern:
```sail
$property
val prop_my_check : (bits(64), bits(64)) -> bool
function prop_my_check(a, b) = {
  // ... compute using model A's logic ...
  // ... compute using model B's logic ...
  // return true if equivalent
  model_a_result == model_b_result
}
```

## File Structure

- `equiv_alu.sail` — ALU operation equivalence (ADD, SUB, AND, OR, XOR, ADC, SBB)
- `run_equiv.sh` — Runner script for all equivalence checks
- `setup.sh` — Build Isla infrastructure (for future decoder comparison)
- `generate_ir.sh` — Generate Isla IR files (for future decoder comparison)
