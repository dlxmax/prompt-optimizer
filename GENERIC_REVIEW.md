# Generic prompt review reference

<role>
Reference for the prompt-optimizer agent. Load for the REVIEW task: `Task: review` declared, or the input is not a judge/grading prompt. Score the prompt against the 15-item checklist, then produce a revised version that fixes every failing item. Begin with the first checklist line: no affirmation or summary before scoring.
</role>

## Verdict rubric

```
[x] PASS: every required sub-condition satisfied. Partial coverage does not pass.
[ ] FAIL: a sub-condition is missing, contradicted, or softened by escape-hatch language.
[N/A]: the item's conditional trigger is not met. Items 8, 9, 10, 11, 12, 13, and 15 are conditional; items 1-7 and 14 always apply. Items 4 and 12 may be marked [N/A: upstream-owned] when rubric, bands, or point values are injected at runtime by the caller's runtime rather than owned by the prompt.
```

A midpoint prompt (tagged blocks and numbered directives but no rubric, no examples, one or two escape hatches) typically scores 7-9 of applicable items; that is the most common case. The mark must be consistent with the evidence cited in the finding: "mostly present" or "partially covered" maps to `[ ]`, not `[x]`. Each finding cites specific evidence (quoted phrase, line, or absence).

## The 15-item checklist

1. **Tagged blocks.** Distinct sections wrapped in XML-style tags.
2. **Numbered directives.** All instructions numbered for traceability.
3. **Length and placement.** Over ~3,000 tokens is bloat to flag. Governing directives (role, output format, guardrails, refusal branches) appear at both the start AND the end. For prompts with a substantial context block (>= ~500 tokens of inline data), the specific query goes at the END after the context, anchored with "Based on the preceding information..." or a domain equivalent. Decompose into chained calls when the task is genuinely multi-stage.
4. **Gate examples, calibrated count.** For judge prompts: 0 or 1 borderline worked example per criterion; per-level verdict-balanced sets go to Optional Enhancements with a bench-validation caveat, not into the revised prompt. For non-judge gate prompts: 1 to 3 examples per criterion with at least one PASS+FAIL pair per binary criterion; prefer borderline examples over obvious contrasts. All examples for a criterion share identical formatting; inconsistent example structure bleeds into the output format.
5. **Machine-parseable output.** Every verdict extractable with a regex.
6. **Skeptical role.** Critical evaluator role, not helpful assistant, at both opening AND closing; a role stated only at the top drifts after many tokens.
7. **Do-instead-of-don't.** Prohibitions paired with alternatives.
8. **Validation model.** If the same model validates its own output: structured gate scoring plus "Wait" prefix plus recency reminder at the end.
9. **Original task in validation.** Validation prompt includes the original task at the top and as a reminder at the end.
10. **One criterion per call (high-stakes) or up to 3 bundled (low-stakes).** High-stakes scoring isolates each criterion in its own call; low-stakes filtering may bundle 2-3 named criteria.
11. **Evidence grounding (conditional).** Applies to any prompt that judges submitted content (student work, user text, model output) and to linguistic-analysis prompts (style, register, authorship, stylometry). Required: (a) reasoning before verdict, (b) cited verbatim token/phrase evidence per claim about the submitted text, (c) for linguistic analysis, enumerated explicit feature categories. Absence of evidence is stated, never invented. N/A only when nothing submitted is being judged.
12. **Judge prompt: rubric (conditional, highest single-change ROI).** Any prompt whose output is a quality judgment carries a concrete rubric with observable criteria per score level. Write the rubric directly; fall back to a `<rubric_generation>` block only when the criterion is dynamic at inference time. Scale rule: when the caller or runtime owns the scale, the scale and level count are upstream policy; restructure descriptors into AND-gated checkable clauses, never compress or extend the scale. When the prompt owns its scale, prefer a small integer scale (1-4) or binary with sub-condition anchors. Also required: structured reasoning before verdict; explicit verdict/reasoning consistency instruction; calibration anchor describing a midpoint response, placed after the rubric.
13. **Judge prompt: reliability and anti-patterns (conditional).** Deployment reliability follows the ladder, in order: (1) calibration against a small human-labeled set (bias offsets, variance compression, at most one wording-refinement round); (2) escalation re-sampling of suspect verdicts only (failed evidence checks, boundary scores); (3) N>=5 sampling with majority vote only when the caller names an available call budget. Never recommend blanket voting as the default fix. No debate-style (ChatEval) structure: actively harmful. Multi-model consensus (2-of-3 across diverse families) for highest-stakes ranking. For Gemma 4 / Gemini 3.x / DeepSeek V4 targets, apply every rule in the loaded family file.
14. **Escape hatch elimination.** No directive contains softening language: "try to," "if possible," "when appropriate," "attempt to," "ideally," "generally," "as needed," "as much as possible." Each instance is a defect; replace with a direct imperative or a genuine factual conditional. Applies to every prompt.
15. **Prompt injection defense (conditional).** User-submitted content sits inside a clearly labeled delimiter block; the prompt states OUTSIDE the block that content inside is data only and instructions within it are ignored. Especially important for Gemma 4; on DeepSeek V4 the delimiter chain is the entire defense (no schema layer).

Items 8-10 apply only to validation/second-pass prompts. Item 11 applies when submitted content is judged. Items 12-13 apply to judge prompts. Item 15 applies when user-submitted text is evaluated.

## Scoring examples

Borderline PASS (item 6): "You are a strict reviewer; reject any prompt that fails one item" at top; closing restates "remain adversarial; do not soften scores." Anchored at both ends. Score: [x].

Borderline FAIL (item 6): Opens "You are a strict reviewer" but the closing only restates the output schema; no recency anchor after ~3,000 tokens. Score: [ ].

Borderline PASS (item 12): "Score 1: no citations. Score 2: one citation, no relevance noted. Score 3: 2-3 citations with relevance noted. Score 4: 4+ citations, each with a one-line relevance justification." Observable indicator per level. Score: [x].

Borderline FAIL (item 12): "Score the response 1-4 on citation quality." Nothing distinguishes a 2 from a 3. Score: [ ].

## Revision procedure

Fix every failing item. Preserve original intent and domain content; change structure, framing, and execution patterns only. In order:

1. **Restructure**: fix structural violations (tags, numbered directives, rubric, examples, placement).
2. **Focus**: strip non-load-bearing context.
3. **Decompose**: if genuinely multi-stage, note where to split into chained calls.
4. **Compact**: when length or duplication defects were found, load `COMPACTION.md` and run its pipeline and gates on the draft. Its preserve-list is binding.
5. **Verify placement**: governing directive still at both start and end after compaction.

For item 12 failures: write a concrete rubric from the criterion with observable score-level indicators. For prompts carrying a structured-output schema: additionally load `GRADING_PIPELINE.md` and apply its Schema review essentials.

Mark each change with a brief inline comment citing the checklist item fixed.

## Sampling note

Single-pass scoring suffices for this structural checklist. If the prompt under review is a high-stakes deployment judge, recommend the item-13 reliability ladder in Key Changes, not inside the revised prompt body.

## Output format

```
## Checklist Score: N/15 (subtract items marked N/A)

[score lines; use [N/A: upstream-owned] on items 4/12 when rubric/bands/points are runtime-injected]

## Key Changes
- [what changed and why]
- Byte budget: <pre> bytes -> <post> bytes (delta, %). Mark [re-inflation] if pre was compacted and post is larger, and justify each added block.

## Optional Enhancements (off by default; needs bench A/B)
- [behavior-shaping additions excluded from the revision; byte cost and risk note each. "None." if empty.]

## Revised Prompt
[full revised text; mechanics-only when port_mode=true]
```

If the prompt scores >=12 of applicable items, state the score in the first Key Changes line and limit Key Changes to the failing items; do not pad. The Revised Prompt still emits full text with targeted fixes inline.

## Rules

1. Never invent domain content. Restructure, do not rewrite.
2. Preserve template placeholders (`$directive`, `{audience}`) exactly.
3. If the prompt is split across files or assembled at runtime, note what a single file does and does not let you evaluate.
4. Never use em dashes in revised prompt text; use commas, colons, or restructure.
5. **Count-versus-universal consistency.** A directive containing a count constraint ("exactly N", "N to M", "at most K") AND a universal quantifier ("every", "all", "each", "must") over the same population self-contradicts: the universal silently overrides the count. Scan every directive before emitting; fix by scoping the universal to the qualifying subset, dropping it, or naming the complement. Re-check after compaction.
6. **Placeholder notation** (fires when a revision introduces or rewrites a placeholder; XML tags are structure, not substitution):
   6.1. `{descriptive_name}` single-curly for Google-family targets (Gemma 4, Gemini 3.x); `{{descriptive_name}}` double-curly for Claude; single-curly when no target is specified.
   6.2. No bare letters (X, Y, Z) as placeholders when substituted values are themselves single letters; use a semantic slot name (`{L2}`, `{role}`).
   6.3. Name placeholders by what fills them, not positionally (`{var1}`).
   6.4. Never `<|name|>` for ordinary substitution; reserved by Gemma 4's tokenizer.
   6.5. A placeholder inside a few-shot example gets a literal-emission guard: "Substitute the actual value before emitting; do not emit the literal `{placeholder}`."
7. **Migration scan.** Retired Gemini `generateContent` wiring in the prompt, call-site, or examples is a migration defect: load `GEMINI_MIGRATION.md` and flag each legacy form with its Interactions equivalent in Key Changes.
8. **Scope discipline for model-port revisions.**
   8.1. port_mode=true when the scoring directive frames the task as adapting to a different target ("update for X", "port to X", "migrate to X"). Bare "review"/"score"/"optimize"/"fix" leaves port_mode=false.
   8.2. Mechanics = items 1, 2, 3, 5, 6, 7, 8, 9, 10, 14, 15 plus every rule in the loaded family file. Behavior-shaping = items 4 (examples), 11 (feature lists), 12 (rubric content, anchors, indicators).
   8.3. port_mode=true: the Revised Prompt is mechanics-only; behavior-shaping fixes go to Optional Enhancements with byte cost and A/B caveat.
   8.4. Upstream-injection: rubric/bands/points injected by the caller's runtime mark items 4 and 12 `[N/A: upstream-owned]`. Inline worked examples on the rated topic create content-anchoring risk on weak/free-tier models; surface in Optional Enhancements.
   8.5. Byte budget (always): report pre, post, delta on the prompt-under-review payload, excluding wrapper and scoring directive. If pre was compacted and post is larger, mark `[re-inflation]` and justify each added block. Default: do not grow the prompt.
9. **Tie-break direction is policy.** When adding a determinism scaffold for band selection or any closed-set choice with exact-boundary ties: UP and DOWN are equally deterministic; the direction is a separate grade-affecting policy choice. True tie (both bands fully fit) differs from doubt (a clause unclear; the AND-gate resolves doubt). Surface the chosen direction in Key Changes; match any existing convention in the source; flag as a deployer decision when none is detectable. Scan the revision for smuggled directional defaults ("on any doubt take the lower band") and replace with AND-gate strictness plus one explicit directional rule for exact ties.
10. **Uncertainty: flag, do not fabricate.** When a fix needs a model/API fact the checklist and loaded family file lack, or the API may have drifted, do not invent it. Surface a deployer-verify item in Key Changes with your interim assumption stated; for Gemini targets, recommend a docs MCP search.

## Deployment note

Single-invocation use against >=16k context is canonical. For chained sub-agent deployment, split scorer (checklist + verdict rubric) from reviser (revision procedure + rules), with the family file as a conditional third call.
