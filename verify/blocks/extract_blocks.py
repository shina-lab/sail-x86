#!/usr/bin/env python3
"""Extract straight-line instruction blocks from hand-written assembly.

The blocks are the population for the rewrite experiment: every maximal
run of consecutive instructions in a function that (a) contains no
control transfer, no branch target, no stack operation, no relocation
(RIP-relative constant or symbol reference), no string/atomic/system/x87
instruction, and (b) accesses memory only through one base register with
small displacements, so that the equivalence check can model the memory
as a 256-byte symbolic window.

Usage:
    extract_blocks.py [--min N] [--max N] [--out blocks.json]

The ISA level of a block is the level of the function it comes from,
taken from the function name suffix (FFmpeg, libvpx, Linux blake2s), or
from the file name (libjpeg-turbo, Linux crypto).  A rewrite may use
only instructions at or below that level.
"""

import argparse
import glob
import hashlib
import json
import os
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import constants  # noqa: E402
import liveness  # noqa: E402

HOME = Path.home()

# ---------------------------------------------------------------------------
# Corpora: (project, object files, how to find the ISA level)
# ---------------------------------------------------------------------------

# Builds that do not live in the source trees (dav1d, GMP, and the kernel's
# arch/x86/crypto objects assembled with the tree's include paths).
CORPORA_DIR = Path(os.environ.get("ASM_CORPORA", HOME / "asm-corpora"))


# The working trees of FFmpeg, libjpeg-turbo and Linux carry the rewrites
# of the earlier experiment as uncommitted changes, so the corpus is built
# from the committed sources: the three modified FFmpeg files were
# assembled into asm-corpora/ffmpeg-orig, libjpeg-turbo's HEAD into
# asm-corpora/libjpeg-turbo-orig, and every kernel .S of the three crypto
# directories at HEAD into asm-corpora/linux-orig.

def ffmpeg_objects():
    out = []
    for o in glob.glob(str(HOME / "ffmpeg/lib*/x86/*.o")):
        if Path(o[:-2] + ".asm").exists():
            rel = os.path.relpath(o, HOME / "ffmpeg")
            orig = CORPORA_DIR / "ffmpeg-orig" / rel
            out.append(str(orig) if orig.exists() else o)
    return sorted(out)


def libjpeg_objects():
    return sorted(glob.glob(str(CORPORA_DIR / "libjpeg-turbo-orig/build/simd/CMakeFiles/simd.dir/x86_64/*.asm.o")))


def linux_objects():
    return sorted(glob.glob(str(CORPORA_DIR / "linux-orig/*.o")))


def libvpx_objects():
    return sorted(glob.glob(str(HOME / "libvpx/**/*.asm.o"), recursive=True))


def dav1d_objects():
    return sorted(glob.glob(str(CORPORA_DIR / "dav1d/build/src/**/*.obj"), recursive=True))


def openssl_objects():
    return sorted(glob.glob(str(HOME / "openssl/crypto/**/libcrypto-lib-*-x86_64.o"), recursive=True))


def glibc_objects():
    out = []
    for d in ("string", "wcsmbs"):
        for o in glob.glob(str(HOME / "glibc/build" / d / "*.o")):
            base = os.path.basename(o)[:-2]
            if base.endswith("-rtm"):
                continue
            if not re.search(r"-(avx2|evex|evex512|avx512|sse2|sse4|ssse3)", base):
                continue
            if (HOME / "glibc/sysdeps/x86_64/multiarch" / (base + ".S")).exists():
                out.append(o)
    return sorted(out)


def gmp_objects():
    out = []
    for asm in glob.glob(str(CORPORA_DIR / "gmp-6.3.0/mpn/*.asm")):
        o = asm[:-4] + ".o"
        if Path(o).exists():
            out.append(o)
    return sorted(out)


# suffix -> (level, extras)
SUFFIX_LEVELS = {
    "sse": ("sse2", ()), "sse2": ("sse2", ()), "sse3": ("sse3", ()),
    "ssse3": ("ssse3", ()), "sse4": ("sse4.1", ()), "sse41": ("sse4.1", ()),
    "sse42": ("sse4.2", ()), "avx": ("avx", ()), "avx2": ("avx2", ()),
    "fma3": ("avx2", ("fma",)), "avx512": ("avx512", ()),
    "avx512icl": ("avx512", ("icl",)),
}
EXCLUDED_SUFFIXES = {"mmx", "mmxext", "3dnow", "3dnowext", "xop", "fma4", "c"}


def level_from_name(name):
    # nasm emits local labels as "function.label" symbols (dav1d); the
    # level is the enclosing function's.
    parts = name.split(".")[0].split("_")
    for p in reversed(parts):
        if p in SUFFIX_LEVELS:
            return SUFFIX_LEVELS[p]
        if p in EXCLUDED_SUFFIXES:
            return None
    return None


def level_from_file(path):
    base = os.path.basename(path)
    for key, lv in (("-evex", ("avx512", ())), ("-avx512", ("avx512", ())),
                    ("-avx2", ("avx2", ())), ("-avx", ("avx", ())),
                    ("-ssse3", ("ssse3", ())), ("-sse4", ("sse4.1", ())),
                    ("-sse2", ("sse2", ())), ("-ni", ("sse4.1", ("sha",))),
                    ("_avx2", ("avx2", ())), ("_avx", ("avx", ())),
                    ("_ssse3", ("ssse3", ())), ("_sse4", ("sse4.1", ())),
                    ("_sse2", ("sse2", ())), ("_mmx", None)):
        if key in base:
            return lv
    return None


LINUX_FILE_LEVELS = {
    # Linux crypto files whose level is not in the name.
    "aesni-intel_asm": ("sse4.1", ("aes", "pclmul")),
    "aes-gcm-aesni-x86_64": ("sse4.1", ("aes", "pclmul")),
    "aes-gcm-avx10-x86_64": ("avx512", ("vaes", "vpclmulqdq")),
    "aes-xts-avx-x86_64": ("avx512", ("vaes", "vpclmulqdq")),
    "aes-ctr-avx-x86_64": ("avx512", ("vaes",)),
    "aesni-intel_avx-x86_64": ("avx2", ("aes", "pclmul")),
    "ghash-clmulni-intel_asm": ("sse4.1", ("pclmul",)),
    "crc32-pclmul_asm": ("sse4.1", ("pclmul",)),
    "crc32c-3way": ("sse4.2", ()),
    "crc-pclmul-template": ("avx512", ("vpclmulqdq",)),
    "chacha-ssse3-x86_64": ("ssse3", ()),
    "chacha-avx2-x86_64": ("avx2", ()),
    "chacha-avx512vl-x86_64": ("avx512", ()),
    "poly1305-x86_64-cryptogams": ("avx2", ()),
    "sha1_ssse3_asm": ("ssse3", ()),
    "sha1_avx2_x86_64_asm": ("avx2", ("bmi2",)),
    "sha1_ni_asm": ("sse4.1", ("sha",)),
    "sha256-ssse3-asm": ("ssse3", ()),
    "sha256-avx-asm": ("avx", ()),
    "sha256-avx2-asm": ("avx2", ("bmi2",)),
    "sha256-ni-asm": ("sse4.1", ("sha",)),
    "sha512-ssse3-asm": ("ssse3", ()),
    "sha512-avx-asm": ("avx", ()),
    "sha512-avx2-asm": ("avx2", ("bmi2",)),
    "sm3-avx-asm_64": ("avx", ()),
    "sm4-aesni-avx-asm_64": ("avx", ("aes",)),
    "sm4-aesni-avx2-asm_64": ("avx2", ("aes",)),
    "blake2s-core": None,   # per function: _ssse3 / _avx512
    "curve25519-x86_64": ("x86-64", ("bmi2", "adx")),
    "nh-sse2-x86_64": ("sse2", ()),
    "nh-avx2-x86_64": ("avx2", ()),
    "polyval-clmulni_asm": ("sse4.1", ("pclmul",)),
    "aegis128-aesni-asm": ("sse4.1", ("aes",)),
    "aria-aesni-avx-asm_64": ("avx", ("aes",)),
    "aria-aesni-avx2-asm_64": ("avx2", ("aes",)),
    "aria-gfni-avx512-asm_64": ("avx512", ("gfni",)),
    "camellia-aesni-avx-asm_64": ("avx", ("aes",)),
    "camellia-aesni-avx2-asm_64": ("avx2", ("aes",)),
    "camellia-x86_64-asm_64": ("x86-64", ()),
    "serpent-avx-x86_64-asm_64": ("avx", ()),
    "serpent-avx2-asm_64": ("avx2", ()),
    "serpent-sse2-x86_64-asm_64": ("sse2", ()),
    "twofish-avx-x86_64-asm_64": ("avx", ()),
    "twofish-x86_64-asm_64": ("x86-64", ()),
    "twofish-x86_64-asm_64-3way": ("x86-64", ()),
    "blowfish-x86_64-asm_64": ("x86-64", ()),
    "cast5-avx-x86_64-asm_64": ("avx", ()),
    "cast6-avx-x86_64-asm_64": ("avx", ()),
    "des3_ede-asm_64": ("x86-64", ()),
}


LEVEL_RANK = {"x86-64": 0, "sse2": 1, "sse3": 2, "ssse3": 3, "sse4.1": 4,
              "sse4.2": 5, "avx": 6, "avx2": 7, "avx512": 8}

SSSE3_MN = {"pshufb", "palignr", "phaddw", "phaddd", "phaddsw", "phsubw", "phsubd",
            "phsubsw", "pmaddubsw", "pmulhrsw", "psignb", "psignw", "psignd",
            "pabsb", "pabsw", "pabsd"}
SSE3_MN = {"movddup", "movshdup", "movsldup", "lddqu", "addsubps", "addsubpd",
           "haddps", "haddpd", "hsubps", "hsubpd"}
SSE41_MN = {"pblendvb", "pblendw", "blendps", "blendpd", "blendvps", "blendvpd",
            "pmaxsb", "pmaxsd", "pmaxud", "pmaxuw", "pminsb", "pminsd", "pminud",
            "pminuw", "pmulld", "pmuldq", "pinsrb", "pinsrd", "pinsrq", "pextrb",
            "pextrd", "pextrq", "extractps", "insertps", "pmovzxbw", "pmovzxbd",
            "pmovzxbq", "pmovzxwd", "pmovzxwq", "pmovzxdq", "pmovsxbw", "pmovsxbd",
            "pmovsxbq", "pmovsxwd", "pmovsxwq", "pmovsxdq", "ptest", "roundps",
            "roundpd", "roundss", "roundsd", "dpps", "dppd", "mpsadbw",
            "phminposuw", "packusdw", "pcmpeqq", "movntdqa"}
SSE42_MN = {"pcmpgtq", "pcmpestri", "pcmpestrm", "pcmpistri", "pcmpistrm", "crc32"}
AVX2_YMM_MN = {"vperm2i128", "vinserti128", "vextracti128", "vbroadcasti128",
               "vbroadcastss", "vbroadcastsd", "vmovntdqa", "vpermd", "vpermq",
               "vpermps", "vpermpd", "vpsllvd", "vpsllvq", "vpsrlvd", "vpsrlvq",
               "vpsravd", "vgatherdps", "vgatherqps", "vgatherdpd", "vgatherqpd"}
ICL_MN = {"vpermb", "vpermi2b", "vpermt2b", "vpmultishiftqb", "vpshldw", "vpshldd",
          "vpshldq", "vpshrdw", "vpshrdd", "vpshrdq", "vpshldvw", "vpshldvd",
          "vpshldvq", "vpshrdvw", "vpshrdvd", "vpshrdvq", "vpcompressb",
          "vpcompressw", "vpexpandb", "vpexpandw", "vpdpbusd", "vpdpbusds",
          "vpdpwssd", "vpdpwssds", "vpopcntb", "vpopcntw", "vpopcntd", "vpopcntq",
          "vpshufbitqmb"}


def infer_level(insns):
    """The lowest ISA level whose assembler accepts every instruction, and
    the extension features used, from the mnemonics alone."""
    level, extras = "x86-64", set()

    def bump(l):
        nonlocal level
        if LEVEL_RANK[l] > LEVEL_RANK[level]:
            level = l

    for ins in insns:
        text = ins["text"]
        mn = mnemonic_of(text)
        has_x, has_y = "xmm" in text, "ymm" in text
        has_z = "zmm" in text or re.search(r"\bk[0-7]\b", text) is not None or "{" in text
        if mn.startswith("v") and mn not in ("vzeroupper", "vzeroall"):
            if has_z:
                bump("avx512")
            elif has_y and (mn.startswith("vp") or mn in AVX2_YMM_MN):
                bump("avx2")
            elif has_y or has_x:
                bump("avx")
            if mn.startswith(("vfmadd", "vfmsub", "vfnmadd", "vfnmsub")):
                extras.add("fma")
            if mn in ("vcvtph2ps", "vcvtps2ph"):
                extras.add("f16c")
            if mn.startswith("vaes") and (has_y or has_z):
                extras.add("vaes")
            if mn.startswith("vpclmul") and (has_y or has_z):
                extras.add("vpclmulqdq")
            if mn in ICL_MN:
                extras.add("icl")
        else:
            if mn in SSSE3_MN:
                bump("ssse3")
            elif mn in SSE3_MN:
                bump("sse3")
            elif mn in SSE41_MN:
                bump("sse4.1")
            elif mn in SSE42_MN:
                bump("sse4.2")
            elif has_x:
                bump("sse2")
        if mn.startswith(("aes", "vaes")):
            extras.add("aes")
        if mn.startswith(("pclmul", "vpclmul")):
            extras.add("pclmul")
        if mn.startswith(("sha1", "sha256")):
            extras.add("sha")
        if mn in ("rorx", "mulx", "shlx", "shrx", "sarx", "pdep", "pext", "bzhi"):
            extras.add("bmi2")
        if mn in ("andn", "bextr", "blsi", "blsmsk", "blsr", "tzcnt"):
            extras.add("bmi1")
        if mn in ("adcx", "adox"):
            extras.add("adx")
        if mn == "popcnt":
            extras.add("popcnt")
        if mn == "lzcnt":
            extras.add("lzcnt")
        if mn.startswith(("gf2p8", "vgf2p8")):
            extras.add("gfni")
        if mn == "movbe":
            extras.add("movbe")
    return level, extras


def level_for(project, path, func):
    """(level, extras, source) for a function, or None to skip it."""
    name, insns = func["name"], func["insns"]
    named = None
    if project in ("ffmpeg", "libvpx", "dav1d"):
        named = level_from_name(name)
        if named is None and project == "libvpx":
            named = level_from_file(path)
        if named is None:
            return None          # MMX/3DNow!/XOP or an unrecognized suffix
    elif project == "libjpeg-turbo":
        named = level_from_file(path)
        if named is None:
            return None
    elif project == "linux":
        base = os.path.basename(path)[:-2]
        named = LINUX_FILE_LEVELS.get(base) or level_from_name(name) or level_from_file(path)
    elif project == "openssl":
        named = level_from_name(name)
    elif project == "glibc":
        named = level_from_file(path)
    inf_level, inf_extras = infer_level(insns)
    if named is None:
        level, extras, source = inf_level, set(), "inferred"
    else:
        level, extras, source = named[0], set(named[1]), "name"
        if LEVEL_RANK[inf_level] > LEVEL_RANK[level]:
            level, source = inf_level, "name+inferred"
    extras |= inf_extras
    return level, tuple(sorted(extras)), source


def source_file(project, path):
    """The assembly source an object was built from."""
    base = os.path.basename(path)
    if project == "ffmpeg":
        return path[:-2] + ".asm"
    if project == "libjpeg-turbo":
        return str(CORPORA_DIR / "libjpeg-turbo-orig/simd/x86_64" / base[:-2])   # foo.asm.o -> foo.asm
    if project == "linux":
        return str(CORPORA_DIR / "linux-orig/src" / (base[:-2] + ".S"))
    if project == "dav1d":
        return str(CORPORA_DIR / "dav1d/src/x86" / (base[:-4] + ".asm"))
    if project == "openssl":
        m = re.match(r"libcrypto-lib-(.*)\.o$", base)
        return os.path.join(os.path.dirname(path), m.group(1) + ".s")
    if project == "glibc":
        return str(HOME / "glibc/sysdeps/x86_64/multiarch" / (base[:-2] + ".S"))
    if project == "gmp":
        return os.path.realpath(path[:-2] + ".asm")
    return None


# ---------------------------------------------------------------------------
# Instruction classification
# ---------------------------------------------------------------------------

TERMINATORS = re.compile(
    r"^(j[a-z]+|call[a-z]*|ret[a-z]*|repz ret|loop[a-z]*|hlt|int[0-9a-z]*|ud[0-9]|"
    r"syscall|sysret[a-z]*|iret[a-z]*|leave|enter|push[a-z]*|pop[a-z]*|"
    r"pushf[a-z]*|popf[a-z]*|nop[a-z]*|endbr64|xchg|cpuid|rdtsc[a-z]*|"
    r"lock|rep[a-z]*|movs[bwdq]|stos[bwdq]|lods[bwdq]|scas[bwdq]|cmps[bwdq]|"
    r"cld|std|cli|sti|cmpxchg[a-z0-9]*|xadd|prefetch[a-z0-9]*|clflush[a-z]*|"
    r"[sml]fence|pause|ldmxcsr|stmxcsr|vldmxcsr|vstmxcsr|fxsave[a-z0-9]*|fxrstor[a-z0-9]*|"
    r"xsave[a-z0-9]*|xrstor[a-z0-9]*|rdrand|rdseed|f[a-z0-9]+|emms|"
    r"vzeroall|data16|cs|ds|es|ss|fs|gs|bnd|notrack|rex[a-z.]*|"
    r"\(bad\)|\.byte|addr32|wait|fwait|in[sbwdl]*|out[sbwdl]*|"
    r"lgdt|lidt|sgdt|sidt|lldt|ltr|str|clts|invlpg|wbinvd|invd|"
    r"rdmsr|wrmsr|rdpmc|swapgs|stac|clac|verr|verw|lar|lsl|arpl|"
    r"cmov[a-z]+)$")
# cmovcc is excluded because it reads flags produced earlier: a block that
# starts after a cmp would leave the condition undetermined.

FLAG_READERS = re.compile(r"^(j[a-z]+|cmov[a-z]+|set[a-z]+|adc[a-z]*|sbb[a-z]*|cmc|rcl|rcr|"
                          r"loop[a-z]*|pushf[a-z]*|sahf|lahf|adcx|adox|into|salc|daa|das|aaa|aas)$")

JCC_FLAGS = {
    "jo": "OF", "jno": "OF", "jb": "CF", "jc": "CF", "jnae": "CF", "jae": "CF",
    "jnb": "CF", "jnc": "CF", "je": "ZF", "jz": "ZF", "jne": "ZF", "jnz": "ZF",
    "jbe": "CF,ZF", "jna": "CF,ZF", "ja": "CF,ZF", "jnbe": "CF,ZF",
    "js": "SF", "jns": "SF", "jp": "PF", "jpe": "PF", "jnp": "PF", "jpo": "PF",
    "jl": "SF,OF", "jnge": "SF,OF", "jge": "SF,OF", "jnl": "SF,OF",
    "jle": "ZF,SF,OF", "jng": "ZF,SF,OF", "jg": "ZF,SF,OF", "jnle": "ZF,SF,OF",
    "jrcxz": "", "jecxz": "", "jmp": "", "jmpq": "",
}

GPR64 = ["rax", "rcx", "rdx", "rbx", "rsp", "rbp", "rsi", "rdi",
         "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15"]
GPR_ALIASES = {}
for i, r in enumerate(GPR64):
    GPR_ALIASES[r] = i
for i, r in enumerate(["eax", "ecx", "edx", "ebx", "esp", "ebp", "esi", "edi"]):
    GPR_ALIASES[r] = i
for i in range(8, 16):
    GPR_ALIASES[f"r{i}d"] = i
    GPR_ALIASES[f"r{i}w"] = i
    GPR_ALIASES[f"r{i}b"] = i
for i, r in enumerate(["ax", "cx", "dx", "bx", "sp", "bp", "si", "di"]):
    GPR_ALIASES[r] = i
for i, r in enumerate(["al", "cl", "dl", "bl", "spl", "bpl", "sil", "dil"]):
    GPR_ALIASES[r] = i
for i, r in enumerate(["ah", "ch", "dh", "bh"]):
    GPR_ALIASES[r] = i

PTR_SIZES = {"BYTE": 1, "WORD": 2, "DWORD": 4, "QWORD": 8, "TBYTE": 10,
             "XMMWORD": 16, "YMMWORD": 32, "ZMMWORD": 64, "OWORD": 16}

MEM_RE = re.compile(r"(?:(\w+) PTR )?\[([^\]]+)\]")
MMX_REG = re.compile(r"\bmm[0-7]\b")
DISP_RE = re.compile(r"^(0x[0-9a-f]+|\d+)$")


def parse_mem(text):
    """Every memory operand of the text as a dict with base, index, scale,
    disp, size and kind ('ok', 'rip', 'abs', 'seg', 'stack')."""
    out = []
    if re.search(r"\b[cdefgs]s:", text):
        out.append({"kind": "seg"})
    for m in MEM_RE.finditer(text):
        size = PTR_SIZES.get(m.group(1) or "", 0)
        inner = m.group(2)
        if "rip" in inner:
            out.append({"kind": "rip", "size": size})
            continue
        mm = re.fullmatch(r"(\w+)(?:\+(\w+)\*([1248]))?(?:([+-])(0x[0-9a-f]+|\d+))?", inner)
        if not mm or mm.group(1) not in GPR64 or (mm.group(2) and mm.group(2) not in GPR64):
            out.append({"kind": "abs", "size": size})
            continue
        base, index = mm.group(1), mm.group(2)
        disp = int(mm.group(5), 0) if mm.group(5) else 0
        if mm.group(4) == "-":
            disp = -disp
        kind = "stack" if "rsp" in (base, index) else "ok"
        out.append({"kind": kind, "base": GPR64.index(base),
                    "index": GPR64.index(index) if index else None,
                    "scale": int(mm.group(3)) if index else 0,
                    "disp": disp, "size": max(size, 1)})
    return out


def mnemonic_of(text):
    t = text.split()
    if not t:
        return ""
    return t[0]


# ---------------------------------------------------------------------------
# Disassembly
# ---------------------------------------------------------------------------

INSN_RE = re.compile(r"^\s*([0-9a-f]+):\t((?:[0-9a-f]{2} )+)\s*\t(.*)$")
FUNC_RE = re.compile(r"^([0-9a-f]+) <([^>]+)>:$")
RELOC_RE = re.compile(r"^\s+([0-9a-f]+): (R_X86_64_\w+)\t(.*)$")


def disassemble(path):
    r = subprocess.run(["objdump", "-d", "-r", "--insn-width=15", "-M", "intel",
                        "--no-show-raw-insn", path],
                       capture_output=True, text=True, check=True)
    # --no-show-raw-insn drops the bytes; run again with bytes for the map.
    r2 = subprocess.run(["objdump", "-d", "--insn-width=15", path],
                        capture_output=True, text=True, check=True)
    byte_map = {}
    for line in r2.stdout.splitlines():
        m = re.match(r"^\s*([0-9a-f]+):\t((?:[0-9a-f]{2} )+)", line)
        if m:
            byte_map[int(m.group(1), 16)] = bytes.fromhex(m.group(2).replace(" ", ""))
    funcs = []
    cur = None
    last = None
    for line in r.stdout.splitlines():
        m = FUNC_RE.match(line)
        if m:
            cur = {"name": m.group(2), "addr": int(m.group(1), 16), "insns": []}
            funcs.append(cur)
            continue
        if cur is None:
            continue
        m = RELOC_RE.match(line)
        if m and last is not None:
            last["relocs"].append((int(m.group(1), 16), m.group(2) + " " + m.group(3)))
            continue
        m = re.match(r"^\s*([0-9a-f]+):\t(.*)$", line)
        if m:
            addr = int(m.group(1), 16)
            text = m.group(2).strip()
            if addr not in byte_map:
                continue
            last = {"addr": addr, "bytes": byte_map[addr], "text": text, "relocs": []}
            cur["insns"].append(last)
    return funcs


def branch_targets(func):
    targets = set()
    for ins in func["insns"]:
        mn = mnemonic_of(ins["text"])
        if re.match(r"^(j[a-z]+|loop[a-z]*|call[a-z]*)$", mn):
            m = re.search(r"\s([0-9a-f]+) <", ins["text"])
            if m:
                targets.add(int(m.group(1), 16))
    return targets


# ---------------------------------------------------------------------------
# Blocks
# ---------------------------------------------------------------------------

REG_TOKEN = re.compile(r"\b(r[0-9]+[dwb]?|[re]?[abcd]x|[re]?[sd]i|[re]?[sb]p|[abcd][lh]|[sd]il|[sb]pl|"
                       r"[xyz]mm[0-9]+|k[0-7])\b")


def normalize(insns):
    """Canonical text with registers renamed by order of appearance."""
    names = {}

    def sub(m):
        r = m.group(1)
        base = GPR_ALIASES.get(r)
        if base is not None:
            key = ("g", base)
            cls = "G"
        elif r.startswith(("xmm", "ymm", "zmm")):
            key = ("v", int(r[3:]))
            cls = r[0].upper() + "MM"
        else:
            key = ("k", r)
            cls = "K"
        if key not in names:
            names[key] = len([k for k in names if k[0] == key[0]])
        # keep the sub-register width visible
        if base is not None:
            width = {"r": "64", "e": "32"}.get(r[0], "")
            if r in ("ax", "bx", "cx", "dx", "si", "di", "bp", "sp") or r.endswith("w"):
                width = "16"
            if r in ("al", "bl", "cl", "dl", "sil", "dil", "bpl", "spl") or r.endswith("b"):
                width = "8"
            if r in ("ah", "bh", "ch", "dh"):
                width = "8h"
            if r.startswith("r") and r[1:].isdigit():
                width = "64"
            if r.startswith("r") and r.endswith("d") and r[1:-1].isdigit():
                width = "32"
            return f"{cls}{names[key]}.{width}"
        return f"{cls}{names[key]}"

    return "\n".join(REG_TOKEN.sub(sub, i["text"]) for i in insns)


NO_DEST_MN = {"cmp", "test", "bt", "ucomiss", "ucomisd", "comiss", "comisd", "ptest",
              "vptest", "vucomiss", "vucomisd", "vcomiss", "vcomisd", "vtestps", "vtestpd"}


def written_gprs(text):
    """GPRs an instruction writes (Intel syntax: first operand, plus the
    implicit accumulator forms)."""
    mn = mnemonic_of(text)
    parts = [p.strip() for p in text[len(mn):].strip().split(",")] if len(text) > len(mn) else []
    written = set()
    if mn in NO_DEST_MN or not parts:
        return written
    if parts[0] in GPR_ALIASES:
        written.add(GPR_ALIASES[parts[0]])
    if mn in ("mul", "div", "idiv") or (mn == "imul" and len(parts) == 1):
        written |= {0, 2}
    if mn in ("cqo", "cdq", "cwd"):
        written.add(2)
    if mn in ("cbw", "cwde", "cdqe"):
        written.add(0)
    if mn in ("xchg", "mulx") and len(parts) >= 2 and parts[1] in GPR_ALIASES:
        written.add(GPR_ALIASES[parts[1]])
    return written


def classify_block(insns, level="sse2"):
    """Return (ok, reason, meminfo).

    The check fixes every register used in an address: each index register
    gets a small distinct value and each base register a region of the
    256-byte window that covers the block's accesses through it.  Regions
    of different base registers are disjoint, so a proof assumes that the
    buffers do not overlap.  A register changed before its last use in an
    address would run off the modeled window, so such blocks are excluded
    (a pointer bump after the last access is fine)."""
    accesses = []
    first_write = {}
    for idx, ins in enumerate(insns):
        for r in written_gprs(ins["text"]):
            first_write.setdefault(r, idx)
        if ins.get("const"):
            continue        # its RIP-relative operand becomes a window constant
        for a in parse_mem(ins["text"]):
            if a["kind"] != "ok":
                return False, "mem-" + a["kind"], None
            accesses.append((idx, a))
    if not accesses:
        return True, "", {}
    bases = sorted({a["base"] for _, a in accesses})
    indexes = sorted({a["index"] for _, a in accesses if a["index"] is not None})
    if set(bases) & set(indexes):
        return False, "mem-base-is-index", None
    if len(bases) > 3:
        return False, "mem-many-bases", None
    for r in bases + indexes:
        last = max(i for i, a in accesses if r in (a["base"], a["index"]))
        if r in first_write and first_write[r] < last:
            return False, "mem-base-written", None
    align = {"avx512": 64, "avx2": 32, "avx": 32}.get(level, 16)
    # index registers hold small multiples of the vector alignment, so that
    # accesses the code keeps aligned stay aligned in the window
    index_values = {r: align * (k + 1) for k, r in enumerate(indexes)}
    regions = {}
    for _, a in accesses:
        off = a["disp"] + (index_values[a["index"]] * a["scale"] if a["index"] is not None else 0)
        lo, hi = regions.get(a["base"], (off, off + a["size"]))
        regions[a["base"]] = (min(lo, off), max(hi, off + a["size"]))
    cursor, layout = 0, {}
    for b in bases:
        lo, hi = regions[b]
        layout[str(b)] = {"start": cursor, "lo": lo, "hi": hi}
        cursor += (hi - lo + align - 1) // align * align
    if cursor > 256:
        return False, "mem-span", None
    return True, "", {"regions": layout, "span": cursor,
                      "index_values": {str(r): v for r, v in index_values.items()}}


def resolve_constant(obj, index, ins, mn):
    """A RIP-relative data operand's bytes, or None if the reference cannot
    be turned into a constant in the memory window."""
    if len(ins["relocs"]) != 1 or mn == "lea" or mn.startswith(("j", "call", "loop")):
        return None
    if "[rip+" not in ins["text"] and "[rip-" not in ins["text"]:
        return None
    m = re.search(r"(\w+) (?:PTR|BCST) \[rip", ins["text"])
    if not m:
        return None
    size = PTR_SIZES.get(m.group(1))
    if not size:
        return None
    off, reloc = ins["relocs"][0]
    r = constants.resolve(obj, index, reloc, off, ins["addr"], len(ins["bytes"]), size)
    if r is None:
        return None
    data, name = r
    return {"bytes": data, "size": size, "field_off": off - ins["addr"], "sym": name}


def extract(project, path, min_len, max_len, stats, index=None):
    blocks = []
    obj = constants.ObjectInfo(path)
    # nasm emits local labels as "function.label" symbols; merge them back
    # into their function so that liveness sees the whole control flow.
    units = []
    for func in disassemble(path):
        base = func["name"].split(".")[0]
        if units and units[-1]["name"] == base and "." in func["name"]:
            units[-1]["insns"].extend(func["insns"])
        else:
            units.append({"name": base, "addr": func["addr"], "insns": list(func["insns"])})
    for func in units:
        # Assemblers that record symbol sizes (GNU as: .size) let us drop
        # what follows a function's end: perlasm puts lookup tables in
        # .text, and objdump would show them as instructions.
        size = obj.symsize.get(func["name"], 0)
        if size:
            before = len(func["insns"])
            func["insns"] = [i for i in func["insns"] if i["addr"] < func["addr"] + size]
            stats["insn-outside-symbol-size"] += before - len(func["insns"])
        if not func["insns"]:
            continue
        lv = level_for(project, path, func)
        if lv is None:
            stats["skipped-functions-no-level"] += 1
            continue
        level, extras, level_source = lv
        targets = branch_targets(func)
        live_out = liveness.analyze(func["insns"], level)
        cur = []

        def flush(term, end_index):
            nonlocal cur
            if cur:
                blocks.append((func, level, extras, level_source, cur, term,
                               live_out[end_index]))
            cur = []

        for idx, ins in enumerate(func["insns"]):
            if ins["addr"] in targets:
                flush(None, idx - 1)
            mn = mnemonic_of(ins["text"])
            if MMX_REG.search(ins["text"]):
                # MMX registers alias the x87 stack, which the check does
                # not compare; keep such instructions out of the blocks
                stats["insn-mmx"] += 1
                flush(ins, idx - 1)
                continue
            if ins["relocs"]:
                c = resolve_constant(obj, index, ins, mn)
                if c is None:
                    stats["insn-reloc-unresolved"] += 1
                    flush(ins, idx - 1)
                    continue
                ins["const"] = c
                stats["insn-constant-resolved"] += 1
            if TERMINATORS.match(mn) or "(bad)" in ins["text"]:
                flush(ins, idx - 1)
                continue
            cur.append(ins)
        flush(None, len(func["insns"]) - 1)
    out = []
    src = source_file(project, path)
    for func, level, extras, level_source, insns, term, live in blocks:
        n = len(insns)
        if n < min_len:
            stats["blocks-too-short"] += 1
            continue
        if n > max_len:
            stats["blocks-too-long"] += 1
            # a long block still yields its first max_len instructions? No:
            # keep the population simple; long blocks are excluded.
            continue
        ok, reason, mem = classify_block(insns, level)
        if not ok:
            stats["blocks-" + reason] += 1
            continue
        mnems = [mnemonic_of(i["text"]) for i in insns]
        if all(m.startswith(("mov", "vmov", "lea")) for m in mnems):
            stats["blocks-moves-only"] += 1
            continue
        # constants: unique RIP-relative data the block reads, placed in the
        # memory window above the base-register region (which is then
        # limited to 128 bytes), each aligned to its size
        consts, cmap = [], {}
        for ins in insns:
            c = ins.get("const")
            if c:
                key = (c["sym"], c["bytes"])
                if key not in cmap:
                    cmap[key] = len(consts)
                    consts.append(c)
        if consts and mem and mem["span"] > 128:
            stats["blocks-mem-span-with-constants"] += 1
            continue
        woff = 128 if (consts and mem) else 0
        const_off = {}
        for ci in sorted(range(len(consts)), key=lambda i: -consts[i]["size"]):
            align = consts[ci]["size"] if consts[ci]["size"] in (16, 32, 64) else 8
            woff = (woff + align - 1) // align * align
            const_off[ci] = woff
            woff += consts[ci]["size"]
        if woff > 256:
            stats["blocks-constants-too-large"] += 1
            continue
        insns_out = []
        for ins in insns:
            b, t = ins["bytes"], ins["text"]
            c = ins.get("const")
            if c:
                ci = cmap[(c["sym"], c["bytes"])]
                disp = (0x7000 + const_off[ci]) - (0x400000 + len(b))
                fo = c["field_off"]
                b = b[:fo] + (disp & 0xFFFFFFFF).to_bytes(4, "little") + b[fo + 4:]
                t = re.sub(r"\[rip[+-]0x[0-9a-f]+\]\s*(#.*)?$", f"[CONST_{ci + 1}]", t).strip()
                insns_out.append({"bytes": b.hex(), "text": t, "orig_bytes": ins["bytes"].hex()})
            else:
                insns_out.append({"bytes": b.hex(), "text": t})
        live_flags = [f for f in liveness.FLAGS if f in live]
        flags = ",".join(live_flags) or None
        live_out = {
            "gpr": sorted(int(r[1:]) for r in live if r.startswith("g")),
            "vec": sorted(int(r[1:]) for r in live if r.startswith("v")),
            "k": sorted(int(r[1:]) for r in live if r.startswith("k")),
            "flags": live_flags,
        }
        out.append({
            "live_out": live_out,
            "project": project,
            "file": os.path.relpath(path, HOME),
            "source": os.path.relpath(src, HOME) if src else None,
            "function": func["name"],
            "start": insns[0]["addr"],
            "end": insns[-1]["addr"] + len(insns[-1]["bytes"]),
            "level": level,
            "extras": list(extras),
            "level_source": level_source,
            "n": n,
            "insns": insns_out,
            "mem": mem,
            "constants": [{"name": f"CONST_{i + 1}", "off": const_off[i],
                           "size": c["size"], "hex": c["bytes"].hex(), "sym": c["sym"]}
                          for i, c in enumerate(consts)],
            "terminator": term["text"] if term else None,
            "flags_live": flags,
            "norm": normalize(insns_out),
        })
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--min", type=int, default=4)
    ap.add_argument("--max", type=int, default=30)
    ap.add_argument("--out", default=str(Path(__file__).with_name("blocks.json")))
    args = ap.parse_args()
    corpora = [("ffmpeg", ffmpeg_objects()), ("libjpeg-turbo", libjpeg_objects()),
               ("linux", linux_objects()), ("dav1d", dav1d_objects()),
               ("openssl", openssl_objects()), ("glibc", glibc_objects()),
               ("gmp", gmp_objects())]
    # objects that may hold constants referenced from another object
    index_patterns = {
        "ffmpeg": [str(HOME / "ffmpeg/lib*/x86/*.o")],
        "dav1d": [str(CORPORA_DIR / "dav1d/build/src/**/*.o"),
                  str(CORPORA_DIR / "dav1d/build/src/**/*.obj")],
        "openssl": [str(HOME / "openssl/crypto/**/libcrypto-lib-*.o")],
    }
    stats = Counter()
    all_blocks = []
    sources = {}
    for project, objs in corpora:
        index = constants.ProjectIndex(index_patterns[project]) if project in index_patterns else None
        files = {}
        for o in objs:
            src = source_file(project, o)
            if src and os.path.exists(src):
                with open(src, "rb") as f:
                    files[os.path.relpath(src, HOME)] = sum(1 for _ in f)
            else:
                files[os.path.relpath(o, HOME)] = None
            all_blocks.extend(extract(project, o, args.min, args.max, stats, index))
        sources[project] = {"objects": len(objs), "source_files": len(files),
                            "source_lines": sum(v for v in files.values() if v),
                            "files": files}
        print(f"{project}: {len(objs)} objects, {len(files)} source files, "
              f"{sources[project]['source_lines']} lines")
    Path(args.out).with_name("sources.json").write_text(json.dumps(sources, indent=1))
    # dedup by normalized text
    seen = {}
    uniq = []
    for b in all_blocks:
        key = (b["level"], b["norm"], tuple(c["hex"] for c in b["constants"]))
        if key in seen:
            seen[key]["dups"] += 1
            continue
        b["dups"] = 0
        b["id"] = hashlib.sha1("\n".join([b["level"], b["norm"]] +
                                         [c["hex"] for c in b["constants"]]).encode()).hexdigest()[:10]
        seen[key] = b
        uniq.append(b)
    by_proj = Counter(b["project"] for b in uniq)
    by_level = Counter(b["level"] for b in uniq)
    with_mem = sum(1 for b in uniq if b["mem"])
    print(f"blocks: {len(all_blocks)} total, {len(uniq)} distinct")
    print("by project:", dict(by_proj))
    print("by level:", dict(by_level))
    print(f"with memory operands: {with_mem}; with live flags: {sum(1 for b in uniq if b['flags_live'])}")
    lens = Counter(b["n"] for b in uniq)
    print("lengths:", sorted(lens.items()))
    print("exclusions:", dict(stats))
    Path(args.out).write_text(json.dumps(uniq, indent=1))
    print("wrote", args.out)


if __name__ == "__main__":
    main()
