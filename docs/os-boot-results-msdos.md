# MS-DOS 6.22 and Windows 3.1 boot results

Worktree `/home/ruiu/sail-x86-os6`, branch `os-boot-msdos`, starting at
`18e90a9`. Work started 2026-09-25 01:19 UTC. All emulator runs use
`build/llvm/sail-x86-system` built with sail-llvm. No official Sail
compiler, CMake build, or CTest target is used. Original installation
media and the earlier worktrees remain read only.

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
and preservation of the upper half of ECX. After rebuilding, all 14 C++ system suites and PNG validation pass;
the basic suite reports 79/79 and all 416 VM86/KVM comparisons pass.
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
MBR copied in. The control did not modify the installation disk.


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

