import json, socket, time, sys
from pathlib import Path
root=Path('build/os-boot'); prefix=root/(sys.argv[1] if len(sys.argv)>1 else 'reactos-qemu-control'); start=time.monotonic()
s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM); s.connect(str(prefix.with_suffix('.qmp'))); stream=s.makefile('rwb',buffering=0)
def recv(): return json.loads(stream.readline())
recv()
def qmp(command,arguments=None):
    msg={'execute':command}
    if arguments is not None: msg['arguments']=arguments
    stream.write(json.dumps(msg).encode()+b'\n')
    while True:
        answer=recv()
        if 'return' in answer: return answer['return']
        if 'error' in answer: raise RuntimeError(answer['error'])
def hmp(command): return qmp('human-monitor-command',{'command-line':command})
def screenshot(label):
    path=Path(str(prefix)+'-'+label+'.png').resolve()
    qmp('screendump',{'filename':str(path),'format':'png'})
qmp('qmp_capabilities'); hmp('sendkey ret'); time.sleep(1)
last_screen=''; last_key=0; milestones=set(); actions=[]
try:
    while time.monotonic()-start<1200:
        path=Path(str(prefix)+'.text.bin').resolve(); qmp('pmemsave',{'val':0xb8000,'size':8000,'filename':str(path)}); b=path.read_bytes()
        screen='\n'.join(bytes(c if 32<=c<127 else 32 for c in b[y*160:y*160+160:2]).decode().rstrip() for y in range(50))
        elapsed=round(time.monotonic()-start,2)
        if screen!=last_screen:
            print(json.dumps({'elapsed':elapsed,'screen':[x for x in screen.splitlines() if x.strip()]}),flush=True)
            last_screen=screen
        low=screen.lower()
        if 'successfully' in low and 'success' not in milestones:
            screenshot('success'); milestones.add('success')
        if 'copying' in low and 'copying' not in milestones:
            screenshot('copying'); milestones.add('copying')
        bottom='\n'.join(screen.splitlines()[-3:])
        waiting=any(x in low for x in ['please wait','is copying','updating the system','checking your disk','successfully'])
        if 'ENTER' in bottom and not waiting and time.monotonic()-last_key>=4:
            screenshot(f'page-{len(actions):02}')
            hmp('sendkey ret'); last_key=time.monotonic()
            actions.append({'elapsed':elapsed,'key':'ret','screen':screen})
            (Path(str(prefix)+'.input.json')).write_text(json.dumps(actions,indent=2)+'\n')
        time.sleep(.5)
    screenshot('timeout'); qmp('quit')
except (ValueError,ConnectionError,BrokenPipeError) as e:
    print('QEMU exited:',str(e),flush=True)
finally:
    (Path(str(prefix)+'.result.json')).write_text(json.dumps({'wall_seconds':round(time.monotonic()-start,3),'success_screen': 'success' in milestones,'screens':sorted(milestones),'last_screen':last_screen,'actions':len(actions)},indent=2)+'\n')
