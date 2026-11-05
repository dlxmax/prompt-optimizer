# Gemini 3.x model choice by task

<role>
Reference for prompt-optimizer, loaded by `GEMINI_3X_API_BEST_PRACTICES.md` when a model choice is asked about or recommended. Rule numbers refer to that file, which also holds the durable patterns.
</role>

## Empirical model choice by task type (probe-verified, not vendor guidance)


Deployer production A/B testing, not Google documentation; the docs cannot
state task-specific results, so this stays hand-maintained regardless of rule 1.
No row in the table below was probed on a model newer than `gemini-3.5-flash`; every Gemini
release after it is untested here (current list: rule 1). The string tested is
named in each row, never generalized to a generation. Each
mapping is a hypothesis to re-verify on
the current generation, not a standing fact. The patterns in rule 9 are
the durable part.

A row records which tier won a task on the generation tested, never which
string to call today. Liveness and the current successor for any string below
= the docs MCP's job (rule 1); this file asserts neither. Never name a table model
as the recommendation for new work. Read a row as "this task type suited that
tier", map to the current successor, put the re-test in Key Changes.

**The newest Flash is not automatically the successor.** `gemini-3.8-flash` is
a behavior break, not an increment (`GEMINI_MIGRATION.md` 5). A Flash row on a
bounded task (grading, extraction, classification) → re-test on both
`gemini-3.6-flash` and `gemini-3.8-flash`, never assume 3.8 wins.

| Task type | Model that won, as tested | Why | Currency |
|---|---|---|---|
| Open-ended multimodal extraction (transcription, speaker labeling, phase detection) | `gemini-3.5-flash` (free tier) | Matched paid `gemini-2.5-pro` exactly on a multi-speaker code-switched video; free-tier `gemini-3.1-flash-lite`/`gemini-2.5-flash` under-counted speakers or mislabeled phases | Re-verify on the current successor (rule 1); `gemini-2.5-pro` since lost production access |
| Constrained rubric-tier grading needing internally consistent verdicts | `gemini-3-flash-preview` over `gemini-3.5-flash` | `gemini-3.5-flash` produced internally inconsistent grades (all-praise justification paired with a sub-Excellent tier) in one production chain; `gemini-3-flash-preview` held consistent | Re-verify: same model won the extraction row and lost here, so task-specific, not a ranking |
| TERMINAL-mode feedback register discipline | `gemini-3-flash-preview` over `gemini-3.1-flash-lite` | Flash-Lite lapsed to draft-register phrasing, used banned forward-framing language, doubled point values, intermittent JSON truncation on first pass | Re-verify on `gemini-3.5-flash-lite` |
| Discrimination/distractor-construction (odd-one-out items) | `gemini-3.5-flash` over `gemini-3.1-flash-lite` | Flash-Lite built distractors around surface word-form patterns (the one gerund among plain nouns) rather than semantic outliers; a stricter surface-uniformity gate made this worse on Flash-Lite specifically, neutral-to-helpful on 3.5-flash | Re-verify on `gemini-3.5-flash-lite`, documented as stronger on reasoning/multimodal than 3.1 Flash-Lite |
| Narrow perceptual tasks (handwriting OCR) | `gemini-3.1-flash-lite` over heavier models | Beat a reasoning-tier model despite being cheaper and lighter | Directionally durable: never assume a "smarter" model wins a narrow perceptual task |
| Semantic claim-vs-finding verification (does a citation's claim match what it found) | Gemini-class over Gemma-class | Independent prompt-wording iterations failed to close a Gemma 4 ceiling; a Gemini reasoning model got it right on the same prompt | `GEMMA4_API_BEST_PRACTICES.md` for the Gemma-side ceiling; route this sub-step to Gemini even inside an otherwise-Gemma pipeline |
| Coarse binary classification (screening only, not graded tiers) | `gemini-3-flash-preview` | Best binary agreement among tested models, despite being weak on fine-grained tier classification on the same data (row 2) | Illustrates task-specificity more than a standing recommendation |
