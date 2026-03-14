#!/usr/bin/env bash
# team-review pre-commit gate hook
# PreToolUse ("pre"): blocks git commit unless gate file is valid
# PostToolUse ("post"): cleans up gate file after successful commit

set -euo pipefail

GATE_FILE="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")/.team-review-gate.json"
PHASE="${1:-pre}"

# Read tool input from stdin
INPUT=$(cat)

# --- PostToolUse: clean up gate file after successful commit ---
# Handled first, independently of command parsing, to avoid JSON schema mismatches
if [[ "$PHASE" == "post" ]]; then
  if [[ -f "$GATE_FILE" ]] && git diff --cached --quiet 2>/dev/null; then
    rm -f "$GATE_FILE"
  fi
  exit 0
fi

# --- PreToolUse: intercept git commit commands ---
# Pattern match on raw JSON — no JSON parser needed for fixed-structure hook input
if ! printf '%s' "$INPUT" | grep -q '"Bash"' || ! printf '%s' "$INPUT" | grep -qE '\bgit\b.*\bcommit\b'; then
  echo '{"decision": "allow"}'
  exit 0
fi

# Block --no-verify explicitly
if printf '%s' "$INPUT" | grep -qE -- '--no-verify'; then
  echo '{"decision": "block", "reason": "The --no-verify flag is not allowed. Please run /team-review before committing."}'
  exit 0
fi

if [[ ! -f "$GATE_FILE" ]]; then
  echo '{"decision": "block", "reason": "No review gate found. Please run /team-review before committing."}'
  exit 0
fi

# Verify staged diff hash matches the gate file (git hash-object = no external deps)
CURRENT_HASH=$(git diff --cached | git hash-object --stdin)
GATE_HASH=$(sed -n 's/.*"staged_diff_hash" *: *"\([^"]*\)".*/\1/p' "$GATE_FILE")

if [[ "$CURRENT_HASH" != "$GATE_HASH" ]]; then
  echo '{"decision": "block", "reason": "Staged files changed since review. Please run /team-review again."}'
  exit 0
fi

echo '{"decision": "allow"}'
