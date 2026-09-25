# Alpine Linux 3.24.2 live-CD boot

Worktree `sail-x86-os4`, branch `os-boot-alpine`, starting at `18e90a9`.
Session date: 2026-09-25 UTC. All emulator and system-test builds use
sail-llvm. A mistaken official-compiler comparison-test invocation in the
resumed session is disclosed below. Original media and other worktrees
are read only. Each full boot attempt has a 2,400-second wall limit.
The initial session budget was about two hours; the resumed session has
an approximately 90-minute budget.

## Platform and reproduction

The existing `build/llvm/sail-x86-system`, SeaBIOS `build/bios.bin`, and
SeaVGABIOS `build/vgabios.bin` are the supplied builds. RAM is 512 MiB,
virtual CPU speed 20 MIPS. The initial serial attempt retains the earlier
`noapic nolapic` options to compare with the previous boot-media stall.
`debug_init` enables initramfs shell and nlplug-findfs diagnostics.

SHA-256 before the attempts:

```text
3ab424762af704b2c2a9e57df1dc37f982af260071504d977f2fb96822e7130b  alpine-virt-3.24.2-x86_64.iso
983c060418c11d625cb53cb86856b8c413c8e578df148043202dabce2a6073eb  build/llvm/sail-x86-system
888830e2b45d64866b461ebfc27aaaa6fa60e993f557a8dd1cc5abad2bd36d44  build/bios.bin
62c8300e0fa564fd26b596fa4327b081fc159e828a0330ec45b61cd428919d55  build/vgabios.bin
```

Raw runner logs, input records and RAM snapshots are in `build/os-boot/`.
Preserved serial logs and PNGs are linked below. SIGUSR1 captures CPU,
interrupt controllers, timers, IDE state, VGA and RAM; SIGUSR2 captures
the VGA framebuffer. A serial console need not appear on that framebuffer.

## Attempts

### alpine-01: boot-prompt timing setup

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_IDE_TRACE=1 python3 system-emu/run-boot.py --name alpine-01 --timeout 2400 --expect ALPINE_BOOT_VERIFIED --send '5:/boot/vmlinuz-virt initrd=/boot/initramfs-virt console=ttyS0,115200 modules=loop,squashfs,sd-mod,usb-storage noapic nolapic tsc=reliable nokaslr debug_init\n' -- build/llvm/sail-x86-system -m 512 -ips 20 -b build/bios.bin -cdrom /home/ruiu/os-images/alpine-virt-3.24.2-x86_64.iso -boot d
```

Stopped manually after **96.269 s / 458,368,665 instructions**, exit 0.
The ISO's `TIMEOUT 10` is one second: the scheduled serial input missed
the prompt and the default entry started without the requested console.
This was an input-timing setup failure, not an observed guest failure.
Last serial output: `boot:`. [Serial](os-boot/alpine-01.serial),
[VGA PNG](os-boot/alpine-01.png), [runner record](os-boot/alpine-01.json).

### alpine-02: serial boot with init/IDE diagnostics

The [input controller](os-boot/alpine-console.py) starts the standard
runner and sends the kernel command line as soon as `boot:` appears.
It records each input and elapsed wall time, then waits for a root login
and runs `uname -a` and `mount`. The verification marker matches a whole
output line so that command echo cannot terminate the run prematurely.

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_IDE_TRACE=1 python3 docs/os-boot/alpine-console.py --name alpine-02 --bootline '/boot/vmlinuz-virt initrd=/boot/initramfs-virt console=ttyS0,115200 modules=loop,squashfs,sd-mod,usb-storage noapic nolapic tsc=reliable nokaslr debug_init' -- build/llvm/sail-x86-system -m 512 -ips 20 -b build/bios.bin -cdrom /home/ruiu/os-images/alpine-virt-3.24.2-x86_64.iso -boot d
```

ISOLINUX accepted the command at 3.704 s. Linux reached `/init` at guest
58.003 s (about eight minutes wall time), then `Mounting boot media` at
guest 64.320 s. It completed 31 `mdev` children and stopped before the
32nd spawn. The last completed child was PID 702, event SEQNUM 692,
`ttyS2`. Stopped for the diagnosed model fix after **969.770 s /
2,490,233,931 instructions**, exit 0. No login or shell was reached.

[Serial](os-boot/alpine-02.serial), [VGA PNG](os-boot/alpine-02.png),
[runner record](os-boot/alpine-02.json), [inputs](os-boot/alpine-02.inputs.json),
[CPU/device state](os-boot/alpine-02-state.txt),
[task inspection](os-boot/alpine-02-tasks.txt).

### Diagnosed XADD restart defect — `23c4e2f`

The final snapshots show the CPU idling with interrupts enabled and the
PIT advancing. No IDE command is pending. PID 1 is waiting for its child;
`nlplug-findfs`'s main thread (446) is blocked in `fork()` on musl's random
lock, whose value is `0xffffffff`. Its remaining worker (447) is waiting
on the trigger condition variable. There is no live `mdev` child.

The snapshot uses the ISO's own System.map and BTF, inspected by
[inspect-alpine.py](os-boot/inspect-alpine.py). The stack listings are
candidate text addresses, not an ORC unwind; saved syscall frames identify
both futex waits. The main thread's libc base is `0x7fd70c685000`, its
saved userspace RIP is `base+0x66613` (the lock's futex syscall), and its
caller is `base+0x2fdba` (`fork`'s atfork-lock loop). Its loop index and
the pointer table identify `__random_lockptr` at `base+0xa7004`.

[musl's fork source](https://git.musl-libc.org/cgit/musl/tree/src/process/fork.c)
and the ISO's libc disassembly explain the failure: fork makes the lock
page copy-on-write; unlocking performs `LOCK XADD [lock], EAX` with
`EAX=0x7fffffff`. The model exchanged EAX with memory *before* attempting
the store. A write-protection page fault therefore left EAX changed.
The restarted instruction added the wrong value, corrupting the lock.
With lock value `0x80000001`, the faulty retry produces `2` instead of
`0`; repetition yields `2, 6, 14, ...`, explaining the 31 completed
children and the subsequent permanent lock wait. This is independent of
the CD-ROM implementation.

Intel SDM revision 090, **Vol.3A §7.5, Exception Classifications**, requires
faults to restore the state preceding the faulting instruction. **Vol.2D,
XADD, pp.6-26–6-27** specifies its result and page-fault exception.
The fix commits the memory store before the source register and flags.
It applies to byte, word, dword and qword memory operands.

The regression protects the destination page, checks unchanged source,
memory, RIP and arithmetic flags on `#PF`, repairs the PTE, then checks
the restarted result. Before the fix, the dword case changes RAX from
`0x123456787fffffff` to `0x80000001` on the fault.
[Failing result](os-boot/alpine-xadd-before.txt).

Validation uses only sail-llvm and clang++:

```sh
system-emu/build-llvm.sh
python3 docs/os-boot/build-alpine-tests.py
```

[Build](os-boot/alpine-xadd-build.txt); all **19 paging** cases
([log](os-boot/alpine-xadd-paging.txt)), **78 basic** cases
([log](os-boot/alpine-xadd-basic.txt)), and **26 exception** cases
([log](os-boot/alpine-xadd-exceptions.txt)) pass.
The new regression covers all four XADD widths.

Rebuilt emulator SHA-256:
`378aa1e2dd5e45e8dea3e1312c5dee2f5377be0b7b78994b61586b67e75c86d9`.

### alpine-03-xadd: retry with corrected XADD restart

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_IDE_TRACE=1 python3 docs/os-boot/alpine-console.py --name alpine-03-xadd --bootline '/boot/vmlinuz-virt initrd=/boot/initramfs-virt console=ttyS0,115200 modules=loop,squashfs,sd-mod,usb-storage noapic nolapic tsc=reliable nokaslr debug_init' -- build/llvm/sail-x86-system -m 512 -ips 20 -b build/bios.bin -cdrom /home/ruiu/os-images/alpine-virt-3.24.2-x86_64.iso -boot d
```

Interrupted when the preceding session reached its usage limit at
10:50 JST. Both the input controller and emulator were gone when work
resumed at 10:52 JST; no final runner JSON was written. The last serial
output records PID 768 / SEQNUM 766 being reaped, after **96** completed
`mdev` children, so the corrected XADD had passed the earlier 31-child
stall. The last available CPU/RAM snapshot is earlier, at **1,773,074,976
instructions**; it is not a final instruction count. No login or shell
was reached before interruption.

[Serial](os-boot/alpine-03-xadd.serial),
[VGA PNG](os-boot/alpine-03-xadd.png),
[last captured state](os-boot/alpine-03-xadd-state.txt),
[inputs](os-boot/alpine-03-xadd.inputs.json),
[controller note](os-boot/alpine-03-xadd.manual.json),
[progress observation](os-boot/alpine-03-xadd.observations.jsonl).

## Resumed session: 2026-09-25, 10:52 JST

The resumed session has an approximately 90-minute budget. Its first
build was `system-emu/build-llvm.sh`, using the corrected sail-llvm
checkout at `54a10b8` (polymorphic argument widths from extern parameter
types). No official Sail compiler or CMake/CTest model build was used.
The ISO and firmware hashes still match those recorded above, and the
CD-ROM device opens the ISO with `O_RDONLY`.

[Build log](os-boot/alpine-resume-build.txt). SHA-256:

```text
67215b2f00512e38b9a1232165d86ef4eff27153088cba382bf511738686984f  ~/sail-llvm/build/sailc
bf354a220fbfba4c6847c71a59734b60482f65ce865f41f8058de5f9ce5dc245  build/llvm/sail-x86-system
```

`python3 docs/os-boot/build-alpine-tests.py` rebuilt and passed all
**78 basic, 19 paging, and 26 exception cases**, including the XADD
restart regression for all four operand widths:
[basic](os-boot/alpine-resume-basic.txt),
[paging](os-boot/alpine-resume-paging.txt),
[exceptions](os-boot/alpine-resume-exceptions.txt).

### alpine-04-resume: fresh boot after sail-llvm rebuild

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_IDE_TRACE=1 python3 docs/os-boot/alpine-console.py --name alpine-04-resume --bootline '/boot/vmlinuz-virt initrd=/boot/initramfs-virt console=ttyS0,115200 modules=loop,squashfs,sd-mod,usb-storage noapic nolapic tsc=reliable nokaslr debug_init' -- build/llvm/sail-x86-system -m 512 -ips 20 -b build/bios.bin -cdrom /home/ruiu/os-images/alpine-virt-3.24.2-x86_64.iso -boot d
```

The fresh boot passed the XADD/mdev stall but could not find the boot
media. It entered an initramfs recovery shell. `uname -a`, `id` and
`mount` ran as root there; this was not a normal Alpine live-system login.
The initial [recovery PNG](os-boot/alpine-04-recovery.png) shows that state.

Only PCI slot 0 (the host bridge) remained in sysfs, although Linux had
enumerated the IDE and VGA functions earlier. Reading `/dev/port` showed
`ff` throughout the advertised GPE0 and PCI-hotplug registers. Linux's
`gpe01` counter showed one enabled, asserted event. A manual
`echo 1 > /sys/bus/pci/rescan` restored the IDE controller and `/dev/sr0`.
Rerunning `nlplug-findfs` and exiting the recovery shell let init mount
the CD read-only and proceed to APK installation. APK then rejected the
repository index with `BAD signature`, leaving no `/sysroot/sbin/init`.

Stopped for the diagnosed fixes after **2,219.739 s / 4,508,946,370
instructions**. Most of the latter wall time was interactive diagnosis.
The final framebuffer mirrors actual guest serial commands through
`tee -a /dev/tty1`.

[Serial](os-boot/alpine-04-resume.serial),
[final VGA PNG](os-boot/alpine-04-resume.png),
[runner record](os-boot/alpine-04-resume.json),
[boot inputs](os-boot/alpine-04-resume.inputs.json),
[manual input transcript](os-boot/alpine-04-resume.manual.jsonl),
[final state](os-boot/alpine-04-resume-state.txt).


### ACPI hotplug status fix — `31d7963`

The SeaBIOS tables advertise GPE0 at `0xafe0`–`0xafe3` and the PCI hotplug
register block at `0xae00`–`0xae0f`. The unimplemented I/O reads returned
`0xff`. SeaBIOS's `_E01` handler calls `PCNF`, which interprets the PCI
removal bitmap and sends eject notifications for slots 1–31. Thus the
initial GPE dispatch removed every enumerated slot except host-bridge
slot 0, including IDE and VGA.

The device now implements the fixed platform's idle hotplug registers:
zero event/status/removability masks and readable/writable GPE enable
bytes. There are no hotplug event producers or removable PCI slots;
status-clear and eject writes cannot remove the static devices. Adjacent
unimplemented ports keep their existing open-bus behavior. This follows
the [QEMU ACPI PCI hotplug interface](https://www.qemu.org/docs/master/specs/acpi_pci_hotplug.html)
used by the supplied SeaBIOS firmware; no CPU semantics changed.

The regression failed before the fix with GPE status `0xffff`
([before](os-boot/alpine-hotplug-before.txt)). It checks the status,
enable-byte behavior, removal/eject masks, IDE presence after eject
writes, and neighboring ports. Validation passed the ACPI/CPU,
firmware-config and seven IDE cases plus all 78 basic, 19 paging and
26 exception cases:
[build](os-boot/alpine-hotplug-build.txt),
[ACPI/CPU](os-boot/alpine-hotplug-apic-cpu.txt),
[firmware config](os-boot/alpine-hotplug-fw-cfg.txt),
[IDE](os-boot/alpine-hotplug-ide.txt),
[basic](os-boot/alpine-hotplug-basic.txt),
[paging](os-boot/alpine-hotplug-paging.txt),
[exceptions](os-boot/alpine-hotplug-exceptions.txt).

Emulator SHA-256:
`8f6bcbaa364fa037a99aaec09ea263b38e93c714ec0abd1d45126279b3a434c6`.

### alpine-05-hotplug: CD found automatically; APK verification fails

The alpine-04 command was repeated with `--name alpine-05-hotplug
--mirror-vga` and the rebuilt emulator. No guest PCI rescan was needed.
Linux bound `ata_piix`, found the ATAPI CD-ROM, and reported
`Mounting boot media: ok.` at guest 104.419 s. The ISO mounted read-only
on `/media/cdrom`.

APK reproduced `BAD signature` and `/sbin/init not found in new root`.
`uname -a`, `id` and `mount` ran in the recovery shell and were mirrored
to tty1 for the PNG. Stopped after **1,016.943 s / 3,166,136,495
instructions**, exit 0. There was no normal live-system login.

[Serial](os-boot/alpine-05-hotplug.serial),
[VGA PNG](os-boot/alpine-05-hotplug.png),
[runner record](os-boot/alpine-05-hotplug.json),
[boot inputs](os-boot/alpine-05-hotplug.inputs.json),
[manual inputs](os-boot/alpine-05-hotplug.manual.jsonl),
[final state](os-boot/alpine-05-hotplug-state.txt).

### Unsigned DIV compiler diagnosis and isolated fix

The guest and host SHA-256 hashes match for both the APK index and its
public key. Host OpenSSL verifies the index's RSA/SHA1 signature. Guest
SHA1 gives the same digest, but OpenSSL's raw RSA public operation gives
incorrect bytes. Disabling OpenSSL CPU acceleration does not fix it.
The signature format was checked against Alpine's
[APK specification](https://wiki.alpinelinux.org/wiki/Apk_spec).

A deterministic instruction diagnostic tested MUL, DIV, ADC, SBB, ADCX
and ADOX against host unsigned-128-bit arithmetic. DIV failed immediately:

```text
RDX:RAX = afe1f3ed928c2ab1:08d23fba8f3254e1
RCX     = b0a526350a0b27ea
expected quotient fee51d66fc2d6163, remainder 13fb37ed16a03b63
actual   quotient 8be42791d45df611, remainder cfbf99e8e417d257
```

The actual values exactly match signed 128-bit division. The Sail
`exec_div` definition already follows Intel SDM revision 090, Vol.2A,
DIV, pp.3-264–3-265: unsigned RDX:RAX division, with `#DE` if the
quotient exceeds 64 bits. The compiler lowered `unsigned(bits(128))`
into its signed-i128 integer representation and used signed division.
The same loss of unsigned interpretation also missed quotient overflow
for an all-ones dividend divided by one.

The shared `~/sail-llvm` checkout contains other work in progress and
was left untouched. An isolated clone at
`build/sail-llvm-unsigned`, based on `54a10b8`, contains compiler commit
**`3d01d86`**, preserved with its regression in
[alpine-sail-llvm-unsigned.patch](os-boot/alpine-sail-llvm-unsigned.patch).
It tracks proven nonnegative SSA values, including conditional joins,
and selects unsigned division/remainder/ordering for those values.
The fixed i128 ABI and signed operations for other values remain in
place; this is not arbitrary-precision integer support. The Sail model
itself was not changed for this compiler issue.

The minimal reproducer failed before the fix
([output](os-boot/alpine-compiler-div-before.txt)). The compiler's **500
sail-llvm-only tests pass**
([full log](os-boot/alpine-compiler-ctest.txt)). The system DIV regression
also fails with the original compiler
([before](os-boot/alpine-div-before.txt)), and passes after rebuilding.
It covers bit-127-set dividends, boundary quotients, divide overflow,
divide by zero, and preservation of the dividend on `#DE`.
The [arithmetic diagnostic source](os-boot/check-rsa-arithmetic.cpp)
passes 10,000 deterministic cases each for MUL, DIV, ADC, SBB, ADCX and
ADOX ([before](os-boot/alpine-rsa-arithmetic.txt),
[after](os-boot/alpine-rsa-arithmetic-after.txt)).

**Execution-rule mistake:** the first unanchored CTest selection also
selected `official_e2e_unsigned_division_128`. It invoked the official
Sail compiler, which rejected the small source at type checking before
producing a binary. This violated the user's rule and was immediately
disclosed. The [selection log](os-boot/alpine-compiler-selection-error.txt)
is retained. Official comparisons were then disabled with
`-DSAIL_ENABLE_OFFICIAL_E2E=OFF`, and the full suite also used
`-E '^official_'`. All emulator and system-test builds and boot runs
used sail-llvm throughout.

The clone's first CMake configure also unexpectedly started its LLVM
fallback build with excessive parallelism. Those processes were stopped;
the successful configure reused the existing LLVM installation through
a symlink, and subsequent builds were explicitly limited to 28 jobs
(or three system-test compiler jobs / eight CTest jobs).

Reproduction after applying the compiler patch to a sail-llvm checkout:

```sh
cmake -S build/sail-llvm-unsigned -B build/sail-llvm-unsigned/build -DSAIL_ENABLE_OFFICIAL_E2E=OFF
cmake --build build/sail-llvm-unsigned/build -j 28
ctest --test-dir build/sail-llvm-unsigned/build -E '^official_' -j 8 --output-on-failure
SAIL_LLVM="$PWD/build/sail-llvm-unsigned" system-emu/build-llvm.sh build/llvm-unsigned
python3 docs/os-boot/build-alpine-tests.py --out build/llvm-unsigned --sail-llvm build/sail-llvm-unsigned --log-prefix alpine-unsigned --tests basic paging exceptions apic-cpu fw-cfg ide
```

The clone uses the existing LLVM installation at
`~/sail-llvm/build/_deps/llvm/install` via
`build/sail-llvm-unsigned/build/_deps/llvm/install`.
[Emulator build](os-boot/alpine-unsigned-build.txt).
All **79 basic, 19 paging, 26 exception**, ACPI/CPU, firmware-config,
and seven IDE cases pass:
[basic](os-boot/alpine-unsigned-basic.txt),
[paging](os-boot/alpine-unsigned-paging.txt),
[exceptions](os-boot/alpine-unsigned-exceptions.txt),
[ACPI/CPU](os-boot/alpine-unsigned-apic-cpu.txt),
[firmware config](os-boot/alpine-unsigned-fw-cfg.txt),
[IDE](os-boot/alpine-unsigned-ide.txt).

```text
9d8f99b48c5681fd660a5c9ef49662e9ded68925a47b71389f0831e0d0eff3c7  build/sail-llvm-unsigned/build/sailc
60eaefa41c3f376270c9e83e7aaaa640ac7deec21de5158e9e26f99843045fbc  build/llvm-unsigned/sail-x86-system
```

### alpine-06-unsigned: retry with ACPI and compiler fixes

```sh
SAIL_X86_BIOS_DEBUG=1 SAIL_X86_IDE_TRACE=1 python3 docs/os-boot/alpine-console.py --name alpine-06-unsigned --mirror-vga --bootline '/boot/vmlinuz-virt initrd=/boot/initramfs-virt console=ttyS0,115200 modules=loop,squashfs,sd-mod,usb-storage noapic nolapic tsc=reliable nokaslr debug_init' -- build/llvm-unsigned/sail-x86-system -m 512 -ips 20 -b build/bios.bin -cdrom /home/ruiu/os-images/alpine-virt-3.24.2-x86_64.iso -boot d
```

In progress. This is a fresh boot with normal APK signature verification.
