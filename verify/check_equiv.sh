#!/bin/bash
# Run equivalence checks between sail-x86 and sail-x86-from-acl2.
# Prerequisites: run setup.sh and generate_ir.sh first.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISLA_DIR="${ISLA_DIR:-$HOME/isla}"

export ISLA_FOOTPRINT="$ISLA_DIR/target/release/isla-footprint"

echo "=== x86 Formal Equivalence Check ==="
echo "Comparing sail-x86 vs sail-x86-from-acl2"
echo ""

python3 "$SCRIPT_DIR/compare_footprint.py" \
    --ours-ir "$SCRIPT_DIR/ir/sail_x86.ir" \
    --acl2-ir "$SCRIPT_DIR/ir/acl2_x86.ir" \
    --ours-config "$SCRIPT_DIR/x86_config_ours.toml" \
    --acl2-config "$SCRIPT_DIR/x86_config_acl2.toml" \
    --output "$SCRIPT_DIR/results.json" \
    --all -v \
    "$@"
