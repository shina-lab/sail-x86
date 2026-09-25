#!/usr/bin/env python3
"""Recompute the support-check verdicts from existing traces (no Isla run).

Usage: recompute_originals.py <trace-dir> <out.json> [<trace-dir> <out.json>...]
A later directory overrides an earlier one for the same block id.
"""
import json, os, re, sys
blocks = {b["id"]: b for b in json.load(open(os.path.join(os.path.dirname(__file__), "blocks.json")))}
res = {}
for tdir in sys.argv[1:-1]:
    for f in os.listdir(tdir):
        if not f.endswith("_a.trace"):
            continue
        bid = f[5:-8]
        if bid not in blocks:
            continue
        p = os.path.join(tdir, f)
        txt = open(p, errors="replace").read() if os.path.getsize(p) else ""
        err = open(p[:-6] + ".err", errors="replace").read() if os.path.exists(p[:-6] + ".err") else ""
        n = txt.count("write-reg |Final result|")
        m = re.search(r'NoFunction\("(\w+)"', err + txt)
        t = re.search(r"Execution took: (\d+)ms", err)
        r = {"id": bid, "project": blocks[bid]["project"], "level": blocks[bid]["level"], "n_a": blocks[bid]["n"],
             "isla_ms": int(t.group(1)) if t else None}
        if n == 1 and "(_ poison)" not in txt:
            r["verdict"], r["trace_a"] = "executable", "ok"
        else:
            r["verdict"], r["trace_a"] = "not executable", "error"
            if m:
                fn = m.group(1)
                r["reason"] = "floating-point extern" if fn.startswith(("__f", "__int", "__uint")) else "extern " + fn
            elif "Timeout" in err or "Timeout" in txt or (t and int(t.group(1)) >= 60000):
                r["reason"] = "timeout"
            elif n > 1:
                r["reason"] = "model branches (%d paths)" % n
            elif n == 1:
                r["reason"] = "fault"
            elif "panicked" in err:
                r["reason"] = "isla panic"
            elif "SymbolicLength" in err or "SymbolicLength" in txt:
                r["reason"] = "isla symbolic length"
            else:
                r["reason"] = "other: " + (err.strip().splitlines() or ["?"])[-1][:80]
        res[bid] = r
json.dump(res, open(sys.argv[-1], "w"), indent=0)
import collections
print(dict(collections.Counter(v["verdict"] for v in res.values())))
print(collections.Counter(v.get("reason") for v in res.values() if v["verdict"] != "executable").most_common(10))
