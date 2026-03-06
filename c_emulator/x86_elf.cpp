#include "integers.h"
#include "x86_elf.h"
#include <cstring>
#include <vector>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

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

struct MappedFile {
  u8 *data = nullptr;
  size_t size = 0;

  ~MappedFile() {
    if (data)
      munmap(data, size);
  }

  bool open(const std::string &path) {
    int fd = ::open(path.c_str(), O_RDONLY);
    if (fd < 0) return false;
    struct stat st;
    if (fstat(fd, &st) < 0) { close(fd); return false; }
    size = st.st_size;
    data = (u8 *)mmap(nullptr, size, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    return data != MAP_FAILED;
  }

  const Ehdr *ehdr() const { return (const Ehdr *)data; }

  const Phdr *phdr(int i) const {
    return (const Phdr *)(data + ehdr()->e_phoff + i * ehdr()->e_phentsize);
  }

  int phnum() const { return ehdr()->e_phnum; }
};

static bool load_elf_segments(x86::Model &model, MappedFile &mf,
                              u64 bias, u64 &max_addr) {
  for (int i = 0; i < mf.phnum(); i++) {
    const Phdr *ph = mf.phdr(i);
    if (ph->p_type != PT_LOAD) continue;

    u64 vaddr = ph->p_vaddr + bias;
    u64 memsz = ph->p_memsz;
    u64 filesz = ph->p_filesz;

    model.memory.map_range(vaddr, memsz);

    if (filesz > 0)
      model.memory.write(vaddr, mf.data + ph->p_offset, filesz);

    u64 end = vaddr + memsz;
    if (end > max_addr) max_addr = end;
  }
  return true;
}

static std::string find_interp(MappedFile &mf) {
  for (int i = 0; i < mf.phnum(); i++) {
    const Phdr *ph = mf.phdr(i);
    if (ph->p_type == PT_INTERP) {
      const char *s = (const char *)(mf.data + ph->p_offset);
      size_t len = ph->p_filesz;
      while (len > 0 && s[len - 1] == '\0') len--;
      return std::string(s, len);
    }
  }
  return {};
}

ElfLoadResult load_elf(x86::Model &model, const std::string &filename) {
  ElfLoadResult result = {};

  MappedFile mf;
  if (!mf.open(filename)) {
    result.error = "Failed to open ELF file: " + filename;
    return result;
  }

  if (mf.size < sizeof(Ehdr)) {
    result.error = "File too small for ELF header";
    return result;
  }

  const Ehdr *eh = mf.ehdr();
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

  for (int i = 0; i < mf.phnum(); i++) {
    const Phdr *ph = mf.phdr(i);
    if (ph->p_type == PT_PHDR) {
      result.phdr_addr = ph->p_vaddr + prog_bias;
      break;
    }
  }
  if (result.phdr_addr == 0) {
    for (int i = 0; i < mf.phnum(); i++) {
      const Phdr *ph = mf.phdr(i);
      if (ph->p_type == PT_LOAD) {
        result.phdr_addr = ph->p_vaddr + prog_bias + eh->e_phoff;
        break;
      }
    }
  }

  std::string interp_path = find_interp(mf);
  if (!interp_path.empty()) {
    MappedFile interp_mf;
    if (!interp_mf.open(interp_path)) {
      result.error = "Failed to open interpreter: " + interp_path;
      return result;
    }

    u64 interp_base = 0x7FFFF7FC0000ULL;
    load_elf_segments(model, interp_mf, interp_base, max_addr);

    result.interp_base = interp_base;
    result.entry_point = interp_mf.ehdr()->e_entry + interp_base;
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
                int argc, char **argv, char **envp) {
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
  u8 random_bytes[16] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16};
  model.memory.write(random_addr, random_bytes, 16);

  sp -= 16;
  u64 platform_addr = sp;
  model.memory.write(platform_addr, "x86_64", 7);

  struct AuxEntry { u64 type; u64 val; };
  std::vector<AuxEntry> auxv;
  auxv.push_back({3, elf.phdr_addr});
  auxv.push_back({4, elf.phdr_size});
  auxv.push_back({5, elf.phdr_num});
  auxv.push_back({6, 4096});
  auxv.push_back({7, elf.interp_base});
  auxv.push_back({9, elf.prog_entry});
  auxv.push_back({11, 1000});
  auxv.push_back({12, 1000});
  auxv.push_back({13, 1000});
  auxv.push_back({14, 1000});
  auxv.push_back({15, platform_addr});
  auxv.push_back({17, 100});
  auxv.push_back({23, 0});
  auxv.push_back({25, random_addr});
  auxv.push_back({0, 0});

  size_t entries_count = auxv.size() * 2 + 1 + envp_ptrs.size() + 1 + argv_ptrs.size() + 1;
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

  for (auto &aux : auxv) {
    model.memory.write(write_sp, &aux.type, 8); write_sp += 8;
    model.memory.write(write_sp, &aux.val, 8); write_sp += 8;
  }

  return sp;
}
