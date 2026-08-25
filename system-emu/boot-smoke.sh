#!/bin/bash
# Automated Linux boot smoke test.
#
# Boots the bzImage undriven (idle console) and polls the serial log for
# the initramfs banner — the same machine-checkable criterion the boot
# timing measurements use.  Exits 0 on banner, 1 on timeout or death,
# and 127 (ctest SKIP_RETURN_CODE) when the boot images have not been
# built (`make linux`).
#
# Budget: a healthy boot reaches the banner in ~2 minutes on the
# development machine; BOOT_SMOKE_BUDGET (seconds) overrides.
set -u

BUILD=${1:-$(cd "$(dirname "$0")/.." && pwd)/build}
EMU=$BUILD/system-emu/sail-x86-system
KERNEL=$BUILD/bzImage
INITRD=$BUILD/initramfs.cpio
BANNER='Sail x86-64 Emulator'
BUDGET=${BOOT_SMOKE_BUDGET:-420}

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
"$EMU" -i "$INITRD" "$KERNEL" < "$FIFO" > "$LOG" 2>&1 &
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
