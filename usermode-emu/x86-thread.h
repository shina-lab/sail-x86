#pragma once

#include "sail_x86_model.h"
#include <atomic>
#include <condition_variable>
#include <mutex>
#include <pthread.h>
#include <unordered_map>
#include <vector>

struct ProcessState;

// Per-thread information stored in the shared process state.
struct ThreadInfo {
  x86::Model *model;
  ProcessState *process = nullptr;
  u64 clear_child_tid = 0;
  pthread_t pthread;
  pid_t tid;
  std::atomic<bool> alive{true};
};

// Shared state across all threads in the emulated process.
struct ProcessState {
  // Process-wide exit flag.  Set by exit_group(); each thread checks this.
  std::atomic<bool> exiting{false};
  std::atomic<int> exit_code{0};

  // brk heap (shared across threads)
  std::mutex brk_mutex;
  u64 brk_base = 0;
  u64 brk_current = 0;
  u64 brk_limit = 0;

  // Thread registry
  std::mutex thread_mutex;
  std::vector<ThreadInfo *> threads;
  std::atomic<pid_t> next_tid;

  // Futex support
  struct FutexWaiter {
    std::condition_variable cv;
    bool woken = false;
  };
  std::mutex futex_mutex;
  std::unordered_multimap<u64, FutexWaiter *> futex_waiters;

  // Debug mode
  bool debug = false;

  pid_t alloc_tid() { return next_tid.fetch_add(1); }

  void register_thread(ThreadInfo *info) {
    std::lock_guard<std::mutex> lock(thread_mutex);
    threads.push_back(info);
  }

  void exit_all(int code) {
    exit_code.store(code);
    exiting.store(true);
  }

  int futex_wait(u64 uaddr, u32 expected);
  int futex_wake(u64 uaddr, int count);
};

// Copy CPU register state from parent to child model.
// Both models must have been model_init()'d first.
void clone_cpu_state(x86::Model &child, const x86::Model &parent);

// Thread entry point — runs the emulator step loop.
void *thread_entry(void *arg);

// Global mutex for Sail model execution.  The generated Sail C++ code uses
// ~50K file-scope temporaries (pre-allocated mpz_t/lbits scratch), making
// concurrent zstep() calls unsafe.  All threads must hold this lock while
// calling zstep() or emulate_syscall().
extern std::mutex sail_step_mutex;
