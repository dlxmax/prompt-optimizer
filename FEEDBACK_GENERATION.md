# Feedback-comment generation reference

<role>
Reference for prompt-optimizer. Load for RESCUE / AUDIT / AUTHOR whose domain
is FEEDBACK: prose feedback/comments on student work, distinct from a numeric
grade. Loads standalone (prompt whose sole output is feedback text) or
additively alongside `GRADING_PIPELINE.md` when a grading response embeds
structured feedback per criterion. F-checklist = audit rubric for AUDIT, build
spec for RESCUE and AUTHOR. Apply every item; cite F1-F10.
</role>

## F-checklist

Score each `[x]` PASS / `[ ]` FAIL / `[N/A]`, one-line finding citing evidence
(quoted phrase, or the absence). Mark must match the cited evidence.

F1. **PQS structure.** Praise → Question → Suggest, that order. Praise names one concrete element anchored to a quote or specific move from the submission, then states its effect ("said what it did", not "was good"). Question names the single biggest gap, not a list. Suggest gives one concrete next step as a soft imperative ("Try..."). Full marks → drop Suggest (Praise only, no gap to name). No submission or zero score → single stock line, not an attempted PQS.

F2. **Ghost-guard grounding.** Before naming a strength (Praise) or a gap (Suggest), the prompt requires verifying it is actually present (Praise) or actually absent (Suggest) — never invented. Presence-AND-absence grounding, broader than a plain quote requirement: absence claims need their own verification step. Prose alone does not hold when the scaffold dwarfs the submission: route thin or empty submissions to F1's stock line through a sufficiency pre-gate (`GRADING_PIPELINE.md` artifact 4, step 0), rather than getting praise assembled from the prompt's own vocabulary.

F3. **Scan-then-judge for claim-bearing feedback.** Feedback asserting a specific structural or content claim ("no citation was used", "the required element is missing", "this pattern recurs") requires an enumerated scan block — naming every instance found, or explicitly stating none — BEFORE the claim. Scan precedes claim, never follows. Skipping it is a defect, not a style choice.

F4. **No content-free praise.** Ban superlative-only praise ("great job", "nice effort", "well done") that names no element and no effect. Pair the rule with one PASS and one FAIL worked example.

F5. **Register and voice named explicitly.** Voice/register rules stated, not left to model default: a plain-language word-swap list, a sentence-length cap, a proficiency-level ceiling, or an equivalent concrete constraint. Voice is owned by the caller's directive/spec, never hardcoded into a shared scaffold serving multiple assignment genres.

F6. **Mode awareness, only if the caller declares modes.** Feedback timing varies (draft-stage, final, course-end/terminal) → prompt names the mode and adjusts tense/forward-framing per mode (terminal mode bans forward-looking language, uses past-conditional: "citing sources would have strengthened this"). No explicit mode requirement from the caller → default to one framing; never invent mode variants nobody asked for.

F7. **Scope declared: standalone or per-criterion.** State whether feedback is a standalone comment on a whole submission, or one PQS block per rubric criterion embedded in a scoring response. Per-criterion additionally inherits `GRADING_PIPELINE.md` G2 (grounding), G3 (schema), G9 (injection defense) for the surrounding scoring machinery; F1-F6 govern the feedback text either way.

F8. **Injection defense.** Submission or source-of-feedback text sits inside a labeled delimiter block; the instruction that block content is data only (not instructions) sits OUTSIDE the block, matching `GRADING_PIPELINE.md` G9.

F9. **Length discipline.** A stated sentence or length cap (concrete range, e.g. 3-7 sentences) is a hard bound in the prompt, not a suggestion. Padding past it is a defect the cap should prevent structurally, not merely discourage.

F10. **Parseable when embedded.** Feedback as a field inside structured output (alongside score or reasoning) is emitted as one schema-validated string field; the response schema requires no separate downstream parsing to extract it.

## Pipeline Spec (FEEDBACK)

### Artifact 1: feedback system_instruction / scaffold

PQS role framing (F1), ghost-guard clause (F2), scan-then-judge requirement for
any claim-bearing item (F3), register rules (F5), injection defense (F8).
Stable, genre-agnostic scaffold; voice/mode specifics injected as
caller-supplied parameters (a directive block), never hardcoded, so one
scaffold serves multiple assignment types.

### Artifact 2: per-item or per-criterion feedback template

Scan block (where F3 applies), the PQS directive, the length cap (F9), and —
scope per-criterion (F7) — the anchor to that criterion's already-decided level
(full marks drops Suggest; zero score short-circuits to the stock line).

### Artifact 3: response schema

Standalone: one string field, schema-validated. Per-criterion: a `feedback`
string field alongside the criterion's existing `score`/`reasoning` fields in
`GRADING_PIPELINE.md` artifact 3. Never a second, competing schema for the
same call.

### Artifact 4: code-side validator checklist

1. Fuzzy-match Praise's quoted/named element against the submission (same technique as grading's quote-verification, `GRADING_PIPELINE.md` artifact 4 item 2); failure → discard, re-call once.
2. Bounds-check length against the stated cap.
3. F3 applies → verify the scan block is present and non-empty before the claim it gates. Missing scan = schema-shape defect, not a quality note.

### Artifact 5: calibration checklist

1. Dry-run on a small human-reviewed set; check Praise/Suggest actually reference real submission content, not plausible-sounding text. Compose the set from the failure surface (`GRADING_PIPELINE.md` artifact 5, item 2): empty, thin, and off-task submissions plus full-marks work, which takes the Praise-only path.
2. Flag repeated Suggest phrasing across submissions — the model is templating, not grounding.
3. Re-run after any scaffold wording change.

## Output skeletons

### RESCUE / AUTHOR (domain: FEEDBACK)

```
## Task: RESCUE (or AUTHOR), domain: FEEDBACK
[F-checklist findings, one line each; AUTHOR skips straight to the spec]
## Pipeline Spec
[artifacts 1-5]
## Key Changes
- [what changed and why, citing F-items]
```

### AUDIT (domain: FEEDBACK)

```
## Task: AUDIT, domain: FEEDBACK
[F-checklist findings, one line each]
## Fixes
[targeted corrections for failing items ONLY; do not re-emit a passing prompt]
## Key Changes
- [what changed and why, citing F-items]
```

## Recipe notes

Loaded alongside `GRADING_PIPELINE.md` (grading response embedding
per-criterion feedback): this file governs the feedback field only. Scoring
artifacts stay grading's. Emit one merged Pipeline Spec, not two — the feedback
field joins grading's artifact 3 schema, and grading's artifact 4 gains the
F-side validators above.
