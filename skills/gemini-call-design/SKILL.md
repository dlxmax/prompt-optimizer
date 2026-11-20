---
name: gemini-call-design
description: Use when adding a Gemini API call (google-genai, generateContent, Interactions, gemini-* ids, gemini-decision-1, gemini-embedding-*) or changing a call's job, prompt, model, thinking level, schema or fallback chain, including grading, feedback, lesson generation and checks. Decides code vs Decisions vs embeddings vs a generating call, tier, thinking, splitting, schema and bench before code. Not for edits that change none of a call's job, prompt, model, thinking, schema or fallback chain.
---

# Gemini call design

Decide the architecture before writing the prompt. Cited guides sit in the plugin root: join this skill's base directory (shown when the skill loads) with `../../<GUIDE>.md` and Read that absolute path. Read a cited guide when you set the parameter or route that line names. "Best practices" below means `GEMINI_3X_API_BEST_PRACTICES.md`.

## 1. Route each job, first match wins

1. Countable, arithmetic, substring, date, set, regex, dedup, empty or junk input, band or total from check answers: **code**. Skip the call on empty input; code verifies quotes (case and punctuation normalised, then substring) and drops misses. A copy field has three states: none, verified text, unverified; unverified never reads as none. Positions (earliest, first, share of words), counts and levels are code on verified spans. (`GRADING_PIPELINE.md` G1.3, G1.4, G2)
2. Output is a level or a choice with no text, or the same answer on rerun matters (regrades, appeals), or a generating call over-flags: **Decisions API** (`gemini-decision-1`). Offload every such judgment here before a generating call. (`GEMINI_DECISIONS.md`)
   2.1. Not for: countable parts, originality or AI authorship, feedback text or quotes, "said before the stop point vs only after it". Exempt items that assert nothing (opinion questions) in code first.
   2.2. Send only the item under judgment from the work judged. Source: whole for claim-support checks; for a part defined by position (opening, ending) code slices by the part, and each slice is benched on the cases it must answer. Ask one choice among contrasting failure kinds, not a bare yes/no. Ask what the item is, never what a later step would need. Options are mutually exclusive contrasts, each with a test case that lands in it; check each positive case against every option, and rewrite when one fits two; a "none" option is tested on the best cases, not only the weak ones. Keep "not a match" exclusions narrow. Define every referent; use the plain concept name, not the course's label. Bench the question alone (probe, section 3, 1.1) on one hand-written item per type, near-misses included, before a pipeline bench.
   2.3. Thresholds from the teacher's graded set; read P(none) as its own signal. A cutoff is provisional until it has two positives from two different inputs: ship it marked provisional and list it under `Unbenched:`. Record the gold-file version beside it, log the probabilities, keep it in a sidecar or env-overridable constant, and say when only the yes branch was tested. The default 0.5 is an uncalibrated placeholder. P 0.3-0.7 on cases that should be clear is a design fault: redesign the options, question or context; never tune the cutoff to fit.
   2.4. A call that copies a quote and also judges it is two jobs: lite copies spans, Decisions judges, code verifies quotes and sets levels, positions and counts. Convert probabilities in code to the fields the existing level code reads, so that code does not change. Take the decide function as an argument; None keeps the lite answers (patterns: `GEMINI_CALL_PATTERNS.md`).
   2.5. Moving a level judgment from lite to Decisions is not a drop-in. Bench at least one top-level and one bottom-level anchor, and report branch-flag changes between the two routes. A check that fails its bench on Decisions stays on lite.
   2.6. Over-flag in the other direction: when lite's false negatives cost more than its false positives, lite "yes" stands and lite "no" is overturned only when Decisions reaches a stated cutoff.
   2.7. A generator receiving input it should not: route upstream with a Decisions question before building downstream rules or re-calls to repair its output.
   2.8. A Decisions request carries model, input and questions only: the thinking rules in section 2 apply to generating calls.
3. Similarity across sources: copying and reuse, draft-to-final change, retrieving nearest examples or slides, duplicates across lessons, grouping by theme: **embeddings**. (`GEMINI_EMBEDDINGS.md`)
   3.1. Not for: quality level, AI detection, grounding, top-k evidence pruning, "same question?" inside one topic.
4. One narrow question, or lines written from already-checked findings: **Flash-Lite**, one job per call. Not when a miss means invented facts, dropped items or lookalike matching: that is Flash. (best practices 9.2)
5. Weighing the whole text, or prose weighing several findings: **Flash**. Name why.
   5.1. Hard tier, UNBENCHED: when lite and Decisions both fail an extremely hard judgment, one medium call to the hard-tier model bundling 2-3 related judgments, within its per-key limits. (best practices 9.9, 10.5)
6. Feedback text: a generating call that receives the fixed level and findings as inputs, never internal labels. (`FEEDBACK_GENERATION.md` F11, F12)
7. A call that receives answers it did not compute (code or earlier calls) and would branch on them: code picks the branch and passes only the problem to address to a dedicated call.

## 2. Each generating call

1. Thinking: set explicitly per call, job named beside it. Copy or split word for word: minimal; on a model that rejects minimal (HTTP 400): low, and state there is no equal floor. Model decides where an item ends: low. Every other job, lines from already-checked findings included: medium; low only where a bench shows medium under-returns or truncates at the output cap. (`GEMINI_3X_API_BEST_PRACTICES.md` 8)
2. Misses persist at medium: try **high** on a small bench. Still failing: **split into two medium calls**. Never raise the level for flips, quote echo, or broken bans; fix the wording, narrow the call, or move it to code. A persistent miss on a sound prompt gets one high try: 3 uncached runs of the failing case plus a control, kept only if it beats medium on all three (tie: keep the lower level).
3. Split: each judgment check gets its own call; presence extraction may share one call (about 10, unbenched); a call that also writes prose carries at most 3-4 asks until benched. Also split when a call joins 3+ conditions in one verdict, bundles feedback with checks, or one check flips. Past about 6 calls per item, question each. Already split once: fix wording or route to code/Decisions before splitting again. (`GRADING_PIPELINE.md` G1.1, G1.2)
4. Flaky output: narrower checks, code, or Decisions. Never voting, majority runs, or temperature. Delete `temperature`, `top_p`, `top_k`. (`GRADING_PIPELINE.md` G8; best practices 9.4)
5. Schema: reasoning and quotes before the verdict; no model-computed counts or totals; an abstain path for thin input; output cap on long output. Student or source text inside a labeled block, with the data-only instruction stated outside that block; the prompt says to rely only on that text. (`GRADING_PIPELINE.md` schema essentials, G2, G9)
6. Fallback chain:
   6.1. Never a Lite model after a Flash model; no retired models. (best practices 9.7)
   6.2. Thinking level valid on every leg; log which model answered, for every call class, Decisions included.
   6.3. Model ids and levels from the Gemini docs MCP, not memory.
   6.4. Pin a call to a stronger model only after a shown failure on the weaker one; write the reason beside the pin.
7. Failure policy: every added check states what a failed or unparseable reply does, including a bad value inside a parsed reply. A failed check keeps the line and reports it; a failed guard on a branch that unlocks content (praise, coaching) takes the closed branch. A slip code finds gets one uncached retry; keep and report the second, except on a content-unlocking branch, which takes the closed branch (an unverified praise line becomes simple praise, `FEEDBACK_GENERATION.md` F11). A level-producing call that still fails after its one retry routes to the pipeline's non-score outcome (human review), never a guessed level. Sibling checks share one policy. A Decisions sidecar that fails as a whole falls back to lite and says so in the review; one failed per-item check keeps the item and reports it.
8. Routing: route a job by an explicit setting, not a name substring. A job that cannot grade a path refuses; it never falls back to a generic prompt.
9. Tests before the commit: every new branch, including fallback, refusal and failure paths, with a fake decide function. (`GEMINI_CALL_PATTERNS.md`)

## 3. Bench

1. Bench in stages, cheapest first, to find mistakes; run a stage only after reading the prior stage's outputs.
   1.1. Probe: send the changed instruction alone plus one case text to the target model as single uncached calls. Write 2-4 wording variants, run each 2-3 times, compare the outputs side by side, pick a wording. When the instruction carries a ban or guard ("never name X"), make one variant without it: a ban meant to stop invention can cause invention. A probe cannot show how the rule interacts with the rest of the prompt, so the winner still gets 1.2.
   1.2. Branch bench: put the chosen wording into the full prompt; 1 run on 2-3 known-problem cases that reach the changed text. Read every output for breakage first.
   1.3. Widen: 1 run on the rest of the known misses that reach the changed text, plus one already-right case.
   1.4. Flip check: 3 uncached runs, only on cases whose output varied in 1.2-1.3.
   1.5. Final confirmation: the whole set x 3 runs, only after the teacher asks for it; never the first bench.
   1.6. Start runs one at a time, never in parallel: launched calls cannot be killed, so the user can no longer cut the bench down.
   1.7. Scope: stages 1.2-1.4 use only cases that read the changed text. An edit to a shared system instruction or an unbranched rule reaches every case, so pick from all cases. Add one case off the changed branch to catch leaks. Never "run the class" before 1.5.
   1.8. Before any bench, state its stage (1.1-1.5) and call count.
2. Accept a prompt change only on uncached reruns: the failing cases fixed in 3 of 3 runs and one already-right control unchanged. Record a config hash (prompt, question files, chain) and the answering model per run; edits between runs are not noise. Decisions replies are cached by input and questions: bypass the cache before claiming rerun stability. Level comparisons report time per call.
3. Ask before more than 5 Flash calls (one ask covers a stated iteration set). One model per run; report the answering model. A run in which a fallback leg answered is not the experiment.
4. Bench data and logs in a persistent folder (this user: `~/.tabot/benches/`), never /tmp, a scratchpad or the code repo. Check the log is non-empty.
5. Labels: a label set is ground truth only after its owner confirms it. Re-check your own label before calling a model miss. With no owner key, a bench shows differences, not regressions. Adjudicator-model verdicts are input; the owner's ruling overrides; keep them in separate keys.
6. Bench input text equals production text, or cache keys and grades differ. A bench on real work writes the production cache on purpose; variance runs go to a throwaway cache.
7. Folder layout, probes and accounting: `GEMINI_CALL_PATTERNS.md`.

## 4. Before writing code

1. New call, or a call whose route, tier or thinking changes: post one design block, then proceed unless vetoed.

```
<job>: <code | Decisions | embeddings | lite | flash>, thinking <level, generating calls only>, <reason>
Failure: <what a failed or unparseable reply does; log of the answering model>
Cutoffs: <value, graded set, gold version, provisional or not; omit when none>
Unbenched: <choices with no bench yet, and the minimal bench for each>
```

## 5. After writing the prompt

1. New or rewritten prompt: send it to `prompt-optimizer:prompt-optimizer` with the prompt inline first, then call-site facts (model and fallbacks, thinking level, schema, parser, prior size for a revision, calls sharing its system instruction), then the request last.
2. Without asking the user: apply its fixes (or state why one is declined), send the revision to the same agent per its `Next:` line, and repeat until it reports no failing items (no revision warranted). Order: probe the wording (section 3, 1.1), then one review round on the winning wording, then the branch bench (1.2). Never more than one review round on wording no model has run; a second round follows a bench result.
3. Prompt examples stay general and domain-neutral; never send a case's own line as the target. A wording change is tested on the other judgments that read the same field and on other inputs.
4. Run the tests (section 2, item 9) and the section 3 bench before the commit.
5. Edits that change no call's job, prompt, model, thinking, schema or fallback chain skip this skill.
