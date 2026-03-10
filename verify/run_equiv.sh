#!/bin/bash
# Run formal equivalence checks between sail-x86 and sail-x86-from-acl2.
#
# Uses Sail's built-in SMT backend with Z3 to prove that both models
# compute identical results for all possible inputs.
#
# Prerequisites: sail and z3 must be on PATH.
#
# Each .sail file in this directory named equiv_*.sail contains
# $property-annotated functions that Sail verifies via SMT.
# UNSAT = proven equivalent for all inputs.
# SAT   = found a counterexample (potential bug).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use SAIL_DIR from environment or default
export SAIL_DIR="${SAIL_DIR:-$HOME/sail/share/sail}"

PASS=0
FAIL=0
TOTAL=0

echo "=== Formal Equivalence Verification ==="
echo "Comparing sail-x86 vs sail-x86-from-acl2"
echo "Using: sail --smt --smt-auto --smt-auto-solver z3"
echo ""

for f in "$SCRIPT_DIR"/equiv_*.sail; do
    name="$(basename "$f" .sail)"
    echo "--- $name ---"

    output=$(sail --smt --smt-auto --smt-auto-solver z3 "$f" 2>&1)
    rc=$?

    # Count properties checked
    props=$(echo "$output" | grep -c "Checking counterexample:" || true)
    unsat=$(echo "$output" | grep -c "^unsat$" || true)

    if [ $rc -eq 0 ] && [ "$props" -gt 0 ] && [ "$props" -eq "$unsat" ]; then
        echo "  PASS: $unsat/$props properties proven equivalent"
        PASS=$((PASS + unsat))
    else
        echo "  FAIL: $unsat/$props properties proven"
        echo "$output" | grep -v "^$" | head -10
        FAIL=$((FAIL + props - unsat))
        PASS=$((PASS + unsat))
    fi
    TOTAL=$((TOTAL + props))
    echo ""
done

echo "=== Summary ==="
echo "Total properties: $TOTAL"
echo "Proven equivalent (UNSAT): $PASS"
echo "Counterexample found (SAT): $FAIL"

if [ $FAIL -gt 0 ]; then
    echo ""
    echo "WARNING: Some properties failed! Check output above for details."
    exit 1
fi
