---
name: resumable-multi-agent
description: This skill should be used when the user asks to "split this into agents", "two agents", "frontend agent + backend agent", "multi-agent project", "lane-based execution", "resumable workflow", "this is too big for one agent", "checkpoint and resume", "context reset", "context too long", "split frontend and backend", or "parallel subagents". Establishes a five-document workflow (plan, requirements, rules, inter-lane contract, todolist) and a two-phase execution model: orchestrator writes synchronous documentation first, then subagents resume from the first unchecked checkbox in their lane. Use this skill proactively whenever the user describes a project that touches multiple distinct components (e.g. backend + frontend, parser + renderer, ETL + dashboard) and is sizable enough that one-shot execution risks context truncation, even if the user does not explicitly say "agent", "lane", or "resume".
version: 0.1.0
---

## On Load - Required First Step

**Every time this skill is invoked, before doing anything else, send the following message to the user. You may adapt the language to the conversation, but keep the meaning unchanged:**

> Loaded the `resumable-multi-agent` skill and started the workflow.

# Resumable Multi-Agent Workflow

## Purpose

Coordinate a non-trivial project across two or more subagents while keeping execution **restart-safe**: if a subagent crashes or its context is reset, relaunching it with the same prompt resumes from the first unchecked checkbox in its lane. State lives entirely in markdown files on disk; no in-memory session is required to make forward progress.

## When to apply

Apply this workflow when **all** of the following hold:

- The project has clearly separable components, such as backend + frontend, ETL + dashboard, or parser + renderer.
- The total work is large enough that a single agent's context window may compact mid-execution.
- The user wants progress to survive a restart or context reset.
- A contract exists or can be written between components, where one component's output is another component's input.

Do not apply this workflow for trivial single-file edits, exploratory research, or tasks where one agent's complete output trivially fits in context.

The default templates show two lanes, but the workflow scales to N lanes. Duplicate the lane block in `todolist.md` and add a row in the ownership table for each lane. Beyond four lanes, reconsider whether some can be merged: too many lanes raises coordination cost faster than parallelism saves time.

## The Five Documents

All five live under `docs/` in the project root during active development. The plan file lives in the user's plan directory if invoked from plan mode. After Phase C completes, the four core documents are archived to `docs/archive/<module-name>/`.

| File | Purpose | Owner | When written | Lifecycle |
|------|---------|-------|--------------|-----------|
| `plans/<slug>.md` | Implementation plan, drafted in plan mode | Orchestrator | Phase 0 | Persistent in `plans/` |
| `docs/prd.md` | What the system must do: requirements and acceptance criteria | Orchestrator | Phase A | Archived after Phase C |
| `docs/explanation.md` | Engineering rules, lane ownership, run instructions | Orchestrator | Phase A | Archived after Phase C |
| `docs/todolist.md` | Resume-safe checklist, split by lane; accumulates one dated section per run | Orchestrator initially and during Phase C append; each subagent ticks its own rows | Phase A initial; Phase B updates; Phase C append on follow-up runs | Archived after Phase C |
| `docs/<contract>.md` | Inter-lane contract, such as `interface.md` or `schema.md`; accumulates with deprecation/version markers across runs | Upstream lane subagent drafts; orchestrator merges in Phase C | Phase B at upstream-lane midpoint; Phase C merges drafts into persistent file | Archived after Phase C |
| `docs/archive/<module>/` | Completed module archive containing the four core documents | Orchestrator | Phase C Step 6 | Permanent reference |
| `docs/archive/INDEX.md` | Archive catalog listing all completed modules | Orchestrator | Phase C Step 6 | Append-only |

The orchestrator never writes the contract during Phase B. The upstream subagent produces it. The orchestrator's only role on the contract is during Phase C, deterministically merging this run's draft into the persistent file with conflict handling. Downstream lanes always read the persistent file as a hard contract.

**Per-run scratch convention for follow-up runs:** during Phase A on a follow-up run, the orchestrator points the upstream lane at `docs/<contract>.draft.md` instead of `docs/<contract>.md`. Phase C merges the draft into the persistent file and deletes it. On the first run, no draft suffix is used; the lane writes the persistent file directly.

## Three-Phase Execution Model

The workflow has three phases. Phase A is synchronous: orchestrator plus user. Phase B is parallel subagent execution. Phase C is a deterministic orchestrator-only merge and cleanup phase that turns this run's outputs into persistent project state, removes transient files, and archives completed modules.

### Phase A - Synchronous Documentation (Orchestrator Only)

1. **Check for archived modules.** If the current task involves a previously completed module, read the relevant files from `docs/archive/<module-name>/`: `prd.md`, `explanation.md`, `todolist.md`, and the contract file. Use them to understand context and avoid duplicated work. If the relevant module is unclear, list available archived modules to the user.
2. Read or draft a plan. If invoked from plan mode, use the plan file.
3. Write `docs/prd.md` from the plan and user dialogue.
4. Write `docs/explanation.md`, declaring lane ownership, naming conventions, run commands, and testing expectations.
5. Write `docs/todolist.md` with two top-level sections, one per lane, each a checklist. Add a Phase A section above with `[x]` rows showing the docs are done and a final `[ ]` row for "user issues resume command".
6. **Halt.** Reply to the user summarizing the docs and ask for a resume command. Do not launch subagents yet.

This phase is synchronous because the user must agree to scope, rules, and lane decomposition before parallel work begins.

### Phase B - Subagent Execution (Gated Parallel)

After the user types "resume", "continue", or an equivalent command, run the upstream and downstream lanes **concurrently**, gated on the contract document. The downstream lane does not wait for upstream completion. It waits for the contract to be published, which happens at the upstream lane's midpoint.

**Orchestrator launch sequence:**

1. **Launch upstream lane in background** (`run_in_background: true`). It works through its full row sequence in one continuous context, including rows after the contract. The orchestrator does not wait for it to finish.
2. **Poll for the contract gate.** The gate opens when both conditions hold:
   - `docs/<contract>.md` exists and has substantive content, for example more than 500 bytes.
   - The contract row in `docs/todolist.md` is `[x]`, meaning the upstream agent explicitly checked it.
3. **Launch downstream lane** the moment the gate opens. It runs in foreground or background, at the orchestrator's discretion, in parallel with the still-running upstream agent.
4. **Wait for both completion notifications.** Each agent appends its own signature line independently. Both must appear before final smoke verification.

**Why a gate rather than splitting upstream into two agent runs:**

- One upstream run keeps continuous context and avoids rereading the docs between halves.
- The sync point is the contract file, a hard artifact, not an orchestrator-controlled boundary.
- If upstream crashes after publishing the contract, downstream is unaffected. It already has the contract and continues. Relaunching upstream with the same prompt resumes from the next `[ ]` row, including any post-contract work that was not checked.

**Each subagent's first action** is to read all five documents in order: PRD, explanation, todolist, contract if any, then asset references. From there, the loop is the same:

```text
read docs/todolist.md
locate first [ ] row in own lane
  if none -> append signature, report done, exit
execute the row's task
edit the row: [ ] -> [x], add brief note
loop
```

If a subagent crashes mid-execution, relaunching it with the same prompt resumes from the next unchecked row. No special "resume" mode is needed because the prompt instructs it to read the todolist first.

**When to skip parallelization and run sequentially:**

- Upstream's post-contract work is small, less than 25% of total upstream rows.
- Downstream needs more than just the contract, such as shared runtime libraries, generated stubs, or fixture data files. Pre-list these as additional gates or keep execution sequential.
- Two lanes are tightly coupled in unobvious ways. This is a sign that the lane decomposition is wrong; consider merging them.

### Gate Detection (Orchestrator Commands)

Use one of these poll loops between launching the upstream agent and launching the downstream agent. Run with a monitor tool or equivalent so the orchestrator gets a single notification when the gate opens instead of busy-polling.

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

The 500-byte threshold filters out a partially-written stub. Adjust per project: a one-endpoint contract may be smaller; a many-endpoint contract should comfortably clear several KB.

**Cap the wait** with a max-iterations bound so a stalled upstream does not hang the orchestrator forever. If the gate does not open within a chosen limit, such as 20 minutes, surface it to the user and decide whether to wait, stop, or fall back to sequential execution.

### Phase C - Merge, Cleanup, and Archive (Orchestrator Only)

After both lane signatures are present in `docs/todolist.md`, run Phase C. This phase is deterministic: the orchestrator reads, edits, deletes, and archives; no subagent is involved. It turns this run's per-run artifacts into persistent project state, removes transient scratch files, and archives completed modules.

Phase C handles two cases with one set of rules:

- **First run:** the project has no prior `docs/<contract>.md`; most steps are no-ops and only cleanup and archive matter.
- **Follow-up run:** the project already has `docs/<contract>.md` and prior todolist sections; merge logic applies.

**Convention for per-run scratch:** when the orchestrator launches a follow-up run, it directs each lane to write contract additions to `docs/<contract>.draft.md` instead of editing the persistent file directly. The orchestrator may also stage explanation addenda to `docs/explanation.draft.md` during Phase A. This keeps Phase B agents focused on new content while Phase C handles integration. On the first run, lanes write directly to the persistent path and `.draft.md` files do not appear.

#### Step 1 - Merge Contract Additions into `docs/<contract>.md`

If `docs/<contract>.draft.md` exists, merge it into `docs/<contract>.md`:

- **New endpoints or sections:** append in the natural section ordering.
- **Conflicting endpoints:** same path or name, but different request, response, or error shape:
  - Keep the old definition. Prepend `**[DEPRECATED at <YYYY-MM-DD> - use v<N> below]**` to its first line.
  - Append the new definition immediately after it, prefixed with `**[v<N> - since <YYYY-MM-DD>]**`. Use v2 for the first conflict, v3 for the next, and so on.
  - Both stay in the document. Downstream consumers can migrate gradually, and the contract preserves history.
- The actual server may or may not run both shapes simultaneously. That is an implementation decision recorded in source code or PRD, separate from the contract document.

Delete `docs/<contract>.draft.md` once merged. On first run this step is a no-op.

#### Step 2 - Append Explanation Additions to `docs/explanation.md`

If `docs/explanation.draft.md` exists with new conventions, lanes, or rules emerging from this run:

- Append to `docs/explanation.md` under a dated section header:

  ```markdown
  ## <YYYY-MM-DD> Addendum
  <new content from the draft>
  ```

- Delete `docs/explanation.draft.md`.
- For modifications to existing sections, surface the change to the user before writing. Do not silently overwrite the original.

#### Step 3 - Append Run Section to `docs/todolist.md`

The todolist accumulates. Each run appends its own dated section at the bottom. It is append-only: never edit prior runs' sections.

Format:

```markdown
---

## <YYYY-MM-DD> - <run slug>

(Optional: one-line summary of what this run delivered.)

### Phase A - Requirements and Rules (Main Conversation Completed)
- [x] ...

### Phase B - <Lane A Name> Agent
| No. | Task | Acceptance Point | Status | Notes |
|-----|------|------------------|--------|-------|
| ... | ... | ... | [x] | ... |

### Phase B - <Lane B Name> Agent
| ... |

<Lane A Name> lane completed at <ISO>
<Lane B Name> lane completed at <ISO>
```

The completion date in the section header acts as the version label. The section is fully self-contained so a fresh agent reading the file sees clear chronological scope.

On first run, Phase A already wrote the todolist with the same shape. No merge is needed; just confirm the signatures landed.

#### Step 4 - Cleanup Transient Files

Delete:

- `docs/_subagent-prompt.template.md` if present.
- Any `docs/*.draft.md` files merged in Steps 1 and 2.
- Any `docs/.runs/<slug>/` scratch directory if you used the `.runs/` pattern instead of `*.draft.md`.

Keep temporarily, until Step 6 archive:

- `docs/prd.md`, `docs/explanation.md`, `docs/<contract>.md`, and `docs/todolist.md`. These will be archived in Step 6.

#### Step 5 - Final Verification

- Both lane signature lines for this run are present in `docs/todolist.md` with the correct date.
- No `*.draft.md` or `_*.md` files remain in `docs/`.
- Smoke verification, such as build or tests listed in `docs/explanation.md` section 7, is green.
- Summarize to the user and surface any gaps the lanes reported in their final replies.

#### Step 6 - Archive Completed Module

After verification passes, archive the completed module to preserve project history and free the main `docs/` directory for the next module:

1. **Determine the module name.** Extract it from the PRD title, todolist run slug, or user input. Use kebab-case, such as `user-auth` or `image-generation`. If the module is large or covers multiple features, use `module-feature` form, such as `user-auth-oauth` or `user-auth-session`.

2. **Create the archive directory.** Create `docs/archive/<module-name>/` if it does not exist.

3. **Move the four core documents:**

   ```bash
   mv docs/prd.md docs/archive/<module-name>/prd.md
   mv docs/explanation.md docs/archive/<module-name>/explanation.md
   mv docs/todolist.md docs/archive/<module-name>/todolist.md
   mv docs/<contract>.md docs/archive/<module-name>/<contract>.md
   ```

   If multiple contract files exist, such as `interface.md` and `schema.md`, move all of them.

4. **Verify archive integrity.** Confirm all four document types exist in the archive directory and the main `docs/` directory is clean, with only the `archive/` subdirectory remaining.

5. **Update the archive index.** Create or append to `docs/archive/INDEX.md`:

   ```markdown
   ## <module-name>
   - **Completed:** <YYYY-MM-DD>
   - **Description:** <one-line summary from PRD>
   - **Files:** [prd.md](/<module-name>/prd.md), [explanation.md](/<module-name>/explanation.md), [todolist.md](/<module-name>/todolist.md), [<contract>.md](/<module-name>/<contract>.md)
   ```

6. **Report to the user.** Confirm the module was archived and the workspace is ready for the next module.

**Module size guidelines:**

- If a module's todolist exceeds 40 rows across all lanes, consider splitting it into smaller `module-feature` submodules during Phase A planning.
- If a module's contract file exceeds 1000 lines, split it by feature domain, such as `user-auth-api.md` plus `user-auth-webhooks.md`.
- Archive structure supports nested modules. For example, `docs/archive/user-auth/oauth/` is valid if `user-auth` is the parent module.

## Lane Ownership Rules

This is the most important property of the workflow. Encode lane ownership in `docs/explanation.md` as a two-column table per lane: **writable paths** and **read-only paths**. Mirror this verbatim in each subagent launch prompt.

Rules:

- Each lane owns its source directory, such as `backend/` or `frontend/`, plus exactly one section of `docs/todolist.md`, plus any output document it produces, such as the contract.
- No lane may modify `docs/prd.md` or `docs/explanation.md` after Phase A. Those are orchestrator-only.
- No lane may modify another lane's source tree or rows in the todolist.
- Shared root files such as `.gitignore` and `README.md` are append-only per lane. Each lane appends a clearly delimited section.

When a real change to read-only territory is needed, such as a missing endpoint on the contract, the subagent must report it back instead of patching across lanes. The orchestrator decides whether to issue a follow-up to the upstream lane.

## Checkpoint Protocol

Each subagent's loop:

```text
read docs/todolist.md
locate first [ ] row in own lane
  if none -> append signature, report done, exit
execute the row's task
edit the row: [ ] -> [x], add brief note
loop
```

This loop makes the workflow restart-safe. The instructions for the loop go in the subagent prompt, not in any tool. There is no special checkpoint tool.
