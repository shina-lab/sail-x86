#!/bin/bash
# Ask Codex (OpenAI's coding agent, non-interactive `codex exec`) for
# rewrites of every batch in batches/ that has no proposals/ file yet.
#
#   run_codex_batches.sh [parallel] [batch-dir] [proposal-dir] [log-dir]
#
# Each batch gets one Codex session with the prompt below; the session
# reads INSTRUCTIONS.md and the batch file and writes the proposals JSON.
# Codex runs without its sandbox (bubblewrap cannot create user
# namespaces on this host); the prompt restricts it to writing one file.
set -u
cd "$(dirname "$0")"
PAR=${1:-16}
BATCHES=${2:-batches}
PROPOSALS=${3:-proposals}
LOGS=${4:-codex-logs}
mkdir -p "$PROPOSALS" "$LOGS"

run_one() {
  local batch=$1 name out log
  name=$(basename "$batch" .json)
  out="$PROPOSALS/$name.json"
  log="$LOGS/$name.log"
  [ -s "$out" ] && return 0
  local prompt="You are given a batch of x86-64 straight-line assembly blocks to optimize. Read the instructions in INSTRUCTIONS.md (in the current directory) carefully, then read the batch file $batch and write your proposals as a single JSON object to $out, following the output format in INSTRUCTIONS.md exactly (every block id must appear; \"rewrite\" is either null or a string with one instruction per line in Intel syntax as objdump prints it). Do not run any code; reason about the instruction semantics only. Do not modify any other file."
  local start=$(date +%s)
  timeout 3600 codex exec --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check "$prompt" > "$log" 2>&1
  local rc=$?
  echo "$name rc=$rc $(( $(date +%s) - start ))s $(grep -A1 'tokens used' "$log" | tail -1 | tr -d ' ,') tokens $( [ -s "$out" ] && echo ok || echo MISSING )"
}
export -f run_one
export PROPOSALS LOGS

ls "$BATCHES"/batch-*.json | xargs -P "$PAR" -I{} bash -c 'run_one {}'
