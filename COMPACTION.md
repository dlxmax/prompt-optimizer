# Compaction reference

<role>
Reference for the prompt-optimizer agent. Load when a prompt must shrink: the RESCUE single-call fallback, a REVIEW pass that finds length or duplication defects, or an explicit caller request to compact. Run the pipeline in order, then the gates, then re-verify placement.
</role>

## Compaction pipeline

Apply to the draft revision, in order:

1. Remove opening sentences that describe what the prompt does or acknowledge the model. The opening sentence must be a directive. Do not remove the first load-bearing directive.
2. Replace verbose phrasing with direct imperatives: "Please make sure to always..." becomes "Always..."; "You should ensure that..." becomes "Ensure..."; "When you encounter a case where..." becomes "If...".
3. Remove unintentional mid-prompt duplicates. Preserve intentional start-and-end repetition of governing directives. When the governing directive is a JSON output schema itself, emit the full spec once and close with a brief shape echo or "do not restart the object" guard instead of duplicating the field-by-field contract.
4. Remove background that explains motivation but does not change model behavior. Feature-category lists in linguistic-analysis prompts are behavior-changing instruction; do not strip them.
5. If examples exceed the applicable ceiling (1 borderline example per criterion for judge prompts; 3 per criterion otherwise), trim to the ceiling. Do not remove all examples: rubric and examples are complementary. For Gemma 4 targets, keep at least one example; open-weight models are more sensitive to example removal than closed frontier models.
6. Remove instructional comments inside output template blocks. Do not rename canonical field tags (`<reasoning>`, `<verdict>`, `evidence`, `level`, `comment`); downstream parsers depend on exact names.
7. Eliminate escape hatches: scan every directive for "try to," "if possible," "when appropriate," "attempt to," "ideally," "generally," "as needed," "as much as possible" and replace with a direct imperative or a genuine factual conditional. Exempt occurrences inside checklists and scan-target listings, where the word is named rather than used; the defect is the word in imperative position.
8. Remove courtesy markers ("kindly," "please," "feel free to," "as you see fit") and filler connectives ("Furthermore," "In addition," "Moreover," "It is important to note that"). Zero signal in directive blocks.
9. Replace threshold prose with numeric notation: "scores below three" becomes "<=2"; "more than five examples" becomes ">5"; "between 20 and 40 percent" becomes "20-40%".

## Preserve-list

Never compaction targets. If a step above would touch one, skip that step for that text:

a. Intentional start-and-end repetition of governing directives (role, output format, guardrails).
b. Rubric numeric scale and per-level anchor descriptions; AND-gated level clauses.
c. Canonical field tag and property names (`<reasoning>`, `<verdict>`, `<criterion>`, `<rubric>`, `evidence`, `level`, `comment`).
d. The verdict/reasoning consistency instruction ("the mark must be consistent with the cited evidence").
e. The example floor: >=1 PASS+FAIL pair per criterion for generic gate prompts; the single borderline example for grading prompts when present.
f. Anchor test: before dropping a line as a "duplicate," confirm it is not the only EXPLICIT statement of its rule. Trigger conditions and list memberships elsewhere do not count as an explicit anchor.

## Post-compaction gates

1. Estimate token count as `len(text)/4`. If the result exceeds ~3,000 tokens after the full pipeline, decomposition is required, not optional: promote the decomposition note in Key Changes from "consider" to "split before deployment."
2. Re-run the count-versus-universal consistency check against the post-compaction draft: a count constraint ("exactly N", "N to M", "at most K") and a universal quantifier ("every", "all", "each") targeting the same population contradict; scope the universal, drop it, or name the complement. Compaction frequently surfaces these when qualifiers are stripped.

## Placement re-verification

Confirm after compaction: the governing directive still appears at both start and end; for prompts with a substantial context block (>= ~500 tokens of inline data), the specific query still sits at the END after the context, anchored with "Based on the preceding..." or a domain equivalent.
