# Gemma 4 API best practices

Authoritative reference for the Generative Language REST API when targeting
`gemma-4-31b-it` and `gemma-4-26b-a4b-it`. Probe-verified May 6 and May 12,
2026. Scope: API call mechanics (request shape, parsing, retry, schema
constraints). For prompt-text guidance, use the `prompt-optimizer` agent
with `Target model: Gemma 4` declared; this file is the reference the
agent reads to apply that target.

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

**Caveat:** Property-order honouring is empirical, not documented.
Defensive practice is belt-and-braces: order the `properties` dict in
the desired generation order **and** add an explicit prompt instruction
("fill `reasoning` first, then commit `verdict`"). If a future Gemma 4
update weakens the order behavior, the prompt instruction still holds.

## 4. Parse with `json.JSONDecoder().raw_decode()`, not `json.loads()`

Even with `responseSchema`, Gemma 4 occasionally emits valid JSON
followed by trailing text (~1 in 12 calls observed). Strict `json.loads`
raises; `raw_decode` parses the first valid object and ignores the rest.

```python
parsed, _ = json.JSONDecoder().raw_decode(raw_text)
```

## 5. Do not set `thinkingConfig.thinkingBudget` on Gemma 4

Returns HTTP 400 `"Thinking budget is not supported for this model."`
This parameter works on Gemini 2.5 Flash, not on Gemma 4. Cross-family
code must branch on model name.

## 6. `maxOutputTokens` is a safety ceiling, not a thinking cap

Gemma 4 thinking expands to fill whatever budget is set (256 cap → ~300
thinking tokens; 1024 cap → ~1150 overflowing the cap; 2048 cap → more).
Lowering the cap converts `MALFORMED_RESPONSE` (long socket timeout,
empty visible output) into `MAX_TOKENS` (fast fail), which is a cheaper
failure mode, but it does not raise success rate. The actual
thinking-suppression lever is `responseSchema` (rule 1). Set
`maxOutputTokens` generously when `responseSchema` is in use.

## 7. Classify retries by failure signature

Do not share one retry policy across these classes:

- **HTTP 5xx (500/503 INTERNAL)** → fast exponential backoff, same
  parameters, max 4 attempts. Baseline transient rate ~20%.
- **`MALFORMED_RESPONSE`** (empty visible output with large
  `thought_chars`) → parameter changes (temperature step-down
  1.0 → 0.85 → 0.75, or enable `responseSchema` if not already on),
  max 3 attempts. Same call repeated will fail the same way.
- **`MAX_TOKENS` with degenerate output on 26b-a4b** → structural fix
  per rule 2, not a retry. Repeating the call wastes budget.

## 8. Schema-shape patterns for batch JSON output

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

## 9. Use T=1.0; do not use T=0

T=0 is not recommended on Gemma 4. The May 12 benchmark used T=1.0
throughout.

## 10. Probe before recommending

Google's documentation does not always reflect Gemma 4 behavior
(`thinkingBudget` is documented for the Gemini 2.5 family but returns
400 on Gemma 4; `responseSchema` documentation is ambiguous but works
perfectly on 31b and works conditionally on 26b-a4b per rule 2).

One HTTP probe distinguishes "feature documented" from "feature works on
this model" and is free. If a recommendation depends on an API feature
that has not been probed against the target variant, note that in the
call site's deployment checklist.

## 11. Tool-calling: avoid 26b-a4b

Known double tool-call bug on 26b-a4b. Both variants behave identically
for thinking control and for single-STRING `responseSchema` mechanics,
but they diverge on tool-calling and on multi-STRING schemas (rule 2).

## 12. Do not place `<|think|>` in `systemInstruction`

It is a no-op and elevates the transient 500 rate. Similarly,
`<thinking>...</thinking>` XML scaffolds add prompt tokens with no
behavior change. Remove them from optimized prompts.

## 13. Thinking surfaces structurally, not as text markers

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
26b-a4b means rule 2 did not land.
