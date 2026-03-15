#!/bin/bash
# Generate Isla symbolic traces and run Z3 equivalence proofs.
#
# Prerequisites:
#   1. Run generate_equiv_ir.sh to produce the IR file
#   2. isla-execute-function and z3 must be in PATH or at known locations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISLA_DIR="${ISLA_DIR:-$HOME/isla}"
IR_FILE="${SCRIPT_DIR}/ir/sail_x86_equiv.ir"
CONFIG="${SCRIPT_DIR}/x86_config_ours.toml"
ISLA="${ISLA_DIR}/target/release/isla-execute-function"

# Check prerequisites
for f in "$IR_FILE" "$CONFIG" "$ISLA"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: Missing $f"
    echo "Run generate_equiv_ir.sh first, or check ISLA_DIR."
    exit 1
  fi
done

# All test function pairs: (short_name, orig_func, opt_func)
TESTS=(
  "difference:test_difference_orig:test_difference_opt"
  "phoenix:test_phoenix_orig:test_phoenix_opt"
  "multiply:test_multiply_orig:test_multiply_opt"
  "extremity:test_extremity_orig:test_extremity_opt"
  "negation:test_negation_orig:test_negation_opt"
  "multiply_byte:test_multiply_byte_orig:test_multiply_byte_opt"
  "abs16:test_abs16_sse2:test_abs16_ssse3"
  "gzip_match:test_gzip_match_orig:test_gzip_match_opt"
  "hardmix:test_hardmix_orig:test_hardmix_opt"
)

echo "=== Generating symbolic traces ==="

for entry in "${TESTS[@]}"; do
  IFS=: read -r name orig opt <<< "$entry"

  for func in "$orig" "$opt"; do
    trace_file="/tmp/trace_${func}.txt"
    echo -n "  $func ... "

    if [ -f "$trace_file" ] && [ "$trace_file" -nt "$IR_FILE" ]; then
      echo "cached"
      continue
    fi

    "$ISLA" "$func" \
      --arch "$IR_FILE" \
      --config "$CONFIG" \
      --traces -s \
      --simplify-registers \
      --timeout 600 \
      > "$trace_file" 2>/dev/null

    lines=$(wc -l < "$trace_file")
    echo "done ($lines lines)"
  done
done

echo ""
echo "=== Running Z3 equivalence proofs ==="
echo ""

# Add Z3 to PATH if needed
export PATH="$HOME/sail/bin:$PATH"

python3 "$SCRIPT_DIR/prove_equiv.py"
