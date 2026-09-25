# MS-DOS 6.22 and Windows 3.1 boot results

Worktree `/home/ruiu/sail-x86-os6`, branch `os-boot-msdos`, starting at
`18e90a9`. Work started 2026-09-25 01:19 UTC. All emulator runs use
`build/llvm/sail-x86-system` built with sail-llvm. No official Sail
compiler, CMake build, or CTest target is used. Original installation
media and the earlier worktrees remain read only.

## Result

**Both requested boot milestones succeeded.** MS-DOS 6.22 was installed
from the supplied CD onto a fresh IDE disk and booted to its own prompt.
Windows 3.1 Express Setup completed on that disk. A fresh boot and plain
`WIN` reached Program Manager; its About dialog explicitly says **386
Enhanced Mode**. A Windows-launched DOS session runs in virtual-8086 mode,
returns to Program Manager, and Windows then exits cleanly to DOS.

* [MS-DOS 6.22 prompt, VER and DIR](os-boot/msdos622-hdd-ver-dir.png)
* [Windows Setup complete](os-boot/win31-msdos-setup-complete.png)
* [Program Manager desktop](os-boot/win31-msdos-program-manager.png)
* [About: 386 Enhanced Mode](os-boot/win31-msdos-enhanced-about.png)
* [DOS prompt inside Windows](os-boot/win31-msdos-vm86-prompt.png)
* [CPU virtual-8086 evidence](os-boot/win31-msdos-vm86-state.txt)

The new model fix is **`115a374`**, F2 repeat prefixes. The prerequisite
IRET fix, absent from the supplied starting commit, is brought in as
**`4b3262a`** (cherry-pick of `42d5f05`). Both commits contain their
regressions and SDM citations. **`d5bfdd6`** records the DOS installation.
No device-model changes were needed to achieve these milestones.

Final validation: **80 basic cases, all 14 C++ system suites, PNG checks,
and all 416 VM86/KVM comparisons pass**, using sail-llvm exclusively.
The final FAT16 partition also passes a read-only filesystem check.

## Media and disk preparation

The supplied `msdos622.iso` has an El Torito 1.44 MB floppy image at ISO
LBA 26 and a duplicate collection of DOS files in the ISO filesystem.
It has **no DOS SETUP.EXE**. Installation therefore uses the supplied
Microsoft FDISK, FORMAT /S, and COPY programs. The boot image's Oak CD-ROM
driver reports no drives, but the DOS installation files are accessible
as A: through SeaBIOS's floppy emulation.

```sh
mkdir -p build/os-boot docs/os-boot
cp /home/ruiu/os-images/msdos622.iso build/os-boot/msdos622.iso
truncate -s 128M build/os-boot/msdos622.img
7z x -y -obuild/os-boot/win31-source /home/ruiu/os-images/win31.iso
```

The first CD boot reached [the DOS prompt](os-boot/msdos-cd-prompt.png).
Keyboard input `FDISK`, Enter, Enter, Enter created the maximum-size active
primary DOS partition. Its MBR entry is type 06, starting at sector 63,
length 261009 sectors, matching the BIOS 16-head/63-sector geometry.
[FDISK restart page](os-boot/msdos-fdisk-created.png).

## F2 repeat-prefix defect

The first FORMAT /S reported success but wrote an invalid boot-sector BPB:
8 sectors/cluster, 8 sectors/FAT, 17 sectors/track, 4 heads, hidden sector 1,
and total size 20739 sectors. Its filesystem-type text was just `F` followed
by spaces. A fresh hard-disk boot stalled before DOS. The disk is preserved
as `build/os-boot/msdos622-bad-bpb.img`.

A QEMU TCG/Pentium control formatted the same partition correctly (4 sectors
per cluster, 255 sectors/FAT, 63 sectors/track, 16 heads, hidden sector 63,
261009 total sectors, `FAT16`). RAM inspection identified `F2 A4` at physical
0x1790a copying the 25-byte BPB, and `F2 A5` in the Microsoft MBR copying
256 words. The model ignored F2 on these operations and copied only one
unit. Its existing F3 path was correct.

Intel SDM rev.090 Vol.2A §2.1.1, p.2-2 specifies F2/F3 repeat prefixes for
MOVS, CMPS, SCAS, LODS, STOS, INS and OUTS. Vol.1 §7.3.9.2 restricts
ZF-conditioned repeat behavior to CMPS/SCAS. The fix routes both F2 and F3
to count-only repetition for the other five operations.

Before the fix, the new real-mode matrix fails and all 48 new VM86/KVM
comparisons fail (the existing 368 pass). The matrix covers byte/word/dword
operations, both DF and ZF values, zero and nonzero CX, segmented pointers,
and preservation of the upper half of ECX. After rebuilding, all 14 C++
system suites and PNG validation pass; the basic suite reports 79/79 and all 416 VM86/KVM comparisons pass.
[Full validation log](os-boot/msdos-f2-validation.txt). The fix and tests
are committed together as `115a374`.

The QEMU control used:

```sh
qemu-system-i386 -L /home/ruiu/qemu/pc-bios -machine pc -accel tcg \
  -cpu pentium -m 16 \
  -drive file=build/os-boot/msdos-qemu-format.img,format=raw \
  -cdrom build/os-boot/msdos622.iso -boot d -display none \
  -qmp unix:build/os-boot/msdos-qemu.sock,server=on,wait=off \
  -serial file:build/os-boot/msdos-qemu.serial -no-reboot
```

Its disk was a separate zero-filled 128 MB image with only the Sail-created
MBR copied in. QMP keyboard input ran `FORMAT C: /S`, answered Y, and set
the label MSDOS622. The control did not modify the installation disk. This
QEMU control was not instruction-counted or timed by the Sail runner.


## MS-DOS hard-disk installation completed

After `115a374`, FORMAT /S creates a valid FAT16 volume and transfers the
Microsoft system files. `MD C:\DOS` and `COPY A:*.* C:\DOS` copy the DOS
utilities. Keyboard `ECHO` commands create these startup files:

```ini
DEVICE=C:\DOS\HIMEM.SYS
DOS=HIGH
FILES=30
BUFFERS=20
```

```bat
@ECHO OFF
PROMPT $P$G
PATH C:\DOS
```

A fresh boot with no floppy or CD attached reaches `C:\>`. `VER` reports
**MS-DOS Version 6.22** and `DIR` lists COMMAND.COM, DOS, CONFIG.SYS and
AUTOEXEC.BAT, with 131,852,288 bytes free.
[Hard-disk prompt, VER and DIR](os-boot/msdos622-hdd-ver-dir.png).
The installed DOS disk is preserved as `build/os-boot/msdos622-verified.img`.

### DOS attempts

Every command below has `SAIL_X86_BIOS_DEBUG=1` in its environment.
All COM1 logs are empty; DOS output comes from the VGA captures.
The runner records time and instruction counts; SIGUSR1 captures CPU,
devices, text display and RAM; SIGUSR2 captures PNGs. Manual keyboard
bytes are paced at 0.1 seconds each through `/proc/PID/fd/0`.

#### msdos-cd-01

CD prompt; FDISK creates the active DOS partition.

```sh
SAIL_X86_BIOS_DEBUG=1 python3 system-emu/run-boot.py --name msdos-cd-01 --timeout 1800 -- build/llvm/sail-x86-system -ips 4 -m 16 -kbd -b build/bios.bin -hda build/os-boot/msdos622.img -cdrom build/os-boot/msdos622.iso -boot d
```

Wall: **72.027 s**; instructions: **342,312,090**; return: `0`; stopped manually. Last serial output: `(none)`.

Additional keyboard input:

```text
2026-09-25 01:20:34 UTC: fdisk\n
2026-09-25 01:20:46 UTC: \n\n
2026-09-25 01:20:56 UTC: \n
```

#### msdos-format-02

FORMAT /S and file copy report success, but BPB is invalid.

```sh
SAIL_X86_BIOS_DEBUG=1 python3 system-emu/run-boot.py --name msdos-format-02 --timeout 1200 --send '15:format c: /s\n' -- build/llvm/sail-x86-system -ips 4 -m 16 -kbd -b build/bios.bin -hda build/os-boot/msdos622.img -cdrom build/os-boot/msdos622.iso -boot d
```

Wall: **102.444 s**; instructions: **515,358,640**; return: `0`; stopped manually. Last serial output: `(none)`.

Additional keyboard input:

```text
2026-09-25 01:21:43 UTC: y\n
2026-09-25 01:22:05 UTC: MSDOS622\n
2026-09-25 01:22:08 UTC: md c:\\dos\ncopy a:*.* c:\\dos\n
2026-09-25 01:22:44 UTC: echo device=c:\\dos\\himem.sys > c:\\config.sys\necho dos=high >> c:\\config.sys\necho files=30 >> c:\\config.sys\necho buffers=20 >> c:\\config.sys\necho @echo off > c:\\autoexec.bat\necho prompt $p$g >> c:\\autoexec.bat\necho path c:\\dos >> c:\\autoexec.bat\n
```

#### msdos-hdd-03

First hard-disk boot stalls in BIOS; F2 MBR relocation is incomplete.

```sh
SAIL_X86_BIOS_DEBUG=1 python3 system-emu/run-boot.py --name msdos-hdd-03 --timeout 600 -- build/llvm/sail-x86-system -ips 4 -m 16 -kbd -b build/bios.bin -hda build/os-boot/msdos622.img -boot c
```

Wall: **39.417 s**; instructions: **106,767,116**; return: `0`; stopped manually. Last serial output: `(none)`.

#### msdos-format-04

After F2 fix: FORMAT /S and DOS file installation succeed.

```sh
SAIL_X86_BIOS_DEBUG=1 python3 system-emu/run-boot.py --name msdos-format-04 --timeout 900 --send '15:format c: /s\n' -- build/llvm/sail-x86-system -ips 4 -m 16 -kbd -b build/bios.bin -hda build/os-boot/msdos622-fixed.img -cdrom build/os-boot/msdos622.iso -boot d
```

Wall: **105.248 s**; instructions: **515,875,748**; return: `0`; stopped manually. Last serial output: `(none)`.

Additional keyboard input:

```text
2026-09-25 01:29:20 UTC: y\n
2026-09-25 01:29:32 UTC: MSDOS622\n
2026-09-25 01:29:35 UTC: md c:\\dos\ncopy a:*.* c:\\dos\n
2026-09-25 01:30:10 UTC: echo device=c:\\dos\\himem.sys > c:\\config.sys\necho dos=high >> c:\\config.sys\necho files=30 >> c:\\config.sys\necho buffers=20 >> c:\\config.sys\necho @echo off > c:\\autoexec.bat\necho prompt $p$g >> c:\\autoexec.bat\necho path c:\\dos >> c:\\autoexec.bat\n
```

#### msdos-hdd-05

Hard-disk MS-DOS 6.22 prompt, VER and DIR verified.

```sh
SAIL_X86_BIOS_DEBUG=1 python3 system-emu/run-boot.py --name msdos-hdd-05 --timeout 600 -- build/llvm/sail-x86-system -ips 4 -m 16 -kbd -b build/bios.bin -hda build/os-boot/msdos622-fixed.img -boot c
```

Wall: **52.821 s**; instructions: **234,488,055**; return: `0`; stopped manually. Last serial output: `(none)`.

Additional keyboard input:

```text
2026-09-25 01:30:46 UTC: ver\ndir\n
```


## Windows 3.1 Express Setup

Installation files were extracted from the read-only UDF ISO with 7-Zip and
added to a copy of the verified MS-DOS disk while the emulator was stopped:

```sh
cp --reflink=auto build/os-boot/msdos622-verified.img build/os-boot/win31-msdos-clean.img
mmd -i build/os-boot/win31-msdos-clean.img@@32256 ::WIN31
mcopy -i build/os-boot/win31-msdos-clean.img@@32256 build/os-boot/win31-source/* ::WIN31
cp --reflink=auto build/os-boot/win31-msdos-clean.img build/os-boot/win31-msdos.img
```

The first run starts `C:\WIN31\SETUP` through the keyboard, selects
[Express Setup](os-boot/win31-msdos-express.png), reaches the graphical
[name confirmation](os-boot/win31-msdos-name.png), then loops in DOSX after
confirming the name. [Stalled setup](os-boot/win31-msdos-iret-stop.png).
The saved CPU state remains in 16-bit protected-mode DOSX selector 0053,
CPL 3. Inspection shows the IRET implementation still changes IOPL at CPL 3.

Although `18e90a9` contains the earlier call-gate/LDT/VM86 work, it does
**not** contain `42d5f05`, the IRET privilege correction documented in the
previous session. That existing fix, regression and diagnostic are brought
in with `git cherry-pick 42d5f05`, producing **`4b3262a`**. Its Intel SDM
rev.090 citation is Vol.2A IRET, pp.3-493 and 3-495. No new workaround is
applied to DOS or Windows. Setup is retried from `win31-msdos-clean.img`.

### win31-msdos-setup-06

Express Setup reaches name confirmation, then stalls in DOSX before graphical file copy. Stopped manually to bring in the missing IRET fix.

```sh
SAIL_X86_BIOS_DEBUG=1 python3 system-emu/run-boot.py --name win31-msdos-setup-06 --timeout 1800 -- build/llvm/sail-x86-system -ips 4 -m 16 -kbd -b build/bios.bin -hda build/os-boot/win31-msdos.img -boot c
```

Wall: **177.069 s**; instructions: **836,808,898**; return: `0`; runner result: `exit`. Last serial output: `(none)`.

Additional keyboard input:

```text
2026-09-25 01:31:55 UTC: cd \\win31\nsetup\n
2026-09-25 01:32:06 UTC: \n
2026-09-25 01:32:13 UTC: \n
2026-09-25 01:32:43 UTC: Sail Test\n
2026-09-25 01:32:56 UTC: \n
```


Rebuild after the cherry-pick: `system-emu/build-llvm.sh`. Direct test
builds are preserved in [msdos-build-tests.py](os-boot/msdos-build-tests.py);
the model object and runtime are exclusively sail-llvm outputs. All 14 C++
system suites pass (basic 80/80), PNG checks pass, and all 416 VM86/KVM
cases pass. [Validation log](os-boot/msdos-iret-validation.txt).
[Keyboard/capture helper](os-boot/msdos-control.py) records each manual
input with UTC time; it sends SIGUSR1/SIGUSR2 for captures.

The fresh attempt now passes name confirmation and reaches
[graphical file copy](os-boot/win31-msdos-copy.png), including
[386 enhanced-mode files](os-boot/win31-msdos-enhanced-files.png).

### win31-msdos-setup-07

Express Setup completes successfully. Name: Sail Test; no printer; unknown EDIT.EXE classified as None of the above; tutorial skipped. The Reboot button successfully restarts MS-DOS, with the Setup-installed SMARTDrive configuration.

```sh
SAIL_X86_BIOS_DEBUG=1 python3 system-emu/run-boot.py --name win31-msdos-setup-07 --timeout 1800 -- build/llvm/sail-x86-system -ips 4 -m 16 -kbd -b build/bios.bin -hda build/os-boot/win31-msdos.img -boot c
```

Wall: **280.526 s**; final instruction count: **133,897,605**; return: `0`;
runner result: `exit`. Last serial output: `(none)`. The emulator resets
its instruction counter during the guest reboot: the final count covers
the subsequent DOS boot, not the whole Setup run. The last pre-reboot
capture is at **1,004,882,547** instructions.

Additional keyboard input:

```text
2026-09-25 01:35:22 UTC: cd \\win31\nsetup\n
2026-09-25 01:35:31 UTC: \n
2026-09-25 01:35:36 UTC: \n
2026-09-25 01:36:15 UTC: Sail Test\n\n
2026-09-25 01:37:58 UTC: \n
2026-09-25 01:38:26 UTC: \x01d\n
2026-09-25 01:38:55 UTC: \t\n
2026-09-25 01:39:08 UTC: \n
```


### win31-msdos-enhanced-08

Fresh installed MS-DOS boot; plain WIN reaches Program Manager. About Program Manager explicitly confirms 386 Enhanced Mode. COMMAND.COM runs as a virtual-8086 DOS session, VER reports 6.22, EXIT returns to the desktop, and File/Exit Windows returns cleanly to DOS. SMARTDRV /C flushes the disk before stopping.

```sh
SAIL_X86_BIOS_DEBUG=1 python3 system-emu/run-boot.py --name win31-msdos-enhanced-08 --timeout 1200 -- build/llvm/sail-x86-system -ips 4 -m 16 -kbd -b build/bios.bin -hda build/os-boot/win31-msdos.img -boot c
```

Wall: **221.499 s**; instructions: **724,157,643**; return: `0`; runner result: `exit`. Last serial output: `(none)`.

Additional keyboard input:

```text
2026-09-25 01:40:02 UTC: win\n
2026-09-25 01:40:40 UTC: \x010h
2026-09-25 01:40:47 UTC: a
2026-09-25 01:41:09 UTC: \n\x010fr
2026-09-25 01:41:19 UTC: command.com\n
2026-09-25 01:41:46 UTC: ver\n
2026-09-25 01:41:47 UTC: exit\n
2026-09-25 01:42:08 UTC: \x010fx
2026-09-25 01:42:20 UTC: \n
2026-09-25 01:42:48 UTC: smartdrv /c\n
```


## Final evidence and preserved disks

The enhanced-mode capture is from the installed disk booted with **plain
WIN**, with no `/S` switch or Windows configuration edits. Express Setup
adds SMARTDrive, its double-buffer device, STACKS=9,256, the Windows PATH
entry and TEMP directory. The chosen display is the default VGA driver.

About Program Manager reports Windows 3.1 and **386 Enhanced Mode**.
File / Run `COMMAND.COM` opens the DOS session. At instruction 335,999,356,
the CPU dump records `mode=V`, CPL=3, CR0=0x8000003b, CR3=0x003dc000,
and VM86 segment caches. `VER` there reports MS-DOS 6.22. `EXIT` returns
to [the desktop](os-boot/win31-msdos-returned-desktop.png). File / Exit
Windows then returns to [the DOS prompt](os-boot/win31-msdos-exited-to-dos.png).
`SMARTDRV /C` completes before terminating the emulator and copying the
final disk.

All writable images are under ignored `build/os-boot/`:

| Image | Contents |
|---|---|
| `msdos622-verified.img` | Freshly installed and verified MS-DOS 6.22 |
| `win31-msdos-clean.img` | Verified DOS plus original C:\WIN31 setup files, before Setup |
| `win31-msdos-installed.img` | Completed Express Setup, before the enhanced-mode run |
| `win31-msdos-enhanced.img` | Final disk after enhanced-mode desktop, VM86 DOS session, clean Windows exit and cache flush |
| `msdos622-bad-bpb.img` | Preserved pre-F2-fix failed installation |
| `win31-msdos-iret-stop.img` | Preserved Setup attempt before the IRET fix |

[Media, firmware and successful disk SHA-256 hashes](os-boot/msdos-images.sha256).
The final partition was copied, then checked without writes:

```sh
fsck.fat -n build/os-boot/msdos-final-fat16.img
```

[Filesystem check](os-boot/msdos-final-fsck.txt): 730 files, 9300/65116
clusters; exit status 0, no errors reported.

To reproduce the final boot, use a writable copy of the preserved image:

```sh
cp --reflink=auto build/os-boot/win31-msdos-enhanced.img build/os-boot/win31-msdos-replay.img
SAIL_X86_BIOS_DEBUG=1 python3 system-emu/run-boot.py \
  --name win31-msdos-replay --timeout 1200 -- \
  build/llvm/sail-x86-system -ips 4 -m 16 -kbd -b build/bios.bin \
  -hda build/os-boot/win31-msdos-replay.img -boot c
# In another terminal, after the DOS prompt:
python3 docs/os-boot/msdos-control.py win31-msdos-replay send 'win\n'
python3 docs/os-boot/msdos-control.py win31-msdos-replay capture
```

Rebuilds: `system-emu/build-llvm.sh`; regression builds:
`python3 docs/os-boot/msdos-build-tests.py`. That script uses at most eight
compiler processes. Run `build/llvm/test-basic`, the other generated
`build/llvm/test-*` executables, and
`python3 system-emu/tests/test-png.py build/llvm/test-vbe` directly.
No official Sail compiler, CMake model build, or CTest target was used.

Eight Sail boot attempts total **1051.051 seconds** of measured
runner wall time. Work completed around 2026-09-25 01:46 UTC, about 27
minutes after starting, within the two-hour budget. All COM1 logs are
empty; VGA screenshots and CPU/device dumps are the evidence.
