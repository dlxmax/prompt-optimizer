# Gemma 4 forensic closed-set scans

<role>
Reference material for the prompt-optimizer agent. Load when `Target model: Gemma 4`
is declared AND the prompt under review is a recall-sensitive closed-set
scan: the model walks a fixed list of N signals/categories and emits
findings per item (AI-detection scans, L1 marker detection,
multi-criterion forensic checklists). This file extends
`GEMMA4_API_BEST_PRACTICES.md` (load that core file first; its rules
apply too). Rubric-grading prompts do not load this file: a rubric
criterion call judges one criterion against level descriptors, it does
not walk a signal checklist for recall. Rule numbering continues the core
file's sequence: this file owns rule 15 and its 15.x sub-rules; cite them
in Key Changes for deployer verification.
</role>

## 15. Recall-sensitive scan extension for closed-set forensic checklists

Fires when the prompt is a recall-sensitive closed-set scan (model walks a fixed list of N signals/categories and emits findings per item; AI-detection scans, L1 marker detection, multi-criterion forensic checklists). When it fires, these four constructs are added to the optimizer's compaction preserve-list:

15.1. "Rationale:" clauses on each signal definition. Without them, Gemma at T=1.0 reads the signal name and moves on without scanning.

15.2. PASS-by-example density of >=2 PASS examples on signals where the prior pass's `findings[]` recall was measurably empty. Keep density at 1 on signals that recalled fine.

15.3. Process-instruction preambles before second-pass review steps that read across earlier output (e.g., "the patchwork signature requires looking across two sections AFTER L1 evidence has accumulated"). Flattening to a conditional collapses the second pass into the first.

15.4. Closing recall-posture override ("when a substantive signal is borderline-supported, emit it; downstream calls aggregate") when the prior pass under-recalled on borderline cases.

Apply 15.1-15.4 selectively per task, not as a package. Empirical risk profile, lowest to highest false-positive: 15.3 < 15.2 (signal-scoped) < 15.1 (low FP on lexical/syntactic signals, high FP on holistic-pattern signals) < 15.4 (over-fires on clean cases globally). When briefed on a regression cycle without per-signal A/B data, default to restoring 15.3, then 15.2 on signals that recalled empty, and treat 15.1 and 15.4 as opt-in with named-case justification.

## Closing reminder

Apply rule 15 selectively per the risk profile above and cite 15.x
sub-rule numbers in Key Changes. The core file's rules (schema shape,
retry classification, sampling triple, parsing) apply to the same prompt
alongside this extension.
