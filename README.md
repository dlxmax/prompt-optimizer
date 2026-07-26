# Prompt Optimizer Agent

A Claude Code agent that designs and reviews LLM prompts for education work:
rubric **grading**, prose **feedback comments**, and **lesson/worksheet/exam
authoring**. It also reviews generic prompts against a 15-item checklist.

It is an adversarial reviewer, not an assistant. It scores a prompt against the
checklist for its domain, then returns targeted fixes or a full pipeline spec.
Its tools are `Read`, `Grep`, `Glob` only: it hands you a spec and never edits
your files.

## What you get back

| Section | Contents |
|---|---|
| Checklist findings | one line per item, PASS / FAIL / N/A, each citing the evidence or its absence |
| Fixes *or* Pipeline Spec | targeted fixes for failing items (AUDIT), or artifacts 1-5 for a full build (RESCUE / AUTHOR) |
| Key Changes | what changed and why, citing item numbers, plus deployer-verify items |
| Optional Enhancements | behavior-shaping additions held back from the main spec, off by default |

Decisions that change a grade — tie-break direction, where an abstention lands —
are surfaced as open policy choices rather than silently defaulted. A full spec
covers the prompt text, the output contract, code-side validators, and a
calibration plan.

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

### Deployment surface (Claude targets)

The same Claude model has two incompatible config surfaces, so the family file
diagnoses which one you're on before applying anything:

- **A Messages API request** gets schema-based coercion: response schema, fixed abstention value, bounded enums.
- **A Claude Code agent definition** has no request body at all. Schemas, `max_tokens`, `stop_reason`, prefill, and sampling parameters do not exist in frontmatter, and nothing errors if you write them — so the coercion moves into a body output contract plus a fixed abstention literal instead.

Emitting API mechanics into an agent definition ships unenforced constraints
that read as enforced. Surface detection is by declared frontmatter, never by
filename or path. State the surface if you know it; unstated defaults to an API
request and says so.

## Files

Loaded additively, at most a handful per call.

| File | Loaded when |
|---|---|
| `agents/prompt-optimizer.md` | always — diagnosis, routing, recipes, invariants |
| **Domain** | |
| `GRADING_PIPELINE.md` | domain GRADING; also for schema review |
| `FEEDBACK_GENERATION.md` | domain FEEDBACK, or grading with PQS-shaped feedback |
| `LESSON_AUTHORING.md` | domain LESSON |
| `GENERIC_REVIEW.md` | generic domain, or `Task: review` |
| `COMPACTION.md` | a prompt has to shrink, or a duplicate is being cut |
| **Model family** | |
| `CLAUDE_API_BEST_PRACTICES.md` | `Target model:` any Claude |
| `GEMINI_3X_API_BEST_PRACTICES.md` | `Target model:` Gemini 3.x |
| `GEMMA4_API_BEST_PRACTICES.md` | `Target model:` Gemma 4 |
| `DEEPSEEK_V4_API_BEST_PRACTICES.md` | `Target model:` DeepSeek V4 |
| **Second-level** (a family file names its own) | |
| `CLAUDE_CODE_AGENTS.md` | the Claude target is an agent definition, not an API request |
| `CLAUDE_STRUCTURED_OUTPUTS.md` | a response schema is in play — exclusive with the file above |
| `CLAUDE_UPGRADE_AUDIT.md` | a prompt is being carried to a newer Claude |
| `GEMINI_MIGRATION.md` | legacy `generateContent` wiring, or a cross-generation port |
| `GEMMA4_FORENSIC_SCANS.md` | closed-set scan tasks on Gemma 4 |

Family files carry **prompt content only**. Model IDs, parameters, defaults, and
migration steps are deferred to the vendor's own skill — Anthropic's `claude-api`
(bundled with Claude Code) and Google's `gemini-interactions-api` — because those
stay current across model releases and a hand-maintained file cannot. The one
exception is the Claude Code agent surface, which `claude-api` states it does not
cover; those facts are version-floored in `CLAUDE_CODE_AGENTS.md` and flagged as
perishable.

## Install

```bash
/plugin marketplace add dlxmax/prompt-optimizer
/plugin install prompt-optimizer
/reload-plugins
```

Invoke as `prompt-optimizer:prompt-optimizer`. Updates are version-gated, so
`/plugin update` then `/reload-plugins` after a new release.

Manual install instead: copy `agents/prompt-optimizer.md` to `~/.claude/agents/`
and the `*.md` reference files to `~/.claude/`. Don't do both — a copy in
`~/.claude/agents/` registers a second agent under the bare name
`prompt-optimizer` and will happily answer with whatever version you last
copied.

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

Reference files resolve from your working directory first, then from the
installed plugin cache, so it works both in a checkout and anywhere else. If a
routed file can't be loaded it says which one and refuses to score rather than
reviewing you against rules it never read.

## License

MIT
