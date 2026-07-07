# Gemini legacy-to-Interactions migration reference

<role>
Reference for the prompt-optimizer agent. Load once per prompt, on any task, when the prompt under review, its call-site, or its examples reference retired `generateContent` wiring. The Interactions API is the sole recommended surface; every legacy form below is a migration defect to flag in Key Changes with its Interactions equivalent named. After a prompt is migrated, this file is not needed again for it.
</role>

## 1. Endpoint and SDK

| Legacy form (defect) | Interactions equivalent |
|---|---|
| `client.models.generate_content(...)` | `client.interactions.create(...)` |
| `:generateContent` / `:streamGenerateContent` paths | `v1beta/interactions` endpoint |
| `google-genai` unpinned or `< 2.3.0` | `google-genai >= 2.3.0` (Python) / `@google/genai >= 2.3.0` (JS) |

## 2. Schema location

`generationConfig.responseSchema` + `responseMimeType: "application/json"` moves to top-level `response_format: {type: "text", mime_type: "application/json", schema: {...}}`. Array form is accepted; the single-object form is the structured-output guide's pattern.

## 3. Request shape

`contents: [{role, parts: [{text}]}]` becomes `input: "..."` (string) or `input: [{type: "text", text}, {type: "image", mime_type, data}, ...]`. `systemInstruction.parts[].text` becomes the top-level `system_instruction` parameter.

## 4. Response parsing

`response.candidates[0].content.parts[*].text` and `parts[].thought == true` filtering are gone. Use `interaction.output_text` (joins trailing TextContent only; earlier text blocks separated by thought/image/function_call steps are dropped) for single-trailing-text, or iterate `interaction.steps[]` selecting `step.type == "model_output"` for interleaved outputs. Thinking: `step.type == "thought"`, walk `step.summary[]` (requires `generation_config.thinking_summaries: "auto"`; default off).

## 5. Tools-array shape

`tools: [{googleSearchRetrieval: {}}]` / `tools: [{google_search: {}}]` become `tools: [{type: "google_search"}]` (typed-string discriminator). Same for `url_context`, `code_execution`, `file_search`.

## 6. Multi-turn history

Replace caller-managed `contents[]` re-sends with `previous_interaction_id=<prev.id>` (default `store=true`). Passing both `previous_interaction_id` AND hand-rolled history in `input` double-counts; pick one.

## 7. `tools` + `response_format` combination scope

Combined use is a Gemini 3-series-only preview. Gemma 4 and Gemini 2.5 cannot mix the two. If a 2.5 or Gemma 4 prompt wires both, recommend a two-step pipeline (tools first, structured-output reduction second).

## 8. `store=false` lockout

`store=false` blocks `previous_interaction_id` chains AND `background=true`. Mixed with either, the second flag silently no-ops or errors. When PII is the driver, recommend `store=true` plus explicit `interactions.delete` cleanup.

## 9. Schema-shape rules port unchanged

Gemma 4 schema-shape rules (`GEMMA4_API_BEST_PRACTICES.md` rules 2, 3, 16, 17) concern model behavior and JSON Schema shape, not which API field carries the schema. They apply when the schema is wired through `response_format.schema` on Interactions.

## 10. Model-upgrade checklist (moving to 3.5 Flash)

Recommend in Key Changes when the target is being upgraded to `gemini-3.5-flash`:

- Update the model name (e.g., `gemini-3-flash-preview` becomes `gemini-3.5-flash`).
- Remove `temperature`, `top_p`, `top_k`.
- Replace `thinking_budget` (numeric) with `thinking_level` (string enum); verify the default `medium` fits the task.
- Add `id` and matching `name` to all `function_result` parts; return one response per call; move multimodal content INSIDE function responses; append inline instructions to the END of function-response text separated by two newlines.
- Test with thought preservation on; token usage increases per turn.
- Place the query at the end of long-context prompts; drop chain-of-thought scaffolding in favor of `thinking_level`.
- Update SDK to `google-genai` / `@google/genai` >= 2.3.0.
