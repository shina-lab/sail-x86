#!/bin/bash
# Run equivalence proofs for BoringSSL assembly optimizations.
# Generates Isla traces for original and optimized instruction sequences,
# then uses Z3 to prove they compute the same function for all inputs.
#
# Usage:
#   ./run_boringssl_equiv.sh              # run all proofs
#   ./run_boringssl_equiv.sh md5_g        # run specific proof

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISLA="${ISLA_DIR:-$HOME/isla}/target/release/isla-execute-function"
IR_DIR="${IR_DIR:-$SCRIPT_DIR/ir}"
IR_FILE="$IR_DIR/sail_x86.ir"
CFG_FILE="$SCRIPT_DIR/x86_config_ours.toml"
TRACE_DIR="${TRACE_DIR:-/tmp/isla_boringssl_traces}"
TIMEOUT="${TIMEOUT:-300}"

# Test function pairs: name, orig_func, opt_func, description
declare -A TESTS_ORIG TESTS_OPT TESTS_DESC
TESTS_ORIG[md5_g]="test_md5_g_orig"
TESTS_OPT[md5_g]="test_md5_g_opt"
TESTS_DESC[md5_g]="MD5 G function: (b&d)|(c&~d) [6 instrs] vs c^(d&(b^c)) [4 instrs]"

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
check_prerequisites() {
    local ok=true
    [[ -x "$ISLA" ]] || { echo >&2 "Error: isla-execute-function not found at $ISLA"; ok=false; }
    [[ -f "$IR_FILE" ]] || { echo >&2 "Error: IR file not found: $IR_FILE"; echo >&2 "Run generate_ir.sh first."; ok=false; }
    [[ -f "$CFG_FILE" ]] || { echo >&2 "Error: config not found: $CFG_FILE"; ok=false; }
    command -v z3 &>/dev/null || { echo >&2 "Error: z3 not found in PATH"; ok=false; }
    [[ "$ok" == true ]] || exit 1
}

# ---------------------------------------------------------------------------
# Trace generation
# ---------------------------------------------------------------------------
generate_trace() {
    local func_name="$1"
    local output_file="$2"

    "$ISLA" "$func_name" \
        --arch "$IR_FILE" \
        --config "$CFG_FILE" \
        --traces -s --simplify-registers \
        --timeout "$TIMEOUT" \
        > "$output_file" 2>&1
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
check_prerequisites
mkdir -p "$TRACE_DIR"

# Select tests
if [[ $# -gt 0 ]]; then
    targets=("$@")
else
    targets=("${!TESTS_ORIG[@]}")
fi

echo "=== BoringSSL Equivalence Verification ==="
echo "IR:       $IR_FILE"
echo "Config:   $CFG_FILE"
echo "Traces:   $TRACE_DIR"
echo "Timeout:  ${TIMEOUT}s"
echo ""

pass_count=0
fail_count=0
error_count=0

for test in "${targets[@]}"; do
    orig_func="${TESTS_ORIG[$test]}"
    opt_func="${TESTS_OPT[$test]}"
    desc="${TESTS_DESC[$test]}"
    orig_trace="$TRACE_DIR/${test}_orig.txt"
    opt_trace="$TRACE_DIR/${test}_opt.txt"

    echo "--- $test ---"
    echo "  $desc"

    # Generate original trace
    echo -n "  Original ($orig_func)... "
    start=$(date +%s%N)
    if generate_trace "$orig_func" "$orig_trace"; then
        ms=$(( ($(date +%s%N) - start) / 1000000 ))
        tc=$(grep -c '^Trace ' "$orig_trace" 2>/dev/null || echo 0)
        echo "done (${ms}ms, ${tc} traces)"
    else
        ms=$(( ($(date +%s%N) - start) / 1000000 ))
        echo "FAILED (${ms}ms)"
        echo "  See: $orig_trace"
        (( error_count++ ))
        continue
    fi

    # Generate optimized trace
    echo -n "  Optimized ($opt_func)... "
    start=$(date +%s%N)
    if generate_trace "$opt_func" "$opt_trace"; then
        ms=$(( ($(date +%s%N) - start) / 1000000 ))
        tc=$(grep -c '^Trace ' "$opt_trace" 2>/dev/null || echo 0)
        echo "done (${ms}ms, ${tc} traces)"
    else
        ms=$(( ($(date +%s%N) - start) / 1000000 ))
        echo "FAILED (${ms}ms)"
        echo "  See: $opt_trace"
        (( error_count++ ))
        continue
    fi

    # Build and run Z3 equivalence proof
    echo -n "  Z3 proof... "
    start=$(date +%s%N)
    smt_file="$TRACE_DIR/${test}_equiv.smt2"

    if python3 "$SCRIPT_DIR/prove_equiv.py" "$orig_trace" "$opt_trace" 2>/dev/null; then
        # prove_equiv.py prints results but we need it to output to file
        # Use build_equiv_query approach instead
        true
    fi

    # Use the prove_boringssl_equiv.py script
    result=$(python3 "$SCRIPT_DIR/prove_boringssl_equiv.py" \
        "$orig_trace" "$opt_trace" "$smt_file" "$test" 2>&1)
    ms=$(( ($(date +%s%N) - start) / 1000000 ))

    if echo "$result" | grep -q "UNSAT"; then
        echo "PROVED EQUIVALENT (${ms}ms)"
        echo "  $result"
        (( pass_count++ ))
    elif echo "$result" | grep -q "SAT"; then
        echo "NOT EQUIVALENT (${ms}ms)"
        echo "  $result"
        (( fail_count++ ))
    else
        echo "ERROR (${ms}ms)"
        echo "  $result"
        (( error_count++ ))
    fi

    echo "  Query: $smt_file"
    echo ""
done

echo "=== Summary ==="
echo "Pass: $pass_count  Fail: $fail_count  Error: $error_count  Total: ${#targets[@]}"
[[ $fail_count -eq 0 && $error_count -eq 0 ]]
