# Gemma 4 forensic closed-set scans

<role>
Reference for prompt-optimizer. Load when `Target model: Gemma 4` is declared
AND the prompt is a recall-sensitive closed-set scan: model walks a fixed list
of N signals/categories, emits findings per item (AI-detection scans, L1 marker
detection, multi-criterion forensic checklists). Extends
`GEMMA4_API_BEST_PRACTICES.md` — load that core file first; its rules apply
too. Rubric-grading prompts do not load this file: a rubric criterion call
judges one criterion against level descriptors, it does not walk a signal
checklist for recall. G6's 0-or-1-example cap governs rubric criteria, not scan
signals: 15.2 applies to signals only and never overrides G6 on a criterion in
the same prompt. Numbering continues the core file's sequence: this file
owns rule 15 and its 15.x sub-rules; cite them in Key Changes.
</role>

## 15. Recall-sensitive scan extension for closed-set forensic checklists

Fires when the prompt is a recall-sensitive closed-set scan (model walks a
fixed list of N signals/categories, emits findings per item; AI-detection
scans, L1 marker detection, multi-criterion forensic checklists). On firing,
these four constructs join the compaction preserve-list:

15.1. "Rationale:" clauses on each signal definition. Without them, Gemma at T=1.0 reads the signal name and moves on without scanning.

15.2. PASS-by-example density >=2 on signals whose prior-pass `findings[]` recall was measurably empty. Density stays 1 on signals that recalled fine.

15.3. Process-instruction preambles before second-pass review steps reading across earlier output ("the patchwork signature requires looking across two sections AFTER L1 evidence has accumulated"). Flattening to a conditional collapses the second pass into the first.

15.4. Closing recall-posture override ("when a substantive signal is borderline-supported, emit it; downstream calls aggregate") where the prior pass under-recalled on borderline cases.

Apply 15.1-15.4 selectively per task, never as a package. Empirical
false-positive risk, lowest to highest: 15.3 < 15.2 (signal-scoped) < 15.1 (low
FP on lexical/syntactic signals, high FP on holistic-pattern signals) < 15.4
(over-fires on clean cases globally). Briefed on a regression cycle without
per-signal A/B data → restore 15.3 first, then 15.2 on signals that recalled
empty; 15.1 and 15.4 stay opt-in with named-case justification.

## Closing reminder

Apply rule 15 selectively per the risk profile above; cite 15.x sub-rule
numbers in Key Changes. Core-file rules (schema shape, retry classification,
sampling settings per core rule 10, parsing) apply to the same prompt alongside this extension.
