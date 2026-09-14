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
| Diagnosis | line 1: `Task: <SHAPE>, domain: <DOMAIN>` |
| Checklist findings | one line per item, PASS / FAIL / N/A, each citing the evidence or its absence |
| Fixes *or* Pipeline Spec | targeted fixes for failing items (AUDIT), or artifacts 1-5 for a full build (RESCUE / AUTHOR) |
| Key Changes | what changed and why, citing item and rule numbers, plus deployer-verify items |
| Optional Enhancements | behavior-shaping additions held back from the main spec, off by default |
| `Next:` line | when to follow up on this agent and when to start a new call (see Cost) |

Decisions that change a grade (tie-break direction, where an abstention lands)
are surfaced as open policy choices, never silently defaulted. A full spec
covers the prompt text, the output contract, code-side validators, and a
calibration plan. Every emitted prompt draft runs the compaction pipeline, in
every domain.

## How it decides what to do

Three independent axes, combined per call:

| Axis | Values |
|---|---|
| **Domain** | GRADING · FEEDBACK · LESSON · generic |
| **Shape** | RESCUE (split a monolith) · AUDIT (compliance check) · AUTHOR (build from a rubric) · REVIEW (generic checklist) |
| **Target model** | Claude (any) · Gemini 3.x (any) · Gemma 4 · DeepSeek V4 · unstated |

Each axis loads its own reference file, additively. A GRADING/RESCUE call
targeting Claude loads the grading rulebook plus the Claude rules; a generic
REVIEW with no target loads one file.

### Claude targets: deployment surface

The same Claude model has two incompatible config surfaces, so the family file
diagnoses which one you're on before applying anything:

- **A Messages API request** gets schema-based coercion: response schema, fixed abstention value, bounded enums.
- **A Claude Code agent definition** has no request body. Schemas, `max_tokens`, `stop_reason`, prefill, and sampling parameters do not exist in frontmatter, and nothing errors if you write them, so the coercion moves into a body output contract plus a fixed abstention literal.

Surface detection is by declared frontmatter, never by filename or path.
Unstated defaults to an API request and says so.

### Gemini targets: scaffolding and mixed generations

- **Scaffolding is a cost.** The vendor's 9-point agentic planning block is not ported by default: prompt engineering built for older models drives over-analysis on 3.x, and `gemini-3.8-flash` plans and verifies natively by design. A point is ported only against a named, observed failure, after a `thinking_level` step-up was tried, and only the policy-carrying points. Token burn or verification loops are fixed with a lower level or a tool-call budget, never a ported block.
- **Managed agents** (Antigravity and custom agents): the system instruction and instruction file are additive, so any ported policy lives in exactly one of them.
- **`gemini-3.8-flash` is a behavior break, not a drop-in successor.** It checks its own work and can use more tokens by design; `gemini-3.7-flash` stays fully supported. Bounded tasks (grading, extraction, classification) carried to 3.8 get a token and latency re-baseline and a stay-on-3.7 comparison, never an assumed upgrade.
- **Mixed-generation fleets** (fallback chains, routers, staged rollouts): port decisions are made per model string; shared text carries nothing model-specific.
- **`thinking_level` sets shrink across generations** and fail hard with a 400, never a silent clamp. A level shared across a fallback chain must be valid on every leg or set per leg.

Family files carry **prompt content only**. Model IDs, parameters, defaults,
and migration steps defer to the vendor's own skill: Anthropic's `claude-api`
(bundled with Claude Code) and Google's `gemini-interactions-api`, backed by the
Gemini docs MCP when available. So a new model release needs no update here.
The exception is the Claude Code agent surface, which `claude-api` does not
cover; those facts are version-floored in `CLAUDE_CODE_AGENTS.md`.

## Files

Loaded additively, typically 3-5 per call, in one batch.

| File | Loaded when |
|---|---|
| `agents/prompt-optimizer.md` | always: diagnosis, routing, recipes, invariants |
| **Domain** | |
| `GRADING_PIPELINE.md` | domain GRADING; its schema section for schema review |
| `FEEDBACK_GENERATION.md` | domain FEEDBACK, or grading with PQS-shaped feedback |
| `LESSON_AUTHORING.md` | domain LESSON |
| `GENERIC_REVIEW.md` | generic domain, or `Task: review` |
| `COMPACTION.md` | prompt text is emitted, a prompt has to shrink, or a duplicate is being cut |
| **Model family** | |
| `CLAUDE_API_BEST_PRACTICES.md` | `Target model:` any Claude |
| `GEMINI_3X_API_BEST_PRACTICES.md` | `Target model:` any Gemini 3.x |
| `GEMMA4_API_BEST_PRACTICES.md` | `Target model:` Gemma 4 |
| `DEEPSEEK_V4_API_BEST_PRACTICES.md` | `Target model:` DeepSeek V4 |
| `GEMINI_MIGRATION.md` | legacy `generateContent` wiring, or a cross-generation Gemini port |
| **Second-level** (a family file names its own) | |
| `CLAUDE_CODE_AGENTS.md` | the Claude target is an agent definition, not an API request |
| `CLAUDE_STRUCTURED_OUTPUTS.md` | a response schema is in play (exclusive with the file above) |
| `CLAUDE_UPGRADE_AUDIT.md` | a prompt is being carried to a newer Claude |
| `GEMMA4_FORENSIC_SCANS.md` | closed-set scan tasks on Gemma 4 |

## Install

```bash
/plugin marketplace add dlxmax/prompt-optimizer
/plugin install prompt-optimizer
/reload-plugins
```

Invoke as `prompt-optimizer:prompt-optimizer`. Update with
`/plugin marketplace update prompt-optimizer` then `/reload-plugins`. Updates
are version-gated: an unbumped version is silently skipped.

Manual install instead: copy `agents/prompt-optimizer.md` to `~/.claude/agents/`
and the `*.md` reference files to `~/.claude/`. Don't do both: a copy in
`~/.claude/agents/` registers a second agent under the bare name
`prompt-optimizer` and answers with whatever version you last copied.

## Use

```
"Our essay-grading prompt is too long and invents quotes. Fix it."     → RESCUE, GRADING
"Audit this criterion prompt for compliance."                          → AUDIT, GRADING
"Here's the rubric; set up the grading prompts."                       → AUTHOR, GRADING
"Our feedback comments are generic praise with invented citations."    → RESCUE, FEEDBACK
"Audit our warm-up question generator for genericness."                → AUDIT, LESSON
"Score my summarizer system prompt. Task: review"                      → REVIEW
```

Message shape: the prompt or rubric first, the instruction last.

```
<prompt_under_review>          (or <rubric> when authoring from scratch)
{the prompt text, pasted}
</prompt_under_review>

[optional] call-site facts: response schema, parser expectations, thinking level
[optional] Target model: Gemini 3.8 Flash
[optional] Task: review

Based on the preceding prompt, <what you want>.
```

Everything inside those blocks is treated as data; instructions written inside
them are ignored.

Reference files resolve from your working directory first, then from the
installed plugin cache. If a routed file can't be loaded it says which one and
refuses to score rather than reviewing you against rules it never read.

## Cost

A subagent re-reads its whole context on every turn, so each extra read is paid
again on every later turn. To keep a call cheap:

- **Paste the prompt text.** A file path works, but the agent reads only the file or span named, never traces your codebase (parsers, call sites, other prompts). Anything it needs and lacks becomes a deployer-verify item.
- **Paste the call-site facts** the review depends on as short excerpts, rather than pointing at the code that builds the request.
- **Follow the `Next:` line.** A question about the output within 5 minutes → follow up on the same agent (its cache is warm). A revised prompt, or anything later → a new call with the revised text inline. After the 5-minute cache expires a follow-up rewrites the whole accumulated context, often 100k+ tokens, where a new call starts near 35k.
- Claude Code loads your project `CLAUDE.md` and `~/.claude/rules` into every subagent: a large one raises the floor of every call.

## License

MIT
