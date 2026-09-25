#!/usr/bin/env python3
"""Feed the serial boot prompt and record every input with elapsed wall time."""
import argparse, json, os, re, subprocess, time
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--name',required=True)
p.add_argument('--bootline',required=True)
p.add_argument('--timeout',type=int,default=2400)
p.add_argument('--mirror-vga',action='store_true',help='also write verified root-command output to guest tty1')
p.add_argument('command',nargs=argparse.REMAINDER)
a=p.parse_args()
cmd=a.command[1:] if a.command[:1]==['--'] else a.command
stem=Path('build/os-boot')/a.name
runner=['python3','system-emu/run-boot.py','--name',a.name,'--timeout',str(a.timeout),'--expect',r'(?m)^ALPINE_BOOT_VERIFIED\r?$', '--', *cmd]
start=time.monotonic()
proc=subprocess.Popen(runner)
inputs=[]
commands='uname -a\nmount\nprintf "ALPINE_BOOT_VERIFIED\\n"\n'
if a.mirror_vga:
    commands='printf "\\033[2J\\033[HAlpine serial root session\\n" > /dev/tty1\n(uname -a; id; mount) | tee -a /dev/tty1\nprintf "ALPINE_BOOT_VERIFIED\\n"\n'
stages=[(rb'boot: ',a.bootline+'\n'),(rb'(?m)[^\n]*login: ', 'root\n'),(rb'(?m)[^\n]*[~/#] # |(?m:^localhost:~# )',commands)]
try:
    while proc.poll() is None:
        if stages and stem.with_suffix('.serial').exists() and stem.with_suffix('.pid').exists():
            data=stem.with_suffix('.serial').read_bytes()
            pattern,entry=stages[0]
            if re.search(pattern,data):
                pid=int(stem.with_suffix('.pid').read_text())
                with open(f'/proc/{pid}/fd/0','wb',buffering=0) as f:
                    f.write(entry.encode())
                inputs.append({'wall_seconds':round(time.monotonic()-start,3),'text':entry})
                stem.with_suffix('.inputs.json').write_text(json.dumps(inputs,indent=2)+'\n')
                print('sent',repr(entry),flush=True)
                stages.pop(0)
        time.sleep(.02)
finally:
    if proc.poll() is None: proc.terminate()
raise SystemExit(proc.wait())
