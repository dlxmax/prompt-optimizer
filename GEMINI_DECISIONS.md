# Gemini Decisions API: when to use it

<role>
Reference for prompt-optimizer. Decides whether a grading or classification step goes to `gemini-decision-1` (Decisions API) instead of a generating call. API facts come from the caller's call-site facts (the docs MCP does not cover this API); anything missing is a deployer-verify item.
</role>

## What it is

Returns calibrated probabilities over a yes/no question, a choice list, or an ordered score scale. No text output; billed on input only; same input gives the same probabilities, but a caller that caches replies by input and questions serves the cache: bypass it to measure rerun stability. No reasoning, quotes, abstain, or comment. Unknown keys in a question get HTTP 400: strip comment or `_` keys before sending.

## Use it when

1. The level is a holistic quality judgment between adjacent descriptors (structure, clarity, voice). Not a drop-in for a lite level call: bench at least one top-level and one bottom-level anchor first, and report branch-flag changes between the two routes (a route that skips items the other flags changes every downstream branch).
2. The same answer on every run matters (regrades, appeals, reviewer trust).
3. Code, not the model, applies the tie-break or the review threshold: it reads `probabilities`, never the `score` average alone.

## Do not use it when

1. A level is defined by countable or missing parts (sections present, word count, number of points). Use yes/no checks plus code.
2. A level depends on originality or AI authorship. It cannot judge either; use detectors or the teacher.
3. The step must produce feedback text or evidence quotes. Keep a generating call; pass it the chosen level as a fixed input.
4. The check must tell "the source says X" from "the source leads up to X" (facts said only after a stop point). Facts said just after the stop scored P(supported) 0.46-0.81; adding the later lines as a separate block, a second "first said later?" question, or a watched/later/neither choice caught at most 1 of 5 for 3 new false flags. Forbid causes and later events beyond the stop in the generation prompt, or have a person check them.
5. A check that failed its bench here (evidence of support, vouching, "new idea better" were three) stays on lite behind a confirm step (Shape of a Decisions step 12).

## Shape of a Decisions step

1. Gates first, in code: missing sections, length, detector flags.
2. Decisions picks the quality level: one score question per criterion, rubric descriptors verbatim, lowest level at index 0.
3. A generating call writes the comment from the fixed level.
4. Send the whole source the item is checked against for claim-support checks (transcript, assignment, who speaks, earlier setup). A part defined by position (opening, ending) is the exception: code slices it by the part, and each slice is benched on the cases it must answer; a whole-transcript ending question failed, and slices cut too short flipped correct answers. Cutting the source to the judged span (±2 lines) wrongly flagged 13 of 20 true claims; the whole transcript flagged 2 of 20. Also when a choice step first picks the supporting line: right picks for 16 of 20 still scored as low as P=0.05 once cut to the pick ±2.
5. Send only the item under judgment from the work being judged, never its other items (the draft's other points, other claims). Copy spans with lite and verify them in code; Decisions judges, code sets levels, positions and counts.
6. One question per item, its criteria naming each failure kind. Splitting it into narrow sub-questions per failure kind wrongly flagged 7 of 20 true claims against 2 of 20, to miss 2 of 15 false ones instead of 4.
7. Ask a choice among contrasting failure kinds, not a bare yes/no. "Is this clue unclear" scored 0.31-0.52 on every point; a 4-option contrasting choice separated them. Options are mutually exclusive contrasts, each with a test case that lands in it; an overlapping set, or a "none" option with no branch, lets the wrong option win.
8. Exempt items that assert nothing (opinion questions) in code before asking. A "facts it takes for granted" clause scores them low: exempting "?" sentences cut wrongly flagged true sentences 20 of 123 to 7, missing 1 more false one (8 of 30).
9. A choice question with a "none" option: read P(none) as its own signal. It caught 4 unsupported claims. Test "none" on the best cases too: an over-strict one emptied praise on excellent work.
10. Set every threshold from the teacher's own graded set, never a default: one checker's best cutoff was 0.4, while a 3-level rubric's confidence ran 0.45-0.7, and true repeat-question pairs often scored 0.3-0.5 (against the revised gold: cutoff 0.3 caught 22/22 with 2/40 false flags; 0.4 20/22, 2/40; 0.5 18/22, 1/40; the first gold gave 19/24 and 14/24, so record the gold-file version beside every cutoff). A cutoff is provisional until it has two positives from two different inputs; a check tested only on its yes branch says so. The default 0.5 is an uncalibrated placeholder. Keep the cutoff in the sidecar or an env-overridable constant and log the probabilities.
11. Relative scoring: score each point in its own question, then in code compare each score to the same draft's other points plus an absolute floor. A floor alone did not separate points across drafts.
12. Confirm step after a generating call that over-flags: keep a flag only when its probability passes the threshold. Reverse case: when lite's false negatives cost more (Decisions alone missed explicit lines), lite "yes" stands and lite "no" is overturned only when Decisions reaches a stated cutoff.
13. Bench end to end: the decision is stable, the generating calls upstream are not. Keep bench data in a persistent folder (e.g. ~/.tabot/benches), never /tmp or a session scratchpad.
14. Keep "not a match" exclusions in the criteria narrow. A broad no-rule ("own habits vs rules/society") pulled true repeats that cross it to No (statement vs question on the same central claim: 0.07-0.48).
15. Adapter: convert probabilities in code to the fields the existing level code reads, so that code does not change. The caller passes the decide function; None keeps the lite answers. The request carries model, input and questions only: no thinking or temperature.

## Measured (EFL speech scripts, posted teacher levels as truth)

| Test | Decisions | Current generating grader |
|---|---|---|
| Outline/Script quality, 3 levels, n=17 | 16/17; identical on rerun | 15/17 majority of 3; 85% per call; changed level between runs on 3 scripts |
| Draft completeness + originality, 3 levels, n=33 | 23/31 scored; caught 1/7 low drafts; 4/6 middle | 23/33; caught 4/7 low drafts (code gates); 1/6 middle |

Both missed full-length drafts the teacher marked low: originality, not completeness. Re-test on a new rubric before switching it.
