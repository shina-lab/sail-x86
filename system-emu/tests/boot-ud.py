"""Check opt-in real-mode #UD diagnostics with SeaBIOS (run from repo root)."""
import os
from pathlib import Path
import re
import subprocess

root = Path('build/os-boot')
root.mkdir(parents=True, exist_ok=True)
disk = root / 'diagnostic-ud.img'
subprocess.run(['nasm', '-f', 'bin', 'system-emu/tests/ud-boot.asm', '-o', str(disk)], check=True)
with disk.open('ab') as f:
    f.truncate(1024 * 1024)
subprocess.run(['python3', 'system-emu/run-boot.py', '--name', 'diagnostic-ud',
                '--timeout', '120', '--', 'build/system-emu/sail-x86-system',
                '-ips', '4', '-m', '16', '-b', 'build/bios.bin', '-hda', str(disk)],
               env=dict(os.environ, SAIL_X86_TRACE_REAL_UD='1'), check=True)
log = (root / 'diagnostic-ud.stderr').read_text()
assert re.search(r'real-mode IVT\[6\] entry from 0000:7c[0-9a-f]+ at instruction \d+', log)
assert re.search(r'\[\d+\] 0000:00007c[0-9a-f]+: 0f 0b fa f4', log)
assert 'HLT with IF=0' in log
assert (root / 'diagnostic-ud.png').read_bytes().startswith(b'\x89PNG\r\n\x1a\n')
print('Real-mode #UD location, opcode, recent execution and text PNG: PASS')
