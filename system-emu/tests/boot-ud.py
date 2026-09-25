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
                '--timeout', '120', '--', os.environ.get('BOOT_SMOKE_EMULATOR', 'build/system-emu/sail-x86-system'),
                '-ips', '4', '-m', '16', '-b', 'build/bios.bin', '-hda', str(disk)],
               env=dict(os.environ, SAIL_X86_TRACE_REAL_UD='1', SAIL_X86_TRACE_ADDRESS='0x7c19'), check=True)
log = (root / 'diagnostic-ud.stderr').read_text()
entries = re.findall(r'real-mode IVT\[6\] entry from 0000:(7c[0-9a-f]+) at instruction \d+.*\n  previous mode=real, stack frame=0000:(7c[0-9a-f]+)', log)
assert len(entries) == 2, entries
assert int(entries[0][1], 16) == int(entries[0][0], 16) + 2  # INT 6
assert entries[1][0] == entries[1][1]  # UD2 fault
assert re.search(r'\[\d+\] 0000:00007c[0-9a-f]+: cd 06 90 0f 0b', log)
assert re.search(r'\[\d+\] 0000:00007c[0-9a-f]+: 0f 0b', log)
assert log.count('trace address 0x7c19 at instruction') == 1
assert 'HLT with IF=0' in log
assert (root / 'diagnostic-ud.png').read_bytes().startswith(b'\x89PNG\r\n\x1a\n')
print('Real-mode INT 6 and #UD frames, opcodes, recent execution and text PNG: PASS')

subprocess.run(['python3', 'system-emu/run-boot.py', '--name', 'diagnostic-ud-window',
                '--timeout', '120', '--', os.environ.get('BOOT_SMOKE_EMULATOR', 'build/system-emu/sail-x86-system'),
                '-ips', '4', '-m', '16', '-b', 'build/bios.bin', '-hda', str(disk)],
               env=dict(os.environ, SAIL_X86_TRACE_ADDRESS='0x7c19',
                        SAIL_X86_TRACE_ADDRESS_STEPS='4'), check=True)
window = (root / 'diagnostic-ud-window.stderr').read_text()
start = int(re.search(r'trace address 0x7c19 at instruction (\d+)', window)[1])
end = int(re.search(r'stopping at trace end (\d+) instructions', window)[1])
assert end == start + 4
counts = [int(n) for n in re.findall(r'^\[(\d+)\] CS:RIP=', window, re.M)]
assert counts == list(range(start, end + 1)), counts
assert 'HLT with IF=0' not in window
assert (root / 'diagnostic-ud-window.ram').stat().st_size == 16 * 1024 * 1024
print('Address-triggered STEP=1 window and exact stop/RAM dump: PASS')
