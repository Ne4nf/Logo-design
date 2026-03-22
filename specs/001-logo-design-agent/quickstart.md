# Quickstart: AI Logo Design Agent (POC Phase 1)

**Last Updated**: 2026-03-22

This guide runs the simplified 8-step POC and validates baseline quality gates.

## Prerequisites

- Python 3.11+
- Node.js 18+
- Docker
- Git

## 1) Setup

### 1.1 Checkout feature branch

```bash
git checkout 001-logo-design-agent
```

### 1.2 Python environment

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

On Windows PowerShell:

```powershell
.venv\Scripts\Activate.ps1
```

### 1.3 Environment variables

Create .env in repository root:

```bash
AI_HUB_SDK_SERVICE_NAME=logo-design-agent
AI_HUB_SDK_TASK_DIR=./backend/src/workers

AI_HUB_SDK_REDIS_HOST=localhost
AI_HUB_SDK_REDIS_PORT=6379
AI_HUB_SDK_DB_TTL=3600

IMAGE_MODEL_PROVIDER=openai
OPENAI_API_KEY=replace-me

LANGFUSE_PUBLIC_KEY=replace-me
LANGFUSE_SECRET_KEY=replace-me
LANGFUSE_HOST=https://cloud.langfuse.com
```

### 1.4 Start Redis

```bash
docker run -d --name logo-redis -p 6379:6379 redis:7-alpine
```

## 2) Generate protobuf stubs

```bash
python -m grpc_tools.protoc \
  -I specs/001-logo-design-agent/contracts \
  --python_out=backend/src/gen \
  --grpc_python_out=backend/src/gen \
  specs/001-logo-design-agent/contracts/agent.proto \
  specs/001-logo-design-agent/contracts/worker.proto
```

## 3) Run services

### 3.1 Communication service

```bash
ai-hub-sdk communication --tasks backend/src/workers
```

### 3.2 Worker service

```bash
ai-hub-sdk worker --tasks backend/src/workers
```

### 3.3 API service

```bash
uvicorn backend.src.api.main:app --reload --host 0.0.0.0 --port 8000
```

## 4) Contract-first quality gate

Run these before implementation-heavy work:

```bash
pytest tests/contract -v
pytest tests/integration -v -k "logo or session"
```

Expected: tests are present and executable; during Red phase they may fail by design.

## 5) POC smoke flow

### Start session

```bash
curl -X POST http://localhost:8000/api/logo/sessions/s1/start \
  -H "Content-Type: application/json" \
  -d '{"user_prompt":"Create a minimalist logo for NovaAI, tech startup"}'
```

### Select logo

```bash
curl -X POST http://localhost:8000/api/logo/sessions/s1/select \
  -H "Content-Type: application/json" \
  -d '{"logo_id":"logo-1"}'
```

### Edit selected logo

```bash
curl -X POST http://localhost:8000/api/logo/sessions/s1/edit \
  -H "Content-Type: application/json" \
  -d '{"selected_logo_id":"logo-1","edit_prompt":"Change icon color to blue"}'
```

## 6) MCP and schema validation checks

- Verify all external tool calls emit structured input/output envelopes.
- Verify error responses include explicit code/message and retry suggestions.
- Verify malformed payloads are rejected by schema validation.

Suggested command set:

```bash
pytest tests/contract -v -k "schema or mcp"
```

## 7) Performance and reliability checks

Targets:

- p95 first reasoning chunk <= 1.5s
- p95 guideline + logos completion <= 25s
- failure response <= 3s

Suggested checks:

```bash
pytest tests/integration -v -k "latency or timeout or failure"
```

## 8) Done criteria for local validation

- Reasoning blocks stream before final generation output.
- Guideline appears before logo options.
- Exactly 3-4 logo options returned.
- Each returned logo is at least 1024x1024 and passes visual checks (single primary mark, no unreadable text artifact, no severe pixelation at 200% zoom, guideline consistency visible).
- Selection plus prompt edit returns regenerated logo and edit summary.
- Skip/default path emits explicit assumptions; repeated runs with same normalized skipped input keep assumption set and order stable.
- Error responses are transparent and actionable.
- Trace spans exist for analyze, reasoning, generate, select, and edit.

## 9) Smoke Validation Notes (2026-03-22)

Executed on local Windows workspace using TestClient-based API flow validation:

```bash
C:/Python314/python.exe -m pytest \
  tests/integration/test_us1_frontend_page.py \
  tests/integration/test_us2_frontend_edit_loop.py \
  tests/integration/test_us3_reasoning_visibility_gate.py \
  tests/integration/test_error_mapping.py \
  tests/integration/test_observability_spans.py \
  tests/integration/test_performance_slo.py \
  tests/contract/test_scope_guardrails.py -q
```

Observed result:

- `13 passed in 0.99s`

What this confirms:

- End-to-end US1->US2->US3 flow is reproducible in local API smoke path.
- Fail-fast error mapping and retry guidance are present on failure paths.
- Trace spans are emitted and correlated by session trace_id.
- p95 smoke checks satisfy local POC targets for first reasoning chunk and generation completion.
- Deferred feature guardrails remain enforced for Phase 1 scope.

Known limitations for this smoke mode:

- Validation uses in-process FastAPI TestClient, not external deployed worker queue.
- External provider calls are mocked/simulated in current POC services.
- Langfuse/OpenTelemetry backend export is represented by local trace collector behavior in this branch.
