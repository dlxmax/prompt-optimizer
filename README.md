# Prompt Optimizer Agent

A Claude Code agent that designs and reviews LLM prompts for education work:
rubric **grading**, prose **feedback comments**, and **lesson/worksheet/exam
authoring**. It also reviews generic prompts against a 15-item checklist.

It is an adversarial reviewer, not an assistant. Give it a prompt and it scores
it against the checklist for its domain, then returns either targeted fixes or a
full pipeline spec — decomposed into one call per criterion or section, with a
response schema (or a text output contract, where the target's deployment
surface has no schema mechanism), code-side validators, and a calibration plan.

## How it decides what to do

Three independent axes, combined per call:

| Axis | Values |
|---|---|
| **Domain** | GRADING · FEEDBACK · LESSON · generic |
| **Shape** | RESCUE (split a monolith) · AUDIT (compliance check) · AUTHOR (build from a rubric) · REVIEW (generic checklist) |
| **Target model** | Claude · Gemini 3.x · Gemma 4 · DeepSeek V4 · unstated |

Each axis loads its own reference file, additively. A GRADING/RESCUE call
targeting Claude loads the grading rulebook plus the Claude rules; a generic
REVIEW with no target loads one file. Nothing pays for bytes it doesn't need.

## Files

| File | Loaded when |
|---|---|
| `agents/prompt-optimizer.md` | always — diagnosis, routing, recipes, invariants |
| `GRADING_PIPELINE.md` | domain GRADING; also for schema review |
| `FEEDBACK_GENERATION.md` | domain FEEDBACK, or grading with PQS-shaped feedback |
| `LESSON_AUTHORING.md` | domain LESSON |
| `GENERIC_REVIEW.md` | generic domain, or `Task: review` |
| `COMPACTION.md` | a prompt has to shrink |
| `CLAUDE_API_BEST_PRACTICES.md` | `Target model:` any Claude (+ three branches: deployment surface, schema shape, upgrade audit) |
| `CLAUDE_CODE_AGENTS.md` | the Claude target is a Claude Code agent definition, not a Messages API request |
| `GEMINI_3X_API_BEST_PRACTICES.md` | `Target model:` Gemini 3.x (+ `GEMINI_MIGRATION.md` on legacy wiring) |
| `GEMMA4_API_BEST_PRACTICES.md` | `Target model:` Gemma 4 (+ `GEMMA4_FORENSIC_SCANS.md` for closed-set scans) |
| `DEEPSEEK_V4_API_BEST_PRACTICES.md` | `Target model:` DeepSeek V4 |

Family files carry **prompt content only**. Model IDs, parameters, defaults, and
migration steps are deferred to the vendor's own skill — Anthropic's `claude-api`
(bundled with Claude Code) and Google's `gemini-interactions-api` — because those
stay current across model releases and a hand-maintained file cannot.

## Install

```bash
/plugin marketplace add dlxmax/prompt-optimizer
/plugin install prompt-optimizer
/reload-plugins
```

Or copy `agents/prompt-optimizer.md` to `~/.claude/agents/` and the `*.md`
reference files to `~/.claude/`.

## Use

```
"Our essay-grading prompt is too long and invents quotes. Fix it."     → RESCUE, GRADING
"Audit this criterion prompt for compliance."                          → AUDIT, GRADING
"Here's the rubric; set up the grading prompts."                       → AUTHOR, GRADING
"Our feedback comments are generic praise with invented citations."    → RESCUE, FEEDBACK
"Audit our warm-up question generator for genericness."                → AUDIT, LESSON
"Score my summarizer system prompt. Task: review"                      → REVIEW
```

Message shape it expects — the prompt or rubric first, the instruction last:

```
<prompt_under_review>          (or <rubric> when authoring from scratch)
{the prompt text, or a file path}
</prompt_under_review>

[optional] Target model: Claude Opus 5
[optional] Task: review

Based on the preceding prompt, <what you want>.
```

Everything inside those blocks is treated as data. Instructions written inside
them are ignored.

## License

MIT
