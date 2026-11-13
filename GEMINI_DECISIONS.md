# Gemini Decisions API: when to use it

<role>
Reference for prompt-optimizer. Decides whether a grading or classification step goes to `gemini-decision-1` (Decisions API) instead of a generating call. API shape and limits: the docs MCP, never this file.
</role>

## What it is

Returns calibrated probabilities over a yes/no question, a choice list, or an ordered score scale. No text output; billed on input only; same input gives the same probabilities. No reasoning, quotes, abstain, or comment.

## Use it when

1. The level is a holistic quality judgment between adjacent descriptors (structure, clarity, voice).
2. The same answer on every run matters (regrades, appeals, reviewer trust).
3. Code, not the model, applies the tie-break or the review threshold: it reads `probabilities`, never the `score` average alone.

## Do not use it when

1. A level is defined by countable or missing parts (sections present, word count, number of points). Use yes/no checks plus code.
2. A level depends on originality or AI authorship. It cannot judge either; use detectors or the teacher.
3. The step must produce feedback text or evidence quotes. Keep a generating call; pass it the chosen level as a fixed input.

## Shape in a grading pipeline

1. Gates first, in code: missing sections, length, detector flags.
2. Decisions picks the quality level, one score question per criterion, rubric descriptors verbatim, lowest level at index 0.
3. A generating call writes the comment from the fixed level.
4. Expect low confidence (0.45-0.7 on a 3-level rubric). Set any review threshold from the teacher's own graded set, never a default.

## Measured (EFL speech scripts, posted teacher levels as truth)

| Test | Decisions | Current generating grader |
|---|---|---|
| Outline/Script quality, 3 levels, n=17 | 16/17; identical on rerun | 15/17 majority of 3; 85% per call; changed level between runs on 3 scripts |
| Draft completeness + originality, 3 levels, n=33 | 23/31 scored; caught 1/7 low drafts; 4/6 middle | 23/33; caught 4/7 low drafts (code gates); 1/6 middle |

Both missed the full-length drafts the teacher marked low, which points to originality, not completeness. Re-test on a new rubric before switching it.
