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
3. A fixed threshold copied from elsewhere. Calibrate on the course's own texts: measure the normal peer range first.

## Rules

1. Same task prefix (or `taskType`) on both sides of a comparison; the prefix shifts every score (classification prefix raised the peer median 0.73 to 0.80).
2. Gate inputs in code first: extraction junk, binary files, and oversized texts. `2` truncates silently past its limit; `001` refused them.
3. 768 dimensions rank the same as 3072; store 768 unless a test says otherwise.
4. Embed once and store; daily caps are small. One unchecked input can use up a key's minute of tokens: a 435k-word binary read as text did, and every later call got 429. Pacing numbers live in the grader, not in prompts.

## Measured (EFL speech scripts, BGO, n=33 drafts, 17 finals)

| Test | Result |
|---|---|
| Peer similarity, same assignment | 0.62-0.87 (`001`), 0.62-0.84 (`2`); highest pair shared a topic, not text. No copying found |
| Draft to final, same student | median 0.98-0.99; own final ranked first for 16/16 (`001`), 16/17 (`2`). Most students barely revised |
| Lowest draft-to-final (0.68) | the draft was an image file read as text; a junk gate, not a revision signal |
| Level from 3 nearest graded scripts | drafts 12-17/33 vs 20, finals 7-12/17 vs 14 for always guessing the most common level |
| `2` at 768 vs 3072 dims | same nearest pairs and ranks |

Lesson-material retrieval is untested here; test on the course's own files before relying on it.
