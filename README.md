# team-review

A Claude Code plugin that enforces pre-commit quality gates. Staged changes are reviewed by dynamically chosen parallel agents, then adversarially challenged before commit is allowed.

## Install

```bash
/plugin marketplace add xukaifu/dev-forge
/plugin install team-review@dev-forge
```

## Usage

```
/team-review [n] [guidance]
```

| Command | Effect |
|---------|--------|
| `/team-review` | Review with 1 round |
| `/team-review 3` | Review with up to 3 rounds |
| `/team-review 3 focus on SQL injection` | Review with guidance |
| `/team-review off` | Disable the gate |
| `/team-review on` | Re-enable the gate |

The plugin blocks `git commit` inside Claude Code until review passes. Terminal `git commit` is unaffected.

## How It Works

1. **Review** — Analyzes the diff, dispatches 1–3 reviewers in parallel based on what changed
2. **Challenge** — Orchestrator acts as devil's advocate, rejects unsubstantiated findings
3. **Test** — Runs related tests if a test framework exists
4. **Commit** — Writes a gate marker file, commits, then auto-cleans the marker

If fixes are applied, the loop repeats (up to max rounds).

## Structure

```
team-review/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── team-review/
│       └── SKILL.md
└── hooks/
    ├── hooks.json
    └── pre-commit-gate.sh
```

## Requirements

- Claude Code CLI
- Git

## License

MIT
