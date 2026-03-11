#!/usr/bin/env python3
"""Prove equivalence of FFmpeg SIMD optimization candidates.

Parses Isla symbolic traces and uses Z3 to prove the original and
optimized instruction sequences compute identical outputs for all
possible 128-bit XMM inputs.

UNSAT = equivalent for all inputs.
"""

import sys
import re
import subprocess
import tempfile


def extract_trace_smt(filename):
    """Extract SMT content from an Isla trace file.

    Returns (smt_lines, result_var) where smt_lines is a list of
    declare-const and define-const lines, and result_var is the
    name of the final output variable.
    """
    smt_lines = []
    result_var = None

    with open(filename) as f:
        for line in f:
            stripped = line.strip()
            # Strip source location comments
            stripped = re.sub(r'\s*;[^)]*$', '', stripped)

            if stripped.startswith('(declare-const '):
                smt_lines.append(stripped)
            elif stripped.startswith('(define-const '):
                smt_lines.append(stripped)
            else:
                m = re.search(r'write-reg \|Final result\| nil (\w+)', stripped)
                if m:
                    result_var = m.group(1)

    return smt_lines, result_var


def get_defined_vars(smt_lines):
    """Get set of variable names defined by define-const."""
    defined = set()
    for line in smt_lines:
        m = re.match(r'\(define-const (\w+) ', line)
        if m:
            defined.add(m.group(1))
    return defined


def rename_vars(smt_lines, result_var, prefix):
    """Rename all defined (non-input) variables with a prefix.

    Input variables (declare-const) are kept as-is since both traces
    share the same inputs. Only define-const variables get renamed.
    """
    defined = get_defined_vars(smt_lines)

    new_lines = []
    for line in smt_lines:
        if line.startswith('(declare-const '):
            # Skip — shared inputs already declared
            continue

        # Rename all defined variables in this line
        new_line = line
        for var in sorted(defined, key=len, reverse=True):
            # Use word boundary replacement
            new_line = re.sub(r'\b' + var + r'\b', prefix + var, new_line)
        new_lines.append(new_line)

    new_result = prefix + result_var if result_var in defined else result_var
    return new_lines, new_result


def tokenize_sexp(s):
    """Tokenize an S-expression string into a nested list."""
    tokens = []
    i = 0
    while i < len(s):
        if s[i] == '(':
            tokens.append('(')
            i += 1
        elif s[i] == ')':
            tokens.append(')')
            i += 1
        elif s[i].isspace():
            i += 1
        else:
            j = i
            while j < len(s) and s[j] not in '() \t\n':
                j += 1
            tokens.append(s[i:j])
            i = j
    return tokens


def parse_sexp(tokens, pos=0):
    """Parse tokens into a nested list structure."""
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
    """Infer bitvector width from a parsed S-expression."""
    if isinstance(sexp, str):
        if sexp.startswith('#x'):
            return (len(sexp) - 2) * 4
        if sexp.startswith('#b'):
            return len(sexp) - 2
        if sexp in known:
            return known[sexp]
        return None

    if not isinstance(sexp, list) or len(sexp) == 0:
        return None

    head = sexp[0]

    # (_ extract hi lo)
    if isinstance(head, list) and len(head) == 3 and head[0] == '_' and head[1] == 'extract':
        return int(head[2]) - int(head[3]) + 1 if len(head) == 4 else None
    if isinstance(head, list) and len(head) == 4 and head[0] == '_' and head[1] == 'extract':
        return int(head[2]) - int(head[3]) + 1

    # (_ zero_extend n)
    if isinstance(head, list) and len(head) == 3 and head[0] == '_' and head[1] == 'zero_extend':
        inner_w = infer_width(sexp[1], known) if len(sexp) > 1 else None
        return int(head[2]) + inner_w if inner_w else None

    # (_ sign_extend n)
    if isinstance(head, list) and len(head) == 3 and head[0] == '_' and head[1] == 'sign_extend':
        inner_w = infer_width(sexp[1], known) if len(sexp) > 1 else None
        return int(head[2]) + inner_w if inner_w else None

    # Width-preserving ops
    if head in ('bvor', 'bvand', 'bvxor', 'bvsub', 'bvadd', 'bvmul',
                'bvshl', 'bvlshr', 'bvashr', 'bvnot'):
        for arg in sexp[1:]:
            w = infer_width(arg, known)
            if w:
                return w

    # concat — sum of widths
    if head == 'concat' and len(sexp) >= 3:
        w1 = infer_width(sexp[1], known)
        w2 = infer_width(sexp[2], known)
        if w1 and w2:
            return w1 + w2
        # For nested concat, try to get width from known vars
        for arg in sexp[1:]:
            w = infer_width(arg, known)
            if w:
                # Can't determine total width from one child of concat
                pass

    # (_ BitVec n) — type reference
    if isinstance(head, str) and head == '_' and len(sexp) == 3 and sexp[1] == 'BitVec':
        return int(sexp[2])

    return None


def infer_bv_width(expr_str, known_widths):
    """Infer bitvector width from an SMT expression string."""
    try:
        tokens = tokenize_sexp(expr_str)
        sexp, _ = parse_sexp(tokens)
        return infer_width(sexp, known_widths)
    except (IndexError, ValueError):
        return None


def convert_define_const_to_fun(smt_lines):
    """Convert define-const to define-fun with inferred types."""
    known_widths = {}
    result = []

    for line in smt_lines:
        # declare-const: extract width
        m = re.match(r'\(declare-const (\w+) \(_ BitVec (\d+)\)\)', line)
        if m:
            known_widths[m.group(1)] = int(m.group(2))
            result.append(line)
            continue

        # define-const: convert to define-fun
        m = re.match(r'\(define-const (\w+) (.+)\)$', line)
        if m:
            var_name = m.group(1)
            expr = m.group(2)
            width = infer_bv_width(expr, known_widths)
            if width is None:
                width = 512  # Default to ZMM width
            known_widths[var_name] = width
            result.append(f"(define-fun {var_name} () (_ BitVec {width}) {expr})")
            continue

        result.append(line)

    return result


def build_equiv_query(trace_a_file, trace_b_file, name):
    """Build a complete SMT2 equivalence query."""
    lines_a, result_a = extract_trace_smt(trace_a_file)
    lines_b, result_b = extract_trace_smt(trace_b_file)

    if not result_a or not result_b:
        print(f"  ERROR: Missing result variable", file=sys.stderr)
        return None

    # Rename trace B's intermediate variables
    lines_b_renamed, result_b_renamed = rename_vars(lines_b, result_b, "b_")

    # Build query
    query_lines = []
    query_lines.append(f"; Equivalence proof: {name}")
    query_lines.append(f"; UNSAT = equivalent for all inputs")
    query_lines.append("(set-logic QF_BV)")
    query_lines.append("")

    # Shared input declarations (from trace A)
    query_lines.append("; Shared symbolic inputs (ZMM register entries)")
    for line in lines_a:
        if line.startswith('(declare-const '):
            query_lines.append(line)
    query_lines.append("")

    # Trace A definitions
    query_lines.append("; === Original sequence ===")
    for line in lines_a:
        if line.startswith('(define-const '):
            query_lines.append(line)
    query_lines.append("")

    # Trace B definitions (renamed)
    query_lines.append("; === Optimized sequence ===")
    for line in lines_b_renamed:
        query_lines.append(line)
    query_lines.append("")

    # Equivalence assertion
    query_lines.append(f"(assert (not (= {result_a} {result_b_renamed})))")
    query_lines.append("(check-sat)")

    # Convert define-const to define-fun with type annotations
    query_lines = convert_define_const_to_fun(query_lines)

    return "\n".join(query_lines)


def run_z3(query, out_file):
    """Run Z3 on an SMT2 query string. Returns 'unsat', 'sat', or error."""
    with open(out_file, 'w') as f:
        f.write(query)

    result = subprocess.run(
        ['z3', out_file],
        capture_output=True, text=True, timeout=300
    )
    output = result.stdout.strip()
    if '(error' in output:
        return f"ERROR: {output[:500]}"
    return output


def main():
    candidates = [
        # NOTE: MULTIPLY uses two different div-by-255 approximations that are
        # NOT bit-exact for all 16-bit word values. They agree only when each
        # word is a product a*b where a,b in [0,255]. Without input constraints,
        # Z3 correctly finds a counterexample (SAT). This is expected.
        ("multiply",
         "/tmp/trace_test_multiply_orig.txt",
         "/tmp/trace_test_multiply_opt.txt",
         "MULTIPLY: div-by-255 shift-based (6 instrs) vs pmulhuw*257 (3 instrs)"),
        ("phoenix",
         "/tmp/trace_test_phoenix_orig.txt",
         "/tmp/trace_test_phoenix_opt.txt",
         "PHOENIX: 255-|a-b| via min/max (6 instrs) vs psubusb+por+xor (5 instrs)"),
        ("difference",
         "/tmp/trace_test_difference_orig.txt",
         "/tmp/trace_test_difference_opt.txt",
         "DIFFERENCE: |a-b| via widen/abs/pack (18 instrs) vs psubusb+por (4 instrs)"),
    ]

    all_proved = True
    for short_name, trace_a, trace_b, desc in candidates:
        print(f"=== {desc} ===")
        query = build_equiv_query(trace_a, trace_b, desc)
        if not query:
            all_proved = False
            continue

        out_file = f"/tmp/equiv_{short_name}.smt2"
        result = run_z3(query, out_file)

        if result == "unsat":
            print(f"  PROVED EQUIVALENT (Z3: unsat)")
        elif result == "sat":
            print(f"  NOT EQUIVALENT (Z3: sat) — counterexample exists!")
            all_proved = False
        else:
            print(f"  {result}")
            all_proved = False
        print(f"  Query: {out_file}")
        print()

    if all_proved:
        print("All three optimizations proved equivalent!")
    return 0 if all_proved else 1


if __name__ == "__main__":
    sys.exit(main())
