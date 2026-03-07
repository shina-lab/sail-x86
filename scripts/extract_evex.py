#!/usr/bin/env python3
"""Extract all EVEX-encoded instructions from SDM HTML files."""

import os
import re
from html.parser import HTMLParser
from collections import defaultdict

SDM_DIR = os.path.expanduser("~/sdm")

class TableExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.rows = []
        self.current_row = []
        self.current_cell = ""
        self.in_td = False
    def handle_starttag(self, tag, attrs):
        if tag == "tr":
            self.current_row = []
        elif tag in ("td", "th"):
            self.in_td = True
            self.current_cell = ""
    def handle_endtag(self, tag):
        if tag in ("td", "th"):
            self.in_td = False
            self.current_row.append(self.current_cell.strip())
        elif tag == "tr":
            if self.current_row:
                self.rows.append(self.current_row)
    def handle_data(self, data):
        if self.in_td:
            self.current_cell += data


def parse_evex_encoding(enc_str):
    """Parse EVEX encoding string. Handles both:
      EVEX.128.66.0F.W0 58 /r VADDPD ...
      EVEX.128.0F.W0 58 /r VADDPS ...  (NP = no prefix)
      EVEX.NDS.128.66.0F38.W0 ...      (with NDS/NDD/DDS)
    """
    # Normalize: remove NDS/NDD/DDS/T1S/etc modifiers
    s = enc_str
    # Pattern: EVEX[.modifier]*.prefix?.map.W  opcode
    m = re.match(
        r'EVEX(?:\.\w+)*\.'       # EVEX. followed by optional modifiers
        r'(0F3A|0F38|0F)\.'       # opcode map
        r'(W[01IG]+)\s+'          # W field
        r'([0-9A-Fa-f]{2})\b',   # opcode byte
        s
    )
    if not m:
        return None

    opmap = m.group(1)
    w_field = m.group(2)
    opcode = m.group(3).upper()

    # Determine mandatory prefix by looking between EVEX and map
    before_map = s[:m.start(1)]
    if '.66.' in before_map:
        prefix = '66'
    elif '.F3.' in before_map:
        prefix = 'F3'
    elif '.F2.' in before_map:
        prefix = 'F2'
    else:
        prefix = 'NP'

    # Determine vector length
    vl_m = re.search(r'EVEX(?:\.\w+)*\.(\d+)', s)
    vl = vl_m.group(1) if vl_m else '?'

    # Extract mnemonic
    mnemonic = ""
    parts = s.split()
    for p in parts:
        if re.match(r'^V[A-Z]', p) or (re.match(r'^[A-Z]{2}', p) and not p.startswith('EVEX') and p not in ('NP',)):
            mnemonic = p.rstrip(',')
            break

    return (opmap, opcode, prefix, w_field, vl, mnemonic)


def extract_evex_from_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            html = f.read()
    except:
        return []

    parser = TableExtractor()
    parser.feed(html)

    results = []
    for row in parser.rows:
        if len(row) < 4:
            continue
        enc = row[0]
        if not enc.startswith("EVEX"):
            continue

        cpuid = row[3] if len(row) > 3 else ""
        desc = row[4] if len(row) > 4 else ""

        parsed = parse_evex_encoding(enc)
        if not parsed:
            continue

        opmap, opcode, prefix, w_field, vl, mnemonic = parsed

        results.append({
            'map': opmap,
            'opcode': opcode,
            'prefix': prefix,
            'w': w_field,
            'vl': vl,
            'mnemonic': mnemonic,
            'cpuid': cpuid,
            'desc': desc,
            'encoding': enc,
            'file': os.path.basename(filepath),
        })

    return results


# Extensions we want to implement (core AVX-512)
CORE_EXTENSIONS = {
    'AVX512F', 'AVX512DQ', 'AVX512CD', 'AVX512BW', 'AVX512VL',
    'AVX512VL AVX512F', 'AVX512VL AVX512DQ', 'AVX512VL AVX512CD', 'AVX512VL AVX512BW',
    'AVX512F AVX512VL', 'AVX512DQ AVX512VL', 'AVX512CD AVX512VL', 'AVX512BW AVX512VL',
    'AVX512VLA VX512DQ',  # typo in SDM
}

# Other AVX-512 extensions
OTHER_EXTENSIONS = {
    'AVX512-FP16', 'AVX512-FP16 AVX512VL',
    'AVX512_VNNI', 'AVX512_VNNI AVX512VL',
    'AVX512_VBMI', 'AVX512_VBMI AVX512VL', 'AVX512VL AVX512_VBMI',
    'AVX512_VBMI2', 'AVX512_VBMI2 AVX512VL',
    'AVX512_BITALG', 'AVX512_BITALG AVX512VL',
    'AVX512_IFMA', 'AVX512_IFMA AVX512VL',
    'AVX512_VPOPCNTDQ', 'AVX512_VPOPCNTDQ AVX512VL',
    'AVX512_4VNNIW', 'AVX512_4FMAPS',
    'AVX512ER', 'AVX512PF',
    'AVX512F AVX512_BF16', 'AVX512VL AVX512_BF16',
    'AVX512F GFNI', 'AVX512VL GFNI',
    'VAES AVX512F', 'VAES AVX512VL',
    'VPCLMULQDQ AVX512F', 'VPCLMULQDQ AVX512VL',
}


def is_core_ext(cpuid):
    return cpuid.strip() in CORE_EXTENSIONS

def classify_ext(cpuid):
    c = cpuid.strip()
    if c in CORE_EXTENSIONS:
        return 'core'
    elif c in OTHER_EXTENSIONS or 'AVX512' in c:
        return 'other_avx512'
    else:
        return 'unknown'


def main():
    all_entries = []
    for entry in sorted(os.listdir(SDM_DIR)):
        path = os.path.join(SDM_DIR, entry)
        if os.path.isdir(path) or entry.endswith('.css') or entry == 'robots.txt' or entry == 'parameters' or entry == 'capabilities':
            continue
        entries = extract_evex_from_file(path)
        all_entries.extend(entries)

    # Group by (map, opcode)
    by_map_opcode = defaultdict(list)
    seen = set()
    for e in all_entries:
        key = (e['map'], e['opcode'], e['prefix'], e['w'], e['vl'])
        if key in seen:
            continue
        seen.add(key)
        by_map_opcode[(e['map'], e['opcode'])].append(e)

    for map_name in ['0F', '0F38', '0F3A']:
        entries_in_map = sorted(
            [(k, v) for k, v in by_map_opcode.items() if k[0] == map_name],
            key=lambda x: int(x[0][1], 16)
        )
        print(f"## EVEX {map_name} Map ({len(entries_in_map)} unique opcode bytes)")
        print()

        for (m, opc), variants in entries_in_map:
            mnemonics = []
            for v in variants:
                if v['mnemonic'] and v['mnemonic'] not in mnemonics:
                    mnemonics.append(v['mnemonic'])
            cpuids = sorted(set(v['cpuid'] for v in variants if v['cpuid']))
            prefixes = sorted(set(v['prefix'] for v in variants))
            ws = sorted(set(v['w'] for v in variants))

            # Classify
            all_core = all(is_core_ext(v['cpuid']) for v in variants)
            any_core = any(is_core_ext(v['cpuid']) for v in variants)

            mnem_str = "/".join(mnemonics) if mnemonics else f"0x{opc}"
            cpuid_str = ", ".join(cpuids) if cpuids else "?"
            prefix_str = "/".join(prefixes)
            w_str = "/".join(ws)

            tag = ""
            if all_core:
                tag = " [CORE]"
            elif any_core:
                tag = " [MIXED]"
            else:
                tag = " [EXT]"

            print(f"- 0x{opc}: {mnem_str} (pp={prefix_str}, W={w_str}) [{cpuid_str}]{tag}")

        print()


if __name__ == '__main__':
    main()
