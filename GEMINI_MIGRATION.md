# Gemini legacy-to-Interactions migration reference

<role>
Reference for prompt-optimizer. Load once per prompt, any task, when the
prompt, its call-site, or its examples reference retired `generateContent`
wiring, or when a Gemini prompt is upgraded across model generations.

Mechanical migration itself — endpoint/SDK, schema location, request shape,
response parsing, tools-array shape, multi-turn history, `store=false`,
per-model upgrade checklists — invoke the `gemini-interactions-api` skill: it
fetches current hosted docs and stays accurate across releases, which a
hand-maintained file cannot. This file carries only migration facts that are
cross-family or otherwise outside that skill's Gemini-only scope. Prompt
migrated → this file is done with it.
</role>

## 1. `tools` + `response_format` combination scope

Combined use = Gemini 3-series-only preview. Gemma 4 and Gemini 2.5 cannot mix
the two. A 2.5 or Gemma 4 prompt wiring both → recommend a two-step pipeline
(tools first, structured-output reduction second).

## 2. Gemma 4 schema-shape rules port unchanged

`GEMMA4_API_BEST_PRACTICES.md` rules 2, 3, 16, 17 concern model behavior and
JSON Schema shape, not which API field carries the schema. They apply unchanged
when the schema is wired through `response_format.schema` on Interactions,
whichever Gemini 3.x model carries it.

## 3. Prefilled model-turn validation

Legacy `generateContent` / raw REST payloads ending `contents[]` on a non-empty
`model`-role turn (common trick to suppress preambles or force JSON) now return
HTTP 400, effective with `gemini-3.6-flash` and `gemini-3.5-flash-lite` and
every Gemini release after. Flag any prefilled trailing model turn as a
migration defect. Interactions equivalent: no model-turn prefill at all — use
`system_instruction` for output style, `response_format` for JSON (exact
wiring: `gemini-interactions-api` skill).

## Closing directive recap

Cross-family migration facts only. Everything else — endpoint/SDK versions,
schema location, request/response shape, tools-array shape, multi-turn history,
`store=false`, per-model upgrade checklists (including moving to
`gemini-3.6-flash` / `gemini-3.5-flash-lite`) — invoke the
`gemini-interactions-api` skill rather than answering from this file or memory.
