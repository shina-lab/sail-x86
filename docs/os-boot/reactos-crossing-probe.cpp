// Diagnostic for the remaining ReactOS copy-corruption issue, outside CTest.
// Expected: #PF on the absent second page, with EAX unchanged.
// Current LLVM result: HLT with EAX=5348 and an undelivered Sail exception.
#define main unused_paging_main
#include "../../system-emu/tests/test-paging.cpp"
#undef main
int main() {
 x86::Model m;init_model_32(m);m.zsystem_mode=false;m.zCR3=0x10000;
 m.phys_mem.write32(0x10000,0x11003);
 for(unsigned i=0;i<1024;i++)m.phys_mem.write32(0x11000+i*4,(i<<12)|3);
 m.phys_mem.write32(0x11000+0x44*4,0);
 m.phys_mem.write8(0,0x53);m.phys_mem.write8(0x43fff,0x48);
 m.zGPR.data[7]=0x43fff;m.zGPR.data[0]=0x12345678;
 const u8 code[]={0x0f,0xb7,0x07,0xf4};
 int kind=run_code(m,0x100000,code,sizeof(code));
 printf("cross-page MOVZX: result=%d fault=%d vector=%lu CR2=%lx EAX=%lx RIP=%lx have_exception=%d\n",kind,(int)m.zfault_pending,(u64)m.zfault_vector,(u64)m.zCR2,(u64)m.zGPR.data[0],(u64)m.zRIP,(int)m.have_exception);
 return !(kind==RUN_FAULTED && (u64)m.zGPR.data[0]==0x12345678);
}
