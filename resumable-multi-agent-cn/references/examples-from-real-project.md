# Reference: a real run of this workflow (redacted)

This file shows the actual shape of a project that ran the skill end-to-end successfully — so the next orchestrator can see *real* row counts, granularity, and lane decomposition rather than reasoning about it abstractly.

The original project was a small web app (proxy + UI to call a third-party image generation API). Domain details have been removed; only the workflow shape is preserved. Drop names like `<lane-A>` / `<lane-B>` are used in place of the original "backend" / "frontend".

## Project shape

- 2 lanes (Lane A produces a contract document, Lane B consumes it).
- Total of 23 rows across the two lanes (12 + 11).
- Mid-execution gap-fix needed once (a missing route the contract didn't cover); orchestrator dispatched a small follow-up to Lane A before launching Lane B.
- One additional follow-up at the end to extend both lanes by ~2 rows each (a feature the PRD listed but the templates omitted — closed by re-launching one agent per lane with a focused prompt).

## Row granularity that worked

Each row took roughly 2–10 minutes of subagent wall-clock time. Some example rows:

| Row | Task | Acceptance point |
|-----|------|------------------|
| A1 | Scaffold lane source dir + dep manifest + `.gitignore` | Directory tree matches `explanation.md §1`; `.gitignore` covers secrets file |
| A2 | Config loader + example template | `python -c "from app.config import get_config; get_config()"` errors with named missing-field message when run against an empty config |
| A3 | Persistence layer + schema | Unit tests cover insert / list / get / update / delete |
| A4 | Core domain logic extracted from prototype, parametrized + with progress callback | Mock external HTTP; cover success / error / cancellation |
| A5 | Concurrency + bounded queue + cancellation | Unit tests cover cap rejection, cancel pending, cancel running, concurrency change preserves in-flight |
| A6 | HTTP routes for happy + sad paths | TestClient covers each route end-to-end |
| A7 | SSE stream endpoint | Browser EventSource receives at least 3 events for one task lifecycle |
| A8 | Global exception handler + CORS + startup hooks | App boots, OpenAPI page renders |
| A9 | **Write contract document** | File exists, every endpoint has request/response/error/curl |
| A10 | Tests for queue cap, cancel, concurrency change, missing-config exit | `pytest -q` green |
| A11 | README section + run instructions | Section exists with copy-pasteable commands |
| A12 | Sign off | Signature line at file bottom |

Lane B mirrored this scale: scaffolding → typed API client → shell → main view → modal/drawer → secondary view → settings dialog → live-update wiring → visual review → README → sign off.

**Key observation:** the rows that reliably caused trouble were the *too-small* and the *too-large* extremes. Rows that wrote one tiny config file felt redundant; rows that touched 5+ files often left a half-done state on context truncation. The 2–10 minute / 1–3 file sweet spot kept restart-safety real.

## Cross-lane contract scheduling

Lane A had 12 rows. The contract row (A9) sat at row 9 of 12 — past midpoint. **In hindsight this was too late, and the orchestration was sequential rather than gated-parallel.** Two compounding losses:
1. The contract published only after A1–A9 finished; if it had been A6–A7, Lane B could have started 3–4 rows earlier.
2. Even after A9 published, Lane B did not start until A10–A12 also finished — because the orchestrator waited for the entire upstream lane completion notification before launching downstream.

The skill's "Phase B — Subagent execution (gated parallel)" section and the "Late contract publication" pitfall both came from these two lessons. The current recommended pattern fixes both:
- **Place the contract at midpoint** (row 6–7 of 12, not row 9–11).
- **Launch upstream in background; gate-poll for the contract; launch downstream the moment the gate opens.** Upstream's remaining rows continue running while downstream is already working.

## Mid-execution gap-fix pattern

Lane A's contract initially omitted a static-asset route the UI mockups required. Lane B's agent would have stalled on row F4 (rendering thumbnails). The orchestrator caught this BEFORE launching Lane B by reading the contract document with the lane requirements in mind.

The fix:
1. Spawn a *fresh* agent with a tight focused prompt (1 task, ~200 lines), explicitly listing the gap, the schema change required, and the test addition.
2. That agent edited only Lane A files + the contract document + appended one note to its existing row. Did not add a new row — kept the row-count stable.
3. Then launch Lane B normally.

This pattern works because all state lives on disk: the new agent re-orients from the same docs, makes the surgical fix, and exits. No "hand-off" between agents needed.

## End-of-flow gap surfacing

After both lanes signed off, each lane's final reply listed *gaps it noticed but did not fix because they crossed lane ownership*:

- Lane A noted that the UI mocks showed a delete action on history records, but the contract had no delete-history endpoint.
- Lane B noted the same gap from the other side and gracefully omitted the button instead of inventing a route.

The orchestrator then dispatched two more focused agents — one per lane — to close the gap. Each was ~1 row of work and used the same prompt template, just much shorter. Both lanes' signature timestamps got revised.

**Lesson encoded in the skill:** the subagent prompt template's "Final reply format" section asks the agent to *report* gaps rather than work around them. This is what made the cleanup possible.

## Things to copy verbatim from this run

- The **bilingual column markers** (`备注`, `所有权`, `绝不动`, `完工签名`) all worked — they survived multiple agent restarts and never drifted, because the subagent prompts referenced them by literal string.
- **`<Lane> lane completed at <ISO>`** as the signature wording — orchestrator can grep for this to confirm completion programmatically.
- **One signature per lane**, two signatures total at the bottom of `todolist.md` — easy to scan.
- **Phase A `[x]` rows above Phase B** — gives the file an honest history at a glance.
- **Lane prompts shipped 8 sections** in this exact order: identity, Step 0 reads, lane ownership, per-row guidance (only for non-obvious rows), verification, sign off, don'ts, final reply format.

## Things NOT to copy

- Do NOT have the orchestrator pre-fill the entire row-by-row guidance for every row in the subagent prompt. Only call out non-obvious rows (data shapes, edge cases, contract details). The PRD already tells the agent what to build for the obvious ones.
- Do NOT let the contract document's row sit at the *end* of upstream lane — schedule it at the midpoint (see lesson above).
- Do NOT use a separate "todolist" tool inside subagents for resume state. The on-disk `docs/todolist.md` is the only source of truth; in-tool todo lists evaporate on restart.

## Approximate rough timeline

For a project of this size (≈23 rows total, light algorithmic complexity):

**Sequential (what actually ran):**

| Phase | Approx. wall time |
|-------|-------------------|
| Phase 0 (plan) | 5–10 min |
| Phase A docs (PRD + explanation + todolist) | 10–15 min |
| Phase B Lane A (12 rows) | one subagent run, ~8–10 min |
| Phase B mid-fix (1 small gap) | one focused agent, ~3–5 min |
| Phase B Lane B (11 rows) | one subagent run, ~9–10 min |
| Phase B end-fix (close 2 gaps across both lanes) | two focused agents, ~6–8 min total |
| **Total (sequential)** | **~45–60 min** orchestrator-clock |

**Gated parallel (what the skill now recommends):**

| Phase | Approx. wall time |
|-------|-------------------|
| Phase 0 + Phase A | same, ~15–25 min |
| Phase B Lane A start (background) → contract row at A6 | ~5 min until gate opens |
| Phase B Lane B starts in parallel with remaining Lane A (A7–A12 + F1–F11) | ~9–10 min concurrent (bottleneck = the longer of the two halves) |
| Phase B mid-fix + end-fix (unchanged) | ~9–13 min |
| **Total (parallel)** | **~35–48 min** orchestrator-clock |

Saves roughly 10–12 min wall time on a project of this size. Larger projects with more post-contract work in Lane A see proportionally bigger savings — for a 30-row Lane A with 25 rows after the contract, parallel saves ~70% of downstream wall time.

Token budget: each lane's main run was in the 60–100k tokens range; the mid/end-fix agents were ~30–70k each. Well within fresh-agent context budgets, so no agent ever risked compaction mid-row — which is exactly what the skill is designed to ensure. Parallelization does not change per-agent tokens; it only changes wall-clock time.

## Hypothetical follow-up run (Phase C in action)

Imagine a second run on the same project a month later, adding two features: bulk task submission, and an export-history endpoint.

**What the orchestrator does differently from first run:**

- Phase A skips the scaffold script entirely (it would refuse to overwrite the existing `docs/`). Instead the orchestrator:
  - Reads existing `docs/prd.md`, `docs/explanation.md`, `docs/interface.md`, `docs/todolist.md` to understand current state.
  - Drafts a 1-section addendum to PRD inline (or in a scratch file).
  - Decides no new explanation rules are needed → no `explanation.draft.md`.
  - Drafts the new run's todolist rows in memory; will append in Phase C.
- Phase B launches lanes with prompts that point the upstream lane at `docs/interface.draft.md` (NOT `docs/interface.md`). Frontend's prompt says "read both `docs/interface.md` (existing contract) AND `docs/interface.draft.md` (this run's additions)".
- Phase C runs after both lane signatures appear:

**Step 1 (contract merge):** the upstream lane added two endpoints to `docs/interface.draft.md`:
- `POST /api/tasks/bulk` — net new, no conflict. Append to the Tasks section of `docs/interface.md`.
- `GET /api/history/export` — net new, no conflict. Append to the History section.

If instead the run had changed `POST /api/tasks` to require a new `priority_class` field (different request shape), Phase C would:
- Prepend `**[已弃用 / DEPRECATED at 2026-06-08 — 请使用下方 v2]**` to the existing `POST /api/tasks` block.
- Append a new block titled `POST /api/tasks **[v2 — 自 2026-06-08]**` with the new request shape.

**Step 2 (explanation):** no draft, no-op.

**Step 3 (todolist append):**

```markdown
---

## 2026-06-08 — bulk submission + export

### Phase A (主对话已完成)
- [x] PRD addendum drafted in memory
- [x] Contract draft path agreed with both lanes

### Phase B — Backend Agent
| 序号 | 任务 | 状态 | 备注 |
|------|------|------|------|
| B1 | POST /api/tasks/bulk + tests | [x] | 5 tests, accepts up to 50 prompts/call |
| B2 | GET /api/history/export (CSV) | [x] | streaming response |
| B3 | Update interface.draft.md | [x] | both endpoints documented |

### Phase B — Frontend Agent
| 序号 | 任务 | 状态 | 备注 |
|------|------|------|------|
| F1 | Bulk-paste textarea in NewTaskDrawer | [x] | one prompt per line |
| F2 | "导出 CSV" button in HistoryView | [x] | uses /api/history/export |

Backend lane completed at 2026-06-08T14:22:10
Frontend lane completed at 2026-06-08T14:18:33
```

The original 2026-05-07 sections at the top of `docs/todolist.md` stay completely untouched. The 2026-06-08 section is appended at the bottom. A reader can scroll the file as a chronological work log.

**Step 4 (cleanup):** delete `docs/interface.draft.md`. No `_subagent-prompt.template.md` was created this run because the scaffold script wasn't invoked.

**Step 5 (verify):** both lanes' 2026-06-08 signature lines present, `pytest -q` and `npm run build` green.

The whole follow-up run took ~25 minutes total — the small change set + already-stable docs + parallel lanes compound to make iterations much faster than the first run.
