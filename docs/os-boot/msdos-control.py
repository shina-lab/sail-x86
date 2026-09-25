import argparse,json,os,signal,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('name');p.add_argument('action',choices=['send','capture','stop']);p.add_argument('value',nargs='?',default='');a=p.parse_args()
s=Path('build/os-boot')/a.name;pid=int(s.with_suffix('.pid').read_text())
if a.action=='send':
    data=a.value.encode().decode('unicode_escape').encode()
    with open(f'/proc/{pid}/fd/0','wb',buffering=0) as f:
        for b in data:
            f.write(bytes([b]));time.sleep(.10)
    with s.with_suffix('.input.jsonl').open('a') as f:f.write(json.dumps({'utc':time.strftime('%Y-%m-%d %H:%M:%S',time.gmtime()),'input':a.value})+'\n')
else:
    os.kill(pid,signal.SIGUSR1);os.kill(pid,signal.SIGUSR2);time.sleep(.5)
    if a.value:
        import shutil
        shutil.copyfile(s.with_suffix('.png'),Path('docs/os-boot')/a.value)
    if a.action=='stop':os.kill(pid,signal.SIGTERM)
