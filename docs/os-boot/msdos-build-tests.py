from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import subprocess
out=Path('build/llvm');rt=Path('/home/ruiu/sail-llvm')
flags=['clang++','-std=c++20','-O2','-march=native','-Wno-unused-parameter','-I'+str(out),'-I'+str(rt/'runtime/sail_llvm_rt/include'),'-Isystem-emu','-Iemu-shared']
platform=['system-emu/x86-externals.cpp','system-emu/x86-phys-mem.cpp','emu-shared/x86-externals-common.cpp']
def obj(src):
 dst=out/(Path(src).stem+'.o');subprocess.run(flags+['-c',src,'-o',str(dst)],check=True);return str(dst)
with ThreadPoolExecutor(max_workers=8) as pool:objects=list(pool.map(obj,platform))
libs=objects+[str(out/'sail_x86_model.o'),str(rt/'build/runtime/sail_llvm_rt/libsail_llvm_rt.a')]
def build(src):
 dst=out/Path(src).stem;subprocess.run(flags+[src]+libs+['-o',str(dst)],check=True);print(dst,flush=True)
with ThreadPoolExecutor(max_workers=8) as pool:list(pool.map(build,[str(p) for p in sorted(Path('system-emu/tests').glob('test-*.cpp'))]+['kvm/test-vm86.cpp']))
