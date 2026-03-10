#!/bin/bash
# Generate Isla IR files for both x86 Sail models.
# Requires setup.sh to have been run first.

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
export SAIL_DIR="$HOME/sail/share/sail"

mkdir -p "$OUTPUT_DIR"

echo "=== Generating Isla IR files ==="

# Generate IR for sail-x86 (our model)
echo "[1/2] Generating IR for sail-x86 (our model)..."
cd "$OUR_MODEL"

OUR_FILES="prelude.sail core_types.sail regs.sail rflags.sail exceptions.sail \
  paging.sail mem.sail interrupts.sail fp_extern.sail x87_regs.sail types.sail \
  insn_prefixes.sail insn_modrm.sail insn_alu.sail insn_x87.sail \
  insn_sse_fp.sail insn_sse_int.sail insn_baseline.sail insn_groups.sail \
  insn_fma.sail insn_sse4_helpers.sail insn_vex.sail insn_vex_imm.sail \
  insn_vex_fp.sail insn_vex_int.sail insn_vex_fma.sail insn_vex_arith.sail \
  insn_vex_dispatch.sail insn_evex.sail insn_evex_fp.sail insn_evex_int.sail \
  insn_evex_fma.sail insn_evex_perm.sail insn_evex_arith.sail \
  insn_evex_imm.sail insn_evex_dispatch.sail insn_dispatch.sail \
  fetch_execute.sail"

"$SAIL" \
  --plugin "$ISLA_PLUGIN" \
  --isla \
  --isla-preserve isla_footprint \
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
  --isla-preserve isla_footprint \
  -splice "$SCRIPT_DIR/splice_acl2.sail" \
  $(for f in "$ACL2_MODEL"/test-generation-patches/*.sail; do echo "-splice $f"; done) \
  -o "$OUTPUT_DIR/acl2_x86" \
  $ACL2_FILES 2>&1 | grep -v "^Warning\|warnings have been suppressed" || true

echo "  -> $OUTPUT_DIR/acl2_x86.ir ($(wc -c < "$OUTPUT_DIR/acl2_x86.ir") bytes)"

echo ""
echo "=== IR generation complete ==="
echo "sail-x86:           $OUTPUT_DIR/sail_x86.ir"
echo "sail-x86-from-acl2: $OUTPUT_DIR/acl2_x86.ir"
