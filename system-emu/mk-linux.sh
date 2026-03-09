#!/bin/bash
# Download, configure, and build a minimal Linux kernel for the Sail x86
# system emulator.
#
# Usage: ./mk-linux.sh <build-dir>
#
# Produces <build-dir>/vmlinux (uncompressed ELF kernel).
# Downloads the kernel source to <build-dir>/linux-src/ if not already present.

set -e

KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.19.6.tar.xz"

BUILD_DIR="${1:-.}"
case "$BUILD_DIR" in
  /*) ;;
  *)  BUILD_DIR="$PWD/$BUILD_DIR" ;;
esac

SRC="${BUILD_DIR}/linux-src"
TARBALL="${BUILD_DIR}/linux.tar.xz"

# Download kernel source if not present.
if [ ! -f "$SRC/Makefile" ]; then
  echo "Downloading Linux kernel..."
  mkdir -p "${BUILD_DIR}"
  if [ ! -f "${TARBALL}" ]; then
    curl -L -o "${TARBALL}" "${KERNEL_URL}"
  fi
  echo "Extracting..."
  mkdir -p "$SRC"
  tar xf "${TARBALL}" --strip-components=1 -C "$SRC"
  rm -f "${TARBALL}"
fi

# Start from tinyconfig (everything off), then enable what we need.
make -C "$SRC" ARCH=x86_64 tinyconfig

cat > "$SRC/.config.fragment" << 'EOF'
CONFIG_KERNEL_XZ=y
CONFIG_PREEMPT_VOLUNTARY=y
CONFIG_BLK_DEV_INITRD=y
CONFIG_CC_OPTIMIZE_FOR_SIZE=y
CONFIG_EXPERT=y
CONFIG_PRINTK=y
CONFIG_EARLY_PRINTK=y
CONFIG_TTY=y
CONFIG_BINFMT_ELF=y
CONFIG_BINFMT_SCRIPT=y
CONFIG_PROC_FS=y
CONFIG_SYSFS=y
CONFIG_CMDLINE_BOOL=y
CONFIG_CMDLINE="console=ttyS0 earlyprintk=serial,ttyS0,115200"
CONFIG_SLUB_TINY=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_FRAME_WARN=1024
CONFIG_UNWINDER_GUESS=y
EOF

"$SRC/scripts/kconfig/merge_config.sh" -m -O "$SRC" "$SRC/.config" "$SRC/.config.fragment"
make -C "$SRC" ARCH=x86_64 olddefconfig
make -C "$SRC" ARCH=x86_64 -j"$(nproc)"

cp "$SRC/vmlinux" "${BUILD_DIR}/vmlinux"
echo "Kernel ready: ${BUILD_DIR}/vmlinux"
