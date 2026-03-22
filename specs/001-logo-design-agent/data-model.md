# Data Model: AI Logo Design Agent (POC Phase 1)

**Generated**: 2026-03-22
**Purpose**: Define entities, validations, and state transitions for the simplified 8-step POC flow.

## Core Entities

### 1) Session

**Purpose**: Holds conversation context for one active POC run.

**Attributes**:
- `session_id` (string, required)
- `phase` (enum): `new | analyzing | clarifying | reasoning | generating | awaiting_selection | editing | completed | failed`
- `created_at` (datetime)
- `expires_at` (datetime, TTL-based)
- `trace_id` (string, optional)

**Validation**:
- `session_id` non-empty
- TTL enforced by storage layer
- `trace_id` required when observability is enabled

### 2) BrandContext

**Purpose**: Structured extraction from user text input.

**Attributes**:
- `brand_name` (string, optional)
- `industry` (string, optional)
- `style_intent` (list of strings)
- `core_values` (list of strings)
- `target_audience` (string, optional)
- `assumptions` (list of strings)

**Validation**:
- lists have bounded size
- strings trimmed and normalized

### 3) ClarificationPrompt

**Purpose**: Optional clarification questions when required input is missing.

**Attributes**:
- `clarification_id` (string)
- `session_id` (string)
- `questions` (list of strings)
- `is_skippable` (bool)
- `status` (enum): `open | answered | skipped`

### 4) ReasoningBlock

**Purpose**: Structured reasoning chunks shown before generation.

**Attributes**:
- `block_id` (string)
- `session_id` (string)
- `stage` (enum): `input_understanding | style_inference | done`
- `title` (string)
- `bullets` (list of strings)
- `emitted_at` (datetime)
- `latency_ms_from_request_start` (int)

**Validation**:
- first emitted block must be `input_understanding`
- `latency_ms_from_request_start` must be non-negative

### 5) DesignGuideline

**Purpose**: Explicit design guideline output generated before image generation.

**Attributes**:
- `guideline_id` (string)
- `session_id` (string)
- `summary` (string)
- `prompt_basis` (string)
- `visual_direction` (list of strings)
- `typography_notes` (string)
- `assumptions` (list of strings)

### 6) LogoOption

**Purpose**: A generated candidate logo shown to user.

**Attributes**:
- `logo_id` (string)
- `session_id` (string)
- `image_url` (string)
- `model_provider` (string)
- `generated_from_guideline_id` (string)
- `generated_at` (datetime)
- `width_px` (int)
- `height_px` (int)
- `quality_checks` (object):
  - `single_primary_mark` (bool)
  - `no_unreadable_overlaid_text` (bool)
  - `no_severe_pixelation_at_200_zoom` (bool)
  - `guideline_consistency_visible` (bool)

**Validation**:
- 3-4 logo options per generation request
- each `image_url` must be absolute URL
- `width_px >= 1024` and `height_px >= 1024`
- all quality_checks fields must be true before option is considered passable for FR-014

### 7) SelectedLogo

**Purpose**: The user-selected logo target for editing.

**Attributes**:
- `session_id` (string)
- `logo_id` (string)
- `selected_at` (datetime)

### 8) EditCommand

**Purpose**: Natural language edit instruction tied to selected logo.

**Attributes**:
- `edit_id` (string)
- `session_id` (string)
- `target_logo_id` (string)
- `command_text` (string)
- `interpreted_change` (string)
- `created_at` (datetime)

### 9) UpdatedLogo

**Purpose**: Regenerated output after edit command.

**Attributes**:
- `updated_logo_id` (string)
- `session_id` (string)
- `source_logo_id` (string)
- `image_url` (string)
- `edit_summary` (list of strings)
- `generated_at` (datetime)

**Validation**:
- edit summary requires at least one bullet

### 10) MCPToolEnvelope

**Purpose**: Defines strict MCP-compatible boundary for external tool interactions.

**Attributes**:
- `tool_name` (string)
- `tool_version` (string)
- `input_schema_version` (string)
- `output_schema_version` (string)
- `request_payload` (json object)
- `response_payload` (json object)
- `error_code` (string, optional)
- `error_message` (string, optional)

**Validation**:
- payloads must validate against declared schema version
- errors must use explicit code/message (no silent fallback)

## Relationships

- Session `1 -> 1` BrandContext
- Session `1 -> 0..1` ClarificationPrompt
- Session `1 -> N` ReasoningBlock
- Session `1 -> 1` DesignGuideline
- Session `1 -> 3..4` LogoOption
- Session `1 -> 1` SelectedLogo (once selection is made)
- SelectedLogo `1 -> N` EditCommand
- EditCommand `1 -> 1` UpdatedLogo (on success)
- Session `1 -> N` MCPToolEnvelope

## State Transitions

### Session Flow

`new -> analyzing -> clarifying(optional) -> reasoning -> generating -> awaiting_selection -> editing -> completed`

Failure path:

`any_state -> failed` with transparent error payload and retry guidance.

Timing SLO anchors:

- first ReasoningBlock emitted within 1500ms (p95)
- generation completion within 25000ms (p95)

### Clarification Flow

`open -> answered` or `open -> skipped`

Skipped path must append explicit assumptions to BrandContext/Guideline.

### Edit Flow

`selected -> edit_requested -> regenerating -> updated`

## Validation Rules (Cross-Entity)

1. Each `SelectedLogo.logo_id` must exist in that session's `LogoOption` set.
2. `EditCommand.target_logo_id` must equal the active selected logo.
3. `UpdatedLogo.source_logo_id` must reference a valid `LogoOption.logo_id`.
4. Generation must not proceed without `DesignGuideline`.
5. If clarification is skipped, at least one assumption must be recorded.
6. Any external tool invocation must create one MCPToolEnvelope record.
7. For the same normalized skipped input payload, emitted assumptions and assumption ordering must be stable across repeated runs.

## Deferred Entities (Not in Phase 1)

- RegionMask
- CanvasSelection
- MultiModelRoutingDecision
- AutoEvaluationReport

These are intentionally deferred and excluded from required POC persistence model.
- `brand.proto`: BrandContext entity
- `agent.proto`: Streaming RPC service definitions
- `worker.proto`: ai-hub-sdk Worker task message definitions
