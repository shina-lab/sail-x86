#!/usr/bin/env python3
r"""Bound a boot attempt and retain its command, serial log, state and timing.

Example: run-boot.py --name xv6 --timeout 300 --expect '\$ ' -- COMMAND ...
--send SECONDS:TEXT writes escaped text (e.g. 20:boot\\n) to the guest.
Artifacts are stored under build/os-boot by default.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import signal
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--name', required=True)
parser.add_argument('--timeout', type=float, default=300)
parser.add_argument('--expect')
parser.add_argument('--send', action='append', default=[])
parser.add_argument('--out', default='build/os-boot')
parser.add_argument('command', nargs=argparse.REMAINDER)
args = parser.parse_args()
command = args.command[1:] if args.command[:1] == ['--'] else args.command
if not command:
    parser.error('missing command')
out = Path(args.out)
out.mkdir(parents=True, exist_ok=True)
stem = out / args.name
sends = sorted((float(s.split(':', 1)[0]), s.split(':', 1)[1]) for s in args.send)
start = time.monotonic()
reason = 'exit'
env = os.environ.copy()
env['SAIL_X86_FRAMEBUFFER'] = str(stem.with_suffix('.png'))
env['SAIL_X86_DUMP_RAM'] = str(stem.with_suffix('.ram'))
with stem.with_suffix('.serial').open('wb') as serial, stem.with_suffix('.stderr').open('wb') as err:
    proc = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=serial, stderr=err, env=env)
    stem.with_suffix('.pid').write_text(str(proc.pid))
    try:
        while proc.poll() is None:
            elapsed = time.monotonic() - start
            while sends and elapsed >= sends[0][0]:
                _, data = sends.pop(0)
                proc.stdin.write(data.encode().decode('unicode_escape').encode())
                proc.stdin.flush()
            if args.expect and re.search(args.expect.encode(), stem.with_suffix('.serial').read_bytes()):
                reason = 'expected output'
                break
            if elapsed >= args.timeout:
                reason = 'timeout'
                break
            time.sleep(0.2)
    finally:
        if proc.poll() is None:
            proc.send_signal(signal.SIGUSR1)
            time.sleep(0.3)
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
elapsed = time.monotonic() - start
stderr = stem.with_suffix('.stderr').read_text(errors='replace')
counts = re.findall(r'(?:after |^\[)(\d+)(?: ins|\])', stderr, re.M)
result = dict(command=shlex.join(command), runner=shlex.join(os.sys.argv),
              wall_seconds=round(elapsed, 3), instructions=int(counts[-1]) if counts else None,
              reason=reason, returncode=proc.returncode,
              serial_tail=stem.with_suffix('.serial').read_text(errors='replace')[-4000:],
              stderr_tail=stderr[-4000:])
stem.with_suffix('.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: v for k, v in result.items() if not k.endswith('_tail')}, indent=2))
