# <Project Name> - Engineering Rules and Explanation

> This file defines **how to build**, **who may edit what**, and **how to run the project**.
> All contributors, including subagents, must follow it.
> Written by the orchestrator in Phase A. No Phase B lane may modify this file.

## 1. Repository Structure

```text
<project>/
├── <lane-A-dir>/            # Owned by Lane A
├── <lane-B-dir>/            # Owned by Lane B
├── docs/
│   ├── prd.md
│   ├── explanation.md       # This file
│   ├── <contract>.md        # Written and maintained by Lane A
│   └── todolist.md          # Multi-lane progress tracker
├── .gitignore
└── README.md
```

## 2. Lanes and Ownership (Prevent Cross-Lane Collisions)

> The column names `Writable paths` and `Read-only paths` are part of the protocol. The subagent prompt reuses them verbatim. If you rename them, also update the lane headers in `docs/todolist.md` ("**Ownership**" and "**Do not touch**") and each subagent prompt's "Lane ownership" section, or the prompts will drift.

| Lane | Writable paths | Read-only paths |
|------|----------------|-----------------|
| **<Lane A>** | `<lane-A-dir>/**`, `docs/<contract>.md`, `docs/todolist.md` (A rows only), `README.md` (Lane A section) | `<lane-B-dir>/**`, `docs/prd.md`, `docs/explanation.md` |
| **<Lane B>** | `<lane-B-dir>/**`, `docs/todolist.md` (B rows only), `README.md` (Lane B section) | `<lane-A-dir>/**`, `docs/<contract>.md` (read-only reference), `docs/prd.md`, `docs/explanation.md` |

Shared files such as PRD, explanation, and reference assets are **read-only**. If a change is needed, raise it in the conversation and let the orchestrator decide.

## 3. Naming Conventions

| Entity | Rule | Example |
|--------|------|---------|
| <id 1> | <Rule> | <Example> |
| File | <Rule> | <Example> |

## 4. Coding Standards

### 4.1 <Lane A>

- <Language version>, <lint/format tools>
- <Required or forbidden patterns>
- ...

### 4.2 <Lane B>

- ...

## 5. Configuration and Secrets

- Real configuration files are **never committed**. Add them to `.gitignore`.
- Provide a `<config>.example.<ext>` template.
- On startup, validate all required fields. If any are missing, exit and print the missing field names.
- Do not write secrets to logs, error messages, or responses.

## 6. Error Handling and Logging

- <Logging framework and levels>
- <Redaction requirements>
- <User-visible error display conventions>

## 7. Testing Expectations

| Scope | Content |
|-------|---------|
| <Lane A> unit | ... |
| <Lane B> unit | ... |
| Integration / smoke | ... |

All test commands must pass before a lane is considered complete.

## 8. Local Run Instructions

### 8.1 Prepare Configuration

```sh
# Copy the template and fill in secrets
```

### 8.2 Start <Lane A>

```sh
# Command sequence
```

### 8.3 Start <Lane B>

```sh
# Command sequence
```

### 8.4 Access / Verify

<Browser URL / CLI command / verification steps>

## 9. Git and Commits (If Applicable)

- One lane = one or more independent commits. Commit messages should look like: `<lane>: <verb>(<row id>)`.
- Do not commit across lanes.
- Do not use `--no-verify`.

## 10. Resume Convention

`docs/todolist.md` is the single source of truth for resumable execution. Each agent follows this workflow:

1. Read `docs/todolist.md` and locate the first unchecked item in its own lane.
2. Complete the item, then immediately check it off and add a one-line note.
3. After all rows are complete, append `<Lane> lane completed at <ISO time>` at the end of the file.

If an agent crashes midway, relaunch it with the same prompt. It will continue from the first unchecked item.

## 11. Assistant Restrictions

- Do not modify this file, `docs/prd.md`, or `docs/<contract>.md` unless your lane owns the contract.
- Do not create new binary assets.
- Do not hardcode secrets or external URLs in code. Use configuration instead.
- Do not assume implementation details from another lane. Trust only `docs/<contract>.md` and `docs/prd.md`.
