#!/usr/bin/env python3
"""Control a running run-boot.py attempt on Linux; retain each manual action.

Examples (from the repository root):
  python3 docs/os-boot/os2-control.py os2-install dump
  python3 docs/os-boot/os2-control.py os2-install swap build/os-boot/os2-diskettes/DISK1_CD.DSK
  python3 docs/os-boot/os2-control.py os2-install keys '\\n'

The swap action copies media into the private -fda path, then sends
Ctrl-a f and Enter. The source diskette is never changed.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import shutil
import signal
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("name")
parser.add_argument("action", choices=("dump", "png", "stop", "keys", "swap"))
parser.add_argument("value", nargs="?")
args = parser.parse_args()
if args.action in ("keys", "swap") and args.value is None:
    parser.error("keys and swap require a value")

stem = Path("build/os-boot") / args.name
pid = int(stem.with_suffix(".pid").read_text())
command = Path(f"/proc/{pid}/cmdline").read_bytes().decode().split("\0")
if Path(command[0]).name != "sail-x86-system":
    raise RuntimeError("PID no longer belongs to sail-x86-system")

if args.action == "swap":
    target = Path(command[command.index("-fda") + 1]).resolve()
    if not target.is_relative_to(Path("build/os-boot").resolve()):
        raise RuntimeError("Only swap a private image under build/os-boot")
    replacement = Path(str(target) + ".next")
    shutil.copyfile(args.value, replacement)
    os.replace(replacement, target)
    data = b"\x01f\n"
elif args.action == "keys":
    data = args.value.encode().decode("unicode_escape").encode()

entry = dict(utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
             action=args.action, values=[args.value] if args.value else [])
with stem.with_suffix(".inputs").open("a") as stream:
    stream.write(json.dumps(entry) + "\n")

if args.action in ("keys", "swap"):
    fd = os.open(f"/proc/{pid}/fd/0", os.O_WRONLY)
    try:
        os.write(fd, data)
    finally:
        os.close(fd)
else:
    os.kill(pid, dict(dump=signal.SIGUSR1, png=signal.SIGUSR2, stop=signal.SIGTERM)[args.action])
    time.sleep(0.2)

if args.action == "dump":
    text = stem.with_suffix(".stderr").read_text(errors="replace")
    print(text[text.rfind("sail-x86-system: framebuffer"):])
