# Feedback-comment generation reference

<role>
Reference for the prompt-optimizer agent. Load for RESCUE, AUDIT, and AUTHOR
tasks whose domain is FEEDBACK: prose feedback/comments on a student's
work, distinct from a numeric grade. Loads standalone (a prompt whose sole
output is feedback text) or additively alongside `GRADING_PIPELINE.md` when
a grading response embeds structured feedback per criterion. The
F-checklist is the audit rubric for AUDIT and the build specification for
RESCUE and AUTHOR. Apply every item; cite item numbers (F1-F10) in
findings and Key Changes.
</role>

## F-checklist

Score each item `[x]` PASS / `[ ]` FAIL / `[N/A]` with a one-line finding
citing specific evidence (quoted phrase, or the absence). The mark must be
consistent with the cited evidence.

F1. **PQS structure.** Feedback follows Praise -> Question -> Suggest, in
that order. Praise names one concrete element and anchors it to a quote
or specific move from the submission, then states its effect ("said what
it did," not "was good"). Question names the single biggest gap, not a
list of gaps. Suggest gives one concrete next step, phrased as a soft
imperative ("Try..."). A full-marks result drops Suggest (Praise only, no
gap to name); a no-submission or zero-score result is a single stock
line, not an attempted PQS.

F2. **Ghost-guard grounding.** Before naming a strength (Praise) or a gap
(Suggest), the prompt requires verifying it is actually present in the
submission (Praise) or actually absent (Suggest) — never invented. This
is presence-AND-absence grounding, broader than a plain quote
requirement: absence claims need their own verification step, not just
presence claims.

F3. **Scan-then-judge for claim-bearing feedback.** When feedback asserts
a specific structural or content claim ("no citation was used," "the
required element is missing," "this pattern recurs"), the prompt
requires an enumerated scan block — naming every instance found, or
explicitly stating none were found — BEFORE the claim is permitted. The
scan happens before the claim, not after; skipping it is a defect, not a
style choice.

F4. **No content-free praise.** Bans superlative-only praise ("great
job," "nice effort," "well done") that doesn't name an element and its
effect. Pair the rule with one PASS and one FAIL worked example.

F5. **Register and voice named explicitly.** Voice/register rules (a
plain-language word-swap list, a sentence-length cap, a proficiency-level
ceiling, or an equivalent concrete constraint) are stated, not left to
model default. Voice is owned by the caller's directive/spec, not
hardcoded into a shared scaffold meant to serve multiple assignment
genres.

F6. **Mode awareness, only if the caller declares modes.** When feedback
timing varies (draft-stage, final, course-end/terminal), the prompt names
the mode and adjusts tense/forward-framing per mode (e.g., a terminal
mode bans forward-looking language and uses past-conditional phrasing:
"citing sources would have strengthened this"). Absent an explicit mode
requirement from the caller, default to one framing; do not invent mode
variants nobody asked for.

F7. **Scope declared: standalone or per-criterion.** State whether
feedback is a standalone comment on a whole submission, or one PQS block
per rubric criterion embedded in a scoring response. Per-criterion
feedback additionally inherits `GRADING_PIPELINE.md` G2 (grounding), G3
(schema), and G9 (injection defense) for the surrounding scoring
machinery; F1-F6 govern the feedback text itself either way.

F8. **Injection defense.** The submission or source-of-feedback text sits
inside a labeled delimiter block; the instruction that block content is
data only (not instructions) appears OUTSIDE the block, matching
`GRADING_PIPELINE.md` G9.

F9. **Length discipline.** A stated sentence or length cap (a concrete
range, e.g. 3-7 sentences) is a hard bound in the prompt, not a
suggestion; padding past it is a defect the cap should prevent
structurally, not just discourage.

F10. **Parseable when embedded.** When feedback is a field inside
structured output (alongside a score or reasoning), it is emitted as one
schema-validated string field; the response schema does not require
separate downstream parsing to extract it.

## Pipeline Spec (FEEDBACK)

### Artifact 1: feedback system_instruction / scaffold

The PQS role framing (F1), ghost-guard clause (F2), scan-then-judge
requirement for any claim-bearing item (F3), register rules (F5), and
injection defense (F8). Written as a stable, genre-agnostic scaffold;
voice/mode specifics are injected as caller-supplied parameters (a
directive block), not hardcoded, so the same scaffold serves multiple
assignment types.

### Artifact 2: per-item or per-criterion feedback template

The scan block (if F3 applies), the PQS directive itself, the length cap
(F9), and — when scope is per-criterion (F7) — the anchor to that
criterion's already-decided level (full marks drops Suggest; zero score
short-circuits to the stock line).

### Artifact 3: response schema

When standalone: one string field, schema-validated. When per-criterion:
a `feedback` string field alongside the criterion's existing
`score`/`reasoning` fields in `GRADING_PIPELINE.md` Artifact 3 — do not
introduce a second, competing schema for the same call.

### Artifact 4: code-side validator checklist

1. Fuzzy-match Praise's quoted/named element against the submission (same
   technique as grading's quote-verification, `GRADING_PIPELINE.md`
   Artifact 4 item 2); on failure, discard and re-call once.
2. Bounds-check length against the stated cap.
3. When F3 applies, verify the scan block is present and non-empty before
   the claim it gates; treat a missing scan as a schema-shape defect, not
   just a quality note.

### Artifact 5: calibration checklist

1. Dry-run on a small human-reviewed set; check Praise/Suggest actually
   reference real submission content, not just plausible-sounding text.
2. Flag repeated Suggest phrasing across submissions (a sign the model is
   templating rather than grounding).
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
[F-checklist findings for failing items ONLY]
## Fixes
[targeted fix per failing item]
## Key Changes
- [...]
```

## Recipe notes

- When domain is GRADING and the caller also wants PQS-style structured
  feedback (not a bare comment string), load this file ADDITIVELY:
  `GRADING_PIPELINE.md` still owns the scoring artifacts (G-checklist,
  schema, calibration for the score), this file owns the feedback text
  inside Artifact 3's `feedback` field (F-checklist). Cite both G-items
  and F-items in Key Changes for such a call.
- A standalone FEEDBACK task (no rubric, no score) never loads
  `GRADING_PIPELINE.md`.

## Closing directive recap

Apply every F-item to the prompt under review; cite item numbers in Key
Changes. Per-criterion feedback additionally inherits the surrounding
grading machinery's G2/G3/G9 from `GRADING_PIPELINE.md`; standalone
feedback stands on F1-F10 alone.
