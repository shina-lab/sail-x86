#!/usr/bin/env python3
"""
Compare instruction semantics between sail-x86 and sail-x86-from-acl2
by symbolically executing matching functions via isla-execute-function
and comparing the SMT output.

For each pair of corresponding functions, we:
1. Run isla-execute-function on our model's wrapper function
2. Run isla-execute-function on the acl2 model's spec function
3. Parse the symbolic Result from both
4. Construct a Z3 script that asserts the results differ
5. If Z3 says UNSAT: proven equivalent for all inputs
   If Z3 says SAT: found a counterexample (one model has a bug)
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from dataclasses import dataclass, field

SCRIPT_DIR = Path(__file__).parent.resolve()

ISLA_DIR = os.environ.get("ISLA_DIR", str(Path.home() / "isla"))
ISLA_EXEC = os.path.join(ISLA_DIR, "target/release/isla-execute-function")

# Function pairs to compare: (our_function, acl2_function, description)
FUNCTION_PAIRS = [
    ("compare_add64", "gpr_add_spec_8", "ADD 64-bit"),
    ("compare_sub64", "gpr_sub_spec_8", "SUB 64-bit"),
    ("compare_and64", "gpr_and_spec_8", "AND 64-bit"),
    ("compare_or64",  "gpr_or_spec_8",  "OR 64-bit"),
    ("compare_xor64", "gpr_xor_spec_8", "XOR 64-bit"),
    ("compare_add32", "gpr_add_spec_4", "ADD 32-bit"),
    ("compare_sub32", "gpr_sub_spec_4", "SUB 32-bit"),
]


@dataclass
class SymbolicResult:
    """Parsed symbolic execution result."""
    raw: str = ""
    declarations: list = field(default_factory=list)  # (name, sort) pairs
    definitions: list = field(default_factory=list)    # (name, expr) pairs
    assertions: list = field(default_factory=list)     # constraint exprs
    result_expr: str = ""
    branches: int = 0
    success: bool = False
    error: str = ""
    num_traces: int = 0


def run_isla_exec(ir_path: str, config_path: str, function: str,
                  timeout: int = 120) -> SymbolicResult:
    """Run isla-execute-function and parse the output."""
    cmd = [
        ISLA_EXEC,
        "-A", ir_path,
        "-C", config_path,
        "--traces", "-s",
        "--timeout", str(timeout),
        function,
    ]

    result = SymbolicResult()
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout + 30)
        result.raw = proc.stdout + proc.stderr
        if proc.returncode != 0:
            result.error = f"Exit code {proc.returncode}: {proc.stderr[:500]}"
            return result
    except subprocess.TimeoutExpired:
        result.error = "Timeout"
        return result
    except Exception as e:
        result.error = str(e)
        return result

    # Parse the output
    lines = result.raw.split("\n")

    # Find Result line
    for line in lines:
        if line.startswith("Result:"):
            result.result_expr = line[len("Result:"):].strip()
            break

    # Count traces
    result.num_traces = result.raw.count("(trace")

    # Parse trace events
    for line in lines:
        line = line.strip()
        if line.startswith("(declare-const"):
            m = re.match(r'\(declare-const (\S+) (.+)\)', line)
            if m:
                result.declarations.append((m.group(1), m.group(2)))
        elif line.startswith("(define-const"):
            m = re.match(r'\(define-const (\S+) (.+)\)', line)
            if m:
                result.definitions.append((m.group(1), m.group(2)))
        elif line.startswith("(assert"):
            m = re.match(r'\(assert (.+)\)', line)
            if m:
                result.assertions.append(m.group(1))
        elif line.startswith("(branch"):
            result.branches += 1

    result.success = result.result_expr != ""
    return result


def extract_result_fields(result_expr: str, model_type: str) -> dict:
    """
    Extract individual result fields from the Result expression.

    Our model returns: tuple of (result_bits, CF, PF, AF, ZF, SF, OF)
    ACL2 model returns: tuple of (result_bits, rflags_struct, undef_flags_struct)
    """
    # For now, return the raw expression for manual comparison
    # Full SMT comparison would parse these into structured fields
    return {"raw": result_expr, "type": model_type}


def compare_pair(our_ir: str, acl2_ir: str, our_config: str, acl2_config: str,
                 our_func: str, acl2_func: str, desc: str,
                 timeout: int = 120, verbose: bool = False) -> dict:
    """Compare one function pair."""
    result = {
        "description": desc,
        "our_function": our_func,
        "acl2_function": acl2_func,
        "equivalent": None,
        "details": {},
    }

    print(f"  [{desc}] Executing {our_func} on sail-x86...", end="", flush=True)
    ours = run_isla_exec(our_ir, our_config, our_func, timeout)
    if not ours.success:
        print(f" FAILED: {ours.error[:100]}")
        result["details"]["our_error"] = ours.error
        return result
    print(f" OK ({ours.num_traces} traces, {ours.branches} branches)")

    print(f"  [{desc}] Executing {acl2_func} on acl2...", end="", flush=True)
    acl2 = run_isla_exec(acl2_ir, acl2_config, acl2_func, timeout)
    if not acl2.success:
        print(f" FAILED: {acl2.error[:100]}")
        result["details"]["acl2_error"] = acl2.error
        return result
    print(f" OK ({acl2.num_traces} traces, {acl2.branches} branches)")

    # Store the symbolic results for analysis
    result["details"] = {
        "our_result": ours.result_expr,
        "acl2_result": acl2.result_expr,
        "our_declarations": len(ours.declarations),
        "acl2_declarations": len(acl2.declarations),
        "our_traces": ours.num_traces,
        "acl2_traces": acl2.num_traces,
    }

    # Write SMT traces to files for manual inspection
    trace_dir = SCRIPT_DIR / "traces"
    trace_dir.mkdir(exist_ok=True)

    our_trace_file = trace_dir / f"{our_func}.smt2"
    acl2_trace_file = trace_dir / f"{acl2_func}.smt2"

    with open(our_trace_file, "w") as f:
        f.write(f"; Symbolic trace for {our_func} (sail-x86)\n")
        f.write(ours.raw)

    with open(acl2_trace_file, "w") as f:
        f.write(f"; Symbolic trace for {acl2_func} (sail-x86-from-acl2)\n")
        f.write(acl2.raw)

    # Attempt automated equivalence check via Z3
    equiv = check_equivalence_z3(ours, acl2, our_func, acl2_func, verbose)
    result["equivalent"] = equiv

    return result


def check_equivalence_z3(ours: SymbolicResult, acl2: SymbolicResult,
                          our_func: str, acl2_func: str,
                          verbose: bool = False) -> bool | None:
    """
    Construct a Z3 script to check if both models produce equivalent results.

    Returns True if equivalent, False if different, None if inconclusive.
    """
    # Both traces start with (declare-const v0 ...) (declare-const v2 ...)
    # for the two input operands. We need to:
    # 1. Rename variables to avoid conflicts (prefix with A_ and B_)
    # 2. Assert inputs are the same
    # 3. Assert outputs are different
    # 4. Check satisfiability

    # For now, we do a structural comparison of the trace
    # Full Z3-based comparison is Phase 2 work

    print(f"  [{our_func} vs {acl2_func}] Comparing traces...", end="", flush=True)

    # Quick structural check: do they have the same number of traces?
    if ours.num_traces != acl2.num_traces:
        print(f" INCONCLUSIVE (different trace counts: {ours.num_traces} vs {acl2.num_traces})")
        return None

    # Check if result expressions have similar structure
    # (This is a heuristic, not a formal proof)
    print(f" trace comparison complete")
    print(f"    Our result:  {ours.result_expr[:100]}...")
    print(f"    ACL2 result: {acl2.result_expr[:100]}...")

    return None  # Inconclusive until we implement full Z3 checking


def main():
    parser = argparse.ArgumentParser(
        description="Compare x86-64 instruction semantics via symbolic execution"
    )
    parser.add_argument("--ours-ir", default=str(SCRIPT_DIR / "ir/sail_x86.ir"),
                        help="Path to sail-x86 IR file")
    parser.add_argument("--acl2-ir", default=str(SCRIPT_DIR / "ir/acl2_x86.ir"),
                        help="Path to acl2 IR file")
    parser.add_argument("--ours-config", default=str(SCRIPT_DIR / "x86_config_ours.toml"),
                        help="Path to sail-x86 Isla config")
    parser.add_argument("--acl2-config", default=str(SCRIPT_DIR / "x86_config_acl2.toml"),
                        help="Path to acl2 Isla config")
    parser.add_argument("--timeout", type=int, default=120,
                        help="Timeout per function (seconds)")
    parser.add_argument("-v", "--verbose", action="store_true")
    parser.add_argument("-o", "--output", default=str(SCRIPT_DIR / "results.json"),
                        help="Output JSON file")

    args = parser.parse_args()

    print("=== x86 Instruction Semantics Equivalence Check ===")
    print(f"sail-x86 IR:   {args.ours_ir}")
    print(f"acl2 IR:       {args.acl2_ir}")
    print()

    results = []
    for our_func, acl2_func, desc in FUNCTION_PAIRS:
        print(f"\n--- {desc} ---")
        r = compare_pair(
            args.ours_ir, args.acl2_ir,
            args.ours_config, args.acl2_config,
            our_func, acl2_func, desc,
            args.timeout, args.verbose,
        )
        results.append(r)

    # Summary
    equiv = sum(1 for r in results if r["equivalent"] is True)
    diff = sum(1 for r in results if r["equivalent"] is False)
    inconclusive = sum(1 for r in results if r["equivalent"] is None)

    print(f"\n=== Summary ===")
    print(f"Equivalent:    {equiv}/{len(results)}")
    print(f"Different:     {diff}/{len(results)}")
    print(f"Inconclusive:  {inconclusive}/{len(results)}")

    with open(args.output, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\nResults written to {args.output}")


if __name__ == "__main__":
    main()
