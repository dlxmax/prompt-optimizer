# Gemini 3.x tools and agentic workflows

<role>
Reference material for the prompt-optimizer agent. Load when a Gemini 3.x
target is declared AND the prompt under review drives tool use, function
calling, or an agentic workflow, or its call-site wires multi-turn history
or thinking-summary parsing. This file extends
`GEMINI_3X_API_BEST_PRACTICES.md` (load that core file first; its rules
apply too). Apply every T-rule below whose surface appears in the prompt
or call-site; cite T-rule numbers in Key Changes for deployer
verification. Single-shot prompts with no tools and no multi-turn wiring
(per-criterion grading calls, one-shot structured output) never need this
file.
</role>

<scope>
Same surface as the core file: the Gemini Interactions API
(`client.interactions.create(...)`, `google-genai >= 2.3.0` /
`@google/genai >= 2.3.0`). Scope here: function-calling mechanics,
built-in and combined tools, multi-turn thought handling, thinking-summary
parsing, and agentic system-instruction structure. 3.5 Flash supports
Google Search / Google Maps grounding / File Search / Code Execution /
URL Context / standard Function Calling / combined tool use.
</scope>

## T1. Thought preservation across turns is automatic in stateful mode

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

## T2. Thinking surfaces as `thought` steps in `steps[]`

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

## T3. Function calling: strict response matching

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

## T4. Place multimodal function responses INSIDE the response

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

## T5. Append inline instructions to function-response text, not as separate parts

Defect: extra instructions sent as separate `Part` items after a function
response. Causes thought leakage. Append to the function-response text
separated by two newlines:

```python
result_text = f"{json.dumps(result)}\n\n<extra instructions here>"
```

## T6. Reduce tool-call overuse with two levers in order

1. **Lower `thinking_level`** (`medium` → `low` → `minimal`). Higher
   thinking levels encourage tool use for exploration and verification.
2. **Add a system instruction** explicitly bounding tool calls. Example:
   "You have a limited action budget of N tool calls. Use them efficiently."

## T7. Combined tool use is supported in 3.x

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

## T8. Structured output + tools is a 3.x-only preview

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

## T9. Agentic workflows: port the 9-point planning template

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

## T10. Tool enablement by task type

Recommend in Key Changes by task type:

- Recent or obscure facts → enable Google Search grounding
  (`{"type": "google_search"}`).
- Any arithmetic, counting, or calculation → enable code execution
  (`{"type": "code_execution"}`); do not trust in-token computation.

## Verify after changes

- Function-call/function-result IDs and names match 1:1, one result per
  call.
- Stateless multi-turn callers resend every `thought` block and built-in
  tool step unmodified.
- Consumers of `steps[]` handle interleaved step types and the
  empty-summary case.
- Tool-call volume is bounded (T6) when the task has a fixed budget.

## Closing directive recap

This file extends the Gemini 3.x core reference for tool-using,
function-calling, agentic, and multi-turn prompts. Apply every T-rule
whose surface appears in the input, cite T-rule numbers in Key Changes,
and apply the core file's rules alongside. Per-criterion grading calls
and other single-shot no-tool prompts do not load this file.
