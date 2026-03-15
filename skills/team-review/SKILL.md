---
name: team-review
description: Pre-commit quality gate with parallel code reviews and adversarial debate. Usage: /team-review [n] [guidance] (n = max rounds, default 1). Use /team-review off|on to toggle the gate.
---

# Team Review — Pre-Commit Quality Gate Orchestrator

You are orchestrating a mandatory code review process. Follow each phase exactly.

**Communication rules:**
- Respond in the **same language** as the user's most recent message.
- Keep output **minimal** — only print the status messages specified in each step. Do NOT narrate intermediate operations (git diff, hash computation, .gitignore checks, etc.). Execute them silently.

## Arguments

```
$ARGUMENTS
```

### Special commands

- `off` → Create `.team-review-disabled` in the project root. Tell the user **"Team review gate disabled. Claude can commit freely. Run /team-review on to re-enable."** and **STOP**.
- `on` → Remove `.team-review-disabled` from the project root. Tell the user **"Team review gate re-enabled."** and **STOP**.

### Review arguments

Parse remaining arguments:
1. If the first word is a valid integer, use it as `MAX_ROUNDS` and treat the remaining text as `USER_GUIDANCE`.
2. If the first word is not a number, default `MAX_ROUNDS` to **1** and treat the entire input as `USER_GUIDANCE`.
3. If empty, `MAX_ROUNDS` = **1** and `USER_GUIDANCE` = empty.

Examples:
- `/team-review` → MAX_ROUNDS=1, no guidance
- `/team-review 3` → MAX_ROUNDS=3, no guidance
- `/team-review 3 遵守安全、高效的原则` → MAX_ROUNDS=3, USER_GUIDANCE="遵守安全、高效的原则"
- `/team-review focus on SQL injection risks` → MAX_ROUNDS=1, USER_GUIDANCE="focus on SQL injection risks"

## Pre-flight Checks

1. Run `git diff --cached` — if output is empty, tell the user **"No staged files. Please `git add` your changes first."** and **STOP**.
2. Check if `.team-review-gate.json` exists and is valid:
   - Compute: `git diff --cached | git hash-object --stdin`
   - If the gate file exists AND its `staged_diff_hash` matches the computed hash → the review already passed and staged files are unchanged. Tell the user **"Review gate is still valid. Proceeding to commit."** and skip directly to **Phase 3, Step 3.2**.
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

### Step 1.3 — Analyze Diff & Dispatch Reviewers

Analyze the `DIFF` content to determine which review dimensions are relevant. Consider:

- **What changed:** file types, language, domain (auth, API, UI, config, tests, docs, etc.)
- **Scale:** a one-line fix needs fewer reviewers than a multi-file feature
- **Risk areas:** code touching user input, credentials, database, external APIs, or concurrency warrants security review; hot paths warrant performance review; large refactors warrant simplicity review

Select **1–3 review dimensions** that are most relevant to this specific diff. Examples:
- CSS-only change → `visual-consistency` (1 reviewer)
- Auth endpoint change → `security`, `input-validation` (2 reviewers)
- New feature with DB queries → `security`, `performance`, `simplicity` (3 reviewers)
- Database migration → `data-integrity`, `performance` (2 reviewers)
- Typo fix in README → skip reviewers entirely, proceed to Phase 2

For each chosen dimension, dispatch an Agent (all with `run_in_background: true`):
- `prompt`: Include the review dimension name, what to focus on, and the diff:
  ```
  "You are a code reviewer focused on {dimension}. Review this staged diff for {focus_description}. Return findings as a JSON array with fields: id, severity (CRITICAL/HIGH/LOW), file, lines, title, evidence, fix. Return empty array if no issues.\n\n```diff\n{DIFF}\n```{GUIDANCE_BLOCK}"
  ```
- Give each agent access to tools: `Grep, Glob, Read`

Where `{GUIDANCE_BLOCK}` is:
- If `USER_GUIDANCE` is non-empty: `"\n\nUser review guidance: {USER_GUIDANCE}"`
- If `USER_GUIDANCE` is empty: `""` (omit entirely)

Print exactly one status line after dispatching:

**"⏳ {N} reviewers ({dimension_list}) working in parallel — results will appear below when challenge concludes."**

Then wait silently for all agents to complete. Do **NOT** print any additional waiting/status messages.

### Step 1.4 — Challenge Findings (Devil's Advocate)

After all 3 reviewers return, **you** (the orchestrator) act as the devil's advocate. Collect all findings and challenge each one:

- **Default stance:** the original code should remain unchanged.
- **Burden of proof** is on the reviewers, not the code author.
- For each finding, ask: Is the evidence concrete? Is the severity realistic, not theoretical? Does the framework/runtime already handle this? Does the fix introduce new risks?
- Classify each finding:
  - **CONFIRMED-CRITICAL** — genuine, high-impact, concrete evidence
  - **CONFIRMED-HIGH** — real issue with realistic impact
  - **CONFIRMED-LOW** — minor issue worth noting
  - **REJECTED** — theoretical, unsubstantiated, or marginal

When in doubt, **REJECT**. False positives waste time and erode trust.

### Step 1.5 — Present Findings

Display confirmed and rejected findings to the user using tables. Only show severity levels that have findings — omit empty sections.

```
## Round {round}/{MAX_ROUNDS} — {confirmed_count} confirmed, {rejected_count} rejected

| # | Severity | Category | Location | Issue | Fix |
|---|----------|----------|----------|-------|-----|
| 1 | CRITICAL | {category} | {file}:{lines} | {title} | {fix} |
| 2 | HIGH | {category} | {file}:{lines} | {title} | {fix} |
| 3 | LOW | {category} | {file}:{lines} | {title} | {fix} |

Rejected:
| Category | Issue | Reason |
|----------|-------|--------|
| {category} | {title} | {rejection_reason} |
```

If **no confirmed findings** (empty `confirmed_findings` array): convergence reached. Print **"Review converged — no issues found."** and proceed to **Phase 2**.

### Step 1.6 — User Confirmation

Ask the user: **"Apply these fixes? (y/n)"**
- **n** → Stop the process entirely.
- **y** → Continue to Step 1.7.

### Step 1.7 — Apply Fixes

For each **CRITICAL** and **HIGH** confirmed finding, apply the recommended fix using Edit tool. Skip **LOW** findings (shown for awareness only). Then re-stage all modified files:
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

Compute the hash of the current staged diff:
```bash
git diff --cached | git hash-object --stdin
```

Write `.team-review-gate.json`:
```json
{
  "version": 1,
  "timestamp": "{ISO-8601 timestamp}",
  "staged_diff_hash": "{hash}",
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
- Default stance is to **keep the original code**. Burden of proof is on the reviewers.
- Match reviewer count and focus to the diff — don't over-review trivial changes.
- **CONFIRMED-CRITICAL** and **CONFIRMED-HIGH** findings get fixed. **CONFIRMED-LOW** findings are shown but not auto-fixed — user decides.
- **REJECTED** findings are left untouched.
- Each review round operates on the **full** `git diff --cached`, not incremental changes.
