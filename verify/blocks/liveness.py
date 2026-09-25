"""Backward register liveness over a disassembled x86-64 function.

The analysis is conservative in the direction that matters for an
equivalence check: uses are over-approximated (an unknown instruction is
assumed to read every register it names, a call to read everything) and
definitions are under-approximated (only a write that replaces the whole
register kills it; partial writes keep the old value live).  A register
that is live at the end of a block therefore must hold the same value
after the rewrite; every other register may be clobbered.

Registers are named "g<i>" (GPR i), "v<i>" (vector register i), "k<i>"
(mask register i), and the five status flags "CF", "PF", "ZF", "SF", "OF".
"""

import re

GPR64 = ["rax", "rcx", "rdx", "rbx", "rsp", "rbp", "rsi", "rdi",
         "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15"]
GPR_ALIASES = {}
GPR_WIDTH = {}
for i, r in enumerate(GPR64):
    GPR_ALIASES[r] = i
    GPR_WIDTH[r] = 64
for i, r in enumerate(["eax", "ecx", "edx", "ebx", "esp", "ebp", "esi", "edi"]):
    GPR_ALIASES[r] = i
    GPR_WIDTH[r] = 32
for i in range(8, 16):
    for suf, w in (("d", 32), ("w", 16), ("b", 8)):
        GPR_ALIASES[f"r{i}{suf}"] = i
        GPR_WIDTH[f"r{i}{suf}"] = w
for i, r in enumerate(["ax", "cx", "dx", "bx", "sp", "bp", "si", "di"]):
    GPR_ALIASES[r] = i
    GPR_WIDTH[r] = 16
for i, r in enumerate(["al", "cl", "dl", "bl", "spl", "bpl", "sil", "dil"]):
    GPR_ALIASES[r] = i
    GPR_WIDTH[r] = 8
for i, r in enumerate(["ah", "ch", "dh", "bh"]):
    GPR_ALIASES[r] = i
    GPR_WIDTH[r] = 8

FLAGS = ["CF", "PF", "ZF", "SF", "OF"]
ALL_GPR = {f"g{i}" for i in range(16)}
ALL_VEC = {f"v{i}" for i in range(32)}
ALL_K = {f"k{i}" for i in range(8)}
ALL = ALL_GPR | ALL_VEC | ALL_K | set(FLAGS)
# At a return, every register is treated as live.  Hand-written assembly
# does not always follow the System V calling convention: FFmpeg's and
# dav1d's internal helpers (x86inc "call"ed routines) return their results
# in whichever vector registers the caller expects, so assuming that only
# rax, rdx and xmm0 survive a return would let a rewrite drop real work.
RET_LIVE = ALL

COND = {"o": ["OF"], "no": ["OF"], "b": ["CF"], "c": ["CF"], "nae": ["CF"],
        "ae": ["CF"], "nb": ["CF"], "nc": ["CF"], "e": ["ZF"], "z": ["ZF"],
        "ne": ["ZF"], "nz": ["ZF"], "be": ["CF", "ZF"], "na": ["CF", "ZF"],
        "a": ["CF", "ZF"], "nbe": ["CF", "ZF"], "s": ["SF"], "ns": ["SF"],
        "p": ["PF"], "pe": ["PF"], "np": ["PF"], "po": ["PF"],
        "l": ["SF", "OF"], "nge": ["SF", "OF"], "ge": ["SF", "OF"], "nl": ["SF", "OF"],
        "le": ["ZF", "SF", "OF"], "ng": ["ZF", "SF", "OF"], "g": ["ZF", "SF", "OF"],
        "nle": ["ZF", "SF", "OF"]}

REG_TOKEN = re.compile(r"\b(r[0-9]+[dwb]?|[re]?[abcd]x|[re]?[sd]i|[re]?[sb]p|[abcd][lh]|[sd]il|[sb]pl|"
                       r"[xyz]mm[0-9]+|k[0-7])\b")

# flags an instruction certainly writes
FLAG_DEFS = {
    **{m: set(FLAGS) for m in ("add", "sub", "adc", "sbb", "cmp", "neg", "and", "or",
                                "xor", "test", "popcnt", "ptest", "vptest", "vtestps",
                                "vtestpd", "comiss", "comisd", "ucomiss", "ucomisd",
                                "vcomiss", "vcomisd", "vucomiss", "vucomisd", "vcomish",
                                "vucomish", "sahf", "kortestb", "kortestw", "kortestd",
                                "kortestq", "ktestb", "ktestw", "ktestd", "ktestq",
                                "pcmpistri", "pcmpistrm", "pcmpestri", "pcmpestrm",
                                "vpcmpistri", "vpcmpistrm", "vpcmpestri", "vpcmpestrm")},
    "inc": {"PF", "ZF", "SF", "OF"}, "dec": {"PF", "ZF", "SF", "OF"},
    "imul": {"CF", "OF"}, "mul": {"CF", "OF"},
    "shl": {"CF", "PF", "ZF", "SF"}, "sal": {"CF", "PF", "ZF", "SF"},
    "shr": {"CF", "PF", "ZF", "SF"}, "sar": {"CF", "PF", "ZF", "SF"},
    "shld": {"CF", "PF", "ZF", "SF"}, "shrd": {"CF", "PF", "ZF", "SF"},
    "rol": {"CF"}, "ror": {"CF"}, "rcl": {"CF"}, "rcr": {"CF"},
    "bt": {"CF"}, "bts": {"CF"}, "btr": {"CF"}, "btc": {"CF"},
    "bsf": {"ZF"}, "bsr": {"ZF"}, "lzcnt": {"CF", "ZF"}, "tzcnt": {"CF", "ZF"},
    "andn": {"CF", "OF", "SF", "ZF"}, "bextr": {"CF", "OF", "ZF"},
    "bzhi": {"CF", "OF", "SF", "ZF"}, "blsi": {"CF", "SF", "ZF", "OF"},
    "blsmsk": {"CF", "SF", "ZF", "OF"}, "blsr": {"CF", "SF", "ZF", "OF"},
    "adcx": {"CF"}, "adox": {"OF"}, "cmc": {"CF"}, "stc": {"CF"}, "clc": {"CF"},
}
FLAG_USES = {"adc": {"CF"}, "sbb": {"CF"}, "rcl": {"CF"}, "rcr": {"CF"}, "adcx": {"CF"},
             "adox": {"OF"}, "cmc": {"CF"}, "into": {"OF"}, "loope": {"ZF"},
             "loopne": {"ZF"}, "loopz": {"ZF"}, "loopnz": {"ZF"},
             "lahf": set(FLAGS), "pushf": set(FLAGS), "pushfq": set(FLAGS)}

# instructions that write no register operand
NO_WRITE = {"cmp", "test", "bt", "ptest", "vptest", "vtestps", "vtestpd", "comiss",
            "comisd", "ucomiss", "ucomisd", "vcomiss", "vcomisd", "vucomiss",
            "vucomisd", "vcomish", "vucomish", "kortestb", "kortestw", "kortestd",
            "kortestq", "ktestb", "ktestw", "ktestd", "ktestq", "prefetcht0",
            "prefetcht1", "prefetcht2", "prefetchnta", "prefetchw", "clflush",
            "clflushopt", "clwb", "nop", "endbr64", "pause", "lfence", "mfence",
            "sfence", "vzeroupper", "vzeroall", "cld", "std", "clc", "stc", "cmc",
            "int3", "ud2", "hlt", "emms", "sahf"}
# legacy (non-VEX) instructions whose first operand is written without
# being read
LEGACY_DEST_ONLY = {"mov", "movabs", "movzx", "movsx", "movsxd", "lea", "movd", "movq",
                    "movdqa", "movdqu", "movaps", "movups", "movapd", "movupd", "lddqu",
                    "movntdqa", "pshufd", "pshufhw", "pshuflw", "pmovmskb", "movmskps",
                    "movmskpd", "pextrb", "pextrw", "pextrd", "pextrq", "extractps",
                    "pabsb", "pabsw", "pabsd", "phminposuw", "aeskeygenassist",
                    "aesimc", "lzcnt", "tzcnt", "popcnt", "andn", "bextr", "bzhi",
                    "pdep", "pext", "sarx", "shlx", "shrx", "rorx", "movbe", "cvtdq2ps",
                    "cvtdq2pd", "cvtps2dq", "cvttps2dq", "cvtps2pd", "cvtpd2ps",
                    "cvtpd2dq", "cvttpd2dq", "movshdup", "movsldup", "movddup",
                    "pmovzxbw", "pmovzxbd", "pmovzxbq", "pmovzxwd", "pmovzxwq",
                    "pmovzxdq", "pmovsxbw", "pmovsxbd", "pmovsxbq", "pmovsxwd",
                    "pmovsxwq", "pmovsxdq", "sqrtps", "sqrtpd", "rcpps", "rsqrtps",
                    "roundps", "roundpd", "kmovb", "kmovw", "kmovd", "kmovq", "knotb",
                    "knotw", "knotd", "knotq", "sete", "setne"}
# VEX/EVEX instructions whose destination is also an input
VEX_DEST_READ_PREFIXES = ("vfmadd", "vfmsub", "vfnmadd", "vfnmsub", "vfmaddsub",
                          "vfmsubadd", "vpternlog", "vpdpbusd", "vpdpwssd", "vpmadd52",
                          "vgather", "vpgather", "vpscatter", "vscatter", "vpinsr",
                          "vinsertps", "vpblendm", "vsqrtss", "vsqrtsd", "vrcpss",
                          "vrsqrtss", "vcvtsi2", "vcvtusi2", "vmovss", "vmovsd",
                          "vmovhps", "vmovlps", "vmovhpd", "vmovlpd", "vmovlhps",
                          "vmovhlps", "vpshufbitqmb", "vp2intersect", "vpcompress",
                          "vpexpand", "vcompress", "vexpand")
IMPLICIT_RAX = {"mul", "div", "idiv"}


def canon(reg):
    if reg in GPR_ALIASES:
        return f"g{GPR_ALIASES[reg]}"
    if reg.startswith(("xmm", "ymm", "zmm")):
        return f"v{int(reg[3:])}"
    return reg          # k0..k7


def split_operands(text):
    mn = text.split()[0] if text.split() else ""
    rest = text[len(mn):].strip()
    ops, depth, cur = [], 0, ""
    for c in rest:
        if c in "[{":
            depth += 1
        elif c in "]}":
            depth -= 1
        if c == "," and depth == 0:
            ops.append(cur.strip())
            cur = ""
        else:
            cur += c
    if cur.strip():
        ops.append(cur.strip())
    return mn, ops


def is_reg_operand(op):
    return re.fullmatch(r"(r[0-9]+[dwb]?|[re]?[abcd]x|[re]?[sd]i|[re]?[sb]p|[abcd][lh]|[sd]il|[sb]pl|"
                        r"[xyz]mm[0-9]+|k[0-7])", op.split("{")[0].strip()) is not None


def defuse(text, level):
    """(uses, defs) of one instruction; defs are full kills only."""
    mn, ops = split_operands(text)
    uses, defs = set(), set()
    for op in ops:
        if "[" in op:
            for m in REG_TOKEN.finditer(op):
                uses.add(canon(m.group(1)))
    m = re.match(r"^(j|set|cmov)([a-z]+)$", mn)
    if m and m.group(2) in COND:
        uses |= set(COND[m.group(2)])
        if m.group(1) == "j":
            return uses, defs
    uses |= FLAG_USES.get(mn, set())
    defs |= FLAG_DEFS.get(mn, set())
    if mn in IMPLICIT_RAX:
        uses |= {"g0"} | ({"g2"} if mn in ("div", "idiv") else set())
        defs |= {"g0", "g2"}
    if mn in ("cqo", "cdq", "cwd"):
        uses.add("g0")
        defs.add("g2")
    if mn in ("cbw", "cwde", "cdqe"):
        uses.add("g0")
    reg_ops = [(i, op) for i, op in enumerate(ops) if is_reg_operand(op)]
    if not reg_ops:
        return uses, defs
    if mn in NO_WRITE or mn.startswith(("j", "loop")) or mn == "ret":
        for _, op in reg_ops:
            uses.add(canon(op.split("{")[0].strip()))
        return uses, defs
    # first operand is the destination for everything else we model
    dest_i, dest_op = reg_ops[0]
    dest_raw = dest_op.split("{")[0].strip()
    dest = canon(dest_raw)
    merge_mask = "{k" in dest_op and "{z}" not in dest_op
    if "{k" in dest_op:
        km = re.search(r"\{(k[0-7])\}", dest_op)
        if km:
            uses.add(km.group(1))
    for _, op in reg_ops[1:]:
        uses.add(canon(op.split("{")[0].strip()))
        if "{k" in op:
            km = re.search(r"\{(k[0-7])\}", op)
            if km:
                uses.add(km.group(1))
    if dest_i != 0:
        # store or compare form: the register is a source
        uses.add(dest)
        return uses, defs
    # is the destination read?
    dest_read = True
    self_zero = mn in ("xor", "pxor", "xorps", "xorpd", "sub", "psubb", "psubw", "psubd",
                       "psubq", "pcmpgtb", "pcmpgtw", "pcmpgtd", "pcmpgtq", "pandn",
                       "andnps", "andnpd") and len(reg_ops) == 2 and len(ops) == 2 \
        and canon(reg_ops[1][1]) == dest
    vex_self_zero = mn in ("vpxor", "vpxord", "vpxorq", "vxorps", "vxorpd", "vpsubb",
                           "vpsubw", "vpsubd", "vpsubq", "vpcmpgtb", "vpcmpgtw",
                           "vpcmpgtd", "vpcmpgtq", "vpandn", "vpandnd", "vpandnq",
                           "vandnps", "vandnpd") and len(ops) == 3 and \
        all(is_reg_operand(o) for o in ops) and len({canon(o.strip()) for o in ops[1:]}) == 1
    if mn.startswith("v") and mn not in ("vzeroupper", "vzeroall"):
        dest_read = merge_mask or mn.startswith(VEX_DEST_READ_PREFIXES) or \
            (len(ops) == 2 and mn in ("vmovss", "vmovsd"))
        if vex_self_zero:
            dest_read = False
    elif mn in LEGACY_DEST_ONLY or self_zero:
        dest_read = False
    elif mn.startswith("set") or mn.startswith(("kmov", "kand", "kor", "kxor", "kxnor",
                                                "knot", "kshift", "kunpck", "kadd")):
        dest_read = False
    elif mn == "imul" and len(ops) == 3:
        dest_read = False
    elif mn in ("mulx",) and len(reg_ops) >= 2:
        dest_read = False
        defs.add(canon(reg_ops[1][1]))
        uses.add("g2")
    elif mn == "xchg":
        for _, op in reg_ops:
            uses.add(canon(op.split("{")[0].strip()))
            defs.add(canon(op.split("{")[0].strip()))
        return uses, defs
    if dest_read:
        uses.add(dest)
    # does the write replace the whole register?
    full = True
    if dest.startswith("g"):
        full = GPR_WIDTH.get(dest_raw, 64) >= 32
    elif dest.startswith("v"):
        if not mn.startswith("v") and level in ("avx", "avx2", "avx512"):
            full = False       # legacy SSE write keeps the upper lanes
        if merge_mask:
            full = False
    if mn in ("movss", "movsd", "movhps", "movlps", "movhpd", "movlpd", "movlhps",
              "movhlps", "cvtsi2ss", "cvtsi2sd", "cvtss2sd", "cvtsd2ss", "sqrtss",
              "sqrtsd", "rcpss", "rsqrtss", "roundss", "roundsd", "pinsrb", "pinsrw",
              "pinsrd", "pinsrq", "insertps", "pmovsxbw"):
        uses.add(dest)
        full = False
    if mn.startswith(("bsf", "bsr", "cmov", "set")):
        uses.add(dest)
        full = mn.startswith("cmov") and GPR_WIDTH.get(dest_raw, 64) >= 32
    if full:
        defs.add(dest)
    else:
        uses.add(dest)
    return uses, defs


def successors(insns, i, addr_index):
    text = insns[i]["text"]
    mn = text.split()[0] if text.split() else ""
    tgt = None
    m = re.search(r"\s([0-9a-f]+) <", text)
    if m:
        tgt = addr_index.get(int(m.group(1), 16))
    nxt = i + 1 if i + 1 < len(insns) else None
    if mn in ("ret", "retq", "hlt", "ud2") or text.startswith("repz ret"):
        return [], "ret"
    if mn.startswith("jmp"):
        if tgt is None:
            return [], "all"       # indirect or out of the function
        return [tgt], None
    if mn.startswith(("j", "loop")):
        if tgt is None:
            return ([nxt] if nxt is not None else []), "all"
        return [tgt] + ([nxt] if nxt is not None else []), None
    if mn.startswith("call"):
        return ([nxt] if nxt is not None else []), "call"
    return ([nxt] if nxt is not None else []), None


def analyze(insns, level):
    """live_out[i] for every instruction of one function."""
    addr_index = {ins["addr"]: i for i, ins in enumerate(insns)}
    n = len(insns)
    du = [defuse(ins["text"], level) for ins in insns]
    succ, extra = [], []
    for i in range(n):
        s, kind = successors(insns, i, addr_index)
        succ.append(s)
        extra.append(kind)
    live_in = [set() for _ in range(n)]
    live_out = [set() for _ in range(n)]
    changed = True
    while changed:
        changed = False
        for i in range(n - 1, -1, -1):
            out = set()
            for s in succ[i]:
                out |= live_in[s]
            if extra[i] == "ret":
                out |= RET_LIVE
            elif extra[i] == "all":
                out |= ALL
            elif extra[i] == "call":
                out |= ALL
            if i == n - 1 and not succ[i] and extra[i] is None:
                out |= ALL           # falls off the end of the symbol
            out.add("g4")            # the stack pointer is always live
            uses, defs = du[i]
            inn = uses | (out - defs)
            if out != live_out[i] or inn != live_in[i]:
                live_out[i], live_in[i] = out, inn
                changed = True
    return live_out
