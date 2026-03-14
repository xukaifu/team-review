# team-review

A Claude Code plugin that enforces mandatory pre-commit quality gates. Code is reviewed by parallel agent teams with adversarial debate before any commit is allowed.

## Install

```bash
# Add marketplace
/plugin marketplace add xukaifu/dev-forge

# Install plugin
/plugin install team-review@dev-forge
```

## Usage

Stage your changes, then run:

```
/team-review [n] [guidance]
```

- `n` — max review rounds (default: 1)
- `guidance` — optional review focus instructions

Examples:

```
/team-review
/team-review 3
/team-review 3 focus on security and SQL injection
/team-review off
/team-review on
```

| Command | Effect |
|---------|--------|
| `/team-review` | Run review with 1 round |
| `/team-review 3` | Run review with up to 3 rounds |
| `/team-review off` | Disable the pre-commit gate |
| `/team-review on` | Re-enable the pre-commit gate |

The plugin blocks `git commit` inside Claude Code until the review process passes. Direct terminal `git commit` is unaffected.

## How It Works

### Phase 1 — Parallel Review + Debate

Four agents run in parallel:

| Agent | Focus |
|-------|-------|
| **security-reviewer** | Injection, auth bypass, data leaks |
| **performance-reviewer** | N+1 queries, blocking calls, complexity regression |
| **simplicity-reviewer** | Over-abstraction, dead code, unnecessary complexity |
| **devil-advocate** | Challenges all findings via adversarial debate |

The devil-advocate's default stance is **keep the original code**. Burden of proof is on reviewers. Only confirmed findings survive debate. Each reviewer gets up to 2 rounds of follow-up questions.

Results are presented in a table with a summary line. CRITICAL and HIGH findings are auto-fixed. LOW findings are shown for awareness only.

**Convergence:** no confirmed findings → Phase 2. Fixes applied → re-review (full diff). Max rounds exceeded → user chooses to add rounds or abandon.

### Phase 2 — Testing

The **test-reviewer** agent runs change-related unit tests and e2e tests (if configured). Test failures are fixed and trigger a return to Phase 1 for full re-review.

### Phase 3 — Commit

A gate file (`.team-review-gate.json`) is written with a hash of the staged diff. The PreToolUse hook validates this gate before allowing `git commit`. The gate file is auto-cleaned after a successful commit.

## Interrupt Recovery

If the process is interrupted after review passes, the gate file persists. On the next `/team-review` invocation, if the staged diff hasn't changed, the review is skipped and commit proceeds directly.

## Plugin Structure

```
team-review/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── team-review/
│       └── SKILL.md
├── agents/
│   ├── security-reviewer.md
│   ├── performance-reviewer.md
│   ├── simplicity-reviewer.md
│   ├── devil-advocate.md
│   └── test-reviewer.md
└── hooks/
    ├── hooks.json
    └── pre-commit-gate.sh
```

## Requirements

- Claude Code CLI
- Git

No other external dependencies. The hook script uses only git, grep, and sed.

## License

MIT
