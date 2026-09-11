#!/bin/bash
# Differential test of the rewritten kernel assembly against the original.
#
# Every patched file is assembled twice, from `git show HEAD:` and from the
# working tree, with the kernel's own include paths; the two object sets are
# linked into one user-space program under the symbol prefixes o_ and n_,
# and difftest.c runs each entry point on the same random inputs and
# compares every output.  The machine must have the extensions the files
# use (AVX2, AES-NI, PCLMULQDQ, GFNI, VAES, AVX-512).
#
# Usage: run.sh [work-dir]     (KSRC defaults to ~/linux)
set -euo pipefail

KSRC=${KSRC:-$HOME/linux}
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=${1:-/tmp/claude-1000/kernel-difftest}
mkdir -p "$WORK/orig" "$WORK/new" "$WORK/orig_inc/asm"

FLAGS="-D__ASSEMBLY__ -D__KERNEL__ -nostdinc \
  -I$KSRC/arch/x86/include -I$KSRC/arch/x86/include/generated -I$KSRC/include \
  -I$KSRC/arch/x86/include/uapi -I$KSRC/arch/x86/include/generated/uapi \
  -I$KSRC/include/uapi -I$KSRC/include/generated/uapi \
  -include $KSRC/include/linux/compiler-version.h \
  -include $KSRC/include/linux/kconfig.h -m64 -DCONFIG_X86_MCE=1"

FILES=(
  arch/x86/crypto/aegis128-aesni-asm.S
  arch/x86/crypto/aes-gcm-aesni-x86_64.S
  arch/x86/crypto/aria-aesni-avx-asm_64.S
  arch/x86/crypto/aria-aesni-avx2-asm_64.S
  arch/x86/crypto/aria-gfni-avx512-asm_64.S
  arch/x86/crypto/camellia-aesni-avx-asm_64.S
  arch/x86/crypto/camellia-aesni-avx2-asm_64.S
  arch/x86/crypto/serpent-sse2-x86_64-asm_64.S
  arch/x86/lib/copy_mc_64.S
  arch/x86/lib/memset_64.S
  lib/crypto/x86/aes-aesni.S
  lib/crypto/x86/chacha-avx2-x86_64.S
  lib/crypto/x86/ghash-pclmul.S
  lib/crypto/x86/sha256-ssse3-asm.S
  lib/crypto/x86/sha512-avx2-asm.S
  lib/crypto/x86/sm3-avx-asm_64.S
)

cd "$KSRC"
for f in "${FILES[@]}"; do
  b=$(basename "$f" .S)
  git show "HEAD:$f" > "$WORK/orig/$b.S"
  cp "$f" "$WORK/new/$b.S"
done

# perlasm: the script locates its helpers relative to its own path, so the
# original copy is generated from inside the same directory.
git show HEAD:lib/crypto/x86/poly1305-x86_64-cryptogams.pl > lib/crypto/x86/.difftest-orig.pl
perl lib/crypto/x86/.difftest-orig.pl > "$WORK/orig/poly1305-x86_64.S"
rm -f lib/crypto/x86/.difftest-orig.pl
perl lib/crypto/x86/poly1305-x86_64-cryptogams.pl > "$WORK/new/poly1305-x86_64.S"

# csum_fold is inline asm in a header: compile csum-partial_64.c with the
# kernel's own command, once against the HEAD header and once as is.
touch arch/x86/lib/csum-partial_64.c
make V=1 arch/x86/lib/csum-partial_64.o > "$WORK/make.log" 2>&1 || true
CC_CMD=$(grep -o 'gcc .*csum-partial_64\.c' "$WORK/make.log" | head -1 || true)
[ -n "$CC_CMD" ] || { echo "could not capture the kernel compile command"; exit 1; }
git show HEAD:arch/x86/include/asm/checksum_64.h > "$WORK/orig_inc/asm/checksum_64.h"
eval "$(echo "$CC_CMD" | sed "s#-o arch/x86/lib/csum-partial_64.o#-o $WORK/new/csum-partial_64.o#")"
eval "$(echo "$CC_CMD" | sed "s#^gcc #gcc -I$WORK/orig_inc #; s#-o arch/x86/lib/csum-partial_64.o#-o $WORK/orig/csum-partial_64.o#")"

for v in orig new; do
  p=${v:0:1}_
  for s in "$WORK/$v"/*.S; do
    gcc $FLAGS -c "$s" -o "${s%.S}.o"
  done
  for o in "$WORK/$v"/*.o; do
    objcopy --prefix-symbols="$p" "$o"
  done
done

# struct aria_ctx offsets normally come from asm-offsets.h (absent when
# CONFIG_CRYPTO_ARIA is off): enc_key[17][4] u32, dec_key[17][4] u32, int rounds.
DEFSYM=""
for p in o_ n_; do
  DEFSYM="$DEFSYM -Wl,--defsym=${p}ARIA_CTX_enc_key=0 -Wl,--defsym=${p}ARIA_CTX_dec_key=272 -Wl,--defsym=${p}ARIA_CTX_rounds=544"
done

gcc -O1 -no-pie -z noexecstack -o "$WORK/difftest" "$HERE/difftest.c" \
  "$WORK"/orig/*.o "$WORK"/new/*.o $DEFSYM
"$WORK/difftest"
