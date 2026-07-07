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
mechanics, parameter defaults, thinking control, function-calling
patterns, prompt-shape guidance specific to 3.x. For Gemma 4 targets read
`GEMMA4_API_BEST_PRACTICES.md`; for DeepSeek V4 targets read
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
| `gemini-3.5-flash` | medium | minimal, low, medium, high | Agentic execution, coding, long-horizon tasks at scale (GA, recommended). |
| `gemini-3.1-pro-preview` | high | low, medium, high | Highest-quality reasoning. No `minimal`. |
| `gemini-3.1-flash-lite` | minimal | minimal, low, medium, high | Low-cost, high-volume tasks not needing 3.5 Flash's reasoning depth. |
| `gemini-3-flash-preview` | high | minimal, low, medium, high | Preview alt for Computer Use; 3.5 Flash is the recommended Computer Use model. |

3.5 Flash supports 1M input tokens / 65k output tokens / Batch API /
Context Caching / Google Search / Google Maps grounding / File Search /
Code Execution / URL Context / standard Function Calling / combined tool
use. Image segmentation is NOT supported in Gemini 3.x; route segmentation
workloads to Gemini 2.5 Flash (thinking off) or Gemini Robotics-ER 1.6.

## 2. Strip `temperature`, `top_p`, `top_k` from every request body

Gemini 3.x reasoning is optimized for default sampling. Remove
`temperature`, `top_p`, and `top_k` from every request body on **every
Gemini 3.x model**. To force determinism, write a system instruction with
explicit rules; do not set temperature.

Branch on model family in cross-family code: Gemma 4 uses T=1.0,
top_p=0.95, top_k=64; Gemini 3.x uses model defaults with the sampling
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

## 4. Thought preservation across turns is automatic in stateful mode

Gemini 3.5 Flash maintains intermediate reasoning across multi-turn
conversations automatically.

- **Interactions API stateful mode** (`store: true` default + `previous_interaction_id`
  in subsequent turns): server manages all thought blocks and signatures.
  No caller action needed.
- **Stateless mode** (caller passes full history): caller MUST resend all
  `thought` blocks exactly as received from the model. Removing or modifying
  them breaks reasoning continuity. Built-in tool steps (e.g.,
  `google_search_call` / `google_search_result`) also carry distinct
  signatures that must be resent.

Thought preservation increases per-turn token usage. Verify cost impact
when migrating from 3 Flash Preview.

## 5. Thinking surfaces as `thought` steps in `steps[]`

On the Interactions API, model reasoning appears as a dedicated `thought`
step in `interaction.steps[]`, distinct from `model_output`,
`function_call`, `function_result`, `user_input`, and built-in tool
steps. Every `thought` step has:

| Field | Required | Content |
|---|---|---|
| `signature` | Always present | Encrypted reasoning state. Maintains continuity across turns. |
| `summary` | Optional | Array of typed content blocks (text and/or images) summarizing the reasoning. May be empty. |

Thought summaries are OFF by default. Enable with:

```python
generation_config = {"thinking_summaries": "auto"}
```

When enabled, walk `interaction.steps[]` selecting `step.type == "thought"`;
iterate `step.summary[]`. Handle the empty-summary case in every consumer.

Streaming delta types for thinking: `thought_summary` (text or image
content, one or more deltas) and `thought_signature` (the cryptographic
signature, last delta before `step.stop`).

## 6. Function calling: strict response matching

Interactions API errors on mismatched function responses. Enforce:

| Requirement | Detail |
|---|---|
| Include `call_id` | Every `function_result` must include the `id` from the corresponding `function_call`. |
| Match `name` | The `name` in the response must match the `name` in the call. |
| Match counts | Return exactly one `function_result` for each `function_call` received. |

Canonical shape (Python):

```python
final = client.interactions.create(
    model="gemini-3.5-flash",
    previous_interaction_id=interaction.id,
    tools=[my_tool],
    input=[{
        "type": "function_result",
        "name": fc_step.name,
        "call_id": fc_step.id,
        "result": [{"type": "text", "text": json.dumps(result)}],
    }],
)
```

## 7. Place multimodal function responses INSIDE the response

Common defect: client provides an image as a sibling part to a function
response. Causes thought leakage and lower-quality outputs. Place the
multimodal content inside the function-result `result[]` array:

```python
input=[{
    "type": "function_result",
    "name": tool_call.name,
    "call_id": tool_call.id,
    "result": [
        {"type": "text", "text": "instrument.jpg"},
        {"type": "image", "mime_type": "image/jpeg", "data": base64_image},
    ],
}]
```

## 8. Append inline instructions to function-response text, not as separate parts

Defect: extra instructions sent as separate `Part` items after a function
response. Causes thought leakage. Append to the function-response text
separated by two newlines:

```python
result_text = f"{json.dumps(result)}\n\n<extra instructions here>"
```

## 9. Reduce tool-call overuse with two levers in order

1. **Lower `thinking_level`** (`medium` → `low` → `minimal`). Higher
   thinking levels encourage tool use for exploration and verification.
2. **Add a system instruction** explicitly bounding tool calls. Example:
   "You have a limited action budget of N tool calls. Use them efficiently."

## 10. Long-context: place query at the end, anchored to the context

For large context (entire books, codebases, long videos), place the
query/question at the END after the data; ending with the query
measurably improves performance. Apply this shape:

- Governing directives (role, output schema, refusal rules) at the START.
- Large context block (data, transcripts, codebases) in the MIDDLE.
- The user's specific query/question at the END, anchored with "Based on
  the preceding information..." or a domain-specific equivalent.
- Repeat the governing directive at the very end as a recency reminder
  (universal start-and-end rule still holds).

## 11. Prompting changes for 3.x

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
- **Context management:** see rule 10 above.

## 12. Combined tool use is supported in 3.x

Google Search, URL Context, Code Execution, File Search, and standard
Function Calling can be used in the **same request** on 3.5 Flash and
other 3.x models. Use the typed-string discriminator shape:

```python
tools=[
    {"type": "google_search"},
    {"type": "url_context"},
    {"type": "code_execution"},
]
```

Recommend combined tool use over chained single-tool calls when the task
spans multiple tool types.

## 13. Structured output + tools is a 3.x-only preview

`response_format` combined with built-in tools is documented as a
**Gemini 3-series-only preview**. Available across the 3.x family
including 3.5 Flash and 3.1 Pro Preview. Not available on Gemma 4 or
2.5 family: for those targets, choose one or the other, or run a
two-step pipeline (tools-call first, structured-reduction second).

Canonical shape:

```python
interaction = client.interactions.create(
    model="gemini-3.5-flash",
    input="Search for all details for the latest Euro.",
    tools=[{"type": "google_search"}, {"type": "url_context"}],
    response_format={
        "type": "text",
        "mime_type": "application/json",
        "schema": MatchResult.model_json_schema()
    },
)
```

## 14. Migration content moved

Legacy `generateContent` wiring scans and the 3.5 Flash upgrade checklist
live in `GEMINI_MIGRATION.md`. Load that file when legacy forms appear;
it is a one-time-per-prompt reference, not part of this file's
frequent-load shape.

## 15. Agentic workflows: port the 9-point planning template

When the prompt drives an agentic workflow (the model reasons, plans,
and executes tasks across tool calls), use a 9-point system-instruction
template covering: (1) logical dependencies and constraints, (2) risk
assessment, (3) abductive reasoning and hypothesis exploration, (4)
outcome evaluation and adaptability, (5) information availability, (6)
precision and grounding, (7) completeness, (8) persistence and patience,
(9) inhibit-response gate.

When the prompt is intended for an agentic workflow but lacks an
equivalent planning structure, port the 9 dimensions above into the
system instruction as a numbered planning block the model must complete
before any tool call or user response. Each dimension is one numbered
directive; the inhibit-response gate (9) goes last.

## 16. Gemini 3 Flash freshness, grounding, and tool enablement

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

**Tool enablement** (general 3.x; recommend by task type in Key Changes):
- Recent or obscure facts → enable Google Search grounding
  (`{"type": "google_search"}`).
- Any arithmetic, counting, or calculation → enable code execution
  (`{"type": "code_execution"}`); do not trust in-token computation.

## 17. Uncertainty: recommend a docs MCP search

When a fix depends on an uncovered or possibly-drifted Gemini fact (model
ID, default, parameter, endpoint, capability, deprecation date), do not
guess. In Key Changes, flag a deployer-verify item and recommend the
requestor confirm via a `gemini-api-docs-mcp` `search_docs` query scoped
to the unknown (e.g. "minimum google-genai SDK version for the
Interactions API"); state your interim assumption. The optimizer
recommends the search, it does not call the MCP.

## Verify after changes

- `interaction.status == "completed"`.
- Sampling triple is NOT in the request body.
- `thinking_level` is set or default `medium` is acceptable.
- Function-call/function-result IDs and names match 1:1.
- `interaction.output_text` (or `steps[]` walk for interleaved output) is
  parseable.
- `interaction.usage.total_thought_tokens` is recorded for cost tracking.

## Closing directive recap

This file is imperative reference for the prompt-optimizer agent when
`Target model: Gemini 3.x` is declared. Apply every numbered rule to the
prompt under review, cite rule numbers in Key Changes, and treat the
Interactions API as the sole supported surface. Legacy `:generateContent`
wiring is a migration defect: load `GEMINI_MIGRATION.md` and flag it
with the Interactions equivalent named.
