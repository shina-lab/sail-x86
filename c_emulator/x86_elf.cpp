#include "integers.h"
#include "x86_cpuid.h"
#include "x86_elf.h"
#include <cstring>
#include <random>
#include <vector>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

static constexpr u64 AT_NULL = 0;
static constexpr u64 AT_PHDR = 3;
static constexpr u64 AT_PHENT = 4;
static constexpr u64 AT_PHNUM = 5;
static constexpr u64 AT_BASE = 7;
static constexpr u64 AT_ENTRY = 9;
static constexpr u64 AT_PLATFORM = 15;
static constexpr u64 AT_HWCAP = 16;
static constexpr u64 AT_RANDOM = 25;
static constexpr u64 AT_HWCAP2 = 26;
static constexpr u64 AT_EXECFN = 31;
static constexpr u64 AT_SYSINFO_EHDR = 33;


struct Ehdr {
  u8 e_ident[16];
  u16 e_type;
  u16 e_machine;
  u32 e_version;
  u64 e_entry;
  u64 e_phoff;
  u64 e_shoff;
  u32 e_flags;
  u16 e_ehsize;
  u16 e_phentsize;
  u16 e_phnum;
  u16 e_shentsize;
  u16 e_shnum;
  u16 e_shstrndx;
};

struct Phdr {
  u32 p_type;
  u32 p_flags;
  u64 p_offset;
  u64 p_vaddr;
  u64 p_paddr;
  u64 p_filesz;
  u64 p_memsz;
  u64 p_align;
};

static constexpr u32 PT_LOAD = 1;
static constexpr u32 PT_INTERP = 3;
static constexpr u32 PT_PHDR = 6;
static constexpr u16 ET_DYN = 3;
static constexpr u16 EM_X86_64 = 62;

static u8 *mmap_file(const std::string &path) {
  int fd = ::open(path.c_str(), O_RDONLY);
  if (fd < 0) return nullptr;
  struct stat st;
  if (fstat(fd, &st) < 0) { close(fd); return nullptr; }
  void *p = mmap(nullptr, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
  close(fd);
  return (p == MAP_FAILED) ? nullptr : (u8 *)p;
}

static const Ehdr *ehdr(u8 *elf) { return (const Ehdr *)elf; }

static const Phdr *phdr(u8 *elf, int i) {
  return (const Phdr *)(elf + ehdr(elf)->e_phoff + i * ehdr(elf)->e_phentsize);
}

static int phnum(u8 *elf) { return ehdr(elf)->e_phnum; }

static bool load_elf_segments(x86::Model &model, u8 *elf,
                              u64 bias, u64 &max_addr) {
  for (int i = 0; i < phnum(elf); i++) {
    const Phdr *ph = phdr(elf, i);
    if (ph->p_type != PT_LOAD) continue;

    u64 vaddr = ph->p_vaddr + bias;
    u64 memsz = ph->p_memsz;
    u64 filesz = ph->p_filesz;

    model.memory.map_range(vaddr, memsz);

    if (filesz > 0)
      model.memory.write(vaddr, elf + ph->p_offset, filesz);

    u64 end = vaddr + memsz;
    if (end > max_addr) max_addr = end;
  }
  return true;
}

static std::string find_interp(u8 *elf) {
  for (int i = 0; i < phnum(elf); i++) {
    const Phdr *ph = phdr(elf, i);
    if (ph->p_type == PT_INTERP) {
      const char *s = (const char *)(elf + ph->p_offset);
      size_t len = ph->p_filesz;
      while (len > 0 && s[len - 1] == '\0') len--;
      return std::string(s, len);
    }
  }
  return {};
}

ElfLoadResult load_elf(x86::Model &model, const std::string &filename) {
  ElfLoadResult result = {};

  u8 *mf = mmap_file(filename);
  if (!mf) {
    result.error = "Failed to open ELF file: " + filename;
    return result;
  }

  const Ehdr *eh = ehdr(mf);
  if (memcmp(eh->e_ident, "\177ELF", 4) != 0) {
    result.error = "Not an ELF file";
    return result;
  }
  if (eh->e_ident[4] != 2) {
    result.error = "Not a 64-bit ELF";
    return result;
  }
  if (eh->e_machine != EM_X86_64) {
    result.error = "Not an x86-64 ELF";
    return result;
  }

  bool is_pie = (eh->e_type == ET_DYN);
  u64 max_addr = 0;
  u64 prog_bias = is_pie ? 0x400000ULL : 0;

  load_elf_segments(model, mf, prog_bias, max_addr);

  result.prog_entry = eh->e_entry + prog_bias;

  result.phdr_num = eh->e_phnum;
  result.phdr_size = eh->e_phentsize;
  result.phdr_addr = 0;

  for (int i = 0; i < phnum(mf); i++) {
    const Phdr *ph = phdr(mf, i);
    if (ph->p_type == PT_PHDR) {
      result.phdr_addr = ph->p_vaddr + prog_bias;
      break;
    }
  }
  if (result.phdr_addr == 0) {
    for (int i = 0; i < phnum(mf); i++) {
      const Phdr *ph = phdr(mf, i);
      if (ph->p_type == PT_LOAD) {
        result.phdr_addr = ph->p_vaddr + prog_bias + eh->e_phoff;
        break;
      }
    }
  }

  std::string interp_path = find_interp(mf);
  if (!interp_path.empty()) {
    u8 *interp_elf = mmap_file(interp_path);
    if (!interp_elf) {
      result.error = "Failed to open interpreter: " + interp_path;
      return result;
    }

    u64 interp_base = 0x7FFFF7FC0000ULL;
    load_elf_segments(model, interp_elf, interp_base, max_addr);

    result.interp_base = interp_base;
    result.entry_point = ehdr(interp_elf)->e_entry + interp_base;
  } else {
    result.interp_base = 0;
    result.entry_point = result.prog_entry;
  }

  u64 brk_start = (max_addr + 4095) & ~4095ULL;
  model.memory.brk_base = brk_start;
  model.memory.brk_current = brk_start;

  result.success = true;
  return result;
}

u64 setup_stack(x86::Model &model, const ElfLoadResult &elf,
                int argc, char **argv, char **envp, char **auxv) {
  constexpr u64 STACK_TOP = 0x7FFFFFFFE000ULL;
  constexpr u64 STACK_SIZE = 8 * 1024 * 1024;
  u64 stack_base = STACK_TOP - STACK_SIZE;

  model.memory.map_range(stack_base, STACK_SIZE);

  u64 sp = STACK_TOP;

  std::vector<u64> argv_ptrs;
  std::vector<u64> envp_ptrs;

  for (int i = 0; i < argc; i++) {
    size_t len = strlen(argv[i]) + 1;
    sp -= len;
    model.memory.write(sp, argv[i], len);
    argv_ptrs.push_back(sp);
  }

  int envc = 0;
  if (envp) {
    for (int i = 0; envp[i]; i++) {
      size_t len = strlen(envp[i]) + 1;
      sp -= len;
      model.memory.write(sp, envp[i], len);
      envp_ptrs.push_back(sp);
      envc++;
    }
  }

  sp &= ~15ULL;

  sp -= 16;
  u64 random_addr = sp;
  {
    std::random_device rd;
    u8 random_bytes[16];
    for (int i = 0; i < 16; i++)
      random_bytes[i] = rd();
    model.memory.write(random_addr, random_bytes, 16);
  }

  sp -= 16;
  u64 platform_addr = sp;
  model.memory.write(platform_addr, "x86_64", 7);

  struct AuxEntry { u64 type; u64 val; };
  std::vector<AuxEntry> guest_auxv;

  // Pass through host auxiliary vector entries, overriding the ones
  // that must reflect the guest ELF layout or emulator capabilities,
  // and filtering out host-specific entries.
  u64 *host_auxv = (u64 *)auxv;
  for (int i = 0; host_auxv[i] || host_auxv[i + 1]; i += 2) {
    u64 type = host_auxv[i];
    u64 val = host_auxv[i + 1];
    switch (type) {
    case AT_SYSINFO_EHDR: continue;  // host vDSO, not applicable
    case AT_EXECFN:       val = argv_ptrs[0]; break;
    case AT_PHDR:     val = elf.phdr_addr; break;
    case AT_PHENT:    val = elf.phdr_size; break;
    case AT_PHNUM:    val = elf.phdr_num; break;
    case AT_BASE:     val = elf.interp_base; break;
    case AT_ENTRY:    val = elf.prog_entry; break;
    case AT_RANDOM:   val = random_addr; break;
    case AT_PLATFORM: val = platform_addr; break;
    case AT_HWCAP:    val = EMU_CPUID_1_EDX; break;
    case AT_HWCAP2:   val = EMU_CPUID_1_ECX; break;
    default: break;
    }
    guest_auxv.push_back({type, val});
  }
  guest_auxv.push_back({AT_NULL, 0});

  size_t entries_count = guest_auxv.size() * 2 + 1 + envp_ptrs.size() + 1 + argv_ptrs.size() + 1;
  size_t entries_bytes = entries_count * 8;

  sp -= entries_bytes;
  sp &= ~15ULL;

  u64 write_sp = sp;

  u64 val = (u64)argc;
  model.memory.write(write_sp, &val, 8); write_sp += 8;

  for (auto ptr : argv_ptrs) {
    model.memory.write(write_sp, &ptr, 8); write_sp += 8;
  }
  val = 0;
  model.memory.write(write_sp, &val, 8); write_sp += 8;

  for (auto ptr : envp_ptrs) {
    model.memory.write(write_sp, &ptr, 8); write_sp += 8;
  }
  model.memory.write(write_sp, &val, 8); write_sp += 8;

  for (auto &aux : guest_auxv) {
    model.memory.write(write_sp, &aux.type, 8); write_sp += 8;
    model.memory.write(write_sp, &aux.val, 8); write_sp += 8;
  }

  return sp;
}
