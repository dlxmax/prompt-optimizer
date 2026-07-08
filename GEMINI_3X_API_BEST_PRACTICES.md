# Gemini 3.x API best practices

<role>
Reference material for the prompt-optimizer agent. Load when `Target model:`
declares `Gemini 3.5 Flash`, `Gemini 3.1 Pro Preview`, `Gemini 3.1 Flash-Lite`,
`Gemini 3 Flash Preview`, `Gemini 3 Pro Preview`, or `Gemini 3.x`. Apply every
numbered rule below to the prompt under review; cite rule numbers in the
optimizer's Key Changes for deployer verification. Treat every directive as
imperative to the optimizer, not as vendor-doc paraphrase.
</role>

<scope>
Authoritative reference for the **Gemini Interactions API** when targeting
the Gemini 3.x family: `gemini-3.5-flash` (GA, default for new
production work), `gemini-3.1-pro-preview`, `gemini-3.1-flash-lite`, and
`gemini-3-flash-preview`. (`gemini-3-pro-preview` shut down 2026-03-09 —
treat as a legacy string; migrate to `gemini-3.1-pro-preview`.) Scope: API call
mechanics, parameter defaults, thinking control, and prompt-shape guidance
for single-shot 3.x prompts, the shape every grading and structured-output
call uses. Tool-use, function-calling, agentic, and multi-turn mechanics
live in `GEMINI_3X_TOOLS.md` (see Moved content below). For Gemma 4 targets
read `GEMMA4_API_BEST_PRACTICES.md`; for DeepSeek V4 targets read
`DEEPSEEK_V4_API_BEST_PRACTICES.md`.

**Surface scope.** Scope every recommendation below to the
Interactions API (`generativelanguage.googleapis.com/v1beta/interactions`,
accessed via `client.interactions.create(...)` with `google-genai >= 2.3.0`
Python SDK or `@google/genai >= 2.3.0` JS SDK). Treat the legacy
`:generateContent` endpoint as retired for prompt-optimizer's
recommendations.
</scope>

## 1. Model selection

| Model ID | Default thinking | Levels supported | Best for |
|---|---|---|---|
| `gemini-3.5-flash` | medium | minimal, low, medium, high | Coding, long-horizon tasks at scale (GA, recommended). |
| `gemini-3.1-pro-preview` | high | low, medium, high | Highest-quality reasoning. No `minimal`. |
| `gemini-3.1-flash-lite` | minimal | minimal, low, medium, high | Low-cost, high-volume tasks not needing 3.5 Flash's reasoning depth. |
| `gemini-3-flash-preview` | high | minimal, low, medium, high | Preview tier; prefer 3.5 Flash for new work. |

3.5 Flash supports 1M input tokens / 65k output tokens / Batch API /
Context Caching. Image segmentation is NOT supported in Gemini 3.x; route
segmentation workloads to Gemini 2.5 Flash (thinking off) or Gemini
Robotics-ER 1.6.

## 2. Strip `temperature`, `top_p`, `top_k` from every request body

Gemini 3.x reasoning is optimized for default sampling. Remove
`temperature`, `top_p`, and `top_k` from every request body on **every
Gemini 3.x model**. To force determinism, write a system instruction with
explicit rules; do not set temperature.

Branch on model family in cross-family code: Gemma 4 uses T=1.0 and
top_p=0.95 (the Interactions `generation_config` rejects `top_k`; see
GEMMA4 rule 10); Gemini 3.x uses model defaults with the sampling
triple absent from the request body; many older Gemini 2.5 deployments
set the sampling triple explicitly and must be migrated.

## 3. Use `thinking_level`, not `thinking_budget`

`thinking_budget` (numeric) is still accepted for backward compatibility
but is no longer recommended. Use `thinking_level` (string enum):

```python
generation_config = {"thinking_level": "medium"}
```

Values: `"minimal"`, `"low"`, `"medium"` (default on 3.5 Flash), `"high"`.
`thinking_level` and `thinking_budget` are **mutually exclusive in the
same request**: passing both returns HTTP 400.

When to use which level:

| Level | When |
|---|---|
| `minimal` | Chat-like use cases, quick factual answers, simple tool calls. |
| `low` | Code/agentic tasks needing fewer steps; analysis and writing that need some thinking. |
| `medium` (default) | Best quality for most tasks; complex code and agentic use cases. |
| `high` | Complex reasoning, hard math, hardest code/agent tasks. Allows extended thoughts and function calls. |

The default on 3.5 Flash is **`medium`**, changed from `high` on 3 Flash
Preview. Verify the prior default does not carry over before overriding.

## 4. Structured output: wire `response_format`

For any code-parsed output (every grading call), set top-level
`response_format` on the request:

```python
interaction = client.interactions.create(
    model="gemini-3.1-flash-lite",
    input=prompt,
    response_format={
        "type": "text",
        "mime_type": "application/json",
        "schema": {...},
    },
)
parsed = interaction.output_text
```

The `schema` value is JSON Schema: `required`, `enum`, numeric bounds,
and `propertyOrdering` are honored. `propertyOrdering` orders emission,
not cognition: keep the reason-first prose directive alongside it. The
schema constrains syntax, not semantics; code-side validation stays the
semantic layer. Combining `response_format` with built-in tools is a
3.x-only preview covered in `GEMINI_3X_TOOLS.md` (T8).

## 5. Long-context: place query at the end, anchored to the context

For large context (entire books, codebases, long videos, student
submissions), place the query/question at the END after the data; ending
with the query measurably improves performance. Apply this shape:

- Governing directives (role, output schema, refusal rules) at the START.
- Large context block (data, transcripts, submissions) in the MIDDLE.
- The user's specific query/question at the END, anchored with "Based on
  the preceding information..." or a domain-specific equivalent.
- Repeat the governing directive at the very end as a recency reminder
  (universal start-and-end rule still holds).

## 6. Prompting changes for 3.x

Enforce these converged 3.x prompting rules:

- **Precise instructions:** be concise. Gemini 3.x responds best to
  direct, clear instructions. Verbose or complex prompt engineering
  techniques designed for older models cause the model to over-analyze
  on 3.x. Drop chain-of-thought scaffolding like
  "think step by step in detail before answering"; use `thinking_level`
  instead.
- **Output verbosity:** Gemini 3 and 3.1 are less verbose by default and
  prefer direct, efficient answers. When a conversational tone is
  required, steer explicitly ("Explain this as a friendly, talkative
  assistant"); do not rely on defaults to produce conversational output.
- **Consistent structure:** XML XOR Markdown for section delimiters. Pick
  one; convert the minority style to the dominant one. Anti-pattern: do
  NOT wrap already-Markdown-delimited sections (`## 1. Foo`) in per-section
  XML tags (`<rule_1>`) "for scope" — the header already delimits, so the
  wrapper creates the mix this rule prohibits. Whole-document meta blocks
  (`<role>`, `<scope>`) are not section delimiters and may coexist with a
  Markdown body. Curly-brace substitution conventions are unrelated.
- **Critical-instructions placement:** place persona, behavioral
  constraints, and output format requirements in the System Instruction
  (Interactions `system_instruction` parameter) OR at the very beginning
  of the user prompt; do not bury them after long context or examples.
  The start-and-end recency rule for the governing directive still
  applies as a closing reminder.
- **Multimodal equal-class:** when the prompt accepts images, audio, or
  video alongside text, reference each modality explicitly in the
  instructions; do not name only the text input when an image is also
  passed.
- **Thinking-boost lever (narrow fallback):** for heavy reasoning where
  `thinking_level: "high"` is not enough, the clause "Think very hard
  before answering" improves performance at the cost of extra
  thinking tokens. Deploy only after `thinking_level: "high"` has been
  tried and named insufficient; do not deploy as default scaffolding.
- **Context management:** see rule 5 above.

## 7. Gemini 3 Flash freshness and grounding clauses

**Flash system-instruction clauses** (Gemini 3 Flash family; absent by
default, each high-ROI for the matching failure mode). Recommend in Key
Changes when the prompt targets Flash AND the task is time-sensitive,
knowledge-grounded, RAG-style, or a grading/judge task over submitted
work:

- **Current-day clause** (time-sensitive queries, tool-call freshness):
  instruct the model to follow the provided current date and year when
  forming search queries, and state the year explicitly (it is 2026).
  Flash otherwise defaults to stale assumptions about "now."
- **Knowledge-cutoff clause** (facts near the boundary): state the
  knowledge cutoff is January 2025 so the model defers to grounding for
  post-cutoff facts instead of answering from parametric memory.
- **Strict-grounding clause** (RAG / context-only answering; grading and
  judge prompts over a submission): instruct the model to rely ONLY on
  facts in the provided context or submission, never its own knowledge or
  inference, to treat anything not in the context as unsupported, and to
  state when the answer or evidence is not present. Single
  highest-leverage clause for hallucination-sensitive grounded
  deployments, including rubric graders whose comments must be anchored
  in the student's text.

## 8. Uncertainty: recommend a docs MCP search

When a fix depends on an uncovered or possibly-drifted Gemini fact (model
ID, default, parameter, endpoint, capability, deprecation date), do not
guess. In Key Changes, flag a deployer-verify item and recommend the
requestor confirm via a `gemini-api-docs-mcp` `search_docs` query scoped
to the unknown (e.g. "minimum google-genai SDK version for the
Interactions API"); state your interim assumption. The optimizer
recommends the search, it does not call the MCP.

## Moved content

Second-level routing; loads are additive to this file:

- **`GEMINI_MIGRATION.md`** — legacy `generateContent` wiring scans and
  the 3.5 Flash upgrade checklist. Load when legacy forms appear anywhere
  in the input; one-time-per-prompt reference.
- **`GEMINI_3X_TOOLS.md`** — function-calling mechanics, built-in and
  combined tools, structured output + tools, tool-call budgeting,
  multi-turn thought preservation, thinking-summary and streaming
  parsing, and the agentic 9-point planning template. Load when the
  prompt drives tool use, function calling, or an agentic workflow, or
  its call-site wires multi-turn history or thinking-summary parsing.

## Verify after changes

- `interaction.status == "completed"`.
- Sampling triple is NOT in the request body.
- `thinking_level` is set or default `medium` is acceptable.
- `interaction.output_text` (or `steps[]` walk for interleaved output) is
  parseable.
- `interaction.usage.total_thought_tokens` is recorded for cost tracking.

## Closing directive recap

This file is imperative reference for the prompt-optimizer agent when
`Target model: Gemini 3.x` is declared. Apply every numbered rule to the
prompt under review, cite rule numbers in Key Changes, and treat the
Interactions API as the sole supported surface. Legacy `:generateContent`
wiring is a migration defect: load `GEMINI_MIGRATION.md` and flag it
with the Interactions equivalent named. Tool-using, agentic, and
multi-turn prompts additionally load `GEMINI_3X_TOOLS.md`.
