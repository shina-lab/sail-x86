#!/usr/bin/env python3
"""Prove equivalence of SIMD optimization candidates.

Parses Isla symbolic traces and uses Z3 to prove the original and
optimized instruction sequences compute identical outputs for all
possible 128-bit XMM inputs.

UNSAT = equivalent for all inputs.

Programs covered: FFmpeg (vf_blend.asm), libjpeg-turbo (jquanti-sse2.asm)
"""

import sys
import re
import subprocess
import tempfile


def parse_reg_mapping(filename, reg_name, expected_count):
    """Parse the first read-reg line for a given register to get variable mapping.

    Returns a list of variable names, or None if not found.
    """
    with open(filename) as f:
        for line in f:
            m = re.search(r'read-reg \|' + reg_name + r'\| nil \(_ vec ([\w ]+)\)', line)
            if m:
                vars = m.group(1).split()
                if len(vars) == expected_count:
                    return vars
    return None


def extract_trace_smt(filename):
    """Extract SMT content from an Isla trace file.

    Returns (smt_lines, result_var, reg_mappings) where smt_lines is a list of
    declare-const and define-const lines, result_var is the name of the
    final output variable, and reg_mappings is a dict of register name to
    variable list.
    """
    smt_lines = []
    result_var = None
    seen_decls = set()

    # Parse register mappings
    reg_mappings = {}
    zmm_vars = parse_reg_mapping(filename, 'ZMM', 32)
    if zmm_vars:
        reg_mappings['ZMM'] = zmm_vars
    gpr_vars = parse_reg_mapping(filename, 'GPR', 16)
    if gpr_vars:
        reg_mappings['GPR'] = gpr_vars

    with open(filename) as f:
        for line in f:
            stripped = line.strip()
            # Strip source location comments
            stripped = re.sub(r'\s*;[^)]*$', '', stripped)

            if stripped.startswith('(declare-const '):
                # Only keep BitVec declarations (skip enum types like SystemState)
                if '(_ BitVec' not in stripped:
                    continue
                # Deduplicate
                m = re.match(r'\(declare-const (\w+) ', stripped)
                if m and m.group(1) in seen_decls:
                    continue
                if m:
                    seen_decls.add(m.group(1))
                smt_lines.append(stripped)
            elif stripped.startswith('(define-const '):
                # Skip definitions that reference enum values
                if '|SysRunning|' in stripped or '|SysHalted|' in stripped or '|SysSyscall|' in stripped:
                    continue
                if '|MP_NONE|' in stripped or '|MP_66|' in stripped:
                    continue
                # Deduplicate define-const
                m = re.match(r'\(define-const (\w+) ', stripped)
                if m and m.group(1) in seen_decls:
                    continue
                if m:
                    seen_decls.add(m.group(1))
                smt_lines.append(stripped)
            else:
                m = re.search(r'write-reg \|Final.result\| nil (\w+)', stripped)
                if m:
                    result_var = m.group(1)

    return smt_lines, result_var, reg_mappings


def get_defined_vars(smt_lines):
    """Get set of variable names defined by define-const."""
    defined = set()
    for line in smt_lines:
        m = re.match(r'\(define-const (\w+) ', line)
        if m:
            defined.add(m.group(1))
    return defined


def get_declared_vars(smt_lines):
    """Get set of variable names from declare-const."""
    declared = set()
    for line in smt_lines:
        m = re.match(r'\(declare-const (\w+) ', line)
        if m:
            declared.add(m.group(1))
    return declared


def rename_vars(smt_lines, result_var, prefix, input_rename=None):
    """Rename variables in trace B for the combined query.

    input_rename: dict mapping trace B input var names to trace A input var names.
    prefix: prefix for intermediate (define-const) variables.
    """
    defined = get_defined_vars(smt_lines)
    declared = get_declared_vars(smt_lines)

    # Build the full rename map: intermediates get prefix, inputs get remapped
    rename_map = {}
    for var in defined:
        rename_map[var] = prefix + var
    # Also rename declared vars unique to trace B (not shared inputs)
    shared_inputs = set(input_rename.keys()) if input_rename else set()
    for var in declared:
        if var not in shared_inputs:
            rename_map[var] = prefix + var
    if input_rename:
        for old_name, new_name in input_rename.items():
            rename_map[old_name] = new_name

    # Build a single regex that matches any variable name to rename.
    # Use a callback to look up the replacement — this avoids chain substitution.
    pattern = re.compile(r'\b(' + '|'.join(
        re.escape(v) for v in sorted(rename_map.keys(), key=len, reverse=True)
    ) + r')\b')

    # Determine which declared vars are shared inputs (mapped to trace A names)
    shared_inputs = set(input_rename.keys()) if input_rename else set()

    new_lines = []
    for line in smt_lines:
        if line.startswith('(declare-const '):
            m_decl = re.match(r'\(declare-const (\w+) ', line)
            if m_decl:
                var = m_decl.group(1)
                if var in shared_inputs:
                    # Shared input — already declared by trace A
                    continue
                # Unique to trace B — emit with prefix
                new_line = pattern.sub(lambda m: rename_map[m.group(1)], line)
                new_lines.append(new_line)
            continue

        # Apply all renames simultaneously
        new_line = pattern.sub(lambda m: rename_map[m.group(1)], line)
        new_lines.append(new_line)

    new_result = rename_map.get(result_var, result_var)
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
        if sexp in ('true', 'false'):
            return 0  # Bool
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

    # Boolean ops return Bool (width = 0 by convention)
    if head in ('=', 'not', 'and', 'or', '=>', 'distinct',
                'bvslt', 'bvsle', 'bvsgt', 'bvsge',
                'bvult', 'bvule', 'bvugt', 'bvuge'):
        return 0  # Bool

    # ite — sort matches the then/else branches
    if head == 'ite' and len(sexp) == 4:
        w = infer_width(sexp[2], known)
        if w is not None:
            return w
        return infer_width(sexp[3], known)

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
            if width == 0:
                result.append(f"(define-fun {var_name} () Bool {expr})")
            else:
                result.append(f"(define-fun {var_name} () (_ BitVec {width}) {expr})")
            continue

        result.append(line)

    return result


def build_input_rename(mappings_a, mappings_b):
    """Build a rename map from trace B's input vars to trace A's input vars.

    mappings_a/b are dicts of register name to variable list.
    Returns a dict mapping trace B var names to trace A var names.
    This includes identity mappings (b_var -> same_name) so rename_vars
    knows which variables are shared inputs even when names happen to match.
    """
    rename = {}
    for reg_name in mappings_a:
        vars_a = mappings_a[reg_name]
        vars_b = mappings_b.get(reg_name)
        if not vars_b or len(vars_a) != len(vars_b):
            continue
        for i in range(len(vars_a)):
            rename[vars_b[i]] = vars_a[i]
    return rename


def build_equiv_query(trace_a_file, trace_b_file, name):
    """Build a complete SMT2 equivalence query."""
    lines_a, result_a, mappings_a = extract_trace_smt(trace_a_file)
    lines_b, result_b, mappings_b = extract_trace_smt(trace_b_file)

    if not result_a or not result_b:
        print(f"  ERROR: Missing result variable", file=sys.stderr)
        return None

    # Build input variable rename map (trace B → trace A naming)
    input_rename = build_input_rename(mappings_a, mappings_b)
    if input_rename:
        print(f"  Input rename: {len(input_rename)} variables remapped")

    # Rename trace B's intermediate variables (b_ prefix) and input vars
    lines_b_renamed, result_b_renamed = rename_vars(
        lines_b, result_b, "b_", input_rename)

    # Build query
    query_lines = []
    query_lines.append(f"; Equivalence proof: {name}")
    query_lines.append(f"; UNSAT = equivalent for all inputs")
    query_lines.append("(set-logic QF_BV)")
    query_lines.append("")

    # Shared input declarations (from trace A)
    query_lines.append("; Shared symbolic inputs")
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
        # --- FFmpeg vf_blend.asm ---
        # NOTE: MULTIPLY (unconstrained) uses two different div-by-255
        # approximations that are NOT bit-exact for all 16-bit word values.
        # They agree only when each word is a product a*b where a,b in
        # [0,255]. Without input constraints, Z3 correctly finds a
        # counterexample (SAT). This is expected.
        ("multiply",
         "/tmp/trace_test_multiply_orig.txt",
         "/tmp/trace_test_multiply_opt.txt",
         "MULTIPLY unconstrained: div-by-255 (5 instrs) vs pmulhuw*257 (3 instrs)",
         "FFmpeg vf_blend.asm:117-123",
         False),  # expected_unsat=False (SAT is correct)
        ("phoenix",
         "/tmp/trace_test_phoenix_orig.txt",
         "/tmp/trace_test_phoenix_opt.txt",
         "PHOENIX: 255-|a-b| via min/max (6 instrs) vs psubusb+por+xor (5 instrs)",
         "FFmpeg vf_blend.asm:291-311",
         True),
        ("difference",
         "/tmp/trace_test_difference_orig.txt",
         "/tmp/trace_test_difference_opt.txt",
         "DIFFERENCE: |a-b| via widen/abs/pack (18 instrs) vs psubusb+por (4 instrs)",
         "FFmpeg vf_blend.asm:314-362",
         True),
        ("extremity",
         "/tmp/trace_test_extremity_orig.txt",
         "/tmp/trace_test_extremity_opt.txt",
         "EXTREMITY: |255-a-b| via widen/sub/abs/pack (21 instrs) vs pxor+psubusb+por (6 instrs)",
         "FFmpeg vf_blend.asm:366-399",
         True),
        ("negation",
         "/tmp/trace_test_negation_orig.txt",
         "/tmp/trace_test_negation_opt.txt",
         "NEGATION: 255-|255-a-b| via widen/sub/abs/inv/pack (25 instrs) vs pxor+psubusb+por+pxor (7 instrs)",
         "FFmpeg vf_blend.asm:401-436",
         True),
        # --- FFmpeg vf_blend.asm: MULTIPLY with byte constraints ---
        # NOTE: Even with byte-range constraints, the two div-by-255
        # approximations are NOT bit-exact. E.g., 0xCF*0x11=3519:
        # orig=(3520+13)>>8=13, opt=(3647*257)>>16=14.
        ("multiply_byte",
         "/tmp/trace_test_multiply_byte_orig.txt",
         "/tmp/trace_test_multiply_byte_opt.txt",
         "MULTIPLY byte-range: div-by-255 (5 instrs) vs pmulhuw*257 (3 instrs), inputs in [0,255]",
         "FFmpeg vf_blend.asm:117-123 (constrained)",
         False),  # expected_unsat=False (two different approximations)
        # --- libjpeg-turbo jquanti-sse2.asm ---
        ("abs16",
         "/tmp/trace_test_abs16_sse2.txt",
         "/tmp/trace_test_abs16_ssse3.txt",
         "ABS16: SSE2 psraw/pxor/psubw (4 instrs) vs SSSE3 pabsw (1 instr)",
         "libjpeg-turbo jquanti-sse2.asm:131-146",
         True),
        # --- gzip longest_match: byte-by-byte vs TZCNT ---
        ("gzip_match",
         "/tmp/trace_test_gzip_match_orig.txt",
         "/tmp/trace_test_gzip_match_opt.txt",
         "GZIP MATCH: byte-by-byte test (47 instrs) vs TZCNT+SHR (3 instrs)",
         "gzip deflate.c:longest_match inner loop",
         True),
        # --- FFmpeg HARDMIX: 4 instructions vs 2 instructions ---
        ("hardmix",
         "/tmp/trace_test_hardmix_orig.txt",
         "/tmp/trace_test_hardmix_opt.txt",
         "HARDMIX: pxor/pcmpgtb/pxor (4 instrs) vs paddusb/pcmpeqb (2 instrs)",
         "FFmpeg vf_blend.asm:239-258",
         True),
        ("threshold_or",
         "/tmp/trace_test_threshold_or_orig.txt",
         "/tmp/trace_test_threshold_or_opt.txt",
         "THRESHOLD_OR: psubusb/pcmpeqb/por (6 instrs) vs pmaxub/psubusb/pcmpeqb (3 instrs)",
         "threshold OR pattern: (a>T)||(b>T) <-> max(a,b)>T",
         True),
    ]

    proved = 0
    disproved = 0
    errors = 0

    for short_name, trace_a, trace_b, desc, source, expected_unsat in candidates:
        print(f"=== {desc} ===")
        print(f"    Source: {source}")

        try:
            query = build_equiv_query(trace_a, trace_b, desc)
        except FileNotFoundError as e:
            print(f"  SKIP: {e}")
            print()
            continue

        if not query:
            errors += 1
            print()
            continue

        out_file = f"/tmp/equiv_{short_name}.smt2"
        result = run_z3(query, out_file)

        if result == "unsat":
            print(f"  PROVED EQUIVALENT (Z3: unsat)")
            proved += 1
        elif result == "sat":
            if not expected_unsat:
                print(f"  CORRECTLY IDENTIFIED AS NON-EQUIVALENT (Z3: sat)")
            else:
                print(f"  NOT EQUIVALENT (Z3: sat) -- counterexample exists!")
                errors += 1
            disproved += 1
        else:
            print(f"  {result}")
            errors += 1
        print(f"  Query: {out_file}")
        print()

    print("=" * 60)
    print(f"Results: {proved} proved equivalent, {disproved} disproved, {errors} errors")
    print(f"Total candidates: {len(candidates)}")
    return 0 if errors == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
