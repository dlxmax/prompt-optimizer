# Lesson and instructional-material authoring reference

<role>
Reference for prompt-optimizer. Load for RESCUE / AUDIT / AUTHOR whose domain
is LESSON: generating instructional material — lesson plans, worksheets,
handout sections, exam/quiz items, vocabulary or discussion content — as
opposed to grading (`GRADING_PIPELINE.md`) or feedback
(`FEEDBACK_GENERATION.md`). L-checklist = audit rubric for AUDIT, build spec
for RESCUE and AUTHOR. Apply every item; cite L1-L9.
</role>

## L-checklist

Score each `[x]` PASS / `[ ]` FAIL / `[N/A]`, one-line finding citing evidence.

L1. **Decomposition by section/phase.** Default architecture: one call per material section or item-type (vocabulary, warm-up questions, comprehension quiz, exam items, worksheet section), mirroring `GRADING_PIPELINE.md` G1. One call generating multiple distinct sections passes only when the caller states exactly one call per material, or names a call-budget ceiling forcing the bundle.

L2. **Validation is a separate pass.** Generation and validation of the same content are separate calls, not one combined self-check, whenever more than one independently-checkable property is verified (G1's reliability-per-category rationale: one pass judging several properties degrades reliability on each). One narrow self-check inside the generation call (one gate, one property) is acceptable; multiple unrelated gates in one combined validation pass is a defect.

L3. **Output contract with a literal parse anchor.** Machine-parsed output → state the exact literal token or line the response must begin with (after any stripped thinking/reasoning block), naming that anchor explicitly ("Begin your response with the literal token '1.'"). No stated anchor → downstream parsing is a deployer-verify item, never a silent assumption.

L4. **Gate-plus-example pairing.** Every constraint framed as a gate, rule, or check ships with >=1 PASS and >=1 FAIL worked example immediately adjacent. Constraint without a paired example = defect: name the missing example as the fix, not just the missing constraint.

L5. **Source-segment scoping.** Input source (transcript, document, subtitles) may span multiple unrelated topics or lessons → prompt explicitly scopes generation to the segment matching the caller's stated title/topic and instructs ignoring the rest. Source could plausibly contain multiple segments and no scope stated → defect.

L6. **Grounding to source, not invention.** Vocabulary, quotes, facts, examples in generated material come from the provided source (or an explicitly provided reference bank), never invented; the prompt states this the way `GRADING_PIPELINE.md` G2 requires grounding for grading comments. Applies with no student submission to quote — "source" here is the input material (transcript, prior lesson bank, learning objectives).

L7. **Structured-commitment ordering (when drift risk is real).** Generation tasks prone to topic drift or genericness (open-ended question generation, discussion-prompt authoring) → prompt requires committing to structured planning fields (topic choice, template ID, category) in a fixed order BEFORE drafting free text, rather than drafting first and justifying after. Recommend when a REVIEW or RESCUE reports generic, repetitive, or off-topic output as the failure mode; never add as default scaffolding absent that report.

L8. **Anti-recency-bias closing block.** Highest-priority constraints (output contract, grounding rule, scope rule) repeat at the very end, immediately before the output-format instruction, in addition to their first statement. Universal start-and-end rule, applied here because these prompts run long (source material plus multiple gates).

L9. **Injection defense for source material.** Source is external content the caller does not fully control (student-submitted topic choice, scraped text, uploaded material) → labeled delimiter block, data-only instruction stated outside the block, same convention as `GRADING_PIPELINE.md` G9. Does not apply to caller-authored curriculum content with no untrusted-content risk; state which case applies.

## Pipeline Spec (LESSON)

### Artifact 1: shared system_instruction / scaffold

Role framing, grounding-to-source rule (L6), output contract and parse anchor
(L3), injection defense where applicable (L9), closing anti-recency block (L8)
repeating the highest-priority constraints.

### Artifact 2: per-section/per-item generation template

Section-specific directive, source-segment scoping (L5) where relevant,
structured-commitment fields (L7) where drift is a reported problem,
gate-plus-example pairs (L4) for that section's constraints.

### Artifact 3: output structure

Either a response schema (`response_format`, preferred for anything
downstream-parsed as JSON) or a literal-anchor text contract (L3) where the
existing pipeline parses plain text. State which; never mix conventions within
one section's output.

### Artifact 4: code-side validator checklist

1. Verify the literal parse anchor is present where the contract requires one; absence = parse-breaking defect.
2. L6 grounding applies → spot-check generated vocabulary/facts/examples against the source; flag invented content.
3. Bounds-check counts (item counts, word counts) against the caller's requested quantities.

### Artifact 5: calibration checklist

1. Dry-run each section on a small set of real source material per material type. Compose from the failure surface (`GRADING_PIPELINE.md` artifact 5, item 2): source too short to fill the section, off-topic source, source missing an element the section requires.
2. Check genericness/drift (L7's failure mode) before assuming wording is the fix.
3. Re-run after any scaffold or per-section template change.

## Output skeletons

### RESCUE / AUTHOR (domain: LESSON)

```
## Task: RESCUE (or AUTHOR), domain: LESSON
[L-checklist findings, one line each; AUTHOR skips straight to the spec]
## Pipeline Spec
[artifacts 1-5, one Artifact 2 per section/item-type]
## Key Changes
- [what changed and why, citing L-items]
```

### AUDIT (domain: LESSON)

```
## Task: AUDIT, domain: LESSON
[L-checklist findings for failing items ONLY]
## Fixes
[targeted fix per failing item]
## Key Changes
- [...]
```

## Closing directive recap

Apply every L-item; cite item numbers in Key Changes. L6 grounding and L9
injection defense borrow framing from `GRADING_PIPELINE.md` G2/G9 but apply to
source material, not a student submission — never conflate the two when both
files load in one review.
