#include "sail_x86_model.h"
#include "x86-helpers.h"
#include <cstdio>
#include <random>
#include <cassert>
int main() {
  x86::Model m; m.model_init(); m.zinitializze_registers(UNIT); x86::enable_all_features(m);
  assert(m.phys_mem.init(0x100000)); m.zsystem_mode=false; m.zcur_mode=x86::zLongMode;
  m.zcur_cpl=0; m.zCR0=0x11; m.zCR4=0; m.zEFER=0xD01; m.zSegCache.data[x86::SEG_CS].zseg_l=1;
  m.zGPR.data[4]=0x80000;
  const u8 code[][6]={{0x48,0xF7,0xE1},{0x48,0xF7,0xF1},{0x48,0x11,0xC8},{0x48,0x19,0xC8},{0x66,0x48,0x0F,0x38,0xF6,0xC1},{0xF3,0x48,0x0F,0x38,0xF6,0xC1}};
  const char *names[]={"mul","div","adc","sbb","adcx","adox"};
  std::mt19937_64 rng(1); int fails=0;
  for (int op=0;op<6;++op) {
    m.phys_mem.write_bytes(0x1000+op*0x100,code[op],6);
    for (int i=0;i<10000;++i) {
      u64 a=rng(),b=rng(),hi=rng();bool c=rng()&1;u64 er=0,eh=0;
      if(op==1) {b|=1UL<<63;hi%=b;}
      unsigned __int128 x=(static_cast<unsigned __int128>(hi)<<64)|a;
      unsigned __int128 ar=static_cast<unsigned __int128>(a)+b+c;
      if(op==0) {ar=static_cast<unsigned __int128>(a)*b;er=ar;eh=ar>>64;}
      else if(op==1) {er=x/b;eh=x%b;}
      else if(op==3) {er=a-b-c;eh=static_cast<unsigned __int128>(a)<static_cast<unsigned __int128>(b)+c;}
      else {er=ar;eh=ar>>64;}
      m.zGPR.data[0]=a;m.zGPR.data[1]=b;m.zGPR.data[2]=hi;m.zCF=c;m.zOF=c;m.zRIP=0x1000+op*0x100;
      m.zstep(UNIT);
      u64 actualhi=op<2?u64(m.zGPR.data[2]):op==5?u64(m.zOF):u64(m.zCF);
      if(m.zfault_pending || u64(m.zGPR.data[0])!=er || actualhi!=eh) {
        printf("FAIL %s i=%d a=%016lx b=%016lx hi=%016lx c=%d result=%016lx high=%016lx expected=%016lx high=%016lx fault=%d\n",names[op],i,a,b,hi,c,u64(m.zGPR.data[0]),actualhi,er,eh,int(m.zfault_pending));++fails;break;
      }
      if(i==9999)printf("PASS %s 10000 cases\n",names[op]);
    }
  }
  m.model_fini();return fails!=0;
}
