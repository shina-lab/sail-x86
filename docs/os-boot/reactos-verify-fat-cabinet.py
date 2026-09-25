"""Read a snapshot directly; report directory anomalies without recursing into them."""
from pathlib import Path
import hashlib, json, mmap, struct, sys
image=Path(sys.argv[1]); label=sys.argv[2]; root=Path('build/os-boot')
f=image.open('rb'); disk=mmap.mmap(f.fileno(),0,access=mmap.ACCESS_READ)
def u16(p): return struct.unpack_from('<H',disk,p)[0]
def u32(p): return struct.unpack_from('<I',disk,p)[0]
offset=u32(454)*512; bps=u16(offset+11); spc=disk[offset+13]
reserved=u16(offset+14); fats=disk[offset+16]; fatsz=u32(offset+36)
fat=offset+reserved*bps; data=offset+(reserved+fats*fatsz)*bps; cluster_size=bps*spc
root_cluster=u32(offset+44)
def chain(c):
    seen=set()
    while 2 <= c < 0x0ffffff8:
        if c in seen: raise ValueError(f'FAT chain loop at {c}')
        if c*4>=fatsz*bps: raise ValueError(f'FAT index out of range: {c}')
        seen.add(c); p=data+(c-2)*cluster_size
        yield disk[p:p+cluster_size]
        c=u32(fat+c*4)&0x0fffffff
    if c<0x0ffffff8: raise ValueError(f'FAT chain ends at {c}')
source={p.name.lower():p for p in (root/'reactos-pagefixed-source').iterdir() if p.is_file()}
compared=[]; anomalies=[]; directories={}; seen_files=set()
def walk(c,path):
    if c<2:
        anomalies.append({'directory':path,'start_cluster':c,'kind':'zero/reserved start cluster'}); return
    if c in directories:
        anomalies.append({'directory':path,'start_cluster':c,'kind':'repeated directory cluster','first':directories[c]}); return
    directories[c]=path; long_name={}
    try: blocks=chain(c)
    except ValueError as e: anomalies.append({'directory':path,'error':str(e)}); return
    try:
        for block in blocks:
            for p in range(0,len(block),32):
                e=block[p:p+32]
                if e[0]==0: return
                if e[0]==0xe5: long_name={}; continue
                attr=e[11]
                if attr==0x0f:
                    long_name[e[0]&31]=(e[1:11]+e[14:26]+e[28:32]).decode('utf-16-le',errors='replace'); continue
                short=e[:8].decode('cp437').rstrip(); ext=e[8:11].decode('cp437').rstrip()
                name=''.join(long_name[i] for i in sorted(long_name)).split('\0')[0].rstrip('\uffff') if long_name else short+('.'+ext if ext else '')
                long_name={}
                if attr&8 or name in ('.','..'): continue
                target=path+'/'+name; start=struct.unpack_from('<H',e,26)[0]|(struct.unpack_from('<H',e,20)[0]<<16)
                if attr&16: walk(start,target); continue
                if name.lower() not in source: continue
                size=struct.unpack_from('<I',e,28)[0]
                try: actual=b''.join(chain(start))[:size] if size else b''
                except ValueError as error:
                    anomalies.append({'file':target,'start_cluster':start,'size':size,'error':str(error)}); continue
                expected_path=source[name.lower()]
                if name.lower()=='fusion.dll' and ('/v1.0.3705/' in target.lower() or target.lower()=='/reactos/system32/fusion.dll'):
                    expected_path=root/'reactos-source-system32-fusion.dll'
                expected=expected_path.read_bytes(); seen_files.add(name.lower())
                compared.append({'file':target,'bytes':len(actual),'source_bytes':len(expected),'sha256':hashlib.sha256(actual).hexdigest(),'source_sha256':hashlib.sha256(expected).hexdigest(),'matches':actual==expected})
    except ValueError as e: anomalies.append({'directory':path,'error':str(e)})
walk(root_cluster,'')
report={'snapshot':str(image),'partition_offset':offset,'cluster_size':cluster_size,'compared':len(compared),'matched':sum(x['matches'] for x in compared),'mismatched':sum(not x['matches'] for x in compared),'directory_anomalies':anomalies,'source_files_not_present_by_name':sorted(source.keys()-seen_files),'files':compared}
(root/f'{label}-cabinet-verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='files'},indent=2))
for item in compared:
    if not item['matches']: print('MISMATCH',json.dumps(item))
raise SystemExit(bool(report['mismatched']))
