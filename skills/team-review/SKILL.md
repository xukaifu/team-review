---
name: team-review
description: Review code changes with parallel agents and adversarial challenge. Usage: /team-review [n] [guidance].
---

# Team Review

## Arguments

```
$ARGUMENTS
```

- First word is integer → `MAX_ROUNDS` (default **1**). Remaining text → `USER_GUIDANCE`.

## Rules

- Respond in the **same language** as the user.
- Execute intermediate operations silently — only show review results and key status.

## Process (max MAX_ROUNDS)

1. **Determine scope** — Figure out what to review: a commit hash/range in arguments, staged changes, unstaged changes, or whatever the user specified. If nothing to review, tell user and **STOP**.
2. **Dispatch** — Analyze the diff. Choose relevant review dimensions based on what changed. Dispatch agents in parallel (`run_in_background: true`) with focused review prompts. Print one status line: `"⏳ {n} reviewers ({dimensions}) working — results below when done."`
3. **Challenge** — When agents return, act as devil's advocate. Default stance: keep original code. Burden of proof on reviewers. Reject theoretical/unsubstantiated findings. Only confirm findings with concrete evidence. When challenging, also consider: git history/blame (why was the code written this way?), previous review feedback on the same files, and inline code comments/documentation that may justify the current approach.
4. **Present** — Show confirmed and rejected findings in a table. If no confirmed findings → converged, **DONE**.
5. **Confirm** — Ask user to approve fixes. If rejected → **STOP**.
6. **Fix** — Apply CRITICAL/HIGH fixes (LOW shown only). Go to step 2 for next round.

If an agent fails or times out, note it in the results and proceed with available findings.
