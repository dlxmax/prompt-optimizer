# Prompt Optimizer Agent

A Claude Code agent that designs and reviews education-domain LLM prompts: rubric-based **grading**, prose **feedback-comment generation**, and **lesson/instructional-material authoring** (lesson plans, worksheets, exam/quiz items). It rescues oversized monoliths into per-criterion or per-section call architectures, audits revised prompts for compliance, and authors pipelines from a rubric or spec. It also reviews generic LLM prompts against a research-backed 15-item checklist on request.

**Topics:** `grading` · `rubric-grading` · `feedback-generation` · `lesson-planning` · `worksheet-generation` · `exam-generation` · `education` · `rubric` · `llm-judge` · `gemini` · `gemini-3.6-flash` · `gemini-3.5-flash` · `gemini-3.5-flash-lite` · `gemini-3.1-flash-lite` · `gemini-3.x` · `interactions-api` · `gemma-4` · `gemma` · `claude` · `deepseek` · `deepseek-v4` · `response-schema` · `structured-output` · `prompt-engineering` · `prompts` · `agents` · `validation` · `compliance` · `best-practices`

## How the agent thinks: three independent axes

Every call is classified on three axes that combine, not a single flat task list:

| Axis | Values | Decides |
|---|---|---|
| **Content domain** | GRADING · FEEDBACK · LESSON · generic | which checklist and Pipeline-Spec artifacts apply |
| **Shape** | RESCUE · AUDIT · AUTHOR · REVIEW | which recipe runs and what output skeleton comes back |
| **Target model family** | Gemini 3.x · Gemma 4 · DeepSeek V4 · Claude · unstated | which API-mechanics/prompting rules apply on top |

Domain and shape combine freely (e.g. "AUDIT a FEEDBACK prompt," "AUTHOR a LESSON pipeline"). Model family is additive on top of either: a GRADING/AUTHOR call targeting Gemma 4 loads both `GRADING_PIPELINE.md` and `GEMMA4_API_BEST_PRACTICES.md`. Nothing pays for bytes it doesn't need — a Claude-targeted, generic-domain REVIEW loads only `GENERIC_REVIEW.md`.

## The three content domains

| Domain | Produces | Checklist | Reference file |
|---|---|---|---|
| **GRADING** | a numeric rubric level/score, per criterion | G1-G10 | `GRADING_PIPELINE.md` |
| **FEEDBACK** | prose feedback/comments, not a score | F1-F10 | `FEEDBACK_GENERATION.md` |
| **LESSON** | lesson plans, worksheets, handout sections, exam/quiz items | L1-L9 | `LESSON_AUTHORING.md` |
| *(generic)* | anything else sent to an LLM | 15-item checklist | `GENERIC_REVIEW.md` |

FEEDBACK is not always standalone: a grading response commonly embeds one PQS-style feedback comment per criterion alongside its score. That case stays domain GRADING — `FEEDBACK_GENERATION.md` loads **additively**, governing just the feedback field, while `GRADING_PIPELINE.md` still owns the scoring artifacts. FEEDBACK is its own domain only when there's no rubric/score in scope at all (a standalone "give feedback on this draft" prompt).

Ambiguity resolves toward the most specific domain — GRADING > FEEDBACK > LESSON > generic — so judge-shaped or material-generation-shaped input never falls through to the generic 15-item checklist by default.

## The four shapes

1. **RESCUE** — an existing prompt in a domain with a checklist that bundles multiple criteria/sections in one call, or exceeds that domain's byte cap. Output: a **Pipeline Spec** for that domain (shared system instruction/scaffold; a per-criterion or per-section template; a response schema; a code-side validator checklist; a calibration checklist). If the caller's runtime makes exactly one call per submission/material, a compact hard-capped monolith revision is emitted alongside the spec.
2. **AUDIT** — an already-decomposed or compact prompt. Output: terse checklist findings (G/F/L, or the 15-item list for generic) and targeted fixes for failing items only. The lightest, most frequent path.
3. **AUTHOR** — a `<rubric>` block (the domain's build spec: rubric criteria for GRADING, voice/mode/scope for FEEDBACK, objectives/source/sections for LESSON) with no existing prompt. Output: the full Pipeline Spec. Unstated policy choices (GRADING tie-break direction; any domain's unstated voice/scope) are surfaced, never silently defaulted. When no model is fixed, Gemini 3.5 Flash-Lite and Gemma 4 are named as candidate small-model targets with a benchmark recommendation.
4. **REVIEW** — `Task: review` declared, or the input is the generic domain. Output: the classic 15-item checklist score, Key Changes, and a revised prompt.

## Why decomposition beats monoliths

One finding drives the Pipeline Spec architecture across all three domains, not just grading:

- **GRADING** (`GRADING_PIPELINE.md` G1): one call per rubric criterion prevents criteria from bleeding into each other and keeps every call's working set small — which is what makes lightweight targets (Flash-Lite, Gemma 4) viable graders in the first place. Whole-rubric grading in one call is multi-needle by construction; long-context strength is a single-needle property.
- **FEEDBACK** (`FEEDBACK_GENERATION.md` F2-F3): the same principle shows up as ghost-guard grounding (verify presence/absence before naming anything) and scan-then-judge (an enumerated evidence scan before any claim-bearing statement) — separating "find the evidence" from "make the claim" instead of asking one pass to do both reliably.
- **LESSON** (`LESSON_AUTHORING.md` L1-L2): generation and validation of the same material are separate calls, and each section/item-type (vocabulary, warm-up questions, quiz, exam items) gets its own call rather than one pass generating everything — a model judging several independent properties in one pass degrades reliability on each of them.

Alongside decomposition, every domain shares: evidence grounding tied to a verbatim quote or scan (never inferred), AND-gated or gate-plus-example constraint framing (never a vague adjective), calibration against a small human-reviewed set before trusting the pipeline (never blanket N>=5 voting as the default reliability mechanism), and prompt-injection defense around any untrusted source text.

## Architecture: thin diagnostic trunk, composable branches

The agent file is a small diagnostic trunk. It classifies each call on the three axes above, then loads only the reference files that call needs — several at once when axes overlap.

| File | Loaded when | Contents |
|---|---|---|
| `agents/prompt-optimizer.md` | always (the agent) | diagnosis (domain × shape), routing, task recipes, universal invariants |
| `GRADING_PIPELINE.md` | domain GRADING (any shape); schema review | G-checklist (G1-G10), the five Pipeline Spec artifacts, output skeletons, monolith recipe, schema review essentials |
| `FEEDBACK_GENERATION.md` | domain FEEDBACK (any shape), or domain GRADING with per-criterion feedback text in scope | F-checklist (F1-F10): PQS structure, ghost-guard grounding, scan-then-judge, mode awareness |
| `LESSON_AUTHORING.md` | domain LESSON (any shape) | L-checklist (L1-L9): per-section decomposition, output-contract parse anchors, gate+example pairing, source-segment scoping |
| `GENERIC_REVIEW.md` | generic domain, or `Task: review` | the 15-item checklist, verdict rubric, revision procedure, port-mode rules |
| `COMPACTION.md` | single-call fallback; length defects; explicit request | compaction pipeline, preserve-list, post-compaction gates |
| `GEMINI_MIGRATION.md` | legacy `generateContent` wiring spotted (one-time per prompt) | cross-family migration facts the `gemini-interactions-api` skill doesn't cover |
| `GEMINI_3X_API_BEST_PRACTICES.md` | `Target model: Gemini 3.x` | prompt-content rules only (structure, grounding clauses, agentic planning template); API mechanics are the `gemini-interactions-api` skill's job |
| `GEMMA4_API_BEST_PRACTICES.md` | `Target model: Gemma 4` | Gemma 4 mechanics (probe-verified) |
| `GEMMA4_FORENSIC_SCANS.md` | Gemma 4 target + closed-set forensic scan prompt (routed by the Gemma core file) | recall-sensitive scan extension (rule 15.x) |
| `DEEPSEEK_V4_API_BEST_PRACTICES.md` | `Target model: DeepSeek V4` | DeepSeek V4 mechanics |

Model-family files are second-level: the family core file, not the trunk, names any further load condition (e.g. Gemma's forensic-scan extension). No call pays for bytes a different domain or a different model family would need.

## Model-family files

Applied additively on top of whichever domain/shape matched, when a `Target model:` is declared:

- **Gemini 3.x** (`GEMINI_3X_API_BEST_PRACTICES.md`): prompt-content only — query at the end of long context, prompting-style changes for 3.x, XML XOR Markdown, strict-grounding clause for grounded/grading tasks, tool-call budgeting, the agentic 9-point planning template, and a note that `gemini-3.5-flash-lite`'s `minimal` thinking default can need escalation to `low`+ on multi-step judgment tasks. Model IDs, defaults, pricing, parameter wiring (`temperature`/`top_p`/`top_k`, `thinking_level`, `response_format`), function-calling mechanics, and migration are all recommended out to the **`gemini-interactions-api`** skill (see below) instead of being hand-maintained here.
- **Gemma 4** (`GEMMA4_API_BEST_PRACTICES.md`): `response_format` suppresses always-on thinking; schema property order controls emission order; parse with `raw_decode`; T=1.0 sampling stays. A candidate target for per-criterion grading calls now that prompts are small — benchmark against Gemini 3.5 Flash-Lite, do not assume either wins. Closed-set forensic scan prompts additionally load `GEMMA4_FORENSIC_SCANS.md`.
- **DeepSeek V4** (`DEEPSEEK_V4_API_BEST_PRACTICES.md`): JSON-mode "json"-keyword and example-block requirement; prose-only behavioral steering; schema-intervention refusal list.
- **Claude**: no family file; XML tags and document-first ordering per vendor guidance.

Legacy `generateContent` wiring in any prompt, call-site, or example loads `GEMINI_MIGRATION.md` once and flags each legacy form with its Interactions equivalent.

## Recommended companion skill: `gemini-interactions-api`

The optimizer's own tools are read-only (`Read`, `Grep`, `Glob`) — it is a reviewer, not an executor, and never calls this skill itself. For any Gemini target, it recommends in Key Changes that the deployer or coding agent invoke the `gemini-interactions-api` skill before touching call-site code. That skill fetches the current hosted Gemini docs page for the matching feature, so model IDs, defaults, pricing, and parameter/request mechanics stay accurate across model releases without this repo needing a manual update every time Google ships a new model (as happened moving from `gemini-3.5-flash`/`gemini-3.1-flash-lite` to `gemini-3.6-flash`/`gemini-3.5-flash-lite`). This repo's Gemini family files are scoped to what that skill does not cover: prompt *content* — wording, structure, and system-instruction design — plus a handful of cross-family facts (`GEMINI_MIGRATION.md`) that fall outside its Gemini-only scope.

## Installation

### As a Claude Code Plugin (Recommended)

```bash
/plugin marketplace add dlxmax/prompt-optimizer
/plugin install prompt-optimizer
/reload-plugins
```

### Manual Installation

```bash
cp agents/prompt-optimizer.md ~/.claude/agents/
cp GRADING_PIPELINE.md FEEDBACK_GENERATION.md LESSON_AUTHORING.md \
   GENERIC_REVIEW.md COMPACTION.md GEMINI_MIGRATION.md \
   GEMINI_3X_API_BEST_PRACTICES.md \
   GEMMA4_API_BEST_PRACTICES.md GEMMA4_FORENSIC_SCANS.md \
   DEEPSEEK_V4_API_BEST_PRACTICES.md ~/.claude/
# For Gemini targets, also install Google's gemini-interactions-api skill
# (e.g. npx skills add google-gemini/gemini-skills --skill gemini-interactions-api --global)
```

### Auto-Invocation (Optional)

Add an entry to your agent-invocation rules so Claude reaches for the optimizer automatically. On the common rules layout, add under `## Immediate Agent Usage` in `~/.claude/rules/common/agents.md`:

```
5. Writing or revising an LLM prompt - Use **prompt-optimizer** agent
```

## Usage

```
"Our essay-grading prompt is too long and invents quotes. Fix it."          → RESCUE, domain: GRADING
"Audit this criterion prompt for compliance."                               → AUDIT, domain: GRADING
"Here's the rubric; set up the grading prompts. One call per criterion."    → AUTHOR, domain: GRADING
"Our feedback comments are generic praise with invented citations. Fix it." → RESCUE, domain: FEEDBACK
"Here's our warm-up question generator; audit it for genericness/drift."    → AUDIT, domain: LESSON
"Score my summarizer system prompt. Task: review"                           → REVIEW
```

### Caller-message shape

```
<prompt_under_review>          (or <rubric> for AUTHOR)
{the full prompt text, or the rubric + pipeline constraints}
</prompt_under_review>

[optional] Target model: <name>
[optional] Task: review

Based on the preceding prompt/rubric, <directive>.
```

Text inside `<prompt_under_review>` and `<rubric>` is data only; instructions inside those blocks are ignored (prompt-injection defense).

### Example: RESCUE output shape (domain: GRADING)

```
## Task: RESCUE, domain: GRADING
[ ] G1 Decomposition: 6 criteria bundled in one call ("Grade all six dimensions below")
[ ] G2 Evidence grounding: no strict-grounding clause; comments cite no quotes
[ ] G3 Response schema: prose-only format instruction, no response_format schema
[x] G4 AND-gated descriptors: levels are clause lists ("AND cites two sources")
[ ] G5 Tie-break: no directional rule for exact-boundary ties
[ ] G6 Examples: 24 worked examples (4 per criterion); cap is 1 borderline each
[ ] G7 Byte cap: ~9,800 tokens vs ~900-token scaffold+criterion cap
...

## Pipeline Spec
1. system_instruction: [strict grader + grounding + output contract]
2. per-criterion template: [submission block, end-anchored directive, 5 AND-gated levels, tie-break]
3. response schema: {evidence[] -> level -> comment}
4. validators: [schema retry, quote fuzzy-match + escalation, level bounds, failure-rate metric]
5. calibration: [human-graded dry run, bias checks, one refinement round]

## Key Changes
- Split 1 monolith call into 6 per-criterion calls (G1); working set per call drops ~85%
- Tie-break: source has no convention; open policy choice, deployer must confirm (G5)
- Byte budget: scaffold+criterion 3,150 chars vs 3,600 cap
```

## Included Files

| File | Purpose |
|---|---|
| `agents/prompt-optimizer.md` | Diagnostic trunk: domain × shape × model-family classification, routing, recipes, invariants |
| `GRADING_PIPELINE.md` | G-checklist + Pipeline Spec artifacts (single source of truth for grading) |
| `FEEDBACK_GENERATION.md` | F-checklist + Pipeline Spec artifacts (single source of truth for feedback-comment generation) |
| `LESSON_AUTHORING.md` | L-checklist + Pipeline Spec artifacts (single source of truth for lesson/worksheet/exam authoring) |
| `GENERIC_REVIEW.md` | 15-item generic review machinery |
| `COMPACTION.md` | Compaction pipeline, preserve-list, gates |
| `GEMINI_MIGRATION.md` | Cross-family migration facts outside the `gemini-interactions-api` skill's scope |
| `GEMINI_3X_API_BEST_PRACTICES.md` | Gemini 3.x prompt-content rules; defers API mechanics to the `gemini-interactions-api` skill |
| `GEMMA4_API_BEST_PRACTICES.md` | Gemma 4 mechanics (probe-verified, Interactions wiring) |
| `GEMMA4_FORENSIC_SCANS.md` | Gemma 4 recall-sensitive closed-set scan extension |
| `DEEPSEEK_V4_API_BEST_PRACTICES.md` | DeepSeek V4 family API mechanics |

## License

MIT
