#!/usr/bin/env python3
"""Check LLM-proposed rewrites of straight-line blocks with Isla and Z3.

Inputs
  blocks.json      from extract_blocks.py (one entry per distinct block)
  proposals/*.json each maps block id -> {"rewrite": "<Intel syntax, one
                   instruction per line>" or null, "note": "..."}

For every block with a rewrite, the original bytes (side a) and the
assembled rewrite (side b) are executed symbolically through the model
from the same symbolic register state, and Z3 is asked for an input on
which the two final states differ.  UNSAT proves the rewrite; SAT gives a
counterexample.  The compared state is every general-purpose register,
every vector register the ISA level can name (at the level's width), the
mask registers for AVX-512, the 256-byte memory window when the block
accesses memory, and the status flags a following conditional consumes.
A rewrite that assembles only at a higher ISA level than the original is
an "ISA violation" and is not checked.

Stages: --stage tests | ir | traces | z3 (default).  --originals runs the
original blocks alone (no proposals) to find out which blocks the model
executes symbolically.

Working files go under $BLOCKS_WORK (default /tmp/claude-1000/prove_blocks).
"""

import argparse
import concurrent.futures
import glob
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.stdout.reconfigure(line_buffering=True)
SCRIPT_DIR = Path(__file__).resolve().parent
VERIFY_DIR = SCRIPT_DIR.parent
sys.path.insert(0, str(VERIFY_DIR))
import prove_candidates as pc  # noqa: E402  (assemble/IR/Isla/Z3 helpers)
import prove_equiv  # noqa: E402

WORK = Path(os.environ.get("BLOCKS_WORK", "/tmp/claude-1000/prove_blocks"))
TESTS_SAIL = SCRIPT_DIR / "blocks_tests.sail"
# The model to execute: a fixed checkout (BLOCKS_MODEL_DIR) rather than the
# working tree, so that edits made elsewhere during a run do not change the
# revision under test.
MODEL_DIR = Path(os.environ.get("BLOCKS_MODEL_DIR", VERIFY_DIR.parent / "model"))

# GAS directives that pin the ISA level; anything newer fails to assemble.
LEVELS = {
    "x86-64": [".arch generic64"],
    "sse2":   [".arch generic64"],
    "sse3":   [".arch generic64", ".arch .sse3"],
    "ssse3":  [".arch generic64", ".arch .ssse3"],
    "sse4.1": [".arch generic64", ".arch .sse4.1"],
    "sse4.2": [".arch generic64", ".arch .sse4.2"],
    "avx":    [".arch generic64", ".arch .avx"],
    "avx2":   [".arch generic64", ".arch .avx2"],
    "avx512": [".arch generic64", ".arch .avx512f", ".arch .avx512bw",
               ".arch .avx512dq", ".arch .avx512vl", ".arch .avx512cd"],
}
EXTRAS = {
    "aes": [".arch .aes"], "pclmul": [".arch .pclmul"], "sha": [".arch .sha"],
    "bmi1": [".arch .bmi"], "bmi2": [".arch .bmi2"], "adx": [".arch .adx"],
    "popcnt": [".arch .popcnt"], "lzcnt": [".arch .lzcnt"], "fma": [".arch .fma"],
    "f16c": [".arch .f16c"], "gfni": [".arch .gfni"], "vaes": [".arch .vaes"],
    "vpclmulqdq": [".arch .vpclmulqdq"], "movbe": [".arch .movbe"],
    "icl": [".arch .avx512vbmi", ".arch .avx512_vbmi2", ".arch .avx512_vnni",
            ".arch .avx512_bitalg", ".arch .avx512_vpopcntdq", ".arch .avx512ifma",
            ".arch .gfni", ".arch .vaes", ".arch .vpclmulqdq"],
}
VEC_WIDTH = {"x86-64": 128, "sse2": 128, "sse3": 128, "ssse3": 128, "sse4.1": 128,
             "sse4.2": 128, "avx": 256, "avx2": 256, "avx512": 512}
FLAG_BIT = {"CF": 0, "PF": 2, "ZF": 6, "SF": 7, "OF": 11}
MASK64 = (1 << 64) - 1


class IsaViolation(Exception):
    pass


def bind_constants(body, block):
    """Replace [CONST_n] (or [rip+CONST_n]) in a rewrite by the constant's
    absolute address in the memory window."""
    addr = {c["name"]: 0x7000 + c["off"] for c in block.get("constants", [])}

    def sub(m):
        name = "CONST_" + m.group(1)
        if name not in addr:
            return m.group(0)
        return f"[0x{addr[name]:x}]"

    return re.sub(r"\[\s*(?:rip\s*\+\s*)?CONST_(\d+)\s*\]", sub, body)


def assemble(body, level, extras):
    """Assemble Intel-syntax text under the level; return [(bytes, text)]."""
    lines = list(LEVELS[level])
    for e in extras:
        lines += EXTRAS.get(e, [])
    lines += [".intel_syntax noprefix", ".text"]
    for line in body.strip().splitlines():
        line = line.split(";")[0].split("#")[0].strip()
        if line:
            lines.append("\t" + line)
    with tempfile.TemporaryDirectory() as td:
        src, obj = Path(td) / "c.s", Path(td) / "c.o"
        src.write_text("\n".join(lines) + "\n")
        r = subprocess.run(["as", "--64", "-o", str(obj), str(src)],
                           capture_output=True, text=True)
        if r.returncode != 0:
            msg = r.stderr.strip()
            if "not supported on" in msg or "operand size mismatch" in msg \
                    or "unsupported instruction" in msg:
                raise IsaViolation(msg)
            raise RuntimeError(msg)
        r = subprocess.run(["objdump", "-d", "--insn-width=15", "-M", "intel", str(obj)],
                           capture_output=True, text=True, check=True)
    insns = []
    for line in r.stdout.splitlines():
        m = re.match(r"^\s*[0-9a-f]+:\s+((?:[0-9a-f]{2}\s)+)\s*(\S.*)$", line)
        if m:
            insns.append((bytes.fromhex(m.group(1).replace(" ", "")), m.group(2).strip()))
    return insns


# ---------------------------------------------------------------------------
# Sail test functions
# ---------------------------------------------------------------------------

HELPERS = """\
// Generated by prove_blocks.py; do not edit.
// test_<id>_a executes the original block, test_<id>_b the proposal; both
// return the compared machine state as one bitvector ("Final result").

val flag_bits : unit -> bits(64)
function flag_bits() = read_rflags()
"""


def outputs_for(block):
    """(sail expressions, total width) of the compared state: the
    registers and flags live after the block, at the ISA level's vector
    width, plus the whole memory window when the block accesses memory."""
    exprs, width = [], 0
    live = block["live_out"]
    for i in live["gpr"]:
        exprs.append(f"GPR[{i}]")
        width += 64
    w = VEC_WIDTH[block["level"]]
    nvec = 32 if block["level"] == "avx512" else 16
    for i in live["vec"]:
        if i >= nvec:
            continue
        exprs.append(f"ZMM[{i}]" if w == 512 else f"ZMM[{i}][{w - 1}..0]")
        width += w
    if block["level"] == "avx512":
        for i in live["k"]:
            exprs.append(f"KREG[{i}]")
            width += 64
    if block["mem"]:
        exprs.append("mem_window")
        width += 2048
    for f in live["flags"]:
        b = FLAG_BIT[f]
        exprs.append(f"flag_bits()[{b}..{b}]")
        width += 1
    if not exprs:
        exprs.append("GPR[4]")   # nothing live: compare the stack pointer
        width += 64
    return exprs, width


def gen_test(func, insns, block):
    exprs, width = outputs_for(block)
    lines = [f"val {func} : unit -> bits({width})",
             f"function {func}() = {{",
             "  enable_features_all();",
             "  system_state = SysRunning;"]
    mem = block["mem"]
    if mem:
        for base, r in mem["regions"].items():
            v = (0x7000 + r["start"] - r["lo"]) & MASK64
            lines.append(f"  GPR[{int(base)}] = 0x{v:016X};  // base register: window +{r['start']}")
        for reg, v in mem["index_values"].items():
            lines.append(f"  GPR[{int(reg)}] = 0x{v:016X};  // index register")
    for c in block.get("constants", []):
        lo, hi = 8 * c["off"], 8 * (c["off"] + c["size"]) - 1
        value = bytes.fromhex(c["hex"])[::-1].hex().upper()
        lines.append(f"  mem_window[{hi}..{lo}] = 0x{value};  // {c['name']} = {c['sym']}")
    for byte_seq, text in insns:
        lines.append(f"  setup_and_exec({pc.sail_literal(byte_seq)});  // {text}")
    lines.append("  " + " @ ".join(exprs))
    lines.append("}")
    return "\n".join(lines)


def generate_ir(func_names, tests_path, ir_base):
    sail_files = []
    for line in (MODEL_DIR / "x86.sail_project").read_text().splitlines():
        cleaned = line.strip().rstrip(",").strip()
        if cleaned.endswith(".sail"):
            sail_files.append(cleaned)
    cmd = [str(pc.SAIL_EXE), "--plugin", str(pc.ISLA_PLUGIN), "--isla", "-D", "ISLA",
           "-splice", str(VERIFY_DIR / "splice_ours.sail"), "-splice", str(tests_path)]
    for f in func_names:
        cmd += ["--isla-preserve", f]
    cmd += ["-o", str(ir_base)] + sail_files
    t0 = time.time()
    r = subprocess.run(cmd, cwd=str(MODEL_DIR), env=pc.opam_env(),
                       capture_output=True, text=True)
    if r.returncode != 0:
        err = [l for l in r.stderr.splitlines()
               if not l.startswith("Warning") and "suppressed" not in l]
        raise RuntimeError("sail failed for %s:\n%s" % (ir_base, "\n".join(err[:30])))
    ir = Path(str(ir_base) + ".ir")
    print(f"    {ir.name}: {ir.stat().st_size:,} bytes, {time.time() - t0:.0f}s")
    return ir


def run_isla(func, ir, trace_dir, timeout):
    """Symbolically execute one test function (unsimplified traces, as in
    prove_candidates.py), with a wall-clock limit in seconds."""
    trace = trace_dir / f"{func}.trace"
    err = trace_dir / f"{func}.err"
    if trace.exists() and trace.stat().st_mtime > ir.stat().st_mtime:
        return trace, "cached"
    t0 = time.time()
    with open(trace, "w") as out, open(err, "w") as e:
        subprocess.run([str(pc.ISLA_EXE), func, "--arch", str(ir),
                        "--config", str(pc.ISLA_CONFIG),
                        "--traces", "--simplify-registers",
                        "--timeout", str(timeout)],
                       stdout=out, stderr=e, text=True)
    return trace, f"{time.time() - t0:.0f}s"


def trace_status(trace, err):
    """('ok', paths) or ('error', reason)."""
    n = pc.trace_paths(trace) if trace.exists() else 0
    if n == 1:
        with open(trace, errors="replace") as f:
            if "Final result| nil (_ poison)" in f.read():
                # an uncaught Sail exception (a fault raised by the block)
                return "error", "fault: the sequence raised an exception"
        return "ok", ""
    if n > 1:
        return "error", f"{n} paths: the model branches on data in this sequence"
    msg = ""
    if err.exists():
        for line in err.read_text().splitlines():
            if line.strip() and not line.startswith("Execution took"):
                msg = line.strip()[:200]
                break
    if not msg and trace.exists():
        for line in trace.read_text().splitlines():
            if "assert" in line or "exception" in line.lower():
                msg = line.strip()[:200]
                break
    return "error", msg or f"{n} paths"


def decode_counterexample(model_text, trace_a):
    """Map Z3 model values back to the registers they initialize."""
    maps = pc.reg_mappings(str(trace_a))
    vals = dict(re.findall(r"\(define-fun (v\d+) \(\) \(_ BitVec \d+\)\s+(#[xb][0-9a-fA-F]+)\)",
                           model_text))
    out = {}
    for reg, elems in maps.items():
        got = [vals.get(e) for e in elems]
        if any(g is not None for g in got):
            out[reg] = got
    return out


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------

def load_proposals(pattern):
    """Proposals from every file matching the glob(s); several globs may
    be given separated by whitespace."""
    props = {}
    paths = sorted({p for pat in pattern.split() for p in glob.glob(pat)})
    for path in paths:
        data = json.loads(Path(path).read_text())
        for bid, p in data.items():
            props[bid] = p
    return props


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--blocks", default=str(SCRIPT_DIR / "blocks.json"))
    ap.add_argument("--proposals", default=str(SCRIPT_DIR / "proposals" / "*.json"))
    ap.add_argument("--only", nargs="*", default=None, help="block ids")
    ap.add_argument("--project", default=None)
    ap.add_argument("--originals", action="store_true",
                    help="execute the original blocks only (support check)")
    ap.add_argument("--stage", choices=["tests", "ir", "traces", "z3"], default="z3")
    ap.add_argument("--chunk", type=int, default=300, help="test functions per IR file")
    ap.add_argument("--jobs", type=int, default=32)
    ap.add_argument("--ir-jobs", type=int, default=4)
    ap.add_argument("--z3-timeout", type=int, default=60)
    ap.add_argument("--isla-timeout", type=int, default=60,
                    help="seconds of symbolic execution per sequence")
    ap.add_argument("--out", default=str(SCRIPT_DIR / "results.json"))
    args = ap.parse_args()

    blocks = {b["id"]: b for b in json.loads(Path(args.blocks).read_text())}
    props = {} if args.originals else load_proposals(args.proposals)
    ids = [i for i in blocks if (not args.only or i in args.only)
           and (not args.project or blocks[i]["project"] == args.project)]
    if not args.originals:
        ids = [i for i in ids if props.get(i, {}).get("rewrite")]
    WORK.mkdir(parents=True, exist_ok=True)
    trace_dir, smt_dir = WORK / "traces", WORK / "smt"
    trace_dir.mkdir(exist_ok=True)
    smt_dir.mkdir(exist_ok=True)

    # 1. assemble proposals and write the test functions
    results, funcs, tests = {}, [], [HELPERS]
    for bid in ids:
        b = blocks[bid]
        res = {"id": bid, "project": b["project"], "level": b["level"], "n_a": b["n"]}
        results[bid] = res
        insns_a = [(bytes.fromhex(i["bytes"]), i["text"]) for i in b["insns"]]
        fa = f"test_{bid}_a"
        tests.append(f"// {bid}: {b['project']} {b['source']} {b['function']}")
        tests.append(gen_test(fa, insns_a, b))
        funcs.append(fa)
        if args.originals:
            continue
        try:
            insns_b = assemble(bind_constants(props[bid]["rewrite"], b), b["level"], b["extras"])
        except IsaViolation as e:
            res["verdict"] = "isa violation"
            res["detail"] = str(e).splitlines()[-1][:200]
            funcs.pop()
            tests.pop(); tests.pop()
            continue
        except RuntimeError as e:
            res["verdict"] = "assembler error"
            res["detail"] = str(e).splitlines()[-1][:200]
            funcs.pop()
            tests.pop(); tests.pop()
            continue
        if not insns_b:
            res["verdict"] = "empty rewrite"
            funcs.pop()
            tests.pop(); tests.pop()
            continue
        res["n_b"] = len(insns_b)
        res["rewrite"] = [t for _, t in insns_b]
        fb = f"test_{bid}_b"
        tests.append(gen_test(fb, insns_b, b))
        funcs.append(fb)
    TESTS_SAIL.write_text("\n\n".join(tests) + "\n")
    print(f"=== {len(funcs)} test functions for {len(ids)} blocks -> {TESTS_SAIL}")
    if args.stage == "tests":
        return

    # 2. IR, in chunks (Sail's IR generation scales with the file size)
    chunks = [funcs[i:i + args.chunk] for i in range(0, len(funcs), args.chunk)]
    irs = {}
    print(f"=== Isla IR: {len(chunks)} chunk(s), {args.ir_jobs} in parallel")

    def build(ci):
        names = chunks[ci]
        # one Sail file per chunk holding just its functions
        body = [HELPERS]
        want = set(names)
        cur, keep = [], False
        for para in "\n\n".join(tests).split("\n\n"):
            m = re.search(r"^val (test_\w+) :", para, re.M)
            if m:
                keep = m.group(1) in want
            if keep and (m or para.startswith("//")):
                body.append(para)
        path = WORK / f"chunk{ci}.sail"
        text = "\n\n".join(body) + "\n"
        if not path.exists() or path.read_text() != text:
            path.write_text(text)      # keep the IR cache valid when unchanged
        ir_base = WORK / f"chunk{ci}"
        ir = Path(str(ir_base) + ".ir")
        if ir.exists() and ir.stat().st_mtime > path.stat().st_mtime and \
                ir.stat().st_mtime > max(p.stat().st_mtime for p in MODEL_DIR.glob("*.sail")):
            return ci, ir
        return ci, generate_ir(names, path, ir_base)

    with concurrent.futures.ThreadPoolExecutor(args.ir_jobs) as ex:
        for ci, ir in ex.map(build, range(len(chunks))):
            for f in chunks[ci]:
                irs[f] = ir
    if args.stage == "ir":
        return

    # 3. traces
    print(f"=== Isla traces ({args.jobs} parallel)")
    traces = {}

    def run(f):
        trace, how = run_isla(f, irs[f], trace_dir, args.isla_timeout)
        return f, trace, how

    t0 = time.time()
    with concurrent.futures.ThreadPoolExecutor(args.jobs) as ex:
        for n, (f, trace, how) in enumerate(ex.map(run, funcs), 1):
            traces[f] = trace
            if n % 100 == 0:
                print(f"    {n}/{len(funcs)} traces, {time.time() - t0:.0f}s")
    for bid, res in results.items():
        if "verdict" in res:
            continue
        for side in ("a", "b"):
            f = f"test_{bid}_{side}"
            if f not in traces:
                continue
            st, msg = trace_status(traces[f], trace_dir / f"{f}.err")
            res[f"trace_{side}"] = st
            if st != "ok":
                res[f"trace_{side}_error"] = msg
        if args.originals:
            res["verdict"] = "executable" if res.get("trace_a") == "ok" else "not executable"
        elif res.get("trace_a") != "ok":
            res["verdict"] = "original not executable"
        elif res.get("trace_b") != "ok":
            res["verdict"] = "rewrite not executable"
    if args.stage == "traces" or args.originals:
        summarize(results, args.out)
        return

    # 4. Z3
    print(f"=== Z3 ({args.jobs} parallel, {args.z3_timeout}s each)")

    def prove(bid):
        fa, fb = f"test_{bid}_a", f"test_{bid}_b"
        try:
            q = pc.build_query(str(traces[fa]), str(traces[fb]), bid)
        except Exception as e:  # noqa: BLE001
            return bid, "query error", str(e)[:200], 0, ""
        verdict, out, dt = pc.run_z3(q, smt_dir / f"{bid}.smt2", args.z3_timeout)
        (smt_dir / f"{bid}.out").write_text(out)
        cex = ""
        if verdict.startswith("sat"):
            cex = decode_counterexample(out, traces[fa])
        return bid, verdict, "", dt, cex

    todo = [bid for bid, r in results.items() if "verdict" not in r]
    with concurrent.futures.ThreadPoolExecutor(args.jobs) as ex:
        for bid, verdict, detail, dt, cex in ex.map(prove, todo):
            r = results[bid]
            r["verdict"] = verdict
            r["z3_seconds"] = round(dt, 1)
            if detail:
                r["detail"] = detail
            if cex:
                r["counterexample"] = cex
    summarize(results, args.out)


def summarize(results, out):
    Path(out).write_text(json.dumps(results, indent=1))
    from collections import Counter
    by = Counter()
    for r in results.values():
        by[(r["project"], r.get("verdict", "?"))] += 1
    print()
    for (proj, verdict), n in sorted(by.items()):
        print(f"  {proj:14s} {verdict:28s} {n}")
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
