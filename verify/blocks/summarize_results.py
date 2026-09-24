#!/usr/bin/env python3
"""Aggregate the block experiment into per-project tables.

Inputs (all in this directory unless given):
  blocks.json, sources.json          the population (extract_blocks.py)
  ORIGINALS ...                      --originals results (support checks;
                                     later files override earlier ones)
  proposals/*.json                   the LLM's proposals
  results/*.json                     check results (later waves override)

Usage: summarize_results.py --originals A.json [B.json ...] [--md out.md]
"""

import argparse
import collections
import glob
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent


def load_many(paths):
    out = {}
    for p in paths:
        out.update(json.loads(Path(p).read_text()))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--originals", nargs="+", required=True)
    ap.add_argument("--results", default=str(HERE / "results" / "w*.json"))
    ap.add_argument("--proposals", default=str(HERE / "proposals" / "batch-*.json"))
    ap.add_argument("--md", default=None)
    args = ap.parse_args()

    blocks = {b["id"]: b for b in json.loads((HERE / "blocks.json").read_text())}
    sources = json.loads((HERE / "sources.json").read_text())
    originals = load_many(args.originals)
    # several globs may be given, separated by spaces; later files override
    props = load_many([p for pat in args.proposals.split() for p in sorted(glob.glob(pat))])
    results = load_many([p for pat in args.results.split() for p in sorted(glob.glob(pat))])

    projects = list(sources.keys())
    T = {p: collections.Counter() for p in projects}
    for bid, b in blocks.items():
        p = b["project"]
        w = 1 + b["dups"]                      # occurrences in the corpus
        T[p]["blocks"] += 1
        T[p]["blocks_all"] += w
        T[p]["insns"] += b["n"] * w
        o = originals.get(bid, {}).get("verdict")
        if o == "executable":
            T[p]["executable"] += 1
        elif o is None:
            T[p]["unchecked"] += 1
        else:
            T[p]["not_executable"] += 1
        pr = props.get(bid)
        if o != "executable":
            continue                     # the LLM stage only counts checkable blocks
        if pr is None:
            T[p]["no_proposal_yet"] += 1
            continue
        if not pr.get("rewrite"):
            T[p]["llm_none"] += 1
            continue
        T[p]["proposed"] += 1
        r = results.get(bid)
        if r is None:
            T[p]["proposal_unchecked"] += 1
            continue
        v = r.get("verdict", "?")
        if v == "unsat" or v.startswith("unsat"):
            T[p]["proved"] += 1
            T[p]["proved_all"] += w
            T[p]["saved"] += (r["n_a"] - r["n_b"]) * w
            T[p]["saved_distinct"] += r["n_a"] - r["n_b"]
            T[p]["covered"] += r["n_a"] * w
            T[p]["covered_distinct"] += r["n_a"]
        elif v.startswith("sat"):
            T[p]["refuted"] += 1
        elif v == "isa violation":
            T[p]["isa_violation"] += 1
        elif v in ("assembler error", "empty rewrite"):
            T[p]["unassemblable"] += 1
        else:
            T[p]["unresolved"] += 1
            T[p]["unresolved:" + v] += 1

    cols = ["blocks", "blocks_all", "insns", "executable", "not_executable",
            "proposed", "llm_none", "proved", "proved_all", "saved", "covered",
            "refuted", "unresolved", "isa_violation", "unassemblable",
            "proposal_unchecked", "no_proposal_yet", "unchecked"]
    total = collections.Counter()
    for p in projects:
        total.update(T[p])
    lines = ["| project | files | lines | blocks (all) | instrs | executable | proposals | none | proved (all) | saved (all) | covered (all) | refuted | unresolved | ISA viol. | unassemblable | pending |",
             "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for p in projects + ["total"]:
        c = T[p] if p != "total" else total
        s = sources[p] if p != "total" else {"source_files": sum(v["source_files"] for v in sources.values()),
                                             "source_lines": sum(v["source_lines"] for v in sources.values())}
        lines.append(f"| {p} | {s['source_files']} | {s['source_lines']:,} | {c['blocks']:,} ({c['blocks_all']:,}) | {c['insns']:,} | "
                     f"{c['executable']:,} | {c['proposed']:,} | {c['llm_none']:,} | {c['proved']:,} ({c['proved_all']:,}) | "
                     f"{c['saved_distinct']:,} ({c['saved']:,}) | {c['covered_distinct']:,} ({c['covered']:,}) | {c['refuted']:,} | {c['unresolved']:,} | {c['isa_violation']:,} | "
                     f"{c['unassemblable']:,} | {c['proposal_unchecked'] + c['no_proposal_yet'] + c['unchecked']:,} |")
    unres = {k: v for k, v in total.items() if k.startswith("unresolved:")}
    text = "\n".join(lines) + "\n\nunresolved by kind: " + json.dumps(unres) + "\n"
    print(text)
    if args.md:
        Path(args.md).write_text(text)


if __name__ == "__main__":
    main()
