#!/bin/bash
# Build a minimal initramfs with busybox for the Sail x86 system emulator.
# Usage: ./mk-initramfs.sh [output.cpio]
#
# Produces a cpio archive suitable for -i flag of sail-x86-system.

set -e

OUTPUT="${1:-initramfs.cpio}"
# Make OUTPUT absolute so it works after cd into TMPDIR.
case "$OUTPUT" in
  /*) ;;
  *)  OUTPUT="$PWD/$OUTPUT" ;;
esac
BUSYBOX="/usr/bin/busybox"
TMPDIR=$(mktemp -d)

trap "rm -rf $TMPDIR" EXIT

if [ ! -x "$BUSYBOX" ]; then
  echo "Error: busybox not found at $BUSYBOX" >&2
  echo "Install with: sudo apt install busybox-static" >&2
  exit 1
fi

# Verify it's statically linked
if file "$BUSYBOX" | grep -q "dynamically linked"; then
  echo "Error: busybox must be statically linked" >&2
  echo "Install with: sudo apt install busybox-static" >&2
  exit 1
fi

echo "Building initramfs with busybox..."

# Create directory structure
mkdir -p "$TMPDIR"/{bin,sbin,usr/bin,usr/sbin,proc,sys,dev,etc,tmp}

# Device nodes will be created inside fakeroot below

# Copy busybox and create symlinks
cp "$BUSYBOX" "$TMPDIR/bin/busybox"
chmod 755 "$TMPDIR/bin/busybox"

# Build and include 32-bit test binary
gcc -m32 -static -O2 -o "$TMPDIR/bin/hello32" "$(dirname "$0")/hello32.c"
chmod 755 "$TMPDIR/bin/hello32"

# Build and include KVM VMX test binary
gcc -static -O2 -o "$TMPDIR/bin/kvm-test" "$(dirname "$0")/kvm-test.c"
chmod 755 "$TMPDIR/bin/kvm-test"

# Create symlinks for all busybox applets
for cmd in sh ash cat echo ls mkdir mount umount sleep clear \
           cp mv rm ln chmod chown id uname hostname dmesg \
           ps kill true false test expr head tail wc \
           grep sed awk sort uniq tr cut tee \
           env printenv pwd cd basename dirname \
           vi ed hexdump od xxd strings \
           free uptime date setsid cttyhack getty stty; do
  ln -sf busybox "$TMPDIR/bin/$cmd"
done

# Create init script
cat > "$TMPDIR/init" << 'INIT'
#!/bin/sh
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sysfs /sys 2>/dev/null
mount -t devtmpfs devtmpfs /dev 2>/dev/null

echo ""
echo "========================================"
echo " Sail x86-64 Emulator - Linux Console"
echo "========================================"
echo ""
echo "Type 'help' for a list of built-in commands."
echo "Press Ctrl-a x to exit the emulator."
echo ""

export HOME=/
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
export TERM=vt100
export PS1='sail# '

# Determine console device from kernel command line.
# "console=tty0" → VGA, "console=ttyS0" → serial.
CONSOLE=ttyS0
for arg in $(cat /proc/cmdline); do
  case "$arg" in
    console=tty0)  CONSOLE=tty0 ;;
    console=ttyS*) CONSOLE="${arg#console=}"; CONSOLE="${CONSOLE%%,*}" ;;
  esac
done

# Respawn getty so Ctrl-D doesn't kill init (PID 1).
while true; do
  if [ "$CONSOLE" = "tty0" ]; then
    setsid cttyhack /bin/sh
  else
    setsid getty -n -l /bin/sh 115200 "$CONSOLE" vt100
  fi
done
INIT
chmod 755 "$TMPDIR/init"

# Create /etc/passwd and /etc/group for basic user support
echo "root:x:0:0:root:/:/bin/sh" > "$TMPDIR/etc/passwd"
echo "root:x:0:" > "$TMPDIR/etc/group"

# Build cpio archive with fakeroot (to create device nodes with correct major/minor)
cd "$TMPDIR"
fakeroot sh -c '
  mknod dev/console c 5 1
  mknod dev/tty0 c 4 0
  mknod dev/ttyS0 c 4 64
  mknod dev/null c 1 3
  mknod dev/kvm c 10 232
  chmod 666 dev/null
  chmod 666 dev/kvm
  find . | cpio -o -H newc 2>/dev/null
' > "$OUTPUT"

SIZE=$(stat -c %s "$OUTPUT")
echo "Created $OUTPUT ($SIZE bytes)"
