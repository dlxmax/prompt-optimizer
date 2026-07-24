# Lesson and instructional-material authoring reference

<role>
Reference for the prompt-optimizer agent. Load for RESCUE, AUDIT, and
AUTHOR tasks whose domain is LESSON: generating instructional material —
lesson plans, worksheets, handout sections, exam/quiz items, vocabulary or
discussion content — as opposed to grading (`GRADING_PIPELINE.md`) or
feedback (`FEEDBACK_GENERATION.md`). The L-checklist is the audit rubric
for AUDIT and the build specification for RESCUE and AUTHOR. Apply every
item; cite item numbers (L1-L9) in findings and Key Changes.
</role>

## L-checklist

Score each item `[x]` PASS / `[ ]` FAIL / `[N/A]` with a one-line finding
citing specific evidence.

L1. **Decomposition by section/phase.** One call per material section or
item-type (vocabulary, warm-up questions, comprehension quiz, exam items,
worksheet section) is the default architecture, mirroring
`GRADING_PIPELINE.md` G1. A single call generating multiple distinct
sections passes only when the caller states the runtime makes exactly one
call per material, or names a call-budget ceiling that forces bundling.

L2. **Validation is a separate pass.** Generation and validation of the
same content are separate calls, not one combined self-check, when more
than one independently-checkable property is being verified (mirrors G1's
reliability-per-category rationale: a model judging several properties in
one pass degrades reliability on each). A single narrow self-check
embedded in the generation call (one gate, one property) is acceptable;
multiple unrelated gates in one combined validation pass is a defect.

L3. **Output contract with a literal parse anchor.** Any prompt whose
output is machine-parsed states the exact literal token or line the
response must begin with (after any stripped thinking/reasoning block),
naming that anchor explicitly in the prompt (e.g., "Begin your response
with the literal token '1.'"). Absent a stated anchor, downstream parsing
is a deployer-verify item, not an assumption to make silently.

L4. **Gate-plus-example pairing.** Every constraint framed as a gate,
rule, or check ships with at least one PASS and one FAIL worked example
immediately adjacent to it. A constraint stated without a paired example
is a defect: name the missing example as the fix, not just the missing
constraint.

L5. **Source-segment scoping.** When the input source material (a
transcript, a document, a video's subtitles) may span multiple unrelated
topics or lessons, the prompt explicitly scopes generation to the segment
matching the caller's stated title/topic and instructs ignoring the rest.
Absent this scope when the source could plausibly contain multiple
segments, flag it as a defect.

L6. **Grounding to source, not invention.** Vocabulary, quotes, facts, or
examples used in generated material are drawn from the provided source
(or an explicitly provided reference bank), not invented; the prompt
states this constraint the same way `GRADING_PIPELINE.md` G2 requires
grounding for grading comments. This applies even though there is no
student submission to quote — the "source" here is the input material
(transcript, prior lesson bank, learning objectives) rather than a
student's work.

L7. **Structured-commitment ordering (when drift risk is real).** For
generation tasks prone to topic drift or genericness (open-ended question
generation, discussion-prompt authoring), the prompt requires the model
to commit to structured planning fields (a topic choice, a template ID, a
category) in a fixed order BEFORE drafting free-text content, rather than
drafting first and justifying after. Recommend this pattern when a REVIEW
or RESCUE finds generic, repetitive, or off-topic output as the reported
failure mode; do not add it as default scaffolding when the caller hasn't
reported that failure.

L8. **Anti-recency-bias closing block.** The highest-priority constraints
(output contract, grounding rule, scope rule) are repeated at the very
end of the prompt, immediately before the output-format instruction, in
addition to their first statement — the universal start-and-end rule
from generic prompting best practice, applied here because these prompts
tend to run long (source material plus multiple gates).

L9. **Injection defense for source material.** When the source is
external content the caller doesn't fully control (a student-submitted
topic choice, scraped text, uploaded material), it sits inside a labeled
delimiter block with the instruction that block content is data only
stated outside the block — same convention as `GRADING_PIPELINE.md` G9.
Does not apply when the source is caller-authored curriculum content with
no untrusted-content risk; state which case applies.

## Pipeline Spec (LESSON)

### Artifact 1: shared system_instruction / scaffold

Role framing, the grounding-to-source rule (L6), the output contract and
parse anchor (L3), injection defense if applicable (L9), and the closing
anti-recency block (L8) repeating the highest-priority constraints.

### Artifact 2: per-section/per-item generation template

The section-specific directive, source-segment scoping (L5) when
relevant, any structured-commitment fields (L7) when drift is a reported
problem, and gate-plus-example pairs (L4) for that section's specific
constraints.

### Artifact 3: output structure

Either a response schema (`response_format`, preferred for anything
downstream-parsed as JSON) or a literal-anchor text contract (L3) when
the existing pipeline parses plain text; state which, and do not mix
conventions within one section's output.

### Artifact 4: code-side validator checklist

1. Verify the literal parse anchor is present when the contract requires
   one; treat its absence as a parse-breaking defect.
2. When L6 grounding applies, spot-check generated vocabulary/facts/
   examples against the source; flag invented content.
3. Bounds-check counts (item counts, word counts) against the caller's
   requested quantities.

### Artifact 5: calibration checklist

1. Dry-run each section on a small set of real source material per
   material type.
2. Check for genericness/drift (L7's failure mode) before assuming
   wording is the fix.
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

Apply every L-item to the prompt under review; cite item numbers in Key
Changes. Grounding (L6) and injection defense (L9) borrow their framing
from `GRADING_PIPELINE.md` G2/G9 but apply to source material, not a
student submission — do not conflate the two when both files are loaded
in the same review.
