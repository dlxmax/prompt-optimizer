# Gemini 3.x prompt-content best practices

<role>
Reference material for the prompt-optimizer agent. Load when `Target model:`
declares `Gemini 3.6 Flash`, `Gemini 3.5 Flash`, `Gemini 3.5 Flash-Lite`,
`Gemini 3.1 Pro Preview`, `Gemini 3.1 Flash-Lite`, `Gemini 3 Flash Preview`,
`Gemini 3 Pro Preview`, or `Gemini 3.x`. Apply every numbered rule below to
the prompt under review; cite rule numbers in the optimizer's Key Changes
for deployer verification.

This file covers **prompt content and empirical findings only**: how to
word and structure a prompt or system instruction so a Gemini 3.x model
performs well, and what deployer production testing has revealed about
model choice and behavior under load. It does NOT cover documented API
call mechanics (model IDs, defaults, pricing, parameter wiring,
request/response shape, SDK versions) — that is the
`gemini-interactions-api` skill's job (rule 1), and it stays current across
model releases in a way a hand-maintained file cannot. Rules 8-10 are the
stated exception: empirical quality judgments and production behavior no
doc-fetching skill can know, since nobody at Google wrote them down.
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
default value and full valid level set: rule 1 — the enum is a mechanics
fact and can shift between model versions, so it is not hard-coded here).
That default is tuned for high-volume extraction, routing, and
classification, and can underperform on any task requiring multi-step
judgment — nuanced rubric-criterion grading, multi-clause AND-gated
descriptors, or anything else where the model needs to weigh evidence
rather than pattern-match. This escalation *policy* is an empirical
quality judgment, not an API mechanic, so it lives here rather than being
deferred: when a prompt targeting `gemini-3.5-flash-lite` fails to
produce the desired result at the default, recommend the caller test the
next level up (confirm the model's current valid levels via rule 1 before
naming one) before concluding the prompt itself is at fault; escalate
further only if the previous step still underperforms. Do not treat
repeated escalation as a signal to abandon the model — it's a signal the
task needs more than `minimal` gives it. See `GRADING_PIPELINE.md`
Artifact 5 for the
calibration-checklist version of this same diagnostic branch.

## 9. Empirical model choice by task type (probe-verified, not vendor guidance)

This reflects deployer production A/B testing, not Google's documentation
— the `gemini-interactions-api` skill does not know task-specific results,
so this stays hand-maintained regardless of rule 1. Every finding below
was tested on the prior model generation (`gemini-3.1-flash-lite`,
`gemini-3-flash-preview`, `gemini-2.5-*`) before `gemini-3.6-flash` and
`gemini-3.5-flash-lite` existed. Treat each specific model-to-task mapping
as a starting hypothesis to re-verify on the current generation, not a
standing fact — Google documents exactly the kind of improvement (fewer
reasoning steps, stronger multimodal/reasoning scores on Flash-Lite) that
would change some of these verdicts. The patterns below the table are the
durable part; recommend re-testing before porting a specific verdict.

| Task type | Model that won, as tested | Why | Currency |
|---|---|---|---|
| Open-ended multimodal extraction (transcription, speaker labeling, phase detection) | `gemini-3.5-flash` (free tier) | Matched paid `gemini-2.5-pro` exactly on a multi-speaker code-switched video; free-tier `gemini-3.1-flash-lite`/`gemini-2.5-flash` under-counted speakers or mislabeled phases | Still current; `gemini-2.5-pro` since lost production access |
| Constrained rubric-tier grading needing internally consistent verdicts | `gemini-3-flash-preview` over `gemini-3.5-flash` | `gemini-3.5-flash` produced internally inconsistent grades (all-praise justification text paired with a sub-Excellent tier) in one production chain; `gemini-3-flash-preview` held consistent | Re-verify: the same model (`gemini-3.5-flash`) won the extraction row above and lost here — task-specific, not a model ranking |
| TERMINAL-mode feedback register discipline | `gemini-3-flash-preview` over `gemini-3.1-flash-lite` | Flash-Lite lapsed to draft-register phrasing, used banned forward-framing language, doubled point values, and had an intermittent JSON truncation failure on first pass | Re-verify on `gemini-3.5-flash-lite` before assuming this persists |
| Discrimination/distractor-construction (odd-one-out-style items) | `gemini-3.5-flash` over `gemini-3.1-flash-lite` | Flash-Lite built distractors around surface word-form patterns (e.g. picking the one gerund among plain nouns) rather than genuine semantic outliers; a stricter surface-uniformity prompt gate made this worse on Flash-Lite specifically while being neutral-to-helpful on 3.5-flash | Re-verify on `gemini-3.5-flash-lite`, which Google documents as stronger on reasoning/multimodal benchmarks than 3.1 Flash-Lite |
| Narrow perceptual tasks (handwriting OCR) | `gemini-3.1-flash-lite` over heavier models | The cheaper/lighter model outperformed a reasoning-tier model on this specific narrow perceptual task | Directionally durable: don't assume a "smarter" model wins a narrow perceptual task |
| Semantic claim-vs-finding verification (does a citation's claim match what it actually found) | Gemini-class over Gemma-class | Independent prompt-wording iterations failed to close a Gemma 4 ceiling on this task; a Gemini reasoning model got it right on the same prompt | See `GEMMA4_API_BEST_PRACTICES.md` for the Gemma-side ceiling; route this sub-step to Gemini even inside an otherwise-Gemma pipeline |
| Coarse binary classification (screening only, not graded tiers) | `gemini-3-flash-preview` | Best binary agreement among tested models on this axis, despite being weak on fine-grained tier classification on the same data (see row 2) | Illustrates the task-specificity principle below more than a standing recommendation |

**Cross-cutting patterns (durable across generations):**

- **Model rankings are task-specific, not global.** The same model won an extraction task and was dropped from a grading-tier task in the same production codebase; the same model won binary screening and lost tier-granular classification on the same underlying data. Never port a win on one task type to a different task type without re-testing; do not emit a family-wide "this model is good" or "this model is bad" verdict from a single task's result.
- **Lite-tier models tend toward surface-pattern matching over semantic judgment** on tasks requiring discrimination between real and superficially similar content — recall gaps on implicit evidence in grading tasks, surface-feature gaming in item-construction tasks. Mitigate with an explicit enumeration/scan requirement (forces the surface-vs-semantic gap into a checkable list, per the scan-then-judge pattern in `FEEDBACK_GENERATION.md` F3), but budget for a second-order cost: piling more prompt-side scan requirements onto a small model can crowd out its attention for other prompt-carried rules. When a fix genuinely competes with another rule for the model's attention, move the competing rule to code-side enforcement rather than adding more prompt text.
- **A bigger/smarter model is not automatically better for a given task**, and may not be worth its cost: a documented finding rejected upgrading a task to a heavier reasoning model specifically because it shared the same constrained quota bucket as the existing model with no quality edge on that task, while being slower. Check both quota-sharing and task-relevant quality gain before recommending a step up in model tier.
- **A single clean benchmark run is the upper tail of variance, not a stable baseline**, at default sampling. Treat a single clean result as optimistic; recommend at least a small multi-run check before declaring a model the winner, especially on a close call.
- **A same-family "gold standard" inflates agreement.** Labels generated by one model family and then graded by the same family showed near-perfect agreement that dropped sharply against an independent, non-LLM ground truth. When benchmarking a model choice, prefer an independent ground truth over another LLM's opinion, especially one from the same family as the model under test.

## 10. Quota and rate-limit behavior the hosted docs don't fully cover

Empirical production findings, not documented API mechanics — an
exception to rule 1's skill-deferral, the same way rule 8 is: a
doc-fetching skill will not surface behavior nobody at Google wrote down,
only what was observed under load.

- `gemini-3.1-flash-lite` has an empirically confirmed per-minute token
  ceiling well below its context window. A generic auto-retry loop (short
  fixed sleep, many attempts) on a long prompt can exhaust it within one
  wall-clock minute, producing repeated zero-output failures that read as
  model failures but are pacing failures. For long-prompt Flash-Lite work,
  prefer single-shot calls with wide spacing (90+ seconds) over blind
  auto-retry; re-verify whether this ceiling still applies to
  `gemini-3.5-flash-lite` before assuming it carries over unchanged.
- On the legacy `generateContent` surface, classify a 429's real severity
  by the `retryDelay` field on `RetryInfo` (short: transient, retry the
  same model; long: real exhaustion, rotate keys or advance to the next
  model in the chain) rather than by the `quotaId` substring — a
  `"PerDay"` string can appear even on a short rolling-window RPM
  throttle and is not reliable on its own.
- The Interactions API's 429 response is a **different, strictly worse
  shape**: HTTP 200 with an SSE-embedded error, no `retryDelay`/`quotaId`/
  scope fields at all. The `retryDelay` classifier above does not apply
  there; use a persistence-based circuit breaker (track consecutive
  failures over a time window) instead of trying to parse severity out of
  the response.

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
  grading, AND-gated descriptors) get a next-level-up `thinking_level`
  test recommendation, not a silent default-`minimal` assumption (rule 8).
- A recommended model swap (rule 9) names its currency caveat — tested on
  which generation, re-verify before porting — rather than being stated
  as a standing fact.
- Any 429/quota troubleshooting recommendation matches the actual
  surface in use (`generateContent` `retryDelay` classifier vs.
  Interactions API circuit breaker; rule 10) rather than assuming one
  applies to both.

## Closing directive recap

This file is imperative reference for the prompt-optimizer agent when
`Target model: Gemini 3.x` is declared, scoped to prompt content and
empirical findings (rules 8-10 are the stated exception to "mechanics
defer to the skill").
Apply every numbered rule to the prompt under review and cite rule
numbers in Key Changes. For current model IDs, defaults, pricing, and
every other documented API-mechanics or migration fact, recommend the
`gemini-interactions-api` skill (rule 1) instead of answering from this
file or from memory; for empirically-tested model choice by task type
(rule 9) or production quota/rate-limit behavior (rule 10), this file is
the source of truth precisely because the skill cannot know it. Legacy
`:generateContent` wiring additionally loads `GEMINI_MIGRATION.md`.
