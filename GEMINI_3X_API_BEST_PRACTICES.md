# Gemini 3.x prompt-content best practices

<role>
Reference for prompt-optimizer. Load when `Target model:` declares any Gemini
3.x string. Apply every numbered rule; cite rule numbers in Key Changes.

**Prompt content and empirical findings only**: how to word and structure a
prompt or system instruction for a Gemini 3.x model, plus deployer production
findings on model choice and behavior under load. NOT documented API mechanics
(model IDs, defaults, pricing, parameter wiring, request/response shape, SDK
versions), which are the `gemini-interactions-api` skill's job (rule 1). Rules
8-10 are the stated exception: empirical quality judgments and production
behavior no doc-fetching skill can know.
</role>

<scope>
Family: any `gemini-3.x` string. Liveness and the current successor for any
string = the skill's job (rule 1); this file stores no model list.

**Surface scope.** Interactions API only. Evidence written against
`generateContent` (doc page, example, forum answer) neither confirms nor
overrides an Interactions fact; never port it to an Interactions call without
verification. Shared doc paths cover both surfaces: check which endpoint an
example calls before treating it as evidence. Legacy wiring in a prompt or
call-site = migration defect (`GEMINI_MIGRATION.md`), never an alternative to
recommend.

Current defaults/pricing and every API-mechanics fact = the skill's job (rule
1). Gemma 4 → `GEMMA4_API_BEST_PRACTICES.md`; DeepSeek V4 →
`DEEPSEEK_V4_API_BEST_PRACTICES.md`.
</scope>

## 1. API mechanics are the gemini-interactions-api skill's job

Never answer from this file, training data, or memory for: current model
IDs/pricing/defaults, parameter wiring (`temperature`/`top_p`/`top_k` removal,
`thinking_level` vs `thinking_budget`, `response_format` schema wiring,
tools-array shape), function-calling response matching,
multi-turn/thought-preservation, streaming, SDK/migration facts. In Key
Changes: recommend invoking the `gemini-interactions-api` skill before writing
or reviewing call-site code. Name `gemini-api-docs-mcp` `search_docs`, scoped
to the unknown, as the deployer's fallback where the skill is not installed.
Read/Grep/Glob cannot detect skill availability or run an MCP query, so both
are recommendations, never steps you take. State your interim assumption
either way. Legacy `generateContent` wiring additionally loads
`GEMINI_MIGRATION.md` (cross-family facts the skill doesn't cover; same
skill-first policy).

## 2. Long-context: query at the end, anchored to the context

Large-context prompt (books, codebases, long videos, student submissions),
required shape:

- Governing directives (role, output schema, refusal rules) at START.
- Large context block (data, transcripts, submissions) in MIDDLE.
- Specific query at END, anchored "Based on the preceding information..." or domain equivalent.
- Governing directive repeated at the very end as recency reminder (universal start-and-end rule holds).

## 3. Prompting changes for 3.x

- **Precise instructions:** be concise. Verbose prompt-engineering built for older models → over-analysis. Drop CoT scaffolding ("think step by step in detail before answering"); tune `thinking_level` instead (mechanics: rule 1).
- **Output verbosity:** 3.x terse by default (observed on 3, 3.1; re-confirm per release). Conversational tone → steer explicitly ("Explain this as a friendly, talkative assistant"). Never rely on the default.
- **Consistent structure:** XML XOR Markdown for section delimiters. Pick one, convert the minority. Anti-pattern: per-section XML (`<rule_1>`) around already-Markdown sections (`## 1. Foo`) "for scope"; header already delimits, wrapper creates the prohibited mix. Whole-document meta blocks (`<role>`, `<scope>`) are not section delimiters and may coexist with a Markdown body. Curly-brace substitution is unrelated.
- **Critical-instructions placement:** persona | behavioral constraints | output format → System Instruction, or the very start of the user prompt. Never after long context or examples. Start-and-end recency still applies as a closing reminder.
- **Multimodal equal-class:** image/audio/video passed alongside text → reference each modality explicitly. Never name only the text input.
- **Thinking-boost lever (narrow fallback):** highest `thinking_level` tried and named insufficient → "Think very hard before answering" buys performance with thinking tokens. Never default scaffolding.
- **Context management:** rule 2.

## 4. Gemini 3 Flash freshness and grounding clauses

System-instruction clauses absent by default. Two scopes, do not merge them.
Clauses 1-2 fire on any Flash-tier target (`-flash` or `-flash-lite`) whose
task is time-sensitive or knowledge-grounded. Clause 3 fires on ANY Gemini 3.x
target, Pro included, that answers from provided context or judges submitted
work. Recommend in Key Changes:

- **Current-day clause** (time-sensitive queries, tool-call freshness): follow the provided current date and year in search queries; state the year explicitly. The year is a runtime value the caller injects, never a literal typed into the prompt: a baked year is correct until it silently is not. Flash otherwise defaults to stale assumptions about "now".
- **Knowledge-cutoff clause** (facts near the boundary): state the cutoff so the model defers to grounding for post-cutoff facts instead of parametric memory (confirm the current cutoff via rule 1; it moves with each release).
- **Strict-grounding clause** (RAG / context-only answering; grading and judge prompts over a submission): rely ONLY on facts in the provided context or submission, never own knowledge or inference; anything not in context is unsupported; state when the answer or evidence is not present. Single highest-leverage clause for hallucination-sensitive grounded deployments, including rubric graders whose comments must anchor in the student's text.

## 5. Reduce tool-call overuse, two levers in order

5.1. **Lower the thinking level** (mechanics: rule 1). Higher levels encourage tool use for exploration and verification.
5.2. **System instruction bounding tool calls**: "You have a limited action budget of {tool_call_budget} tool calls. Use them efficiently." Substitute the real number before emitting; never emit the literal `{tool_call_budget}`. Pair the cap with an under-budget path: budget exhausted and the answer still unsupported -> report the gap, never fall back to parametric memory. A cap with no stated way out converts a grounding task into a guessing task at the boundary.

Rule 6's persistence dimension pulls against both levers; 6c arbitrates.

## 6. Agentic workflows: the 9-point planning template, added sparingly

Prompt drives an agentic workflow (model reasons, plans, executes across tool
calls) → 9-point system-instruction template: (1) logical dependencies and
constraints, (2) risk assessment, (3) abductive reasoning and hypothesis
exploration, (4) outcome evaluation and adaptability, (5) information
availability, (6) precision and grounding, (7) completeness, (8) persistence
and patience, (9) inhibit-response gate.

**Default: port none of it.** Scaffolding is a cost paid on every call
(`GENERIC_REVIEW.md` rule 12). A nine-directive planning block bought a
capability older models lacked; a 3.x model plans natively at its default
thinking level, and the block now competes with that reasoning for attention.
Order of moves on a failing agentic run: raise `thinking_level` one step
(mechanics: rule 1) and re-run; still failing → port by the split below.
Inhibit-response gate (9) last whenever any dimension is ported.

**Port policy, never reasoning.** A dimension carrying external policy the model
cannot infer from the task earns its tokens. A dimension describing how to reason
duplicates native thinking and competes with it.

- Port: (2) risk assessment, which tool calls mutate state versus read; (5) information availability, what counts as unknown rather than inferable; (9) inhibit-response gate, when to stop and ask. Add (6) precision and grounding where exact-string or type fidelity matters, and (8) persistence only to set a retry limit.
- Omit: (1) logical dependencies, (3) abductive reasoning, (4) outcome evaluation, (7) completeness. Written into the prompt they buy verbosity, not planning.

Triangulated, not probed: the vendor scopes the template's evaluation to
complex-rulebook plus user-interaction agents, which is the policy class, and a
`gemini-3.7-flash` self-report split the nine the same way. Neither is a
benchmark. Re-test before trusting the omit list on a new deployment.

**Hurt case, named.** Read-only exploratory agents (codebase search, database
triage): risk assessment plus the inhibit gate reclassify benign reads as
permission-worthy and the agent stops to ask instead of paging, while
completeness has no end-state to satisfy on an open-ended search and drives
keyword-variation loops. Read-only high-throughput work → port none.

**The dimensions govern reasoning, not output.** The block is completed in the
model's thinking. Emit it only where a human or a log consumes the plan, and
then by 6e's ladder, never as a tagged block.

**Adapt, never paste.** Vendor frames it as an example to fit to the use case,
tuning a stated cost-versus-accuracy trade-off. Four dimensions invert when
ported as a bare label:

6a. (6) is a quote-grounding directive, not a tone word: verify each claim by
quoting the exact applicable source or policy. Emit the clause, never the label.
6b. (7) scopes to the PLAN, every requirement and constraint exhaustively
incorporated into it. Ported as output exhaustiveness it becomes a quota and
manufactures findings (`GENERIC_REVIEW.md` item 5).
6c. (8) "do not give up until the reasoning is exhausted" costs tokens and risks
loops, vendor-stated, and pulls against rule 5. Say which governs this
deployment; never emit both unarbitrated. Persistence binds the reasoning, never
the abstention path: reasoning exhausted with no support found is a completed
task, not a failure to push through.
6d. (5) resolves missing information by consulting the user. No user in a batch
or scoring pipeline -> substitute the fixed abstention literal, else the model
assumes instead of asking.

6e. **No structured text immediately before a tool call.** A directive to emit a
tagged or serialized block (`<UPDATE>`, a JSON or YAML object) as the turn's
first output and then call a tool intermittently corrupts the call into a
malformed-function-call error. The 9-point block is the common source: it is
completed BEFORE any tool call. Three fixes in order: move the notes into a
declared `update` function the model calls first, so the notes call and the real
call leave in one step; demote the block to Markdown headers (`# PLAN`); drop the
pre-tool text requirement. Markdown headers here override rule 3's
single-delimiter choice, for these note blocks only. Vendor-stated for the whole
Gemini 3 series. The failure is intermittent: a clean dry run does not clear a
prompt of it.

## 7. Tool enablement by task type

Recommend in Key Changes:

- Recent or obscure facts → Google Search grounding.
- Any arithmetic, counting, calculation → code execution; never trust in-token computation.

(Tool-declaration syntax is call-site mechanics: rule 1.)

## 8. Lite-tier thinking defaults often need escalation

Lite-tier targets default to the bottom of the `thinking_level` enum (current
default and full valid level set: rule 1, never this file; both shift between
model versions). Tuned for high-volume extraction, routing, classification;
can underperform on any task requiring multi-step judgment: nuanced
rubric-criterion grading, multi-clause AND-gated descriptors, anything
weighing evidence rather than pattern-matching.

Escalation policy = empirical quality judgment, not an API mechanic, so it
lives here. Two triggers:

- **Review time:** target is a Lite tier AND the task needs multi-step judgment → put a one-level-up test in Key Changes as a deployer action, reported failure or not (confirm current valid levels via rule 1 before naming one).
- **Reported failure:** escalate one level at a time, each step conditional on the previous still underperforming. Never call the prompt at fault before the default has been ruled out. Repeated escalation signals the task needs more than the bottom level, not that the model is wrong.

`GRADING_PIPELINE.md` artifact 5 carries the calibration-checklist version of
this diagnostic branch.

## 9. Empirical model choice by task type (probe-verified, not vendor guidance)

Deployer production A/B testing, not Google documentation; the skill cannot
know task-specific results, so this stays hand-maintained regardless of rule 1.
No finding was probed on a model newer than `gemini-3.5-flash`; every Gemini
release after it is untested here (current list: rule 1). The string tested is
named in each row, never generalized to a generation. Each
mapping is a hypothesis to re-verify on
the current generation, not a standing fact. The patterns below the table are
the durable part.

A row records which tier won a task on the generation tested, never which
string to call today. Liveness and the current successor for any string below
= the skill's job (rule 1); this file asserts neither. Never name a table model
as the recommendation for new work. Read a row as "this task type suited that
tier", map to the current successor, put the re-test in Key Changes.

| Task type | Model that won, as tested | Why | Currency |
|---|---|---|---|
| Open-ended multimodal extraction (transcription, speaker labeling, phase detection) | `gemini-3.5-flash` (free tier) | Matched paid `gemini-2.5-pro` exactly on a multi-speaker code-switched video; free-tier `gemini-3.1-flash-lite`/`gemini-2.5-flash` under-counted speakers or mislabeled phases | Re-verify on the current successor (rule 1); `gemini-2.5-pro` since lost production access |
| Constrained rubric-tier grading needing internally consistent verdicts | `gemini-3-flash-preview` over `gemini-3.5-flash` | `gemini-3.5-flash` produced internally inconsistent grades (all-praise justification paired with a sub-Excellent tier) in one production chain; `gemini-3-flash-preview` held consistent | Re-verify: same model won the extraction row and lost here, so task-specific, not a ranking |
| TERMINAL-mode feedback register discipline | `gemini-3-flash-preview` over `gemini-3.1-flash-lite` | Flash-Lite lapsed to draft-register phrasing, used banned forward-framing language, doubled point values, intermittent JSON truncation on first pass | Re-verify on `gemini-3.5-flash-lite` |
| Discrimination/distractor-construction (odd-one-out items) | `gemini-3.5-flash` over `gemini-3.1-flash-lite` | Flash-Lite built distractors around surface word-form patterns (the one gerund among plain nouns) rather than semantic outliers; a stricter surface-uniformity gate made this worse on Flash-Lite specifically, neutral-to-helpful on 3.5-flash | Re-verify on `gemini-3.5-flash-lite`, documented as stronger on reasoning/multimodal than 3.1 Flash-Lite |
| Narrow perceptual tasks (handwriting OCR) | `gemini-3.1-flash-lite` over heavier models | Beat a reasoning-tier model despite being cheaper and lighter | Directionally durable: never assume a "smarter" model wins a narrow perceptual task |
| Semantic claim-vs-finding verification (does a citation's claim match what it found) | Gemini-class over Gemma-class | Independent prompt-wording iterations failed to close a Gemma 4 ceiling; a Gemini reasoning model got it right on the same prompt | `GEMMA4_API_BEST_PRACTICES.md` for the Gemma-side ceiling; route this sub-step to Gemini even inside an otherwise-Gemma pipeline |
| Coarse binary classification (screening only, not graded tiers) | `gemini-3-flash-preview` | Best binary agreement among tested models, despite being weak on fine-grained tier classification on the same data (row 2) | Illustrates task-specificity more than a standing recommendation |

**Cross-cutting patterns (durable across generations):**

- **Rankings are task-specific, not global.** Never port a win across task types without re-testing. Never emit a family-wide good/bad verdict from one task.
- **Lite-tier models tend toward surface-pattern matching over semantic judgment** on tasks needing discrimination between real and superficially similar content: recall gaps on implicit evidence in grading, surface-feature gaming in item construction. Mitigate with an explicit enumeration/scan requirement (forces the surface-vs-semantic gap into a checkable list, per `FEEDBACK_GENERATION.md` F3), shaped as a fixed list walked with a per-item present/absent verdict, never a findings quota: a surface-matcher told to return N returns N, padded with lookalikes. Budget a second-order cost too: piling scan requirements onto a small model crowds out attention for other prompt-carried rules. A fix genuinely competing with another rule for attention → move the competing rule code-side rather than adding prompt text.
- **Bigger/smarter is not automatically better**, and may not be worth its cost: one finding rejected a heavier reasoning model that shared the same constrained quota bucket, was slower, and gained no quality on that task. Check quota-sharing AND task-relevant quality gain before recommending a tier step-up.
- **A single clean benchmark run is the upper tail of variance**, not a stable baseline, at default sampling. Treat one clean result as optimistic; recommend a small multi-run check before declaring a winner, especially on a close call.
- **A same-family "gold standard" inflates agreement.** Labels generated by one family and graded by the same family showed near-perfect agreement that dropped sharply against an independent non-LLM ground truth. Prefer independent ground truth over another LLM's opinion, especially same-family.

## 10. Quota and rate-limit behavior the hosted docs don't cover

Empirical production findings, not documented mechanics: exception to rule 1's
skill-deferral, same as rule 8.

- `gemini-3.1-flash-lite` has an empirically confirmed per-minute token ceiling well below its context window. A generic auto-retry loop (short fixed sleep, many attempts) on a long prompt exhausts it inside one wall-clock minute, producing repeated zero-output failures that read as model failures but are pacing failures. Long-prompt Flash-Lite work → single-shot calls with wide spacing (90+ seconds) over blind auto-retry. Re-verify whether the ceiling carries to `gemini-3.5-flash-lite`.
- A newly released model on the free tier sheds load as HTTP 500 with a high-demand message BEFORE any quota 429 appears, and sheds a long prompt while a trivial one on the same key succeeds seconds earlier. Observed on `gemini-3.7-flash` at launch. A circuit breaker keyed on 429 alone reads this as a server fault and retries straight into the real quota wall: count consecutive 500s toward the same breaker.
- Interactions API's 429 is a **different, strictly worse shape**: HTTP 200 with an SSE-embedded error, no `retryDelay`/`quotaId`/scope fields at all. No severity can be parsed out of the response; use a persistence-based circuit breaker (consecutive failures over a time window). A severity classifier built on legacy `generateContent` `RetryInfo` fields does not port: legacy retry wiring in the input is a migration defect to flag, never a path to tune.

## Moved content

Second-level routing, additive to this file:

- **`GEMINI_MIGRATION.md`**: cross-family migration facts the skill doesn't cover (tools + response_format scope across families, Gemma 4 schema-shape porting, prefilled model-turn validation). Load one-time per prompt when EITHER legacy `generateContent` forms appear anywhere in the input OR the prompt is being carried across Gemini generations, or from Gemma 4 / Gemini 2.5, to a 3.x target. The trunk routes only the first trigger, so the second is this file's to fire.

## Verify after changes

- No API-mechanics claim (model ID, parameter, endpoint, request/response shape) answered from this file instead of the skill (1).
- Long-context prompts end on the query, not the data (2).
- Chain-of-thought scaffolding replaced with a `thinking_level` recommendation, not left in place (3).
- Freshness clauses present on Flash-tier targets with time-sensitive or knowledge-grounded tasks; strict-grounding clause present on any 3.x target answering from context or judging submitted work (4).
- No planning block ported without a named failure and a `thinking_level` step-up tried first; ported dimensions are policy-carrying (2, 5, 9), never reasoning-describing (1, 3, 4, 7); each emitted as a clause rather than a label and arbitrated against rule 5 (6, 6a-6d).
- No tagged or serialized block is required immediately before a tool call; pre-tool notes route to a declared `update` call or to Markdown headers (6e).
- Lite-tier targets on multi-step judgment tasks (rubric grading, AND-gated descriptors) get a next-level-up `thinking_level` test recommendation, not a silent bottom-level assumption (8).
- Any recommended model swap names its currency caveat, tested on which generation and re-verify before porting, rather than standing as fact (9).
- Any 429/quota recommendation is written for Interactions (persistence-based circuit breaker), and legacy retry wiring is flagged as a migration defect rather than tuned (10).

## Closing directive recap

Imperative reference when `Target model: Gemini 3.x` is declared, scoped to
prompt content and empirical findings (rules 8-10 = stated exception to
mechanics-defer-to-skill). Apply every numbered rule; cite rule numbers in Key
Changes. Current model IDs, defaults, pricing, and every other documented
API-mechanics or migration fact → recommend the `gemini-interactions-api` skill
(rule 1), never this file or memory. Empirically-tested model choice (9) and
production quota behavior (10) → this file is the source of truth. Legacy
`:generateContent` wiring additionally loads `GEMINI_MIGRATION.md`.
