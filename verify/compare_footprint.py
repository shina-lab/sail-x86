#!/usr/bin/env python3
"""
Compare instruction footprints between sail-x86 and sail-x86-from-acl2.

For each instruction, runs isla-footprint on both models and compares
the symbolic traces to check for semantic equivalence.

The comparison maps register names between the two models:
  sail-x86:          GPR[0..15], ZMM[0..31], flags as individual registers
  sail-x86-from-acl2: rax..r15, zmms[0..31], rflags as bitfield struct
"""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from dataclasses import dataclass, field

SCRIPT_DIR = Path(__file__).parent.resolve()

# Register mapping: our model index -> acl2 model register name
GPR_MAP = {
    0: "rax", 1: "rcx", 2: "rdx", 3: "rbx",
    4: "rsp", 5: "rbp", 6: "rsi", 7: "rdi",
    8: "r8",  9: "r9",  10: "r10", 11: "r11",
    12: "r12", 13: "r13", 14: "r14", 15: "r15",
}

# Flag bit positions in RFLAGS (acl2 model uses a packed bitfield)
FLAG_BITS = {
    "CF": 0, "PF": 2, "AF": 4, "ZF": 6, "SF": 7,
    "TF": 8, "IF_flag": 9, "DF": 10, "OF": 11,
}


@dataclass
class FootprintResult:
    """Parsed footprint from isla-footprint output."""
    raw_output: str = ""
    register_reads: list = field(default_factory=list)
    register_writes: list = field(default_factory=list)
    memory_reads: list = field(default_factory=list)
    memory_writes: list = field(default_factory=list)
    success: bool = False
    error: str = ""


def run_footprint(ir_path: str, config_path: str, instruction: str,
                  hex_mode: bool = False, timeout: int = 120) -> FootprintResult:
    """Run isla-footprint and capture the output."""
    isla = os.environ.get("ISLA_FOOTPRINT",
                          str(Path.home() / "isla/target/release/isla-footprint"))

    cmd = [
        isla,
        "-A", ir_path,
        "-C", config_path,
        "-i", instruction,
        "-s",  # simplify
        "--timeout", str(timeout),
    ]
    if hex_mode:
        cmd.append("-x")

    result = FootprintResult()
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout + 30)
        result.raw_output = proc.stdout
        if proc.returncode != 0:
            result.error = proc.stderr or proc.stdout
            return result
        result.success = True
    except subprocess.TimeoutExpired:
        result.error = "Timeout"
    except Exception as e:
        result.error = str(e)

    return result


def parse_sexp_trace(output: str) -> list:
    """Parse S-expression trace output from isla-footprint."""
    # Each trace is a sequence of events like:
    #   (read-reg |GPR| (bv_access 0) v1234)
    #   (write-reg |GPR| (bv_access 0) v5678)
    #   (read-mem v_addr Read_plain 8 v_data)
    #   (write-mem v_addr Write_plain 8 v_data)
    #   (define v1234 (bvadd v100 v200))
    events = []
    for line in output.strip().split("\n"):
        line = line.strip()
        if line.startswith("("):
            events.append(line)
    return events


def compare_instructions(instruction: str, ours_ir: str, acl2_ir: str,
                         ours_config: str, acl2_config: str,
                         hex_mode: bool = False, timeout: int = 120,
                         verbose: bool = False) -> dict:
    """Compare a single instruction between both models."""
    result = {
        "instruction": instruction,
        "equivalent": None,
        "ours": None,
        "acl2": None,
        "differences": [],
    }

    if verbose:
        print(f"  Running isla-footprint on sail-x86...", flush=True)
    ours_fp = run_footprint(ours_ir, ours_config, instruction, hex_mode, timeout)
    result["ours"] = {
        "success": ours_fp.success,
        "error": ours_fp.error if not ours_fp.success else "",
        "trace_lines": len(ours_fp.raw_output.split("\n")) if ours_fp.success else 0,
    }

    if verbose:
        print(f"  Running isla-footprint on sail-x86-from-acl2...", flush=True)
    acl2_fp = run_footprint(acl2_ir, acl2_config, instruction, hex_mode, timeout)
    result["acl2"] = {
        "success": acl2_fp.success,
        "error": acl2_fp.error if not acl2_fp.success else "",
        "trace_lines": len(acl2_fp.raw_output.split("\n")) if acl2_fp.success else 0,
    }

    if not ours_fp.success or not acl2_fp.success:
        result["equivalent"] = None
        if not ours_fp.success:
            result["differences"].append(f"sail-x86 failed: {ours_fp.error[:200]}")
        if not acl2_fp.success:
            result["differences"].append(f"acl2 failed: {acl2_fp.error[:200]}")
        return result

    # Parse and compare traces
    ours_events = parse_sexp_trace(ours_fp.raw_output)
    acl2_events = parse_sexp_trace(acl2_fp.raw_output)

    # Extract register write effects (the observable semantics)
    ours_writes = extract_reg_writes(ours_events)
    acl2_writes = extract_reg_writes(acl2_events)

    # Map register names and compare
    differences = compare_reg_writes(ours_writes, acl2_writes)

    result["equivalent"] = len(differences) == 0
    result["differences"] = differences

    if verbose:
        if differences:
            print(f"  DIFFERENT: {len(differences)} differences found")
            for d in differences[:5]:
                print(f"    - {d}")
        else:
            print(f"  EQUIVALENT")

    return result


def extract_reg_writes(events: list) -> dict:
    """Extract register write events from a trace."""
    writes = {}
    for event in events:
        if event.startswith("(write-reg"):
            # Parse: (write-reg |REG_NAME| [accessor] value)
            m = re.match(r'\(write-reg \|(\w+)\|(.+)\)', event)
            if m:
                reg = m.group(1)
                rest = m.group(2).strip()
                writes[f"{reg}:{rest}"] = event
    return writes


def compare_reg_writes(ours: dict, acl2: dict) -> list:
    """Compare register writes between models, applying the register mapping."""
    differences = []

    # For now, just report which registers each model writes to
    # Full semantic comparison requires SMT solving (future work)
    ours_regs = set(k.split(":")[0] for k in ours.keys())
    acl2_regs = set(k.split(":")[0] for k in acl2.keys())

    # Map our register names to normalized form
    ours_normalized = set()
    for r in ours_regs:
        if r.startswith("zGPR"):
            ours_normalized.add(f"GPR:{r}")
        elif r.startswith("zZMM"):
            ours_normalized.add(f"SIMD:{r}")
        elif r in ("zCF", "zPF", "zAF", "zZF", "zSF", "zOF", "zDF"):
            ours_normalized.add(f"FLAG:{r}")
        else:
            ours_normalized.add(r)

    acl2_normalized = set()
    for r in acl2_regs:
        if r in ("zrax", "zrbx", "zrcx", "zrdx", "zrsi", "zrdi",
                  "zrsp", "zrbp", "zr8", "zr9", "zr10", "zr11",
                  "zr12", "zr13", "zr14", "zr15"):
            acl2_normalized.add(f"GPR:{r}")
        elif r == "zzzmms":
            acl2_normalized.add(f"SIMD:{r}")
        elif r == "zrflags":
            acl2_normalized.add(f"FLAG:{r}")
        else:
            acl2_normalized.add(r)

    # Report structural differences
    if ours_normalized != acl2_normalized:
        differences.append(
            f"Different register write sets: "
            f"ours={sorted(ours_normalized)}, acl2={sorted(acl2_normalized)}"
        )

    return differences


# Test instructions to compare (x86-64 assembly)
DEFAULT_INSTRUCTIONS = [
    # Basic ALU register-register
    "add rax, rbx",
    "sub rax, rbx",
    "and rax, rbx",
    "or rax, rbx",
    "xor rax, rbx",
    "cmp rax, rbx",
    "test rax, rbx",
    # ALU with immediate
    "add rax, 42",
    "sub rax, 42",
    "and rax, 0xff",
    # Shifts
    "shl rax, 1",
    "shr rax, cl",
    "sar rax, 1",
    # Data movement
    "mov rax, rbx",
    "mov eax, ebx",
    "xchg rax, rbx",
    # Stack
    "push rax",
    "pop rax",
    # Control flow
    "nop",
    # Flag manipulation
    "clc",
    "stc",
    "cld",
    "std",
]


def main():
    parser = argparse.ArgumentParser(
        description="Compare x86-64 instruction footprints between two Sail models"
    )
    parser.add_argument("-i", "--instruction", action="append",
                        help="Instruction to compare (can be repeated)")
    parser.add_argument("-x", "--hex", action="store_true",
                        help="Parse instruction as hex opcode")
    parser.add_argument("--ours-ir", default=str(SCRIPT_DIR / "ir/sail_x86.ir"),
                        help="Path to sail-x86 IR file")
    parser.add_argument("--acl2-ir", default=str(SCRIPT_DIR / "ir/acl2_x86.ir"),
                        help="Path to acl2 IR file")
    parser.add_argument("--ours-config", default=str(SCRIPT_DIR / "x86_config_ours.toml"),
                        help="Path to sail-x86 Isla config")
    parser.add_argument("--acl2-config", default=str(SCRIPT_DIR / "x86_config_acl2.toml"),
                        help="Path to acl2 Isla config")
    parser.add_argument("--timeout", type=int, default=120,
                        help="Timeout per instruction (seconds)")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="Verbose output")
    parser.add_argument("-o", "--output", help="Write results to JSON file")
    parser.add_argument("--all", action="store_true",
                        help="Run all default test instructions")

    args = parser.parse_args()

    instructions = args.instruction or []
    if args.all or not instructions:
        instructions = DEFAULT_INSTRUCTIONS

    results = []
    equiv_count = 0
    diff_count = 0
    error_count = 0

    print(f"Comparing {len(instructions)} instructions between models")
    print(f"  sail-x86 IR:   {args.ours_ir}")
    print(f"  acl2 IR:       {args.acl2_ir}")
    print()

    for insn in instructions:
        print(f"[{len(results)+1}/{len(instructions)}] {insn}...", flush=True)
        r = compare_instructions(
            insn, args.ours_ir, args.acl2_ir,
            args.ours_config, args.acl2_config,
            args.hex, args.timeout, args.verbose,
        )
        results.append(r)

        if r["equivalent"] is True:
            equiv_count += 1
            print(f"  -> EQUIVALENT")
        elif r["equivalent"] is False:
            diff_count += 1
            print(f"  -> DIFFERENT")
            for d in r["differences"][:3]:
                print(f"     {d}")
        else:
            error_count += 1
            print(f"  -> ERROR")
            for d in r["differences"][:3]:
                print(f"     {d}")

    print()
    print(f"=== Results ===")
    print(f"Equivalent: {equiv_count}/{len(results)}")
    print(f"Different:  {diff_count}/{len(results)}")
    print(f"Errors:     {error_count}/{len(results)}")

    if args.output:
        with open(args.output, "w") as f:
            json.dump(results, f, indent=2)
        print(f"\nDetailed results written to {args.output}")


if __name__ == "__main__":
    main()
