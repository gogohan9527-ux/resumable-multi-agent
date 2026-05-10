# <Project Name> - Execution Progress Tracker (TodoList)

> **Resume convention:** after each agent starts, its first step is to read this file, locate the first unchecked `[ ]` item in its own lane (A rows = Lane A, B rows = Lane B), and continue from there. After completing an item, it immediately changes the checkbox to `[x]` and writes a note in the Notes column. Agents may only edit their own lane's checkbox states and corresponding Notes cells. All other documents follow the ownership rules in [explanation.md section 2](explanation.md).
>
> **Phase A** (requirements documentation) is completed by the orchestrator in the main conversation. The A / B lanes below belong to **Phase B** and are handed off to subagents only after the user issues a "resume" or "continue" command.

---

## Phase A - Requirements and Rules (Main Conversation Completed)

- [x] P1. Draft plan file `<plan-path>`
- [x] P2. Write `docs/prd.md`
- [x] P3. Write `docs/explanation.md`
- [x] P4. Write `docs/todolist.md` (this file)
- [ ] P5. User issues "resume / continue" command -> enter Phase B

---

## Phase B - <Lane A Name> Agent
**Ownership:** <Writable path list>.
**Do not touch:** <Read-only path list>.

| No. | Task | Acceptance Point | Status | Notes |
|-----|------|------------------|--------|-------|
| A1 | <Small task starting with a verb> | <Observable acceptance condition> | [ ] |  |
| A2 | ... | ... | [ ] |  |
| A3 | ... | ... | [ ] |  |
| ... | ... | ... | [ ] |  |
| A<N-1> | Write `docs/<contract>.md` (the contract for Lane B) | File exists and each endpoint/field has an example | [ ] |  |
| A<N> | <Lane A sign-off> | - | [ ] |  |

---

## Phase B - <Lane B Name> Agent
**Ownership:** <Writable path list>.
**Do not touch:** <Read-only path list>.
**Prerequisite:** after A<N-1> completes, `docs/<contract>.md` is readable. B items that consume the contract must wait for A<N-1>. Other B items may run in parallel with Lane A.

| No. | Task | Acceptance Point | Status | Notes |
|-----|------|------------------|--------|-------|
| B1 | <Small task starting with a verb> | <Observable acceptance condition> | [ ] |  |
| B2 | ... | ... | [ ] |  |
| ... | ... | ... | [ ] |  |
| B<M> | <Lane B sign-off> | - | [ ] |  |

---

## Completion Signatures

<!-- After an agent has completed all [x] rows in its own lane, append one line here:
     `<Lane> lane completed at <YYYY-MM-DDTHH:MM:SS>` -->
