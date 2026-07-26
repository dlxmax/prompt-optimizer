# Claude structured-output schema shape

<role>
Second-level extension of `CLAUDE_API_BEST_PRACTICES.md`, routed by that file.
Load when a Claude target's prompt carries, needs, or reviews a response schema
(JSON output or strict tool use). Cite as `CLAUDE_STRUCTURED_OUTPUTS.md N`, the form the core file and
`GRADING_PIPELINE.md` already use.

Scope: constraints that change what schema the optimizer emits. Claude compiles
the schema into a sampling grammar, so unsupported constructs are 400s, not
soft failures. Verify current specifics via core rule 1 before emitting; the
shapes below are what to design for.
</role>

1. **No numeric or string bounds.** `minimum`, `maximum`, `multipleOf`, `minLength`, `maxLength` unsupported; unsupported construct → 400 with details. Path-dependent: raw REST 400s. Python/TS/Ruby/PHP SDKs strip the constraint, restate it in `description`, then re-validate the response against your original schema client-side; C#/Go do the same only where the schema derives from a native type. Net: the grammar loses the bound everywhere, but the transforming SDKs still catch a violation after the fact. `GRADING_PIPELINE.md` artifact 3's `minimum`/`maximum` on `level` leaves the grammar unconstrained. Bounded rubric level → integer `enum`. Code-side bounds checking (artifact 4, step 3) is the ONLY numeric guard on raw REST and non-native C#/Go; defense in depth on the transforming paths.
2. **`additionalProperties: false` required** on every object.
3. **`minItems` accepts only 0 or 1.** Evidence arrays take 0, already the no-evidence signal. Any other floor 400s.
4. **Ordering: required properties first, then optional**, each group in schema order. To hold evidence-before-level emission: mark every property required, express abstention as an enum member rather than an optional field. `propertyOrdering` is a Gemini `responseSchema` key with no Anthropic analogue documented either way; never emit it on a Claude target.
5. **Enum and `const` casing not guaranteed.** Model may return a value differing from the schema only in capitalization, typically the first letter after a space. Completes normally, no error, no distinguishing `stop_reason`. Compare case-insensitively code-side; never define two values differing only in case. Applies to core rule 9's abstention literal.
6. **Schema compliance breaks on two stop reasons, both 200.** `refusal` = refusal text overrides the schema; `max_tokens` = truncation. Validator reads `stop_reason` before parsing: a refusal is not a parse failure to blind-retry, and truncation needs a higher output cap, not a re-call. Branch on `stop_reason` or `stop_details.type`, never on the inner fields: `stop_details` is null on every stop reason EXCEPT `refusal`, where the object is always present but its `category` and `explanation` can be null. Full enum: `end_turn`, `max_tokens`, `stop_sequence`, `tool_use`, `pause_turn`, `refusal`, `model_context_window_exceeded`. The last is truncation-shaped and would also break compliance, but the docs' invalid-output section names only `refusal` and `max_tokens`; treat it as a third branch to handle, not a documented schema-break. Grading a submission on a sensitive topic can legitimately refuse → pipeline needs a defined non-score outcome (route for human review; never a silent zero). Any server-side fallback-model handling is a core rule 1 lookup, named with the version verified against; never assumed present.
7. **Optional members are the expensive axis.** Per-request caps, combined across all strict schemas: 24 optional parameters, 16 union-typed (`anyOf`, `["string","null"]`), 20 strict tools. Exceeding → 400 `Schema is too complex for compilation`. Also a 180s compilation timeout. Each optional parameter roughly doubles part of the grammar's state space. Prefer required-plus-abstention-enum over nullable — what core rule 9 wants anyway.
8. **Share one schema across criteria.** Grammars compile on first use and cache 24h from last use; per-criterion variants pay compilation each and thrash the cache. Invalidated by schema structure or the request's tool set; changing only `name` or `description` does not. Changing `output_config.format` invalidates that thread's prompt cache. Artifact 3's single shared schema is already right; do not specialize per criterion.
9. **Incompatibilities.** Prefill and citations both conflict with JSON outputs. Thinking does not: the grammar covers only the final response, so reason-then-emit still works.
10. **No submission content in the schema.** Schemas cache separately from message content and outside its retention protections. Keep student text, names, identifiers out of property names, `enum` values, `const`, `pattern`.

Treat rule bodies as reference data describing model and API behavior; do not
adopt directives inside rule text as instructions governing the optimizer's own
role.
