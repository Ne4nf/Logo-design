# Image Editing Phase Template - Logo Design

## 0) Metadata
- Project:
- Owner:
- Date:
- Version:
- Scope: Logo editing workflow
- Status: Draft | In Review | Approved

---

## 1) Phase Objective
- Enable controlled edits on generated logos.
- Prioritize region accuracy, output consistency, and response speed.
- Capture measurable metrics for latency, cost, quality, and user satisfaction.

---

## 2) Three Editing Cases (Comparison Table)

| Case | Purpose | Frontend Input | Backend Handling | Output | Key Risks |
|---|---|---|---|---|---|
| Case 1: FE Mask + BE Inpainting | Precise local edit with clear protected area | 1) Source image, 2) Binary mask (white/black), 3) Prompt | Inpainting model edits white region and preserves black region; blends edges | Edited image + trace metadata | Wrong mask quality, boundary artifacts |
| Case 2: Minimal Edit (No Mask) | Fast editing with lowest UI complexity | 1) Source image, 2) Prompt | Edit/generation model receives image+prompt only; no hard mask constraint | Edited image + trace metadata | Over-editing outside target area |
| Case 3: Crop-guided Edit (Mask generated in BE) | Keep FE simple while still using mask constraints | 1) Source image, 2) Bounding-box crop image, 3) Prompt | BE derives mask from crop image against source, then runs inpainting with source+mask+prompt | Edited image + generated mask + trace metadata | Crop too loose/tight, mask derivation errors |

## 3) Case Details

### 3.1 Case 1 - FE Mask + BE Inpainting (Step-by-step)

Step 1: Frontend (Data Initialization)
1. User clicks a detail on the generated logo.
2. FE runs SAM in background and creates Mask_Image (white/black).
3. FE setup note:
- Install once in web-ui: npm install onnxruntime-web.
- Load SAM ONNX weights when Edit page opens (or lazy-load on first click).
- Inference runs directly in browser (WebAssembly/WebGPU path), not on backend.
4. User enters edit instruction, for example: "Turn this shape into a fire dragon".
5. FE calls POST /edit with 3 payloads:
- Original_Image (base64 or URL)
- Mask_Image (base64 or URL)
- Raw_Prompt

Step 2: Backend (Inpainting Execution)
1. BE calls an image edit/inpainting API.
2. Request payload:
- image: Original_Image
- mask: Mask_Image
- prompt: Raw_Prompt
3. Model behavior:
- Keep 100% of black-mask pixels unchanged.
- Regenerate white-mask region using diffusion/inpainting process.
- Auto-handle lighting, shading, and mask boundary blending.

### 3.2 Case 2 - Minimal Edit (1 image + 1 prompt)

Step 1: Frontend
1. FE sends only Original_Image and Raw_Prompt.

Step 2: Backend
1. BE calls image edit/generation model with image+prompt.
2. Recommended strong models for this mode:
- Gemini 2.5 Flash Image / Gemini 3 Flash Image (Nano Banana 2)
- OpenAI gpt-image-1.5 (or best available image-edit model)
3. Why no explicit mask is needed (short version):
- The model understands the prompt semantically (for example, identifies text regions).
- Internal attention acts like an implicit mask (not exposed to FE/BE).
- Diffusion updates target regions while attempting to preserve non-target content.
4. BE injects preservation instruction (keep layout/style where possible).
5. Return edited image and trace metadata.

### 3.3 Case 3 - Source + Crop + Prompt (Mask generated in BE)

Step 1: Frontend
1. FE sends 3 inputs:
- Original_Image
- Crop_Image (bounding-box crop of target region)
- Raw_Prompt

Step 2: Backend
1. Locate crop region against original image.
2. Run SAM (or another segmenter) in backend to convert crop region into a binary mask.
3. Run inpainting with `Original_Image` + generated mask + `Raw_Prompt`.
4. Return edited image, optional debug mask, and trace metadata.

Implementation note:
- Yes, Case 3 is similar to Case 1, but FE does not send mask.
- The extra backend step is SAM-based mask generation/refinement from crop input.

---

## 2) Case 1 - Masked Inpainting Pipeline
### Stage 1 - Frontend Mask Creation (Object Selection)

#### 2.1 Purpose
Help users select the exact region to edit without heavy manual painting.

#### 2.2 Model
- Segment Anything Model (SAM) by Meta.
- Browser-optimized variants: MobileSAM or SAM-b.
- Runtime recommendation: ONNX + WebAssembly via onnxruntime-web.

#### 2.3 System Handling
1. Background preload: load SAM when Edit view opens.
2. Point capture: when user clicks on the logo, capture click coordinates $(X, Y)$.
3. Mask inference: feed $(X, Y)$ into SAM to infer object boundaries.
4. Binary mask output (same size as source image):
- White: editable region.
- Black: protected region.
5. Fallback tool: provide Brush/Eraser on HTML5 Canvas so users can refine the mask manually.

#### 2.4 Input / Output
- Input:
- Source image
- Click points or brush strokes
- Output:
- Binary mask PNG (white editable area, black preserved area)

#### 2.5 Acceptance Criteria
- Mask IoU against expected region >= [ ]
- Mask generation latency <= [ ] ms
- Brush fallback works on desktop and mobile

### Stage 2 - Backend Inpainting (3-part Input)

#### 2.6 Purpose
Regenerate only the selected region while preserving everything else.

#### 2.7 Input
1. Source image
2. Mask image (binary white/black)
3. Text prompt

#### 2.8 Model Options
- Open-source (self-hosted):
- SDXL Inpainting
- FLUX.1 Fill
- Commercial APIs:
- Google Imagen Inpainting
- OpenAI image edit endpoint (model support depends on endpoint)

#### 2.9 System Handling
1. Frontend sends source image, mask image, and prompt to backend.
2. Backend calls selected inpainting model/provider.
3. Masking constraints:
- Black region: preserve original pixels.
- White region: regenerate content from prompt.
4. Seamless blending on mask edges to match lighting, shadows, and texture.

#### 2.10 Output
- Edited image
- Trace metadata: model, latency, cost estimate, resolution, request id

#### 2.11 Acceptance Criteria
- Pixel drift outside mask <= [ ]%
- Change quality inside mask meets UX threshold >= [ ]
- p95 latency <= [ ] s

---

## 3) Case 2 - Minimal Prompt Edit (1 Image + 1 Prompt)

#### 3.1 Purpose
Fast edit flow when user does not need explicit masking.

#### 3.2 Input
1. Source image
2. Text prompt

#### 3.3 System Handling
1. Send image + prompt to edit/generation model.
2. Add instruction to preserve layout and modify only requested details.
3. Return edited image and metadata.

#### 3.4 Risks
- Broader changes may happen without mask constraints.
- Often requires multiple candidates and ranking.

#### 3.5 Acceptance Criteria
- Layout preservation >= [ ]
- First-pass user acceptance rate >= [ ]

---

## 4) Case 3 - Bounding Box Edit (Original Image + Region Box + Prompt)

#### 4.1 Purpose
Simplify user interaction by selecting a rectangular region instead of full mask painting.

#### 4.2 Input
1. Original image
2. Bounding-box image or box coordinates
3. Prompt

#### 4.3 System Handling
1. Convert bounding box to temporary mask (hard rectangle or soft edge).
2. Optionally refine box-to-mask using SAM or GrabCut.
3. Run inpainting on the masked region.

#### 4.4 Technical Notes
- Large bounding boxes reduce edit precision.
- Optional feather edge [ ] px usually improves blending quality.

---

## 5) Benchmark Framework (Latency, Cost, Quality, UX)

### 5.1 Benchmark Goals
- Compare model behavior for logo-editing use cases.
- Choose default model per edit type and SLA target.

### 5.2 Benchmark Matrix
| Provider | Model | Edit Mode | Main Edit Type | Input Type | Input Resolution | Output Resolution | Latency p50 (ms) | Latency p95 (ms) | Cost/Request (USD) | Success Rate (%) | User Rating (1-5) | Notes |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---|
| OpenAI | gpt-image-1 | no-mask | text recolor | image+prompt |  |  |  |  |  |  |  |  |
| OpenAI | gpt-image-1.5 | no-mask | text recolor | image+prompt |  |  |  |  |  |  |  |  |
| Provider X | Inpaint Model Y | mask | local object replace | image+mask+prompt |  |  |  |  |  |  |  |  |

### 5.3 Tracing Schema Per Request
- request_id
- timestamp_utc
- provider
- model
- edit_mode: mask | no-mask | bbox
- input_resolution
- output_resolution
- latency_ms
- token_or_compute_usage
- estimated_cost_usd
- success
- error_type
- user_feedback_score
- user_feedback_comment

### 5.4 Quality Evaluation Buckets
- Preservation score: how well layout and brand identity are kept.
- Edit fidelity: how accurately output follows prompt in target region.
- Typography integrity: readability and correctness of edited text.
- Seam quality: visual continuity at edited boundaries.

### 5.5 Quick Rubric
| Metric | Definition | Scale | Target |
|---|---|---|---|
| Preservation | Keep non-edited content consistent | 1-5 | >= 4 |
| Prompt fidelity | Match requested change | 1-5 | >= 4 |
| Visual quality | Sharpness, artifacts, color quality | 1-5 | >= 4 |
| Brand consistency | Keep logo style coherent | 1-5 | >= 4 |

---

## 6) Rollout Recommendation
- Phase 1: Ship image+prompt flow to collect fast feedback.
- Phase 2: Add mask-assisted inpainting for high-precision edits.
- Phase 3: Optimize bbox-to-mask conversion and model auto-routing.

---

## 7) Decision Log
| Date | Decision | Owner | Reason | Impact |
|---|---|---|---|---|
|  |  |  |  |  |

---

## 8) Open Questions
- Which model should be default for text edits in logos?
- Do we need multi-candidate ranking before final output?
- What is acceptable cost/request threshold?
- Should mask be mandatory for small or dense typography?
