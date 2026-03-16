#!/usr/bin/env python3
"""Prove equivalence of BoringSSL assembly optimizations using Isla traces + Z3.

Parses Isla symbolic traces from original and optimized instruction sequences,
builds an SMT-LIB2 query asserting the outputs differ, and runs Z3.
UNSAT = equivalent for all inputs.

Usage:
    python3 prove_boringssl_equiv.py orig_trace opt_trace output.smt2 name
"""

import sys
import re
import subprocess
import os


def parse_trace(filename):
    """Parse an Isla trace file.

    Returns (smt_lines, result_var, reg_mappings) where:
    - smt_lines: list of declare-const and define-const lines
    - result_var: the variable name written to "Final result"
    - reg_mappings: dict of register name -> list of variable names
    """
    smt_lines = []
    result_var = None
    reg_mappings = {}
    seen_decls = set()

    with open(filename) as f:
        for line in f:
            stripped = line.strip()
            # Strip source location comments
            stripped = re.sub(r'\s*;[^)]*$', '', stripped)

            # Parse register mappings (GPR, ZMM, etc.)
            for reg_name in ('GPR', 'ZMM'):
                m = re.search(r'read-reg \|' + reg_name + r'\| nil \(_ vec ([\w ]+)\)', stripped)
                if m and reg_name not in reg_mappings:
                    reg_mappings[reg_name] = m.group(1).split()

            # Collect declare-const (BitVec only)
            if stripped.startswith('(declare-const '):
                if '(_ BitVec' not in stripped:
                    continue
                m = re.match(r'\(declare-const (\w+) ', stripped)
                if m and m.group(1) not in seen_decls:
                    seen_decls.add(m.group(1))
                    smt_lines.append(stripped)

            # Collect define-const (skip enum types)
            elif stripped.startswith('(define-const '):
                skip_patterns = ['|SysRunning|', '|SysHalted|', '|SysSyscall|',
                                 '|MP_NONE|', '|MP_66|']
                if any(p in stripped for p in skip_patterns):
                    continue
                m = re.match(r'\(define-const (\w+) ', stripped)
                if m and m.group(1) not in seen_decls:
                    seen_decls.add(m.group(1))
                    smt_lines.append(stripped)

            # Parse final result
            m = re.search(r'write-reg \|Final result\| nil (\w+)', stripped)
            if m:
                result_var = m.group(1)

    return smt_lines, result_var, reg_mappings


def build_input_rename(mappings_a, mappings_b):
    """Build rename map from trace B's input variables to trace A's."""
    rename = {}
    for reg_name in mappings_a:
        vars_a = mappings_a[reg_name]
        vars_b = mappings_b.get(reg_name)
        if vars_b and len(vars_a) == len(vars_b):
            for i in range(len(vars_a)):
                rename[vars_b[i]] = vars_a[i]
    return rename


def get_defined_vars(smt_lines):
    defined = set()
    for line in smt_lines:
        m = re.match(r'\(define-const (\w+) ', line)
        if m:
            defined.add(m.group(1))
    return defined


def get_declared_vars(smt_lines):
    declared = set()
    for line in smt_lines:
        m = re.match(r'\(declare-const (\w+) ', line)
        if m:
            declared.add(m.group(1))
    return declared


def rename_vars(smt_lines, result_var, prefix, input_rename):
    """Rename variables in trace B to avoid conflicts with trace A."""
    defined = get_defined_vars(smt_lines)
    declared = get_declared_vars(smt_lines)
    shared_inputs = set(input_rename.keys()) if input_rename else set()

    rename_map = {}
    for var in defined:
        rename_map[var] = prefix + var
    for var in declared:
        if var not in shared_inputs:
            rename_map[var] = prefix + var
    if input_rename:
        for old_name, new_name in input_rename.items():
            rename_map[old_name] = new_name

    pattern = re.compile(r'\b(' + '|'.join(
        re.escape(v) for v in sorted(rename_map.keys(), key=len, reverse=True)
    ) + r')\b')

    new_lines = []
    for line in smt_lines:
        if line.startswith('(declare-const '):
            m_decl = re.match(r'\(declare-const (\w+) ', line)
            if m_decl and m_decl.group(1) in shared_inputs:
                continue  # Already declared by trace A
            new_line = pattern.sub(lambda m: rename_map[m.group(1)], line)
            new_lines.append(new_line)
            continue
        new_line = pattern.sub(lambda m: rename_map[m.group(1)], line)
        new_lines.append(new_line)

    new_result = rename_map.get(result_var, result_var)
    return new_lines, new_result


def tokenize_sexp(s):
    tokens = []
    i = 0
    while i < len(s):
        if s[i] == '(':
            tokens.append('('); i += 1
        elif s[i] == ')':
            tokens.append(')'); i += 1
        elif s[i].isspace():
            i += 1
        else:
            j = i
            while j < len(s) and s[j] not in '() \t\n':
                j += 1
            tokens.append(s[i:j]); i = j
    return tokens


def parse_sexp(tokens, pos=0):
    if tokens[pos] == '(':
        result = []
        pos += 1
        while tokens[pos] != ')':
            val, pos = parse_sexp(tokens, pos)
            result.append(val)
        return result, pos + 1
    else:
        return tokens[pos], pos + 1


def infer_width(sexp, known):
    if isinstance(sexp, str):
        if sexp.startswith('#x'): return (len(sexp) - 2) * 4
        if sexp.startswith('#b'): return len(sexp) - 2
        if sexp in ('true', 'false'): return 0
        if sexp in known: return known[sexp]
        return None
    if not isinstance(sexp, list) or len(sexp) == 0:
        return None
    head = sexp[0]
    # (_ extract hi lo)
    if isinstance(head, list) and len(head) >= 3 and head[0] == '_' and head[1] == 'extract':
        return int(head[2]) - int(head[3]) + 1
    # (_ zero_extend n) / (_ sign_extend n)
    if isinstance(head, list) and len(head) == 3 and head[0] == '_' and head[1] in ('zero_extend', 'sign_extend'):
        inner_w = infer_width(sexp[1], known) if len(sexp) > 1 else None
        return int(head[2]) + inner_w if inner_w is not None else None
    # Boolean ops
    if head in ('=', 'not', 'and', 'or', '=>', 'distinct',
                'bvslt', 'bvsle', 'bvsgt', 'bvsge',
                'bvult', 'bvule', 'bvugt', 'bvuge'):
        return 0
    # ite
    if head == 'ite' and len(sexp) == 4:
        w = infer_width(sexp[2], known)
        return w if w is not None else infer_width(sexp[3], known)
    # Width-preserving ops
    if head in ('bvor', 'bvand', 'bvxor', 'bvsub', 'bvadd', 'bvmul',
                'bvshl', 'bvlshr', 'bvashr', 'bvnot'):
        for arg in sexp[1:]:
            w = infer_width(arg, known)
            if w: return w
    # concat
    if head == 'concat' and len(sexp) >= 3:
        w1 = infer_width(sexp[1], known)
        w2 = infer_width(sexp[2], known)
        if w1 is not None and w2 is not None: return w1 + w2
    return None


def infer_bv_width(expr_str, known):
    try:
        tokens = tokenize_sexp(expr_str)
        sexp, _ = parse_sexp(tokens)
        return infer_width(sexp, known)
    except (IndexError, ValueError):
        return None


def convert_to_define_fun(smt_lines):
    """Convert define-const to define-fun with inferred types."""
    known_widths = {}
    result = []

    for line in smt_lines:
        m = re.match(r'\(declare-const (\w+) \(_ BitVec (\d+)\)\)', line)
        if m:
            known_widths[m.group(1)] = int(m.group(2))
            result.append(line)
            continue

        m = re.match(r'\(define-const (\w+) (.+)\)$', line)
        if m:
            var_name = m.group(1)
            expr = m.group(2)
            width = infer_bv_width(expr, known_widths)
            if width is None:
                width = 64  # Default to GPR width
            known_widths[var_name] = width
            if width == 0:
                result.append(f"(define-fun {var_name} () Bool {expr})")
            else:
                result.append(f"(define-fun {var_name} () (_ BitVec {width}) {expr})")
            continue

        result.append(line)

    return result


def build_equiv_query(trace_a_file, trace_b_file, name):
    """Build a complete SMT2 equivalence query."""
    lines_a, result_a, mappings_a = parse_trace(trace_a_file)
    lines_b, result_b, mappings_b = parse_trace(trace_b_file)

    if not result_a:
        print(f"ERROR: No 'Final result' in {trace_a_file}", file=sys.stderr)
        return None
    if not result_b:
        print(f"ERROR: No 'Final result' in {trace_b_file}", file=sys.stderr)
        return None

    # Build input rename map
    input_rename = build_input_rename(mappings_a, mappings_b)
    if input_rename:
        print(f"  Input rename: {len(input_rename)} GPR variables remapped",
              file=sys.stderr)

    # Rename trace B variables
    lines_b_renamed, result_b_renamed = rename_vars(
        lines_b, result_b, "b_", input_rename)

    # Assemble query
    query = []
    query.append(f"; Equivalence proof: {name}")
    query.append("; UNSAT = equivalent for all inputs")
    query.append("(set-logic QF_BV)")
    query.append("")

    # Shared input declarations (from trace A)
    query.append("; Shared symbolic inputs (GPR registers)")
    for line in lines_a:
        if line.startswith('(declare-const '):
            query.append(line)
    query.append("")

    # Trace A definitions
    query.append("; === Original sequence ===")
    for line in lines_a:
        if line.startswith('(define-const '):
            query.append(line)
    query.append("")

    # Trace B definitions (renamed)
    query.append("; === Optimized sequence ===")
    for line in lines_b_renamed:
        query.append(line)
    query.append("")

    # Equivalence assertion
    query.append(f"(assert (not (= {result_a} {result_b_renamed})))")
    query.append("(check-sat)")

    # Convert define-const to define-fun
    query = convert_to_define_fun(query)

    return "\n".join(query)


def main():
    if len(sys.argv) != 5:
        print("Usage: prove_boringssl_equiv.py orig_trace opt_trace output.smt2 name",
              file=sys.stderr)
        sys.exit(1)

    trace_a, trace_b, smt_file, name = sys.argv[1:5]

    query = build_equiv_query(trace_a, trace_b, name)
    if not query:
        print("ERROR: Failed to build query")
        sys.exit(1)

    with open(smt_file, 'w') as f:
        f.write(query)

    # Run Z3
    try:
        result = subprocess.run(
            ['z3', smt_file],
            capture_output=True, text=True, timeout=300
        )
        output = result.stdout.strip()
        if '(error' in output:
            print(f"Z3 ERROR: {output[:500]}")
            sys.exit(1)
        elif output == 'unsat':
            print(f"UNSAT — {name} proved equivalent for all inputs")
        elif output == 'sat':
            print(f"SAT — {name} NOT equivalent (counterexample exists)")
        else:
            print(f"Z3: {output}")
    except subprocess.TimeoutExpired:
        print("Z3 TIMEOUT")
        sys.exit(1)


if __name__ == "__main__":
    main()
