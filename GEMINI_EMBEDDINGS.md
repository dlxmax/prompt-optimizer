# Gemini embeddings: when to use them

<role>
Reference for prompt-optimizer. Decides whether a step in a grading or lesson pipeline is a similarity job for `gemini-embedding-001` or `gemini-embedding-2` instead of an LLM call. API shape, limits, prefixes: the docs MCP, never this file.
</role>

## What they are

A vector per input; cosine similarity says how alike two inputs are in topic and wording. No level, no text, no reasons. Cheap, same output every run. `001`: text only, 2,048 tokens, `taskType` parameter. `2`: text, image, audio, video, PDF in one space, 8,192 tokens, task written as a text prefix. The two spaces are incompatible; never compare across models.

## Use them for

1. Copying between students, or reuse from past terms: pairwise similarity within and across sections.
2. Draft-to-final revision: same-student similarity says how much changed.
3. Retrieval: the nearest graded examples or past comments to give a grader as anchors; the nearest slide, clip, or question for a lesson.
4. Duplicate and coverage checks on generated questions or lesson items.
5. Grouping answers or feedback by theme.

## Do not use them for

1. Picking a quality level. Neighbours share a topic, not a grade. Use a judging call or the Decisions API.
2. AI-authorship detection. Similarity measures closeness to other texts, not who wrote it.
3. Grounding or entailment checks ("does the transcript state this?", "does it come later?"). Similarity can't tell "states the fact" from "same topic"; keep that judgment in an LLM or Decisions call.
4. Pruning a judge's evidence to the top-k nearest lines when claims summarize scattered material; the judge loses support and flags true claims. Give it the full context.
5. A fixed threshold copied from elsewhere. Calibrate on the course's own texts: measure the normal peer range first.

## Rules

1. Same task prefix (or `taskType`) on both sides of a comparison; the prefix shifts every score (classification prefix raised the peer median 0.73 to 0.80).
2. Gate junk, binary, and oversized inputs in code first; `2` truncates silently, and one huge input spends the key's minute of tokens.
3. 768 dimensions rank the same as 3072; store 768 unless a test says otherwise.
4. Embed once and store.

## Measured (EFL speech scripts, BGO, n=33 drafts, 17 finals)

| Test | Result |
|---|---|
| Peer similarity, same assignment | 0.62-0.87 (`001`), 0.62-0.84 (`2`); highest pair shared a topic, not text. No copying found |
| Draft to final, same student | median 0.98-0.99; own final ranked first for 16/16 (`001`), 16/17 (`2`). Most students barely revised |
| Lowest draft-to-final (0.68) | the draft was an image file read as text; a junk gate, not a revision signal |
| Level from 3 nearest graded scripts | drafts 12-17/33 vs 20, finals 7-12/17 vs 14 for always guessing the most common level |
| `2` at 768 vs 3072 dims | same nearest pairs and ranks |

## Measured (slide grounding vs video transcript, ISE, 153 sentences, 54 slides)

| Variant (`gemini-decision-1` judge, `2` at 768) | Clean slides flagged / bad caught |
|---|---|
| Baseline: judge over all watched lines + code number gate | 6/34, 17/20 |
| Judge over top-6 similar lines only | 24/34, 18/20 |
| Plus flag "best match is after stop point" | 9-13/34, no new catches |

Code gates (every number appears in a watched line) beat both for numeric claims.

Lesson-material retrieval beyond this is untested; test on the course's own files before relying on it.
