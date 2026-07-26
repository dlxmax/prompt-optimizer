# Compaction reference

<role>
Reference for prompt-optimizer. Load when a prompt must shrink: RESCUE
single-call fallback, a GRADING artifact over the G7 byte cap in any shape,
REVIEW finding length/duplication defects, or explicit caller request. Run pipeline in order, then gates, then re-verify placement.
</role>

## Compaction pipeline

Apply to draft revision, in order:

1. Cut opening sentences describing what the prompt does or acknowledging the model. Keep the opening sentence where it is itself a load-bearing directive, the role statement, or the grounding clause.
2. Verbose → imperative. "Please make sure to always..." → "Always...". "You should ensure that..." → "Ensure...". "When you encounter a case where..." → "If...".
3. Cut unintentional mid-prompt duplicates, each cleared first by the anchor test (preserve-list f). Keep intentional start-and-end repetition of governing directives. Governing directive = a JSON output schema: emit full spec once, close with a brief shape echo or "do not restart the object" guard, never a second field-by-field contract.
4. Cut background explaining motivation without changing behavior. Exception: feature-category lists in linguistic-analysis prompts are behavior-changing instruction — keep.
5. Examples over ceiling → trim to the ceiling the loaded domain file sets: grading 0 or 1 borderline per criterion (G6), FEEDBACK/LESSON one PASS+FAIL pair per gate (F4, L4), generic gate prompts 3 per criterion. No domain file loaded → 3 per criterion. Zero is legal under G6, and cutting the example is G7's named fix for an over-cap block. Gemma 4 forensic scans: PASS-example density is owned by `GEMMA4_FORENSIC_SCANS.md` 15.2, never cut below it.
6. Cut instructional comments inside output template blocks. Keep the literal-emission guard on any placeholder inside a worked example (invariant 3): a directive to the model, not a comment. Never rename canonical field tags (`<reasoning>`, `<verdict>`, `evidence`, `level`, `comment`) — parsers key on exact names.
7. Escape hatches out: scan every directive for "try to", "if possible", "when appropriate", "attempt to", "ideally", "generally", "as needed", "as much as possible" → direct imperative or genuine factual conditional. Exempt occurrences inside checklists and scan-target listings, where the word is named not used; defect = word in imperative position.
8. Cut courtesy markers ("kindly", "please", "feel free to", "as you see fit") and filler connectives ("Furthermore", "In addition", "Moreover", "It is important to note that"). Zero signal in directive blocks.
9. Threshold prose → numeric. "scores below three" → `<=2`. "more than five examples" → `>5`. "between 20 and 40 percent" → `20-40%`.

## Preserve-list

Never compaction targets. Step above would touch one → skip that step for that text:

a. Intentional start-and-end repetition of governing directives (role, output format, guardrails).
b. Rubric numeric scale, per-level anchor descriptions, AND-gated level clauses.
c. Canonical field tag and property names (`<reasoning>`, `<verdict>`, `<criterion>`, `<rubric>`, `evidence`, `level`, `comment`).
d. Verdict/reasoning consistency instruction ("mark must be consistent with cited evidence").
e. Example floor: the loaded domain file's floor, never a global one. One PASS+FAIL pair per gate for FEEDBACK (F4) and LESSON (L4); >=1 PASS+FAIL pair per criterion for generic gate prompts; no floor for grading, where G6 admits 0.
f. Anchor test: before dropping a line as "duplicate", confirm it is not the only EXPLICIT statement of its rule. Trigger conditions and list memberships elsewhere are not anchors.
g. Schema-versus-prose: a prose clause covering ground a schema field also covers (grounding, abstention, bounds) is additive, not a duplicate (`GRADING_PIPELINE.md` schema review essentials 2, 6). Cut only field-by-field restatement of the schema shape.

## Post-compaction gates

1. Token estimate `len(text)/4` against the cap the calling file sets, never a global one: GRADING per-criterion block ~900 tokens (G7), GRADING monolith ~3,000, generic REVIEW ~3,000 (`GENERIC_REVIEW.md` item 3). FEEDBACK and LESSON set no cap; use ~3,000 and say so. Still over after the full pipeline → decomposition required, not optional: write "split before deployment" in Key Changes and name the split boundary.
2. Re-run count-versus-universal check on the post-compaction draft: count constraint ("exactly N", "N to M", "at most K") + universal ("every", "all", "each") over the same population = contradiction; scope the universal, drop it, or name the complement.

## Placement re-verification

Confirm: governing directive still at start AND end; with a substantial context block (>= ~500 tokens inline data), the specific query still sits at END after context, anchored "Based on the preceding..." or domain equivalent.
