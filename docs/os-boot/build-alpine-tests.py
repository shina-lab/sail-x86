from pathlib import Path
import argparse, subprocess, concurrent.futures
p=argparse.ArgumentParser(description='Link system tests against an existing sail-llvm model object.')
p.add_argument('--out',type=Path,default=Path('build/llvm'))
p.add_argument('--sail-llvm',type=Path,default=Path.home()/'sail-llvm')
p.add_argument('--log-prefix',default='alpine-xadd')
p.add_argument('--tests',nargs='+',default=['basic','paging','exceptions'],choices=['basic','paging','exceptions','apic-cpu','fw-cfg','ide'])
a=p.parse_args()
out=a.out
flags=['clang++','-std=c++20','-O2','-march=native','-Wno-unused-parameter','-I'+str(out),'-I'+str(a.sail_llvm/'runtime/sail_llvm_rt/include'),'-Isystem-emu','-Iemu-shared']
files=['system-emu/x86-externals.cpp','system-emu/x86-phys-mem.cpp','emu-shared/x86-externals-common.cpp']
def obj(f):
    p=out/(Path(f).stem+'.o');subprocess.run(flags+['-c',f,'-o',str(p)],check=True);return str(p)
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool: objs=list(pool.map(obj,files))
def test(n):
    exe=out/('system_test_'+n)
    subprocess.run(flags+['system-emu/tests/test-'+n+'.cpp']+objs+[str(out/'sail_x86_model.o'),str(a.sail_llvm/'build/runtime/sail_llvm_rt/libsail_llvm_rt.a'),'-o',str(exe)],check=True)
    r=subprocess.run([str(exe)],capture_output=True,text=True)
    Path('build/os-boot/'+a.log_prefix+'-'+n+'.log').write_text(r.stdout+r.stderr)
    return n,r.returncode
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool: results=list(pool.map(test,a.tests))
for n,rc in results: print(n,rc)
raise SystemExit(any(rc for _,rc in results))
