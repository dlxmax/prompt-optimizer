# Gemini 3.x prompt-content best practices

<role>
Reference material for the prompt-optimizer agent. Load when `Target model:`
declares `Gemini 3.6 Flash`, `Gemini 3.5 Flash`, `Gemini 3.5 Flash-Lite`,
`Gemini 3.1 Pro Preview`, `Gemini 3.1 Flash-Lite`, `Gemini 3 Flash Preview`,
`Gemini 3 Pro Preview`, or `Gemini 3.x`. Apply every numbered rule below to
the prompt under review; cite rule numbers in the optimizer's Key Changes
for deployer verification.

This file covers **prompt content only**: how to word and structure a
prompt or system instruction so a Gemini 3.x model performs well. It does
NOT cover API call mechanics (model IDs, defaults, pricing, parameter
wiring, request/response shape, SDK versions) — that is the
`gemini-interactions-api` skill's job (rule 1), and it stays current across
model releases in a way a hand-maintained file cannot.
</role>

<scope>
The Gemini 3.x family: `gemini-3.6-flash`, `gemini-3.5-flash`,
`gemini-3.5-flash-lite`, `gemini-3.1-pro-preview`, `gemini-3.1-flash-lite`,
and `gemini-3-flash-preview`. (`gemini-3-pro-preview` shut down 2026-03-09
— treat as a legacy string; migrate to `gemini-3.1-pro-preview`.) Model
selection, current defaults/pricing, and every API-mechanics fact are the
`gemini-interactions-api` skill's job, not this file's (rule 1). For Gemma
4 targets read `GEMMA4_API_BEST_PRACTICES.md`; for DeepSeek V4 targets
read `DEEPSEEK_V4_API_BEST_PRACTICES.md`.
</scope>

## 1. API mechanics are the gemini-interactions-api skill's job, not this file's

Never answer from this file, training data, or memory for: current model
IDs/pricing/defaults, parameter wiring (`temperature`/`top_p`/`top_k`
removal, `thinking_level` vs `thinking_budget`, `response_format` schema
wiring, tools-array shape), function-calling response matching,
multi-turn/thought-preservation mechanics, streaming, or SDK/migration
facts. In Key Changes, recommend the requestor invoke the
`gemini-interactions-api` skill before writing or reviewing any call-site
code — it fetches the current hosted docs page for the matching feature,
so it stays accurate across model releases. If the skill is unavailable,
fall back to a `gemini-api-docs-mcp` `search_docs` query scoped to the
unknown, and state your interim assumption either way. Legacy
`generateContent` wiring additionally loads `GEMINI_MIGRATION.md`
(cross-family migration facts the skill doesn't cover; same skill-first
policy applies there).

## 2. Long-context: place query at the end, anchored to the context

For large context (entire books, codebases, long videos, student
submissions), place the query/question at the END after the data; ending
with the query measurably improves performance. Apply this shape:

- Governing directives (role, output schema, refusal rules) at the START.
- Large context block (data, transcripts, submissions) in the MIDDLE.
- The user's specific query/question at the END, anchored with "Based on
  the preceding information..." or a domain-specific equivalent.
- Repeat the governing directive at the very end as a recency reminder
  (universal start-and-end rule still holds).

## 3. Prompting changes for 3.x

Enforce these converged 3.x prompting rules:

- **Precise instructions:** be concise. Gemini 3.x responds best to
  direct, clear instructions. Verbose or complex prompt engineering
  techniques designed for older models cause the model to over-analyze
  on 3.x. Drop chain-of-thought scaffolding like
  "think step by step in detail before answering"; recommend the caller
  tune `thinking_level` instead (mechanics: see rule 1).
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
  OR at the very beginning of the user prompt; do not bury them after
  long context or examples. The start-and-end recency rule for the
  governing directive still applies as a closing reminder.
- **Multimodal equal-class:** when the prompt accepts images, audio, or
  video alongside text, reference each modality explicitly in the
  instructions; do not name only the text input when an image is also
  passed.
- **Thinking-boost lever (narrow fallback):** for heavy reasoning where
  the highest `thinking_level` is not enough, the clause "Think very hard
  before answering" improves performance at the cost of extra thinking
  tokens. Deploy only after the highest level has been tried and named
  insufficient; do not deploy as default scaffolding.
- **Context management:** see rule 2 above.

## 4. Gemini 3 Flash freshness and grounding clauses

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
  knowledge cutoff so the model defers to grounding for post-cutoff facts
  instead of answering from parametric memory (confirm the current
  cutoff via rule 1 if in doubt — it moves with each model release).
- **Strict-grounding clause** (RAG / context-only answering; grading and
  judge prompts over a submission): instruct the model to rely ONLY on
  facts in the provided context or submission, never its own knowledge or
  inference, to treat anything not in the context as unsupported, and to
  state when the answer or evidence is not present. Single
  highest-leverage clause for hallucination-sensitive grounded
  deployments, including rubric graders whose comments must be anchored
  in the student's text.

## 5. Reduce tool-call overuse with two levers in order

1. **Lower the thinking level** (mechanics: rule 1). Higher thinking
   levels encourage tool use for exploration and verification.
2. **Add a system instruction** explicitly bounding tool calls. Example:
   "You have a limited action budget of N tool calls. Use them
   efficiently."

## 6. Agentic workflows: port the 9-point planning template

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

## 7. Tool enablement by task type

Recommend in Key Changes by task type:

- Recent or obscure facts → enable Google Search grounding.
- Any arithmetic, counting, or calculation → enable code execution; do
  not trust in-token computation.

(Exact tool-declaration syntax is call-site mechanics: rule 1.)

## 8. Flash-Lite's `minimal` default may need escalation

`gemini-3.5-flash-lite` defaults `thinking_level` to `minimal` (current
default value: rule 1). This is an empirical quality judgment, not an API
mechanic, so it lives here rather than being deferred: `minimal` is tuned
for high-volume extraction, routing, and classification, and can
underperform on any task requiring multi-step judgment — nuanced
rubric-criterion grading, multi-clause AND-gated descriptors, or anything
else where the model needs to weigh evidence rather than pattern-match.
When a prompt targeting `gemini-3.5-flash-lite` fails to produce the
desired result at the default, recommend the caller test
`thinking_level: "low"` before concluding the prompt itself is at fault;
raise further to `medium`/`high` only if `low` still underperforms. Do
not treat repeated escalation as a signal to abandon the model — it's a
signal the task needs more than `minimal` gives it. See
`GRADING_PIPELINE.md` Artifact 5 for the calibration-checklist version of
this same diagnostic branch.

## Moved content

Second-level routing; loads are additive to this file:

- **`GEMINI_MIGRATION.md`** — cross-family migration facts the
  `gemini-interactions-api` skill doesn't cover (tools + response_format
  scope across families, Gemma 4 schema-shape porting, prefilled
  model-turn validation). Load when legacy `generateContent` forms appear
  anywhere in the input; one-time-per-prompt reference.

## Verify after changes

- No API-mechanics claim (model ID, parameter, endpoint, request/response
  shape) was answered from this file instead of the skill (rule 1).
- Long-context prompts end on the query, not the data (rule 2).
- Chain-of-thought scaffolding is replaced with a `thinking_level`
  recommendation, not left in place (rule 3).
- Flash grounding/freshness clauses are present when the task is
  time-sensitive, knowledge-grounded, or a grading/judge task over
  submitted work (rule 4).
- Agentic system instructions carry the 9-point planning block when the
  workflow is agentic (rule 6).
- `gemini-3.5-flash-lite` targets with multi-step judgment tasks (rubric
  grading, AND-gated descriptors) get a `thinking_level: "low"` test
  recommendation, not a silent default-`minimal` assumption (rule 8).

## Closing directive recap

This file is imperative reference for the prompt-optimizer agent when
`Target model: Gemini 3.x` is declared, scoped to prompt content only.
Apply every numbered rule to the prompt under review and cite rule
numbers in Key Changes. For every API-mechanics, model-selection, or
migration fact, recommend the `gemini-interactions-api` skill (rule 1)
instead of answering from this file or from memory. Legacy
`:generateContent` wiring additionally loads `GEMINI_MIGRATION.md`.
