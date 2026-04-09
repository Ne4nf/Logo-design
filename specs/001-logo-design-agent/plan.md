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

## 5) Image Models Benchmark

### 5.1 Image Models
| Name | Latest Version | Pricing | Average Cost | Average Latency (second) | Correlation between latency and output token | Recommend UseCase | Context window | Note |
|---|---|---|---|---|---|---|---|---|
| OpenAI gpt-image-1 |  |  |  |  |  | Case 2 - minimal edit |  |  |
| OpenAI gpt-image-1.5 |  |  |  |  |  | Case 2 - minimal edit |  |  |
| OpenAI / other inpaint model |  |  |  |  |  | Case 1 / Case 3 - masked edit |  |  |

### 5.2 Image Models Benchmark
#### Dataset

#### Dataset Overview

| ID | Image Model Benchmark Result |
|---|---|
| 1 |  |

**Testcase:**

**Testcase explanation**

**Input**

| Input |  |
|---|---|
| Model |  |
| Output |  |

**Result**

| Result |  |
|---|---|
|  |  |

| ID | Image Model Benchmark Result |
|---|---|
| 2 |  |

**Testcase:**

**Testcase explanation**

**Input**

| Text Input |  |
|---|---|
| Image Input |  |
| Model |  |
| Output |  |

**Result**

| Result |  |
|---|---|
|  |  |

### Benchmark Note
- Use the same source image set across all models.
- Record prompt, resolution, latency, and user feedback for each run.
- For Case 1 and Case 3, store the generated mask path as trace data.
- For Case 2, note any unexpected layout drift or over-editing.


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
