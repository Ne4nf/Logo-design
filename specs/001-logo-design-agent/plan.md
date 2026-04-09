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
| Name | Pricing | Average Cost | Average Latency (second) | Correlation between latency and output token | Recommend UseCase | Case Fit | Note |
|---|---|---|---|---|---|---|---|
| google/gemini-2.5-flash-image (Nano Banana) | $30 / 1M output tokens; each 1024x1024 image ~ 1,290 tokens (~$0.039/image) | $0.039 (1024px) | ~6s | Positive - latency grows with output token count | Low-cost bulk generation, rapid prototyping, high-throughput creation | Case 2 | Free tier exists with rate limits; some users report occasional resolution downscaling |
| google/gemini-3.1-flash-image-preview (Nano Banana 2) | ~$0.045-$0.151/image depending on resolution; 1024px around $0.067 | $0.067 (1024px) | 23-56s (avg ~37.6s) | Weak/unclear correlation in real-world tests | High-quality premium generation, larger-resolution marketing assets | Case 2 | Preview-phase variability and compute pressure can increase latency |
| google/gemini-3-pro-image-preview (Nano Banana Pro) | ~$0.02-$0.08/image | ~$0.05 (mid-tier) | 3-12s | Latency increases with higher resolution | Professional-grade quality, stronger text rendering, high-res brand graphics | Case 2 | Supports up to 4K-class outputs in provider docs |
| openai/gpt-image-1 | Tiered pricing: Low $0.011, Medium $0.042, High $0.167 per image | $0.042 (medium) | ~45-50s | Higher quality tiers usually increase latency | General-purpose generation/editing where flexibility matters | Case 2 | Token-based billing may apply in some API modes |
| openai/gpt-image-1.5 | Tiered pricing: Low $0.009-$0.052, Medium $0.034-$0.051, High $0.133-$0.200 | $0.034 (medium) | 15-45s | Latency increases with quality tier | Premium marketing edits, stronger prompt adherence, high-fidelity outputs | Case 2 | Commonly faster than gpt-image-1 with improved instruction following |
| black-forest-labs/flux-fill-pro | Fixed ~$0.05 per execution | $0.05/image | ~9s | Minimal - fixed-size inpainting workloads are relatively stable | Inpainting, local replacement, content-aware fill | Case 1, Case 3 | Good fit for production edit pipelines |
| black-forest-labs/flux-kontext-pro | ~$0.04/image (provider-level) | $0.04/image | ~7s | Low sensitivity to token-like factors; tuned for edit speed | Fast iterative editing with strong content preservation | Case 2, Case 3 | Good trade-off for interactive design tools |
| black-forest-labs/flux-kontext-max | ~$0.08/image (premium) | $0.08/image | Not publicly disclosed | N/A | Highest-fidelity editing, final-asset polishing | Case 2, Case 3 | Premium tier focused on quality over cost |
| black-forest-labs/flux-kontext-dev | ~$0.025/image (dev/open-weight tier) | $0.025/image | N/A (public data limited) | N/A | Development, experimentation, low-cost testing | Case 2 (R&D), Case 3 (R&D) | Often non-commercial or restricted license depending on channel |
| prunaai/flux-kontext-fast | ~$0.005/image (provider listing) | $0.005/image | Sub-second to few seconds (typical 1024px claims) | Latency usually scales with resolution/steps | Real-time creative apps, low-latency web experiences | Case 2 | Very cost-effective for interactive prototyping |
| black-forest-labs/flux-2-flex | ~$0.06/image | $0.06/image | ~13s | Scales with diffusion steps and resolution | Balanced quality/speed for production workflows | Case 2, Case 3 | Tunable quality-speed trade-off |
| black-forest-labs/flux-2-dev | ~$0.025/image | $0.025/image | N/A (public data limited) | N/A | Open-weight experimentation and custom training workflows | Case 2 (R&D), Case 3 (R&D) | Self-host option possible with licensing constraints |

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
