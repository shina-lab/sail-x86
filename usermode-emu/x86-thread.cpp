#include "x86-thread.h"
#include "x86-syscall.h"
#include <cassert>
#include <cerrno>
#include <cstdio>
#include <cstring>
#include <linux/futex.h>
#include <sys/syscall.h>
#include <unistd.h>

std::mutex sail_step_mutex;

template <typename T, size_t N>
static constexpr size_t array_len(const T (&)[N]) {
  return N;
}

// =========================================================================
// Futex support
// =========================================================================

int ProcessState::futex_wait(u64 uaddr, u32 expected) {
  // Atomically check *uaddr == expected, then sleep.
  // We must hold the futex_mutex while checking, so that a concurrent
  // futex_wake cannot slip between the check and the sleep.
  std::unique_lock<std::mutex> lock(futex_mutex);

  u32 actual = *reinterpret_cast<std::atomic<u32> *>(uaddr);
  if (actual != expected)
    return -EAGAIN;

  FutexWaiter waiter;
  auto it = futex_waiters.emplace(uaddr, &waiter);

  // Wait until woken or process is exiting.
  waiter.cv.wait(lock, [&] { return waiter.woken || exiting.load(); });

  futex_waiters.erase(it);
  return waiter.woken ? 0 : -EINTR;
}

int ProcessState::futex_wake(u64 uaddr, int count) {
  std::lock_guard<std::mutex> lock(futex_mutex);
  int woken = 0;
  auto range = futex_waiters.equal_range(uaddr);
  for (auto it = range.first; it != range.second && woken < count; ++it) {
    it->second->woken = true;
    it->second->cv.notify_one();
    woken++;
  }
  return woken;
}

// =========================================================================
// CPU state cloning
// =========================================================================

void clone_cpu_state(x86::Model &child, const x86::Model &parent) {
  fprintf(stderr, "clone_cpu_state: parent RIP=0x%lx RSP=0x%lx\n",
          (u64)parent.zRIP, (u64)parent.zGPR.data[4]);

  // GPRs
  for (size_t i = 0; i < array_len(parent.zGPR.data); i++)
    child.zGPR.data[i] = parent.zGPR.data[i];

  child.zRIP = parent.zRIP;
  fprintf(stderr, "clone_cpu_state: child RIP=0x%lx after copy\n", (u64)child.zRIP);

  // Segment registers
  for (size_t i = 0; i < array_len(parent.zSegReg.data); i++)
    child.zSegReg.data[i] = parent.zSegReg.data[i];

  // Flags
  child.zCF = parent.zCF;
  child.zPF = parent.zPF;
  child.zAF = parent.zAF;
  child.zZF = parent.zZF;
  child.zSF = parent.zSF;
  child.zOF = parent.zOF;
  child.zDF = parent.zDF;
  child.zIF_flag = parent.zIF_flag;
  child.zTF = parent.zTF;
  child.zIOPL = parent.zIOPL;
  child.zNT = parent.zNT;
  child.zRF = parent.zRF;
  child.zID = parent.zID;
  child.zAC_flag = parent.zAC_flag;

  // Mode
  child.zcur_mode = parent.zcur_mode;
  child.zcur_cpl = parent.zcur_cpl;
  child.zsystem_mode = parent.zsystem_mode;

  // Segment caches and bases
  for (int i = 0; i < 6; i++)
    child.zSegCache.data[i] = parent.zSegCache.data[i];
  child.zKERNEL_GS_BASE = parent.zKERNEL_GS_BASE;

  // Control registers
  child.zCR0 = parent.zCR0;
  child.zCR2 = parent.zCR2;
  child.zCR3 = parent.zCR3;
  child.zCR4 = parent.zCR4;
  child.zEFER = parent.zEFER;

  // Descriptor tables
  child.zGDTR_base = parent.zGDTR_base;
  child.zGDTR_limit = parent.zGDTR_limit;
  child.zIDTR_base = parent.zIDTR_base;
  child.zIDTR_limit = parent.zIDTR_limit;
  child.zLDTR = parent.zLDTR;
  child.zTR = parent.zTR;
  child.zTR_base = parent.zTR_base;
  child.zTR_limit = parent.zTR_limit;

  // FPU/SSE state
  child.mxcsr_state.mxcsr = parent.mxcsr_state.mxcsr;
  child.zx87_cw = parent.zx87_cw;
  child.zx87_sw = parent.zx87_sw;
  child.zx87_tw = parent.zx87_tw;

  // KREG (mask registers)
  for (size_t i = 0; i < array_len(parent.zKREG.data); i++)
    child.zKREG.data[i] = parent.zKREG.data[i];

  for (size_t i = 0; i < array_len(parent.zZMM.data); i++)
    COPY(lbits)(&child.zZMM.data[i], parent.zZMM.data[i]);

  for (size_t i = 0; i < array_len(parent.zx87_ST.data); i++)
    COPY(lbits)(&child.zx87_ST.data[i], parent.zx87_ST.data[i]);
}

// =========================================================================
// Thread entry point
// =========================================================================

void *thread_entry(void *arg) {
  ThreadInfo *info = static_cast<ThreadInfo *>(arg);
  x86::Model &model = *info->model;
  ProcessState *process = info->process;
  assert(process);
  u64 insn_count = 0;

  fprintf(stderr, "thread_entry: RIP=0x%lx RSP=0x%lx RAX=0x%lx\n",
          (u64)model.zRIP, (u64)model.zGPR.data[4], (u64)model.zGPR.data[0]);

  while (!model.should_exit &&
         !process->exiting.load(std::memory_order_relaxed)) {
    {
      std::lock_guard<std::mutex> lock(sail_step_mutex);
      model.zstep(UNIT);
    }

    if (model.zfault_pending) {
      i64 vec = model.zfault_vector;
      u32 err = model.zfault_error_code;
      fprintf(stderr, "sail-x86: thread %d: fault #%ld (error code 0x%x) at RIP=0x%lx after %lu instructions\n",
              info->tid, vec, err, (u64)model.zRIP, insn_count);
      process->exit_all(128 + (int)vec);
      break;
    } else if (model.zsystem_state == x86::zSysSyscall) {
      emulate_syscall(model);
      model.zsystem_state = x86::zSysRunning;
      insn_count++;
    } else {
      insn_count++;
    }
  }

  // Handle CLONE_CHILD_CLEARTID: write 0 to clear_child_tid and futex_wake it.
  if (info->clear_child_tid != 0) {
    *reinterpret_cast<u32 *>(info->clear_child_tid) = 0;
    process->futex_wake(info->clear_child_tid, 1);
  }

  info->alive.store(false);
  return nullptr;
}
