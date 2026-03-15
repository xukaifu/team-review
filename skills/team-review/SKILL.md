---
name: team-review
description: Pre-commit quality gate. Reviews staged changes with parallel agents and adversarial challenge before allowing commit. Usage: /team-review [n] [guidance]. Use /team-review off|on to toggle.
---

# Team Review

## Arguments

```
$ARGUMENTS
```

- `off` → Create `.team-review-disabled` in project root, print confirmation, **STOP**.
- `on` → Remove `.team-review-disabled`, print confirmation, **STOP**.
- First word is integer → `MAX_ROUNDS` (default **1**). Remaining text → `USER_GUIDANCE`.

## Rules

- Respond in the **same language** as the user.
- Execute intermediate operations silently — only show review results and key status.
- Ensure `.team-review-gate` is in `.gitignore`.

## Pre-flight

1. `git diff --cached` — if empty, tell user to stage files and **STOP**.
2. If `.team-review-gate` exists → review already passed, skip to **Commit**.

## Review Loop (max MAX_ROUNDS)

1. **Dispatch** — Analyze the staged diff. Choose relevant review dimensions based on what changed. Dispatch agents in parallel (`run_in_background: true`) with focused review prompts. Print one status line: `"⏳ {n} reviewers ({dimensions}) working — results below when done."`
2. **Challenge** — When agents return, act as devil's advocate. Default stance: keep original code. Burden of proof on reviewers. Reject theoretical/unsubstantiated findings. Only confirm findings with concrete evidence.
3. **Present** — Show confirmed and rejected findings in a table. If no confirmed findings → converged, proceed to **Test**.
4. **Confirm** — Ask user to approve fixes. If rejected → **STOP**.
5. **Fix & re-stage** — Apply CRITICAL/HIGH fixes (LOW shown only). `git add` modified files. Go to step 1 for next round.

## Test

Run tests related to the changed files using the project's existing test framework. If no test framework → skip. If tests pass → **Commit**. If tests fail → fix, re-stage, return to **Review Loop**.

## Commit

1. Create `.team-review-gate` marker file.
2. Ask user for commit message or generate one. Run `git commit`.
3. PostToolUse hook auto-cleans the gate file.
