# Gemini legacy-to-Interactions migration reference

<role>
Reference for prompt-optimizer. Load once per prompt, any task, when the
prompt, its call-site, or its examples reference retired `generateContent`
wiring, or when a Gemini prompt is upgraded across model generations.

Mechanical migration (endpoint/SDK, schema location, request shape, response
parsing, tools-array shape, multi-turn history, `store=false`, per-model
upgrade checklists): invoke the `gemini-interactions-api` skill, which tracks
current hosted docs as a hand-maintained file cannot. This file carries only
migration facts that are cross-family or outside that skill's Gemini-only scope.
</role>

## 1. `tools` + `response_format` combination scope

Combined use = Gemini 3-series-only preview as last verified. Gemma 4 and
Gemini 2.5 cannot mix the two. Preview scope moves: confirm current
combined-use support through the `gemini-interactions-api` skill before
recommending the split, and name that check in Key Changes. A 2.5 or Gemma 4
prompt wiring both -> recommend a two-step pipeline (tools first,
structured-output reduction second).

## 2. Gemma 4 schema-shape rules survive a surface change, not a family change

`GEMMA4_API_BEST_PRACTICES.md` rules 2, 3, 16, 17 concern model behavior and
JSON Schema shape, not which API field carries the schema. They hold unchanged
when the SAME Gemma 4 model's schema moves to `response_format.schema` on
Interactions. They do not transfer to a Gemini 3.x model: all four are
`gemma-4-31b-it` probe records, and rule 3's property-order effect is
Gemma-empirical. Gemma 4 prompt
retargeted at Gemini 3.x -> mark all four unverified there in Key Changes. That
file is not loaded on a Gemini target: load it before citing any of the four;
load fails -> report and stop that path.

## 3. Prefilled model-turn validation

Legacy `generateContent` / raw REST payloads ending `contents[]` on a non-empty
`model`-role turn (preamble suppression or JSON forcing) return HTTP 400 as of
`gemini-3.6-flash` and `gemini-3.5-flash-lite` and every Gemini release after.
Flag any prefilled trailing model turn as a migration defect. Interactions
equivalent: no model-turn prefill at all. Use `system_instruction` for output
style, `response_format` for JSON (exact wiring: `gemini-interactions-api`
skill).

## 4. `thinking_level` values shrink across generations

A level valid on the source model can be absent on the target and fails hard,
HTTP 400 `invalid_request` naming the allowed set, never a silent clamp to the
nearest level. Probe-confirmed: `minimal` is rejected by `gemini-3.7-flash`
while `gemini-3.6-flash`, `gemini-3.5-flash`, and `gemini-3.5-flash-lite`
accept it, so the enum narrowed rather than grew. Any generation move carrying
a `thinking_level` in the prompt, call-site, or examples → re-read the target's
allowed set through the `gemini-interactions-api` skill and flag the carried
value in Key Changes. Never hand-carry the value, and never store the table
here: it is per-model and it moves. A prompt whose behavior depends on the
bottom level (high-volume extraction, routing, classification) may have no
equivalent floor on the target: say so rather than substituting the next level
up silently, since that changes cost and latency.

## Closing directive recap

Cross-family migration facts only. Everything else, including per-model upgrade
checklists, whatever the target generation: invoke
the `gemini-interactions-api` skill, never this file or memory.
