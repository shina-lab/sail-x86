#!/usr/bin/env python3
"""Compare Isla traces from sail-x86 and sail-x86-from-acl2 for equivalence.

Both models share symbolic input parameters (v0 = reg, v3/v4 = imm, etc.).
Each Isla trace is a path through the symbolic execution.

For equivalence, we check that every execution path in our model is matched
by some ACL2 path producing the same output. For each our-trace that writes
a register, we search for an ACL2 trace that's equivalent (unsat on output!=).

Usage:
    python3 compare_traces.py <ours_traces.smt> <acl2_traces.smt>
"""

import sys
import re
import z3
from dataclasses import dataclass, field
from typing import Optional

# ACL2 register name -> our GPR index (all 16)
GPR_NAME_TO_IDX = {
    'rax': 0, 'rcx': 1, 'rdx': 2, 'rbx': 3,
    'rsp': 4, 'rbp': 5, 'rsi': 6, 'rdi': 7,
    'r8': 8, 'r9': 9, 'r10': 10, 'r11': 11,
    'r12': 12, 'r13': 13, 'r14': 14, 'r15': 15,
}

GPR_IDX_TO_NAME = {v: k for k, v in GPR_NAME_TO_IDX.items()}

# Our flag register names -> bit position in ACL2's rflags
FLAG_BIT = {
    'CF': 0, 'PF': 2, 'AF': 4, 'ZF': 6, 'SF': 7, 'OF': 11,
}

# Registers to ignore in write tracking
INTERNAL_REGS = {
    'decode_pos', 'insn_start', 'insn_buf', 'fault_pending',
    'rip_rel_pending', 'next_rip', 'Final result',
    'log_register_writes', 'ms_reg', 'fault_reg',
    'msrs', 'seg_hidden_attrs', 'seg_hidden_bases', 'seg_hidden_limits',
    'cur_mode', 'cur_cpl', 'system_mode', 'rip_rel_disp', 'seg_regs',
    'app_view', 'marking_view',
}

# Canonical initial state variables (shared across all traces after substitution)
INIT_GPR = [z3.BitVec(f"init_gpr_{i}", 64) for i in range(16)]
INIT_RFLAGS = z3.BitVec("init_rflags", 32)


@dataclass
class TraceResult:
    """Result of processing a single Isla trace."""
    path_conds: list = field(default_factory=list)
    gpr_outputs: dict = field(default_factory=dict)    # idx -> z3 expr
    reg_outputs: dict = field(default_factory=dict)    # name -> z3 expr
    flag_outputs: dict = field(default_factory=dict)   # name -> z3 expr
    rflags_output: Optional[object] = None             # z3 expr
    gpr_reads: dict = field(default_factory=dict)      # idx -> z3 expr
    reg_reads: dict = field(default_factory=dict)      # name -> z3 expr
    flag_reads: dict = field(default_factory=dict)     # name -> z3 expr
    rflags_read: Optional[object] = None               # z3 expr
    rip_output: Optional[object] = None
    mem_writes: list = field(default_factory=list)     # [(addr, data)]


def parse_traces(filename):
    """Parse Isla trace file into list of event-string lists."""
    traces = []
    current = None
    with open(filename) as f:
        for line in f:
            stripped = line.strip()
            if stripped.startswith('(trace'):
                current = []
                traces.append(current)
            elif current is not None:
                if stripped == ')':
                    current = None
                else:
                    current.append(stripped)
    return traces


def parse_sexp(s):
    """Parse an S-expression string into nested lists/atoms."""
    tokens = []
    i = 0
    while i < len(s):
        if s[i] == '(':
            tokens.append('(')
            i += 1
        elif s[i] == ')':
            tokens.append(')')
            i += 1
        elif s[i] in ' \t\n':
            i += 1
        elif s[i] == '"':
            j = i + 1
            while j < len(s) and s[j] != '"':
                j += 1
            tokens.append(s[i:j+1])
            i = j + 1
        elif s[i] == '|':
            j = i + 1
            while j < len(s) and s[j] != '|':
                j += 1
            tokens.append(s[i:j+1])
            i = j + 1
        elif s[i] == ';':
            break
        else:
            j = i
            while j < len(s) and s[j] not in '() \t\n;':
                j += 1
            tokens.append(s[i:j])
            i = j

    def build(idx):
        if idx >= len(tokens):
            return None, idx
        if tokens[idx] == '(':
            lst = []
            idx += 1
            while idx < len(tokens) and tokens[idx] != ')':
                item, idx = build(idx)
                if item is not None:
                    lst.append(item)
            return lst, idx + 1
        else:
            return tokens[idx], idx + 1

    result, _ = build(0)
    return result


def sexp_to_z3(sexp, env):
    """Convert parsed S-expression to Z3 expression."""
    if isinstance(sexp, str):
        if sexp in env:
            return env[sexp]
        if sexp.startswith('#x'):
            val = int(sexp[2:], 16)
            nbits = (len(sexp) - 2) * 4
            return z3.BitVecVal(val, nbits)
        if sexp.startswith('#b'):
            val = int(sexp[2:], 2)
            nbits = len(sexp) - 2
            return z3.BitVecVal(val, nbits)
        if sexp == 'true':
            return z3.BoolVal(True)
        if sexp == 'false':
            return z3.BoolVal(False)
        raise ValueError(f"Unknown atom: {sexp}")

    if not isinstance(sexp, list) or len(sexp) == 0:
        raise ValueError(f"Bad sexp: {sexp}")

    head = sexp[0]

    # (_ extract hi lo), (_ zero_extend n), (_ sign_extend n)
    if isinstance(head, list) and head[0] == '_':
        op = head[1]
        if op == 'extract':
            hi, lo = int(head[2]), int(head[3])
            return z3.Extract(hi, lo, sexp_to_z3(sexp[1], env))
        if op == 'zero_extend':
            return z3.ZeroExt(int(head[2]), sexp_to_z3(sexp[1], env))
        if op == 'sign_extend':
            return z3.SignExt(int(head[2]), sexp_to_z3(sexp[1], env))

    # (_ struct (|field| val)) -- extract the inner value
    if head == '_' and len(sexp) >= 3 and sexp[1] == 'struct':
        field_sexp = sexp[2]
        if isinstance(field_sexp, list) and len(field_sexp) == 2:
            return sexp_to_z3(field_sexp[1], env)
        raise ValueError(f"Unsupported struct: {sexp}")

    def _reduce(fn, lst):
        r = lst[0]
        for x in lst[1:]:
            r = fn(r, x)
        return r

    ops = {
        'concat': lambda a: _reduce(z3.Concat, a),
        'bvor':   lambda a: _reduce(lambda x, y: x | y, a),
        'bvand':  lambda a: _reduce(lambda x, y: x & y, a),
        'bvxor':  lambda a: _reduce(lambda x, y: x ^ y, a),
        'bvadd':  lambda a: a[0] + a[1],
        'bvsub':  lambda a: a[0] - a[1],
        'bvmul':  lambda a: a[0] * a[1],
        'bvnot':  lambda a: ~a[0],
        'bvneg':  lambda a: -a[0],
        'bvshl':  lambda a: a[0] << a[1],
        'bvlshr': lambda a: z3.LShR(a[0], a[1]),
        'bvashr': lambda a: a[0] >> a[1],
        '=':      lambda a: a[0] == a[1],
        'not':    lambda a: z3.Not(a[0]),
        'and':    lambda a: z3.And(*a),
        'or':     lambda a: z3.Or(*a),
        'ite':    lambda a: z3.If(a[0], a[1], a[2]),
        'bvsge':  lambda a: a[0] >= a[1],
        'bvsle':  lambda a: a[0] <= a[1],
        'bvsgt':  lambda a: a[0] > a[1],
        'bvslt':  lambda a: a[0] < a[1],
        'bvuge':  lambda a: z3.UGE(a[0], a[1]),
        'bvule':  lambda a: z3.ULE(a[0], a[1]),
        'bvugt':  lambda a: z3.UGT(a[0], a[1]),
        'bvult':  lambda a: z3.ULT(a[0], a[1]),
        'bvurem': lambda a: z3.URem(a[0], a[1]),
        'bvsrem': lambda a: z3.SRem(a[0], a[1]),
        'bvsdiv': lambda a: a[0] / a[1],
        'bvudiv': lambda a: z3.UDiv(a[0], a[1]),
    }

    if head in ops:
        args = [sexp_to_z3(a, env) for a in sexp[1:]]
        return ops[head](args)

    raise ValueError(f"Unknown SMT op: {head}")


def build_trace_z3(trace, shared_env, prefix):
    """Process a single trace, building Z3 expressions.

    Returns a TraceResult with all outputs, reads, path conditions.
    """
    path_conds = []
    env = dict(shared_env)
    result = TraceResult()
    gpr_write_vec_names = None

    for event in trace:
        event_nc = re.sub(r'\s*;.*$', '', event.strip())
        if not event_nc:
            continue

        sexp = parse_sexp(event_nc)
        if sexp is None or not isinstance(sexp, list):
            continue

        tag = sexp[0]

        if tag == 'declare-const':
            name = sexp[1]
            sort = sexp[2]
            if name in shared_env and name in env:
                continue
            if isinstance(sort, list) and sort[0] == '_' and sort[1] == 'BitVec':
                env[name] = z3.BitVec(f"{prefix}_{name}", int(sort[2]))
            elif sort == 'Bool':
                env[name] = z3.Bool(f"{prefix}_{name}")

        elif tag == 'define-const':
            try:
                env[sexp[1]] = sexp_to_z3(sexp[2], env)
            except (ValueError, KeyError, TypeError):
                pass

        elif tag == 'assert':
            try:
                path_conds.append(sexp_to_z3(sexp[1], env))
            except (ValueError, KeyError, TypeError):
                pass

        elif tag == 'read-reg':
            reg_name = sexp[1].strip('|')
            val_sexp = sexp[3] if len(sexp) > 3 else sexp[2]

            # GPR vector read (our model)
            if reg_name == 'GPR' and isinstance(val_sexp, list) \
               and len(val_sexp) >= 2 and val_sexp[0] == '_' and val_sexp[1] == 'vec':
                if not result.gpr_reads:
                    for i, vname in enumerate(val_sexp[2:]):
                        if vname in env:
                            result.gpr_reads[i] = env[vname]

            # Individual flag reads (our model)
            elif reg_name in FLAG_BIT and reg_name not in result.flag_reads:
                if isinstance(val_sexp, str) and val_sexp in env:
                    result.flag_reads[reg_name] = env[val_sexp]
                elif isinstance(val_sexp, list):
                    try:
                        result.flag_reads[reg_name] = sexp_to_z3(val_sexp, env)
                    except (ValueError, KeyError, TypeError):
                        pass

            # rflags read (ACL2 model)
            elif reg_name == 'rflags' and result.rflags_read is None:
                try:
                    result.rflags_read = sexp_to_z3(val_sexp, env)
                except (ValueError, KeyError, TypeError):
                    pass

            # Individual register reads (ACL2 style)
            elif reg_name in GPR_NAME_TO_IDX and reg_name not in result.reg_reads:
                if isinstance(val_sexp, str) and val_sexp in env:
                    result.reg_reads[reg_name] = env[val_sexp]
                elif isinstance(val_sexp, list):
                    try:
                        result.reg_reads[reg_name] = sexp_to_z3(val_sexp, env)
                    except (ValueError, KeyError, TypeError):
                        pass

        elif tag == 'write-reg':
            reg_name = sexp[1].strip('|')
            val_sexp = sexp[3] if len(sexp) > 3 else sexp[2]

            # GPR vector write (our model)
            if reg_name == 'GPR' and isinstance(val_sexp, list) \
               and len(val_sexp) >= 2 and val_sexp[0] == '_' and val_sexp[1] == 'vec':
                gpr_write_vec_names = val_sexp[2:]

            elif reg_name == 'RIP' or reg_name == 'rip':
                try:
                    result.rip_output = sexp_to_z3(val_sexp, env)
                except (ValueError, KeyError, TypeError):
                    pass

            elif reg_name == 'rflags':
                try:
                    result.rflags_output = sexp_to_z3(val_sexp, env)
                except (ValueError, KeyError, TypeError):
                    pass

            elif reg_name in FLAG_BIT:
                try:
                    result.flag_outputs[reg_name] = sexp_to_z3(val_sexp, env)
                except (ValueError, KeyError, TypeError):
                    pass

            elif reg_name in GPR_NAME_TO_IDX:
                try:
                    result.reg_outputs[reg_name] = sexp_to_z3(val_sexp, env)
                except (ValueError, KeyError, TypeError):
                    pass

            elif reg_name not in INTERNAL_REGS:
                try:
                    sexp_to_z3(val_sexp, env)
                except (ValueError, KeyError, TypeError):
                    pass

        elif tag == 'write-mem':
            try:
                if len(sexp) >= 3:
                    addr = sexp_to_z3(sexp[1], env)
                    data = sexp_to_z3(sexp[2], env)
                    result.mem_writes.append((addr, data))
            except (ValueError, KeyError, TypeError):
                pass

    # Resolve GPR vector write elements
    if gpr_write_vec_names and len(gpr_write_vec_names) >= 16:
        for i, vname in enumerate(gpr_write_vec_names):
            if i < 16 and vname in env:
                result.gpr_outputs[i] = env[vname]

    result.path_conds = path_conds
    return result


def get_early_declarations(trace):
    """Extract declarations that appear before any define-const."""
    decls = {}
    for event in trace:
        event_nc = re.sub(r'\s*;.*$', '', event.strip())
        if not event_nc:
            continue
        sexp = parse_sexp(event_nc)
        if not sexp or not isinstance(sexp, list):
            continue
        if sexp[0] == 'define-const':
            break
        if sexp[0] == 'declare-const':
            name = sexp[1]
            sort = sexp[2]
            if isinstance(sort, list) and sort[0] == '_' and sort[1] == 'BitVec':
                decls[name] = ('BitVec', int(sort[2]))
            elif sort == 'Bool':
                decls[name] = ('Bool',)
    return decls


def detect_shared_inputs(ours_trace, acl2_trace):
    """Find variables declared identically in both traces before first define-const."""
    ours_decls = get_early_declarations(ours_trace)
    acl2_decls = get_early_declarations(acl2_trace)

    shared_env = {}
    for name in ours_decls:
        if name in acl2_decls and ours_decls[name] == acl2_decls[name]:
            sort = ours_decls[name]
            if sort[0] == 'BitVec':
                shared_env[name] = z3.BitVec(name, sort[1])
            elif sort[0] == 'Bool':
                shared_env[name] = z3.Bool(name)
    return shared_env


def canonicalize(tr, init_gpr, init_rflags):
    """Replace trace-specific initial-state variables with canonical ones using z3.substitute."""
    subs = []

    # Our model: GPR vector reads -> canonical init_gpr
    for idx, val in tr.gpr_reads.items():
        if idx < 16:
            subs.append((val, init_gpr[idx]))

    # ACL2 model: individual register reads -> canonical init_gpr
    for name, val in tr.reg_reads.items():
        idx = GPR_NAME_TO_IDX.get(name)
        if idx is not None:
            subs.append((val, init_gpr[idx]))

    # ACL2 model: rflags read -> canonical init_rflags
    if tr.rflags_read is not None:
        subs.append((tr.rflags_read, init_rflags))

    # Our model: individual flag reads -> extract from canonical init_rflags
    for flag_name, val in tr.flag_reads.items():
        bit = FLAG_BIT[flag_name]
        subs.append((val, z3.Extract(bit, bit, init_rflags)))

    if not subs:
        return

    def sub(expr):
        if expr is None:
            return None
        try:
            return z3.substitute(expr, *subs)
        except Exception:
            return expr

    tr.path_conds = [sub(c) for c in tr.path_conds]
    tr.gpr_outputs = {k: sub(v) for k, v in tr.gpr_outputs.items()}
    tr.reg_outputs = {k: sub(v) for k, v in tr.reg_outputs.items()}
    tr.flag_outputs = {k: sub(v) for k, v in tr.flag_outputs.items()}
    tr.rflags_output = sub(tr.rflags_output)
    tr.rip_output = sub(tr.rip_output)
    tr.mem_writes = [(sub(a), sub(d)) for a, d in tr.mem_writes]


def check_equiv_pair(ours_tr, ours_val, acl2_tr, acl2_val, timeout=60000):
    """Check if a pair of traces always produce the same output when both active.

    Returns: ('unsat', None) if equivalent (no input makes both active with different output),
             ('sat', model) if counterexample found,
             ('timeout', None) if solver timed out.
    """
    s = z3.Solver()
    s.set("timeout", timeout)
    for c in ours_tr.path_conds:
        s.add(c)
    for c in acl2_tr.path_conds:
        s.add(c)
    s.add(ours_val != acl2_val)

    result = s.check()
    if result == z3.unsat:
        return ('unsat', None)
    elif result == z3.sat:
        return ('sat', s.model())
    else:
        return ('timeout', None)


def find_matching_acl2(ours_tr, ours_val, acl2_candidates, get_acl2_val,
                       timeout=60000):
    """Find an ACL2 trace equivalent to ours_tr for the given output.

    Iterates ACL2 candidates, returns on first equivalent match.
    Returns (True, pairs_checked) if matched, (False, pairs_checked) if not.
    On failure, also returns the last counterexample model.
    """
    last_model = None
    last_acl2_val = None
    checked = 0

    for acl2_tr in acl2_candidates:
        acl2_val = get_acl2_val(acl2_tr)
        if acl2_val is None:
            continue

        checked += 1
        status, model = check_equiv_pair(ours_tr, ours_val,
                                         acl2_tr, acl2_val, timeout)
        if status == 'unsat':
            return (True, checked, None, None)
        elif status == 'sat':
            last_model = model
            last_acl2_val = acl2_val

    return (False, checked, last_model, last_acl2_val)


def check_equivalence(ours_file, acl2_file):
    """Check instruction equivalence between the two models."""
    ours_traces_raw = parse_traces(ours_file)
    acl2_traces_raw = parse_traces(acl2_file)

    print(f"Our model: {len(ours_traces_raw)} traces")
    print(f"ACL2 model: {len(acl2_traces_raw)} traces")

    if not ours_traces_raw or not acl2_traces_raw:
        print("ERROR: No traces found in one or both files")
        return False

    # Auto-detect shared symbolic inputs
    shared_env = detect_shared_inputs(ours_traces_raw[0], acl2_traces_raw[0])
    print(f"Shared inputs: {sorted(shared_env.keys())}")

    # --- Process ALL our traces ---
    print(f"\nProcessing our model ({len(ours_traces_raw)} traces)...")
    ours_results = []
    for i, t in enumerate(ours_traces_raw):
        try:
            tr = build_trace_z3(t, shared_env, f"A{i}")
            ours_results.append(tr)
        except Exception:
            pass
    print(f"  {len(ours_results)} traces processed")

    # --- Process ALL ACL2 traces ---
    print(f"\nProcessing ACL2 model ({len(acl2_traces_raw)} traces)...")
    acl2_results = []
    for i, t in enumerate(acl2_traces_raw):
        try:
            tr = build_trace_z3(t, shared_env, f"B{i}")
            acl2_results.append(tr)
        except Exception:
            pass
        if (i + 1) % 500 == 0:
            print(f"  {i+1}/{len(acl2_traces_raw)} ({len(acl2_results)} ok)")
    print(f"  {len(acl2_results)} traces processed")

    # --- Canonicalize all traces ---
    print("\nCanonicalizing initial state...")
    for tr in ours_results:
        canonicalize(tr, INIT_GPR, INIT_RFLAGS)
    for tr in acl2_results:
        canonicalize(tr, INIT_GPR, INIT_RFLAGS)

    # --- Collect stats ---
    ours_gpr_idxs = set()
    ours_flag_names = set()
    ours_has_mem = False
    acl2_reg_names = set()
    acl2_has_rflags = False
    acl2_has_mem = False

    for tr in ours_results:
        ours_gpr_idxs.update(tr.gpr_outputs.keys())
        ours_flag_names.update(tr.flag_outputs.keys())
        if tr.mem_writes:
            ours_has_mem = True
    for tr in acl2_results:
        acl2_reg_names.update(tr.reg_outputs.keys())
        if tr.rflags_output is not None:
            acl2_has_rflags = True
        if tr.mem_writes:
            acl2_has_mem = True

    print(f"Our GPR outputs: {sorted(ours_gpr_idxs)}")
    print(f"Our flag outputs: {sorted(ours_flag_names)}")
    print(f"ACL2 reg outputs: {sorted(acl2_reg_names)}")
    print(f"ACL2 rflags: {'yes' if acl2_has_rflags else 'no'}")

    all_ok = True
    summary = []

    # === GPR Equivalence ===
    # For each ours trace with GPR[i] output, find a matching ACL2 trace.
    # A match means: for all inputs where both traces are active, outputs agree.
    print("\n=== GPR Equivalence ===")
    for gpr_idx in range(16):
        gpr_name = GPR_IDX_TO_NAME.get(gpr_idx)
        if gpr_name is None:
            continue

        ours_with = [tr for tr in ours_results if gpr_idx in tr.gpr_outputs]
        acl2_with = [tr for tr in acl2_results if gpr_name in tr.reg_outputs]

        if not ours_with and not acl2_with:
            continue
        if not ours_with:
            summary.append((f"GPR {gpr_name}", "SKIP", "no ours writes"))
            continue
        if not acl2_with:
            print(f"  GPR[{gpr_idx}] ({gpr_name}): SKIP - no ACL2 writes "
                  f"({len(ours_with)} ours traces)")
            summary.append((f"GPR {gpr_name}", "SKIP",
                            f"no ACL2 writes ({len(ours_with)} ours)"))
            continue

        all_matched = True
        total_pairs = 0

        for ours_i, ours_tr in enumerate(ours_with):
            ours_val = ours_tr.gpr_outputs[gpr_idx]
            matched, checked, model, acl2_val = find_matching_acl2(
                ours_tr, ours_val, acl2_with,
                lambda tr: tr.reg_outputs.get(gpr_name))
            total_pairs += checked

            if not matched:
                print(f"  GPR[{gpr_idx}] ({gpr_name}): DIFFERENT "
                      f"(ours trace {ours_i}, checked {checked} ACL2 traces)")
                if model is not None:
                    inputs = ', '.join(
                        f"{k}={model.eval(v)}"
                        for k, v in sorted(shared_env.items()))
                    print(f"    inputs: {inputs}")
                    print(f"    ours={model.eval(ours_val)}")
                    print(f"    acl2={model.eval(acl2_val)}")
                summary.append((f"GPR {gpr_name}", "FAIL", "different"))
                all_ok = False
                all_matched = False
                break

        if all_matched:
            print(f"  GPR[{gpr_idx}] ({gpr_name}): EQUIVALENT "
                  f"({len(ours_with)} ours traces matched, "
                  f"{total_pairs} pairs checked)")
            summary.append((f"GPR {gpr_name}", "PASS", "equivalent"))

    # === Flag Equivalence ===
    if ours_flag_names:
        print("\n=== Flag Equivalence ===")
        if not acl2_has_rflags:
            print("  No rflags writes in ACL2 traces (skipped)")
            for fn in sorted(ours_flag_names):
                summary.append((f"Flag {fn}", "SKIP", "no ACL2 rflags"))
        else:
            for flag_name in ['CF', 'PF', 'AF', 'ZF', 'SF', 'OF']:
                if flag_name not in ours_flag_names:
                    continue

                bit_pos = FLAG_BIT[flag_name]

                ours_with = [tr for tr in ours_results
                             if flag_name in tr.flag_outputs]
                acl2_with = []
                for tr in acl2_results:
                    if tr.rflags_output is not None:
                        sz = (tr.rflags_output.size()
                              if hasattr(tr.rflags_output, 'size') else None)
                        if sz is not None and bit_pos < sz:
                            acl2_with.append(tr)

                if not ours_with or not acl2_with:
                    print(f"  {flag_name}: SKIP (ours={len(ours_with)}, "
                          f"acl2={len(acl2_with)})")
                    summary.append((f"Flag {flag_name}", "SKIP", "no data"))
                    continue

                all_matched = True
                total_pairs = 0

                for ours_i, ours_tr in enumerate(ours_with):
                    ours_val = ours_tr.flag_outputs[flag_name]
                    matched, checked, model, acl2_val = find_matching_acl2(
                        ours_tr, ours_val, acl2_with,
                        lambda tr, bp=bit_pos: z3.Extract(
                            bp, bp, tr.rflags_output))
                    total_pairs += checked

                    if not matched:
                        print(f"  {flag_name} (bit {bit_pos}): DIFFERENT "
                              f"(ours trace {ours_i})")
                        if model is not None:
                            inputs = ', '.join(
                                f"{k}={model.eval(v)}"
                                for k, v in sorted(shared_env.items()))
                            print(f"    inputs: {inputs}")
                            print(f"    ours={model.eval(ours_val)}")
                            print(f"    acl2={model.eval(acl2_val)}")
                        summary.append((f"Flag {flag_name}", "FAIL",
                                        "different"))
                        all_ok = False
                        all_matched = False
                        break

                if all_matched:
                    print(f"  {flag_name} (bit {bit_pos}): EQUIVALENT "
                          f"({len(ours_with)} ours × {len(acl2_with)} acl2, "
                          f"{total_pairs} pairs)")
                    summary.append((f"Flag {flag_name}", "PASS", "equivalent"))

    # === RIP Equivalence ===
    print("\n=== RIP Equivalence ===")
    ours_rip = [tr for tr in ours_results if tr.rip_output is not None]
    acl2_rip = [tr for tr in acl2_results if tr.rip_output is not None]

    if ours_rip and acl2_rip:
        all_matched = True
        total_pairs = 0

        for ours_i, ours_tr in enumerate(ours_rip):
            matched, checked, model, acl2_val = find_matching_acl2(
                ours_tr, ours_tr.rip_output, acl2_rip,
                lambda tr: tr.rip_output)
            total_pairs += checked

            if not matched:
                print(f"  RIP: DIFFERENT (ours trace {ours_i})")
                if model is not None:
                    print(f"    ours={model.eval(ours_tr.rip_output)}")
                    print(f"    acl2={model.eval(acl2_val)}")
                summary.append(("RIP", "FAIL", "different"))
                all_ok = False
                all_matched = False
                break

        if all_matched:
            print(f"  RIP: EQUIVALENT ({len(ours_rip)} ours traces, "
                  f"{total_pairs} pairs)")
            summary.append(("RIP", "PASS", "equivalent"))
    elif ours_rip:
        print("  No RIP writes in ACL2 traces")
        summary.append(("RIP", "SKIP", "no ACL2 RIP"))
    else:
        print("  No RIP writes in either model")

    # === Memory Write Warning ===
    if ours_has_mem or acl2_has_mem:
        print("\n=== Memory Writes ===")
        ours_mw = sum(len(tr.mem_writes) for tr in ours_results)
        acl2_mw = sum(len(tr.mem_writes) for tr in acl2_results)
        print(f"  WARNING: Memory writes detected but not compared")
        print(f"  ours: {ours_mw} writes, acl2: {acl2_mw} writes")
        summary.append(("Memory", "WARN", "not compared"))

    # === Summary ===
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"{'Component':<25} {'Status':<10} {'Detail'}")
    print("-" * 60)
    for component, status, detail in summary:
        print(f"{component:<25} {status:<10} {detail}")
    print("-" * 60)

    passes = sum(1 for _, s, _ in summary if s == "PASS")
    fails = sum(1 for _, s, _ in summary if s == "FAIL")
    timeouts = sum(1 for _, s, _ in summary if s == "TIMEOUT")
    warnings = sum(1 for _, s, _ in summary if s == "WARN")
    skips = sum(1 for _, s, _ in summary if s == "SKIP")
    print(f"PASS={passes}  FAIL={fails}  TIMEOUT={timeouts}  "
          f"WARN={warnings}  SKIP={skips}")

    print(f"\n{'PASS' if all_ok else 'FAIL'}")
    return all_ok


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <ours_traces.smt> <acl2_traces.smt>")
        sys.exit(1)
    ok = check_equivalence(sys.argv[1], sys.argv[2])
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
