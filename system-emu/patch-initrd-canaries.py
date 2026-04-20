#!/usr/bin/env python3
"""
Patch common x86-64 stack-canary FS:0x28 sequences to a fixed immediate.

This keeps initramfs userland deterministic even when we import a host-built
static busybox that was compiled with stack protector enabled.
"""

from __future__ import annotations

import pathlib
import sys

# 32-bit immediate; mov/sub/xor r64, imm32 sign-extend, so the runtime canary
# value is actually 0xFFFFFFFF87654321. That's fine — what matters is that
# the entry-load and the exit-check both use the same constant.
FIXED = bytes.fromhex("21436587")
NOP9 = bytes.fromhex("660f1f840000000000")

REPLACEMENTS = {
    # mov reg, fs:[0x28]  ->  mov reg, imm32 (sign-extended)
    bytes.fromhex("64488b042528000000"): bytes.fromhex("48c7c0") + FIXED + bytes.fromhex("9090"),
    bytes.fromhex("64488b142528000000"): bytes.fromhex("48c7c2") + FIXED + bytes.fromhex("9090"),
    bytes.fromhex("64488b3c2528000000"): bytes.fromhex("48c7c7") + FIXED + bytes.fromhex("9090"),
    # mov fs:[0x28], reg  ->  9-byte nop (drop store; FIXED is the canary)
    bytes.fromhex("644889042528000000"): NOP9,
    bytes.fromhex("644889142528000000"): NOP9,
    bytes.fromhex("6448893c2528000000"): NOP9,
    # sub reg, fs:[0x28]  ->  sub reg, imm32
    bytes.fromhex("64482b042528000000"): bytes.fromhex("482d") + FIXED + bytes.fromhex("909090"),
    bytes.fromhex("64482b142528000000"): bytes.fromhex("4881ea") + FIXED + bytes.fromhex("9090"),
    bytes.fromhex("64482b3c2528000000"): bytes.fromhex("4881ef") + FIXED + bytes.fromhex("9090"),
    # xor reg, fs:[0x28]  ->  xor reg, imm32 (modern GCC stack-check form)
    bytes.fromhex("644833042528000000"): bytes.fromhex("4835") + FIXED + bytes.fromhex("909090"),
    bytes.fromhex("644833142528000000"): bytes.fromhex("4881f2") + FIXED + bytes.fromhex("9090"),
    bytes.fromhex("6448333c2528000000"): bytes.fromhex("4881f7") + FIXED + bytes.fromhex("9090"),
}


def patch_file(path: pathlib.Path) -> int:
    data = path.read_bytes()
    patched = data
    replacements = 0
    for old, new in REPLACEMENTS.items():
      count = patched.count(old)
      if count:
        patched = patched.replace(old, new)
        replacements += count
    if patched != data:
        path.write_bytes(patched)
    return replacements


def main(argv: list[str]) -> int:
    total = 0
    for name in argv[1:]:
        total += patch_file(pathlib.Path(name))
    print(total)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
