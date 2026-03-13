---
name: team-review
description: Mandatory pre-commit quality gate. Runs parallel code reviews (security, performance, simplicity) with adversarial debate, then tests, before allowing git commit. Invoke with /team-review [n] where n is max review rounds (default 3).
---

# Team Review — Pre-Commit Quality Gate Orchestrator

You are orchestrating a mandatory code review process. Follow each phase exactly.

## Arguments

```
$ARGUMENTS
```

Parse the first word as the maximum review round count (integer). Default to **3** if empty or not a valid number. Store as `MAX_ROUNDS`.

## Pre-flight Checks

1. Run `git diff --cached` — if output is empty, tell the user **"No staged files. Please `git add` your changes first."** and **STOP**.
2. Check if `.team-review-gate.json` exists and is valid:
   - Compute: `git diff --cached | shasum -a 256 | cut -d' ' -f1`
   - If the gate file exists AND its `staged_diff_sha256` matches the computed hash → the review already passed and staged files are unchanged. Tell the user **"Review gate is still valid. Proceeding to commit."** and skip directly to **Phase 3, Step 3.2**.
3. Ensure `.team-review-gate.json` is in the project's `.gitignore`. If `.gitignore` doesn't exist or doesn't contain the entry, add it.

---

## Phase 1 — Review Loop

Initialize `round = 0`.

### Step 1.1 — Check Round Limit

Increment `round`. If `round > MAX_ROUNDS`:
- Tell the user: **"Maximum review rounds (MAX_ROUNDS) reached without convergence."**
- Ask the user:
  - **(a)** Add N more rounds — ask how many, add to MAX_ROUNDS, continue
  - **(b)** Abandon — stop entirely
- Wait for the user's choice before proceeding.

### Step 1.2 — Capture Staged Diff

Run `git diff --cached` and store the full output as `DIFF`.

### Step 1.3 — Dispatch Review Team

Create a team:
```
TeamCreate("review-round-{round}")
```

Dispatch **4 agents in parallel** (all in the same team, all with `run_in_background: true`):

1. **security-reviewer** — Agent tool with:
   - `subagent_type`: use the `security-reviewer` agent definition
   - `team_name`: "review-round-{round}"
   - `prompt`: "Review this staged diff for security vulnerabilities:\n\n```diff\n{DIFF}\n```"

2. **performance-reviewer** — Agent tool with:
   - `subagent_type`: use the `performance-reviewer` agent definition
   - `team_name`: "review-round-{round}"
   - `prompt`: "Review this staged diff for performance regressions:\n\n```diff\n{DIFF}\n```"

3. **simplicity-reviewer** — Agent tool with:
   - `subagent_type`: use the `simplicity-reviewer` agent definition
   - `team_name`: "review-round-{round}"
   - `prompt`: "Review this staged diff for unnecessary complexity:\n\n```diff\n{DIFF}\n```"

4. **devil-advocate** — Agent tool with:
   - `subagent_type`: use the `devil-advocate` agent definition
   - `team_name`: "review-round-{round}"
   - `prompt`: "Challenge the findings from security-reviewer, performance-reviewer, and simplicity-reviewer. The staged diff is:\n\n```diff\n{DIFF}\n```\n\nWait for their findings via SendMessage, then debate each finding (max 2 rounds per reviewer). Return the confirmed findings list."

Wait for all agents to complete. The **devil-advocate's output** is the authoritative result.

### Step 1.4 — Present Findings

Parse the devil-advocate's confirmed findings. Display to the user:

```
## Review Round {round}/{MAX_ROUNDS}

### Confirmed Findings

#### CRITICAL
1. [{category}] {file}:{lines} — {title}
   Fix: {fix}

#### HIGH
2. [{category}] {file}:{lines} — {title}
   Fix: {fix}

### Rejected (no action)
- [{category}] {title} — {rejection_reason}
```

If **no confirmed findings** (empty `confirmed_findings` array): convergence reached. Print **"Review converged — no issues found."** and proceed to **Phase 2**.

### Step 1.5 — User Confirmation

Ask the user: **"Apply these fixes? (y/n)"**
- **n** → Stop the process entirely.
- **y** → Continue to Step 1.6.

### Step 1.6 — Apply Fixes

For each confirmed finding, apply the recommended fix using Edit tool. Then re-stage all modified files:
```bash
git add <modified-files>
```

**Go back to Step 1.1** for the next review round.

---

## Phase 2 — Testing

Dispatch the **test-reviewer** agent:

```
Agent(
  subagent_type: "test-reviewer",
  prompt: "Run tests related to these staged changes:\n\n```diff\n{DIFF}\n```\n\nDetect the test framework, scope tests to changed files, run unit tests and e2e (if configured). Return results as JSON."
)
```

Parse the test-reviewer's result:

- **All tests pass** (status: "pass" or "skip") → Proceed to **Phase 3**.
- **Tests fail** (status: "fail"):
  1. Display failures to the user.
  2. Fix the failing tests / source bugs using Edit tool.
  3. Re-stage fixes: `git add <files>`
  4. **Go back to Phase 1** (the bug fix is a code change that needs full re-review). The `round` counter continues from where it left off.

---

## Phase 3 — Commit

### Step 3.1 — Write Gate File

Compute the SHA-256 hash of the current staged diff:
```bash
git diff --cached | shasum -a 256 | cut -d' ' -f1
```

Write `.team-review-gate.json`:
```json
{
  "version": 1,
  "timestamp": "{ISO-8601 timestamp}",
  "staged_diff_sha256": "{hash}",
  "review_rounds": {round},
  "status": "passed"
}
```

### Step 3.2 — Execute Commit

Ask the user for a commit message, or generate one based on the staged changes.

Run:
```bash
git commit -m "{message}"
```

The PostToolUse hook will automatically clean up `.team-review-gate.json` after a successful commit.

Tell the user: **"Commit successful. Gate file cleaned up."**

---

## Review Philosophy

- **Safe, efficient, simple** — only change what must be changed.
- The devil-advocate's default stance is to **keep the original code**.
- Burden of proof is on the reviewers.
- Only **CONFIRMED-CRITICAL** and **CONFIRMED-HIGH** findings get fixed.
- **REJECTED** findings are left untouched.
- Each review round operates on the **full** `git diff --cached`, not incremental changes.
