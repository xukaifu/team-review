#!/usr/bin/env bash
# team-review pre-commit gate hook
# PreToolUse ("pre"): blocks git commit unless gate file exists
# PostToolUse ("post"): cleans up gate file after commit

PHASE="${1:-pre}"

# --- PostToolUse: clean up gate file after commit ---
if [[ "$PHASE" == "post" ]]; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
  GATE="$REPO_ROOT/.team-review-gate"
  if [[ -f "$GATE" ]] && git diff --cached --quiet 2>/dev/null; then
    rm -f "$GATE"
  fi
  exit 0
fi

# --- PreToolUse: intercept git commit commands ---
INPUT=$(cat)
if ! printf '%s' "$INPUT" | grep -q '"Bash"' || ! printf '%s' "$INPUT" | grep -qE '\bgit\b.*\bcommit\b'; then
  echo '{"decision": "allow"}'
  exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"

# Disabled → allow
if [[ -f "$REPO_ROOT/.team-review-disabled" ]]; then
  echo '{"decision": "allow"}'
  exit 0
fi

# Block --no-verify
if printf '%s' "$INPUT" | grep -qE -- '--no-verify'; then
  echo '{"decision": "block", "reason": "--no-verify is not allowed. Run /team-review first."}'
  exit 0
fi

# Gate file exists → allow, otherwise block
if [[ -f "$REPO_ROOT/.team-review-gate" ]]; then
  echo '{"decision": "allow"}'
else
  echo '{"decision": "block", "reason": "No review gate found. Run /team-review first."}'
fi
