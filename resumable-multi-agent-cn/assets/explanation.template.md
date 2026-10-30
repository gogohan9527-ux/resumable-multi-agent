# <项目名> — 项目规章与说明

> 本文件定义 **怎么做**、**谁能改什么**、**怎么跑起来**。
> 所有贡献者（含 AI 子智能体）必须遵守。
> 由 orchestrator 在 Phase A 写成；Phase B 任何 lane 都不得修改。

## 1. 仓库结构

```
<project>/
├── <lane-A-dir>/            # Lane A 负责
├── <lane-B-dir>/            # Lane B 负责
├── docs/
│   ├── prd.md
│   ├── explanation.md       # 本文件
│   ├── <contract>.md        # 由 Lane A 编写并维护
│   └── todolist.md          # 多 lane 进度追踪
├── .gitignore
└── README.md
```

## 2. Lane 与所有权（防止两个 Agent 互踩）

> 列名 `可写路径` / `不可写路径` 是协议的一部分，subagent prompt 会原文复用。改名前先同步改 `docs/todolist.md` 的 lane 头部（"**所有权**" / "**绝不动**" 两行）和每个 subagent prompt 的 "Lane ownership" 段，否则触发回填漂移。

| Lane | 可写路径 | 不可写路径 |
|------|---------|-----------|
| **<Lane A>** | `<lane-A-dir>/**`、`docs/<contract>.md`、`docs/todolist.md`（仅 A 行）、`README.md`（A 段落） | `<lane-B-dir>/**`、`docs/prd.md`、`docs/explanation.md` |
| **<Lane B>** | `<lane-B-dir>/**`、`docs/todolist.md`（仅 B 行）、`README.md`（B 段落） | `<lane-A-dir>/**`、`docs/<contract>.md`（只读引用）、`docs/prd.md`、`docs/explanation.md` |

公共文件（PRD、explanation、参考资源）**只读**。如需调整，先在对话中提出，由 orchestrator 决定。

## 3. 命名约定

| 实体 | 规则 | 示例 |
|------|------|------|
| <id 1> | <规则> | <例子> |
| 文件 | <规则> | <例子> |

## 4. 编码规范

### 4.1 <Lane A>

- <语言版本>，<lint/format 工具>
- <禁止 / 必须的写法>
- …

### 4.2 <Lane B>

- …

## 5. 配置与密钥

- 真实配置文件 **永不入库**（写入 `.gitignore`）。
- 提供 `<config>.example.<ext>` 模板。
- 启动时校验所有必填字段，缺失则进程退出并打印缺失字段名。
- 禁止把密钥写进日志、错误信息、响应。

## 6. 错误处理与日志

- <日志框架与级别>
- <脱敏要求>
- <用户可见错误的展示约定>

## 7. 测试期望

| 范围 | 内容 |
|------|------|
| <Lane A> 单元 | … |
| <Lane B> 单元 | … |
| 集成 / smoke | … |

测试命令全绿是 lane 完工的硬门槛。

## 8. 本地运行

### 8.1 准备配置

```sh
# 复制模板并填入密钥
```

### 8.2 启动 <Lane A>

```sh
# 命令序列
```

### 8.3 启动 <Lane B>

```sh
# 命令序列
```

### 8.4 访问 / 验证

<浏览器 URL / CLI 命令 / 验证步骤>

## 9. Git 与提交（如适用）

- 一个 lane = 一个/多个独立提交，提交信息形如：`<lane>: <动词>(<行号>)`
- 不允许跨 lane 提交。
- 不允许 `--no-verify`。

## 10. 恢复执行约定

`docs/todolist.md` 是断点续跑的唯一真相源。每个 Agent 的工作流：

1. 读 `docs/todolist.md`，定位本 lane 第一个未勾选项。
2. 完成后立即勾选并写一行备注。
3. 全部完成后在文件末尾追加 `<Lane> lane completed at <ISO 时间>`。

如果一个 Agent 中途崩溃，重启它只需要再传同一个 prompt——它会从未勾选项继续。

## 11. AI 助手限制

- 不要修改本文件、`docs/prd.md`、`docs/<contract>.md`（除拥有 lane 外）。
- 不要新建二进制资源。
- 不要在代码里硬编码密钥或外部 URL（一律走 config）。
- 不要假设其他 lane 的实现细节，只信任 `docs/<contract>.md` 与 `docs/prd.md`。
