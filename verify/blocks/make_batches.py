#!/usr/bin/env python3
"""Split the checkable blocks into batches for the LLM proposal stage.

Each batch is a JSON file (batches/batch-NNN.json) listing blocks with
everything the LLM needs: the instructions in Intel syntax, the ISA level
and extensions the rewrite may use, what the registers used in addresses
point to, the constants, and the registers and flags whose final values
must be preserved.  The LLM writes proposals/batch-NNN.json (see
INSTRUCTIONS.md).

Usage: make_batches.py [--executable originals_results.json] [--size 20]
"""

import argparse
import json
import struct
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent

GPR64 = ["rax", "rcx", "rdx", "rbx", "rsp", "rbp", "rsi", "rdi",
         "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15"]
LEVEL_TEXT = {
    "x86-64": "baseline x86-64 (no SSE3 or later, no AVX)",
    "sse2": "SSE2 (the x86-64 baseline; no SSE3 or later, no AVX)",
    "sse3": "SSE3 and below (no SSSE3 or later, no AVX)",
    "ssse3": "SSSE3 and below (no SSE4.1 or later, no AVX)",
    "sse4.1": "SSE4.1 and below (no SSE4.2, no AVX)",
    "sse4.2": "SSE4.2 and below (no AVX)",
    "avx": "AVX and below (VEX-encoded 128-bit and 256-bit floating-point; 256-bit integer instructions need AVX2 and are NOT allowed)",
    "avx2": "AVX2 and below (no AVX-512)",
    "avx512": "AVX-512 F/BW/DQ/VL/CD and below",
}
EXTRA_TEXT = {
    "aes": "AES-NI", "pclmul": "PCLMULQDQ", "sha": "SHA extensions", "bmi1": "BMI1",
    "bmi2": "BMI2", "adx": "ADX", "popcnt": "POPCNT", "lzcnt": "LZCNT", "fma": "FMA",
    "f16c": "F16C", "gfni": "GFNI", "vaes": "VAES", "vpclmulqdq": "VPCLMULQDQ",
    "movbe": "MOVBE", "icl": "AVX-512 VBMI/VBMI2/VNNI/BITALG/VPOPCNTDQ/IFMA, GFNI, VAES, VPCLMULQDQ",
}


def vec_name(i, level):
    return {"avx512": "zmm", "avx2": "ymm", "avx": "ymm"}.get(level, "xmm") + str(i)


def describe(block):
    lv = block["level"]
    d = {
        "id": block["id"],
        "project": block["project"],
        "source": block["source"],
        "function": block["function"],
        "isa_level": LEVEL_TEXT[lv],
        "extensions_also_allowed": [EXTRA_TEXT[e] for e in block["extras"] if e in EXTRA_TEXT],
        "instructions": [i["text"] for i in block["insns"]],
    }
    mem = block["mem"]
    notes = []
    if mem:
        for b, r in mem["regions"].items():
            notes.append(f"{GPR64[int(b)]} points to a buffer; the block accesses bytes "
                         f"{r['lo']}..{r['hi'] - 1} relative to it")
        for reg, v in mem["index_values"].items():
            notes.append(f"{GPR64[int(reg)]} is an index register (treat its value as unknown)")
        if len(mem["regions"]) > 1:
            notes.append("buffers reached through different base registers do not overlap")
    d["memory"] = notes
    consts = []
    for c in block["constants"]:
        raw = bytes.fromhex(c["hex"])
        entry = {"name": c["name"], "size": c["size"], "bytes_le_hex": c["hex"]}
        if c["size"] % 2 == 0:
            entry["as_u16"] = list(struct.unpack("<%dH" % (c["size"] // 2), raw))
        if c["size"] % 4 == 0:
            entry["as_u32"] = list(struct.unpack("<%dI" % (c["size"] // 4), raw))
        entry["as_u8"] = list(raw)
        consts.append(entry)
    d["constants"] = consts
    live = block["live_out"]
    must = [GPR64[i] for i in live["gpr"] if i != 4]
    must += [vec_name(i, lv) for i in live["vec"]]
    must += [f"k{i}" for i in live["k"]]
    d["must_preserve_final_values_of"] = must
    d["flags_that_must_match"] = live["flags"]
    d["note"] = ("Every register not listed above (and every flag not listed) may hold any "
                 "value after the rewrite.  rsp must not be touched.")
    if live["vec"] and lv in ("avx", "avx2"):
        d["note"] += "  Vector registers are compared as full 256-bit ymm values."
    elif live["vec"] and lv == "avx512":
        d["note"] += "  Vector registers are compared as full 512-bit zmm values."
    elif live["vec"]:
        d["note"] += "  Vector registers are compared as 128-bit xmm values."
    return d


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--blocks", default=str(SCRIPT_DIR / "blocks.json"))
    ap.add_argument("--executable", default=None,
                    help="results.json of an --originals run; keep only executable blocks")
    ap.add_argument("--size", type=int, default=20)
    ap.add_argument("--out", default=str(SCRIPT_DIR / "batches"))
    ap.add_argument("--append", action="store_true",
                    help="keep existing batches and add new ones for blocks not yet batched")
    args = ap.parse_args()
    blocks = json.loads(Path(args.blocks).read_text())
    if args.executable:
        res = json.loads(Path(args.executable).read_text())
        blocks = [b for b in blocks if res.get(b["id"], {}).get("verdict") == "executable"]
    blocks.sort(key=lambda b: (b["project"], b["source"], b["start"]))
    out = Path(args.out)
    out.mkdir(exist_ok=True)
    n = 0
    if args.append:
        done = set()
        for old in sorted(out.glob("batch-*.json")):
            done |= {d["id"] for d in json.loads(old.read_text())}
            n = max(n, int(old.stem.split("-")[1]) + 1)
        blocks = [b for b in blocks if b["id"] not in done]
    else:
        for old in out.glob("batch-*.json"):
            old.unlink()
    for i in range(0, len(blocks), args.size):
        batch = [describe(b) for b in blocks[i:i + args.size]]
        (out / f"batch-{n:03d}.json").write_text(json.dumps(batch, indent=1))
        n += 1
    print(f"{len(blocks)} blocks in {(len(blocks) + args.size - 1) // args.size} new batches under {out}")


if __name__ == "__main__":
    main()
