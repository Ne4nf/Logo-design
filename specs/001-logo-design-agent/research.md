# Research: AI Logo Design Agent (POC Phase 1)

**Generated**: 2026-03-22
**Purpose**: Resolve plan unknowns and incorporate feedback from specledger.analyze into executable planning decisions.

## Prior Work

- specs/001-logo-design-agent/spec.md finalized POC scope and requirements (FR-001..FR-014, NFR-001..NFR-008).
- Beads prior closed references from spec: SpecLedger-4cx and SpecLedger-ct8.
- Current open delivery graph in Beads: SpecLedger-7ij epic with setup/foundational/US1/US2/US3/polish phases.

## Decision 1: Test-First Is an Execution Gate (Not Only Policy Text)

### Decision

Every story phase must begin with contract/integration tests that fail first, then implementation tasks are unblocked.

### Rationale

- Constitution principle II is non-negotiable.
- Previous analyze feedback flagged ordering risk when implementation scaffolding proceeds before tests.

### Alternatives considered

- Keep tests inside each story but without blocking semantics.
  - Rejected: does not guarantee constitution compliance in actual execution order.

## Decision 2: MCP Compliance Must Be Explicit

### Decision

Treat MCP conformance as first-class boundary requirement: contracts and runtime adapters must validate MCP-compatible tool I/O schema and error envelopes.

### Rationale

- Constitution principle III requires strict MCP integration.
- Explicit tasks and checks reduce drift and avoid implicit assumptions.

### Alternatives considered

- Rely on generic gRPC/proto validation only.
  - Rejected: insufficient for explicit MCP boundary enforcement.

## Decision 3: Single-Model POC Retained

### Decision

Keep one generation model/provider for initial generation and edit regeneration in Phase 1.

### Rationale

- Reduces integration risk and keeps delivery focus on core hypotheses.
- Aligns with NFR-005 and scope constraints.

### Alternatives considered

- Multi-model routing and auto-evaluation.
  - Rejected for Phase 1; deferred to later phases.

## Decision 4: Measurable Performance Targets

### Decision

Replace qualitative performance wording with measurable targets:

- p95 time to first reasoning chunk <= 1.5s
- p95 guideline + 3-4 options completion <= 25s
- failure response emission <= 3s from detected failure

### Rationale

- Removes ambiguity from NFR/performance planning.
- Enables deterministic validation in tests and observability.

### Alternatives considered

- Keep "responsive enough" and "conversational tolerance" wording.
  - Rejected: not testable.

## Decision 5: Out-of-Scope Guardrails

### Decision

Add explicit negative-scope checks in planning/tasks to enforce that Touch Edit, Smart Mark, multi-model routing, and auto-eval are not introduced in Phase 1.

### Rationale

- Protects 4-week execution safety.
- Prevents accidental scope creep from implementation shortcuts.

### Alternatives considered

- Rely on narrative out-of-scope section only.
  - Rejected: narrative-only constraints are often bypassed under schedule pressure.

## Decision 6: Measurable Output Quality and Deterministic Defaults

### Decision

Apply explicit quality checks to generated PNG outputs (minimum 1024x1024, no unreadable text artifact, no severe pixelation at 200% zoom, visible consistency with guideline) and enforce deterministic skip/default behavior for repeated runs with the same normalized skipped input.

### Rationale

- Resolves ambiguity raised during analysis for FR-014 and NFR-003.
- Enables stable validation for both visual quality and assumption-handling behavior.

### Alternatives considered

- Keep qualitative wording only (for example, "clean vector-style" and "consistent behavior").
  - Rejected: not sufficiently testable for gate-based execution.

## Consolidated Result

- No unresolved NEEDS CLARIFICATION items remain.
- Plan inputs for Phase 1 artifacts are stable.
- Next iteration of tasks should add explicit MCP, performance, and guardrail coverage to close analyze gaps.
