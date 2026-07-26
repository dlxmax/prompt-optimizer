# Compaction reference

<role>
Reference for prompt-optimizer. Load when a prompt must shrink: RESCUE
single-call fallback, REVIEW finding length/duplication defects, or explicit
caller request. Run pipeline in order, then gates, then re-verify placement.
</role>

## Compaction pipeline

Apply to draft revision, in order:

1. Cut opening sentences describing what the prompt does or acknowledging the model. Opening sentence = a directive. Never cut the first load-bearing directive.
2. Verbose → imperative. "Please make sure to always..." → "Always...". "You should ensure that..." → "Ensure...". "When you encounter a case where..." → "If...".
3. Cut unintentional mid-prompt duplicates. Keep intentional start-and-end repetition of governing directives. Governing directive = a JSON output schema: emit full spec once, close with a brief shape echo or "do not restart the object" guard, never a second field-by-field contract.
4. Cut background explaining motivation without changing behavior. Exception: feature-category lists in linguistic-analysis prompts are behavior-changing instruction — keep.
5. Examples over ceiling (judge: 1 borderline per criterion; else 3 per criterion) → trim to ceiling. Never to zero: rubric and examples are complementary. Gemma 4 targets keep >=1; open-weight models are more example-sensitive than closed frontier models.
6. Cut instructional comments inside output template blocks. Never rename canonical field tags (`<reasoning>`, `<verdict>`, `evidence`, `level`, `comment`) — parsers key on exact names.
7. Escape hatches out: scan every directive for "try to", "if possible", "when appropriate", "attempt to", "ideally", "generally", "as needed", "as much as possible" → direct imperative or genuine factual conditional. Exempt occurrences inside checklists and scan-target listings, where the word is named not used; defect = word in imperative position.
8. Cut courtesy markers ("kindly", "please", "feel free to", "as you see fit") and filler connectives ("Furthermore", "In addition", "Moreover", "It is important to note that"). Zero signal in directive blocks.
9. Threshold prose → numeric. "scores below three" → `<=2`. "more than five examples" → `>5`. "between 20 and 40 percent" → `20-40%`.

## Preserve-list

Never compaction targets. Step above would touch one → skip that step for that text:

a. Intentional start-and-end repetition of governing directives (role, output format, guardrails).
b. Rubric numeric scale, per-level anchor descriptions, AND-gated level clauses.
c. Canonical field tag and property names (`<reasoning>`, `<verdict>`, `<criterion>`, `<rubric>`, `evidence`, `level`, `comment`).
d. Verdict/reasoning consistency instruction ("mark must be consistent with cited evidence").
e. Example floor: >=1 PASS+FAIL pair per criterion for generic gate prompts; the single borderline example for grading prompts where present.
f. Anchor test: before dropping a line as "duplicate", confirm it is not the only EXPLICIT statement of its rule. Trigger conditions and list memberships elsewhere are not anchors.

## Post-compaction gates

1. Token estimate `len(text)/4`. Over ~3,000 after full pipeline → decomposition required, not optional: promote the Key Changes note from "consider" to "split before deployment".
2. Re-run count-versus-universal check on the post-compaction draft: count constraint ("exactly N", "N to M", "at most K") + universal ("every", "all", "each") over the same population = contradiction; scope the universal, drop it, or name the complement. Stripping qualifiers surfaces these.

## Placement re-verification

Confirm: governing directive still at start AND end; with a substantial context block (>= ~500 tokens inline data), the specific query still sits at END after context, anchored "Based on the preceding..." or domain equivalent.
