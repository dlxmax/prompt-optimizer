# Gemini 3.x prompt-content best practices

<role>
Reference for prompt-optimizer. Load when `Target model:` declares any Gemini
3.x string. Apply every numbered rule.

**Prompt content and empirical findings only**: how to word and structure a
prompt or system instruction for a Gemini 3.x model, plus deployer production
findings on model choice and behavior under load. NOT documented API mechanics
(model IDs, defaults, pricing, parameter wiring, request/response shape, SDK
versions), which are the Gemini docs MCP's job (rule 1). Rules
8-10 are the stated exception: empirical quality judgments and production
behavior no docs search can know.
</role>

<scope>
Family: any `gemini-3.x` string. Liveness and the current successor for any
string = the docs MCP's job (rule 1); this file stores no model list.

**Surface scope.** Interactions API only. Evidence written against
`generateContent` (doc page, example, forum answer) neither confirms nor
overrides an Interactions fact; never port it to an Interactions call without
verification. Shared doc paths cover both surfaces: check which endpoint an
example calls before treating it as evidence. Legacy wiring in a prompt or
call-site = migration defect (`GEMINI_MIGRATION.md`), never an alternative to
recommend.

Current defaults/pricing and every API-mechanics fact = the docs MCP's job
(rule 1). Gemma 4 → `GEMMA4_API_BEST_PRACTICES.md`; DeepSeek V4 →
`DEEPSEEK_V4_API_BEST_PRACTICES.md`.
</scope>

## 1. API mechanics are the Gemini docs MCP's job

Never answer from this file, training data, or memory for: current model
IDs/pricing/defaults, parameter wiring (`temperature`/`top_p`/`top_k` removal,
`thinking_level` vs `thinking_budget`, `response_format` schema wiring,
tools-array shape), function-calling response matching,
multi-turn/thought-preservation, streaming, SDK/migration facts. Query
`gemini_search_docs` (`gemini-api-docs-mcp`) scoped to the unknown before writing
or reviewing call-site code, `gemini_get_doc` when the snippet lacks context;
state the resulting fact, never its source. Tool absent or erroring → deployer-verify
item recommending that query, with your interim assumption. Never point to the
`gemini-interactions-api` skill: you cannot see whether the caller has it. Legacy `generateContent` wiring additionally
loads `GEMINI_MIGRATION.md` (cross-family facts; same docs-MCP-first policy).

## 2. Long-context: query at the end, anchored to the context

Large-context prompt (books, codebases, long videos, student submissions),
required shape:

2.1. Governing directives (role, output schema, refusal rules) at START.
2.2. Large context block (data, transcripts, submissions) in MIDDLE.
2.3. Specific query at END, anchored "Based on the preceding information..." or domain equivalent.
2.4. Governing directive repeated at the very end as recency reminder (universal start-and-end rule holds).

## 3. Prompting changes for 3.x

3.1. **Precise instructions:** be concise. Verbose prompt-engineering built for older models → over-analysis. Drop CoT scaffolding ("think step by step in detail before answering"); tune `thinking_level` instead (mechanics: rule 1).
3.2. **Output verbosity:** 3.x terse by default (observed on 3, 3.1; re-confirm per release). Conversational tone → steer explicitly ("Explain this as a friendly, talkative assistant"). Never rely on the default.
3.3. **Consistent structure:** XML XOR Markdown for section delimiters. Pick one, convert the minority. Anti-pattern: per-section XML (`<rule_1>`) around already-Markdown sections (`## 1. Foo`) "for scope"; header already delimits, wrapper creates the prohibited mix. Whole-document meta blocks (`<role>`, `<scope>`) are not section delimiters and may coexist with a Markdown body. Curly-brace substitution is unrelated.
3.4. **Critical-instructions placement:** persona | behavioral constraints | output format → System Instruction, or the very start of the user prompt. Never after long context or examples. Start-and-end recency still applies as a closing reminder.
3.5. **Multimodal equal-class:** image/audio/video passed alongside text → reference each modality explicitly. Never name only the text input.
3.6. **Thinking-boost lever (narrow fallback):** highest `thinking_level` tried and named insufficient → "Think very hard before answering" buys performance with thinking tokens. Never default scaffolding.
3.7. **Context management:** rule 2.

## 4. Gemini 3 Flash freshness and grounding clauses

System-instruction clauses absent by default. Two scopes, do not merge them.
Clauses 1-2 fire on any Flash-tier target (`-flash` or `-flash-lite`) whose
task is time-sensitive or knowledge-grounded. Clause 3 fires on ANY Gemini 3.x
target, Pro included, that answers from provided context or judges submitted
work. Recommend in Key Changes:

4.1. **Current-day clause** (time-sensitive queries, tool-call freshness): follow the provided current date and year in search queries; state the year explicitly. The year is a runtime value the caller injects, never a literal typed into the prompt: a baked year is correct until it silently is not. Flash otherwise defaults to stale assumptions about "now".
4.2. **Knowledge-cutoff clause** (facts near the boundary): state the cutoff so the model defers to grounding for post-cutoff facts instead of parametric memory (confirm the current cutoff via rule 1; it moves with each release).
4.3. **Strict-grounding clause** (RAG / context-only answering; grading and judge prompts over a submission): rely ONLY on facts in the provided context or submission, never own knowledge or inference; anything not in context is unsupported; state when the answer or evidence is not present. Single highest-leverage clause for hallucination-sensitive grounded deployments, including rubric graders whose comments must anchor in the student's text.

## 7. Tool enablement by task type

Recommend in Key Changes:

7.1. Recent or obscure facts → Google Search grounding.
7.2. Any arithmetic, counting, calculation → code execution; never trust in-token computation.

(Tool-declaration syntax is call-site mechanics: rule 1.)

## 8. Thinking level per call, set by the call's job

Valid levels and per-model defaults: rule 1, never this file. Levels below
are empirical, verified on `gemini-3.5-flash-lite` and `gemini-3.8-flash`; use
the nearest level the target accepts, valid on every model in the chain. A config shared across models (fallback chain, router) sets the level per leg or uses one valid on every leg: a bottom level valid on the primary can 400 the fallback exactly when it is needed.

8.1. Name a level per call, never a token budget: budgets map onto levels, so two budgets can send the same level and a bench across them tests fewer levels than it names.
8.2. Start from the call's job; name the job beside the level:
   8.2.1. Copy or split word for word: minimal. The model decides where an item ends: low.
   8.2.2. One yes/no check against a definition, or a shared presence-check call (`GRADING_PIPELINE.md` G1.2): medium.
   8.2.3. Lines written from already-checked findings: low.
   8.2.4. One verdict over the whole text: medium; high only after an 8.3 bench shows medium misses.
   8.2.5. Long structured output matching no job above: medium.
8.3. Change a level only after a bench on anchor cases: the level below and the level above, the same anchors including cases already right, uncached, one model, time per call reported. Levels tie -> keep the lower: faster, less truncation. Report the model that answered; a fallback partway through voids the comparison.
8.4. Never raise the level for quote echoing, broken bans, output carrying content a rule forbids, content an earlier step filtered out, or answers that swing between runs at a fixed level. A higher level tidies grammar; it does not recover filtered content. Fix the prompt, narrow the question, or move the decision to code (`GRADING_PIPELINE.md` G1.1). A call below its 8.2 level is exempt: raise it to that level.
8.5. Flash-Lite: medium is the default. High has fixed named misses at medium and has also backfired, so try it only through an 8.3 bench that includes cases already right.
8.5. Thinking tokens share the output cap. Long structured output always carries an output cap; above medium, also warn that the JSON tail may be truncated (empty replies, 500s).

## 9. Model choice patterns

Task-by-task results: `GEMINI_3X_MODEL_CHOICE.md`.

**Cross-cutting patterns (durable across generations):**

9.1. **Rankings are task-specific, not global.** Never port a win across task types without re-testing. Never emit a family-wide good/bad verdict from one task.
9.2. **Lite-tier models tend toward surface-pattern matching over semantic judgment** on tasks needing discrimination between real and superficially similar content: recall gaps on implicit evidence in grading, surface-feature gaming in item construction. Mitigate with an explicit enumeration/scan requirement (forces the surface-vs-semantic gap into a checkable list, per `FEEDBACK_GENERATION.md` F3), shaped as a fixed list walked with a per-item present/absent verdict, never a findings quota: a surface-matcher told to return N returns N, padded with lookalikes. Budget a second-order cost too: piling scan requirements onto a small model crowds out attention for other prompt-carried rules. A fix genuinely competing with another rule for attention → move the competing rule code-side rather than adding prompt text.
9.3. **Bigger/smarter is not automatically better**, and may not be worth its cost: one finding rejected a heavier reasoning model that shared the same constrained quota bucket, was slower, and gained no quality on that task. Check quota-sharing AND task-relevant quality gain before recommending a tier step-up.
9.4. **Instability is never a temperature fix.** Run-to-run flips on a 3.x target -> narrower checks (`GRADING_PIPELINE.md` G1.1), never a temperature change. Caller sets `temperature`, `top_p`, or `top_k` at any value -> recommend deleting the parameter from the request, never a value to set it to (not even 1.0: an older docs page names it, the 3.x guidance says remove).
9.5. **A single clean benchmark run is the upper tail of variance**, not a stable baseline, at default sampling. Treat one clean result as optimistic; recommend a small multi-run check before declaring a winner, especially on a close call.
9.6. **A same-family "gold standard" inflates agreement.** Labels generated by one family and graded by the same family showed near-perfect agreement that dropped sharply against an independent non-LLM ground truth. Prefer independent ground truth over another LLM's opinion, especially same-family.

## 10. Quota and rate-limit behavior the hosted docs don't cover

Empirical production findings, not documented mechanics: exception to rule 1's
docs deferral, same as rule 8.

10.1. `gemini-3.1-flash-lite` has an empirically confirmed per-minute token ceiling well below its context window. A generic auto-retry loop (short fixed sleep, many attempts) on a long prompt exhausts it inside one wall-clock minute, producing repeated zero-output failures that read as model failures but are pacing failures. Long-prompt Flash-Lite work → single-shot calls with wide spacing (90+ seconds) over blind auto-retry. Re-verify whether the ceiling carries to `gemini-3.5-flash-lite`.
10.2. A newly released model on the free tier sheds load as HTTP 500 with a high-demand message BEFORE any quota 429 appears, and sheds a long prompt while a trivial one on the same key succeeds seconds earlier. A circuit breaker keyed on 429 alone reads this as a server fault and retries straight into the real quota wall: count consecutive 500s toward the same breaker.
10.3. Quota is tracked per model per key. Several keys with a fallback model -> spend the primary on every key before the fallback on any key: a key whose primary is spent still holds fallback quota.
10.4. Interactions API's 429 is a **different, strictly worse shape**: HTTP 200 with an SSE-embedded error, no `retryDelay`/`quotaId`/scope fields at all. No severity can be parsed out of the response; use a persistence-based circuit breaker (consecutive failures over a time window). A severity classifier built on legacy `generateContent` `RetryInfo` fields does not port: legacy retry wiring in the input is a migration defect to flag, never a path to tune.

## Moved content

Second-level routing, additive to this file:

**`GEMINI_3X_AGENTIC.md`**: rules 5-6. Load when the prompt under review declares tools or function calling, runs a multi-step agent, or carries a planning block. Never for a single-call prompt without tools.

**`GEMINI_3X_MODEL_CHOICE.md`**: task-by-task model results. Load when the caller asks which model to use, or before you recommend a model or tier change.

**`GEMINI_MIGRATION.md`**: cross-family migration facts the docs don't state (tools + response_format scope across families, Gemma 4 schema-shape porting, prefilled model-turn validation, `thinking_level` shrinkage, the `gemini-3.8-flash` behavior break). Load one-time per prompt when EITHER legacy `generateContent` forms appear anywhere in the input OR the caller's request states a move of this prompt to a different model or generation (Gemma 4 / Gemini 2.5 / earlier 3.x to a 3.x target). Never load it for a review, audit, or authoring task that states no move, and a chain or router, a model string, or a recommended model swap alone is not a move. The trunk routes only the first trigger, so the second is this file's to fire.

## Verify after changes

1. No API-mechanics claim (model ID, parameter, endpoint, request/response shape) answered from this file instead of the docs MCP (1).
2. Long-context prompts end on the query, not the data (2).
3. A `thinking_level` shared across a fallback chain or router is valid on every leg, or set per leg (8).
4. Chain-of-thought scaffolding replaced with a `thinking_level` recommendation, not left in place (3).
5. Freshness clauses present on Flash-tier targets with time-sensitive or knowledge-grounded tasks; strict-grounding clause present on any 3.x target answering from context or judging submitted work (4).
6. Every call names its `thinking_level` and job, never a token budget; any change rests on an 8.3 bench; no level raised for an 8.4 cause; long structured output carries an output cap, plus a truncation warning above medium (8).
7. Any recommended model swap names its currency caveat, tested on which generation and re-verify before porting, rather than standing as fact (9); a Flash successor is never assumed to be `gemini-3.8-flash` (9, `GEMINI_MIGRATION.md` 5).
8. Any 429/quota recommendation is written for Interactions (persistence-based circuit breaker), and legacy retry wiring is flagged as a migration defect rather than tuned (10).

## Closing directive recap

Imperative reference when `Target model: Gemini 3.x` is declared, scoped to
prompt content and empirical findings (rules 8-10 = stated exception to
mechanics-defer-to-docs). Apply every numbered rule.
Current model IDs, defaults, pricing, and every other documented
API-mechanics or migration fact → a `gemini_search_docs` query (rule 1), never
this file or memory. Empirically-tested model choice (9) and
production quota behavior (10) → this file is the source of truth. Legacy
`:generateContent` wiring additionally loads `GEMINI_MIGRATION.md`.
