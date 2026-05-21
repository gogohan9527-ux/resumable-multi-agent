---
name: resumable-multi-agent
description: This skill should be used when the user asks to "split this into agents", "two agents", "frontend agent + backend agent", "multi-agent project", "lane-based execution", "resumable workflow", "this is too big for one agent", "checkpoint and resume", "context reset", "context too long", "split frontend and backend", "parallel subagents", "断点续跑", "多 agent 协作", "拆成多个 agent", "用 subagent 接力". Establishes a five-document workflow (plan, requirements, rules, inter-lane contract, todolist) and a two-phase execution model — orchestrator writes synchronous documentation first, then subagents resume from the first unchecked checkbox in their lane. Use this skill proactively whenever the user describes a project that touches multiple distinct components (e.g. backend + frontend, parser + renderer, ETL + dashboard) and is sizable enough that one-shot execution risks context truncation — even if the user does not explicitly say "agent", "lane", or "resume".
version: 0.1.0
---

## On Load — 必读第一步

**每次调用此 skill，在执行任何其他步骤之前，必须先向用户发送以下消息（可根据语境调整语言，但含义不变）：**

> 已读取 `resumable-multi-agent` skill，开始执行工作流。

# Resumable Multi-Agent Workflow

## Purpose

Coordinate a non-trivial project across two or more subagents while keeping execution **restart-safe**: if a subagent crashes or its context is reset, re-launching it with the same prompt resumes from the first unchecked checkbox in its lane. State lives entirely in markdown files on disk — no in-memory session is required to make forward progress.

## When to apply

Apply this workflow when **all** of the following hold:

- The project has clearly separable components (e.g. backend + frontend, ETL + dashboard, parser + renderer).
- The total work is large enough that a single agent's context window risks compaction mid-execution.
- The user wants progress to survive an AI restart or context reset.
- A contract exists or can be written between components (one component's output is another's input).

Do NOT apply for trivial single-file edits, exploratory research, or tasks where one agent's complete output trivially fits in context.

The default templates show 2 lanes, but the workflow scales to N lanes — duplicate the lane block in `todolist.md` and add a row in the ownership table for each. Beyond 4 lanes, reconsider whether some can be merged: too many lanes raises coordination cost faster than parallelism saves time.

## The five documents

All five live under `docs/` in the project root during active development. The plan file lives in the user's plan directory if invoked from plan mode. After Phase C completion, the four core documents are archived to `docs/archive/<module-name>/`.

| File | Purpose | Owner | When written | Lifecycle |
|------|---------|-------|--------------|-----------|
| `plans/<slug>.md` | Implementation plan, drafted in plan mode | Orchestrator | Phase 0 | Persistent in plans/ |
| `docs/prd.md` | What the system must do (requirements, acceptance criteria) | Orchestrator | Phase A | Archived after Phase C |
| `docs/explanation.md` | Engineering rules, lane ownership, run instructions | Orchestrator | Phase A | Archived after Phase C |
| `docs/todolist.md` | Resume-safe checklist, split by lane; accumulates one dated section per run | Orchestrator (initial + Phase C append), each subagent (ticking own rows) | Phase A initial; Phase B updates; Phase C append on follow-up runs | Archived after Phase C |
| `docs/<contract>.md` | Inter-lane contract (e.g. `interface.md`, `schema.md`); accumulates with deprecation/version markers across runs | Upstream lane subagent (drafts), Orchestrator (Phase C merge) | Phase B at upstream-lane midpoint; Phase C merges drafts into persistent file | Archived after Phase C |
| `docs/archive/<module>/` | Completed module archive containing the four core documents | Orchestrator | Phase C Step 6 | Permanent reference |
| `docs/archive/INDEX.md` | Archive catalog listing all completed modules | Orchestrator | Phase C Step 6 | Append-only |

The orchestrator never writes the contract during Phase B — that is produced by the upstream subagent. The orchestrator's only role on the contract is during Phase C, deterministically merging this-run's draft into the persistent file with conflict handling. Downstream lanes always read the persistent file as a hard contract.

**Per-run scratch convention (follow-up runs):** during Phase A on a follow-up run, the orchestrator points the upstream lane at `docs/<contract>.draft.md` instead of `docs/<contract>.md`. Phase C merges the draft into the persistent file and deletes it. On the first run, no draft suffix is used — the lane writes the persistent file directly.

## Three-phase execution model

The workflow has three phases. Phase A is synchronous (orchestrator + user). Phase B is parallel subagent execution. Phase C is a deterministic orchestrator-only merge & cleanup that turns this run's outputs into persistent project state and removes transient files, then archives completed modules.

### Phase A — Synchronous documentation (orchestrator only)

1. **Check for archived modules.** If the current task involves a previously completed module, read the relevant files from `docs/archive/<module-name>/` (prd.md, explanation.md, todolist.md, contract.md) to understand context and avoid duplication. List available archived modules to the user if uncertain which ones are relevant.
2. Read or draft a plan; if invoked from plan mode, use the plan file.
3. Write `docs/prd.md` from the plan and user dialogue.
4. Write `docs/explanation.md` declaring lane ownership, naming conventions, run commands, testing expectations.
5. Write `docs/todolist.md` with two top-level sections (one per lane), each a checklist. Add a Phase A section above with `[x]` rows showing the docs are done and a final `[ ]` row for "user issues resume command".
6. **Halt.** Reply to the user summarising the docs and ask for a resume command. Do NOT launch subagents yet.

This phase is synchronous because the user must agree to scope, rules, and lane decomposition before parallel work begins. Skipping the halt produces churn when the user disagrees three subagent launches later.

### Phase B — Subagent execution (gated parallel)

After the user types "resume" / "继续" / equivalent, run the upstream and downstream lanes **concurrently**, gated on the contract document. The downstream lane does not wait for upstream completion — it waits for the contract to be published, which happens at upstream's midpoint.

**Orchestrator launch sequence:**

1. **Launch upstream lane in background** (`run_in_background: true`). It works through its full row sequence in one continuous context — including rows after the contract. The orchestrator does NOT wait for it to finish.
2. **Poll for the contract gate.** The gate opens when both conditions hold:
   - `docs/<contract>.md` exists and has substantive content (e.g. > 500 bytes), AND
   - The contract row in `docs/todolist.md` is `[x]` (the upstream agent has explicitly checked it).
3. **Launch downstream lane** the moment the gate opens. It runs in foreground or background — orchestrator's choice — in parallel with the still-running upstream agent.
4. **Wait for both completion notifications.** Each agent appends its own signature line independently; both must appear before final smoke verification.

**Why "gate" rather than "split upstream into two agent runs":**
- Single upstream run = continuous context, no re-read of the docs between halves.
- Sync point is the contract file (a hard artifact), not an orchestrator-controlled boundary.
- If upstream crashes after publishing the contract, downstream is unaffected — it already has the contract and continues. Re-launching upstream with the same prompt resumes from the next `[ ]` row, including any post-contract work that didn't get checked.

**Each subagent's first action** is to read all five documents in order: prd → explanation → todolist → contract (if any) → asset references. From there the loop is the same:

```
read docs/todolist.md
locate first [ ] row in own lane
  if none → append signature, report done, exit
execute the row's task
edit the row: [ ] → [x], add brief note
loop
```

If a subagent crashes mid-execution, re-launching it with the same prompt resumes from the next unchecked row — no special "resume" mode needed because the prompt instructs it to read the todolist first.

**When to skip parallelization and run sequentially:**
- Upstream's post-contract work is small (< 25% of total upstream rows). Gain isn't worth the orchestration overhead.
- Downstream needs more than just the contract — e.g. shared runtime libraries, generated stubs, fixture data files. Either pre-list these as additional gates, or keep sequential.
- Two lanes are tightly coupled in unobvious ways (a sign the lane decomposition is wrong; consider merging them).

### Gate detection (orchestrator commands)

Use one of these poll loops between launching the upstream agent and launching the downstream agent. Run with the `Monitor` tool (or equivalent) so the orchestrator gets a single notification when the gate opens, instead of busy-polling.

PowerShell (Windows):
```powershell
$contract = "docs\<contract>.md"
$todolist = "docs\todolist.md"
$contractRow = "<contract row id, e.g. B9>"
while (-not ((Test-Path $contract) -and ((Get-Item $contract).Length -gt 500) -and (Select-String -Path $todolist -Pattern "^\| \Q$contractRow\E .*\[x\]" -Quiet))) {
    Start-Sleep -Seconds 5
}
"gate open"
```

Bash (macOS / Linux / WSL):
```bash
contract=docs/<contract>.md
todolist=docs/todolist.md
row='<contract row id, e.g. B9>'
until [ -s "$contract" ] && [ "$(wc -c < "$contract")" -gt 500 ] && grep -Eq "^\| $row .*\[x\]" "$todolist"; do
    sleep 5
done
echo "gate open"
```

The 500-byte threshold filters out a partially-written stub. Adjust per project — a one-endpoint contract may be smaller; a many-endpoint contract should comfortably clear several KB.

**Cap the wait** with a max-iterations bound so a stalled upstream doesn't hang the orchestrator forever; if the gate doesn't open within e.g. 20 minutes, surface it to the user and decide whether to wait, kill, or fall back to sequential.

### Phase C — Merge, cleanup & archive (orchestrator only)

After both lane signatures are present in `docs/todolist.md`, run Phase C. This phase is deterministic — orchestrator reads, edits, deletes, and archives; no subagent involved. It exists to turn this run's per-run artifacts into persistent project state, remove transient scratch files, and archive completed modules.

Phase C handles two cases with one set of rules:
- **First run** (project has no prior `docs/<contract>.md`, etc.): most steps are no-ops; only Step 4 (cleanup) and Step 6 (archive) do real work.
- **Follow-up run** (project already has `docs/<contract>.md` and prior todolist sections): merge logic kicks in.

**Convention for per-run scratch:** when the orchestrator launches a follow-up run, it directs each lane to write its contract additions to `docs/<contract>.draft.md` instead of editing the persistent file directly. The orchestrator may also stage explanation addenda to `docs/explanation.draft.md` during Phase A. This keeps Phase B agents from having to reason about the old document — they produce new content; Phase C handles the integration. On the first run, lanes write directly to the persistent path and `.draft.md` files don't appear.

#### Step 1 — Merge contract additions into `docs/<contract>.md`

If `docs/<contract>.draft.md` exists, merge it into `docs/<contract>.md`:

- **New endpoints / sections** (path or name not in the persistent file): append in the natural section ordering. No conflict.
- **Conflicting endpoints** (same path/name, different request, response, or error shape):
  - Keep the old definition. Prepend `**[已弃用 / DEPRECATED at <YYYY-MM-DD> — 请使用下方 v<N>]**` to its first line.
  - Append the new definition immediately after it, prefixed with `**[v<N> — 自 <YYYY-MM-DD>]**` (use v2 for first conflict, v3 for the next, etc.).
  - Both stay in the document. Downstream consumers can migrate gradually; the contract preserves history.
- The actual server may or may not run both shapes simultaneously — that is an implementation decision recorded in source code or PRD, separate from the contract document.

Delete `docs/<contract>.draft.md` once merged. On first run this step is a no-op.

#### Step 2 — Append explanation additions to `docs/explanation.md`

If `docs/explanation.draft.md` exists with new conventions / lane / rules emerging from this run:

- Append to `docs/explanation.md` under a dated section header:

  ```markdown
  ## <YYYY-MM-DD> Addendum
  <new content from the draft>
  ```

- Delete `docs/explanation.draft.md`.
- For modifications to existing sections (rare — explanation is supposed to be stable), surface to the user before writing. Do not silently overwrite the original.

#### Step 3 — Append run section to `docs/todolist.md`

The todolist accumulates: each run appends its own dated section at the bottom. Append-only — never edit prior runs' sections.

Format:

```markdown
---

## <YYYY-MM-DD> — <run slug>

(Optional: 1-line summary of what this run delivered.)

### Phase A — 需求与规章 (主对话已完成)
- [x] ...

### Phase B — <Lane A 名称> Agent
| 序号 | 任务 | 验收点 | 状态 | 备注 |
|------|------|--------|------|------|
| ... | ... | ... | [x] | ... |

### Phase B — <Lane B 名称> Agent
| ... |

<Lane A 名称> lane completed at <ISO>
<Lane B 名称> lane completed at <ISO>
```

The completion date in the section header acts as the version label. The section is fully self-contained (its own Phase A and lane subsections) so a fresh agent reading the file sees clear chronological scope.

On first run, Phase A already wrote the todolist with the same shape — no merge needed; just confirm signatures landed.

#### Step 4 — Cleanup transient files

Delete:
- `docs/_subagent-prompt.template.md` if present (per-run reference scaffolded by `scripts/scaffold-docs.*`, not a tracked doc).
- Any `docs/*.draft.md` files merged in Steps 1–2.
- Any `docs/.runs/<slug>/` scratch directory if you used the `.runs/` pattern instead of `*.draft.md` suffix.

Keep (temporarily, until Step 6 archive):
- `docs/prd.md`, `docs/explanation.md`, `docs/<contract>.md`, `docs/todolist.md` — these will be archived in Step 6.

#### Step 5 — Final verification

- Both lane signature lines for THIS run are present in `docs/todolist.md` with the correct date.
- No `*.draft.md` or `_*.md` files remain in `docs/`.
- Smoke verification (build, tests, etc. per `docs/explanation.md` §7) is green.
- Summary to user, surfacing any gaps the lanes reported in their final replies.

#### Step 6 — Archive completed module

After verification passes, archive the completed module to preserve project history and free up the main `docs/` directory for the next module:

1. **Determine module name.** Extract from the PRD title, todolist run slug, or ask the user. Use kebab-case format (e.g., `user-auth`, `image-generation`). If the module is large or covers multiple features, use `module-feature` format (e.g., `user-auth-oauth`, `user-auth-session`).

2. **Create archive directory.** Create `docs/archive/<module-name>/` if it doesn't exist.

3. **Move the four core documents:**
   ```bash
   mv docs/prd.md docs/archive/<module-name>/prd.md
   mv docs/explanation.md docs/archive/<module-name>/explanation.md
   mv docs/todolist.md docs/archive/<module-name>/todolist.md
   mv docs/<contract>.md docs/archive/<module-name>/<contract>.md
   ```

   If multiple contract files exist (e.g., `interface.md`, `schema.md`), move all of them.

4. **Verify archive integrity.** Confirm all four files exist in the archive directory and the main `docs/` directory is clean (only `archive/` subdirectory remains).

5. **Update archive index.** Create or append to `docs/archive/INDEX.md`:
   ```markdown
   ## <module-name>
   - **Completed:** <YYYY-MM-DD>
   - **Description:** <one-line summary from PRD>
   - **Files:** [prd.md](/<module-name>/prd.md), [explanation.md](/<module-name>/explanation.md), [todolist.md](/<module-name>/todolist.md), [<contract>.md](/<module-name>/<contract>.md)
   ```

6. **Report to user.** Confirm module archived and ready for next module.

**Module size guidelines:**
- If a module's todolist exceeds 40 rows across all lanes, consider splitting into smaller `module-feature` submodules during Phase A planning.
- If a module's contract file exceeds 1000 lines, split by feature domain (e.g., `user-auth-api.md` + `user-auth-webhooks.md`).
- Archive structure supports nested modules: `docs/archive/user-auth/oauth/` is valid if `user-auth` is the parent module.

## Lane ownership rules

The single most important property of this workflow. Encode lane ownership in `docs/explanation.md` as a two-column table per lane: **可写路径 / writable** and **不可写路径 / read-only**. Mirror this in each subagent's launch prompt verbatim.

Rules:

- Each lane owns its source directory (`backend/`, `frontend/`, etc.) plus exactly one section of `docs/todolist.md` (its own rows) plus any output document it produces (e.g. backend owns the contract).
- No lane may modify `docs/prd.md` or `docs/explanation.md` after Phase A — those are orchestrator-only.
- No lane may modify another lane's source tree or rows in the todolist.
- Shared root files (`.gitignore`, `README.md`) are append-only per lane: each lane appends a clearly delimited section.

When a real change to read-only territory is needed (e.g. a missing endpoint on the contract), the subagent must report it back rather than monkey-patching across lanes. The orchestrator decides whether to issue a follow-up to the upstream lane.

## Checkpoint protocol

Each subagent's loop:

```
read docs/todolist.md
locate first [ ] row in own lane
  if none → append signature, report done, exit
execute the row's task
edit the row: [ ] → [x], add brief note
loop
```

This loop is what makes restart safe. The instructions for the loop go in the subagent's prompt, not in any tool — there is no special checkpoint tool.

To make restart actually work in practice:

- Keep todolist rows **small enough to redo without harm** (idempotent or near-idempotent). A single row should be one Edit/Write or a tight cluster.
- Tick the row **immediately after** the edit completes, not at the end of a batch. Half-done rows are the only ambiguous state and should be rare.
- Use the `备注` column to capture a one-line summary so a fresh agent reading the file later understands what was done.

## Inter-lane contracts

When lane A produces output that lane B consumes (API, schema, file format), that contract becomes a tracked document.

- **Schedule the contract row at the midpoint of lane A's work** (e.g. row 6–7 of a 12-row backend lane). This is the gate that unblocks lane B (see "Gate detection" above). The remaining lane A rows run in parallel with all of lane B.
- The contract document is the **single source of truth**. Lane B trusts it over its own assumptions; lane A treats it as a public commitment — once published it should not change shape silently.
- If a gap is found in the contract during lane B work, lane B reports it back in its final reply rather than silently working around it. The orchestrator coordinates a follow-up to lane A (a small focused agent run, see real-project example).
- **Aggressive option:** if lane B has scaffolding rows that don't need the contract (e.g. project init, dep install, design tokens), they can be split off as a "lane B prelude" and launched in parallel with lane A from the start. Most projects don't need this; it saves only minutes and adds an orchestration moving part.

## Subagent launch prompt

Every subagent prompt must contain a fixed set of sections (identity, Step 0 read list, lane ownership, per-row guidance, verification, sign off, don'ts, final reply format). The complete authoritative template — including the orchestrator self-check checklist — lives in `assets/subagent-prompt.template.md`. Read that file before writing a launch prompt; do not reconstruct the section list from memory.

A short prompt produces shallow work. Brief the agent like a colleague who walked into the room cold — it has not seen the conversation, the previous agent's output, or the user's intent.

## Common pitfalls

- **Skipping Phase A halt.** Launching subagents before the user approves scope wastes one or two agent runs when scope shifts.
- **Forgetting to check archives.** Starting a new module without reading `docs/archive/INDEX.md` and relevant archived modules can lead to duplicated work or inconsistent contracts.
- **Cross-lane edits.** A subagent "helpfully" fixing the other lane's file. Prevention: explicit `不可写` list in the prompt + lane ownership table.
- **Contract drift.** Backend ships an endpoint shape, frontend assumes a different shape, and the contract document is stale. Prevention: backend authors the contract; frontend's first action is to read it; deviation is a reported gap, not a workaround.
- **Coarse rows.** A single row that takes 30 minutes and touches 10 files. If the agent crashes halfway, a restart redoes everything. Split into smaller rows.
- **Forgetting to tick.** The agent did the work but did not edit the todolist. A restart redoes. Mitigation: in the prompt, make ticking the row part of the row's "Done" definition.
- **Hidden resume state.** Subagents must not store row-completion state in TodoWrite or in-memory lists — that vanishes on restart. The orchestrator's own TodoWrite for session-level milestones is fine; the rule applies only to per-row checkpoint state, which must live in `docs/todolist.md`.
- **No signature line.** Without it, the orchestrator cannot tell whether the agent finished cleanly or context-truncated mid-row.
- **Late contract publication.** Lane A's contract row scheduled at the *end* of its work blocks lane B for the whole upstream duration. Mitigation: place the contract row at the midpoint of lane A; lane A may keep iterating on its source code after publishing the contract, but lane B is unblocked the moment the contract exists.
- **Skipping archive step.** Leaving completed modules in `docs/` clutters the workspace and makes Phase A harder for the next module. Always archive after Phase C verification passes.
- **Poor module naming.** Vague names like `module1` or `feature` make archives hard to navigate. Use descriptive kebab-case names that match the PRD title or feature domain.

## Assets

The bundled templates are bilingual (Chinese-leaning) — column headers like `备注` and section markers like `完工签名` and `可写路径` / `不可写路径` are part of the resume protocol and are referenced verbatim by the subagent prompts. When adapting for an English-only project, replace these markers consistently across `todolist.md`, `explanation.md`, and the subagent prompt — do not translate one and leave the others, or the subagent's "find the row to tick" / "append signature" steps will break.

Concrete templates the orchestrator can copy and adapt:

- **`assets/prd.template.md`** — PRD skeleton with sections for goals, non-goals, scenarios, functional requirements, non-functional requirements, error semantics, acceptance criteria.
- **`assets/explanation.template.md`** — engineering rules skeleton with repo structure, lane ownership table, naming conventions, encoding standards, run commands, testing expectations, AI restrictions.
- **`assets/todolist.template.md`** — todolist skeleton with Phase A rows, two empty lanes (rename the lanes for the actual project), signature footer.
- **`assets/subagent-prompt.template.md`** — subagent launch prompt skeleton + orchestrator self-check checklist.

For deterministic scaffolding (create `docs/`, copy templates, replace `<项目名>` placeholder), use `scripts/scaffold-docs.ps1` (Windows) or `scripts/scaffold-docs.sh` (macOS / Linux) — see header of either script for usage.

For a redacted real-world example showing actual row counts, granularity, and lane decomposition from a project that ran this workflow successfully, see `references/examples-from-real-project.md`.

Read each template before adapting it to a project — they encode formatting choices (备注 column position, signature line wording) that the resume protocol depends on.

## Workflow checklist for the orchestrator

Use this as a mental checklist when applying this skill to a new project:

- [ ] Phase 0: plan written (in plan mode if applicable)
- [ ] Phase A: check `docs/archive/INDEX.md` for relevant completed modules; read archived files if current task builds on prior work
- [ ] Phase A: `docs/prd.md` written
- [ ] Phase A: `docs/explanation.md` written with lane ownership table
- [ ] Phase A: `docs/todolist.md` written, lanes named, rows scoped small
- [ ] Phase A: halt + summarise to user
- [ ] Phase B: upstream lane subagent launched **in background**, prompt covers all required sections; on follow-up runs, lane writes contract to `docs/<contract>.draft.md` instead of the persistent file
- [ ] Phase B: gate-poll started (waits for contract file + checked contract row)
- [ ] Phase B: contract gate opened → downstream lane subagent launched in parallel
- [ ] Phase B: both signature lines appear at the bottom of todolist (independent of one another)
- [ ] Phase C: contract `.draft.md` (if any) merged into `docs/<contract>.md` with deprecation/version markers on conflicts
- [ ] Phase C: explanation `.draft.md` (if any) appended under dated `## <YYYY-MM-DD> Addendum` header
- [ ] Phase C: this run's todolist section appended at the bottom of `docs/todolist.md` (append-only, never edit prior sections)
- [ ] Phase C: transient files deleted — `docs/_subagent-prompt.template.md`, all `docs/*.draft.md`, any `docs/.runs/<slug>/`
- [ ] Phase C: smoke verification passes
- [ ] Phase C: module archived to `docs/archive/<module-name>/` with all four core documents moved
- [ ] Phase C: `docs/archive/INDEX.md` updated with new module entry
- [ ] Final: end-to-end smoke verification + summary to user, surfacing any gaps the lanes reported

### Todolist row-granularity self-check

Right after drafting `docs/todolist.md`, before showing it to the user, run this check on each lane's rows:

- [ ] Each row is finishable in 5–30 minutes by a fresh subagent. Anything over an hour gets split.
- [ ] Each row has an observable acceptance point (e.g. "test X passes", "page Y renders", "file Z exists with shape S") — never just "code written".
- [ ] Cross-lane dependencies flow ONLY through the contract document; no row references another lane's source path.
- [ ] Any single row, redone from scratch on restart, does not break already-completed work (idempotent or near-idempotent).
- [ ] At least one row writes tests; at least one row updates the README; the last row is the lane signature.

If any item fails, rewrite the offending rows before launching subagents — these properties are what make restart safe.

## Out of scope for this skill

- Specific tech stacks (Python/Vue/etc.) — those are project decisions, not workflow decisions.
- Single-agent workflows — this skill assumes ≥ 2 lanes.
- Real-time agent-to-agent communication — lanes communicate only through on-disk files, by design. If two lanes need real-time coordination, they should be one lane.
- Git automation — this skill does not commit. Ticking the todolist is independent of any VCS.
