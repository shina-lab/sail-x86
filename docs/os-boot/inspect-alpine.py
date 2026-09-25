#!/usr/bin/env python3
"""Inspect a nokaslr x86-64 Linux RAM snapshot using its own BTF and System.map.
Stack output is a scan for possible text addresses, not a validated unwind.
This kernel uses 16 KiB stacks and a 16-byte FRED reservation at the top.
Kernel addresses use init_top_pgt so snapshots taken under KPTI also work.
"""
import argparse, bisect, json, mmap, re, struct
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('stem')
p.add_argument('--media',default='build/os-boot/alpine-media')
p.add_argument('--tasks',default='init|nlplug-findfs|mdev|modprobe|sh|swapper/0')
a=p.parse_args()
media=Path(a.media)
syms={name:int(addr,16) for addr,kind,name in (s.split()[:3] for s in (media/'System.map').read_text().splitlines())}
ordered=sorted((v,k) for k,v in syms.items())
addresses=[v for v,k in ordered]
def symbol(v):
    i=bisect.bisect_right(addresses,v)-1
    return f'{ordered[i][1]}+0x{v-ordered[i][0]:x}' if i>=0 else '?'
types=json.loads((media/'btf.json').read_text())['types']
byid={t['id']:t for t in types}
def members(name):
    t=next(t for t in types if t['kind']=='STRUCT' and t['name']==name)
    return {m['name']:m['bits_offset']//8 for m in t['members']}
task=members('task_struct');thread=members('thread_struct');sig=members('signal_struct');regs=members('pt_regs')
f=open(a.stem+'.ram','rb');ram=mmap.mmap(f.fileno(),0,access=mmap.ACCESS_READ)
state=Path(a.stem+'.stderr').read_text(errors='replace')
cr3=int(re.findall(r'CR3=([0-9a-f]+)',state)[-1],16)&0xffffffffff000
rip=int(re.findall(r'RIP=([0-9a-f]+)',state)[-1],16)
cr4=int(re.findall(r'CR4=([0-9a-f]+)',state)[-1],16)
print(f'CR3={cr3:x} RIP={rip:x} {symbol(rip)}')
def pu64(pa):return struct.unpack_from('<Q',ram,pa)[0]
def phys(va):
    table=(syms['init_top_pgt']-0xffffffff80000000) if va>>63 else cr3
    for shift in ([48] if cr4 & (1<<12) else []) + [39,30,21,12]:
        e=pu64(table+((va>>shift)&511)*8)
        if not e&1:raise ValueError(f'unmapped {va:x} at level {shift}')
        if shift==12 or shift in (30,21) and e&128:
            mask=(1<<shift)-1
            return (e&0xffffffffff000&~mask)|(va&mask)
        table=e&0xffffffffff000
    raise ValueError(va)
def read(va,size):
    b=b''
    while size:
        n=min(size,4096-(va&4095));pa=phys(va);b+=ram[pa:pa+n];size-=n;va+=n
    return b
def u64(va):return struct.unpack('<Q',read(va,8))[0]
def u32(va):return struct.unpack('<I',read(va,4))[0]
first=syms['init_task'];ptr=first;seen=set();pending=[first]
while pending and len(seen)<2000:
    ptr=pending.pop(0)
    if ptr in seen: continue
    seen.add(ptr)
    nxt=u64(ptr+task['tasks'])-task['tasks']
    if nxt not in seen: pending.append(nxt)
    head=u64(ptr+task['signal'])+sig['thread_head'];node=u64(head);ns=set()
    while node != head and node not in ns and len(ns)<1000:
        ns.add(node);t=node-task['thread_node']
        if t not in seen: pending.append(t)
        node=u64(node)
    name=read(ptr+task['comm'],16).split(b'\0')[0].decode(errors='replace')
    pid=u32(ptr+task['pid']);st=u32(ptr+task['__state']);sp=u64(ptr+task['thread']+thread['sp'])
    print(f'task={ptr:016x} pid={pid:4} state={st:04x} sp={sp:016x} {name}')
    if re.fullmatch(a.tasks,name):
        stack=u64(ptr+task['stack']);print(f'  stack={stack:x} mm={u64(ptr+task["mm"]):x}')
        try:
            data=read(sp,min(16384-(sp-stack),4096))
            for i in range(0,len(data)-7,8):
                v=struct.unpack_from('<Q',data,i)[0]
                if syms['_stext']<=v<syms['_etext']:
                    print(f'    {sp+i:016x}: {v:016x} {symbol(v)}')
        except (ValueError,OverflowError) as e: print('  stack read:',e)
        mm=u64(ptr+task['mm'])
        if mm:
            pgd=u64(mm+120);cr3=phys(pgd)
            r={k:u64(stack+16384-168-16+off) for k,off in regs.items() if k!='(anon)'}
            print('  saved user regs:',' '.join(f'{k}={v:x}' for k,v in r.items()))
            try:
                print('  user code:',read(r['ip'],24).hex(' '))
                print('  user stack:',' '.join(f'{u64(r["sp"]+i):x}' for i in range(0,256,8)))
                if r['orig_ax']==202: print('  futex value:',hex(u32(r['di'])))
                aux={u64(mm+512+i):u64(mm+520+i) for i in range(0,320,16)}
                print('  auxv:',{k:hex(aux.get(k,0)) for k in (3,7,9)})
            except ValueError as e: print('  user read:',e)

