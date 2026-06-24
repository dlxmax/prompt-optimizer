# Gemma 4 API best practices

Authoritative reference for the **Gemini Interactions API** when targeting
`gemma-4-31b-it` and `gemma-4-26b-a4b-it`. Scope: API call mechanics
(request shape, parsing, retry, schema constraints). For prompt-text
guidance, use the `prompt-optimizer` agent with `Target model: Gemma 4`
declared; this file is the reference the agent reads to apply that
target.

> **Surface scope.** All recommendations below are scoped to the
> Interactions API (`generativelanguage.googleapis.com/v1beta/interactions`,
> accessed via `client.interactions.create(...)` with `google-genai >= 2.3.0`
> Python SDK or `@google/genai >= 2.3.0` JS SDK). The legacy
> `:generateContent` endpoint is **retired for prompt-optimizer's
> recommendations** — appearance of `generateContent`, `generationConfig.responseSchema`,
> `responseMimeType`, `systemInstruction.parts[].text`, `contents: [{role, parts}]`,
> or `candidates[0].content.parts[].thought` parsing in a prompt or call-site is
> flagged as a migration defect (see Topic 13.8 in `PROMPT_RESEARCH.md`).
> Empirical probes (May 6 and May 12, 2026) were performed under the legacy
> wiring; the observed behaviors describe the Gemma 4 model and port to
> the Interactions wiring at the schema/behavior layer. Re-probes under the
> new wiring are pending; the rules below state the Interactions wiring
> directly.

## 1. Use `response_format` for any code-parsed output

Set top-level `response_format` with `type: "text"`, `mime_type: "application/json"`,
and a `schema` on every Gemma 4 call whose output is parsed by code. This is the
**primary lever**, not a Tier 2 option.

Canonical wiring (Python SDK):
```python
interaction = client.interactions.create(
    model="gemma-4-31b-it",
    input=prompt,
    response_format={
        "type": "text",
        "mime_type": "application/json",
        "schema": {"type": "object", "properties": {"output": {"type": "string"}}, "required": ["output"]}
    }
)
text = interaction.output_text
```

Canonical wiring (REST):
```json
POST https://generativelanguage.googleapis.com/v1beta/interactions
{
  "model": "gemma-4-31b-it",
  "input": "...",
  "response_format": {
    "type": "text",
    "mime_type": "application/json",
    "schema": {"type": "object", "properties": {"output": {"type": "string"}}, "required": ["output"]}
  }
}
```

Behaviors observed under the legacy wiring (expected to port to Interactions):
- Suppresses thinking emission: response collapses to a single `model_output`
  step with no `thought` step preceding it. `usage.total_thought_tokens` drops
  to 0. MALFORMED rate observed at 0% on `:generateContent` probes.
- ~30 to 40x wall-clock speedup on short outputs (May 12 benchmark on
  `:generateContent`: ~67s/call median down to 1 to 2s/call).
- The only reliable thinking-suppression mechanism for Gemma 4. The
  `thinking_level` parameter (Gemini 3.x knob) is not listed as supported
  for Gemma 4 on Google's thinking page; legacy probes showed
  `thinkingLevel: "low"`/`"off"` and `thinkingBudget: 0` returned HTTP 400
  and `thinkingLevel: "high"` was a silent no-op. Expected Interactions
  behavior: either 400 or silent no-op. The fix is `response_format`.

If reasoning is wanted, request a bounded `reasoning` field inside the
schema (Rule 3 property-order pattern) rather than enabling
`thinking_summaries`. Gemma 4 is not in Google's supported-models table
for thinking levels; rely on schema-driven reasoning instead.

## 2. `26b-a4b` constraint: at most one unbounded `string` per `object`

`gemma-4-26b-a4b-it` fails under `response_format` whenever an `object` has
two or more unbounded free-text `string` properties. Failure modes split
between deterministic bigram/trigram loops to the output limit (e.g.,
`-classification-classification-...`, `0.0.0.0.0...`) and degenerate
empty `" [] ```"` output. Same schema passes cleanly on `gemma-4-31b-it`.

**Per-field `array` of `string` wrapping does NOT rescue this.** Probe-tested
May 12, 2026 on `:generateContent`: wrapping the long `string` moves the loop
to a sibling unbounded `string`; wrapping all of them shifts to HTTP 500 /
empty array. Schema-validator behavior is identical on Interactions, so the
failure mode is expected to reproduce.

**Verified workarounds when 26b-a4b is in the fallback chain:**
1. **Caller-side `response_format` skip** on the model-name match for
   `26b-a4b`. The model then emits free-form JSON inside the prompt's
   format scaffold, which it terminates correctly.
2. **Prompt-level bounding plus a worked stop-example** on every
   unbounded `string` field ("one short sentence; e.g., ..."). The 31b
   path can self-terminate without explicit bounding; 26b-a4b cannot.

**Safe schema shape on 26b-a4b:** exactly one unbounded `string` per `object`
inside a top-level `array` of `object` container (the `audit[].reason`
pattern) has held in production. Enum-bounded strings, MM:SS-bounded
strings, integer, and boolean are unaffected.

Temperature step-down does not break this loop; the fix is structural.

## 3. Property order in the schema controls generation order

The order in which fields appear inside an `object`'s `properties` dict
determines the order Gemma 4 emits them in the response. Place any
`reasoning` `string` field BEFORE the `verdict` enum it justifies, and
the model fills `reasoning` first, then commits to `verdict`, then (if
present) writes a short `reason` tag. This makes the verdict an output
of the reasoning rather than a post-hoc justification, and materially
shrinks per-item output length: observed ~1.8k chars per item dropping
to ~250 chars under this change alone on a warmup validator.

The corresponding anti-pattern is `verdict, reasoning`: the model locks
the verdict on the first token of the field, then inflates the
following `string` to justify it. Schema-level length caps in the field
`description` ("max 10 words") are not strongly enforced once the
verdict has committed.

**Application:**
- For judge or audit schemas, order properties as
  `index, reasoning, verdict, reason` (or the equivalent for your
  decision field). Define the reasoning `string` first.
- Keep `verdict` as a tight `enum` (e.g., `KEEP`/`DROP`) so it parses
  cleanly once committed.
- Keep `reasoning` and `reason` separate when both an audit trail and a
  short downstream tag are needed; otherwise collapse into a single
  length-capped `reasoning` field.
- This also interacts with rule 2 on `26b-a4b`: each `object` still gets
  at most one unbounded `string`. A `reasoning` `string` placed first
  consumes that one slot, so any sibling `reason` should be enum-bounded
  or length-capped via a stop-example.
- **Narrow schemas only.** Rule 4 overrides this pattern when the schema
  already has >=4 mandatory nested `object`s: on `31b`, the reasoning
  `string` crashes the request entirely. Move the reasoning surface to
  prompt-level prose or Python-side checks when the schema is wide.

**Caveat:** Property-order honouring is empirical, not documented.
Defensive practice is belt-and-braces: order the `properties` dict in
the desired generation order **and** add an explicit prompt instruction
("fill `reasoning` first, then commit `verdict`"). If a future Gemma 4
update weakens the order behavior, the prompt instruction still holds.

## 4. Wide schemas reject a top-level reasoning `string` on 31b

`gemma-4-31b-it` reliably crashes (alternating HTTP 400 INVALID_ARGUMENT
and 500 INTERNAL, 0/4 success) when the schema combines a
top-level free-text `reasoning` `string` with many mandatory nested
`object`s. Empirical bisect May 13, 2026 on a forensic signal schema at
T=0.5: removing the reasoning `string` brought success to 4/4 on the same
schema; removing the evidence `object`s while keeping the reasoning
`string` left success at 2/4 (general backend baseline). The crash is
schema-specific, not backend flake.

The mechanism appears to be response-budget overload: each mandatory
evidence `object` must be emitted with default values even when its
matching signal does not trigger, and a prose-populated `string` on top
pushes the response past an internal Gemma 4 limit, producing malformed
output that the upstream validator rejects.

**Threshold:** observed crash at 5 mandatory evidence `object`s plus 1
reasoning `string`. Prudent safety margin: do not add a top-level
reasoning `string` when the schema already has >=4 mandatory nested
`object`s with multiple inner properties each. Schemas with <=3 nested
`object`s (e.g., 3 `array` of `object` plus 1 nullable `object`) have carried
a single bounded reasoning `string` without issue in production.

**Workarounds when reasoning is wanted on a wide schema:**
- Move reasoning to prompt-level prose instructions ahead of the JSON
  output (the model can still self-audit; the audit just does not
  appear in the parsed payload).
- Move reasoning to Python-side deterministic checks after parsing.
- Split into two calls: a narrow reasoning call that returns the
  reasoning `string`, then a wide structured-output call that returns
  the evidence `object`s.

**Bisect, do not retry.** When a schema-bearing call returns alternating
400/500, the prior probability splits ~50/50 between backend flake and
schema rejection. Four schema variants x four attempts each (16 calls,
~5 minutes) make the answer obvious. Concluding "API instability"
without the comparative test wastes the same retry budget over and
over.

**Interaction with rule 3:** rule 3's reason-before-commit pattern
requires a reasoning `string` in the schema. That pattern only applies
to narrow schemas (<4 mandatory nested `object`s); for wide schemas use
the workarounds above.

## 5. Parse with `json.JSONDecoder().raw_decode()`, not `json.loads()`

Even with `response_format`, Gemma 4 occasionally emits valid JSON
followed by trailing text (~1 in 12 calls observed under legacy wiring;
expected to reproduce). Strict `json.loads` raises; `raw_decode` parses
the first valid object and ignores the rest.

```python
parsed, _ = json.JSONDecoder().raw_decode(interaction.output_text)
```

## 6. Do not pass `thinking_level` or `thinking_budget` on Gemma 4

Gemma 4 is NOT in Google's supported-models table for thinking levels
(thinking page lists only Gemini 3.x and 2.5 families). Passing
`generation_config.thinking_level` or `generation_config.thinking_budget`
on a Gemma 4 call is expected to either return HTTP 400 or silent-no-op,
matching the legacy `:generateContent` behavior. Branch on model family:
pass `thinking_level` for Gemini 3.x targets only; rely on
`response_format` (rule 1) for Gemma 4 thinking control.

## 7. `max_output_tokens` is a safety ceiling, not a thinking cap

Gemma 4 thinking expands to fill whatever budget is set (256 cap → ~300
thinking tokens; 1024 cap → ~1150 overflowing the cap; 2048 cap → more).
Lowering the cap converts `MALFORMED_RESPONSE` (long socket timeout,
empty visible output) into `MAX_TOKENS` (fast fail), which is a cheaper
failure mode, but it does not raise success rate. The actual
thinking-suppression lever is `response_format` (rule 1). Set
`max_output_tokens` generously when `response_format` is in use.

## 8. Classify retries by failure signature

Do not share one retry policy across these classes:

- **HTTP 5xx (500/503 INTERNAL)** → fast exponential backoff, same
  parameters, max 4 attempts. Baseline transient rate ~20% observed on
  legacy probes; treat as the expected Interactions baseline pending
  re-probe.
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
  `total_thought_tokens`) → parameter changes (temperature step-down
  1.0 → 0.85 → 0.75, or enable `response_format` if not already on),
  max 3 attempts. Same call repeated will fail the same way.
- **`MAX_TOKENS` with degenerate output on 26b-a4b** → structural fix
  per rule 2, not a retry. Repeating the call wastes budget.
- **Alternating 400/500 on a schema-bearing call** → suspect rule 4
  (wide-schema reasoning `string` overload on 31b). Bisect the schema
  before exhausting retries.

## 9. Schema-shape patterns for batch JSON output

When the prompt produces a fixed JSON schema and code parses the result,
two structural patterns matter beyond `response_format`:

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
`generation_config`; the earlier guidance to set `T=1.0` only is
incomplete.

**Contrast with Gemini 3.x.** Google's Gemini 3.5 Flash guide says
"`temperature`, `top_p`, `top_k`: we strongly recommend not changing the
default values. Gemini 3's reasoning capabilities are optimized for the
default settings. Remove these parameters from all requests." That
guidance applies to Gemini 3.x models, NOT to Gemma 4. Cross-family code
must branch on model family: pass the sampling triple for Gemma 4;
remove it for Gemini 3.x.

## 11. Probe before recommending

Google's documentation does not always reflect Gemma 4 behavior
(`thinking_budget` is documented for the Gemini 3.x family but is
expected to return 400 on Gemma 4; `response_format` documentation is
ambiguous but works perfectly on 31b and works conditionally on 26b-a4b
per rule 2).

One HTTP probe distinguishes "feature documented" from "feature works on
this model" and is free. If a recommendation depends on an API feature
that has not been probed against the target variant under Interactions
wiring, note that in the call site's deployment checklist.

## 12. Tool-calling: avoid 26b-a4b

Known double tool-call bug on 26b-a4b observed under legacy wiring. Both
variants behave identically for thinking control and for single-`string`
`response_format` mechanics, but they diverge on tool-calling and on
multi-`string` schemas (rule 2). Treat 26b-a4b as a code-parsed-JSON
target; reach for 31b when tool-calling is required.

## 13. Do not place `<|think|>` in `system_instruction`

It is a no-op and elevates the transient 500 rate. Similarly,
`<thinking>...</thinking>` XML scaffolds add prompt tokens with no
behavior change. Remove them from optimized prompts.

**Surface scope.** Google's April 20, 2026 chat-template doc states that
`<|think|>` in the system instruction enables thinking on Gemma 4. That
guidance applies to the chat-template surface (HuggingFace Transformers,
llama.cpp, MLX, Unsloth), where `apply_chat_template(messages,
enable_thinking=True)` emits the actual special-token id into `input_ids`.
On the Gemini REST API surface (whether Interactions or legacy), the
`system_instruction` field is plain text and the tokenizer does not
register `"<|think|>"` as a plain-text special-token mapping; the string
tokenizes as ordinary BPE pieces. The two surfaces are not equivalent.
This rule is REST-API-scoped and stands; deployers using local chat-template
paths should follow Google's chat-template doc directly. See
`PROMPT_RESEARCH.md` "Gemma 4 May 2026 Update: Deployment-Surface
Distinction" for the full reconciliation.

## 14. Thinking surfaces in `interaction.steps[]`, suppress via schema

On the Interactions API, model reasoning (when emitted) appears as a
dedicated `thought` step in `interaction.steps[]` with a `signature`
(always) and optional `summary` (only when `generation_config.thinking_summaries: "auto"`
is set). The legacy `parts[].thought == true` filter is replaced by:

```python
for step in interaction.steps:
    if step.type == "model_output":
        for block in step.content:
            if block.type == "text":
                # final answer text
```

**For Gemma 4 specifically**, the reliable suppression mechanism is
`response_format` (rule 1), which collapses the response to a single
`model_output` step with no `thought` step. `thinking_summaries` and
`thinking_level` are not listed as supported controls for Gemma 4 on
Google's thinking page; probe before relying on them. When `response_format`
is in use, the steps walk simplifies — there is just one `model_output`
step — and `interaction.output_text` works as the shortcut.

**Open question pending re-probe.** Under legacy wiring, Gemma 4
unconditionally emitted thinking parts unless `responseSchema` was set.
Under Interactions wiring, the expected behavior is parallel: no
`response_format` → `thought` step(s) precede `model_output`; with
`response_format` → single `model_output` step. Re-probe before
production rollout.

## Cross-family: do not generalize from sibling Gemini models

- **Gemini 3.5 Flash** (`gemini-3.5-flash`): GA June 2026 on Interactions.
  Defaults `thinking_level` to `medium` (down from `high` on 3 Flash Preview).
  Supports `minimal | low | medium | high`. Do NOT pass `temperature`,
  `top_p`, `top_k` (Gemini 3.x recommendation: remove these parameters).
  See `GEMINI_3X_API_BEST_PRACTICES.md`.
- **Gemini 3.1 Pro Preview** (`gemini-3.1-pro-preview`): defaults to
  `high`, supports `low | medium | high`. No `minimal`.
- **Gemini 3.1 Flash-Lite** (`gemini-3.1-flash-lite`): efficiency-tuned;
  defaults to `minimal`. Supports the full level set.
- **Gemini 3 Flash Preview** (`gemini-3-flash-preview`): defaults to `high`,
  supports the full level set. Computer Use is supported on 3 Flash Preview
  but NOT on 3.5 Flash.
- **Gemini 2.5 family** (`gemini-2.5-pro`, `gemini-2.5-flash`,
  `gemini-2.5-flash-lite`): supports `low | medium | high`. 2.5 Flash-Lite
  defaults thinking OFF. Older Gemini 2.5 advice (e.g., `thinking_budget: 0`
  disables thinking on 2.5 Flash) does not port to Gemma 4.

Code that targets multiple Google models must branch on model family.
A `Target model: Gemini 3.x` brief invokes `GEMINI_3X_API_BEST_PRACTICES.md`;
a `Target model: Gemma 4` brief invokes this file.

## Verify after changes

Sample N=12 calls per code path. Expect: `interaction.status == "completed"`,
no `thought` step in `interaction.steps[]` (when `response_format` is set),
`usage.total_thought_tokens == 0`, median wall <5s, 100% schema-valid JSON
via `raw_decode` on `interaction.output_text`. Non-zero `total_thought_tokens`
or a `thought` step preceding `model_output` means rule 1 did not land.
`MAX_TOKENS` with degenerate output on 26b-a4b means rule 2 did not land.
Alternating 400/500 on a schema-bearing call means rule 4 needs a bisect.
