# Gemini-to-Ornith 1.5 migration reference

<role>
Reference for prompt-optimizer. Load ONLY when the caller message carries the
line `Migrate: gemini-to-ornith-1.5`. Never infer it: an Ornith target, a
Gemini source prompt, or both together without that line do not load this
file. Applies on top of the declared shape and domain; it adds port findings,
it does not replace the shape's checklist.

Source: a prompt written for Gemini (3.x Interactions, legacy `generateContent`,
or Gemma 4 via Interactions). Target: Ornith 1.5 9B (GGUF) served by Ollama,
OpenAI-compatible `/v1/chat/completions` preferred, native `/api/chat` second.
No other variant or server is in scope. "Probe-confirmed" = observed on Ollama
0.40.1, Q6_K; everything else is from the model card: report it as
re-verify-on-target.
</role>

## 1. Request shape

1. Gemini `system_instruction` / `systemInstruction.parts` -> leading
   `{"role": "system"}` message. Interactions `input` / legacy
   `contents: [{role, parts}]` -> `messages`; role `model` -> `assistant`.
2. Gemini-only fields have no equivalent: `store`, `thinking_level`,
   `thinking_budget`, `safety_settings`, `media_resolution`, `cached_content`.
   Flag each; remove, never map by guess.
3. System text belongs at the start only. Two leading system messages are
   merged and both obeyed; a system message after the first user turn is
   silently ignored (probe-confirmed). Flag any mid-conversation system
   message; fold it into the leading one.
4. Trailing `assistant` prefill: skips thinking, the reply repeats the prefill
   text, and output quality drops (probe-confirmed). Flag; replace with an
   instruction or structured output.

## 2. Thinking

1. On by default; the trace returns in `message.reasoning` (OpenAI path) or
   `message.thinking` (native), never inline in `content` (probe-confirmed).
   Read the answer from `content` only.
2. Gemini's graded `thinking_level` collapses to on/off. Off
   (probe-confirmed):
   2.1. OpenAI path: `reasoning_effort: "none"`. `think: false` on this path
        is ignored and thinking stays on.
   2.2. Native path: `think: false`.
   2.3. `/no_think` or `/nothink` in prompt text is inert: flag and remove.
3. Thinking spends `max_tokens`. Undersized budget -> `finish_reason:
   "length"` with truncated or empty `content` (probe-confirmed). Gemini
   budgets sized for the answer alone carry over too small: flag; floor 1000,
   more for long answers, and treat `length` as a failure in the parser.
4. The template keeps prior-turn reasoning in history: replaying it grows
   context fast against the 98,304-token window (model card behavior,
   re-verify). Name whether the call-site replays it.
5. Off trades multi-step quality for latency: keep on for grading, multi-hop,
   and tool-planning calls; off is a remove-and-retest choice, never a default.

## 3. Sampling

1. Card defaults by task. General: `temperature` 1.0, `top_p` 0.95, `top_k`
   20, `min_p` 0, `presence_penalty` 1.5. Precise coding: `temperature` 0.6,
   `presence_penalty` 0. Ollama ships none of these as defaults: set them per
   request. Drop carried-over Gemini values.
2. Greedy (`temperature` 0) on a thinking model is a repetition risk: flag a
   carried-over 0 used to force determinism; recommend a parser-side check
   instead.

## 4. Structured output

1. Gemini `response_format` / `responseSchema` -> OpenAI
   `response_format: {"type": "json_schema", "json_schema": {"name", "schema",
   "strict": true}}`. Works with thinking on or off; the grammar applies to
   `content`, not the trace (probe-confirmed).
2. Enforcement is hard: an enum with no correct option returns a confident
   wrong value, never a refusal (probe-confirmed). Every closed-set schema
   needs an escape value (`unknown`, `not_applicable`) where the input allows
   no valid answer.
3. Gemini schema-subset quirks (`propertyOrdering`, enum handling) do not
   carry: strip Gemini-only keywords.

## 5. Tools

1. Gemini `function_declarations` -> OpenAI `tools: [{"type": "function",
   "function": {...}}]`. Calls return parsed in `tool_calls` with
   `finish_reason: "tool_calls"`, `arguments` as a JSON string; replaying them
   as-is in an `assistant` turn plus a `role: "tool"` result works
   (probe-confirmed). Works with thinking off.
2. The template tells the model reasoning goes before a call, never after:
   flag prompt text asking for commentary after a tool call.
3. Few-shot tool-call examples in prompt text: 9B renders non-string scalars
   Python-style (`True`, `None`). JSON-style examples copied from Gemini
   mismatch the training format: flag, or drop the examples and rely on the
   `tools` schema.
4. Gemini built-ins (Google Search grounding, code execution, URL context)
   have no equivalent: flag each as a feature loss needing an external tool.

## 6. Prompt text and capacity

1. Remove Gemini-specific instructions: grounding, citations metadata, Gemini
   persona names, `thinking_level` advice embedded in prose.
2. A 9B model is not a frontier model: rules that held on Gemini may need
   splitting. Apply the generic decompose signal.
3. Served window is 98,304 tokens, far below Gemini's. Long-context prompts ->
   flag truncation; state the assumed input size.
4. One request at a time, one model loaded: a Gemini call-site that fans out
   in parallel or mixes models per job serializes and reloads. Flag as
   throughput loss, not a prompt defect.

## Report

Key Changes lists each port finding as `Port: <item> -> <action>`, suffixed
`(re-verify on target)` unless the item is probe-confirmed.
