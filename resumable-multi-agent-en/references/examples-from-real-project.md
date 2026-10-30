# Reference: A Real Run of This Workflow (Redacted)

This file shows the actual shape of a project that ran the skill end-to-end successfully. It gives the next orchestrator concrete row counts, granularity, and lane decomposition instead of leaving those choices abstract.

The original project was a small web app: a proxy plus UI for calling a third-party image-generation API. Domain details have been removed. Only the workflow shape is preserved. Placeholder names like `<lane-A>` and `<lane-B>` are used in place of the original backend and frontend.

## Project Shape

- Two lanes. Lane A produced a contract document, and Lane B consumed it.
- Twenty-three total rows across the two lanes: 12 + 11.
- One mid-execution gap fix was needed when a route was missing from the contract. The orchestrator dispatched a focused follow-up to Lane A before launching Lane B.
- One additional follow-up at the end extended both lanes by about two rows each. A feature listed in the PRD had been omitted from the templates, and relaunching one agent per lane closed the gap.

## Row Granularity That Worked

Each row took roughly 2-10 minutes of subagent wall-clock time. Example rows:

| Row | Task | Acceptance Point |
|-----|------|------------------|
| A1 | Scaffold lane source dir, dependency manifest, and `.gitignore` | Directory tree matches `explanation.md` section 1; `.gitignore` covers secrets file |
| A2 | Config loader and example template | `python -c "from app.config import get_config; get_config()"` errors with named missing-field message when run against an empty config |
| A3 | Persistence layer and schema | Unit tests cover insert / list / get / update / delete |
| A4 | Core domain logic extracted from prototype, parameterized, with progress callback | Mock external HTTP; cover success / error / cancellation |
| A5 | Concurrency, bounded queue, and cancellation | Unit tests cover cap rejection, cancel pending, cancel running, and concurrency change preserving in-flight work |
| A6 | HTTP routes for happy and sad paths | TestClient covers each route end-to-end |
| A7 | SSE stream endpoint | Browser EventSource receives at least three events for one task lifecycle |
| A8 | Global exception handler, CORS, and startup hooks | App boots, OpenAPI page renders |
| A9 | **Write contract document** | File exists; every endpoint has request, response, error, and curl examples |
| A10 | Tests for queue cap, cancel, concurrency change, and missing-config exit | `pytest -q` green |
| A11 | README section and run instructions | Section exists with copy-pasteable commands |
| A12 | Sign off | Signature line at file bottom |

Lane B mirrored this scale: scaffolding, typed API client, shell, main view, modal/drawer, secondary view, settings dialog, live-update wiring, visual review, README, sign off.

**Key observation:** rows that reliably caused trouble were either too small or too large. Rows that wrote one tiny config file felt redundant. Rows that touched five or more files often left a half-done state on context truncation. The 2-10 minute / 1-3 file range kept restart safety real.

## Cross-Lane Contract Scheduling

Lane A had 12 rows. The contract row (A9) sat at row 9 of 12, past the midpoint. In hindsight this was too late, and orchestration became sequential rather than gated-parallel.

Two compounding losses:

1. The contract was published only after A1-A9 finished. If it had been A6-A7, Lane B could have started several rows earlier.
2. Even after A9 published, Lane B did not start until A10-A12 also finished because the orchestrator waited for the entire upstream lane completion notification before launching downstream.

The current recommended pattern fixes both:

- **Place the contract at midpoint**, such as row 6-7 of 12, not row 9-11.
- **Launch upstream in background; gate-poll for the contract; launch downstream the moment the gate opens.** Upstream's remaining rows continue while downstream is already working.

## Mid-Execution Gap-Fix Pattern

Lane A's contract initially omitted a static-asset route the UI mockups required. Lane B would have stalled on the thumbnail rendering row. The orchestrator caught this before launching Lane B by reading the contract document with lane requirements in mind.

The fix:

1. Spawn a fresh agent with a focused prompt: one task, roughly 200 lines, explicitly listing the gap, the required schema change, and the test addition.
2. The agent edited only Lane A files, the contract document, and one note on its existing row. It did not add a new row, keeping the row count stable.
3. Then launch Lane B normally.

This pattern works because all state lives on disk. The new agent reorients from the same docs, makes the surgical fix, and exits. No hand-off between agents is needed.

## End-of-Flow Gap Surfacing

After both lanes signed off, each lane's final reply listed gaps it noticed but did not fix because they crossed lane ownership:

- Lane A noted that the UI mocks showed a delete action on history records, but the contract had no delete-history endpoint.
- Lane B noted the same gap from the other side and gracefully omitted the button instead of inventing a route.

The orchestrator then dispatched two focused agents, one per lane, to close the gap. Each was about one row of work and used the same prompt template, just shorter. Both lanes' signature timestamps were revised.

**Lesson encoded in the skill:** the subagent prompt template's "Final Reply Format" asks the agent to report gaps rather than work around them. This made cleanup straightforward.

## Things to Copy Verbatim from This Run

- The column markers (`Notes`, `Ownership`, `Do not touch`, `Completion Signatures`) survived multiple agent restarts because the subagent prompts referenced them by literal string.
- **`<Lane> lane completed at <ISO>`** as the signature wording. The orchestrator can grep for this to confirm completion programmatically.
- **One signature per lane**, two signatures total at the bottom of `todolist.md`, which is easy to scan.
- **Phase A `[x]` rows above Phase B**, giving the file an honest history at a glance.
- **Lane prompts shipped eight sections** in this exact order: identity, Step 0 reads, lane ownership, per-row guidance for non-obvious rows, verification, sign off, don'ts, final reply format.

## Things Not to Copy

- Do not have the orchestrator pre-fill row-by-row guidance for every row in the subagent prompt. Only call out non-obvious rows such as data shapes, edge cases, and contract details. The PRD already tells the agent what to build for obvious rows.
- Do not place the contract document row at the end of the upstream lane. Schedule it at the midpoint.
- Do not use a separate todolist tool inside subagents for resume state. The on-disk `docs/todolist.md` is the only source of truth. In-tool todo lists evaporate on restart.

## Approximate Timeline

For a project of this size, around 23 total rows with light algorithmic complexity:

**Sequential, what actually ran:**

| Phase | Approx. Wall Time |
|-------|-------------------|
| Phase 0 plan | 5-10 min |
| Phase A docs: PRD + explanation + todolist | 10-15 min |
| Phase B Lane A, 12 rows | one subagent run, about 8-10 min |
| Phase B mid-fix, one small gap | one focused agent, about 3-5 min |
| Phase B Lane B, 11 rows | one subagent run, about 9-10 min |
| Phase B end-fix, close two gaps across both lanes | two focused agents, about 6-8 min total |
| **Total sequential** | **about 45-60 min orchestrator-clock** |

**Gated parallel, current recommendation:**

| Phase | Approx. Wall Time |
|-------|-------------------|
| Phase 0 + Phase A | same, about 15-25 min |
| Phase B Lane A start in background -> contract row at A6 | about 5 min until gate opens |
| Phase B Lane B starts in parallel with remaining Lane A | about 9-10 min concurrent, bottleneck is the longer half |
| Phase B mid-fix + end-fix | about 9-13 min |
| **Total parallel** | **about 35-48 min orchestrator-clock** |

This saves roughly 10-12 minutes on a project of this size. Larger projects with more post-contract work in Lane A see proportionally bigger savings.

Token budget: each lane's main run was in the 60-100k token range; focused mid/end-fix agents were about 30-70k each. These fit comfortably within fresh-agent context budgets, so no agent risked compaction mid-row. Parallelization changes wall-clock time, not per-agent token use.

## Hypothetical Follow-Up Run (Phase C in Action)

Imagine a second run a month later, adding two features: bulk task submission and an export-history endpoint.

**What the orchestrator does differently from the first run:**

- Phase A skips the scaffold script entirely. It would refuse to overwrite existing `docs/`.
- The orchestrator reads existing `docs/prd.md`, `docs/explanation.md`, `docs/interface.md`, and `docs/todolist.md` to understand current state.
- It drafts a one-section PRD addendum inline or in a scratch file.
- It decides no new explanation rules are needed, so no `explanation.draft.md` is created.
- It drafts the new run's todolist rows in memory and appends them during Phase C.
- Phase B launches lanes with prompts that point the upstream lane at `docs/interface.draft.md`, not `docs/interface.md`. The frontend prompt says to read both `docs/interface.md` (existing contract) and `docs/interface.draft.md` (this run's additions).

Phase C runs after both lane signatures appear.

**Step 1, contract merge:** the upstream lane added two endpoints to `docs/interface.draft.md`:

- `POST /api/tasks/bulk`: net new, no conflict. Append to the Tasks section of `docs/interface.md`.
- `GET /api/history/export`: net new, no conflict. Append to the History section.

If instead the run changed `POST /api/tasks` to require a new `priority_class` field, Phase C would:

- Prepend `**[DEPRECATED at 2026-06-08 - use v2 below]**` to the existing `POST /api/tasks` block.
- Append a new block titled `POST /api/tasks **[v2 - since 2026-06-08]**` with the new request shape.

**Step 2, explanation:** no draft, no-op.

**Step 3, todolist append:**

```markdown
---

## 2026-06-08 - bulk submission + export

### Phase A (Main Conversation Completed)
- [x] PRD addendum drafted in memory
- [x] Contract draft path agreed with both lanes

### Phase B - Backend Agent
| No. | Task | Status | Notes |
|-----|------|--------|-------|
| B1 | POST /api/tasks/bulk + tests | [x] | 5 tests, accepts up to 50 prompts/call |
| B2 | GET /api/history/export (CSV) | [x] | streaming response |
| B3 | Update interface.draft.md | [x] | both endpoints documented |

### Phase B - Frontend Agent
| No. | Task | Status | Notes |
|-----|------|--------|-------|
| F1 | Bulk-paste textarea in NewTaskDrawer | [x] | one prompt per line |
| F2 | Export CSV button in HistoryView | [x] | uses /api/history/export |

Backend lane completed at 2026-06-08T14:22:10
Frontend lane completed at 2026-06-08T14:18:33
```

Original earlier sections stay untouched. The new section is appended at the bottom, making the file a chronological work log.

**Step 4, cleanup:** delete `docs/interface.draft.md`. No `_subagent-prompt.template.md` was created because the scaffold script was not invoked.

**Step 5, verify:** both lane signature lines are present, `pytest -q` and `npm run build` are green.

The follow-up run took about 25 minutes. The small change set, stable docs, and parallel lanes compound to make iterations much faster than the first run.
