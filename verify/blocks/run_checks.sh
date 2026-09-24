#!/bin/bash
# Check one wave of Codex proposals with Isla and Z3 (60 s each side).
#
#   run_checks.sh <wave-name> <proposal-glob>
#   e.g. run_checks.sh w1 'proposals/batch-0[0-4]*.json'
#
# Uses the fixed model checkout ~/sail-x86-blocks (bd400e9) so that edits
# in the main tree do not change the revision under test; work files go
# to $BLOCKS_WORK_ROOT/<wave> (default /tmp/claude-1000/prove_blocks_waves).
set -u
cd "$(dirname "$0")"
WAVE=${1:?wave name}
GLOB=${2:?proposal glob}
ROOT=${BLOCKS_WORK_ROOT:-/tmp/claude-1000/prove_blocks_waves}
mkdir -p "$ROOT/$WAVE" results
BLOCKS_MODEL_DIR=$HOME/sail-x86-blocks/model BLOCKS_WORK=$ROOT/$WAVE \
  python3 prove_blocks.py --proposals "$GLOB" --jobs "${JOBS:-100}" --ir-jobs "${IR_JOBS:-8}" \
    --chunk 300 --isla-timeout 60 --z3-timeout 60 --out "results/$WAVE.json" \
    > "results/$WAVE.log" 2>&1
echo "wave $WAVE exit $?"
tail -15 "results/$WAVE.log"
