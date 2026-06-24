# Gemini 3.x API best practices

Authoritative reference for the **Gemini Interactions API** when targeting
the Gemini 3.x family: `gemini-3.5-flash` (GA, default for new
production work), `gemini-3.1-pro-preview`, `gemini-3.1-flash-lite`,
`gemini-3-flash-preview`, and `gemini-3-pro-preview`. Scope: API call
mechanics, parameter defaults, thinking control, function-calling
patterns, prompt-shape guidance specific to 3.x. For Gemma 4 targets see
`GEMMA4_API_BEST_PRACTICES.md`; for DeepSeek V4 targets see
`DEEPSEEK_V4_API_BEST_PRACTICES.md`.

> **Surface scope.** All recommendations below are scoped to the
> Interactions API (`generativelanguage.googleapis.com/v1beta/interactions`,
> accessed via `client.interactions.create(...)` with `google-genai >= 2.0.0`
> Python SDK or `@google/genai >= 2.0.0` JS SDK; Google's 3.5 Flash guide
> recommends 2.0.0+ for the Interactions breaking-changes pass, and the
> general Interactions minimum is 2.3.0). The legacy `:generateContent`
> endpoint is retired for prompt-optimizer's recommendations.

## 1. Model selection

| Model ID | Default thinking | Levels supported | Best for |
|---|---|---|---|
| `gemini-3.5-flash` | medium | minimal, low, medium, high | Agentic execution, coding, long-horizon tasks at scale (GA, recommended). |
| `gemini-3.1-pro-preview` | high | low, medium, high | Highest-quality reasoning. No `minimal`. |
| `gemini-3.1-flash-lite` | minimal | minimal, low, medium, high | Low-cost, high-volume tasks not needing 3.5 Flash's reasoning depth. |
| `gemini-3-flash-preview` | high | minimal, low, medium, high | Computer Use workloads (3.5 Flash does NOT support Computer Use). |
| `gemini-3-pro-preview` | high | low, high | Hardest reasoning tasks. No `minimal` or `medium`. |

3.5 Flash supports 1M input tokens / 65k output tokens / January 2025
knowledge cutoff / Batch API / Context Caching / Google Search /
Google Maps grounding / File Search / Code Execution / URL Context /
standard Function Calling / combined tool use. Image segmentation is NOT
supported in Gemini 3.x; stay on Gemini 2.5 Flash (thinking off) or
Gemini Robotics-ER 1.6 for segmentation workloads.

## 2. Remove `temperature`, `top_p`, `top_k` from all configs

Google's 3.5 Flash guide is explicit:

> "`temperature`, `top_p`, `top_k`: we strongly recommend not changing the
> default values. Gemini 3's reasoning capabilities are optimized for the
> default settings. Remove these parameters from all requests."

This applies to **all Gemini 3.x models** including 3.5 Flash, 3.1 Pro,
3.1 Flash-Lite, 3 Flash Preview, and 3 Pro Preview. To force determinism,
write a system instruction with explicit rules instead of setting
temperature.

This is a behavioral inversion from Gemma 4 (which uses T=1.0, top_p=0.95,
top_k=64) and from many older Gemini 2.5 deployments. Cross-family code
must branch on model family.

## 3. Use `thinking_level`, not `thinking_budget`

`thinking_budget` (numeric) is still accepted for backward compatibility
but is no longer recommended. Use `thinking_level` (string enum):

```python
generation_config = {"thinking_level": "medium"}
```

Values: `"minimal"`, `"low"`, `"medium"` (default on 3.5 Flash), `"high"`.
`thinking_level` and `thinking_budget` are **mutually exclusive in the
same request** — passing both returns HTTP 400.

When to use which level:

| Level | When |
|---|---|
| `minimal` | Chat-like use cases, quick factual answers, simple tool calls. |
| `low` | Code/agentic tasks needing fewer steps; analysis and writing that need some thinking. Significantly improved on 3.5 Flash vs. 3 Flash Preview. |
| `medium` (default) | Best quality for most tasks; complex code and agentic use cases. |
| `high` | Complex reasoning, hard math, hardest code/agent tasks. Allows extended thoughts and function calls. |

Default on 3.5 Flash is **`medium`**, changed from `high` on 3 Flash
Preview. Test before assuming the prior default carries over.

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

Thought preservation may increase per-turn token usage — verify cost
impact when migrating from 3 Flash Preview.

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
iterate `step.summary[]`. Always handle the empty-summary case.

Streaming delta types for thinking: `thought_summary` (text or image
content, one or more deltas) and `thought_signature` (the cryptographic
signature, last delta before `step.stop`).

## 6. Function calling: strict response matching

Interactions API errors on mismatched function responses (legacy
GenerateContent returns empty responses with `finish_reason: STOP` instead
of erroring). Always:

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

## 7. Multimodal function responses go INSIDE the response

Common defect: client provides an image as a sibling part to a function
response. Causes thought leakage and lower-quality outputs. Correct
shape: include the multimodal content inside the function-result `result[]`
array:

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

## 8. Inline instructions appended to function-response text, not as separate parts

Defect: extra instructions sent as separate `Part` items after a function
response. Causes thought leakage. Correct shape: append to the
function-response text separated by two newlines.

```python
result_text = f"{json.dumps(result)}\n\n<extra instructions here>"
```

## 9. Reducing tool-call overuse

Two levers, in order:

1. **Lower `thinking_level`** (`medium` → `low` → `minimal`). Higher
   thinking levels encourage tool use for exploration and verification.
2. **Add a system instruction** explicitly bounding tool calls. Example:
   "You have a limited action budget of N tool calls. Use them efficiently."

## 10. Long-context: query at the end, anchored to the context

Google's 3.5 Flash guide:

> "Context management: When working with large datasets (such as entire
> books, codebases, or long videos), place your specific instructions or
> questions at the end of the prompt, after the data context. Anchor the
> model's reasoning by starting your question with a phrase like, 'Based
> on the preceding information...'."

Google's Long Context FAQ:

> "In most cases, especially if the total context is long, the model's
> performance will be better if you put your query / question at the end
> of the prompt (after all the other context)."

Application:

- Governing directives (role, output schema, refusal rules) at the START.
- Large context block (data, transcripts, codebases) in the MIDDLE.
- The user's specific query/question at the END, anchored with "Based on
  the preceding information..." or a domain-specific equivalent.
- Recency reminder of the governing directive at the very end (universal
  start-and-end rule for governing directives still holds).

## 11. Prompting changes for 3.x

Canonical reference: Google's prompt design strategies page
(`ai.google.dev/gemini-api/docs/prompting-strategies.md.txt`) plus the
3.5 Flash prompting best-practices section. The two converge on:

- **Precise instructions:** be concise. Gemini 3.x responds best to
  direct, clear instructions. Verbose or complex prompt engineering
  techniques designed for older models may cause the model to
  over-analyze. Drop chain-of-thought scaffolding like
  "think step by step in detail before answering"; use `thinking_level`
  instead.
- **Output verbosity:** Gemini 3 and 3.1 are less verbose by default and
  prefer direct, efficient answers. If a conversational tone is needed,
  steer explicitly ("Explain this as a friendly, talkative assistant").
- **Consistent structure:** XML-style tags (e.g., `<instructions>`,
  `<context>`) OR Markdown headings as section delimiters — not both
  styles mixed within a single prompt. Pick one and stay with it.
  Variable-substitution conventions (curly braces) are unchanged.
- **Critical-instructions placement:** persona, behavioral constraints,
  and output format requirements belong in the System Instruction
  (Interactions `system_instruction` parameter) OR at the very beginning
  of the user prompt. Burying these after long context or examples is a
  defect. The start-and-end recency rule for the governing directive
  still applies as a closing reminder.
- **Multimodal equal-class:** when the prompt accepts images, audio, or
  video alongside text, instructions must reference each modality
  explicitly. A prompt that names only the text input when an image is
  also passed is a defect.
- **Thinking-boost lever (narrow fallback):** for heavy reasoning where
  `thinking_level: "high"` is not enough, the clause "Think very hard
  before answering" can improve performance at the cost of extra
  thinking tokens. Use only after `thinking_level: "high"` has been
  tried; do not deploy as default scaffolding since it conflicts with
  the precise-and-direct rule above.
- **Context management:** see rule 10 above.

## 12. Combined tool use is supported in 3.x

Google Search, URL Context, Code Execution, File Search, and standard
Function Calling can be used in the **same request** on 3.5 Flash and
other 3.x models. Tools array shape uses typed-string discriminators:

```python
tools=[
    {"type": "google_search"},
    {"type": "url_context"},
    {"type": "code_execution"},
]
```

## 13. Structured output + tools is a 3.x-only preview

`response_format` combined with built-in tools is documented as a
**Gemini 3-series-only preview**. Available across the 3.x family
including 3.5 Flash and 3.1 Pro Preview. Not available on Gemma 4 or
2.5 family — for those targets, choose one or the other (or run a
two-step pipeline: tools-call first, structured-reduction second).

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

## 14. Migration checklist when moving to 3.5 Flash

Recommend in Key Changes section when target is being upgraded to 3.5 Flash:

- Update model name (e.g., `gemini-3-flash-preview` → `gemini-3.5-flash`).
- Remove `temperature`, `top_p`, `top_k`.
- Replace `thinking_budget` (numeric) with `thinking_level` (string enum).
- Verify default `medium` thinking is acceptable for the task. Test `low`
  for cost; reserve `high` for hardest cases.
- Add `id` and matching `name` to all `function_result` parts; return one
  response per call.
- Move multimodal content INSIDE function responses, not as sibling parts.
- Append inline instructions to the END of function-response text separated
  by two newlines.
- Test with thought preservation on — token usage may increase per turn.
- Place query at end of prompt for long-context inputs.
- Drop chain-of-thought scaffolding from prompts; lean on `thinking_level`.
- Update SDK to `google-genai` >= 2.0.0 (per Google's migration note) or
  >= 2.3.0 (general Interactions floor).
- Stay on Gemini 3 Flash Preview for Computer Use workloads; 3.5 Flash
  does not support Computer Use.

## 15. Agentic workflows: port the 9-point planning template

When the prompt drives an agentic workflow (the model reasons, plans,
and executes tasks across tool calls), Google's prompt design strategies
page publishes a researcher-validated 9-point system-instruction
template: (1) logical dependencies and constraints, (2) risk assessment,
(3) abductive reasoning and hypothesis exploration, (4) outcome
evaluation and adaptability, (5) information availability, (6) precision
and grounding, (7) completeness, (8) persistence and patience,
(9) inhibit-response gate.

When the prompt is intended for an agentic workflow but lacks an
equivalent planning structure, recommend porting the 9-point template
into the system instruction. The template body lives at
`ai.google.dev/gemini-api/docs/prompting-strategies.md.txt`; cite the
URL rather than inlining the full template.

## Verify after changes

- `interaction.status == "completed"`.
- Sampling triple is NOT in the request body.
- `thinking_level` is set or default `medium` is acceptable.
- Function-call/function-result IDs and names match 1:1.
- `interaction.output_text` (or `steps[]` walk for interleaved output) is
  parseable.
- `interaction.usage.total_thought_tokens` is recorded for cost tracking.
