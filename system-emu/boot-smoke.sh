#!/bin/bash
# Automated Linux boot smoke test.
#
# Boots the bzImage undriven (idle console) and polls the serial log for
# the initramfs banner — the same machine-checkable criterion the boot
# timing measurements use.  Exits 0 on banner, 1 on timeout or death,
# and 127 (ctest SKIP_RETURN_CODE) when the boot images have not been
# built (`make linux`).
#
# Budget: the 64-bit kernel reaches the banner after about 126 M
# instructions, some ten minutes on the development machine, the i386
# kernel at -ips 4 after about 54 M; BOOT_SMOKE_BUDGET (seconds)
# overrides.  Another kernel and initramfs (the i386 pair) are selected
# with BOOT_SMOKE_KERNEL and BOOT_SMOKE_INITRD, and BOOT_SMOKE_EMU_ARGS
# passes options to the emulator (the i386 kernel needs "-ips 4").
set -u

BUILD=${1:-$(cd "$(dirname "$0")/.." && pwd)/build}
EMU=$BUILD/system-emu/sail-x86-system
KERNEL=${BOOT_SMOKE_KERNEL:-$BUILD/bzImage}
INITRD=${BOOT_SMOKE_INITRD:-$BUILD/initramfs.cpio}
EMU_ARGS=${BOOT_SMOKE_EMU_ARGS:-}
# The full console banner: the kernel's CPU brand line also says
# "Sail x86-64 Emulator", long before the initramfs runs.
BANNER='Sail x86-64 Emulator - Linux Console'
BUDGET=${BOOT_SMOKE_BUDGET:-1500}

if [ ! -x "$EMU" ] || [ ! -f "$KERNEL" ] || [ ! -f "$INITRD" ]; then
  echo "boot-smoke: boot images not built (run 'make linux'); skipping"
  exit 127
fi

WORK=$(mktemp -d)
LOG=$WORK/serial.log
FIFO=$WORK/console.in
mkfifo "$FIFO"

cleanup() {
  [ -n "${EMUPID:-}" ] && kill "$EMUPID" 2>/dev/null
  [ -n "${FEEDPID:-}" ] && kill "$FEEDPID" 2>/dev/null
  rm -rf "$WORK"
}
trap cleanup EXIT

# Idle console: keep stdin open without typing anything.
sleep "$BUDGET" > "$FIFO" &
FEEDPID=$!
# shellcheck disable=SC2086  # EMU_ARGS is a list of options
"$EMU" $EMU_ARGS -i "$INITRD" "$KERNEL" < "$FIFO" > "$LOG" 2>&1 &
EMUPID=$!

for _ in $(seq 1 $((BUDGET / 2))); do
  sleep 2
  if grep -q "$BANNER" "$LOG" 2>/dev/null; then
    echo "boot-smoke: PASS — banner reached"
    grep -m1 "$BANNER" "$LOG"
    exit 0
  fi
  if ! kill -0 "$EMUPID" 2>/dev/null; then
    echo "boot-smoke: FAIL — emulator exited before the banner; tail:"
    tail -20 "$LOG"
    exit 1
  fi
done

echo "boot-smoke: FAIL — banner not reached within ${BUDGET}s; tail:"
tail -20 "$LOG"
exit 1
