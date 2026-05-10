# <Project Name> - Product Requirements Document (PRD)

> This file defines **what to build** and **what counts as done**.
> Written by the orchestrator in Phase A. No Phase B lane may modify this file.
> If a subagent finds ambiguous or missing requirements, it reports them in its final reply and the orchestrator decides whether to update the document.

## 1. Background

<One paragraph explaining where the problem comes from, the current pain point, and what should be delivered.>

## 2. Goals

| ID | Goal |
|----|------|
| G1 | <One-sentence goal> |
| G2 | ... |

## 3. Non-Goals

- <State what is intentionally out of scope to avoid scope creep>
- ...

## 4. Core Capability (User's Original Words)

> <Paste the user's original request here to avoid translation drift>

## 5. Roles and Scenarios

**Role:** <Who will use this>

| Scenario | Description |
|----------|-------------|
| S1 | <Typical use case> |
| S2 | ... |

## 6. Functional Requirements

### 6.1 <Module / Page 1>

- <Controls / fields / behavior>
- ...

### 6.2 <Module / Page 2>

...

## 7. Non-Functional Requirements

| Dimension | Requirement |
|-----------|-------------|
| Performance | ... |
| Persistence | ... |
| Error semantics | ... |
| Compatibility | ... |
| Security | ... |

## 8. Configuration / Schema

```yaml
# Key configuration example, if applicable
```

## 9. Error Semantics (Critical Paths)

| Scenario | HTTP / Exit Code | Response Body / Behavior |
|----------|------------------|--------------------------|
| ... | ... | ... |

## 10. Acceptance Criteria

- [ ] <Specific item that can be demonstrated and verified>
- [ ] ...

> Acceptance criteria should describe *observable behavior*, not *implementation details*.
> Example: `When the user enters Y in X, they see Z`, not `function foo was called`.
