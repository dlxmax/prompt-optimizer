---
name: gemini-call-design
description: Use when adding a Gemini API call (google-genai, generateContent, Interactions, gemini-* ids, gemini-decision-1, gemini-embedding-*) or changing a call's job, prompt, model, thinking level, schema or fallback chain, including grading, feedback, lesson generation and checks. Decides code vs Decisions vs embeddings vs a generating call, tier, thinking, splitting, schema and bench before code. Not for edits that leave every call's job and settings unchanged.
---

# Gemini call design

Decide the architecture before writing the prompt. Cited guides sit in the plugin root, two levels above this file (`../../`). Read a cited guide when you set the parameter or route that line names.

## 1. Route each job, first match wins

1. Countable, arithmetic, substring, date, set, regex, dedup, empty or junk input, band or total from check answers: **code**. Skip the call on empty input; code verifies quotes are verbatim and drops misses. (`GRADING_PIPELINE.md` G1.3, G1.4)
2. Output is a level or a choice with no text, or the same answer on rerun matters (regrades, appeals), or a generating call over-flags: **Decisions API** (`gemini-decision-1`). Offload every such judgment here before a generating call. (`GEMINI_DECISIONS.md`)
   2.1. Not for: countable parts, originality or AI authorship, feedback text or quotes, "said before the stop point vs only after it". Exempt items that assert nothing (opinion questions) in code first.
   2.2. Send the whole source and only the item under judgment. Ask one choice among contrasting failure kinds, not a bare yes/no. Keep "not a match" exclusions narrow.
   2.3. Thresholds from the teacher's graded set; read P(none) as its own signal.
3. Similarity across sources: copying and reuse, draft-to-final change, retrieving nearest examples or slides, duplicates across lessons, grouping by theme: **embeddings**. (`GEMINI_EMBEDDINGS.md`)
   3.1. Not for: quality level, AI detection, grounding, top-k evidence pruning, "same question?" inside one topic.
4. One narrow question, or lines written from already-checked findings: **Flash-Lite**, one job per call.
5. Weighing the whole text, or prose weighing several findings: **Flash**. Name why.
6. Feedback text: a generating call that receives the fixed level and findings as inputs.
7. A call that receives answers it did not compute (code or earlier calls) and would branch on them: code picks the branch and passes only the problem to address to a dedicated call.

## 2. Each generating call

1. Thinking: set explicitly per call, job named beside it. Copy word for word: minimal; rejected on the model (400): low, and state there is no equal floor. Model decides where an item ends, or lines from already-checked findings: low. Every other job: medium. (`GEMINI_3X_API_BEST_PRACTICES.md` 8)
2. Misses persist at medium: try **high** on a small bench. Still failing: **split into two medium calls**. Never raise the level for flips, quote echo, or broken bans; fix the wording or move it to code.
3. Split: each judgment check gets its own call; presence checks may share one. Also split when a call joins 3+ conditions in one verdict, bundles feedback with checks, or one check flips. Past about 6 calls per item, question each. Already split once: fix wording or route to code/Decisions before splitting again. (`GRADING_PIPELINE.md` G1.1, G1.2)
4. Flaky output: narrower checks, code, or Decisions. Never voting, majority runs, or temperature. Delete `temperature`, `top_p`, `top_k`. (`GRADING_PIPELINE.md` G8; best practices 9.4)
5. Schema: reasoning and quotes before the verdict; no model-computed counts or totals; an abstain path for thin input; output cap on long output. Student or source text inside a labeled block stated as data only; the prompt says to rely only on that text. (`GRADING_PIPELINE.md` schema essentials, G2, G9)
6. Fallback chain:
   6.1. Never a Lite model after a Flash model; no retired models. (best practices 9.7)
   6.2. Thinking level valid on every leg; log which model answered.
   6.3. Model ids and levels from the Gemini docs MCP, not memory.

## 3. Bench

1. Minimal, to find mistakes: pick the cases most likely to change under the edit, known misses plus at least one already right.
2. A case suspected of flipping: 3 uncached runs. Level comparisons report time per call.
3. State the call count first; ask before more than 5 Flash calls. One model per run; report the answering model.
4. Bench data in a persistent folder (this user: `~/.tabot/benches/`), never /tmp or a scratchpad.

## 4. Before writing code

New call, or a call whose route, tier or thinking changes: post one design block, then proceed unless vetoed.

```
<job>: <code | Decisions | embeddings | lite | flash>, thinking <level>, <reason>
Unbenched: <choices with no bench yet, and the minimal bench for each>
```

## 5. After writing the prompt

1. New or rewritten prompt: send it to `prompt-optimizer:prompt-optimizer` with the prompt inline first, then call-site facts (model and fallbacks, thinking level, schema, parser, prior size for a revision, calls sharing its system instruction), then the request last.

Edits that change no call's job, prompt, model, thinking, schema or fallback chain skip this skill.
