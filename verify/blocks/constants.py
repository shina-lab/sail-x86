"""Resolve RIP-relative data references in object files to their bytes.

Hand-written SIMD code loads its constants (multipliers, shuffle masks,
rounding terms) from the object's read-only data through RIP-relative
operands.  In an unlinked object these appear as R_X86_64_PC32
relocations against a section or a symbol.  This module reads the bytes
the operand refers to, so that the equivalence check can place the same
constant in its memory window and both the original and a rewrite can
address it there.
"""

import glob
import os
import re

from elftools.elf.elffile import ELFFile

RELOC_RE = re.compile(r"^(R_X86_64_\w+) (\S+?)([+-]0x[0-9a-f]+)?$")


class ObjectInfo:
    def __init__(self, path):
        self.path = path
        self._f = open(path, "rb")
        self.elf = ELFFile(self._f)
        self.sections = list(self.elf.iter_sections())
        self.section_by_name = {s.name: i for i, s in enumerate(self.sections)}
        self.symbols = {}          # name -> (section index, value)
        self.symsize = {}          # name -> st_size (0 when the assembler gave none)
        self.undefined = set()
        symtab = self.elf.get_section_by_name(".symtab")
        if symtab is not None:
            for sym in symtab.iter_symbols():
                if not sym.name:
                    continue
                shndx = sym["st_shndx"]
                if shndx == "SHN_UNDEF":
                    self.undefined.add(sym.name)
                elif isinstance(shndx, int):
                    self.symbols[sym.name] = (shndx, sym["st_value"])
                    self.symsize[sym.name] = sym["st_size"]
        self._data = {}

    def section_data(self, shndx):
        if shndx not in self._data:
            self._data[shndx] = self.sections[shndx].data()
        return self._data[shndx]

    def read(self, sym, offset, size):
        """Bytes at symbol + offset, or None."""
        if sym in self.symbols:
            shndx, value = self.symbols[sym]
        elif sym in self.section_by_name:
            shndx, value = self.section_by_name[sym], 0
        else:
            return None
        sec = self.sections[shndx]
        if sec["sh_type"] == "SHT_NOBITS":
            return None
        data = self.section_data(shndx)
        off = value + offset
        if off < 0 or off + size > len(data):
            return None
        return data[off:off + size]


class ProjectIndex:
    """Global data symbols across a project's objects, for constants that
    live in another object (FFmpeg's ff_pw_* in constants.o)."""

    def __init__(self, patterns):
        self.objects = {}
        self.where = {}
        for pat in patterns:
            for path in glob.glob(pat, recursive=True):
                try:
                    info = ObjectInfo(path)
                except Exception:  # noqa: BLE001
                    continue
                self.objects[path] = info
                symtab = info.elf.get_section_by_name(".symtab")
                if symtab is None:
                    continue
                for sym in symtab.iter_symbols():
                    if sym.name and sym["st_info"]["bind"] == "STB_GLOBAL" and \
                            isinstance(sym["st_shndx"], int) and sym.name not in self.where:
                        self.where[sym.name] = path

    def read(self, sym, offset, size):
        path = self.where.get(sym)
        if path is None:
            return None
        return self.objects[path].read(sym, offset, size)


def parse_reloc(line):
    """'R_X86_64_PC32 .rodata+0x1c' -> (type, symbol, addend) or None."""
    m = RELOC_RE.match(line.strip())
    if not m:
        return None
    addend = int(m.group(3), 16) if m.group(3) else 0
    return m.group(1), m.group(2), addend


def resolve(obj, index, reloc, reloc_off, insn_addr, insn_len, size):
    """Bytes of the constant a RIP-relative operand refers to.

    reloc_off is the file offset of the disp32 field; the CPU adds the
    displacement to the address of the next instruction, so the target is
    symbol + addend + (insn_end - field)."""
    parsed = parse_reloc(reloc)
    if not parsed or parsed[0] != "R_X86_64_PC32":
        return None
    _, sym, addend = parsed
    offset = addend + (insn_addr + insn_len - reloc_off)
    data = obj.read(sym, offset, size)
    if data is None and index is not None:
        data = index.read(sym, offset, size)
    if data is None:
        return None
    return data, f"{sym}{offset:+#x}" if sym.startswith(".") else f"{sym}{offset:+#x}"
