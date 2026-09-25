from pathlib import Path
import subprocess, concurrent.futures
out=Path('build/llvm')
flags=['clang++','-std=c++20','-O2','-march=native','-Wno-unused-parameter','-Ibuild/llvm','-I/home/ruiu/sail-llvm/runtime/sail_llvm_rt/include','-Isystem-emu','-Iemu-shared']
files=['system-emu/x86-externals.cpp','system-emu/x86-phys-mem.cpp','emu-shared/x86-externals-common.cpp']
def obj(f):
    p=out/(Path(f).stem+'.o');subprocess.run(flags+['-c',f,'-o',str(p)],check=True);return str(p)
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool: objs=list(pool.map(obj,files))
def test(n):
    exe=out/('system_test_'+n)
    subprocess.run(flags+['system-emu/tests/test-'+n+'.cpp']+objs+[str(out/'sail_x86_model.o'),'/home/ruiu/sail-llvm/build/runtime/sail_llvm_rt/libsail_llvm_rt.a','-o',str(exe)],check=True)
    r=subprocess.run([str(exe)],capture_output=True,text=True)
    Path('build/os-boot/alpine-xadd-'+n+'.log').write_text(r.stdout+r.stderr)
    return n,r.returncode
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool: results=list(pool.map(test,['basic','paging','exceptions']))
for n,rc in results: print(n,rc)
raise SystemExit(any(rc for _,rc in results))
