#!/usr/bin/env python3
"""Boot SeaVGABIOS in modes 12h, 13h and 101h, then validate PNG pixels.

Run from the repository root after building the emulator and bios.bin:
  python3 system-emu/tests/boot-graphics.py
Requires nasm. Artifacts and boot measurements stay under build/os-boot.
"""
from pathlib import Path
import struct
import subprocess
import zlib

out = Path('build/os-boot')
out.mkdir(parents=True, exist_ok=True)
for mode, width, height, colors in [(0x12, 640, 480, 8), (0x13, 320, 200, 2), (0x101, 640, 480, 4)]:
    name = f'bios-mode{mode:x}'
    disk = out / (name + '.img')
    subprocess.run(['nasm', '-f', 'bin', f'-DTEST_MODE={mode}',
                    'system-emu/tests/graphics-boot.asm', '-o', str(disk)], check=True)
    with disk.open('ab') as f:
        f.truncate(1024 * 1024)
    subprocess.run(['python3', 'system-emu/run-boot.py', '--name', name, '--timeout', '120', '--',
                    'build/system-emu/sail-x86-system', '-ips', '4', '-m', '16',
                    '-b', 'build/bios.bin', '-hda', str(disk), '-boot', 'c'], check=True)
    assert b'GRAPHICS READY' in (out / (name + '.serial')).read_bytes()
    png = (out / (name + '.png')).read_bytes()
    assert png[:8] == b'\x89PNG\r\n\x1a\n'
    pos, data = 8, b''
    while pos < len(png):
        length = struct.unpack_from('>I', png, pos)[0]
        tag, chunk = png[pos+4:pos+8], png[pos+8:pos+8+length]
        assert zlib.crc32(tag + chunk) == struct.unpack_from('>I', png, pos+8+length)[0]
        if tag == b'IHDR':
            assert struct.unpack_from('>IIBB', chunk) == (width, height, 8, 2)
        if tag == b'IDAT': data += chunk
        pos += length + 12
    raw = zlib.decompress(data)
    assert len(raw) == height * (width * 3 + 1)
    first = raw[1:1+width*3]
    assert len({first[i:i+3] for i in range(0, len(first), 3)}) == colors
    assert all(raw[y*(width*3+1)] == 0 and
               raw[y*(width*3+1)+1:(y+1)*(width*3+1)] == first for y in range(height))
    print(f'{name}: {width}x{height}, {colors} distinct palette colors: PASS')
