# Resumable Multi-Agent Skill

一个用于大型开发任务的可续跑工作流模板。它解决 agent 切换、会话中断、上下文重置后无法断点继续的问题：把需求、规则、任务清单和跨模块契约写入项目内的 `docs/`，让多个 lane 可以并行推进；重新启动或更换 agent 后，也能从自己的第一个未完成事项继续。

---

A resumable workflow template for larger engineering tasks. It solves the handoff problem when agents change, sessions stop, or context resets: requirements, rules, checklists, and inter-lane contracts are stored in `docs/`, so each lane can continue from its first unfinished item after a restart.

---

## Getting Started

选择需要的版本并导入到 Claude：

- `resumable-multi-agent-cn/`

导入后，在对话中说明项目目标，并使用类似指令：

```text
使用 resumable-multi-agent，帮我生成一个运动可视化页面。
```

---

Select the required version and import to Claude:

- `resumable-multi-agent-en/`

After importing, state the project goal in the conversation and use similar instructions:

```text
Use resumable-multi-agent, help me generate a sports visualization page.
```

---

## Claude Auto Workflow

1. Phase A: 生成 PRD、工程说明、任务清单。
2. 用户确认后输入 `resume` / `继续`。
3. 上游 lane 先发布契约文件，下游 lane 读契约后并行工作。
4. 每个 lane 完成一项就勾选 `docs/todolist.md`。
5. 切换 agent 或重新启动时，新 agent 先读取 `docs/todolist.md`，从第一个未勾选项继续。
6. 所有 lane 完成后，由主流程合并草稿、清理临时文件并运行验收。

---

1. Phase A: Generate PRD, engineering documentation, and task list.
2. After user confirmation, input `resume` / `continue`.
3. Upstream lanes publish contract files first, downstream lanes read contracts and work in parallel.
4. Each lane checks off `docs/todolist.md` upon completing an item.
5. When switching agents or restarting, the new agent first reads `docs/todolist.md` and continues from the first unchecked item.
6. After all lanes are completed, the main process merges drafts, cleans up temporary files, and runs acceptance tests.