#!/usr/bin/env python3
"""Build Z3 equivalence queries from Isla trace pairs.

Extracts SMT define-const statements from Isla traces and constructs
equivalence queries that Z3 can solve. UNSAT = the two instruction
sequences are equivalent for all possible inputs.
"""

import re
import sys
import os


def extract_smt_from_trace(trace_file):
    """Extract define-const statements and the final result variable from a trace."""
    defines = []
    result_var = None

    with open(trace_file) as f:
        for line in f:
            line = line.strip()
            # Extract define-const lines
            m = re.match(r'\(define-const\s+(\S+)\s+(.*)\)', line)
            if m:
                var_name = m.group(1)
                expr = m.group(2)
                # Strip trailing source location comments
                expr = re.sub(r'\s*;\s*\S+\s*$', '', expr)
                defines.append((var_name, expr))

            # Extract the final result variable
            m = re.match(r'\s*\(write-reg \|Final result\| nil (\S+)\)', line)
            if m:
                result_var = m.group(1).rstrip(')')

    return defines, result_var


def find_input_vars(defines):
    """Find symbolic input variables (those referenced but never defined)."""
    defined = set()
    referenced = set()

    for var_name, expr in defines:
        defined.add(var_name)
        # Find all v<N> references in the expression
        for ref in re.findall(r'\bv\d+\b', expr):
            referenced.add(ref)

    return referenced - defined


def build_equiv_query(trace_a, trace_b, name):
    """Build an SMT2 equivalence query from two traces."""
    defs_a, result_a = extract_smt_from_trace(trace_a)
    defs_b, result_b = extract_smt_from_trace(trace_b)

    if not result_a or not result_b:
        print(f"ERROR: Could not find Final result in traces", file=sys.stderr)
        return None

    # Find all input variables
    inputs_a = find_input_vars(defs_a)
    inputs_b = find_input_vars(defs_b)
    all_inputs = inputs_a | inputs_b

    # Build the query
    lines = []
    lines.append(f"; Equivalence proof: {name}")
    lines.append(f"; Trace A: {os.path.basename(trace_a)}")
    lines.append(f"; Trace B: {os.path.basename(trace_b)}")
    lines.append(f"; UNSAT = equivalent for all inputs")
    lines.append("")
    lines.append("(set-logic QF_BV)")
    lines.append("")

    # Determine bit-widths of input variables by examining how they're used
    # For now, assume all inputs are 512-bit (ZMM register width) since that's
    # what the Isla traces use for the ZMM register file.
    # We need to find the actual widths from the expressions.
    # The traces use (_ vec ...) for the ZMM array, and individual entries are 512-bit.

    # Collect all variables and their sizes from define-const
    var_sizes = {}
    for var_name, expr in defs_a + defs_b:
        # Try to determine size from extract operations
        m = re.match(r'\(\(_ extract (\d+) (\d+)\)', expr)
        if m:
            size = int(m.group(1)) - int(m.group(2)) + 1
            var_sizes[var_name] = size

    # Declare input variables
    # The main inputs are ZMM register entries (512-bit each)
    lines.append("; Symbolic inputs (ZMM register entries)")
    for v in sorted(all_inputs, key=lambda x: int(x[1:])):
        # Default to 512-bit for ZMM entries
        lines.append(f"(declare-const {v} (_ BitVec 512))")
    lines.append("")

    # Rename variables in trace B to avoid conflicts with trace A
    rename_map = {}
    for var_name, expr in defs_b:
        if var_name not in all_inputs:
            new_name = f"b_{var_name}"
            rename_map[var_name] = new_name

    def rename_b(name):
        return rename_map.get(name, name)

    def rename_expr_b(expr):
        # Rename all v<N> that are in the rename map
        def replacer(m):
            v = m.group(0)
            return rename_map.get(v, v)
        return re.sub(r'\bv\d+\b', replacer, expr)

    # Emit trace A definitions
    lines.append("; === Trace A (original) ===")
    for var_name, expr in defs_a:
        if var_name not in all_inputs:
            lines.append(f"(define-const {var_name} {expr})")
    lines.append("")

    # Emit trace B definitions (renamed)
    lines.append("; === Trace B (optimized) ===")
    for var_name, expr in defs_b:
        if var_name not in all_inputs:
            new_name = rename_b(var_name)
            new_expr = rename_expr_b(expr)
            lines.append(f"(define-const {new_name} {new_expr})")
    lines.append("")

    # Assert non-equivalence
    result_b_renamed = rename_b(result_b)
    lines.append(f"; Assert outputs differ (UNSAT = equivalent)")
    lines.append(f"(assert (not (= {result_a} {result_b_renamed})))")
    lines.append("(check-sat)")
    lines.append("")

    return "\n".join(lines)


def main():
    pairs = [
        ("/tmp/trace_test_difference_orig.txt",
         "/tmp/trace_test_difference_opt.txt",
         "DIFFERENCE: widen/abs/pack (18 instrs) vs psubusb+por (4 instrs)"),
        ("/tmp/trace_test_phoenix_orig.txt",
         "/tmp/trace_test_phoenix_opt.txt",
         "PHOENIX: min/max/sub/add (6 instrs) vs psubusb+por+xor (5 instrs)"),
        ("/tmp/trace_test_multiply_orig.txt",
         "/tmp/trace_test_multiply_opt.txt",
         "MULTIPLY: shift-based div255 (6 instrs) vs pmulhuw*257 (3 instrs)"),
    ]

    for trace_a, trace_b, name in pairs:
        print(f"=== {name} ===")
        query = build_equiv_query(trace_a, trace_b, name)
        if query:
            short_name = name.split(":")[0].lower().strip()
            out_file = f"/tmp/equiv_{short_name}.smt2"
            with open(out_file, "w") as f:
                f.write(query)
            print(f"  Written to {out_file}")
        print()


if __name__ == "__main__":
    main()
