#!/bin/bash
# Build SeaBIOS firmware and create a bootable FreeDOS hard disk image.
#
# Usage: mk-freedos.sh <build-dir>
#
# Produces:
#   <build-dir>/bios.bin    — SeaBIOS firmware ROM
#   <build-dir>/freedos.img — 32MB bootable FreeDOS hard disk image

set -euo pipefail

BUILD_DIR="${1:?Usage: $0 <build-dir>}"
mkdir -p "$BUILD_DIR"

SEABIOS_VER="1.16.3"
SEABIOS_URL="https://www.seabios.org/downloads/seabios-${SEABIOS_VER}.tar.gz"
FREEDOS_URL="https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/distributions/1.3/official/FD13-FloppyEdition.zip"

WORK="$BUILD_DIR/freedos-build"
mkdir -p "$WORK"

# =========================================================================
# SeaBIOS
# =========================================================================

SEABIOS_SRC="$WORK/seabios-${SEABIOS_VER}"
BIOS_BIN="$BUILD_DIR/bios.bin"

if [ ! -f "$BIOS_BIN" ]; then
  echo "=== Building SeaBIOS ${SEABIOS_VER} ==="

  if [ ! -d "$SEABIOS_SRC" ]; then
    echo "Downloading SeaBIOS..."
    curl -L -o "$WORK/seabios.tar.gz" "$SEABIOS_URL"
    tar -xzf "$WORK/seabios.tar.gz" -C "$WORK"
  fi

  # Create minimal config.
  # CONFIG_QEMU=y is needed for CMOS-based RAM size detection.
  cat > "$SEABIOS_SRC/.config" <<'EOF'
CONFIG_QEMU=y
CONFIG_QEMU_HARDWARE=y
CONFIG_COREBOOT=n
CONFIG_CSM=n
CONFIG_ATA=y
CONFIG_ATA_DMA=n
CONFIG_ATA_PIO32=n
CONFIG_FLOPPY=n
CONFIG_FLASH_FLOPPY=n
CONFIG_USB=n
CONFIG_USB_UHCI=n
CONFIG_USB_OHCI=n
CONFIG_USB_EHCI=n
CONFIG_USB_XHCI=n
CONFIG_USB_MSC=n
CONFIG_USB_HUB=n
CONFIG_USB_KEYBOARD=n
CONFIG_USB_MOUSE=n
CONFIG_AHCI=n
CONFIG_NVME=n
CONFIG_SDCARD=n
CONFIG_VIRTIO_BLK=n
CONFIG_VIRTIO_SCSI=n
CONFIG_BOOTSPLASH=n
CONFIG_TCGBIOS=n
CONFIG_XEN=n
CONFIG_LZMA=n
CONFIG_HARDWARE_IRQ=y
CONFIG_DRIVES=y
CONFIG_CDROM_BOOT=n
CONFIG_CDROM_EMU=n
CONFIG_DEBUG_LEVEL=1
CONFIG_SMBIOS=n
CONFIG_MPTABLE=n
CONFIG_PIRTABLE=n
CONFIG_ACPI=n
CONFIG_ACPI_PARSE=n
CONFIG_ROM_SIZE=128
CONFIG_MOUSE=n
CONFIG_PNPBIOS=n
CONFIG_KEYBOARD=n
CONFIG_KBD_CALL_INT15_4F=n
CONFIG_LPT=n
CONFIG_SERIAL=n
CONFIG_BOOT_MENU=n
CONFIG_DEBUG_SERIAL=y
CONFIG_DEBUG_SERIAL_PORT=0x3f8
CONFIG_SERCON=n
CONFIG_OPTIONROMS=y
CONFIG_ENTRY_EXTRASTACK=y
CONFIG_PS2PORT=y
CONFIG_CALL32_SMM=y
CONFIG_THREADS=n
EOF

  make -C "$SEABIOS_SRC" olddefconfig PYTHON=python3
  make -C "$SEABIOS_SRC" -j"$(nproc)" PYTHON=python3
  cp "$SEABIOS_SRC/out/bios.bin" "$BIOS_BIN"
  echo "SeaBIOS built: $BIOS_BIN ($(stat -c%s "$BIOS_BIN") bytes)"
else
  echo "=== SeaBIOS already built: $BIOS_BIN ==="
fi

# =========================================================================
# FreeDOS disk image
# =========================================================================

FREEDOS_IMG="$BUILD_DIR/freedos.img"

# =========================================================================
# FreeDOS kernel (built from source, uncompressed)
# =========================================================================

FDKERN_VER="ke2043"
FDKERN_URL="https://github.com/FDOS/kernel/archive/refs/tags/${FDKERN_VER}.tar.gz"
FDKERN_SRC="$WORK/kernel-${FDKERN_VER}"

if [ ! -f "$FDKERN_SRC/bin/kernel.sys" ]; then
  echo "=== Building FreeDOS kernel from source ==="
  if [ ! -d "$FDKERN_SRC" ]; then
    echo "Downloading FreeDOS kernel source..."
    curl -L -o "$WORK/kernel-src.tar.gz" "$FDKERN_URL"
    tar -xzf "$WORK/kernel-src.tar.gz" -C "$WORK"
  fi
  cat > "$FDKERN_SRC/config.mak" << 'KMAK'
COMPILER=gcc
XCPU=86
XFAT=16
XUPX=
KMAK
  # Adjust makefiles for GCC cross-compiler, then build
  (cd "$FDKERN_SRC" && \
   for i in utils lib drivers boot sys kernel setver; do
     sed 's@!include "\(.*\)"@include ../mkfiles/gcc.mak@' < $i/makefile > $i/GNUmakefile
   done && \
   make all COMPILER=gcc)
  echo "FreeDOS kernel built: $FDKERN_SRC/bin/kernel.sys ($(stat -c%s "$FDKERN_SRC/bin/kernel.sys") bytes)"
else
  echo "=== FreeDOS kernel already built ==="
fi

if [ ! -f "$FREEDOS_IMG" ]; then
  echo "=== Building FreeDOS disk image ==="

  FLOPPY_IMG="$WORK/freedos-floppy.img"

  if [ ! -f "$FLOPPY_IMG" ]; then
    echo "Downloading FreeDOS 1.3 Floppy Edition..."
    curl -L -o "$WORK/freedos-floppy.zip" "$FREEDOS_URL"
    # Extract the 144m boot floppy image
    unzip -o "$WORK/freedos-floppy.zip" -d "$WORK/freedos-zip"
    FLOPPY_FOUND="$WORK/freedos-zip/144m/x86BOOT.img"
    if [ ! -f "$FLOPPY_FOUND" ]; then
      echo "Error: Could not find 144m/x86BOOT.img in FreeDOS zip"
      find "$WORK/freedos-zip" -name "*.img" -ls
      exit 1
    fi
    cp "$FLOPPY_FOUND" "$FLOPPY_IMG"
    echo "Using boot floppy: $FLOPPY_FOUND"
  fi

  # Create 32MB hard disk image
  echo "Creating 32MB hard disk image..."
  dd if=/dev/zero of="$FREEDOS_IMG" bs=1M count=32 status=none

  # Partition with a single FAT16 partition starting at sector 63
  echo "Partitioning..."
  echo ",,06,*" | sfdisk --no-reread "$FREEDOS_IMG" 2>/dev/null || true

  # Find the partition offset
  PART_START=$(sfdisk -d "$FREEDOS_IMG" 2>/dev/null | grep 'start=' | sed 's/.*start=\s*\([0-9]*\).*/\1/')
  if [ -z "$PART_START" ]; then
    PART_START=2048  # Default for modern sfdisk
  fi
  PART_OFFSET=$((PART_START * 512))

  echo "Partition starts at sector $PART_START (offset $PART_OFFSET)"

  # Format the partition as FAT16
  mkfs.fat -F 16 --offset="$PART_START" "$FREEDOS_IMG"

  # Extract files from floppy and copy to HDD partition
  echo "Copying FreeDOS files..."
  TMPDIR_FD=$(mktemp -d)
  # Extract all files from floppy image
  mcopy -i "$FLOPPY_IMG" -s -p -m -n ::/ "$TMPDIR_FD/" 2>/dev/null || true

  # Use the uncompressed KERNEL.SYS built from source (not the UPX-compressed
  # one from the floppy, which requires in-place decompression that conflicts
  # with the kernel's own relocation code).
  # Copy KERNEL.SYS FIRST so it gets cluster 2.
  BUILT_KERNEL="$FDKERN_SRC/bin/kernel.sys"
  if [ -f "$BUILT_KERNEL" ]; then
    mcopy -i "$FREEDOS_IMG@@$PART_OFFSET" "$BUILT_KERNEL" ::/KERNEL.SYS 2>/dev/null || true
    echo "Using built kernel: $BUILT_KERNEL ($(stat -c%s "$BUILT_KERNEL") bytes)"
  else
    mcopy -i "$FREEDOS_IMG@@$PART_OFFSET" "$TMPDIR_FD/KERNEL.SYS" ::/ 2>/dev/null || true
    echo "WARNING: using floppy kernel (UPX compressed)"
  fi

  # Copy COMMAND.COM to root directory (case-insensitive find)
  CMDCOM=$(find "$TMPDIR_FD" -iname 'command.com' -print -quit)
  if [ -n "$CMDCOM" ]; then
    mcopy -i "$FREEDOS_IMG@@$PART_OFFSET" "$CMDCOM" ::/COMMAND.COM 2>/dev/null || true
    echo "Copied COMMAND.COM from $CMDCOM"
  fi

  # Copy remaining files
  for f in "$TMPDIR_FD"/*; do
    if [ -e "$f" ]; then
      mcopy -i "$FREEDOS_IMG@@$PART_OFFSET" -s -p -m -n "$f" ::/ 2>/dev/null || true
    fi
  done
  rm -rf "$TMPDIR_FD"

  # Write minimal FDCONFIG.SYS (no interactive menu, no drivers)
  printf 'LASTDRIVE=Z\r\nFILES=20\r\nSHELL=\\COMMAND.COM /E:2048 /P\r\n' | \
    mcopy -i "$FREEDOS_IMG@@$PART_OFFSET" -o - ::/FDCONFIG.SYS

  # Install standard FreeDOS FAT16 boot sector from the kernel source.
  # This is the official boot.asm from the FreeDOS kernel project,
  # assembled with -DISFAT16 for FAT16 support.
  echo "Installing FreeDOS FAT16 boot sector..."
  BOOT_BIN="$WORK/boot16.bin"
  nasm -DISFAT16 -o "$BOOT_BIN" "$FDKERN_SRC/boot/boot.asm"

  # Merge: keep BPB (bytes 3-61) from mkfs.fat, use FreeDOS boot code
  python3 -c "
import struct
with open('$BOOT_BIN', 'rb') as f:
    boot = bytearray(f.read())
with open('$FREEDOS_IMG', 'r+b') as f:
    f.seek($PART_OFFSET)
    bpb = f.read(62)
    # Preserve BPB from mkfs.fat (bytes 3-61)
    boot[3:62] = bpb[3:62]
    # mkfs.fat --offset doesn't set hidden_sectors; patch it manually
    struct.pack_into('<I', boot, 0x1C, $PART_START)
    f.seek($PART_OFFSET)
    f.write(bytes(boot))
"
  echo "FreeDOS FAT16 boot sector installed"

  # Write a minimal MBR boot code that loads the partition boot sector
  # This is a simple MBR that finds the active partition and chain-loads it
  # Write MBR using nasm. The MBR relocates itself from 0x7C00 to 0x0600,
  # then loads the partition boot sector at 0x7C00 and jumps to it.
  # Standard MBR behavior — avoids overwriting the JMP FAR instruction.
  MBR_ASM="$WORK/mbr.asm"
  MBR_BIN="$WORK/mbr.bin"
  cat > "$MBR_ASM" << 'MBREOF'
[BITS 16]
[ORG 0x7C00]
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    ; Preserve boot drive in BP across relocation
    mov bp, dx

    ; Relocate MBR from 0x7C00 to 0x0600
    mov si, 0x7C00
    mov di, 0x0600
    mov cx, 256
    rep movsw
    jmp 0x0000:(relocated)

relocated equ 0x0600 + (.here - 0x7C00)
.here:
    ; Now running from 0x0600+. DS=ES=0. DL still in BP.
    ; Find active partition (table is at 0x0600 + 0x1BE = 0x07BE)
    mov si, 0x07BE
    mov cx, 4
.find:
    cmp byte [si], 0x80
    je .found
    add si, 16
    loop .find
    jmp short .halt       ; no active partition

.found:
    ; Build DAP on stack for INT 13h extended read
    ; Partition LBA start is at [si+8] (4 bytes)
    mov eax, [si + 8]      ; LBA start (32-bit)
    push dword 0            ; LBA high dword = 0
    push eax                ; LBA low dword
    push word 0x0000        ; buffer segment
    push word 0x7C00        ; buffer offset
    push word 1             ; sector count
    push word 16            ; DAP size + reserved
    mov si, sp
    mov dx, bp              ; restore boot drive
    mov ah, 0x42
    int 0x13
    jc short .halt

    ; Jump to loaded boot sector, DL = boot drive
    mov dx, bp
    jmp 0x0000:0x7C00

.halt:
    jmp short .halt

    times 446 - ($ - $$) db 0
    ; Partition table (64 bytes) and signature (2 bytes) are NOT included —
    ; we only write the first 446 bytes of code area.
MBREOF
  nasm -f bin "$MBR_ASM" -o "$MBR_BIN"
  dd if="$MBR_BIN" of="$FREEDOS_IMG" bs=1 count=446 conv=notrunc status=none

  echo "FreeDOS disk image created: $FREEDOS_IMG ($(stat -c%s "$FREEDOS_IMG") bytes)"
else
  echo "=== FreeDOS image already built: $FREEDOS_IMG ==="
fi

echo ""
echo "Done! To boot:"
echo "  ./system-emu/sail-x86-system -b $BIOS_BIN -hda $FREEDOS_IMG"
echo ""
echo "With debug output:"
echo "  ./system-emu/sail-x86-system -d -b $BIOS_BIN -hda $FREEDOS_IMG"
