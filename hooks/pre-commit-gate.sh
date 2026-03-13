#!/usr/bin/env bash
# team-review pre-commit gate hook
# PreToolUse ("pre"): blocks git commit unless gate file is valid
# PostToolUse ("post"): cleans up gate file after successful commit

set -euo pipefail

GATE_FILE=".team-review-gate.json"
PHASE="${1:-pre}"

# Read tool input from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only intercept git commit commands
if [[ "$TOOL_NAME" != "Bash" ]] || ! echo "$COMMAND" | grep -qE '\bgit\s+commit\b'; then
  if [[ "$PHASE" == "pre" ]]; then
    echo '{"decision": "allow"}'
  fi
  exit 0
fi

if [[ "$PHASE" == "pre" ]]; then
  # --- PreToolUse: validate gate file before allowing commit ---

  if [[ ! -f "$GATE_FILE" ]]; then
    echo '{"decision": "block", "reason": "No review gate found. Please run /team-review before committing."}'
    exit 0
  fi

  # Verify staged diff hash matches the gate file
  CURRENT_HASH=$(git diff --cached | shasum -a 256 | cut -d' ' -f1)
  GATE_HASH=$(jq -r '.staged_diff_sha256' "$GATE_FILE")

  if [[ "$CURRENT_HASH" != "$GATE_HASH" ]]; then
    echo '{"decision": "block", "reason": "Staged files changed since review. Please run /team-review again."}'
    exit 0
  fi

  echo '{"decision": "allow"}'

elif [[ "$PHASE" == "post" ]]; then
  # --- PostToolUse: clean up gate file after successful commit ---
  # If no staged changes remain, the commit succeeded
  if [[ -f "$GATE_FILE" ]] && git diff --cached --quiet 2>/dev/null; then
    rm -f "$GATE_FILE"
  fi
fi
