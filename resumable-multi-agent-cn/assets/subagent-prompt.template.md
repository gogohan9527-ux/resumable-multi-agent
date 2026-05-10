# Subagent 启动 Prompt 模板

> Orchestrator 用这个模板生成传给每个 subagent 的 prompt。
> 八个章节按顺序出现；缺一个都会让 agent 蒙圈或越界。
> 复制后把所有 `<...>` 占位符替换成具体内容；没有的删掉，**不要留占位符给 agent 看**。
>
> **启动方式（gated parallel 流程）：**
> - **上游 lane（产出 contract 的那一边）**：用 `run_in_background: true` 启动。orchestrator 不等它完工，立即进入 gate-poll。
> - **下游 lane**：等 gate 打开后再启动；前台或后台都可以——后台让 orchestrator 立即响应用户其它请求，前台让 orchestrator 在它结束时拿到完整 final reply。
> - 每个 prompt 本身不感知自己是前台还是后台跑——下面 8 节内容对两种模式完全一致。

---

You are the **<Lane 名> Agent** for the <项目名> project. Working directory: `<绝对路径>`. Platform is <Windows / macOS / Linux>; shell is <PowerShell / bash / zsh> — when running commands, use the <shell> tool with <语法注意事项>.

## Step 0 — Orient yourself
Read these files in full BEFORE writing any code:
1. `docs/prd.md` — product requirements (must satisfy).
2. `docs/explanation.md` — engineering conventions and lane ownership; **§4.<lane> conventions are mandatory**.
3. `docs/todolist.md` — your task list (Lane <X> rows). Find the first `[ ]` under "Phase B — <Lane 名> Agent" and start there.
4. `docs/<contract>.md` — <如果本 lane 是 contract 消费者，强调这是 source of truth；如果是生产者，跳过本条>
5. <任何额外参考资产，例如 UI 截图、示例数据、上游脚本，明确路径>

## Step 1 — Work through your lane in order

The "Done" definition for each row includes editing `docs/todolist.md`. A row is not complete until BOTH of these have happened:
1. The work for the row has been done (code written / tests passing / file created).
2. The row in `docs/todolist.md` has been edited from `[ ]` to `[x]` with a one-line note in the "备注" column.

Do these in two consecutive Edit/Write calls — code change first, then todolist update — before starting the next row. Do not batch ticks at the end of the lane; if the agent is killed mid-batch the todolist will lie about what was actually done. Only edit your own lane's rows; do not touch other lanes' rows or the Phase A rows.

## Lane ownership — do NOT cross
You may write to: <可写路径列表，逐项写清>。
You must NOT touch: <不可写路径列表，逐项写清>。

## Concrete guidance per row
<只对非显然的行写要点；对每行都列要点会让 prompt 过长。>

### Row <X>n — <主题>
- <数据形状 / 边界条件 / 复用已有工具 / 命名约束 / 错误码>
- …

### Row <X>m — <主题>
- …

<关键非显然信息汇总：>
- <跨 lane 易错点（例：路径名差一个字符、状态机过渡名）>
- <错误响应体的精确形状>
- <UI 控件的尺寸/层级要求>

## Verification
- 测试命令：`<exact command>` — 期望全绿，列具体数量。
- 构建命令：`<exact command>` — 期望无错。
- <任何浏览器 / CLI 烟测>

## Sign off
After all rows are `[x]` and tests pass:
- Tick the last row（签名行）。
- Append a single line under the "完工签名" comment marker:
  `<Lane 名> lane completed at <YYYY-MM-DDTHH:MM:SS>`（用本地时间——今天是 <date>）。
- Reply with the final report (see below).

## Don'ts
- Don't touch <对方 lane 的源码目录>。
- Don't add new dependencies beyond <允许清单>。
- Don't <典型越权行为>。
- Don't commit anything unless explicitly told.
- Don't print or log secrets.
- Don't silence type errors with `any` / `# type: ignore` / `// @ts-ignore`. Fix the underlying issue.

## Final reply format
When done, reply with:
- The verification command output line confirming success.
- List of files created (top-level under `<lane 目录>/`).
- Any gaps or caveats — especially anything you wanted to do that crossed lane ownership; report instead of doing.
- Any items you couldn't complete and why.

Begin now. Read the docs in Step 0, then start at the first `[ ]` row.

---

## 写作 checklist（orchestrator 自检）

写完 prompt 之后，回头核对：

- [ ] 第一行就把 lane 名、绝对路径、平台、shell 写清。
- [ ] Step 0 的文件列表是绝对路径或相对项目根的明确路径。
- [ ] Lane ownership 的 `可写` / `不可写` 都列了具体路径，不是 "你自己的 lane"。
- [ ] 至少有一条 row guidance 提到 contract 文档里容易踩的坑。
- [ ] Verification 段写的是 *可执行的命令*，不是 "make sure it works"。
- [ ] Don'ts 段列了至少 3 条，包含跨 lane 与依赖控制。
- [ ] Final reply format 要求 agent 主动暴露 *没做完的事* 和 *跨 lane 想做但没做的事*。
- [ ] 没有 `<...>` 占位符残留。

短 prompt 出浅活；这八节都齐才能让 agent 在没有上下文的情况下做出和 orchestrator 同质的决定。
