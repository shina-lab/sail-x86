#!/usr/bin/env python3
"""Validate SeaBIOS's 16-bit IDE I/O BAR allocation and CPU port routing.

Run from the repository root after mk-freedos.sh:
  python3 system-emu/tests/boot-ide-pci.py build/llvm/sail-x86-system
"""
from pathlib import Path
import subprocess
import sys

out = Path('build/os-boot')
out.mkdir(parents=True, exist_ok=True)
disk = out / 'bios-ide-pci.img'
subprocess.run(['nasm', '-f', 'bin', 'system-emu/tests/ide-pci-boot.asm',
                '-o', str(disk)], check=True)
with disk.open('ab') as f:
    f.truncate(1024 * 1024)
emulator = sys.argv[1] if len(sys.argv) > 1 else 'build/system-emu/sail-x86-system'
subprocess.run(['python3', 'system-emu/run-boot.py', '--name', 'bios-ide-pci',
                '--timeout', '120', '--', emulator, '-ips', '4', '-m', '16',
                '-b', 'build/bios.bin', '-hda', str(disk), '-boot', 'c'], check=True)
assert (out / 'bios-ide-pci.serial').read_bytes() == b'IDE PCI BAR READY\n'
print('PIIX IDE BAR allocation, channel isolation, status and PRDT I/O: PASS')
