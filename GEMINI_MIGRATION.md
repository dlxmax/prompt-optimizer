# Gemini legacy-to-Interactions migration reference

<role>
Reference for the prompt-optimizer agent. Load once per prompt, on any
task, when the prompt under review, its call-site, or its examples
reference retired `generateContent` wiring, or when a Gemini prompt is
being upgraded across model generations.

For the mechanical migration itself — endpoint/SDK, schema location,
request shape, response parsing, tools-array shape, multi-turn history,
`store=false` behavior, and per-model upgrade checklists — invoke the
`gemini-interactions-api` skill; it fetches the current hosted docs and
stays accurate across model releases, which a hand-maintained file
cannot promise. This file covers only the migration facts that are
cross-family or otherwise outside that skill's Gemini-only scope. After
a prompt is migrated, this file is not needed again for it.
</role>

## 1. `tools` + `response_format` combination scope

Combined use is a Gemini 3-series-only preview. Gemma 4 and Gemini 2.5
cannot mix the two. If a 2.5 or Gemma 4 prompt wires both, recommend a
two-step pipeline (tools first, structured-output reduction second).

## 2. Gemma 4 schema-shape rules port unchanged

Gemma 4 schema-shape rules (`GEMMA4_API_BEST_PRACTICES.md` rules 2, 3,
16, 17) concern model behavior and JSON Schema shape, not which API
field carries the schema. They apply unchanged when the schema is wired
through `response_format.schema` on Interactions, whichever Gemini 3.x
model carries it.

## 3. Prefilled model-turn validation

Legacy `generateContent` / raw REST payloads that end `contents[]` on a
non-empty `model`-role turn (a common trick to suppress preambles or
force JSON formatting) now return an HTTP 400 error, effective with
`gemini-3.6-flash` and `gemini-3.5-flash-lite` and all Gemini releases
after them. Flag any prefilled trailing model turn as a migration
defect. Interactions equivalent: do not prefill a model turn at all; use
`system_instruction` to control output style, or `response_format` for
JSON formatting (exact wiring: `gemini-interactions-api` skill).

## Closing directive recap

Cross-family migration facts only. For everything else — endpoint/SDK
versions, schema location, request/response shape, tools-array shape,
multi-turn history, `store=false` behavior, and per-model upgrade
checklists (including moving to `gemini-3.6-flash` /
`gemini-3.5-flash-lite`) — invoke the `gemini-interactions-api` skill
instead of answering from this file or from memory.
