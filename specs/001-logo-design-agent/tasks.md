# Tasks Index: AI Logo Design Agent POC Phase 1

Beads issue-graph index for implementing the feature. This file is intentionally index-only; all execution details are tracked in Beads issues.

## Feature Tracking

- Beads Epic ID: SpecLedger-7ij
- Epic Labels: spec:001-logo-design-agent, component:backend, component:frontend, component:orchestrator
- User Stories Source: specs/001-logo-design-agent/spec.md
- Research Inputs: specs/001-logo-design-agent/research.md
- Planning Details: specs/001-logo-design-agent/plan.md
- Data Model: specs/001-logo-design-agent/data-model.md
- Contract Definitions: specs/001-logo-design-agent/contracts/

## Phase Features

- Setup: SpecLedger-xgg
- Foundational and Test Gate: SpecLedger-075
- US1 Generate Initial Logos: SpecLedger-j4k
- US2 Select and Edit Logo: SpecLedger-1pf
- US3 Reasoning Transparency: SpecLedger-fkz
- Polish and Cross-Cutting: SpecLedger-1xy

## Beads Query Hints

```bash
# All issues in this feature graph
bd list --label "spec:001-logo-design-agent" --status open -n 200

# Ready work now
bd ready --label "spec:001-logo-design-agent" -n 20

# Phase-specific queues
bd list --label "spec:001-logo-design-agent" --label "phase:setup" -n 20
bd list --label "spec:001-logo-design-agent" --label "phase:foundational" -n 20
bd list --label "spec:001-logo-design-agent" --label "story:US1" -n 50
bd list --label "spec:001-logo-design-agent" --label "story:US2" -n 50
bd list --label "spec:001-logo-design-agent" --label "story:US3" -n 50
bd list --label "spec:001-logo-design-agent" --label "phase:polish" -n 20

# Dependency inspection
bd dep tree SpecLedger-7ij
bd dep tree SpecLedger-j4k
```

## Dependency Strategy

Phase order and blockers:
- Setup blocks Foundational.
- Foundational blocks US1, US2, US3.
- Foundational observability baseline task T027 (SpecLedger-i8l) explicitly blocks US1, US2, and US3 phase features.
- US1 blocks US2.
- US1, US2, US3 all block Polish.

Within-story execution rules:
- Tests are created first in each story phase and block implementation tasks (TDD gate).
- Tasks touching different files/components are kept parallelizable when possible.
- Tasks touching same service paths are sequenced with explicit blocks dependencies.
- MCP boundary validation is foundational and must complete before story implementation.
- Observability baseline and trace bootstrap are foundational and must complete before story implementation.
- Performance and out-of-scope guardrails are enforced in polish before final sign-off.

## Story Testability

- US1 (P1): Independent verification by submitting prompt and asserting reasoning chunks + explicit guideline + exactly 3-4 logo options.
- US2 (P1): Independent verification by selecting one generated logo, applying prompt edit, and asserting regenerated output + concise edit summary.
- US3 (P1): Independent verification by asserting stage-ordered reasoning visibility and explicit assumptions before generation output.

## Parallel Execution Assumptions

- Agent working on backend assumes setup tasks T001-T003, foundational gate T004, and observability baseline T027 are completed first.
- Agent working on US2 assumes US1 integration task T014 is complete and selected logo state is available.
- Agent working on US3 frontend assumes reasoning formatter task T020 has stabilized response payload shape.
- Agents must avoid duplicate edits to the same file set by respecting dependency edges in Beads.
- If a dependency is not closed yet, create a discovered-from issue instead of implementing speculative duplicates.

## Parallel Execution Examples

US1 parallel opportunities after foundational complete:
- Backend extraction/clarification services and frontend rendering work can run in parallel until final API/UI wiring task.

US2 parallel opportunities after US1 complete:
- Selection persistence and edit interpreter tasks can progress in parallel until EditLogo API/UI integration step.

US3 parallel opportunities after foundational complete:
- Backend reasoning formatter and frontend timeline rendering can be split by component owners, then converged for integration checks.

## MVP and Incremental Delivery

Suggested MVP scope:
- Entire Setup + Foundational + US1.
- This validates the primary value hypothesis and verifies test-first plus MCP boundary assumptions early.

Incremental delivery:
1. MVP: Setup + Foundational + US1.
2. Iteration 2: US2 edit loop.
3. Iteration 3: US3 transparency hardening.
4. Final: Polish tasks for reliability/observability/smoke validation.

## Execution Notes

- Use Beads as source of truth for task status; do not duplicate task checklists in markdown.
- Keep labels unchanged for traceability: spec, phase, story, component, requirement, test.
- Legacy graph SpecLedger-fxv is closed and superseded by SpecLedger-7ij.
- If new work is discovered during implementation, create a new issue and link with discovered-from dependency.
