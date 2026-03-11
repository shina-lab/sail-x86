#!/bin/bash
# Generate Isla IR files for both x86 Sail models.
# Uses insn_buf register-based instruction buffer to avoid
# Isla's symbolic memory issue (writes not connected to reads).
#
# Prerequisites: run setup.sh first.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAIL_SRC="${SAIL_SRC:-$HOME/sail-github}"
ISLA_DIR="${ISLA_DIR:-$HOME/isla}"
ACL2_MODEL="${ACL2_MODEL:-$HOME/sail-x86-from-acl2}"
OUR_MODEL="${OUR_MODEL:-$HOME/sail-x86/model}"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/ir}"

SAIL="$SAIL_SRC/_build/default/src/bin/sail.exe"
ISLA_PLUGIN="$ISLA_DIR/isla-sail/_build/default/sail_plugin_isla.cmxs"

# Activate opam environment
eval $(opam env 2>/dev/null) || true
export SAIL_DIR="$SAIL_SRC"

mkdir -p "$OUTPUT_DIR"

echo "=== Generating Isla IR files ==="

# Generate IR for sail-x86 (our model)
echo "[1/2] Generating IR for sail-x86 (our model)..."
cd "$OUR_MODEL"

# Use sail_project file list — read .sail files from x86.sail_project
OUR_FILES=$(grep '\.sail' x86.sail_project | sed 's/,$//' | tr -d ' ' | tr '\n' ' ')

"$SAIL" \
  --plugin "$ISLA_PLUGIN" \
  --isla \
  -D ISLA \
  --isla-preserve isla_test_add_r64_imm32 \
  --isla-preserve isla_test_mov_r64_imm64 \
  --isla-preserve isla_test_shl_r64_imm8 \
  -splice "$SCRIPT_DIR/splice_ours.sail" \
  -o "$OUTPUT_DIR/sail_x86" \
  $OUR_FILES 2>&1 | grep -v "^Warning\|warnings have been suppressed" || true

echo "  -> $OUTPUT_DIR/sail_x86.ir ($(wc -c < "$OUTPUT_DIR/sail_x86.ir") bytes)"

# Generate IR for sail-x86-from-acl2
echo "[2/2] Generating IR for sail-x86-from-acl2..."
cd "$ACL2_MODEL/model"

ACL2_FILES="prelude.sail register_types.sail registers.sail register_accessors.sail \
  opcode_ext.sail memory_accessors.sail init.sail config.sail logging.sail \
  step.sail main.sail"

"$SAIL" \
  --plugin "$ISLA_PLUGIN" \
  --isla \
  --isla-preserve isla_test_add_r64_imm32 \
  --isla-preserve isla_test_mov_r64_imm64 \
  --isla-preserve isla_test_shl_r64_imm8 \
  -splice "$SCRIPT_DIR/splice_acl2.sail" \
  $(for f in "$ACL2_MODEL"/test-generation-patches/*.sail; do echo "-splice $f"; done) \
  -o "$OUTPUT_DIR/acl2_x86" \
  $ACL2_FILES 2>&1 | grep -v "^Warning\|warnings have been suppressed" || true

echo "  -> $OUTPUT_DIR/acl2_x86.ir ($(wc -c < "$OUTPUT_DIR/acl2_x86.ir") bytes)"

echo ""
echo "=== IR generation complete ==="
echo "sail-x86:           $OUTPUT_DIR/sail_x86.ir"
echo "sail-x86-from-acl2: $OUTPUT_DIR/acl2_x86.ir"
