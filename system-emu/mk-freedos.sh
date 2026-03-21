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
  cat > "$SEABIOS_SRC/.config" <<'SEABIOS_CONFIG'
CONFIG_QEMU=y
CONFIG_QEMU_HARDWARE=y
CONFIG_COREBOOT=n
CONFIG_CSM=n
CONFIG_ATA=y
CONFIG_ATA_DMA=n
CONFIG_ATA_PIO32=n
CONFIG_FLOPPY=n
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
CONFIG_DEBUG_LEVEL=3
CONFIG_SMBIOS=n
CONFIG_MPTABLE=n
CONFIG_PIRTABLE=n
CONFIG_ACPI=n
CONFIG_DEBUG_SERIAL=y
CONFIG_DEBUG_SERIAL_PORT=0x3f8
CONFIG_SERCON=y
SEABIOS_CONFIG

  # SeaBIOS Makefile uses 'python' — ensure python3 is used
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

  # Copy files to HDD partition
  # mcopy with @@offset notation to access partition within disk image
  for f in "$TMPDIR_FD"/*; do
    if [ -e "$f" ]; then
      mcopy -i "$FREEDOS_IMG@@$PART_OFFSET" -s -p -m -n "$f" ::/ 2>/dev/null || true
    fi
  done
  rm -rf "$TMPDIR_FD"

  # Copy boot sector from floppy to HDD partition boot sector
  echo "Installing boot sector..."
  dd if="$FLOPPY_IMG" of="$FREEDOS_IMG" bs=1 count=3 seek="$PART_OFFSET" conv=notrunc status=none
  dd if="$FLOPPY_IMG" of="$FREEDOS_IMG" bs=1 skip=62 count=450 seek=$((PART_OFFSET + 62)) conv=notrunc status=none

  # Write a minimal MBR boot code that loads the partition boot sector
  # This is a simple MBR that finds the active partition and chain-loads it
  python3 -c "
import struct, sys
mbr = bytearray(512)

# MBR boot code: find active partition, load its boot sector, jump to it
code = bytes([
    0xFA,                   # cli
    0x31, 0xC0,             # xor ax, ax
    0x8E, 0xD8,             # mov ds, ax
    0x8E, 0xD0,             # mov ss, ax
    0xBC, 0x00, 0x7C,       # mov sp, 0x7C00
    0xFB,                   # sti
    0x8E, 0xC0,             # mov es, ax
    # Find active partition in partition table at 0x7DBE
    0xBE, 0xBE, 0x7D,       # mov si, 0x7DBE
    0xB9, 0x04, 0x00,       # mov cx, 4
    # loop:
    0x80, 0x3C, 0x80,       # cmp byte [si], 0x80
    0x74, 0x05,             # je found
    0x83, 0xC6, 0x10,       # add si, 16
    0xE2, 0xF6,             # loop (back to cmp)
    0xEB, 0xFE,             # jmp $ (no active partition)
    # found: read boot sector from partition
    0x8B, 0x44, 0x08,       # mov ax, [si+8]  (LBA low word)
    0x8B, 0x54, 0x0A,       # mov dx, [si+10] (LBA high word - actually CHS start head)
    # Use INT 13h extended read (LBA)
    0x66, 0x50,             # push eax (save LBA)
    0x06,                   # push es
    0x53,                   # push bx
    0x6A, 0x01,             # push 1 (count)
    0x6A, 0x10,             # push 16 (packet size)
    0x89, 0xE6,             # mov si, sp
    # Actually use CHS-based INT 13h for compatibility
])
# Simpler approach: use INT 13h CHS read
code2 = bytes([
    0xFA,                   # cli
    0x31, 0xC0,             # xor ax, ax
    0x8E, 0xD8,             # mov ds, ax
    0x8E, 0xD0,             # mov ss, ax
    0xBC, 0x00, 0x7C,       # mov sp, 0x7C00
    0xFB,                   # sti
    0x8E, 0xC0,             # mov es, ax
    # Find active partition
    0xBE, 0xBE, 0x7D,       # mov si, 0x7DBE
    0xB9, 0x04, 0x00,       # mov cx, 4
    # loop:
    0x80, 0x3C, 0x80,       # cmp byte [si], 0x80
    0x74, 0x05,             # je found
    0x83, 0xC6, 0x10,       # add si, 16
    0xE2, 0xF6,             # loop
    0xEB, 0xFE,             # jmp $ (halt)
    # found: load partition boot sector using CHS from partition table entry
    0x8A, 0x74, 0x01,       # mov dh, [si+1]  (start head)
    0x8B, 0x4C, 0x02,       # mov cx, [si+2]  (start cyl/sector)
    0xBB, 0x00, 0x7C,       # mov bx, 0x7C00
    0xB8, 0x01, 0x02,       # mov ax, 0x0201 (read 1 sector)
    0xBA, 0x80, 0x00,       # mov dx, 0x0080 (drive 0x80)
    # Actually dh is head from partition entry
    0x8A, 0x74, 0x01,       # mov dh, [si+1]
    0xCD, 0x13,             # int 0x13
    0x72, 0xFE,             # jc $ (retry on error - just halt)
    0xEA, 0x00, 0x7C, 0x00, 0x00,  # jmp 0000:7C00
])
mbr[:len(code2)] = code2
mbr[510] = 0x55
mbr[511] = 0xAA
sys.stdout.buffer.write(bytes(mbr[:446]))
" | dd of="$FREEDOS_IMG" bs=1 count=446 conv=notrunc status=none

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
