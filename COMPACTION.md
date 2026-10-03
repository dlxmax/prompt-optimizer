# Compaction reference

<role>
Reference for prompt-optimizer. Load whenever prompt text is emitted (RESCUE,
AUTHOR, any full revision), or a prompt must shrink: any shape cutting a bloat sign (trunk
`<verdicts>`), or explicit caller request. A duplicate deleted without the anchor test below is the
failure mode this file exists to prevent, so the shape does not gate the load.
Run pipeline in order (cut 1-9, then densify 10-13), then gates, then
re-verify placement. Cite as `COMPACTION.md step N`, `preserve-list
<letter>`, or `gate N`.
</role>

## Compaction pipeline

Apply to draft revision, in order:

1. Cut opening sentences describing what the prompt does or acknowledging the model. Keep the opening sentence where it is itself a load-bearing directive, the role statement, or the grounding clause.
2. Verbose -> imperative. "Please make sure to always..." -> "Always...". "You should ensure that..." -> "Ensure...". "When you encounter a case where..." -> "If...".
3. Cut unintentional mid-prompt duplicates, each cleared first by the anchor test (preserve-list f). Keep intentional start-and-end repetition of governing directives. Governing directive = a JSON output schema: emit full spec once, close with a brief shape echo or "do not restart the object" guard, never a second field-by-field contract.
4. Cut background explaining motivation without changing behavior. Exception: feature-category lists in linguistic-analysis prompts are behavior-changing instruction: keep.
5. Examples over ceiling -> trim to the ceiling the loaded domain file sets: grading 0 or 1 borderline per criterion (G6), FEEDBACK/LESSON one PASS+FAIL pair per gate (F4, L4), generic gate prompts 3 per criterion. No domain file loaded -> 3 per criterion. Zero is legal under G6, and cutting the example is G7's named ratio fix. Gemma 4 forensic scans: PASS-example density is owned by `GEMMA4_FORENSIC_SCANS.md` 15.2, never cut below it.
6. Cut instructional comments inside output template blocks. Keep the literal-emission guard on any placeholder inside a worked example (invariant 3): a directive to the model, not a comment. Never rename canonical field tags (`<reasoning>`, `<verdict>`, `evidence`, `level`, `comment`): parsers key on exact names.
7. Escape hatches out: scan every directive for "try to", "if possible", "when appropriate", "attempt to", "ideally", "generally", "as needed", "as much as possible" -> direct imperative or genuine factual conditional. Exempt occurrences inside checklists and scan-target listings, where the word is named not used; defect = word in imperative position.
8. Cut courtesy markers ("kindly", "please", "feel free to", "as you see fit") and filler connectives ("Furthermore", "In addition", "Moreover", "It is important to note that"). Zero signal in directive blocks.
9. Threshold prose -> numeric. "scores below three" -> `<=2`. "more than five examples" -> `>5`. Range with unstated endpoints ("between 20 and 40 percent"): intent known -> `>=20% and <=40%`; unknown -> keep words, flag in Key Changes (a value on the boundary has no band). Never `20-40%`: it hides the gap.

## Densification

Densify after cutting: 1-9 delete, 10-13 re-encode survivors. Grammar is not
a goal; gate 3 recoverability is.

10. **Telegraphic lines.** Drop articles, copulas, model-as-subject. "The grader must check that the quote is present in the submission before the level is assigned." -> "Check quote present in submission before assigning level." Largest per-line win; apply before notation. Exempt: preserve-list b, and any subject naming who acts (model / parent / deployer).

11. **Multi-word relation -> operator.** Two or more English words only: a one-word term already costs one token, so the swap buys nothing and spends readability. ASCII digraph over unicode glyph, never costlier and sometimes cheaper (`!=` beats `≠`). Numeric thresholds: step 9.

| Emit | For |
|---|---|
| `<=` | at most, no more than, less than or equal to |
| `>=` | at least, no fewer than |
| `!=` | is not, does not equal |
| `->` | leads to, results in, maps to, then |
| `in {a,b,c}` | is one of, is a member of |

Never, no saving and sometimes a cost: `and`->`&`/`∧`, `or`->`|` (collides
with table syntax), `with`->`w/`, bare `percent`->`%`, `maximum`->`max`,
`each`->`∀`, `if and only if`->`iff` (reads as a typo of `if`), any one-word abbreviation (`criterion`->`crit`, `required`->`req`,
`evidence`->`ev`).

12. **Parallel cases -> table.** Repeated field labels are paid once per item; emit one header row, N data rows. Level descriptors, per-criterion config, any "X means..., Y means..." run. Compresses labels, not discriminating language: preserve-list b governs cell contents.

13. **Negation and scope stay lexical.** Keep "must not", "never", "do not", `only`, `unless`, `except`, `at least one`. Saves ~one token; a misread inverts the directive. `!` as a negation prefix is banned.

## Preserve-list

Never compaction targets. Step above would touch one -> skip that step for that text:

a. Intentional start-and-end repetition of governing directives (role, output format, guardrails).
b. Rubric numeric scale, per-level anchor descriptions, AND-gated level clauses.
c. Canonical field tag and property names (`<reasoning>`, `<verdict>`, `<criterion>`, `<rubric>`, `evidence`, `level`, `comment`).
d. Verdict/reasoning consistency instruction ("mark must be consistent with cited evidence").
e. Example floor: the loaded domain file's floor, never a global one. One PASS+FAIL pair per gate for FEEDBACK (F4) and LESSON (L4); >=1 PASS+FAIL pair per criterion for generic gate prompts; no floor for grading, where G6 admits 0.
f. Anchor test: before dropping a line as "duplicate", confirm it is not the only EXPLICIT statement of its rule. Trigger conditions and list memberships elsewhere are not anchors.
g. Schema-versus-prose: a prose clause covering ground a schema field also covers (grounding, abstention, bounds) is additive, not a duplicate (`GRADING_PIPELINE.md` schema review essentials 2, 6). Cut only field-by-field restatement of the schema shape.

## Post-compaction gates

1. Token estimate pre -> post; no size cap (trunk `<verdicts>`). Per-run cost or a stated rate limit still binding after the full pipeline -> decomposition required, not optional: write "split before deployment" in Key Changes and name the split boundary.
   **Divisor is density-dependent.** `len/4` prose, `len/3` for any block carrying steps 10-13. Score the output on the divisor its final form earns, not the input's: characters fall faster than tokens under densification, so `len/4` on a densified block overstates the cut.
2. Re-run count-versus-universal check on the post-compaction draft: count constraint ("exactly N", "N to M", "at most K") + universal ("every", "all", "each") over the same population = contradiction; scope the universal, drop it, or name the complement.
3. Semantic round-trip every densified line: restate the original directive without consulting it. Fails when the expansion is not unique: `/` as "per" or "or", `|` as "or" or column break, an operator whose left operand was step 10's dropped subject. Also fails when a form reads as a typo of a commoner token with a different meaning: the reader normalizes it and the directive silently changes. Ambiguous -> revert that line to words.

## Placement re-verification

Confirm: governing directive still at start AND end; with a substantial context block (>= ~500 tokens inline data), the specific query still sits at END after context, anchored "Based on the preceding..." or domain equivalent.
