# Gemini 3.x prompt-content best practices

<role>
Reference for prompt-optimizer. Load when `Target model:` declares `Gemini 3.6
Flash`, `Gemini 3.5 Flash`, `Gemini 3.5 Flash-Lite`, `Gemini 3.1 Pro Preview`,
`Gemini 3.1 Flash-Lite`, `Gemini 3 Flash Preview`, `Gemini 3 Pro Preview`, or
`Gemini 3.x`. Apply every numbered rule; cite rule numbers in Key Changes.

**Prompt content and empirical findings only**: how to word and structure a
prompt or system instruction so a Gemini 3.x model performs well, plus what
deployer production testing revealed about model choice and behavior under
load. NOT documented API mechanics (model IDs, defaults, pricing, parameter
wiring, request/response shape, SDK versions) — the `gemini-interactions-api`
skill's job (rule 1), current across releases in a way a hand-maintained file
cannot be. Rules 8-10 are the stated exception: empirical quality judgments and
production behavior no doc-fetching skill can know, because nobody at Google
wrote them down.
</role>

<scope>
Family: `gemini-3.6-flash`, `gemini-3.5-flash`, `gemini-3.5-flash-lite`,
`gemini-3.1-pro-preview`, `gemini-3.1-flash-lite`, `gemini-3-flash-preview`.
(`gemini-3-pro-preview` shut down 2026-03-09 — legacy string; migrate to
`gemini-3.1-pro-preview`.)

**Surface scope.** Interactions API only. Evidence written against
`generateContent` — doc page, example, forum answer — neither confirms nor
overrides an Interactions fact, and is never ported to an Interactions call
without verification; Google documents both surfaces under shared paths, so
check which endpoint an example calls before treating it as evidence. Legacy
wiring in a prompt or call-site = migration defect (`GEMINI_MIGRATION.md`),
never an alternative to recommend.

Only `gemini-3.6-flash`, `gemini-3.5-flash-lite`, `gemini-3.1-pro-preview`,
`gemini-3.1-flash-lite` appear in the skill's current-model list; the rest are
migration sources. Which strings are live, plus current defaults/pricing and
every API-mechanics fact = the skill's job (rule 1). Gemma 4 →
`GEMMA4_API_BEST_PRACTICES.md`; DeepSeek V4 →
`DEEPSEEK_V4_API_BEST_PRACTICES.md`.
</scope>

## 1. API mechanics are the gemini-interactions-api skill's job

Never answer from this file, training data, or memory for: current model
IDs/pricing/defaults, parameter wiring (`temperature`/`top_p`/`top_k` removal,
`thinking_level` vs `thinking_budget`, `response_format` schema wiring,
tools-array shape), function-calling response matching,
multi-turn/thought-preservation, streaming, SDK/migration facts. In Key
Changes: recommend invoking the `gemini-interactions-api` skill before writing
or reviewing call-site code — it fetches the current hosted docs page per
feature, staying accurate across releases. Skill unavailable → fall back to a
`gemini-api-docs-mcp` `search_docs` query scoped to the unknown; state your
interim assumption either way. Legacy `generateContent` wiring additionally
loads `GEMINI_MIGRATION.md` (cross-family facts the skill doesn't cover; same
skill-first policy).

## 2. Long-context: query at the end, anchored to the context

Large context (books, codebases, long videos, student submissions) → query at
the END after the data; ending on the query measurably improves performance.
Shape:

- Governing directives (role, output schema, refusal rules) at START.
- Large context block (data, transcripts, submissions) in MIDDLE.
- Specific query at END, anchored "Based on the preceding information..." or domain equivalent.
- Governing directive repeated at the very end as recency reminder (universal start-and-end rule holds).

## 3. Prompting changes for 3.x

- **Precise instructions:** be concise. 3.x responds best to direct, clear instructions; verbose prompt-engineering techniques built for older models make it over-analyze. Drop chain-of-thought scaffolding ("think step by step in detail before answering"); recommend tuning `thinking_level` instead (mechanics: rule 1).
- **Output verbosity:** 3 and 3.1 are less verbose by default, preferring direct answers. Conversational tone required → steer explicitly ("Explain this as a friendly, talkative assistant"); never rely on defaults for it.
- **Consistent structure:** XML XOR Markdown for section delimiters. Pick one; convert the minority style. Anti-pattern: wrapping already-Markdown-delimited sections (`## 1. Foo`) in per-section XML tags (`<rule_1>`) "for scope" — the header already delimits, so the wrapper creates the mix this rule prohibits. Whole-document meta blocks (`<role>`, `<scope>`) are not section delimiters and may coexist with a Markdown body. Curly-brace substitution conventions are unrelated.
- **Critical-instructions placement:** persona, behavioral constraints, output format go in the System Instruction OR at the very beginning of the user prompt; never buried after long context or examples. Start-and-end recency rule still applies as a closing reminder.
- **Multimodal equal-class:** prompt accepts images, audio, or video alongside text → reference each modality explicitly in the instructions; never name only the text input when an image is also passed.
- **Thinking-boost lever (narrow fallback):** heavy reasoning where the highest `thinking_level` is not enough → "Think very hard before answering" improves performance at the cost of thinking tokens. Only after the highest level has been tried and named insufficient. Never default scaffolding.
- **Context management:** rule 2.

## 4. Gemini 3 Flash freshness and grounding clauses

Flash system-instruction clauses (Gemini 3 Flash family; absent by default,
each high-ROI for its failure mode). Recommend in Key Changes when the target
is Flash AND the task is time-sensitive, knowledge-grounded, RAG-style, or a
grading/judge task over submitted work:

- **Current-day clause** (time-sensitive queries, tool-call freshness): instruct the model to follow the provided current date and year when forming search queries, stating the year explicitly (2026). Flash otherwise defaults to stale assumptions about "now".
- **Knowledge-cutoff clause** (facts near the boundary): state the cutoff so the model defers to grounding for post-cutoff facts instead of parametric memory (confirm the current cutoff via rule 1 — it moves with each release).
- **Strict-grounding clause** (RAG / context-only answering; grading and judge prompts over a submission): rely ONLY on facts in the provided context or submission, never own knowledge or inference; anything not in context is unsupported; state when the answer or evidence is not present. Single highest-leverage clause for hallucination-sensitive grounded deployments, including rubric graders whose comments must anchor in the student's text.

## 5. Reduce tool-call overuse, two levers in order

1. **Lower the thinking level** (mechanics: rule 1). Higher levels encourage tool use for exploration and verification.
2. **System instruction bounding tool calls**: "You have a limited action budget of N tool calls. Use them efficiently."

## 6. Agentic workflows: port the 9-point planning template

Prompt drives an agentic workflow (model reasons, plans, executes across tool
calls) → 9-point system-instruction template: (1) logical dependencies and
constraints, (2) risk assessment, (3) abductive reasoning and hypothesis
exploration, (4) outcome evaluation and adaptability, (5) information
availability, (6) precision and grounding, (7) completeness, (8) persistence
and patience, (9) inhibit-response gate.

Prompt intended for agentic use but lacking an equivalent planning structure →
port the 9 dimensions into the system instruction as a numbered planning block
the model completes before any tool call or user response. One numbered
directive per dimension; inhibit-response gate (9) last.

## 7. Tool enablement by task type

Recommend in Key Changes:

- Recent or obscure facts → Google Search grounding.
- Any arithmetic, counting, calculation → code execution; never trust in-token computation.

(Tool-declaration syntax is call-site mechanics: rule 1.)

## 8. Flash-Lite's `minimal` default may need escalation

`gemini-3.5-flash-lite` defaults `thinking_level` to `minimal` (current default
and full valid level set: rule 1 — the enum is a mechanics fact that shifts
between model versions, so it is not hard-coded here). That default is tuned
for high-volume extraction, routing, classification, and can underperform on
any task requiring multi-step judgment: nuanced rubric-criterion grading,
multi-clause AND-gated descriptors, anything weighing evidence rather than
pattern-matching.

Escalation *policy* is an empirical quality judgment, not an API mechanic, so
it lives here: prompt targeting `gemini-3.5-flash-lite` fails at the default →
recommend testing the next level up (confirm current valid levels via rule 1
before naming one) before concluding the prompt is at fault; escalate further
only if the previous step still underperforms. Repeated escalation is not a
signal to abandon the model — it signals the task needs more than `minimal`.
`GRADING_PIPELINE.md` artifact 5 carries the calibration-checklist version of
this diagnostic branch.

## 9. Empirical model choice by task type (probe-verified, not vendor guidance)

Deployer production A/B testing, not Google documentation — the skill cannot
know task-specific results, so this stays hand-maintained regardless of rule 1.
Every finding was tested on the prior generation (`gemini-3.1-flash-lite`,
`gemini-3-flash-preview`, `gemini-2.5-*`) before `gemini-3.6-flash` and
`gemini-3.5-flash-lite` existed. Treat each model-to-task mapping as a starting
hypothesis to re-verify on the current generation, not a standing fact — Google
documents exactly the kind of improvement (fewer reasoning steps, stronger
multimodal/reasoning scores on Flash-Lite) that would flip some verdicts. The
patterns below the table are the durable part.

Stronger than a currency caveat: every model in the table is a documented
migration *source*, not a current target (`gemini-3.5-flash`,
`gemini-3-flash-preview`, `gemini-3.1-pro-preview` → `gemini-3.6-flash`;
`gemini-3.1-flash-lite`, `gemini-2.5-flash` → `gemini-3.5-flash-lite`), and
none appears in the skill's current-model list. Never name a table model as the
recommendation for new work. Read a row as "this task type suited that tier",
map to the current successor, put the re-test in Key Changes.

| Task type | Model that won, as tested | Why | Currency |
|---|---|---|---|
| Open-ended multimodal extraction (transcription, speaker labeling, phase detection) | `gemini-3.5-flash` (free tier) | Matched paid `gemini-2.5-pro` exactly on a multi-speaker code-switched video; free-tier `gemini-3.1-flash-lite`/`gemini-2.5-flash` under-counted speakers or mislabeled phases | Still current; `gemini-2.5-pro` since lost production access |
| Constrained rubric-tier grading needing internally consistent verdicts | `gemini-3-flash-preview` over `gemini-3.5-flash` | `gemini-3.5-flash` produced internally inconsistent grades (all-praise justification paired with a sub-Excellent tier) in one production chain; `gemini-3-flash-preview` held consistent | Re-verify: same model won the extraction row and lost here — task-specific, not a ranking |
| TERMINAL-mode feedback register discipline | `gemini-3-flash-preview` over `gemini-3.1-flash-lite` | Flash-Lite lapsed to draft-register phrasing, used banned forward-framing language, doubled point values, intermittent JSON truncation on first pass | Re-verify on `gemini-3.5-flash-lite` |
| Discrimination/distractor-construction (odd-one-out items) | `gemini-3.5-flash` over `gemini-3.1-flash-lite` | Flash-Lite built distractors around surface word-form patterns (the one gerund among plain nouns) rather than semantic outliers; a stricter surface-uniformity gate made this worse on Flash-Lite specifically, neutral-to-helpful on 3.5-flash | Re-verify on `gemini-3.5-flash-lite`, documented as stronger on reasoning/multimodal than 3.1 Flash-Lite |
| Narrow perceptual tasks (handwriting OCR) | `gemini-3.1-flash-lite` over heavier models | Cheaper/lighter model beat a reasoning-tier model on this narrow perceptual task | Directionally durable: never assume a "smarter" model wins a narrow perceptual task |
| Semantic claim-vs-finding verification (does a citation's claim match what it found) | Gemini-class over Gemma-class | Independent prompt-wording iterations failed to close a Gemma 4 ceiling; a Gemini reasoning model got it right on the same prompt | `GEMMA4_API_BEST_PRACTICES.md` for the Gemma-side ceiling; route this sub-step to Gemini even inside an otherwise-Gemma pipeline |
| Coarse binary classification (screening only, not graded tiers) | `gemini-3-flash-preview` | Best binary agreement among tested models, despite being weak on fine-grained tier classification on the same data (row 2) | Illustrates task-specificity more than a standing recommendation |

**Cross-cutting patterns (durable across generations):**

- **Rankings are task-specific, not global.** The same model won an extraction task and was dropped from a grading-tier task in one codebase; the same model won binary screening and lost tier-granular classification on the same data. Never port a win across task types without re-testing; never emit a family-wide "this model is good/bad" verdict from one task's result.
- **Lite-tier models tend toward surface-pattern matching over semantic judgment** on tasks needing discrimination between real and superficially similar content — recall gaps on implicit evidence in grading, surface-feature gaming in item construction. Mitigate with an explicit enumeration/scan requirement (forces the surface-vs-semantic gap into a checkable list, per `FEEDBACK_GENERATION.md` F3), but budget a second-order cost: piling scan requirements onto a small model crowds out attention for other prompt-carried rules. A fix genuinely competing with another rule for attention → move the competing rule code-side rather than adding prompt text.
- **Bigger/smarter is not automatically better**, and may not be worth its cost: one documented finding rejected a heavier reasoning model because it shared the same constrained quota bucket with no quality edge on that task, while being slower. Check quota-sharing AND task-relevant quality gain before recommending a tier step-up.
- **A single clean benchmark run is the upper tail of variance**, not a stable baseline, at default sampling. Treat one clean result as optimistic; recommend a small multi-run check before declaring a winner, especially on a close call.
- **A same-family "gold standard" inflates agreement.** Labels generated by one family and graded by the same family showed near-perfect agreement that dropped sharply against an independent non-LLM ground truth. Prefer independent ground truth over another LLM's opinion, especially same-family.

## 10. Quota and rate-limit behavior the hosted docs don't cover

Empirical production findings, not documented mechanics — exception to rule 1's
skill-deferral, same as rule 8: a doc-fetching skill surfaces only what was
written down, not what was observed under load.

- `gemini-3.1-flash-lite` has an empirically confirmed per-minute token ceiling well below its context window. A generic auto-retry loop (short fixed sleep, many attempts) on a long prompt exhausts it inside one wall-clock minute, producing repeated zero-output failures that read as model failures but are pacing failures. Long-prompt Flash-Lite work → single-shot calls with wide spacing (90+ seconds) over blind auto-retry. Re-verify whether the ceiling carries to `gemini-3.5-flash-lite`.
- Legacy `generateContent` surface: classify a 429's real severity by the `retryDelay` field on `RetryInfo` (short = transient, retry same model; long = real exhaustion, rotate keys or advance the chain), not by the `quotaId` substring — a `"PerDay"` string can appear on a short rolling-window RPM throttle and is unreliable alone.
- Interactions API's 429 is a **different, strictly worse shape**: HTTP 200 with an SSE-embedded error, no `retryDelay`/`quotaId`/scope fields at all. The `retryDelay` classifier does not apply; use a persistence-based circuit breaker (consecutive failures over a time window) instead of parsing severity out of the response.

## Moved content

Second-level routing, additive to this file:

- **`GEMINI_MIGRATION.md`** — cross-family migration facts the skill doesn't cover (tools + response_format scope across families, Gemma 4 schema-shape porting, prefilled model-turn validation). Load when legacy `generateContent` forms appear anywhere in the input; one-time per prompt.

## Verify after changes

- No API-mechanics claim (model ID, parameter, endpoint, request/response shape) answered from this file instead of the skill (1).
- Long-context prompts end on the query, not the data (2).
- Chain-of-thought scaffolding replaced with a `thinking_level` recommendation, not left in place (3).
- Flash grounding/freshness clauses present when the task is time-sensitive, knowledge-grounded, or a grading/judge task over submitted work (4).
- Agentic system instructions carry the 9-point planning block (6).
- `gemini-3.5-flash-lite` targets on multi-step judgment tasks (rubric grading, AND-gated descriptors) get a next-level-up `thinking_level` test recommendation, not a silent default-`minimal` assumption (8).
- Any recommended model swap names its currency caveat — tested on which generation, re-verify before porting — rather than standing as fact (9).
- Any 429/quota recommendation matches the surface actually in use (`generateContent` `retryDelay` classifier vs. Interactions circuit breaker; 10).

## Closing directive recap

Imperative reference when `Target model: Gemini 3.x` is declared, scoped to
prompt content and empirical findings (rules 8-10 = stated exception to
mechanics-defer-to-skill). Apply every numbered rule; cite rule numbers in Key
Changes. Current model IDs, defaults, pricing, and every other documented
API-mechanics or migration fact → recommend the `gemini-interactions-api` skill
(rule 1) rather than answering from this file or memory. Empirically-tested
model choice (9) and production quota behavior (10) → this file is the source
of truth precisely because the skill cannot know it. Legacy `:generateContent`
wiring additionally loads `GEMINI_MIGRATION.md`.
