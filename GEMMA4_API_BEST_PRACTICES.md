# Gemma 4 API best practices

Authoritative reference for the Generative Language REST API when targeting
`gemma-4-31b-it` and `gemma-4-26b-a4b-it`. Probe-verified May 6 and May 12,
2026. Scope: API call mechanics (request shape, parsing, retry, schema
constraints). For prompt-text guidance, use the `prompt-optimizer` agent
with `Target model: Gemma 4` declared; this file is the reference the
agent reads to apply that target.

> **API surface note (June 2026).** All probe-verified rules in sections 1
> through 14 below are scoped to the legacy `:generateContent` endpoint
> (`generativelanguage.googleapis.com/v1beta/models/<model>:generateContent`).
> Google declared the new **Interactions API**
> (`generativelanguage.googleapis.com/v1beta/interactions`, accessed via
> `client.interactions.create(...)` in `google-genai >= 2.3.0`) generally
> available in June 2026 and lists both `gemma-4-31b-it` and
> `gemma-4-26b-a4b-it` as supported models. `generateContent` "remains fully
> supported" per the GA announcement, so these rules do not lapse — but the
> Interactions API moves schema to top-level `response_format` instead of
> `generationConfig.responseSchema`, returns a `steps[]` timeline instead of
> `candidates[0].content.parts[]`, and exposes `previous_interaction_id` /
> `store` / `background`. See section 15 for the surface-mapping rules; the
> behavioral findings in sections 1-14 have NOT been re-probed on the new
> surface, and rule 14's `parts[].thought = true` filter does not have a
> verified analogue on Interactions yet.

## 1. Use `responseSchema` for any code-parsed output

Set `generationConfig.responseSchema` plus `responseMimeType:
"application/json"` on every Gemma 4 call whose output is parsed by code.
This is the **primary lever**, not a Tier 2 option.

- Suppresses thinking mode: `finishReason=STOP`, `thoughtsTokenCount=0`,
  MALFORMED rate 0%.
- ~30 to 40x wall-clock speedup on short outputs (May 12 benchmark:
  ~67s/call median down to 1 to 2s/call).
- The only reliable thinking-suppression mechanism on this endpoint.
  `thinkingLevel: "low"`/`"off"` and `thinkingBudget: 0` return HTTP 400;
  `thinkingLevel: "high"` is a silent no-op.

Minimal schema for a single-string output:
```json
{"type":"OBJECT","properties":{"output":{"type":"STRING"}},"required":["output"]}
```

If reasoning is wanted, request a bounded `<reasoning>` field inside the
schema rather than relying on `thought: true` parts.

## 2. `26b-a4b` constraint: at most one unbounded STRING per OBJECT

`gemma-4-26b-a4b-it` fails under `responseSchema` whenever an OBJECT has
two or more unbounded free-text STRING properties. Failure modes split
between deterministic bigram/trigram loops to `MAX_TOKENS` (e.g.,
`-classification-classification-...`, `0.0.0.0.0...`) and degenerate
empty `" [] ```"` output. Same schema passes cleanly on `gemma-4-31b-it`.

**Per-field `ARRAY[STRING]` wrapping does NOT rescue this.** Probe-tested
May 12, 2026: wrapping the long STRING moves the loop to a sibling
unbounded STRING; wrapping all of them shifts to HTTP 500 / empty array.

**Verified workarounds when 26b-a4b is in the fallback chain:**
1. **Caller-side `responseSchema` skip** on the model-name match for
   `26b-a4b`. The model then emits free-form JSON inside the prompt's
   format scaffold, which it terminates correctly.
2. **Prompt-level bounding plus a worked stop-example** on every
   unbounded STRING field ("one short sentence; e.g., ..."). The 31b
   path can self-terminate without explicit bounding; 26b-a4b cannot.

**Safe schema shape on 26b-a4b:** exactly one unbounded STRING per OBJECT
inside a top-level `ARRAY[OBJECT]` container (the `audit[].reason`
pattern) has held in production. Enum-bounded STRINGs, MM:SS-bounded
STRINGs, INTEGER, and BOOLEAN are unaffected.

Temperature step-down does not break this loop; the fix is structural.

## 3. Property order in `responseSchema` controls generation order

The order in which fields appear inside an OBJECT's `properties` dict
determines the order Gemma 4 emits them in the response. Place any
`reasoning` STRING field BEFORE the `verdict` enum it justifies, and
the model fills `reasoning` first, then commits to `verdict`, then (if
present) writes a short `reason` tag. This makes the verdict an output
of the reasoning rather than a post-hoc justification, and materially
shrinks per-item output length: observed ~1.8k chars per item dropping
to ~250 chars under this change alone on a warmup validator.

The corresponding anti-pattern is `verdict, reasoning`: the model locks
the verdict on the first token of the field, then inflates the
following STRING to justify it. Schema-level length caps in the field
`description` ("max 10 words") are not strongly enforced once the
verdict has committed.

**Application:**
- For judge or audit schemas, order properties as
  `index, reasoning, verdict, reason` (or the equivalent for your
  decision field). Define the reasoning STRING first.
- Keep `verdict` as a tight `enum` (e.g., `KEEP`/`DROP`) so it parses
  cleanly once committed.
- Keep `reasoning` and `reason` separate when both an audit trail and a
  short downstream tag are needed; otherwise collapse into a single
  length-capped `reasoning` field.
- This also interacts with rule 2 on `26b-a4b`: each OBJECT still gets
  at most one unbounded STRING. A `reasoning` STRING placed first
  consumes that one slot, so any sibling `reason` should be enum-bounded
  or length-capped via a stop-example.
- **Narrow schemas only.** Rule 4 overrides this pattern when the schema
  already has >=4 mandatory nested OBJECTs: on `31b`, the reasoning
  STRING crashes the request entirely. Move the reasoning surface to
  prompt-level prose or Python-side checks when the schema is wide.

**Caveat:** Property-order honouring is empirical, not documented.
Defensive practice is belt-and-braces: order the `properties` dict in
the desired generation order **and** add an explicit prompt instruction
("fill `reasoning` first, then commit `verdict`"). If a future Gemma 4
update weakens the order behavior, the prompt instruction still holds.

## 4. Wide schemas reject a top-level reasoning STRING on 31b

`gemma-4-31b-it` reliably crashes (alternating HTTP 400 INVALID_ARGUMENT
and 500 INTERNAL, 0/4 success) when a `responseSchema` combines a
top-level free-text `reasoning` STRING with many mandatory nested
OBJECTs. Empirical bisect May 13, 2026 on a forensic signal schema at
T=0.5: removing the reasoning STRING brought success to 4/4 on the same
schema; removing the evidence OBJECTs while keeping the reasoning
STRING left success at 2/4 (general backend baseline). The crash is
schema-specific, not backend flake.

The mechanism appears to be response-budget overload: each mandatory
evidence OBJECT must be emitted with default values even when its
matching signal does not trigger, and a prose-populated STRING on top
pushes the response past an internal Gemma 4 limit, producing malformed
output that the upstream validator rejects.

**Threshold:** observed crash at 5 mandatory evidence OBJECTs plus 1
reasoning STRING. Prudent safety margin: do not add a top-level
reasoning STRING when the schema already has >=4 mandatory nested
OBJECTs with multiple inner properties each. Schemas with <=3 nested
OBJECTs (e.g., 3 `ARRAY[OBJECT]`s plus 1 nullable OBJECT) have carried
a single bounded reasoning STRING without issue in production.

**Workarounds when reasoning is wanted on a wide schema:**
- Move reasoning to prompt-level prose instructions ahead of the JSON
  output (the model can still self-audit; the audit just does not
  appear in the parsed payload).
- Move reasoning to Python-side deterministic checks after parsing.
- Split into two calls: a narrow reasoning call that returns the
  reasoning STRING, then a wide structured-output call that returns
  the evidence OBJECTs.

**Bisect, do not retry.** When a schema-bearing call returns alternating
400/500, the prior probability splits ~50/50 between backend flake and
schema rejection. Four schema variants x four attempts each (16 calls,
~5 minutes) make the answer obvious. Concluding "API instability"
without the comparative test wastes the same retry budget over and
over.

**Interaction with rule 3:** rule 3's reason-before-commit pattern
requires a reasoning STRING in the schema. That pattern only applies
to narrow schemas (<4 mandatory nested OBJECTs); for wide schemas use
the workarounds above.

## 5. Parse with `json.JSONDecoder().raw_decode()`, not `json.loads()`

Even with `responseSchema`, Gemma 4 occasionally emits valid JSON
followed by trailing text (~1 in 12 calls observed). Strict `json.loads`
raises; `raw_decode` parses the first valid object and ignores the rest.

```python
parsed, _ = json.JSONDecoder().raw_decode(raw_text)
```

## 6. Do not set `thinkingConfig.thinkingBudget` on Gemma 4

Returns HTTP 400 `"Thinking budget is not supported for this model."`
This parameter works on Gemini 2.5 Flash, not on Gemma 4. Cross-family
code must branch on model name.

## 7. `maxOutputTokens` is a safety ceiling, not a thinking cap

Gemma 4 thinking expands to fill whatever budget is set (256 cap → ~300
thinking tokens; 1024 cap → ~1150 overflowing the cap; 2048 cap → more).
Lowering the cap converts `MALFORMED_RESPONSE` (long socket timeout,
empty visible output) into `MAX_TOKENS` (fast fail), which is a cheaper
failure mode, but it does not raise success rate. The actual
thinking-suppression lever is `responseSchema` (rule 1). Set
`maxOutputTokens` generously when `responseSchema` is in use.

## 8. Classify retries by failure signature

Do not share one retry policy across these classes:

- **HTTP 5xx (500/503 INTERNAL)** → fast exponential backoff, same
  parameters, max 4 attempts. Baseline transient rate ~20%.
- **HTTP 429 RATE_LIMIT_EXCEEDED** → read the response body before
  routing. Substring-check `error.details[].violations[].quotaId` for
  `"PerDay"`: present means RPD (hard exhaustion) and the chain should
  advance to the next model permanently; absent means RPM (transient,
  ~60s window) and the retry stays on the same model with backoff.
  Status code alone does not distinguish the two. Free Gemma 4 31b is
  15 RPM, so a naive "429 means exhausted, advance the chain" handler
  will permanently knock the model out after a 60s burst; the standard
  1s + 10s + 30s overload schedule reaches the RPM clear window
  naturally.
- **`MALFORMED_RESPONSE`** (empty visible output with large
  `thought_chars`) → parameter changes (temperature step-down
  1.0 → 0.85 → 0.75, or enable `responseSchema` if not already on),
  max 3 attempts. Same call repeated will fail the same way.
- **`MAX_TOKENS` with degenerate output on 26b-a4b** → structural fix
  per rule 2, not a retry. Repeating the call wastes budget.
- **Alternating 400/500 on a schema-bearing call** → suspect rule 4
  (wide-schema reasoning STRING overload on 31b). Bisect the schema
  before exhausting retries.

## 9. Schema-shape patterns for batch JSON output

When the prompt produces a fixed JSON schema and code parses the result,
two structural patterns matter beyond `responseSchema`:

**A. Lead with a literal JSON skeleton.** Place an `<output_shape>` block
at the very top of the prompt showing the exact keys and value-object
shape this call requires. Schema buried late produces shape drift on
Gemma 4 (observed: bare-list output, missing top-level keys in batch
grading). Build the skeleton from the call's actual inputs when keys
vary across batches.

**B. Emit the full schema spec exactly once.** Do not restate the
field-by-field contract at both start and end of the prompt: on Gemma 4
this triggers a restart-loop bug (`{Q31: {{Q31: {...`). A brief shape
echo or "do not restart the object" guard at the end is fine; full
re-specification is what backfires. This is a Gemma 4-specific exception
to the universal start-and-end repetition rule.

## 10. Use T=1.0, top_p=0.95, top_k=64; do not use T=0

T=0 is not recommended on Gemma 4. The May 12 benchmark used T=1.0
throughout. Google's May 5, 2026 model card refresh documents the full
recommended sampling configuration: `temperature=1.0`, `top_p=0.95`,
`top_k=64`, applied uniformly across all Gemma 4 sizes and all use cases
(including judge calls). Pass all three when constructing
`generationConfig`; the earlier guidance to set `T=1.0` only is
incomplete.

## 11. Probe before recommending

Google's documentation does not always reflect Gemma 4 behavior
(`thinkingBudget` is documented for the Gemini 2.5 family but returns
400 on Gemma 4; `responseSchema` documentation is ambiguous but works
perfectly on 31b and works conditionally on 26b-a4b per rule 2).

One HTTP probe distinguishes "feature documented" from "feature works on
this model" and is free. If a recommendation depends on an API feature
that has not been probed against the target variant, note that in the
call site's deployment checklist.

## 12. Tool-calling: avoid 26b-a4b

Known double tool-call bug on 26b-a4b. Both variants behave identically
for thinking control and for single-STRING `responseSchema` mechanics,
but they diverge on tool-calling and on multi-STRING schemas (rule 2).

## 13. Do not place `<|think|>` in `systemInstruction`

It is a no-op and elevates the transient 500 rate. Similarly,
`<thinking>...</thinking>` XML scaffolds add prompt tokens with no
behavior change. Remove them from optimized prompts.

**Surface scope.** Google's April 20, 2026 chat-template doc states that
`<|think|>` in the system instruction enables thinking on Gemma 4. That
guidance applies to the chat-template surface (HuggingFace Transformers,
llama.cpp, MLX, Unsloth), where `apply_chat_template(messages,
enable_thinking=True)` emits the actual special-token id into `input_ids`.
On the Generative Language REST API surface, `systemInstruction.parts[].text`
is plain text and the tokenizer does not register `"<|think|>"` as a
plain-text special-token mapping; the string tokenizes as ordinary BPE
pieces. The two surfaces are not equivalent. This rule is REST-API-scoped
and stands; deployers using local chat-template paths should follow
Google's chat-template doc directly. See PROMPT_RESEARCH.md "Gemma 4 May
2026 Update: Deployment-Surface Distinction" for the full reconciliation.

## 14. Thinking surfaces structurally, not as text markers

Gemma 4 thinking returns as `parts[].thought = true`, not as
`<|channel>` text markers. Code parsers must filter `parts[].thought`
rather than searching response text.

## Cross-family: do not generalize from sibling Gemini models

- **Gemini 2.5 Flash**: hides thinking by default (single-part response,
  `thoughtsTokenCount` in metadata only). Accepts `thinkingBudget: 0` to
  disable thinking entirely.
- **Gemini 3.1 Flash Lite Preview**: does not think at all (no
  `thoughtsTokenCount` on any response).
- **`gemini-3-pro`**: 404 NOT_FOUND on the v1beta endpoint as of
  May 6, 2026.

Code that targets multiple Google models must branch on model family.

## Verify after changes

Sample N=12 calls per code path. Expect: `finishReason=STOP`,
`thoughtsTokenCount=0` (or absent), median wall <5s, 100% schema-valid
JSON via `raw_decode`. Non-zero `MALFORMED_RESPONSE` or thinking-token
leak means rule 1 did not land. `MAX_TOKENS` with degenerate output on
26b-a4b means rule 2 did not land. Alternating 400/500 on a
schema-bearing call means rule 4 needs a bisect.

## 15. Interactions API surface mapping (June 2026 GA, unprobed)

The Interactions API is a parallel, additive surface that ships both Gemma
4 variants as supported Models. None of sections 1-14's behavioral findings
have been re-probed against `client.interactions.create(...)`; treat this
section as a request-shape translation table plus an explicit list of
open questions to verify before relying on legacy rules on the new surface.

### 15.1 Where things move

| Slot | `:generateContent` (legacy) | `interactions.create` (new) |
|---|---|---|
| Endpoint | `v1beta/models/<model>:generateContent` | `v1beta/interactions` (canonical per structured-output guide); `v1beta2/interactions` appears in the migration guide — try `v1beta` first |
| SDK method | `client.models.generate_content(...)` | `client.interactions.create(...)` |
| Min SDK | any `google-genai` / `@google/genai` | `google-genai >= 2.3.0`, `@google/genai >= 2.3.0` |
| User input | `contents: [{role, parts: [{text}]}]` | `input: "..."` (string) or `input: [{type, ...}, ...]` |
| System instruction | `systemInstruction.parts[].text` | `system_instruction` parameter (interaction-scoped) |
| Schema | `generationConfig.responseSchema` + `generationConfig.responseMimeType: "application/json"` | Top-level `response_format: [{type: "text", mime_type: "application/json", schema: {...}}]` (single object or array) |
| Response root | `response.candidates[0].content.parts[]` | `interaction.steps[]` with a `model_output` step whose `content[]` carries typed items |
| Trailing text shortcut | concat `parts[].text` filtered by `thought == null` | `interaction.output_text` (joins **only trailing** TextContent items) |
| Multi-turn | resend full `contents[]` | `previous_interaction_id=<prev.id>`; server holds history |
| Tool list | `tools: [{"googleSearchRetrieval": {}}]` | `tools: [{"type": "google_search"}, {"type": "url_context"}, ...]` |
| Streaming | `:streamGenerateContent` | `stream=True`; events `event_type=="step.delta"` (Python) / `type=="step.delta"` (JS), text in `event.delta.text` |
| Long-running | not supported | `background=true` (incompatible with `store=false`) |
| Storage | not stored | default `store=true`; opt out with `store=false` (which blocks `previous_interaction_id` and `background`) |

### 15.2 What carries over unchanged (schema layer)

The JSON Schema subset accepted by the Interactions `response_format[].schema`
field is the same one accepted by legacy `responseSchema` plus explicit
guarantees for string `format` (`date-time`/`date`/`time`), array
`prefixItems`, and recursive `$ref: "#"`. Behavioral rules that are about
**schema shape on Gemma 4** rather than API plumbing port over at the
schema level:

- Rule 2 (`26b-a4b`: at most one unbounded STRING per OBJECT) — applies if
  the behavior reproduces on Interactions. Schema validator constraints are
  unchanged; the failure mode is model behavior, not API.
- Rule 3 (property order in `properties` controls generation order) —
  applies at the schema level. Place `reasoning` STRING before `verdict`
  enum the same way.
- Rule 4 (wide schemas reject a top-level reasoning STRING on 31b) — same
  schema shape, same behavior expected.
- Rule 9 (top-level `ARRAY[OBJECT]` batch shape) — schema-level rule.

### 15.3 What does NOT carry over verbatim (parsing layer)

- **Rule 14 (`parts[].thought = true` filter).** The `parts[]` array is gone
  on Interactions. The legacy thought-flag does not have a verified analogue
  in `interaction.steps[]`. Open question: does Gemma 4 thinking appear as a
  distinct step type (e.g., `model_thought`) or as a typed `content[]` item
  inside `model_output`? Unknown. Do not transplant the legacy filter
  pattern; introspect `steps[]` and report shape before recommending a
  filter.
- **Rule 1 (`responseSchema` is the only reliable thinking-suppressor).**
  Whether top-level `response_format` produces the same single-non-thought
  collapse and the same ~30-40x wall-clock speedup on Interactions is
  unprobed. The wiring is `response_format`, not `responseSchema`; the
  empirical claim must be re-measured.
- **Rule 5 (`json.JSONDecoder().raw_decode()` for trailing garbage).**
  Whether Gemma 4 occasionally appends trailing text after valid JSON on
  Interactions is unprobed. The defensive parser is cheap; recommend it
  on both surfaces until disproved.

### 15.4 New failure modes specific to Interactions

- **`output_text` truncation.** `interaction.output_text` joins only
  trailing consecutive TextContent items. If Gemma 4 emits a thinking-shaped
  preamble or interleaved tool output before the final answer, the
  preamble's text content is dropped from `.output_text`. For any code path
  that does not use `response_format`, iterate `steps[]` instead.
- **History double-counting.** Passing both `previous_interaction_id` and a
  hand-rolled history string inside `input` double-counts. Pick one.
- **`store=false` lockout.** `store=false` blocks both `previous_interaction_id`
  chains and `background=true`. Recommend `store=true` plus an explicit
  `interactions.delete` cleanup for PII rather than `store=false` if
  multi-turn is needed.
- **Combined `response_format` + built-in tools is Gemini-3-only preview.**
  Per the structured-output guide, mixing `response_format` with
  `google_search` / `url_context` / `code_execution` / `file_search` /
  `function_calling` is Gemini 3 series only. Gemma 4 cannot mix the two.

### 15.5 Sources

- Interactions API overview (GA, supported-models table including both Gemma
  4 variants): `ai.google.dev/gemini-api/docs/interactions-overview`
  (scrapling-verified 2026-06-24; page last updated 2026-06-23).
- Migrate to Interactions API:
  `ai.google.dev/gemini-api/docs/migrate-to-interactions.md.txt`
  (scrapling-verified 2026-06-24; uses `v1beta2/interactions`).
- Structured outputs (Interactions, REST curl uses `v1beta/interactions`):
  `ai.google.dev/gemini-api/docs/structured-output` (scrapling-verified
  2026-06-24; page last updated 2026-06-22).
