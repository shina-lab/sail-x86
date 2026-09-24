"""Exercise headless F8 and arrow input through the BIOS keyboard service."""
from pathlib import Path
import subprocess

root = Path('build/os-boot')
root.mkdir(parents=True, exist_ok=True)
disk = root / 'diagnostic-keyboard.img'
subprocess.run(['nasm', '-f', 'bin', 'system-emu/tests/keyboard-boot.asm', '-o', str(disk)], check=True)
with disk.open('ab') as f:
    f.truncate(1024 * 1024)
subprocess.run(['python3', 'system-emu/run-boot.py', '--name', 'diagnostic-keyboard',
                '--timeout', '120', '--send', r'20:\x018\x01u\x01d', '--',
                'build/system-emu/sail-x86-system', '-ips', '4', '-m', '16', '-kbd',
                '-b', 'build/bios.bin', '-hda', str(disk)], check=True)
assert (root / 'diagnostic-keyboard.serial').read_bytes() == b'KEYBOARD PASS\r\n'
print('F8, Up and Down via headless input and BIOS INT 16h: PASS')
