# team-review

A Claude Code plugin that reviews staged changes with dynamically chosen parallel agents and adversarial challenge.

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
| `/team-review` | Review staged changes (1 round) |
| `/team-review 3` | Review with up to 3 rounds |
| `/team-review 3 focus on SQL injection` | Review with guidance |

## How It Works

1. **Review** — Analyzes the diff, dispatches reviewers in parallel based on what changed
2. **Challenge** — Orchestrator acts as devil's advocate, rejects unsubstantiated findings
3. **Fix** — Applies confirmed fixes, re-stages, and re-reviews until converged or max rounds reached

## Structure

```
team-review/
├── .claude-plugin/
│   └── plugin.json
└── skills/
    └── team-review/
        └── SKILL.md
```

## Requirements

- Claude Code CLI

## License

MIT
