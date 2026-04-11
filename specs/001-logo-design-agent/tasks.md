# Logo Design AI — Technical Design (source_v2)

## 1. Overview

### 1.1 Objective

Build a logo generation and editing backend using a **tool-first DAG orchestration runtime** (`source_v2`). The system plans, executes, and streams structured results through a reusable tool registry, an iterative DAG planner, and an executor with interpolation middleware.

### 1.2 In-scope (step-by-step)

| Step | Name | What the backend does |
|:---|:---|:---|
| Step 1 | Intent Detection | Classify whether the user request is related to logo design. |
| Step 2 | Input Extraction + Reference Analysis | Extract brand context fields (`brand_name`, `industry`, style, color, symbol, typography) from the user query and any attached reference images. |
| Step 3 | Required-field Gate + Clarification Loop | Validate that mandatory fields (`brand_name`, `industry`) are present. If missing, generate clarification questions and pause the pipeline until the user answers. |
| Step 4 | Web Research Enrichment | Search for visual references via an **Image Search API** (configurable provider), then analyze top results with a **Text/Multimodal LLM** to extract design insights. |
| Step 5 | Design Guideline Inference | Generate per-concept design guidelines (prompt, negative prompt, style tags, color palette, Do's and Don'ts) from brand context + research insights. Write guidelines to the **Design Artifact Store** (DB). |
| Step 6 | Logo Generation | Generate logo options in parallel from finalized guidelines using an **Image Generation API** (configurable provider). |
| Step 7 | Image Editing (Edit Loop) | User selects a generated logo and provides an edit instruction (with optional mask or crop). BE calls an **Image Edit API** to produce the edited image. If style changed, update the Design Artifact Store. Suggest follow-up edits. User can loop or finish. |

### 1.3 Out-of-scope

- Step 8: Follow-up suggestion intelligence (automatic next-action recommendation).
- Multi-domain intent classifier (non-logo task routing).
- Production queue-decoupled deployment.

### 1.4 Success metrics

| Metric | Target |
|:---|:---|
| Requests that extract or clarify `brand_name` + `industry` before generation | >= 90% |
| Requests past required-field gate that produce valid guideline | >= 90% |
| Requests returning valid options payload | >= 85% |
| p95 stream end-to-end completion (generate flow) | <= 40s |
| Edit-flow single-image turnaround (Case 2) | <= 15s |
| On failure, return actionable `error_code` and `error_message` | 100% |

### 1.5 User journey (full flow including edit)

1. User submits query with optional explicit fields and references.
2. System streams DAG execution chunks (intent → extract → gate).
3. If required fields are missing, system emits `clarification_needed` and pauses.
4. User answers; system re-plans with post-clarification DAG (research → guideline → generate).
5. System returns completed payload with 3 logo options.
6. **User selects a logo and enters edit instruction** (with optional mask or crop).
7. System runs edit DAG → calls Image Edit API → updates Design Artifact if style changed → returns edited image.
8. System suggests follow-up edits. User can loop back to step 6 or finish.

### 1.6 Technical constraints

- Runtime is `source_v2` package: tool-first DAG orchestration with `Runner` + `PlannerTool` + `ToolExecutor`.
- Tools are OOP classes (`V2BaseTool`) registered in `ToolRegistry`.
- DAG plans are Pydantic models (`DAGPlan`, `DAGNode`) validated by `DAGValidator` (cycle detection, dependency resolution).
- Tool inputs support `${...}` placeholder interpolation resolved by `InputResolver` at execution time.
- Clarification is handled via iterative DAG re-plan with `should_pause_for_clarification()` decision hook.
- Session state persisted in-memory via `RuntimeState` with `context_version` for stale-write-safe merges.
- Provider failures are fail-closed with explicit `ToolError` codes.
- **Design Artifact Store** — the "DESIGN.md" shown on UI is a mock; the backend treats it as a **structured artifact persisted in a data store** (currently in-memory DB mock). In production this will likely be managed by a dedicated artifact/storage service.

---

## 2. Scope

### 2.1 Build vs Defer

| Area | Build (source_v2) | Defer |
|:---|:---|:---|
| Intent + input (Step 1–2) | IntentDetectTool + InputExtractTool + ReferenceAnalyzeTool | Multi-domain intent classifier |
| Clarification (Step 3) | ClarificationGateTool + ClarificationTool + iterative re-plan | Adaptive personalized questioning policy |
| Research (Step 4) | WebResearchTool + AnalyzeResearchTool (Image Search API + LLM analyzer) | Automatic query backfill when image pool is insufficient |
| Guideline (Step 5) | GuidelineGenerateTool (parallel per-image inference) | Guideline optimization loop |
| Generation (Step 6) | LogoGenerateTool (parallel option generation via Image Generation API) | Provider auto-routing/ranking |
| **Editing (Step 7)** | **LogoEditTool (Case 1/2/3) via Image Edit API** | Multi-candidate ranking before edit output |
| Planning | PlannerTool (LLM-based DAG planning + deterministic fallback) | Multi-agent self-critique loops |
| Session / Design Artifact | RuntimeState + context_version versioning + Design Artifact Store (DB mock) | Dedicated artifact service, long-term project memory |

### 2.2 Not yet implemented

- Production BFF stream controls (retry/reconnect/backpressure).
- Queue-decoupled deployment for heavy generation nodes.
- Confidence-threshold gate policy as hard rule.
- End-to-end cost analytics by task_id and session_id.
- Asset retention and signed URL TTL runtime policy.
- SAM model deployment for Case 1 (FE) and Case 3 (BE mask generation).
- Dedicated Design Artifact service (currently mock DB in-memory).

---

## 3. System Architecture

### 3.1 Overview

#### 3.1.1 Why this architecture

The source_v2 architecture is a **tool-first DAG runtime** with these key properties:

1. **Tool Registry** — reusable OOP tool classes with metadata-only context for planner prompts.
2. **DAG Planner** — LLM-based planning with deterministic fallback templates; supports iterative re-plan after clarification.
3. **Input Interpolation** — `${...}` bindings resolved at execution from `RuntimeState` (node results, query, user_context).
4. **Executor Middleware** — timeout, retry, and topological-order execution.
5. **Iterative Clarification** — pause/re-plan loop with `context_version` for stale-write-safe merges.
6. **Edit Loop** — iterative edit DAG with session state persistence for style tracking.
7. **Design Artifact Store** — structured artifact (brand overview, style, Do's/Don'ts) persisted in DB. Currently mocked as in-memory store rendered as "DESIGN.md" on UI; production-ready for migration to a dedicated artifact service.

#### 3.1.2 Diagram — Full flow (flowchart)

> The following diagram shows the complete user journey including the edit loop.
> "Design Artifact (DB)" represents the structured design data stored in the backend data store. On the UI it is displayed as a file for user readability, but the backend treats it as a DB record/artifact.

![Full flow diagram](C:\Users\THUC\.gemini\antigravity\brain\1a12dabc-340a-4e42-a7a3-c30d4f2ab75f\image_flowchart_diagram.png)

```mermaid
flowchart TD
  U([User sends message]) --> A1["analyze_logo_request\n(message, session_id, image?)"]
  A1 --> DB1[("Design Artifact - DB\nwrite: Overview, Brand, Style")]
  DB1 --> G1{brand + industry?}

  G1 -->|No| CL[Clarify question]
  CL --> UR([User replies])
  UR --> A1

  G1 -->|Yes| G2{image reference?}
  G2 -->|No| SR["search_references\n(brand, industry)"]
  G2 -->|Yes| AP["auto-pick top 3\nby relevance"]
  SR --> AP
  AP --> GD["generate_design_guideline\n(session_id)"]
  GD --> DB2[("Design Artifact - DB\nread context, write Do's and Don'ts")]
  DB2 --> GL["generate_logo\n(guideline, count=3)"]

  GL --> EDIT_LOOP

  subgraph EDIT_LOOP["Edit loop (Step 7)"]
    direction TB
    SEL([User selects logo]) --> ED["edit_logo\n(image_url, instruction, mask?)"]
    ED --> DB3[("Design Artifact - DB\nupdate if style changed")]
    DB3 --> SUG[Suggest follow-ups]
    SUG --> AGAIN{Edit again?}
    AGAIN -->|Yes| SEL
  end

  AGAIN -->|No| DONE([Done])
```

#### 3.1.3 Diagram — Sequence diagram (full flow)

> The following diagram shows the detailed sequence including the edit loop.
> "Design Artifact (DB)" is the backend data store for design context. On the UI this is rendered as a file, but it is a DB artifact.

![Sequence diagram](C:\Users\THUC\.gemini\antigravity\brain\1a12dabc-340a-4e42-a7a3-c30d4f2ab75f\image_sequence_diagram.png)

```mermaid
sequenceDiagram
  actor FE as Frontend
  participant AG as Agent (Runner)
  participant TL as Tools
  participant DB as Design Artifact (DB)
  participant IMG as Image API

  Note over FE: generate session_id

  FE->>AG: POST /stream (task_type="logo_design", session_id, message, image?)
  AG-->>FE: {type:"progress", stage:"analyzing"}
  AG->>TL: analyze_logo_request(message, image?, session_id)
  TL->>DB: write(session_id, Overview, Brand, Style)
  DB-->>TL: ok
  TL-->>AG: {brand, industry, is_sufficient}

  alt missing brand or industry
    AG-->>FE: stream clarify question
    FE->>AG: POST /stream (task_type="logo_design", session_id, user reply)
    AG-->>FE: {type:"progress", stage:"analyzing"}
    AG->>TL: analyze_logo_request(reply, session_id)
    TL->>DB: update(session_id, Brand, Style)
    DB-->>TL: ok
    TL-->>AG: {brand, industry, is_sufficient}
  end

  AG-->>FE: {type:"progress", stage:"searching_references"}
  AG->>TL: search_references(brand, industry)
  TL-->>AG: references[3]

  AG-->>FE: {type:"references", data:references[3]}
  AG-->>FE: {type:"progress", stage:"creating_guideline"}

  AG->>TL: generate_design_guideline(session_id)
  TL->>DB: read(session_id)
  DB-->>TL: Overview + Brand + Style
  TL->>DB: write(session_id, Do's and Don'ts)
  DB-->>TL: ok
  TL-->>AG: {prompt, negative_prompt, style_tags, palette}

  AG-->>FE: {type:"guideline", data:{prompt, style_tags, palette}}
  AG-->>FE: {type:"progress", stage:"generating_logos"}

  AG->>TL: generate_logo(guideline, count=3)
  TL->>IMG: generate(prompt)
  IMG-->>TL: image_urls[3]
  TL-->>AG: image_urls[3]

  AG-->>FE: {type:"result", data:image_urls[3]}

  loop User edits (Step 7)
    FE->>AG: POST /stream (task_type="logo_design", session_id, edit instruction, selected_url)
    AG-->>FE: {type:"progress", stage:"editing_logo"}
    AG->>TL: edit_logo(image_url, instruction, session_id, mask?)
    TL->>DB: update(session_id, Style)
    DB-->>TL: ok
    TL->>IMG: edit(image_url, instruction, mask?)
    IMG-->>TL: image_url
    TL-->>AG: image_url
    AG-->>FE: {type:"result", data:image_url}
    AG-->>FE: {type:"suggestions", data:suggestions[]}
  end
```

#### 3.1.4 Diagram — DAG pipeline (source_v2 internals)

```mermaid
flowchart TD
  U[User Request] --> API[POST /stream]
  API --> AGENT[LogoCreatorAgent]
  AGENT --> RUNNER[Runner]
  RUNNER --> PLANNER[PlannerTool]

  subgraph DAG_GEN["DAG Plan — Generate Flow"]
    direction TB
    N1["intent\nIntentDetectTool"]
    N2["extract\nInputExtractTool"]
    N3["clarification_gate\nClarificationGateTool"]
    N4["clarification\nClarificationTool"]
    N5["research\nWebResearchTool"]
    N6["guideline\nGuidelineGenerateTool"]
    N7["generate\nLogoGenerateTool"]
  end

  subgraph DAG_EDIT["DAG Plan — Edit Flow"]
    direction TB
    E1["edit\nLogoEditTool"]
  end

  PLANNER --> N1
  N1 --> N2
  N2 --> N3
  N3 -->|missing fields| N4
  N4 --> RUNNER
  N3 -->|gate passed| N5
  N5 --> N6
  N6 --> N7

  N7 --> |User selects + edit| E1

  subgraph EXEC["Executor Layer"]
    direction TB
    TE[ToolExecutor]
    IR[InputResolver]
    DV[DAGValidator]
  end

  RUNNER --> TE
  TE --> IR
  TE --> DV

  subgraph INFRA["Infrastructure"]
    direction TB
    REG[ToolRegistry]
    RS[RuntimeState]
    CFG[SourceV2Settings]
    DAS["Design Artifact Store (DB)"]
  end

  AGENT --> REG
  RUNNER --> RS
  RUNNER --> CFG

  subgraph EXTERNAL["External Services (configurable providers)"]
    direction TB
    LLM["Text / Multimodal LLM"]
    SEARCH["Image Search API"]
    IMGAPI["Image Generation API"]
    EDITAPI["Image Edit API"]
  end

  N1 --> LLM
  N2 --> LLM
  N5 --> SEARCH
  N5 --> LLM
  N6 --> LLM
  N7 --> IMGAPI
  E1 --> EDITAPI
```

### 3.2 Architecture principles

- **Tool-first**: business logic is encapsulated in registerable tool classes with explicit input/output schemas.
- **Schema-first**: Pydantic models enforce DAG plan, tool IO, and runtime state contracts.
- **DAG-first planning**: LLM-based planner generates DAG JSON; deterministic templates as fallback.
- **Interpolation-driven**: `${...}` bindings decouple tool wiring from execution.
- **Iterative re-plan**: clarification pauses DAG, persists state, and resumes with post-clarification plan.
- **Fail-closed**: tool execution failures propagate explicit `ToolError` codes.
- **Context-versioned**: `RuntimeState.context_version` prevents stale-write conflicts.
- **Provider-agnostic**: all external services (LLM, Image Search, Image Generation, Image Edit) are configurable. Specific providers are evaluated in the Benchmark section (Section 5) and selected by PO.

#### 3.2.1 Design Artifact Store

The "DESIGN.md" visible on the UI is **not a literal file**. It is a **structured artifact** persisted in the backend data store:

| Aspect | Detail |
|:---|:---|
| What it stores | Brand overview, style preferences, color palette, Do's and Don'ts, guideline context per session |
| Current implementation | In-memory mock DB (dict-based store) |
| UI representation | Rendered as a readable file/document for the user |
| Future plan | Migrate to a dedicated artifact/storage service with versioning, access control, and persistence |
| Treated as | An artifact — one of several outputs produced during the design pipeline |

Tools that read/write the Design Artifact: `InputExtractTool`, `GuidelineGenerateTool`, `LogoEditTool`.

#### 3.2.2 Memory flow contract (source_v2)

1. `Runner` owns the execution loop state — `RuntimeState` including `node_results`, `artifacts`, `context_version`.
2. `PlannerTool` receives `runtime_state` and `tool_contexts` to generate DAG plans.
3. `ToolExecutor` runs nodes in topological order, resolving `${...}` inputs from `RuntimeState`.
4. `RuntimeState` is persisted per `session_id` in `Runner._runtime_sessions` (in-memory).
5. Clarification follow-up restores state from persisted session or `user_context.runtime_state`.
6. `context_version` increments on each persist to detect version conflicts.

#### 3.2.3 Simplification notes

- Planner and executor are separate modules but run in one stream lifecycle.
- DAG execution is sequential (topological order), not parallelized across independent nodes.
- Session store is in-memory (`dict`) — does not survive process restarts.
- Design Artifact Store is in-memory mock — does not survive process restarts.
- Edit flow reuses the same `Runner` and `ToolRegistry` infrastructure.

### 3.3 Component breakdown

#### 3.3.1 Agent layer

| Component | Role | Notes |
|:---|:---|:---|
| LogoCreatorAgent | High-level facade; wires registry, planner, executor, and runner | Entry point for external callers |
| Runner (BaseRunner) | Iterative DAG execution loop with clarification pause and re-plan | Owns `RuntimeState`, session persistence, chunk emission |

#### 3.3.2 Planner layer

| Component | Role | Notes |
|:---|:---|:---|
| PlannerTool (BasePlanner) | LLM-based DAG planner with deterministic fallback templates | Supports multiple LLM provider frameworks; auto-repair on malformed output |
| planner_templates | `build_default_logo_plan()` and `build_post_clarification_plan()` | Deterministic fallback DAGs |
| DAGValidator | Topological sort + cycle detection + dependency validation | Throws `DAGValidationError` |

#### 3.3.3 Executor layer

| Component | Role | Notes |
|:---|:---|:---|
| ToolExecutor (BaseToolExecutor) | Execute DAG nodes with timeout and retry middleware | Skips clarification node when gate passes |
| InputResolver | Resolve `${...}` placeholders against `RuntimeState` | Supports nested paths like `${extract.result.context.brand_name}` |
| ExecutionValidator | Decision hook: `should_pause_for_clarification()` | Checks clarification_gate result |

#### 3.3.4 Tool layer — Generate flow (Step 1–6)

| Tool | DAG node id | Step | Purpose | Delegates to |
|:---|:---|:---|:---|:---|
| IntentDetectTool | `intent` | 1 | Detect logo generation intent from user query | Text/Multimodal LLM |
| InputExtractTool | `extract` | 2 | Extract brand context from query + references | Text/Multimodal LLM |
| ReferenceAnalyzeTool | — | 2 | Analyze reference images for visual preferences | Text/Multimodal LLM |
| ClarificationGateTool | `clarification_gate` | 3 | Check `brand_name` + `industry` presence | Local validation logic |
| ClarificationTool | `clarification` | 3 | Generate clarification questions for missing fields | Text/Multimodal LLM |
| WebResearchTool | `research` | 4 | Collect visual references via Image Search API | Image Search API |
| AnalyzeResearchTool | — | 4 | Analyze research results and extract design insights | Text/Multimodal LLM (wraps WebResearchTool output) |
| GuidelineGenerateTool | `guideline` | 5 | Generate per-concept design guidelines, write to Design Artifact | Text/Multimodal LLM |
| LogoGenerateTool | `generate` | 6 | Generate logo options from guidelines | Image Generation API |
| ToolSearchTool | — | — | Search available tools by name/description | Local keyword search on `ToolContext` |

#### 3.3.5 Tool layer — Edit flow (Step 7)

| Tool | DAG node id | Step | Purpose | Delegates to |
|:---|:---|:---|:---|:---|
| LogoEditTool | `edit` | 7 | Edit a generated logo (Case 1/2/3), update Design Artifact if style changed | Image Edit API |

#### 3.3.6 Schema layer

| Schema | Purpose |
|:---|:---|
| DAGPlan | Plan containing `planning_mode`, `nodes[]`, `edges[]` |
| DAGNode | Single node: `id`, `tool`, `tool_input`, `deps[]` |
| PlanningMode | Enum: `single_pass` or `iterative` |
| RuntimeState | Mutable execution state: `input`, `node_results`, `artifacts`, `clarification_round`, `context_version` |
| ToolContext | Metadata-only tool contract for planner prompts |
| ToolResult | Node execution result with `result`, `error`, `trace` |
| ToolError | Structured error with `code` and `message` |
| LargePayloadRef | Stable artifact reference for oversized payloads |
| ArtifactKind | Enum: `inline`, `file`, `object_store`, `vector_store` |

### 3.4 End-to-end pipeline

#### 3.4.1 Generate flow — Default DAG

```
intent → extract → clarification_gate → [clarification] → research → guideline → generate
```

Planner template: `build_default_logo_plan()`

| Node | Tool | Input bindings | Dependencies |
|:---|:---|:---|:---|
| `intent` | `intent_detect` | `query: ${query}` | — |
| `extract` | `input_extract` | `query: ${query}`, `references: ${user_context.references}` | `intent` |
| `clarification_gate` | `clarification_gate` | `context: ${extract.result.context}` | `extract` |
| `clarification` | `clarification_tool` | `missing_fields: ${clarification_gate.result.missing_fields}`, `query: ${query}`, `current_context: ${extract.result.context}` | `clarification_gate` |
| `research` | `web_research` | `brand_context: ${extract.result.context}` | `clarification_gate` |
| `guideline` | `guideline_generate` | `brand_context: ${extract.result.context}`, `research_context: ${research.result.research_context}` | `research` |
| `generate` | `logo_generate` | `task_id: ${task_id}`, `guidelines: ${guideline.result.guidelines}`, `brand_name: ${extract.result.context.brand_name}`, `industry: ${extract.result.context.industry}`, `variation_count: ${user_context.variation_count}` | `guideline` |

#### 3.4.2 Post-clarification DAG

When `clarification_answer` is provided and `extract` result exists:

```
research → guideline → generate
```

Planner template: `build_post_clarification_plan()`

The Runner applies `clarification_answer` fields (brand_name, industry, style_preference, color_preference, symbol_preference, typography_direction) into the existing `extract.result.context` before re-planning.

#### 3.4.3 Edit flow — Edit DAG (Step 7)

After generation completes, user can enter the edit loop:

```
edit (→ update Design Artifact → suggest follow-ups)
```

Frontend sends: `POST /stream` with `task_type="logo_design"`, `session_id`, `edit_instruction`, `selected_url`, optional `mask` or `crop`.

| Item | Detail |
|:---|:---|
| Input | `image_url` (selected logo), `instruction` (edit prompt), optional `mask` or `crop_image` |
| Tool used | `LogoEditTool` → Image Edit API (configurable provider) |
| Editing case | Auto-detected based on input presence (mask → Case 1, crop → Case 3, neither → Case 2) |
| Design Artifact update | If style changed, update session's design artifact in DB |
| Output | Edited `image_url` + trace metadata + `suggestions[]` |
| Loop | User can continue editing or finish |

#### 3.4.4 Clarification loop mechanics

1. `ToolExecutor` executes `clarification_gate` node.
2. If `gate.result.passed == false`, executor continues to `clarification` node (generates questions).
3. `ExecutionValidator.should_pause_for_clarification()` returns `true`.
4. `Runner` emits `clarification_needed` chunk with `missing_fields`, `questions`, and full `runtime_state`.
5. `Runner` persists `RuntimeState` to session store with version check.
6. On next call, `Runner` restores state, applies `clarification_answer`, and `PlannerTool` returns `build_post_clarification_plan()`.
7. Max rounds configured via `max_clarification_rounds` (default: 2).

#### 3.4.5 Stream status progression

Generate flow:
```
planning_ready → intent_ready → context_extracted → clarification_gate_checked →
  [clarification_questions_ready → clarification_needed] →
  research_completed → guideline_completed →
  generation_option_ready (repeated) → generation_completed → completed
```

Edit flow:
```
planning_ready → editing_logo → edit_completed → completed
```

---

## 4. Image Editing Phase (Step 7)

### 4.1 Phase objective

- Enable controlled edits on generated logos.
- Prioritize region accuracy, output consistency, and response speed.
- Capture measurable metrics for latency, cost, quality, and user satisfaction.

### 4.2 Three editing cases

| Case | Purpose | Frontend Input | Backend Handling | Output | Key Risks |
|:---|:---|:---|:---|:---|:---|
| Case 1: FE Mask + BE Inpainting | Precise local edit with clear protected area | Source image + Binary mask (white=edit, black=keep) + Prompt | Inpainting model edits white region, preserves black region, blends edges | Edited image + trace metadata | Wrong mask quality, boundary artifacts |
| Case 2: Minimal Edit (No Mask) | Fast editing with lowest UI complexity | Source image + Prompt only | Edit/generation model receives image+prompt; no hard mask constraint | Edited image + trace metadata | Over-editing outside target area |
| Case 3: Crop-guided Edit | Keep FE simple while still using mask constraints | Source image + Bounding-box crop image + Prompt | BE runs segmenter on source+crop to create mask, then inpainting | Edited image + generated mask + trace metadata | Crop too loose/tight, mask derivation errors |

### 4.3 Case details

#### 4.3.1 Case 1 — FE Mask + BE Inpainting

**Step 1: Frontend (Data Initialization)**
1. User clicks a detail on the generated logo.
2. FE runs a segmentation model (e.g., SAM) in browser and creates `Mask_Image` (white = edit region, black = keep region).
3. FE setup: load segmentation ONNX weights (lazy-load on first click), inference via WebAssembly/WebGPU.
4. User enters edit instruction (e.g., "Turn this shape into a fire dragon").
5. FE calls `POST /edit` with: `Original_Image`, `Mask_Image`, `Raw_Prompt`.

**Step 2: Backend (Inpainting Execution)**
1. BE calls an Image Edit / Inpainting API with `image`, `mask`, `prompt`.
2. Model behavior: keep 100% of black-mask pixels, regenerate white-mask region, auto-blend boundaries.

#### 4.3.2 Case 2 — Minimal Edit (1 image + 1 prompt)

**Step 1: Frontend**
1. FE sends only `Original_Image` and `Raw_Prompt`.

**Step 2: Backend**
1. BE calls Image Edit API with image+prompt.
2. Model understands prompt semantically; internal attention acts as implicit mask.
3. BE injects preservation instruction (keep layout/style where possible).
4. Return edited image and trace metadata.

#### 4.3.3 Case 3 — Source + Crop + Prompt (Mask generated in BE)

**Step 1: Frontend**
1. FE sends: `Original_Image`, `Crop_Image` (bounding-box crop of target region), `Raw_Prompt`.

**Step 2: Backend**
1. Locate crop region against original image.
2. Run segmentation model (e.g., SAM or another segmenter) in backend to convert crop into binary mask.
3. Run inpainting with `Original_Image` + generated mask + `Raw_Prompt`.
4. Return edited image, optional debug mask, and trace metadata.

### 4.4 Edit tool integration in source_v2

```python
class LogoEditInput(ToolInput):
    image_url: str
    instruction: str
    session_id: str
    mask_image: str | None = None        # Case 1: base64 or URL
    crop_image: str | None = None        # Case 3: base64 or URL
    editing_case: str | None = None      # "case_1", "case_2", "case_3" or auto-detect

class LogoEditOutput(ToolOutput):
    edited_image_url: str
    editing_case: str
    mask_used: bool
    trace: dict
```

Auto-detection logic:
- `mask_image` present → Case 1
- `crop_image` present → Case 3
- Neither → Case 2

---

## 5. Models & API Benchmark

This section lists **all configurable external providers** used across the pipeline. Specific provider selection is a PO decision based on benchmark results below. The backend is provider-agnostic — any listed option can be swapped via configuration.

### 5.1 Text / Multimodal LLM (used in Step 1–5)

Used by: IntentDetectTool, InputExtractTool, ReferenceAnalyzeTool, ClarificationTool, AnalyzeResearchTool, GuidelineGenerateTool, PlannerTool.

| Name | Pricing | Avg Cost / 1K tokens | Avg Latency | Recommended Use Case | Note |
|:---|:---|:---|:---|:---|:---|
| google/gemini-2.5-flash | $0.15/1M input, $0.60/1M output | ~$0.0006 (output) | ~1–3s | Fast text reasoning, planning, extraction | Low cost, good for high-throughput |
| google/gemini-2.5-pro | $1.25/1M input, $10/1M output | ~$0.01 (output) | ~3–8s | Complex reasoning, guideline generation | Higher quality, higher cost |
| openai/gpt-4.1 | $2/1M input, $8/1M output | ~$0.008 (output) | ~2–6s | General-purpose text reasoning | Strong instruction following |
| openai/gpt-4.1-mini | $0.40/1M input, $1.60/1M output | ~$0.0016 (output) | ~1–3s | Cost-effective text tasks | Good balance of quality and cost |
| openai/gpt-4.1-nano | $0.10/1M input, $0.40/1M output | ~$0.0004 (output) | ~0.5–2s | Ultra-low-cost, simple extraction | Fastest, cheapest |
| anthropic/claude-sonnet-4 | $3/1M input, $15/1M output | ~$0.015 (output) | ~3–8s | Complex analysis, nuanced reasoning | Strong at structured output |

### 5.2 Image Search API (used in Step 4)

Used by: WebResearchTool.

| Name | Pricing | Avg Cost / request | Rate Limit | Coverage | Note |
|:---|:---|:---|:---|:---|:---|
| SerpAPI — Google Images | $50/5K searches (paid plan) | ~$0.01/search | 100/month (free), 5K/month (paid) | Google Image index | Most comprehensive coverage, structured metadata |
| SerpAPI — Bing Images | $50/5K searches (paid plan) | ~$0.01/search | Same as above | Bing Image index | Alternative index, good for diversity |
| Pinterest API | Free (with developer access) | Free | Rate-limited per app | Pinterest visual content | Strong for design/aesthetic references; limited to Pinterest content |

### 5.3 Image Generation API (used in Step 6)

Used by: LogoGenerateTool.

| Name | Pricing | Avg Cost | Avg Latency | Recommended Use Case | Note |
|:---|:---|:---|:---|:---|:---|
| google/gemini-2.5-flash-image | $30/1M output tokens; ~1,290 tokens/1024px (~$0.039/image) | $0.039 (1024px) | ~6s | Low-cost bulk generation, rapid prototyping | Free tier exists with rate limits |
| google/gemini-3.1-flash-image-preview | ~$0.045–$0.151/image; 1024px ~$0.067 | $0.067 (1024px) | 23–56s (avg ~37.6s) | High-quality premium generation | Preview-phase variability |
| google/gemini-3-pro-image-preview | ~$0.02–$0.08/image | ~$0.05 | 3–12s | Professional-grade, stronger text rendering | Supports up to 4K-class outputs |
| openai/gpt-image-1 | Low $0.011, Medium $0.042, High $0.167 | $0.042 (medium) | ~45–50s | General-purpose generation | Token-based billing in some modes |
| openai/gpt-image-1.5 | Low $0.009–$0.052, Medium $0.034–$0.051, High $0.133–$0.200 | $0.034 (medium) | 15–45s | Premium generation, stronger prompt adherence | Faster than gpt-image-1 |

### 5.4 Image Edit API (used in Step 7)

Used by: LogoEditTool.

| Name | Pricing | Avg Cost | Avg Latency | Latency vs Output Token | Recommended Use Case | Case Fit | Note |
|:---|:---|:---|:---|:---|:---|:---|:---|
| google/gemini-2.5-flash-image | $30/1M output tokens; ~$0.039/image | $0.039 (1024px) | ~6s | Positive — grows with token count | Low-cost prompt-only editing, rapid iteration | Case 2 | Free tier exists with rate limits |
| google/gemini-3.1-flash-image-preview | ~$0.045–$0.151/image | $0.067 (1024px) | 23–56s (avg ~37.6s) | Weak/unclear correlation | High-quality premium editing | Case 2 | Preview-phase variability |
| google/gemini-3-pro-image-preview | ~$0.02–$0.08/image | ~$0.05 | 3–12s | Increases with resolution | Professional-grade editing, text rendering | Case 2 | Supports up to 4K-class outputs |
| openai/gpt-image-1 | Low $0.011, Medium $0.042, High $0.167 | $0.042 (medium) | ~45–50s | Higher quality tiers increase latency | General-purpose editing | Case 2 | Token-based billing in some modes |
| openai/gpt-image-1.5 | Low $0.009–$0.052, Medium $0.034–$0.051, High $0.133–$0.200 | $0.034 (medium) | 15–45s | Increases with quality tier | Premium marketing edits, prompt adherence | Case 2 | Faster than gpt-image-1 |
| black-forest-labs/flux-fill-pro | Fixed ~$0.05/exec | $0.05 | ~9s | Minimal — fixed-size inpainting | Inpainting, local replacement, content-aware fill | **Case 1, Case 3** | Good for production edit pipelines |
| black-forest-labs/flux-kontext-pro | ~$0.04/image | $0.04 | ~7s | Low sensitivity | Fast iterative editing with content preservation | Case 2, Case 3 | Good trade-off for interactive tools |
| black-forest-labs/flux-kontext-max | ~$0.08/image (premium) | $0.08 | N/A | N/A | Highest-fidelity editing, final-asset polishing | Case 2, Case 3 | Premium tier for quality |
| black-forest-labs/flux-kontext-dev | ~$0.025/image | $0.025 | N/A | N/A | Development, experimentation, low-cost testing | Case 2 (R&D), Case 3 (R&D) | Often non-commercial license |
| prunaai/flux-kontext-fast | ~$0.005/image | $0.005 | Sub-second to few seconds | Scales with resolution/steps | Real-time creative apps, low-latency web | Case 2 | Very cost-effective for prototyping |
| black-forest-labs/flux-2-flex | ~$0.06/image | $0.06 | ~13s | Scales with diffusion steps | Balanced quality/speed for production | Case 2, Case 3 | Tunable quality-speed trade-off |
| black-forest-labs/flux-2-dev | ~$0.025/image | $0.025 | N/A | N/A | Open-weight experimentation | Case 2 (R&D), Case 3 (R&D) | Self-host option possible |

### 5.5 Recommended provider selection (for PO review)

> These are starting-point recommendations. Final selection should be made by PO after benchmark validation.

| Pipeline Stage | Recommended Primary | Recommended Fallback | Rationale |
|:---|:---|:---|:---|
| Text / Multimodal LLM (Step 1–5) | To be benchmarked | To be benchmarked | Depends on quality/cost/latency trade-off per step |
| Image Search (Step 4) | To be benchmarked | To be benchmarked | Depends on coverage and rate limit requirements |
| Image Generation (Step 6) | To be benchmarked | To be benchmarked | Depends on logo quality and cost budget |
| Image Edit — Case 1 (FE Mask) | To be benchmarked | To be benchmarked | Must support mask-based inpainting |
| Image Edit — Case 2 (Minimal) | To be benchmarked | To be benchmarked | Best cost/latency ratio for prompt-only editing |
| Image Edit — Case 3 (Crop-guided) | To be benchmarked | To be benchmarked | Strong content preservation with backend mask generation |

### 5.6 Benchmark template

#### Dataset

| ID | Benchmark Result |
|:---|:---|
| 1 |  |

**Testcase:**

**Testcase explanation**

**Input**

| Input |  |
|:---|:---|
| Model / API |  |
| Output |  |

**Result**

| Result |  |
|:---|:---|
|  |  |

| ID | Benchmark Result |
|:---|:---|
| 2 |  |

**Testcase:**

**Testcase explanation**

**Input**

| Text Input |  |
|:---|:---|
| Image Input |  |
| Model / API |  |
| Output |  |

**Result**

| Result |  |
|:---|:---|
|  |  |

#### Benchmark notes
- Use the same source image set across all models for Image Edit benchmarks.
- Record prompt, resolution, latency, cost, and user feedback for each run.
- For Case 1, validate black-region preservation and white-region edit fidelity.
- For Case 3, store crop alignment diagnostics and backend-generated mask path.
- For Case 2, track layout drift and over-edit frequency due to implicit masking behavior.
- When a model is listed as Case 2 only, avoid using it for strict masked inpainting.
- For Text/Multimodal LLM benchmarks, measure extraction accuracy, structured output compliance, and latency.
- For Image Search API benchmarks, measure result relevance, fetchable image ratio, and rate limit headroom.

---

## 6. Data Schema and API Integration

### 6.1 Pydantic models (source_v2 schemas)

```python
# --- DAG ---
class PlanningMode(str, Enum):
    single_pass = "single_pass"
    iterative = "iterative"

class DAGNode(BaseModel):
    id: str                           # Unique node identifier
    tool: str                         # Registered tool name
    tool_input: dict[str, Any] = {}   # ${...} interpolation bindings
    deps: list[str] = []              # Dependency node ids

class DAGPlan(BaseModel):
    planning_mode: PlanningMode = PlanningMode.iterative
    nodes: list[DAGNode] = []
    edges: list[tuple[str, str]] = []  # Auto-derived from deps

# --- Runtime ---
class RuntimeState(BaseModel):
    input: dict[str, Any] = {}
    node_results: dict[str, ToolResult] = {}
    artifacts: dict[str, LargePayloadRef] = {}
    clarification_round: int = 0
    context_version: int = 0

# --- Tool IO ---
class ToolResult(BaseModel):
    node_id: str
    tool_name: str
    result: Any = None
    error: ToolError | None = None
    trace: dict[str, Any] = {}
    produced_at: float

class ToolError(BaseModel):
    code: str
    message: str

class LargePayloadRef(BaseModel):
    ref_id: str
    kind: ArtifactKind     # inline, file, object_store, vector_store
    preview: str | None
    uri_or_key: str

# --- Tool Context (for planner prompts) ---
class ToolContext(BaseModel):
    name: str
    description: str
    parameters: dict[str, Any] = {}
    output: dict[str, Any] = {}
```

### 6.2 Tool input/output schemas

```python
# IntentDetectTool (Step 1)
class IntentDetectInput(ToolInput):
    query: str

class IntentDetectOutput(ToolOutput):
    is_logo_intent: bool
    confidence: float
    reason: str

# InputExtractTool (Step 2)
class InputExtractInput(ToolInput):
    query: str
    references: list[dict] = []

class InputExtractOutput(ToolOutput):
    context: dict     # BrandContext fields
    confidence: float
    reason: str

# ClarificationGateTool (Step 3)
class ClarificationGateInput(ToolInput):
    context: dict = {}

class ClarificationGateOutput(ToolOutput):
    passed: bool
    missing_fields: list[str] = []

# ClarificationTool (Step 3)
class ClarificationInput(ToolInput):
    missing_fields: list[str] = []
    query: str
    current_context: dict = {}

class ClarificationOutput(ToolOutput):
    questions: list[dict] = []

# WebResearchTool (Step 4)
class WebResearchInput(ToolInput):
    brand_context: dict = {}
    requested_optional_fields: list[str] = []

class WebResearchOutput(ToolOutput):
    research_context: dict

# GuidelineGenerateTool (Step 5)
class GuidelineGenerateInput(ToolInput):
    brand_context: dict = {}
    research_context: dict = {}

class GuidelineGenerateOutput(ToolOutput):
    guidelines: list[dict] = []

# LogoGenerateTool (Step 6)
class LogoGenerateInput(ToolInput):
    task_id: str
    guidelines: list[dict] = []
    brand_name: str | None = None
    industry: str | None = None
    variation_count: int = 1    # [1, 4]

class LogoGenerateOutput(ToolOutput):
    options: list[dict] = []

# LogoEditTool (Step 7)
class LogoEditInput(ToolInput):
    image_url: str
    instruction: str
    session_id: str
    mask_image: str | None = None
    crop_image: str | None = None
    editing_case: str | None = None

class LogoEditOutput(ToolOutput):
    edited_image_url: str
    editing_case: str
    mask_used: bool
    trace: dict
```

### 6.3 Validation rules and merge precedence

- `query` must be non-empty after trim.
- Required-field gate requires both `brand_name` and `industry`.
- Clarification answer merge precedence: `answer fields > existing extract.result.context`.
- Supported clarification fields: `brand_name`, `industry`, `style_preference`, `color_preference`, `symbol_preference`, `typography_direction`.
- Empty string for optional scalar fields is normalized to `None`.
- `variation_count` defaults to 1 (configurable via `user_context`).
- Edit case auto-detection: mask → Case 1, crop → Case 3, neither → Case 2.

### 6.4 Endpoint mapping

```
POST /stream (task_type="logo_design")
  → Generate flow: intent → extract → gate → [clarification] → research → guideline → generate
  → Edit flow: edit (with selected_url + instruction + optional mask/crop)
```

Stream status progression — see Section 3.4.5.

### 6.5 Configuration

```python
class SourceV2Settings(BaseSettings):
    planner_framework: str = "async_genai"       # configurable LLM framework
    planner_model: str = "gemini-2.5-flash"      # configurable planner model
    planner_api_key: str | None = None
    planner_temperature: float = 0.0
    planner_repair_attempts: int = 1
    planner_use_llm: bool = True

    google_api_key: str | None = None
    gemini_text_model: str = "gemini-2.5-flash"  # configurable text model

    max_clarification_rounds: int = 2
    tool_timeout_seconds: float = 90.0
    retry_attempts: int = 1

    inline_payload_limit_chars: int = 4000
```

---

## 7. Risks and open issues

### 7.1 Latency

**Risk:** Web research + multimodal analysis can increase p95 latency for the generate flow.

**Mitigation:**
- Bounded query policy and fetchable-image filtering.
- Parallel guideline inference (`asyncio.gather`).
- DAG topology allows future parallelization of independent nodes.

### 7.2 Provider reliability

**Risk:** Provider internal errors, media fetch restrictions, or API unavailability.

**Mitigation:**
- Executor retry middleware (configurable `retry_attempts`).
- Timeout middleware (configurable `tool_timeout_seconds`).
- Explicit `ToolError` propagation with stage-specific error codes.
- Model fallback strategy per editing case (see Section 5.5).

### 7.3 Clarification loop quality

**Risk:** Ambiguous inputs can trigger repeated clarification turns.

**Mitigation:**
- Max clarification rounds enforced (`max_clarification_rounds = 2`).
- Targeted clarification questions from LLM with deterministic fallback.
- Session state reuse across clarification turns.

### 7.4 Edit quality

**Risk:** Over-editing outside target area (Case 2), mask quality issues (Case 1), crop-to-mask conversion errors (Case 3).

**Mitigation:**
- Model selection strategy per case (see Section 5.5).
- Preservation instruction injection for Case 2.
- Segmentation-based mask validation for Case 3.
- Trace metadata capture for quality diagnostics.

### 7.5 Planner reliability

**Risk:** LLM-based planner may produce malformed or semantically invalid DAG plans.

**Mitigation:**
- DAGValidator structural validation (cycle detection, dependency resolution).
- Semantic guard validation (required nodes, input path verification).
- Auto-repair attempt on malformed output.
- Deterministic template fallback when all LLM attempts fail.
- Convention enforcement layer (`_enforce_logo_conventions`).

### 7.6 Design Artifact Store

**Risk:** Current mock DB is in-memory and does not survive process restarts.

**Mitigation:**
- Treat as an artifact with clear read/write contracts.
- Design for migration to dedicated artifact/storage service.
- Version design artifacts to support audit trail.

### 7.7 Open technical decisions

- Segmentation model deployment strategy for Case 1 (FE ONNX) and Case 3 (BE inference).
- Default provider selection for each pipeline stage (PO decision after benchmarks).
- Multi-candidate ranking before edit output.
- Acceptable cost/request threshold for editing.
- Session store persistence strategy (current `dict` → Redis/DB).
- Design Artifact Store migration plan (current mock → dedicated service).
- Production BFF transport controls and stream resilience policy.
- Queue/service decoupling roadmap for heavy generation nodes.
- Cost tracking/reporting by task_id and session_id.
- Asset URL TTL and retention policies.
- Whether mask should be mandatory for small or dense typography edits.

---


