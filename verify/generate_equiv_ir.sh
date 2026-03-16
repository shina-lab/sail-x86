#!/bin/bash
# Generate Isla IR for SIMD equivalence proofs.
# Compiles the Sail x86 model with test functions spliced in.
#
# Prerequisites: run setup.sh first.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAIL_SRC="${SAIL_SRC:-$HOME/sail-github}"
ISLA_DIR="${ISLA_DIR:-$HOME/isla}"
OUR_MODEL="${OUR_MODEL:-$HOME/sail-x86-2/model}"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/ir}"

SAIL="$SAIL_SRC/_build/default/src/bin/sail.exe"
ISLA_PLUGIN="$ISLA_DIR/isla-sail/_build/default/sail_plugin_isla.cmxs"

# Activate opam environment
eval $(opam env 2>/dev/null) || true
export SAIL_DIR="$SAIL_SRC"

mkdir -p "$OUTPUT_DIR"

echo "=== Generating Isla IR for equivalence proofs ==="
cd "$OUR_MODEL"

# Read .sail files from x86.sail_project
OUR_FILES=$(grep '\.sail' x86.sail_project | sed 's/,$//' | tr -d ' ' | tr '\n' ' ')

# All test functions to preserve from inlining
TEST_FUNCS=(
  # Existing instruction-level tests
  isla_test_add_r64_imm32
  isla_test_mov_r64_imm64
  isla_test_shl_r64_imm8
  # FFmpeg blend mode equivalence tests
  test_hardmix_orig test_hardmix_opt
  test_phoenix_orig test_phoenix_opt
  test_difference16_orig test_difference16_opt
  test_extremity16_orig test_extremity16_opt
  test_negation16_orig test_negation16_opt
  test_phoenix16_orig test_phoenix16_opt
  test_sign_add_orig test_sign_add_opt
  test_sign_sub_orig test_sign_sub_opt
  test_threshold_or_orig test_threshold_or_opt
)

PRESERVE_FLAGS=""
for func in "${TEST_FUNCS[@]}"; do
  PRESERVE_FLAGS="$PRESERVE_FLAGS --isla-preserve $func"
done

echo "Compiling Sail model with ${#TEST_FUNCS[@]} preserved test functions..."

"$SAIL" \
  --plugin "$ISLA_PLUGIN" \
  --isla \
  -D ISLA \
  $PRESERVE_FLAGS \
  -splice "$SCRIPT_DIR/splice_ours.sail" \
  -splice "$SCRIPT_DIR/hardmix_tests.sail" \
  -o "$OUTPUT_DIR/sail_x86_equiv" \
  $OUR_FILES 2>&1 | grep -v "^Warning\|warnings have been suppressed" || true

echo "  -> $OUTPUT_DIR/sail_x86_equiv.ir ($(wc -c < "$OUTPUT_DIR/sail_x86_equiv.ir") bytes)"

echo ""
echo "=== IR generation complete ==="
echo "Next: run_equiv_proofs.sh to generate traces and prove equivalence"
