# DeepSeek V4 API best practices

Authoritative reference for the DeepSeek API and the local chat-template
surface when targeting `deepseek-v4-pro` and `deepseek-v4-flash`. Compiled
May 19, 2026 from the launch announcement (April 24, 2026), the official
API guides, the V4-Pro model card on HuggingFace, and the `encoding_dsv4.py`
chat-template reference. Scope: API call mechanics and prompt-text
implications. For prompt-text guidance, use the `prompt-optimizer` agent
with `Target model: DeepSeek V4` declared; this file is the reference the
agent reads to apply that target.

## Surfaces in scope

DeepSeek V4 ships under three call surfaces; rules below note which one
they apply to:

1. **Native OpenAI-compatible REST** at `https://api.deepseek.com`. Default
   target for code-parsed deployments.
2. **Anthropic-compatible REST** at `https://api.deepseek.com/anthropic`.
   Subset of capabilities (see rule 10).
3. **Local chat-template** (vLLM, SGLang, llama.cpp, Transformers via
   `encoding_dsv4.py`). The model ships with a Python encoding script, not
   a Jinja template, and uses DSML markup for tool calls (see rule 12).

When a rule is surface-specific, it is tagged `[OpenAI]`, `[Anthropic]`,
or `[Local]`.

## 1. Thinking mode is enabled by default; disable it for deterministic JSON

V4 reasons by default on both V4-Flash and V4-Pro. The model emits
`reasoning_content` alongside `content` and per-call wall-clock balloons
to tens of seconds even on trivial prompts.

For any code-parsed JSON output, disable thinking:

```python
extra_body={"thinking": {"type": "disabled"}}
```

The `type` field accepts `enabled` (default) or `disabled`. There is no
"low" or "medium" thinking level on V4: `reasoning_effort` accepts only
`high` or `max`; `low`/`medium` silently remap to `high`; `xhigh` remaps
to `max`. For agent harnesses (Claude Code, OpenCode), the API
auto-promotes effort to `max`.

When thinking is disabled, the model returns a single `content` field
and `reasoning_content` is absent.

## 2. JSON mode requires the literal word "json" in the prompt

`response_format={"type": "json_object"}` is the only JSON-shape
enforcement V4 exposes; there is no `responseSchema` analogue on the
native API. Two prompt-text consequences:

- The system OR user message MUST contain the word "json" (the docs are
  explicit). Without it, the model can emit an unending stream of
  whitespace until `max_tokens` is hit — the request appears to hang.
- Include a concrete JSON example block. The docs state "the API may
  occasionally return empty content" and the recommended mitigation is
  "modify the prompt" — concretely, providing an example input and
  example JSON output reduces the empty-response rate.

JSON mode does not bind a schema. The prompt carries the schema in prose
and the caller validates the parsed output. Pair with `max_tokens` set
generously so truncation does not corrupt the JSON.

## 3. JSON mode may return empty content; retry policy is parameter change, not same-call

Documented: "the API may occasionally return empty content" under JSON
mode. Repeating the same call with the same parameters fails the same
way. Recovery options:

- Step temperature down (e.g., 1.0 → 0.85 → 0.7).
- Add or expand the in-prompt JSON example.
- Reduce prompt-text drift by tightening the schema description.

Do not budget an unbounded retry loop on the same parameters.

## 4. Thinking mode silently ignores `temperature`, `top_p`, presence and frequency penalties

When thinking is enabled, the request body's `temperature`, `top_p`,
`presence_penalty`, and `frequency_penalty` are accepted without error
but have no effect on generation. This is documented behavior for
compatibility. To control output randomness on V4, disable thinking
first (rule 1), then set the sampling parameters.

## 5. `presence_penalty` and `frequency_penalty` are deprecated

The API reference flags both as deprecated. They are silently no-ops on
both thinking and non-thinking modes. Remove them from request bodies;
do not lean on them in prompt text either ("avoid repetition" must be a
directive, not a sampling-parameter assumption).

## 6. Strict tool-calling requires the `/beta` endpoint and a constrained schema [OpenAI]

The default `tools` field returns "best-effort" JSON; arguments may
hallucinate parameters not in the schema. Strict mode forces the model
to emit schema-conformant arguments, at the cost of three constraints:

1. `base_url="https://api.deepseek.com/beta"` (the Beta endpoint).
2. Every `function` in `tools` sets `"strict": true`.
3. The server validates the JSON Schema and rejects with an error if it
   does not conform.

Strict-mode schema rules (these are prompt-design constraints, not just
schema mechanics):

- Every `object` must set `additionalProperties: false` and list every
  property in `required`. There is no "optional field" concept under
  strict mode.
- `string` accepts `pattern` and `format` (`email`, `hostname`, `ipv4`,
  `ipv6`, `uuid`) but rejects `minLength` and `maxLength`.
- `array` rejects `minItems` and `maxItems`.
- Supported types are `object`, `string`, `number`, `integer`, `boolean`,
  `array`, `enum`, `anyOf`, plus `$ref`/`$def` for reuse and recursion.
- Maximum 128 functions per call.

Length and count constraints must live in the prompt body, not in the
schema.

## 7. `reasoning_content` must be passed back in all subsequent requests after a tool call [OpenAI]

Once an assistant turn carries `tool_calls`, the matching
`reasoning_content` from that turn must be passed back in every later
request that continues the conversation. Missing it returns HTTP 400.

In contrast, when an assistant turn carried no tool call,
`reasoning_content` from prior turns is server-side-ignored on the next
request. Including it costs nothing structurally but wastes tokens.

The simplest correct pattern is to append the full
`response.choices[0].message` object to the message history; that object
already carries `content`, `reasoning_content`, and `tool_calls` in the
shape the API expects.

## 8. Tool-result message ordering matters when a turn produces multiple calls [OpenAI, Local]

When an assistant turn emits multiple `tool_calls`, the subsequent
`role: "tool"` messages must appear in the same order as the calls were
issued. Local chat-template paths sort `<tool_result>` blocks by the
order of the corresponding tool calls in the preceding assistant message.
For prompts that orchestrate ordered tool dependencies (call B uses
output of A), state the ordering explicitly in the prompt rather than
relying on the model to infer it from prose.

## 9. Cache hits require full prefix-unit match; structure prompts for cache reuse

V4 uses sliding-window attention (DSA: DeepSeek Sparse Attention) with a
disk-based prefix cache. Cache prefix units are persisted at three
points:

1. End of each user input and end of each model output (each call
   produces two cache units).
2. Common prefix detected across multiple requests.
3. Fixed token intervals for long inputs or long outputs.

A subsequent request only hits the cache if it **fully** matches a
persisted prefix unit. Practical consequences:

- Put stable instructions (role, schema, evaluation criteria) at the
  very top so they participate in every cache unit.
- Volatile content (timestamps, request IDs) at the top kills cache
  hits.
- The `usage` field returns `prompt_cache_hit_tokens` and
  `prompt_cache_miss_tokens` — monitor these to verify the structure is
  cache-friendly.

Output randomness is unaffected by cache state; cached and fresh calls
produce different completions when temperature is non-zero.

## 10. The Anthropic-compatible endpoint drops several primitives [Anthropic]

`https://api.deepseek.com/anthropic` accepts Anthropic SDK requests but
strips capabilities:

| Field | Status |
|---|---|
| `response_format={"type": "json_object"}` | Not exposed (no equivalent in Messages API) |
| `top_k` | Ignored |
| `cache_control` (on tools or messages) | Ignored |
| `citations`, `is_error` | Ignored |
| `thinking.budget_tokens` | Ignored; only `output_config.effort` works |
| `image`, `document`, `search_result`, `web_search_tool_result`, `mcp_tool_use`, `mcp_tool_result`, `container_upload`, `code_execution_tool_result`, `server_tool_use` | Not supported |
| Unknown `model` value | Silently mapped to `deepseek-v4-flash` |

The unknown-model silent remap is the load-bearing gotcha: deploying
"deepseek-v4-pro-max" or any other invented variant degrades silently to
Flash. Validate the model name string explicitly before dispatch.

If the deployment needs JSON-shape enforcement, use the OpenAI-compatible
endpoint, not the Anthropic one.

## 11. `reasoning_effort="max"` already prepends a thoroughness preamble; do not duplicate [Local]

The `encoding_dsv4.py` reference adds a built-in system-level preamble
when `reasoning_effort="max"` is set:

> "Reasoning Effort: Absolute maximum with no shortcuts permitted. You
> MUST be very thorough in your thinking and comprehensively decompose
> the problem to resolve the root cause, rigorously stress-testing your
> logic against all potential paths, edge cases, and adversarial
> scenarios. Explicitly write out your entire deliberation process,
> documenting every intermediate step, considered alternative, and
> rejected hypothesis to ensure absolutely no assumption is left
> unchecked."

This is prepended BEFORE the system message. Prompts that hand-roll a
"think very carefully" preamble at the top of the system prompt stack
with this one. On the REST API the same string mapping holds: setting
`reasoning_effort="max"` enables this preamble internally; prompt-text
duplication adds tokens without benefit.

## 12. Local chat-template uses DSML markup, not OpenAI tool tokens [Local]

The V4 release does NOT ship a Jinja chat template. Local deployments
must use `encoding_dsv4.py` (`encode_messages` and
`parse_message_from_completion_text`). The format diverges from prior
DeepSeek models in two places:

**Chat-mode opening (`thinking_mode="chat"`)** places an orphan close-tag
right after the assistant prefix to immediately close the (empty)
thinking block before content:

```
<｜begin▁of▁sentence｜>{system}
<｜User｜>{message}<｜Assistant｜></think>{response}<｜end▁of▁sentence｜>
```

The `</think>` BEFORE any `<think>` is intentional; the model treats the
thinking block as already-closed and emits content directly.

**Tool calls use DSML format**, not OpenAI-style `function`/`arguments`
text:

```
<｜DSML｜tool_calls>
<｜DSML｜invoke name="$TOOL_NAME">
<｜DSML｜parameter name="$PARAM" string="true|false">$VALUE</｜DSML｜parameter>
</｜DSML｜invoke>
</｜DSML｜tool_calls>
```

`string="true"` carries a raw string; `string="false"` carries JSON
(numbers, booleans, arrays, objects). The token delimiters are
full-width Unicode pipes (U+FF5C), not ASCII pipes.

Tool results wrap in `<tool_result>` tags inside user messages. Multiple
results sort by the order of the corresponding `tool_calls` in the
preceding assistant message.

Prompts that demonstrate tool use must match the surface. For REST
deployments, OpenAI shape works; for local chat-template deployments,
example tool calls in the prompt should use DSML.

## 13. Local sampling defaults: T=1.0, top_p=1.0 [Local]

The HuggingFace V4-Pro model card recommends `temperature=1.0,
top_p=1.0` for local inference. This differs from V3's recommendation
and from the API surface (where `top_p` default is 1.0 and `temperature`
default is 1.0; both are accepted up to 2.0). T=0 is not recommended on
V4 in any deployment surface.

For Think Max reasoning mode, the model card also recommends a context
window of at least 384K tokens — the model expands reasoning to fill
available budget.

## 14. `drop_thinking` defaults to True without tools, False with tools [Local]

In the local encoding, `drop_thinking=True` (the default) strips
reasoning content from assistant turns BEFORE the last user message;
only the most recent assistant turn retains its `<think>...</think>`
block. When tools are defined on the system or developer message,
`drop_thinking` is automatically forced to False — multi-step tool
reasoning needs full context.

REST API behavior (rule 7) mirrors this: server-side strips
`reasoning_content` from old turns without tool calls, requires it
preserved on turns with tool calls.

## 15. `finish_reason` includes `insufficient_system_resource`; treat as retryable

V4's `finish_reason` enum includes a value not present on most
OpenAI-compatible APIs:

| finish_reason | Meaning |
|---|---|
| `stop` | Natural stop or stop sequence |
| `length` | Hit `max_tokens` |
| `content_filter` | Server-side filter triggered |
| `tool_calls` | Model called a tool |
| `insufficient_system_resource` | Inference interrupted by capacity |

`insufficient_system_resource` is a transient and should be retried with
exponential backoff. The `content_filter` finish does not signal a
prompt defect alone; surface the result and investigate before
re-prompting.

## 16. Streaming and scheduling: tolerate empty lines and SSE keep-alive

While a request waits for inference scheduling, the API emits:

- Non-streaming: continuous empty lines on the open HTTP connection.
- Streaming: SSE keep-alive comments (`: keep-alive`).

These do not contain JSON. A naive line-by-line parser that assumes
every non-blank line is content will break. The connection is closed
after 10 minutes if inference has not started; budget that ceiling into
client timeouts.

## 17. 5xx retry policy: 429 is dynamic-concurrency, not exhausted

Rate-limit handling on V4 is fundamentally different from per-user-quota
APIs:

- `429 Rate Limit Reached` reflects **current server concurrency**, not
  an exhausted quota. Back off and retry on the same model. Do not
  advance a fallback chain on 429.
- `500 Server Error` and `503 Server Overloaded` are transient. Standard
  exponential backoff (e.g., 1s + 10s + 30s).
- DeepSeek's recommendation: "temporarily switch to alternative LLM
  service providers" if 429 persists — there is no per-account quota
  increase available.

There is no `quotaId.PerDay` distinction analogous to the Gemini Free
tier; 429 is purely transient.

## 18. Chat prefix and FIM completion are Beta endpoints with shape constraints

Two Beta features require `base_url="https://api.deepseek.com/beta"`:

**Chat Prefix Completion** — force the model to start its reply with a
specific string. Last message in `messages` must have `role="assistant"`,
`prefix=True`, and `content` set to the desired opening. Pair with
`stop=["```"]` (or similar) to bound the completion. Useful when the
prompt format is rigid (e.g., always-JSON outputs) and worth more than
the regular chat-completion shape.

**FIM Completion** — fill-in-the-middle for code or text completion via
`/completions` (not `/chat/completions`). Max output: 4K tokens. Pass
`prompt` and `suffix`; the model fills between. Non-thinking mode only;
the thinking-mode FIM path is not supported.

## 19. Deprecated model names route to V4-Flash and retire 2026-07-24

`deepseek-chat` and `deepseek-reasoner` route through to V4-Flash
non-thinking and thinking modes respectively until 2026-07-24, 15:59
UTC. After that date, requests using those names return errors. Prompts
that hard-code the legacy names must migrate to `deepseek-v4-flash` or
`deepseek-v4-pro` with explicit `extra_body.thinking` control.

## 20. KV cache user isolation via `user_id`

The `user_id` request parameter (max 512 chars, `[a-zA-Z0-9\-\_]`)
isolates KV cache between users. Required for any multi-tenant
deployment where cache cross-contamination is a privacy concern. The
docs note: "Do not include user privacy information in the `user_id`."
Use opaque identifiers (UUID, hashed account ID), not email addresses.

## Verify after changes

For each code-parsed path: sample N=12 calls. Expect `finish_reason=stop`
on all twelve, parseable JSON via the JSON parser, and zero empty
`content` responses. If any of those fail:

- Empty content under JSON mode → rule 2 (add example, ensure "json"
  literal) or rule 3 (parameter change, not same-call retry).
- Hang or 10-minute timeout → schema in prose was ambiguous; tighten.
- 400 on a tool-bearing follow-up turn → rule 7 (forward
  `reasoning_content` from the prior tool-using assistant turn).
- 429 burst → rule 17 (back off, do not chain-advance).
- Unexpected Flash behavior on a Pro request via Anthropic endpoint →
  rule 10 (model name validation).
