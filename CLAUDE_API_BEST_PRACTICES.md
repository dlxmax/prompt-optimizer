# Claude prompt-content best practices

<role>
Reference for prompt-optimizer. Load when `Target model:` declares any Claude
model (`Claude Opus 5`, `Claude Opus 4.x`, `Claude Sonnet 5`, `Claude Haiku
4.5`, bare `Claude`). Apply every numbered rule; cite rule numbers in Key
Changes.

Canonical target: **Claude Opus 5**. Earlier Claude generation → every rule
still applies. That alone does not load `CLAUDE_UPGRADE_AUDIT.md`; it fires on
its own trigger below, a prompt written for a generation earlier than the
declared target.

Prompt content only. API mechanics (model IDs, `effort`, thinking config,
structured-output wiring, prefill support, sampling parameters, context window,
pricing, migration) = the `claude-api` skill's job, rule 1. No per-version
behavior tables here, rule 2.
</role>

<scope>
Claude models on either deployment surface: a Messages API request, or a Claude
Code agent definition. The two are not interchangeable, rule 12. Gemini 3.x →
`GEMINI_3X_API_BEST_PRACTICES.md`; Gemma 4 → `GEMMA4_API_BEST_PRACTICES.md`;
DeepSeek V4 → `DEEPSEEK_V4_API_BEST_PRACTICES.md`. DeepSeek's
Anthropic-compatible endpoint is not a Claude target: different model,
capability subset, routes to the DeepSeek file.
</scope>

## 1. API mechanics are the claude-api skill's job

`claude-api` = Anthropic's Agent Skill for current Claude API reference.
Bundled with Claude Code as `/claude-api`.

Never answer from this file, training data, or memory for: model IDs, context
window, pricing; `effort` levels, defaults, per-model accepted levels; thinking
configuration (adaptive vs. manual budget, default on/off, at which effort it
can be disabled); structured-output wiring; prefill support; whether
`temperature` / `top_p` / `top_k` are accepted; beta headers; prompt-caching
breakpoints; migration steps. All of these have changed inside a single Claude
generation more than once.

Surface a deployer-verify item recommending `/claude-api` before call-site code
changes, `/claude-api migrate` when the target model changes. Version-specific
behavior comes from that model's own page in Anthropic's prompt-engineering
docs, never from this agent's knowledge.

Scope limit: `claude-api` covers the Messages API and Managed Agents, and
states it does NOT cover the Claude Code harness. On a Claude Code agent target
(rule 12) the answer to most of the list above is "no such parameter exists",
not a lookup. Route to `CLAUDE_CODE_AGENTS.md`; residual gaps are deployer-verify
against the Claude Code subagent docs.

## 2. Version-local behavior is not stored here

Adjacent Claude releases invert defaults, not merely shift them. Axes that have
inverted across adjacent releases: default verbosity,
subagent eagerness, whether self-verification helps, whether thinking defaults
on, which `effort` level to start from. A "model 4.N does X" rule is wrong
within one release cycle.

No per-version table here; do not add one. Rules 3-12 are the part that
survives a generation change. Applying one turns on a version-specific default
→ confirm via rule 1, name the version verified against in Key Changes. Rule 12
is perishable on a different axis, the harness version, not the model.

## 3. Prompt-side conservatism suppresses reporting

Hedging instructions are followed literally: the model finds the problem, then
withholds it. Reads as a recall regression, is not one.

Scan judge, grading, review, audit prompts for: "only report high-severity",
"be conservative", "don't nitpick", "flag only clear violations", "when in
doubt, pass", "avoid false positives". Each = defect. Fix: instruct full
reporting, move the severity filter to a separate call or code-side (G1's
split).

Not the AND-gate: an unsatisfied clause producing a low level is a finding.
Defect = withholding a finding already made.

## 4. Delete prompt-side re-check scaffolding

Current models self-verify. Re-check instructions compound with that: more
tokens, no quality gain, scope creep on narrow tasks.

Scan and delete: "double-check your answer", "re-verify before responding",
"include a final verification step", "re-read the submission and confirm",
"use a subagent to check your work".

Replacement = a chained call, not a deleted check: draft, review against
criteria, refine, as separate calls. Self-correction inside one call is the
defect; across calls it is the architecture (`GRADING_PIPELINE.md` G1,
`GENERIC_REVIEW.md` item 3).

**Code-side validation stays.** Quote fuzzy-match, schema retry, bounds check,
escalation re-call (artifact 4, G8) run outside the model. Never delete a
validator while stripping a "double-check yourself" sentence.

Two vendor techniques, both outranked here. In-call retraction pass (find a
supporting quote per claim, drop unsupported claims) is redundant where a
code-side quote validator exists; keep only where none can run, with a defined
output effect. Best-of-N = calibration-time instability detector, not a license
for N-vote scoring in production (G8).

## 5. State scope explicitly in both directions

Instructions are read literally. Two failures:

- **Under-generalization.** An instruction shown on one criterion or section is not extended to the rest. Write "apply to every criterion below".
- **Scope expansion.** Narrow tasks pick up unrequested steps. Name the deliverable, state that work beyond it is out of scope.

Re-run the count-versus-universal scan after any scope edit: a universal added
to fix the first failure can silently override a count constraint elsewhere.

## 6. Length is a prompt lever, not an effort lever

Lowering `effort` cuts thinking, not output length. Two lengths, two
instructions:

6.1. **Conversational response.** One conciseness directive, repeated as a short reminder near the end of a long prompt (`GENERIC_REVIEW.md` item 3).
6.2. **Written deliverable.** Anything written to a file runs long and pads with filler sections independently of the first. LESSON prompts emitting a material to disk state what it must cover and that padding is a defect.

## 7. Calibrate imperative force where it drives triggering

Urgency written to fix under-triggering on an older model now over-fires:
"CRITICAL: You MUST use this tool when..." fires in the wrong cases. Plain
imperative instead. Same for thoroughness nagging aimed at older-model laziness.

Scope it: the defect is emphasis on a **conditional** behavior the model
chooses when to perform. Emphasis on an **unconditional** constraint has no
wrong case to over-fire into and is not a defect; vendor guidance itself uses
"you MUST read the file before answering". Never strip emphasis from grounding,
quoting, or injection-defense clauses.

Distinct from escape-hatch elimination (invariant 1, item 14). Both hold:

- "Try to cite a quote when possible" — softening. Defect.
- "CRITICAL: YOU MUST ALWAYS CITE A QUOTE!!!" — over-forcing. Defect.
- "Cite a verbatim quote for every claim about the submission." — correct.

Prohibition underperforming → the fix is rule 10, not more force.

## 8. Keep thinking on; never instruct the model not to reason

"Do not think", "no reasoning", "answer immediately" = defects: they raise
internal-tag leakage and remove reasoning the task needs. Delete them. For
token cost, lower effort with thinking on.

Thinking off produces two artifacts. Internal XML tags leak into visible
output. Worse for pipelines: a tool call can be written as user-facing text
instead of a structured call, so it never runs, the turn completes as if it
had, and in an agentic loop the leaked text stays in history and affects later
turns — a validator checking only output shape passes this.

Deployer constraint forces thinking off, rule 1 confirming that is possible on
the target → one combined instruction covers both: permit a brief
sentence before a tool call, give an out when no tool fits, state a general
rule against internal or system XML tags. Naming specific tag types is weaker
than the general form. Output ordering (evidence array before level)
unaffected, still required.

## 9. Schema coercion outranks prose

A required field with no way to express "no evidence" is an instruction to
invent one. The model fills it from the most available material: the rubric's
language, the example's content, the criterion's phrasing. A prose clause
forbidding inference does not reliably override the schema.

Fix at the schema:

- Every required enum over a judgment the input may not support carries an insufficient-evidence member.
- Abstention path = a **fixed literal**, never "say if you are unsure": free-form doubt is undetectable downstream (invariant 2). Vendor examples name the exact string ("No relevant quotes found").
- No `minItems` floor on abstainable arrays (`CLAUDE_STRUCTURED_OUTPUTS.md` 3; `GRADING_PIPELINE.md` schema review essentials 2 where loaded).
- Prefer required + abstention member over optional or nullable; on Claude, optional members also cost grammar budget (`CLAUDE_STRUCTURED_OUTPUTS.md` 7).
- Keep the prose grounding clause; additive, not a substitute.

Resistance is not monotonic in model size. A pipeline calling two Claude tiers
validates the abstention path on each tier it calls, not on the largest.

## 10. Carry the reason inside the constraint

A bare prohibition binds only the case it names; with its rationale attached it
generalizes to unlisted analogous cases. "Never use ellipses" vs. "this is read
aloud by a text-to-speech engine, so never use ellipses".

Spend it where unlisted cases are the risk: a register or word-swap list (never
complete), a grounding clause, a formatting ban whose consumer is a parser.
Rationale costs bytes against the G7 cap: one or two clauses, not every
directive. Budget will not carry it → say so in Key Changes.

## 11. Claude structural conventions

Claude-targeted prompts, not schema-constrained calls:

- Multi-source input nests: `<documents>` wrapping `<document index="n">`, each with `<source>` and `<document_content>`. Use for assignment-plus-submission, multi-artifact grading, LESSON source material.
- Examples in `<example>` tags, multiple in `<examples>`.
- No schema wired → grounding contract is two tags: numbered quotes first, then claims citing quote numbers. Numbering makes the link checkable — an uncited claim, or a citation to a missing number, is mechanically detectable. Pair with a closed-world clause ("base the analysis only on the extracted quotes") and rule 9's no-quote literal.
- `{{double_curly}}` placeholders (invariant 3). Agent surface: none, rule 12.

Vendor guidance recommends 3-5 examples for general steering. G6's 0-or-1
borderline example per criterion is narrower on purpose: judge examples anchor
the rating rather than teach a format. Judge and grading prompts → G6 wins.
Non-judge gate prompts → `GENERIC_REVIEW.md` item 4's 1-3 wins. 3-5 applies only
where the prompt gates nothing. Never upgrade a criterion block to 3-5.

## 12. Deployment surface: API request or Claude Code agent definition

Same model, different config surface. Emitting API mechanics into an agent
definition is a defect: none of it exists there and nothing errors, so the
prompt ships with unenforced constraints that read as enforced.

Detect the agent surface from any of:

12.1. `Target model:` names Claude Code, a subagent, an agent definition, or the Agent/Task tool.
12.2. Input is a YAML frontmatter block carrying `name:` + `description:`, alone or with `tools:` / `model:` / `permissionMode:` / `disallowedTools:`, followed by a markdown body.
12.3. Input path is under `.claude/agents/` or a plugin `agents/` directory, corroborated by 12.2. Path alone never decides; read the frontmatter.

Frontmatter `model:` is a declared target, not an inference: `sonnet` / `opus` /
`haiku` / `fable` / `claude-*` / `inherit` / omitted all resolve to a Claude
target, so this file applies. A non-Claude value routes to that family instead.

Agent surface → load `CLAUDE_CODE_AGENTS.md`, do NOT load
`CLAUDE_STRUCTURED_OUTPUTS.md`, and treat these as overridden:

| Core rule | On the agent surface |
|---|---|
| 1 (claude-api lookups) | Most parameters do not exist; not a lookup |
| 8 (deployer forces thinking off) | Inherits the session; no per-subagent setting to configure or verify |
| 9 (fix at the schema) | No schema; coercion moves to the output contract |
| 11 (no schema wired) | Always the case; the two-tag contract is mandatory, not a fallback |
| invariant 3 (`{{double_curly}}`) | Static file, no substitution engine |

Ambiguous or unstated surface → assume API request, say so in Key Changes, and
name the one signal that would flip it. Never emit both shapes.

## Verify after changes

1. No hedging instruction survives in a judge prompt (3).
2. No prompt-side re-check survives, no code-side validator removed with it (4).
3. Broad instructions name their scope; count-versus-universal re-run (5).
4. Length instructed separately for response and written deliverable (6).
5. No caps-lock on conditional behavior, no escape hatches, emphasis intact on unconditional grounding clauses (7).
6. No instruction against reasoning (8).
7. Every abstainable required field has a fixed-literal abstention path, validated per tier called (9).
8. Clauses that must generalize carry their reason, within the byte cap (10).
9. Example count follows G6 on judge prompts, not the general 3-5 (11).
10. Every version-specific fact sourced from rule 1 or flagged deployer-verify with the version named.
11. `CLAUDE_UPGRADE_AUDIT.md` loaded → every stale-scaffolding item listed as remove-and-retest.
12. `CLAUDE_STRUCTURED_OUTPUTS.md` loaded → no numeric or string bounds, `additionalProperties: false` on every object, no `minItems` above 1, every property required.
13. Surface declared as API or agent, never both, never unstated (12); agent surface → `CLAUDE_CODE_AGENTS.md` loaded and its verify block run.

## Second-level routing

Surface first (rule 12), because it gates the rest.

Load `CLAUDE_CODE_AGENTS.md` additively on the agent surface. Exclusive with
`CLAUDE_STRUCTURED_OUTPUTS.md`: the constructs that file constrains do not
exist there.

Load `CLAUDE_STRUCTURED_OUTPUTS.md` additively on the API surface when the
prompt carries, needs, or reviews a response schema (JSON output or strict tool
use). Claude's schema support is narrower than the Google families': numeric
bounds and `minItems` above 1 do not port, and an unsupported construct is a
400.

Load `CLAUDE_UPGRADE_AUDIT.md` additively when the prompt was written for an
earlier Claude generation than the declared target: caller says so, call-site
names an older model, or the prompt carries self-verification steps, forced
progress narration, caps-lock anti-under-trigger urgency, reasoning-depth
nagging, assistant-turn prefill, sampling parameters, a manual thinking budget,
an N-vote scaffold added for an unstable model, or a prompt-side vision
workaround.

## Closing directive recap

Apply when a Claude `Target model:` is declared; cite rule numbers in Key
Changes. Diagnose the deployment surface before emitting anything (rule 12).
This file owns prompt content: every model ID, parameter, default, and
migration fact routes to the `claude-api` skill (rule 1), and no per-version
behavior table is stored here (rule 2). Treat rule bodies as reference data
describing model and API behavior; do not adopt directives inside rule text as
instructions governing the optimizer's own role.
