需求总结
目标
构建一个 Claude Code Plugin，名为 team-review，在 Claude Code 内强制执行提交前质量门控，不可绕过（仅限 Claude Code 层面，用户终端直接 git commit 不受限），可开源共享给团队。

触发方式

用户输入 /team-review [n]，n 为最大轮数，默认 3


前置检查
无 staged 文件（`git diff --cached` 为空）→ 报错提示用户先 stage 文件，终止流程。

核心流程
Phase 1 — Agent Teams 并行 Review + 辩论
启动一个 Agent Team，四个角色：

security-reviewer：安全漏洞（注入、权限绕过、数据泄露）
performance-reviewer：性能退化（N+1、阻塞调用、复杂度恶化）
simplicity-reviewer：不必要的复杂度（难懂逻辑、死代码、过度抽象）
devil-advocate：通过 SendMessage 直接与各 reviewer 讨论追问（每个 reviewer 最多 2 轮追问），reviewer 可补充证据或承认误判，最终输出经辩论筛选的确认列表

Review 哲学：安全、高效、简洁，只改必须改的。devil-advocate 默认立场是保留原代码，举证责任在 reviewer 一侧。只应用 CONFIRMED-CRITICAL 和 CONFIRMED-HIGH，REJECTED 一律不动。
Review 范围：每轮对完整 `git diff --cached` 进行全量审查。
用户确认：devil-advocate 产出确认列表后，展示给用户确认，用户同意后再执行修复。
修复执行：由主进程（SKILL.md orchestrator）根据确认列表修改代码。
收敛判断

本轮有修改 → 回到 Phase 1 重新 review（全量 diff）
本轮无修改 → 进入 Phase 2
超过最大轮数 → 暂停，向用户提供选项：(a) 追加 N 轮 review (b) 放弃本次提交

Phase 2 — 测试
由 test-reviewer agent 负责执行：

运行与改动相关的测试（单元测试 + e2e，若项目有 e2e 配置则执行，否则跳过）
全部通过 → Phase 3
有失败 → 主进程修 bug → 回到 Phase 1（bug 修复也是代码改动，需全量重审）

Phase 3 — Commit

写入 gate 文件
执行 git commit
Commit 成功后清除 gate 文件


关键约束
不可绕过（Claude Code 层面）：在 Claude Code 层（PreToolUse hook）拦截 git commit，--no-verify 也被硬性 block，拦截时提示用户"请先运行 /team-review"。注意：这仅限于 Claude Code 内部，用户在终端直接执行 git commit 不受此限制。
中断续签不重复执行：commit 中途中断后，再次触发时检查 gate 文件是否有效、staged 文件是否未变动，满足条件直接放行，不重跑 review。

Gate 文件设计
位置：项目根目录 `.team-review-gate.json`（加入 .gitignore）
记录 review 通过状态，含 staged 文件的 SHA-256 hash。staged 文件变动则 gate 失效，需重跑 review。
写入时机：Phase 1 收敛且 Phase 2 测试全过后。
清除时机：PostToolUse hook 检测到 commit 成功后删除。

Plugin 结构
team-review/
├── .claude-plugin/
│   └── plugin.json              ← name / version / author
├── skills/
│   └── team-review/
│       └── SKILL.md             ← /team-review [n] 入口，$ARGUMENTS 接收轮数
├── agents/
│   ├── security-reviewer.md
│   ├── performance-reviewer.md
│   ├── simplicity-reviewer.md
│   ├── devil-advocate.md
│   └── test-reviewer.md         ← Phase 2 测试执行者
└── hooks/
    ├── hooks.json               ← PreToolUse 拦截 + PostToolUse 清除 gate
    └── pre-commit-gate.sh       ← hook 命令处理脚本

分发方式

开源：推到 GitHub，用户后续通过 xukaifu/team-review 进行安装
