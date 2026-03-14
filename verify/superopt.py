#!/usr/bin/env python3
"""Automated formally-verified superoptimization pipeline.

Profiles a program, identifies hot basic blocks, sends assembly snippets to
an LLM for optimization, formally verifies each proposal using Isla symbolic
execution + Z3, and mechanically substitutes the proven-equivalent sequence
into the compiled assembly.

Pipeline architecture:
  1. Profile binary → find hot function
  2. Find which source file defines the hot function (via nm)
  3. Compile that source with -fbasic-block-sections=all → parse BBs
  4. perf annotate → rank BBs by hotness
  5. For each hot feasible BB: LLM optimize → Isla+Z3 verify
  6. Recompile source WITHOUT BB-sections → .s, patch, assemble
  7. Relink binary → correctness check → benchmark

Usage:
  superopt.py run --binary ./gzip --build-dir ~/gzip \\
                  --compile-flags "-DHAVE_CONFIG_H -I. -I./lib -O2" \\
                  --args -9c input.bin
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

# Force line-buffered stdout so progress appears in real-time
sys.stdout.reconfigure(line_buffering=True)


def elapsed(start):
    """Format elapsed time since start."""
    dt = time.time() - start
    if dt < 60:
        return f"{dt:.1f}s"
    return f"{int(dt)//60}m{int(dt)%60}s"

SCRIPT_DIR = Path(__file__).resolve().parent
SAIL_X86_DIR = SCRIPT_DIR.parent
MODEL_DIR = SAIL_X86_DIR / "model"

# External tool paths (configurable via environment)
ISLA_DIR = Path(os.environ.get("ISLA_DIR", Path.home() / "isla"))
SAIL_SRC = Path(os.environ.get("SAIL_SRC", Path.home() / "sail-github"))
ISLA_EXE = ISLA_DIR / "target/release/isla-execute-function"
ISLA_PLUGIN = ISLA_DIR / "isla-sail/_build/default/sail_plugin_isla.cmxs"
SAIL_EXE = SAIL_SRC / "_build/default/src/bin/sail.exe"
ISLA_CONFIG = SCRIPT_DIR / "x86_config_ours.toml"


# ---------------------------------------------------------------------------
# Stage 1: Profile
# ---------------------------------------------------------------------------

def profile(binary, args, workload_input=None):
    """Run perf record + perf report to identify the hottest function.

    Returns (perf_data_path, hotspots) where hotspots is a list of
    (percent, function_name) tuples sorted by hotness.
    """
    print("=== Stage 1: Profiling ===")
    perf_data = "/tmp/superopt_perf.data"

    cmd = ["perf", "record", "-g", "-o", perf_data, "--", binary] + args
    print(f"  Running: {' '.join(cmd)}")

    stdin_source = None
    if workload_input and os.path.exists(workload_input):
        stdin_source = open(workload_input, "rb")

    try:
        subprocess.run(cmd, stdin=stdin_source, capture_output=True, timeout=300)
    finally:
        if stdin_source:
            stdin_source.close()

    # Parse perf report
    result = subprocess.run(
        ["perf", "report", "-i", perf_data, "--stdio", "--no-children",
         "-g", "none", "-F", "overhead,sym"],
        capture_output=True, text=True
    )

    hotspots = []
    for line in result.stdout.splitlines():
        m = re.match(r'\s+(\d+\.\d+)%\s+\[.\]\s+(\S+)', line)
        if m:
            hotspots.append((float(m.group(1)), m.group(2)))

    hotspots.sort(key=lambda x: -x[0])

    print("  Top functions:")
    for pct, func in hotspots[:10]:
        print(f"    {pct:5.1f}%  {func}")

    return perf_data, hotspots


# ---------------------------------------------------------------------------
# Source file discovery
# ---------------------------------------------------------------------------

def find_source_for_function(function_name, build_dir, source_dirs=None):
    """Find which source file defines a function.

    Uses nm on .o files in build_dir to find which object defines the function,
    then looks for a .c file with the same stem.

    Args:
        function_name: the function to find
        build_dir: directory containing .o files
        source_dirs: additional directories to search for .c files (optional)

    Returns (source_path, object_path) or (None, None).
    """
    print(f"=== Find source for '{function_name}' ===")
    build_path = Path(build_dir)

    # Search all .o files for the function
    for obj_file in sorted(build_path.rglob("*.o")):
        result = subprocess.run(
            ["nm", "--defined-only", str(obj_file)],
            capture_output=True, text=True
        )
        for line in result.stdout.splitlines():
            parts = line.split()
            if len(parts) >= 3 and parts[2] == function_name:
                print(f"  Found in: {obj_file}")

                # Look for .c with same stem
                stem = obj_file.stem
                search_dirs = [build_path]
                if source_dirs:
                    search_dirs.extend(Path(d) for d in source_dirs)

                for d in search_dirs:
                    for ext in ('.c', '.cc', '.cpp'):
                        candidate = d / (stem + ext)
                        if candidate.exists():
                            print(f"  Source: {candidate}")
                            return str(candidate), str(obj_file)
                    # Also search subdirectories
                    for candidate in d.rglob(stem + '.c'):
                        print(f"  Source: {candidate}")
                        return str(candidate), str(obj_file)

                print(f"  WARNING: Found {function_name} in {obj_file} but no source file")
                return None, str(obj_file)

    print(f"  ERROR: Function '{function_name}' not found in any .o file")
    return None, None


# ---------------------------------------------------------------------------
# Basic block parsing
# ---------------------------------------------------------------------------

# x86 branch/jump mnemonics (AT&T syntax)
_BRANCH_MNEMONICS = {
    'jmp', 'je', 'jne', 'jz', 'jnz', 'jg', 'jge', 'jl', 'jle',
    'ja', 'jae', 'jb', 'jbe', 'js', 'jns', 'jo', 'jno', 'jp', 'jnp',
    'jmpq', 'retq', 'ret',
}


class BasicBlock:
    """A basic block parsed from -fbasic-block-sections=all output."""
    __slots__ = ('label', 'lines', 'branch_lines', 'function')

    def __init__(self, label, function=None):
        self.label = label
        self.function = function
        self.lines = []             # instruction lines (excluding branches)
        self.branch_lines = []      # terminating branch instructions

    def instruction_count(self):
        return len(self.lines)


def parse_basic_blocks(asm_file, function_name=None):
    """Parse basic blocks from a -fbasic-block-sections=all assembly file.

    If function_name is given, only return BBs belonging to that function.
    Returns a dict of label -> BasicBlock.
    """
    with open(asm_file) as f:
        text = f.read()

    blocks = {}
    current_bb = None
    current_func = None

    for line in text.splitlines():
        stripped = line.strip()

        # Function entry: "longest_match:" at column 0 (not a .part label)
        m = re.match(r'^(\w+):', line)
        if m and '.' not in m.group(1) and '__part' not in line:
            label = m.group(1)
            current_func = label
            current_bb = BasicBlock(label, function=current_func)
            blocks[label] = current_bb
            continue

        # BB part labels: "longest_match.__part.3:" at column 0
        m = re.match(r'^(\w+\.__part\.\d+):', line)
        if m:
            label = m.group(1)
            func = label.rsplit('.__part.', 1)[0]
            current_func = func
            current_bb = BasicBlock(label, function=func)
            blocks[label] = current_bb
            continue

        if not current_bb:
            continue
        if not stripped or stripped.startswith('.') or stripped.startswith('#'):
            continue
        if stripped.startswith('LBB_END') or stripped.startswith('.LBB_END'):
            continue
        if '# kill:' in stripped:
            continue

        parts = stripped.split(None, 1)
        if not parts:
            continue
        mnemonic = parts[0].rstrip(',')

        if mnemonic in _BRANCH_MNEMONICS:
            current_bb.branch_lines.append(stripped)
        else:
            current_bb.lines.append(stripped)

    if function_name:
        blocks = {l: bb for l, bb in blocks.items()
                  if bb.function == function_name}

    return blocks


# ---------------------------------------------------------------------------
# Instruction normalization
# ---------------------------------------------------------------------------

def _normalize_insn(line):
    """Normalize an instruction line for matching: strip whitespace and comments."""
    line = line.strip()
    idx = line.find('#')
    if idx >= 0:
        line = line[:idx].strip()
    idx = line.find('//')
    if idx >= 0:
        line = line[:idx].strip()
    return re.sub(r'\s+', ' ', line)


# Mnemonics where the trailing b/w/l/q is part of the name, not a size suffix
_KEEP_SUFFIX = {
    'movzbl', 'movzwl', 'movzbq', 'movzwq',
    'movslq', 'movsbl', 'movsbq', 'movswl', 'movswq',
    'cltq', 'cwtl', 'cbtw', 'cwtd', 'cltd', 'cqto',
    'retq', 'jmpq', 'callq', 'syscall', 'sysret',
    'rep', 'repz', 'repnz', 'shl', 'shr', 'sar', 'rol', 'ror',
    'mul', 'imul', 'idiv', 'div',
}


def _normalize_insn_fuzzy(line):
    """Normalize instruction for fuzzy matching (perf annotate vs clang -S).

    Strips operand-size suffixes (addl -> add) since perf and clang may differ.
    For branch instructions, strips the target (different label formats).
    """
    line = _normalize_insn(line)
    if not line:
        return line
    parts = line.split(' ', 1)
    mnemonic = parts[0]
    if mnemonic not in _KEEP_SUFFIX and len(mnemonic) > 1 and mnemonic[-1] in 'bwlq':
        mnemonic = mnemonic[:-1]
        parts[0] = mnemonic
    if mnemonic in _BRANCH_MNEMONICS or mnemonic.rstrip('bwlq') in _BRANCH_MNEMONICS:
        return parts[0]
    return ' '.join(parts)


# ---------------------------------------------------------------------------
# BB hotness annotation via perf annotate
# ---------------------------------------------------------------------------

def annotate_bb_hotness(perf_data, function_name, blocks):
    """Use perf annotate to assign hotness (% samples) to each basic block.

    Returns a dict of label -> total%.
    """
    print("=== Annotate BB hotness ===")

    result = subprocess.run(
        ["perf", "annotate", "-i", perf_data, "--stdio", "--no-source",
         "-l", "--symbol=" + function_name],
        capture_output=True, text=True
    )

    # Parse perf annotate: "   23.16 :   5643:   cmp    %r10b,(%rax,%rcx,1)"
    perf_insns = []
    for line in result.stdout.splitlines():
        m = re.match(r'\s+(\d+\.\d+)\s*:\s+[0-9a-f]+:\s+(.+)', line)
        if m:
            pct = float(m.group(1))
            insn = m.group(2).strip()
            perf_insns.append((pct, _normalize_insn_fuzzy(insn)))
        else:
            m = re.match(r'\s+:\s+[0-9a-f]+:\s+(.+)', line)
            if m:
                insn = m.group(1).strip()
                perf_insns.append((0.0, _normalize_insn_fuzzy(insn)))

    if not perf_insns:
        print("  WARNING: No instructions found in perf annotate output")
        return {label: 0.0 for label in blocks}

    bb_hotness = {}
    for label, bb in blocks.items():
        if not bb.lines:
            bb_hotness[label] = 0.0
            continue

        pattern = [_normalize_insn_fuzzy(insn) for insn in bb.lines]
        pattern = [p for p in pattern if p]
        if not pattern:
            bb_hotness[label] = 0.0
            continue

        best_pct = 0.0
        for start_idx in range(len(perf_insns)):
            if perf_insns[start_idx][1] == pattern[0]:
                pi = 0
                j = start_idx
                total = 0.0
                matched = True
                while pi < len(pattern) and j < len(perf_insns):
                    if not perf_insns[j][1]:
                        j += 1
                        continue
                    if perf_insns[j][1] == pattern[pi]:
                        total += perf_insns[j][0]
                        pi += 1
                        j += 1
                    else:
                        matched = False
                        break
                if matched and pi == len(pattern):
                    best_pct = max(best_pct, total)

        # Also add samples from branch instructions
        for branch in bb.branch_lines:
            norm_branch = _normalize_insn_fuzzy(branch)
            for pct, norm_insn in perf_insns:
                if norm_insn == norm_branch:
                    best_pct += pct
                    break

        bb_hotness[label] = best_pct

    print(f"  BB hotness (top 10):")
    for label, pct in sorted(bb_hotness.items(), key=lambda x: -x[1])[:10]:
        print(f"    {pct:5.1f}%  {label} ({blocks[label].instruction_count()} insns)")

    return bb_hotness


# ---------------------------------------------------------------------------
# LLM optimization proposals
# ---------------------------------------------------------------------------

def propose_optimizations(asm_snippet, output_regs=None):
    """Send an assembly snippet to Claude for optimization.

    Returns a list of proposal dicts.
    """
    import anthropic
    print("=== LLM optimization proposal ===")

    if output_regs is not None:
        out_names = ", ".join(f"%{GPR_NAMES[i]}" for i in sorted(output_regs))
        reg_constraint = f"""Only these registers are live outputs (read after this block):
  {out_names}
You must preserve the values in those registers exactly. Other registers
(not listed above) may be freely clobbered."""
    else:
        reg_constraint = """Every GPR (rax-r15) must have the exact same value after your
replacement as after the original."""

    prompt = f"""You are an expert x86-64 assembly optimizer.

Here is a hot basic block from a compiled C program (branch instruction at
the end has been removed). It uses AT&T syntax (src, dst).

```asm
{asm_snippet}
```

Propose a shorter or faster replacement. Requirements:
- {reg_constraint}
- Straight-line code only (no branches, no labels).
- AT&T syntax.
- You may use CMOV, BMI1/BMI2 (TZCNT, LZCNT, BLSI, BEXTR, PDEP, PEXT),
  POPCNT, and other modern x86-64 extensions.

Common pitfalls to avoid:
- LEA does not set flags, but ADD does. Don't replace ADD with LEA if the
  flags from ADD feed into a subsequent conditional branch.
- Writing a 32-bit register (e.g., movl %eax, %edx) zero-extends to 64 bits.
- MOVZBL zero-extends to 64 bits when dest is a 32-bit register.

Return ONLY a JSON array of proposals. Each proposal:
- "name": short identifier (alphanumeric + underscores only)
- "description": one-line description
- "optimized_asm": the replacement assembly as a single string (one instruction per line)

If you find no optimization, return `[]`.
"""

    client = anthropic.Anthropic()
    t0 = time.time()
    print("  Sending snippet to Claude API...")

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=8192,
        messages=[{"role": "user", "content": prompt}]
    )

    text = response.content[0].text

    # Extract JSON array — try code blocks first, then bracket matching
    proposals = None
    code_match = re.search(r'```(?:json)?\s*(\[[\s\S]*?\])\s*```', text)
    if code_match:
        try:
            proposals = json.loads(code_match.group(1))
        except json.JSONDecodeError:
            pass

    if proposals is None:
        start = text.find('[')
        if start >= 0:
            depth = 0
            for i in range(start, len(text)):
                if text[i] == '[':
                    depth += 1
                elif text[i] == ']':
                    depth -= 1
                    if depth == 0:
                        try:
                            proposals = json.loads(text[start:i+1])
                        except json.JSONDecodeError:
                            pass
                        break

    if proposals is None:
        print("  ERROR: No valid JSON found in response")
        print(f"  Response: {text[:500]}")
        return []

    print(f"  Received {len(proposals)} proposal(s) ({elapsed(t0)}):")
    for p in proposals:
        print(f"    - {p['name']}: {p['description']}")

    return proposals


# ---------------------------------------------------------------------------
# Assemble to machine code and pack into Sail hex literals
# ---------------------------------------------------------------------------

def assemble_to_bytes(asm_lines):
    """Assemble x86-64 instructions and return list of (bytes, mnemonic) tuples."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.s', delete=False) as f:
        f.write(".text\n.globl _start\n_start:\n")
        for line in asm_lines.strip().splitlines():
            line = line.strip()
            if line and not line.startswith('#') and not line.startswith('//'):
                f.write(f"  {line}\n")
        f.write("  ret\n")
        tmp_s = f.name

    tmp_o = tmp_s.replace('.s', '.o')
    try:
        subprocess.run(
            ["gcc", "-c", "-o", tmp_o, tmp_s],
            check=True, capture_output=True, text=True
        )

        result = subprocess.run(
            ["objdump", "-d", tmp_o],
            capture_output=True, text=True, check=True
        )

        instructions = []
        for line in result.stdout.splitlines():
            m = re.match(r'\s+[0-9a-f]+:\s+((?:[0-9a-f]{2} )+)\s+(.+)', line)
            if m:
                hex_bytes = bytes.fromhex(m.group(1).replace(' ', ''))
                mnemonic = m.group(2).strip()
                if mnemonic in ('ret', 'retq'):
                    continue
                instructions.append((hex_bytes, mnemonic))

        return instructions
    finally:
        os.unlink(tmp_s)
        if os.path.exists(tmp_o):
            os.unlink(tmp_o)


def pack_instructions_to_sail(instructions):
    """Pack assembled instructions into 120-bit Sail hex literals."""
    calls = []
    for byte_seq, mnemonic in instructions:
        if len(byte_seq) > 15:
            raise ValueError(f"Instruction too long ({len(byte_seq)} bytes): {mnemonic}")
        reversed_bytes = byte_seq[::-1]
        padded = b'\xf4' * (15 - len(reversed_bytes)) + reversed_bytes
        hex_str = "0x" + padded.hex().upper()
        calls.append((hex_str, mnemonic))
    return calls


# ---------------------------------------------------------------------------
# Sail test generation and Isla infrastructure
# ---------------------------------------------------------------------------

GPR_NAMES = ["rax", "rcx", "rdx", "rbx", "rsp", "rbp", "rsi", "rdi",
             "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15"]


def generate_fullstate_test(name, asm_text):
    """Generate a Sail test that executes instructions and returns all 16 GPRs."""
    instructions = assemble_to_bytes(asm_text)
    calls = pack_instructions_to_sail(instructions)

    func_name = f"test_{name}"

    lines = [
        f"// Full-state test: {name}",
        f"val {func_name} : unit -> bits(1024)",
        f"function {func_name}() = {{",
        f"  system_state = SysRunning;",
    ]
    for hex_lit, comment in calls:
        lines.append(f"  setup_and_exec({hex_lit});  // {comment}")
    lines.append(f"  read_gpr64(15) @ read_gpr64(14) @ read_gpr64(13) @ read_gpr64(12) @")
    lines.append(f"  read_gpr64(11) @ read_gpr64(10) @ read_gpr64(9) @ read_gpr64(8) @")
    lines.append(f"  read_gpr64(7) @ read_gpr64(6) @ read_gpr64(5) @ read_gpr64(4) @")
    lines.append(f"  read_gpr64(3) @ read_gpr64(2) @ read_gpr64(1) @ read_gpr64(0)")
    lines.append(f"}}")

    sail_code = "\n".join(lines)
    print(f"  Generated full-state test: {func_name} ({len(instructions)} instructions)")
    return sail_code, func_name


def _tokenize_sexp(s):
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


def _parse_sexp(tokens, pos=0):
    if tokens[pos] == '(':
        result = []
        pos += 1
        while tokens[pos] != ')':
            val, pos = _parse_sexp(tokens, pos)
            result.append(val)
        return result, pos + 1
    else:
        return tokens[pos], pos + 1


def _sexp_to_str(sexp):
    if isinstance(sexp, str):
        return sexp
    return '(' + ' '.join(_sexp_to_str(s) for s in sexp) + ')'


def check_trace_feasibility(trace_file):
    """Check that a trace has exactly one execution path."""
    trace_size = os.path.getsize(trace_file)
    if trace_size > 10_000_000:
        print(f"trace too large ({trace_size:,} bytes)")
        return False

    with open(trace_file) as tf:
        n_paths = sum(1 for l in tf if 'write-reg |Final result|' in l)
    if n_paths != 1:
        print(f"{n_paths} execution paths")
        return False

    return True


def infer_output_regs(trace_file):
    """Infer which GPRs are modified by analyzing the Isla trace.

    The trace's final result is a 1024-bit concatenation of 16 GPRs (r15..rax).
    A register is "modified" if its slot in the result is a define-const
    (computed expression) rather than a bare declare-const (initial symbolic value).

    Returns a list of GPR indices (0=rax, 1=rcx, ..., 15=r15) that are modified.
    """
    with open(trace_file) as f:
        text = f.read()

    # Find the final result definition: (define-const vN (concat ...))
    m = re.search(r'write-reg \|Final result\| nil (v\d+)', text)
    if not m:
        return list(range(16))  # Can't infer, assume all modified

    result_var = m.group(1)
    m = re.search(rf'define-const {result_var} \(concat (.+)\)', text)
    if not m:
        return list(range(16))

    # Extract the 16 variable names from the nested concat
    # Format: (concat v15 (concat v14 (concat v13 ... (concat v1 v0)...)))
    concat_body = m.group(1)
    gpr_vars = []
    remaining = concat_body
    while remaining:
        # Match "vN (concat " or "vN vM)...))"
        vm = re.match(r'(v\d+)\s+\(concat\s+(.+)', remaining)
        if vm:
            gpr_vars.append(vm.group(1))
            remaining = vm.group(2)
        else:
            # Last two: "vN vM" possibly with trailing parens
            vm = re.match(r'(v\d+)\s+(v\d+)', remaining)
            if vm:
                gpr_vars.append(vm.group(1))
                gpr_vars.append(vm.group(2))
            break

    if len(gpr_vars) != 16:
        return list(range(16))  # Can't parse, assume all

    # Check which are define-const (modified) vs declare-const (unchanged)
    modified = []
    for i, var in enumerate(gpr_vars):
        # Position 0 = r15, position 15 = rax
        gpr_idx = 15 - i
        # Check if this var is a define-const (computed) or declare-const (initial)
        if re.search(rf'\(define-const {var}\b', text):
            modified.append(gpr_idx)

    return modified


def build_equiv_query(trace_a_file, trace_b_file, name, output_regs=None):
    """Build Z3 equivalence query.

    If output_regs is given, compare only those GPR indices.
    Otherwise compare the full 1024-bit result.
    """
    sys.path.insert(0, str(SCRIPT_DIR))
    import prove_equiv

    lines_a, result_a, mappings_a = prove_equiv.extract_trace_smt(trace_a_file)
    lines_b, result_b, mappings_b = prove_equiv.extract_trace_smt(trace_b_file)

    if not result_a or not result_b:
        print("  ERROR: Missing result variable in trace", file=sys.stderr)
        return None

    input_rename = prove_equiv.build_input_rename(mappings_a, mappings_b)
    if input_rename:
        print(f"  Input rename: {len(input_rename)} variables remapped")

    lines_b_renamed, result_b_renamed = prove_equiv.rename_vars(
        lines_b, result_b, "b_", input_rename)

    if output_regs:
        desc = ", ".join(GPR_NAMES[i] for i in sorted(output_regs))
        print(f"  Comparing output registers: {desc}")
    else:
        desc = "all 16 GPRs"

    query_lines = [
        f"; Equivalence proof: {name}",
        f"; Comparing: {desc}",
        "(set-logic QF_BV)",
        "",
        "; Shared symbolic inputs",
    ]
    for line in lines_a:
        if line.startswith('(declare-const '):
            query_lines.append(line)
    query_lines.append("")

    query_lines.append("; === Original sequence ===")
    for line in lines_a:
        if line.startswith('(define-const '):
            query_lines.append(line)
    query_lines.append("")

    query_lines.append("; === Optimized sequence ===")
    for line in lines_b_renamed:
        query_lines.append(line)
    query_lines.append("")

    if output_regs and len(output_regs) < 16:
        # Selective comparison: extract 64-bit slices for modified registers
        # The 1024-bit value is r15 @ r14 @ ... @ r1 @ r0
        # Bit positions: GPR[i] occupies bits [i*64+63 : i*64]
        assertions = []
        for gpr_idx in sorted(output_regs):
            hi = gpr_idx * 64 + 63
            lo = gpr_idx * 64
            assertions.append(
                f"(assert (not (= ((_ extract {hi} {lo}) {result_a}) "
                f"((_ extract {hi} {lo}) {result_b_renamed}))))")
        # Any one register differing is enough to show non-equivalence
        # We want: NOT (all equal) = at least one differs
        # So use (or (not (= r_a r_b)) ...) wrapped in assert
        if len(assertions) == 1:
            query_lines.append(assertions[0])
        else:
            parts = []
            for gpr_idx in sorted(output_regs):
                hi = gpr_idx * 64 + 63
                lo = gpr_idx * 64
                parts.append(
                    f"(not (= ((_ extract {hi} {lo}) {result_a}) "
                    f"((_ extract {hi} {lo}) {result_b_renamed})))")
            query_lines.append(f"(assert (or {' '.join(parts)}))")
    else:
        query_lines.append(f"(assert (not (= {result_a} {result_b_renamed})))")

    query_lines.append("(check-sat)")

    query_lines = prove_equiv.convert_define_const_to_fun(query_lines)
    return "\n".join(query_lines)


def generate_ir(test_sail_file, test_func_names):
    """Generate Isla IR with the test functions spliced in."""
    print("=== Generate Isla IR ===")

    output_dir = SCRIPT_DIR / "ir"
    output_dir.mkdir(exist_ok=True)
    ir_file = output_dir / "sail_x86_equiv.ir"

    result = subprocess.run(
        ["grep", r"\.sail", str(MODEL_DIR / "x86.sail_project")],
        capture_output=True, text=True
    )
    sail_files = []
    for line in result.stdout.splitlines():
        cleaned = line.strip().rstrip(',').strip()
        if cleaned.endswith('.sail'):
            sail_files.append(cleaned)

    preserve_flags = []
    existing_funcs = [
        "isla_test_add_r64_imm32", "isla_test_mov_r64_imm64",
        "isla_test_shl_r64_imm8",
    ]
    for func in existing_funcs + test_func_names:
        preserve_flags.extend(["--isla-preserve", func])

    splice_files = [SCRIPT_DIR / "splice_ours.sail"]
    seen_paths = {sf.resolve() for sf in splice_files}
    for f in SCRIPT_DIR.glob("*_tests.sail"):
        if f.resolve() not in seen_paths:
            splice_files.append(f)
            seen_paths.add(f.resolve())
    new_test_path = Path(test_sail_file).resolve()
    if new_test_path not in seen_paths:
        splice_files.append(Path(test_sail_file))
        seen_paths.add(new_test_path)

    for f in splice_files:
        if f.name.endswith('_tests.sail'):
            with open(f) as fh:
                for line in fh:
                    m = re.match(r'val\s+(test_\w+)\s*:', line)
                    if m:
                        fname = m.group(1)
                        if fname not in test_func_names and fname not in existing_funcs:
                            preserve_flags.extend(["--isla-preserve", fname])

    env = os.environ.copy()
    opam_result = subprocess.run(
        ["opam", "env"], capture_output=True, text=True
    )
    for line in opam_result.stdout.splitlines():
        m = re.match(r"(\w+)='([^']*)'", line)
        if m:
            env[m.group(1)] = m.group(2)
    env["SAIL_DIR"] = str(SAIL_SRC)

    cmd = [
        str(SAIL_EXE), "--plugin", str(ISLA_PLUGIN), "--isla", "-D", "ISLA",
    ]
    for sf in splice_files:
        cmd.extend(["-splice", str(sf)])
    cmd.extend(preserve_flags)
    cmd.extend(["-o", str(output_dir / "sail_x86_equiv")])
    cmd.extend(sail_files)

    t0 = time.time()
    print(f"  Compiling Sail model with {len(test_func_names)} test functions...")
    print(f"  (this may take a few minutes)")

    result = subprocess.run(cmd, cwd=str(MODEL_DIR), env=env,
                           capture_output=True, text=True)
    if result.returncode != 0:
        print(f"  Sail compilation failed!")
        for line in result.stderr.splitlines():
            if not line.startswith("Warning") and "warnings have been suppressed" not in line:
                print(f"    {line}")
        result.check_returncode()

    size = ir_file.stat().st_size
    print(f"  Generated: {ir_file} ({size:,} bytes, {elapsed(t0)})")
    return str(ir_file)


def generate_trace(func_name, ir_file):
    """Run Isla symbolic execution to generate a trace."""
    trace_file = f"/tmp/trace_{func_name}.txt"

    if (os.path.exists(trace_file) and
            os.path.getmtime(trace_file) > os.path.getmtime(ir_file)):
        print(f"    {func_name}: cached")
        return trace_file

    t0 = time.time()
    print(f"    {func_name}: generating...", end="", flush=True)

    result = subprocess.run(
        [str(ISLA_EXE), func_name,
         "--arch", ir_file,
         "--config", str(ISLA_CONFIG),
         "--traces", "-s",
         "--simplify-registers",
         "--timeout", "600"],
        capture_output=True, text=True
    )

    with open(trace_file, 'w') as f:
        f.write(result.stdout)

    lines = len(result.stdout.splitlines())
    print(f" done ({lines} lines, {elapsed(t0)})")
    return trace_file


# ---------------------------------------------------------------------------
# Assembly substitution (pattern-match in normal assembly)
# ---------------------------------------------------------------------------

def substitute_normal_asm(asm_file, original_insns, optimized_asm, output_file):
    """Find and replace an instruction sequence in a normal .s file."""
    print("=== Substitute into normal assembly ===")

    with open(asm_file) as f:
        lines = f.readlines()

    pattern = [_normalize_insn(insn) for insn in original_insns]
    pattern = [p for p in pattern if p]
    if not pattern:
        print("  ERROR: Empty instruction pattern")
        return False

    print(f"  Looking for {len(pattern)}-instruction sequence:")
    for p in pattern:
        print(f"    {p}")

    match_start = None
    match_end = None
    for i in range(len(lines)):
        norm = _normalize_insn(lines[i])
        if norm == pattern[0]:
            matched = True
            j = i
            pi = 0
            while pi < len(pattern) and j < len(lines):
                norm_j = _normalize_insn(lines[j])
                if not norm_j or norm_j.startswith('.'):
                    j += 1
                    continue
                if norm_j != pattern[pi]:
                    matched = False
                    break
                pi += 1
                j += 1
            if matched and pi == len(pattern):
                match_start = i
                match_end = j
                break

    if match_start is None:
        print("  ERROR: Could not find instruction sequence in normal assembly")
        return False

    print(f"  Found match at lines {match_start + 1}-{match_end}")

    opt_lines = []
    for line in optimized_asm.strip().splitlines():
        opt_lines.append(f"\t{line.strip()}\n")

    lines[match_start:match_end] = opt_lines
    print(f"  Replaced {match_end - match_start} lines with {len(opt_lines)} optimized lines")

    with open(output_file, 'w') as f:
        f.writelines(lines)

    print(f"  Output: {output_file}")
    return True


# ---------------------------------------------------------------------------
# Rebuild and benchmark
# ---------------------------------------------------------------------------

def rebuild_binary(optimized_obj, build_dir, original_binary, output_binary):
    """Link the optimized .o against the other .o files to produce the binary."""
    print("=== Rebuild ===")

    # Find which symbols our optimized .o defines
    result = subprocess.run(
        ["nm", "--defined-only", str(optimized_obj)],
        capture_output=True, text=True
    )
    our_symbols = set()
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[1] == 'T':
            our_symbols.add(parts[2])

    # Collect all .o files except those that conflict
    other_objects = []
    for f in sorted(Path(build_dir).glob("*.o")):
        if f.resolve() == Path(optimized_obj).resolve():
            continue
        result = subprocess.run(
            ["nm", "--defined-only", str(f)],
            capture_output=True, text=True
        )
        f_symbols = set()
        for line in result.stdout.splitlines():
            parts = line.split()
            if len(parts) >= 3 and parts[1] == 'T':
                f_symbols.add(parts[2])

        if f_symbols & our_symbols:
            print(f"  Excluding {f.name} (conflicts: {f_symbols & our_symbols})")
            continue
        other_objects.append(str(f))

    for f in sorted(Path(build_dir).glob("*.a")):
        other_objects.append(str(f))
    for f in sorted(Path(build_dir).glob("lib/*.a")):
        other_objects.append(str(f))

    cmd = ["clang", "-O2", "-o", output_binary, str(optimized_obj)] + other_objects
    print(f"  Linking: {len(other_objects) + 1} object files")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"  Link error: {result.stderr[:500]}")
        result.check_returncode()
    print(f"  Output: {output_binary}")
    return output_binary


def benchmark(original_binary, optimized_binary, args, runs=10):
    """Run hyperfine to compare original and optimized binaries."""
    print("=== Benchmark ===")

    orig_cmd = f"{original_binary} {' '.join(args)} > /dev/null"
    opt_cmd = f"{optimized_binary} {' '.join(args)} > /dev/null"
    cmd = [
        "hyperfine", "--warmup", "2", "--runs", str(runs),
        "--export-json", "/tmp/superopt_bench.json",
        "--shell", "bash",
        orig_cmd, opt_cmd,
    ]
    print(f"  Running: hyperfine ({runs} runs)...")
    print(f"    A: {orig_cmd}")
    print(f"    B: {opt_cmd}")
    subprocess.run(cmd, check=True)

    with open("/tmp/superopt_bench.json") as f:
        data = json.load(f)

    results = data["results"]
    orig_mean = results[0]["mean"]
    opt_mean = results[1]["mean"]
    speedup = (1 - opt_mean / orig_mean) * 100

    print(f"\n  Original:  {orig_mean*1000:.1f} ms")
    print(f"  Optimized: {opt_mean*1000:.1f} ms")
    print(f"  Speedup:   {speedup:.1f}%")

    return orig_mean, opt_mean, speedup


def validate_correctness(original_binary, optimized_binary, args):
    """Verify both binaries produce identical output."""
    print("=== Correctness validation ===")

    def run_and_hash(binary):
        result = subprocess.run(
            [binary] + args,
            capture_output=True, timeout=300
        )
        import hashlib
        return hashlib.md5(result.stdout).hexdigest()

    orig_hash = run_and_hash(original_binary)
    opt_hash = run_and_hash(optimized_binary)

    if orig_hash == opt_hash:
        print(f"  Output identical (md5: {orig_hash})")
        return True
    else:
        print(f"  OUTPUT DIFFERS!")
        print(f"    Original:  {orig_hash}")
        print(f"    Optimized: {opt_hash}")
        return False


# ---------------------------------------------------------------------------
# Full pipeline
# ---------------------------------------------------------------------------

def run_pipeline(binary, args, compile_flags, build_dir,
                 function_name=None, workspace="/tmp/superopt_workspace"):
    """Run the full superoptimization pipeline."""
    os.makedirs(workspace, exist_ok=True)
    print(f"Workspace: {workspace}")
    print()

    # Stage 1: Profile
    perf_data, hotspots = profile(binary, args)
    if not hotspots:
        print("No hotspots found.")
        return

    if function_name is None:
        function_name = hotspots[0][1]
    print(f"\n  Target function: {function_name}\n")

    # Stage 2: Find which source file defines the function
    source_file, obj_file = find_source_for_function(function_name, build_dir)
    if source_file is None:
        print("Cannot find source file. Provide --source-dir if sources are elsewhere.")
        return
    print()

    # Stage 3: Compile that source with BB-sections (for analysis only)
    bb_asm_file = os.path.join(workspace, "bb_sections.s")
    cmd = (f"clang {compile_flags} -S -g0 -fbasic-block-sections=all "
           f"-o {bb_asm_file} {source_file}")
    print("=== Compile with BB-sections (for analysis) ===")
    print(f"  Running: {cmd}")
    subprocess.run(cmd, shell=True, check=True)
    print()

    # Parse BBs for the hot function
    print("=== Parse basic blocks ===")
    blocks = parse_basic_blocks(bb_asm_file, function_name)
    if not blocks:
        print(f"  ERROR: No basic blocks found for '{function_name}'")
        return
    total_insns = sum(bb.instruction_count() for bb in blocks.values())
    print(f"  Found {len(blocks)} basic blocks, {total_insns} instructions")
    print()

    # Sort by instruction count (largest BBs have most optimization potential)
    candidates = sorted(
        [(label, bb) for label, bb in blocks.items()
         if bb.instruction_count() >= 3],
        key=lambda x: -x[1].instruction_count())

    if not candidates:
        print("  No BBs with >= 3 instructions.")
        return

    print(f"  {len(candidates)} candidate BBs (sorted by instruction count):")
    for label, bb in candidates[:20]:
        print(f"    {label} ({bb.instruction_count()} insns)")
    print()

    # Stage 5: Generate Isla tests for all candidates, compile IR once
    print("=== Generate Isla tests for all candidates ===")
    all_sail_parts = []
    all_func_names = []
    candidate_info = []

    for ci, (label, bb) in enumerate(candidates):
        clean_asm = "\n".join(bb.lines)
        func_name_suffix = f"bb_{ci}"
        sail_code, func_name = generate_fullstate_test(func_name_suffix, clean_asm)
        all_sail_parts.append(sail_code)
        all_func_names.append(func_name)
        candidate_info.append((label, bb, func_name, clean_asm, sail_code))

    combined_sail = "\n\n".join(all_sail_parts)
    test_file = os.path.join(workspace, "all_orig_tests.sail")
    with open(test_file, 'w') as f:
        f.write(combined_sail)
    deployed = SCRIPT_DIR / "all_orig_tests.sail"
    shutil.copy2(test_file, deployed)

    print(f"  Generated {len(all_func_names)} test functions")

    ir_file = generate_ir(str(deployed), all_func_names)
    print()

    # Stage 6: Isla feasibility scan — collect all feasible BBs
    print("=== Isla feasibility scan ===")
    feasible = []

    for label, bb, func_name, bb_asm, bb_sail in candidate_info:
        print(f"  {label} ({bb.instruction_count()} insns): ", end="", flush=True)

        try:
            trace = generate_trace(func_name, ir_file)
        except Exception as e:
            print(f"trace failed ({e})")
            continue

        if not check_trace_feasibility(trace):
            continue

        output_regs = infer_output_regs(trace)
        out_names = ", ".join(GPR_NAMES[i] for i in sorted(output_regs))
        print(f"OK (outputs: {out_names})")
        feasible.append((label, bb, func_name, bb_asm, bb_sail, trace, output_regs))

    if not feasible:
        print("\n  No BB passed the Isla feasibility gate.")
        return

    print(f"\n  {len(feasible)} feasible BBs")
    print()

    # Stage 7: For each feasible BB, ask LLM for proposals, batch-compile
    # IR once per BB (all proposals + original), then verify each.
    verified_proposal = None
    verified_bb = None

    for label, bb, orig_func, clean_asm, orig_sail, orig_trace, output_regs in feasible:
        print(f"{'='*60}")
        print(f"Trying BB: {label} ({bb.instruction_count()} insns)")
        out_names = ", ".join(GPR_NAMES[i] for i in sorted(output_regs))
        print(f"  Output registers: {out_names}")
        print(f"{'='*60}\n")

        proposals = propose_optimizations(clean_asm, output_regs)
        if not proposals:
            print("  No proposals. Trying next BB.\n")
            continue

        # Generate test functions for all proposals at once
        proposal_tests = []  # (proposal, opt_func_name, opt_sail_code)
        for i, proposal in enumerate(proposals):
            opt_asm = proposal.get('optimized_asm', '')
            if not opt_asm:
                continue
            if isinstance(opt_asm, list):
                opt_asm = "\n".join(opt_asm)

            test_name = f"{label.replace('.', '_')}_{proposal['name']}"
            try:
                opt_sail, opt_func = generate_fullstate_test(
                    f"{test_name}_opt", opt_asm)
                proposal_tests.append((proposal, opt_func, opt_sail, test_name))
            except Exception as e:
                print(f"    {proposal['name']}: assembly error ({e})")

        if not proposal_tests:
            print("  No valid proposals. Trying next BB.\n")
            continue

        # Write combined Sail file with original + all proposal tests
        all_sail = [orig_sail]
        all_funcs = [orig_func]
        for _, opt_func, opt_sail, _ in proposal_tests:
            all_sail.append(opt_sail)
            all_funcs.append(opt_func)

        combined_sail = "\n\n".join(all_sail)
        tf = os.path.join(workspace, f"{label.replace('.', '_')}_tests.sail")
        with open(tf, 'w') as fh:
            fh.write(combined_sail)
        deployed_test = SCRIPT_DIR / f"{label.replace('.', '_')}_tests.sail"
        shutil.copy2(tf, deployed_test)

        # Single IR compilation for all proposals of this BB
        print()
        ir_file_v = generate_ir(str(deployed_test), all_funcs)
        print()

        # Generate original trace once
        orig_trace_new = generate_trace(orig_func, ir_file_v)

        # Verify each proposal
        for proposal, opt_func, opt_sail, test_name in proposal_tests:
            print(f"\n  Verifying: {proposal['name']}")
            print(f"    {proposal['description']}")

            try:
                opt_trace = generate_trace(opt_func, ir_file_v)

                if not check_trace_feasibility(opt_trace):
                    print(f"    SKIP: Optimized code not feasible")
                    continue

                print("    Z3 equivalence proof...")
                query = build_equiv_query(
                    orig_trace_new, opt_trace, test_name, output_regs)
                if not query:
                    print("    ERROR: Failed to build equivalence query")
                    continue

                out_file = os.path.join(workspace, f"equiv_{test_name}.smt2")
                sys.path.insert(0, str(SCRIPT_DIR))
                import prove_equiv
                z3_result = prove_equiv.run_z3(query, out_file)

                if z3_result == "unsat":
                    print(f"    PROVED EQUIVALENT (Z3: unsat)")
                    verified_proposal = proposal
                    verified_bb = (label, bb)
                    break
                elif z3_result == "sat":
                    print(f"    NOT EQUIVALENT (Z3: sat)")
                else:
                    print(f"    Z3 ERROR: {z3_result}")

            except Exception as e:
                print(f"    ERROR: {e}")
                import traceback
                traceback.print_exc()

        if verified_proposal:
            break
        print()

    if verified_proposal is None:
        print("\nNo proposals were verified across all BBs. Pipeline stops here.")
        return

    entry_label, entry_bb = verified_bb
    print(f"\n{'='*60}")
    print(f"Verified optimization for {entry_label}: {verified_proposal['name']}")
    print(f"{'='*60}\n")

    # Stage 8: Recompile source without BB-sections, substitute, rebuild
    opt_asm = verified_proposal['optimized_asm']
    if isinstance(opt_asm, list):
        opt_asm = "\n".join(opt_asm)

    normal_asm_file = os.path.join(workspace, "normal.s")
    cmd = f"clang {compile_flags} -S -g0 -o {normal_asm_file} {source_file}"
    print(f"=== Recompile without BB-sections ===")
    print(f"  Running: {cmd}")
    subprocess.run(cmd, shell=True, check=True)

    opt_asm_file = os.path.join(workspace, "optimized.s")
    success = substitute_normal_asm(
        normal_asm_file, entry_bb.lines, opt_asm, opt_asm_file)
    if not success:
        print("Substitution failed.")
        return
    print()

    # Assemble the optimized .s to .o
    opt_obj = os.path.join(workspace, "optimized.o")
    subprocess.run(
        ["clang", "-c", "-o", opt_obj, opt_asm_file],
        check=True, capture_output=True
    )
    print(f"  Assembled: {opt_obj}")

    # Link
    opt_binary = os.path.join(workspace, Path(binary).stem + "-opt")
    rebuild_binary(opt_obj, build_dir, binary, opt_binary)
    print()

    # Stage 9: Validate and benchmark
    valid = validate_correctness(binary, opt_binary, args)
    if not valid:
        print("CORRECTNESS CHECK FAILED")
        return
    print()

    benchmark(binary, opt_binary, args)

    print(f"\n{'='*60}")
    print("Pipeline complete!")
    print(f"  Original binary:  {binary}")
    print(f"  Optimized binary: {opt_binary}")
    print(f"  Verified: {verified_proposal['name']}")
    print(f"{'='*60}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Automated formally-verified superoptimization pipeline"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # profile
    p_profile = subparsers.add_parser("profile", help="Profile a program")
    p_profile.add_argument("--binary", required=True)
    p_profile.add_argument("--args", nargs=argparse.REMAINDER, default=[])

    # run (full pipeline)
    p_run = subparsers.add_parser("run", help="Run the full pipeline")
    p_run.add_argument("--binary", required=True, help="Binary to optimize")
    p_run.add_argument("--build-dir", required=True,
                       help="Build directory with .o files and sources")
    p_run.add_argument("--compile-flags", default="-O2",
                       help="Compiler flags for clang -S")
    p_run.add_argument("--function", default=None,
                       help="Function to optimize (default: hottest from profiling)")
    p_run.add_argument("--workspace", default="/tmp/superopt_workspace")
    p_run.add_argument("--args", nargs=argparse.REMAINDER, default=[])

    args = parser.parse_args()

    if args.command == "profile":
        profile(args.binary, args.args)

    elif args.command == "run":
        run_pipeline(
            binary=args.binary,
            args=args.args or [],
            compile_flags=args.compile_flags,
            build_dir=args.build_dir,
            function_name=args.function,
            workspace=args.workspace,
        )


if __name__ == "__main__":
    main()
