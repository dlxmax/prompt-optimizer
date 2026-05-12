# Gemma 4 fixes

Empirically verified 2026-05-12 on `gemma-4-31b-it`, `gemma-4-26b-a4b-it`, `gemini-3.1-flash-lite` via the Generative Language API.

## API changes (mechanical, ship first)

1. **Add `responseSchema` + `responseMimeType: "application/json"`** to every Gemma 4 call. Schema for single-string outputs:
   ```json
   {"type":"OBJECT","properties":{"output":{"type":"STRING"}},"required":["output"]}
   ```
   Bypasses thinking mode on Gemma 4. `finishReason=STOP`, `thought_chars=0`, MALFORMED rate 0%, wall-clock ~30-40× faster.

   **Exception: `gemma-4-26b-a4b-it`.** This model fails under `responseSchema` whenever an OBJECT has two or more unbounded free-text STRING properties: either deterministic bigram/trigram loops to `MAX_TOKENS` or degenerate empty `[]` output. See [`GEMMA4_26B_A4B_SCHEMA_RUNAWAY.md`](./GEMMA4_26B_A4B_SCHEMA_RUNAWAY.md). If 26b-a4b is in your fallback chain, use one of (verified 2026-05-12): (a) caller-side schema-skip guard on the model-name match for 26b-a4b, or (b) prompt-level bounding ("one short sentence") plus a worked stop-example on every unbounded STRING field. Per-field `ARRAY[STRING]` wrapping does NOT rescue this shape; the loop just migrates to a sibling STRING field. Schemas with exactly one unbounded STRING per OBJECT inside a top-level ARRAY[OBJECT] have held in production (e.g., `audit[].reason`); two or more unbounded STRINGs per OBJECT have not.

2. **Parse with `json.JSONDecoder().raw_decode()`, not `json.loads()`.** Gemini occasionally emits valid JSON followed by trailing text; strict `loads` raises.

3. **Do NOT set `thinkingConfig.thinkingBudget` on Gemma 4.** Returns HTTP 400 "Thinking budget is not supported for this model." It works on Gemini 2.5 Flash, not Gemma 4.

4. **`maxOutputTokens` is a safety ceiling, not a thinking cap.** Gemma 4 thinking expands to fill whatever budget is set (256 → ~300 thought tokens, 1024 → ~1150, 2048 → more). Use 256/512 for short outputs only after `responseSchema` is in place.

5. **Classify retries by signature:**
   - HTTP 5xx → fast exponential backoff, same params, max 4 attempts.
   - `MALFORMED_RESPONSE` (empty visible output, large `thought_chars`) → param changes (temp step-down 1.0 → 0.85 → 0.75), max 3 attempts.
   - Do not share one retry policy across both.

6. **Probe new API features with one HTTP request before recommending.** Documented ≠ works on this model.

## Prompt changes

Invoke the `prompt-optimizer` agent on each Gemma-facing prompt. Under `responseSchema`, negative-constraint-heavy scaffolds and in-range examples may no longer be load-bearing; A/B lean vs scaffolded prompts before locking in.

If the prompt routes to `gemma-4-26b-a4b-it` (directly or via fallback) and the OBJECT in the schema has two or more unbounded STRING properties, the optimizer should require one of: (a) caller-side schema-skip guard on the model-name match for 26b-a4b, or (b) explicit prompt-level bounding ("one short sentence") plus a worked stop-example on every unbounded STRING field. Do not recommend `ARRAY[STRING]` wrapping as a fix; it was empirically rejected 2026-05-12 (the loop migrates to whichever sibling unbounded STRING the model reaches first). Temperature step-down does not break the loop; the fix is structural.

## Verify

Sample N=12 calls after changes. Expect `finishReason=STOP`, `thought_chars=0`, median wall <5s, 100% schema-valid JSON via `raw_decode`. Non-zero MALFORMED or `thought_chars >0` means something didn't land.
