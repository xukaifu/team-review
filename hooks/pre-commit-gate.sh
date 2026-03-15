#!/usr/bin/env bash
# team-review pre-commit gate hook
# PreToolUse ("pre"): blocks git commit unless gate file is valid
# PostToolUse ("post"): cleans up gate file after successful commit

set -euo pipefail

PHASE="${1:-pre}"

# --- PostToolUse: clean up gate file after successful commit ---
if [[ "$PHASE" == "post" ]]; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
  if [[ -f "$REPO_ROOT/.team-review-gate.json" ]] && git diff --cached --quiet 2>/dev/null; then
    rm -f "$REPO_ROOT/.team-review-gate.json"
  fi
  exit 0
fi

# --- PreToolUse: intercept git commit commands ---
INPUT=$(cat)
if ! printf '%s' "$INPUT" | grep -q '"Bash"' || ! printf '%s' "$INPUT" | grep -qE '\bgit\b.*\bcommit\b'; then
  echo '{"decision": "allow"}'
  exit 0
fi

# --- From here: confirmed git commit command ---
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"

# Disabled check
if [[ -f "$REPO_ROOT/.team-review-disabled" ]]; then
  echo '{"decision": "allow"}'
  exit 0
fi

# Block --no-verify
if printf '%s' "$INPUT" | grep -qE -- '--no-verify'; then
  echo '{"decision": "block", "reason": "The --no-verify flag is not allowed. Please run /team-review before committing."}'
  exit 0
fi

# Gate file check
GATE_FILE="$REPO_ROOT/.team-review-gate.json"

if [[ ! -f "$GATE_FILE" ]]; then
  echo '{"decision": "block", "reason": "No review gate found. Please run /team-review before committing."}'
  exit 0
fi

# Verify staged diff hash matches
CURRENT_HASH=$(git diff --cached | git hash-object --stdin)
GATE_HASH=$(sed -n 's/.*"staged_diff_hash" *: *"\([^"]*\)".*/\1/p' "$GATE_FILE")

if [[ "$CURRENT_HASH" != "$GATE_HASH" ]]; then
  echo '{"decision": "block", "reason": "Staged files changed since review. Please run /team-review again."}'
  exit 0
fi

echo '{"decision": "allow"}'
