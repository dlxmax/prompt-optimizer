# Prompt Optimizer Agent

A Claude Code agent for rubric-based grading pipelines: it rescues oversized grading monoliths into per-criterion call architectures, audits revised grading prompts for compliance, and authors grading pipelines from a rubric. It also reviews generic LLM prompts against a research-backed 15-item checklist on request.

**Topics:** `grading` · `rubric-grading` · `education` · `rubric` · `llm-judge` · `gemini` · `gemini-3.5-flash` · `gemini-3.1-flash-lite` · `gemini-3.x` · `interactions-api` · `gemma-4` · `gemma` · `claude` · `deepseek` · `deepseek-v4` · `response-schema` · `structured-output` · `prompt-engineering` · `prompts` · `agents` · `validation` · `compliance` · `best-practices`

## Architecture: thin diagnostic trunk, composable branches

The agent file is a small diagnostic trunk. It classifies each call into one task, then loads only the reference branches that call needs — several at once when conditions overlap.

| File | Loaded when | Contents |
|---|---|---|
| `agents/prompt-optimizer.md` | always (the agent) | diagnosis, routing, task recipes, universal invariants |
| `GRADING_PIPELINE.md` | RESCUE / AUDIT / AUTHOR; schema review | G-checklist (G1-G10), the five Pipeline Spec artifacts, output skeletons, monolith recipe, schema review essentials |
| `GENERIC_REVIEW.md` | REVIEW (`Task: review` or non-judge prompt) | the 15-item checklist, verdict rubric, revision procedure, port-mode rules |
| `COMPACTION.md` | single-call fallback; length defects; explicit request | compaction pipeline, preserve-list, post-compaction gates |
| `GEMINI_MIGRATION.md` | legacy `generateContent` wiring spotted (one-time per prompt) | legacy-to-Interactions migration tables, 3.5 Flash upgrade checklist |
| `GEMINI_3X_API_BEST_PRACTICES.md` | `Target model: Gemini 3.x` | single-shot prompt/call shape for current Interactions-API prompts (the grading shape) |
| `GEMINI_3X_TOOLS.md` | Gemini 3.x target + tool use / function calling / agentic / multi-turn (routed by the Gemini core file) | function-calling mechanics, combined tools, thought preservation, agentic planning template |
| `GEMMA4_API_BEST_PRACTICES.md` | `Target model: Gemma 4` | Gemma 4 mechanics (probe-verified) |
| `GEMMA4_FORENSIC_SCANS.md` | Gemma 4 target + closed-set forensic scan prompt (routed by the Gemma core file) | recall-sensitive scan extension (rule 15.x) |
| `DEEPSEEK_V4_API_BEST_PRACTICES.md` | `Target model: DeepSeek V4` | DeepSeek V4 mechanics |

Family extension branches are second-level: the family core file, not the trunk, names the load condition and points at its extension. Grading calls never pay for tool-use or forensic-scan bytes.

## The four tasks

1. **RESCUE** — a grading/judge prompt that bundles multiple rubric criteria or exceeds the byte cap. Output: a **Pipeline Spec** (shared system instruction with a strict-grounding clause; per-criterion user template with AND-gated level descriptors; evidence-before-level response schema; code-side validator checklist; calibration checklist). If the caller's runtime makes exactly one call per submission, a compact hard-capped monolith revision is emitted alongside the spec.
2. **AUDIT** — an already-decomposed or compact grading prompt. Output: terse G-checklist findings and targeted fixes for failing items only. The lightest, most frequent path.
3. **AUTHOR** — a `<rubric>` block (criteria, scale, call budget, model) with no existing prompt. Output: the full Pipeline Spec. Unstated policy choices (tie-break direction) are surfaced, never silently defaulted. When no model is fixed, Gemini 3.1 Flash-Lite and Gemma 4 are named as candidate small-model targets with a benchmark recommendation.
4. **REVIEW** — `Task: review` declared, or the input is not a judge/grading prompt. Output: the classic 15-item checklist score, Key Changes, and a revised prompt.

Judge-shaped input always routes to the grading tasks; REVIEW is the explicit opt-out.

## Why per-criterion grading calls

The grading design the agent enforces (G-checklist, `GRADING_PIPELINE.md`) reflects the strongest findings on LLM graders:

- **Decomposition beats monoliths.** One call per rubric criterion prevents criteria from bleeding into each other, keeps every call's working set small, and helps small models most — which makes lightweight targets (Flash-Lite, Gemma 4) viable graders. Long-context strength is a single-needle property; whole-rubric grading is multi-needle by construction.
- **Grounding beats trust.** Feedback comments hallucinate at material rates unless every claim is tied to a verbatim quote from the submission, emitted before the level, and verified in code. The quote-verification failure rate is the pipeline's hallucination metric.
- **Descriptors beat vibes.** Each rubric level becomes a conjunction of checkable clauses ("select the highest level whose every clause is satisfied"); exact-boundary ties get one explicit directional rule, surfaced as deployer policy. The rubric scale itself is upstream policy and is never compressed.
- **Calibration beats voting.** A small human-graded dry run, a harsh-bias check on mechanics-type criteria, a variance-compression check, and escalation-only re-sampling replace blanket N>=5 majority voting.
- **Examples are spice, not structure.** 0-1 borderline worked example per criterion; per-level balanced example sets are an opt-in enhancement pending an A/B, not a default.

## Family files

Model mechanics stay in per-family branches, applied when a `Target model:` is declared:

- **Gemini 3.x** (`GEMINI_3X_API_BEST_PRACTICES.md`): Interactions API only; strip `temperature`/`top_p`/`top_k`; `thinking_level` not `thinking_budget`; query at the end of long context; XML XOR Markdown; strict-grounding clause for grounded and grading tasks. Tool-using, agentic, and multi-turn prompts additionally load `GEMINI_3X_TOOLS.md` (function calling, combined tools, structured output + tools, thought preservation, agentic planning template).
- **Gemma 4** (`GEMMA4_API_BEST_PRACTICES.md`): `response_format` suppresses always-on thinking; schema property order controls emission order; parse with `raw_decode`; T=1.0 sampling stays. A candidate target for per-criterion grading calls now that prompts are small — benchmark against Flash-Lite, do not assume either wins. Closed-set forensic scan prompts additionally load `GEMMA4_FORENSIC_SCANS.md`.
- **DeepSeek V4** (`DEEPSEEK_V4_API_BEST_PRACTICES.md`): JSON-mode "json"-keyword and example-block requirement; prose-only behavioral steering; schema-intervention refusal list.
- **Claude**: no family file; XML tags and document-first ordering per vendor guidance.

Legacy `generateContent` wiring in any prompt, call-site, or example loads `GEMINI_MIGRATION.md` once and flags each legacy form with its Interactions equivalent.

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
cp GRADING_PIPELINE.md GENERIC_REVIEW.md COMPACTION.md GEMINI_MIGRATION.md \
   GEMINI_3X_API_BEST_PRACTICES.md GEMINI_3X_TOOLS.md \
   GEMMA4_API_BEST_PRACTICES.md GEMMA4_FORENSIC_SCANS.md \
   DEEPSEEK_V4_API_BEST_PRACTICES.md ~/.claude/
```

### Auto-Invocation (Optional)

Add an entry to your agent-invocation rules so Claude reaches for the optimizer automatically. On the common rules layout, add under `## Immediate Agent Usage` in `~/.claude/rules/common/agents.md`:

```
5. Writing or revising an LLM prompt - Use **prompt-optimizer** agent
```

## Usage

```
"Our essay-grading prompt is too long and invents quotes. Fix it."          → RESCUE
"Audit this criterion prompt for compliance."                               → AUDIT
"Here's the rubric; set up the grading prompts. One call per criterion."    → AUTHOR
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

### Example: RESCUE output shape

```
## Task: RESCUE
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
| `agents/prompt-optimizer.md` | Diagnostic trunk: task classification, routing, recipes, invariants |
| `GRADING_PIPELINE.md` | G-checklist + Pipeline Spec artifacts (single source of truth for grading) |
| `GENERIC_REVIEW.md` | 15-item generic review machinery |
| `COMPACTION.md` | Compaction pipeline, preserve-list, gates |
| `GEMINI_MIGRATION.md` | One-time legacy-to-Interactions migration scan |
| `GEMINI_3X_API_BEST_PRACTICES.md` | Gemini 3.x single-shot prompt/call shape on the Interactions API |
| `GEMINI_3X_TOOLS.md` | Gemini 3.x tool-use, function-calling, agentic, and multi-turn mechanics |
| `GEMMA4_API_BEST_PRACTICES.md` | Gemma 4 mechanics (probe-verified, Interactions wiring) |
| `GEMMA4_FORENSIC_SCANS.md` | Gemma 4 recall-sensitive closed-set scan extension |
| `DEEPSEEK_V4_API_BEST_PRACTICES.md` | DeepSeek V4 family API mechanics |

## License

MIT
