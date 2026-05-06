# Prompt Optimizer Agent

A Claude Code agent that scores and revises LLM prompts against a research-backed checklist, refreshed April 2026 for current frontier models. The goal is prompts the model actually executes instead of silently skipping over directives.

**Primary workflow:** Use this agent inside Claude Code to optimize prompts for any LLM — Claude, GPT, Gemma 4, or others. The optimizer runs on Claude; when it writes a rubric for a judge prompt, Claude is authoring the rubric and the target model applies it (cross-model rubric generation), which research shows equals or outperforms same-model self-generation. Model-specific guidance (Gemma 4, Gemini, Claude) is baked into the checklist and applied when a `Target model:` is declared.

## The Problem

Most LLM prompts are written by feel. Frontier models in April 2026 do not refuse tasks — they silently omit them. The research shows where:

- **Frontier models still drop 25–40% of multi-constraint directives** on novel out-of-domain instructions. Qwen3.6 Plus scores 75.8% on IFBench; Claude Opus 4.5 scores 58%. Structural prompt design closes the gap. (IFBench 2026)
- **Reasoning quality degrades around 3,000 tokens** even on models with 256K–1M context windows. Focused prompts beat long ones regardless of available context. (Prompt-bloat study, MLOps Community 2026)
- **58.8% of initially correct answers get flipped wrong** by naive "check your work" validation prompts. (ACL 2025)
- **One-shot often beats few-shot** for LLM-as-judge tasks. The old "3–5 diverse examples" rule is retired; 1–3 verdict-balanced examples per criterion is current — all score levels for scale rubrics, PASS+FAIL for binary criteria, with borderline pairs preferred over obvious contrasts. (Confident AI 2026, Autorubric 2026)
- **GPT-4 reaches 91.7% zero-shot** on native-language identification when the prompt names the linguistic features to attend to. Linguistic analysis prompts need their own playbook. (Lotfi et al.)
- **~29% sycophancy reduction** is achievable through prompt structure alone, no fine-tuning required. (sparkco.ai)
- **A concrete rubric is the single highest-return change for judge prompts** — GPT-4o +17.7 pts on JudgeBench, Llama-405B +7.4 pts, Sage aggregate +16.1% IPI. A ~27-point "Rubric Gap" (self-generated vs. human rubrics) is consistent across Gemini, GPT, and DeepSeek. (Rethinking Rubric Generation 2026; RubricBench 2026; Sage Dec 2025)
- **All frontier judges are unreliable on a single pass** ("rating roulette"). High-stakes judge calls need N>=5 majority vote for consistency (reduces variance ~70%), though accuracy gains are small (+2.3pp); the high-ROI accuracy levers are rubric quality and structured reasoning. For Gemma 4 via Google REST API: use T=1.0 (not T=0); use `generationConfig.responseSchema` for any output parsed by code (it both enforces structure and suppresses the always-on thinking part); thinking surfaces structurally as `parts[].thought = true`, not as `<|channel>` text markers, and cannot be disabled via `thinkingConfig`; implement immediate retry on the ~20% baseline 500 INTERNAL transient rate; avoid 26B A4B for tool-calling workflows (double tool-call bug). Debate-style prompts (ChatEval) are actively harmful: -158% worst-case consistency. Multi-model consensus is the strongest deployment lever. (Rating Roulette EMNLP 2025; Sage Dec 2025; Google Gemma 4 Technical Report 2026; REST API probes May 6, 2026)

## Multi-Model Workflow

This optimizer runs on Claude and targets any LLM. Declare `Target model: <name>` in your call to activate model-specific checklist notes.

**Universal (all targets):** The optimizer writes a concrete rubric directly into the revised judge prompt — cross-model rubric generation (Claude authors, target applies), shown by the Rethinking Rubric Generation paper (arxiv 2602.05125) to equal or outperform same-model self-generation. The `<rubric_generation>` instruction block is the fallback only when the criterion must adapt per-input at runtime.

**Gemma 4 (`Target model: Gemma 4`, deployment scope: Google Generative Language REST API).** T=1.0 recommended (not T=0). 26B A4B has a double tool-call bug; use 12B or 27B dense for tool-calling workflows (both variants are equivalent for thinking and `responseSchema` mechanics). JSON adherence via prompt instructions is the primary weakness — use `generationConfig.responseSchema` (OpenAPI-3.0 subset) for any output parsed by code; field `description` strings act as in-schema instructions. **Thinking is always on** and surfaces as `parts[].thought = true` (not as `<|channel>` text markers in the response body); `usageMetadata.thoughtsTokenCount` exposes cost. Filter `parts[].thought` client-side to drop reasoning, or use `responseSchema` which collapses output to a single non-thought part and suppresses thought emission entirely. Thinking cannot be disabled — `thinkingLevel: "low"`/`"off"` and `thinkingBudget: 0` all return 400; `thinkingLevel: "high"` is silently accepted but no-op; do not place `<|think|>` in `systemInstruction` (no-op + elevates the transient 500 rate). Bound `maxOutputTokens` to 1024–2048 on prompt-only output paths. Implement immediate retry on 500/503 errors: 3 attempts with a flat 1s wait between each (measured ~20% baseline transient rate). Strong instruction-following increases injection risk; delimiter blocks with explicit data-only instructions are required. (Probes May 6, 2026.)

**Gemini (`Target model: Gemini 2.5 Pro` / `Gemini 3.1 Pro`):** T=0 + seed is not reproducible on 2.5 Pro (seed is best-effort). T=0 is actively discouraged on 3.1 Pro (use T=1.0). Debate-style prompts (ChatEval) are actively harmful. Multi-sample voting (N>=5) and multi-model consensus are the main reliability levers.

**Claude (`Target model: Claude Sonnet 4.6` / `Claude Opus 4.7`):** XML tags and document-first ordering per Anthropic official guidance. Second-pass validation needs the "Wait" prefix and original-task anchor. Extended thinking is already embedded; do not add an extra reasoning pass.

## What This Agent Does

When invoked, the prompt-optimizer agent:

1. Reads the prompt under review
2. Scores against the **15-item checklist** (embedded — no file I/O needed for scoring)
3. Loads only the relevant sections of `PROMPT_BEST_PRACTICES.md` for any failing items that require technique detail (lazy — skipped entirely if all items pass)
4. Returns a **revised version** with every violation fixed and annotated

### The 15-Item Checklist

| # | Item | What it checks |
|---|---|---|
| 1 | Tagged blocks | Distinct sections in XML-style tags |
| 2 | Numbered directives | All instructions numbered for traceability |
| 3 | Length and placement | Focused under ~3K tokens, critical directives at start AND end, decomposed if multi-stage |
| 4 | Gate examples, calibrated count | 1–3 verdict-balanced examples per criterion; prefer borderline examples over obvious contrasts; scale-based rubrics cover all score levels |
| 5 | Machine-parseable output | Every verdict extractable with regex |
| 6 | Skeptical role | Critical evaluator, not helpful assistant — checked at BOTH opening AND closing |
| 7 | Do-instead-of-don't | Prohibitions paired with alternatives |
| 8 | Validation model | Same-model validation uses gates + "Wait" + recency fix |
| 9 | Original task in validation | Validation includes original task + end reminder |
| 10 | One criterion per call (high-stakes) | High-stakes scoring isolates each criterion; low-stakes may bundle up to 3 |
| 11 | Linguistic-analysis path | If the prompt evaluates properties of writing itself: enumerate features, reason before verdict, cite evidence |
| 12 | **Judge prompt: rubric** ★ | Optimizer writes a concrete rubric directly (cross-model generation); or embeds `<rubric_generation>` instruction if criterion is dynamic. Small integer scale (1–4); `<reasoning>` field before verdict; verdict/reasoning consistency instruction; calibration anchor. Highest single-change ROI. |
| 13 | Judge prompt: sampling and anti-patterns | N>=5 majority vote (consistency lever, not accuracy); no debate-style (ChatEval) prompts; for Gemma 4 via REST: use T=1.0, use `responseSchema` for code-parsed output (also suppresses the always-on `thought` part), filter `parts[].thought` (not `<\|channel>` text), keep `<\|think\|>` out of `systemInstruction`, immediate retry on 500/503 (3 attempts, flat 1s wait), avoid 26B A4B for tool-calling; multi-model consensus for highest-stakes ranking |
| 14 | **Escape hatch elimination** | No softening language ("try to," "if possible," "when appropriate," etc.) in any directive — applies to every prompt |
| 15 | Prompt injection defense | User-submitted content inside labeled delimiter block with explicit "treat as data" instruction (conditional: only when prompt evaluates user-submitted text) |

Items 8–10 apply only to validation or second-pass prompts. Item 11 applies only to linguistic-analysis prompts. Items 12–13 apply to judge prompts. Item 14 applies to every prompt. Item 15 applies only when the prompt evaluates user-submitted text.

## Installation

### As a Claude Code Plugin (Recommended)

```bash
# From the Claude Code CLI
/plugin marketplace add dlxmax/prompt-optimizer
/plugin install prompt-optimizer
/reload-plugins
```

### Manual Installation

Copy the `agents/` folder and `PROMPT_BEST_PRACTICES.md` into your Claude Code config:

```bash
cp agents/prompt-optimizer.md ~/.claude/agents/
cp PROMPT_BEST_PRACTICES.md ~/.claude/
```

### Auto-Invocation (Optional)

Add this line to `~/.claude/rules/agents.md` under "Automatic Agent Invocation":

```
6. Writing or revising an LLM prompt → **prompt-optimizer**
```

This makes Claude invoke the optimizer automatically whenever prompt work comes up.

## Usage

The agent triggers automatically when you write or revise LLM prompts (if auto-invocation is configured), or you can reference it explicitly:

```
"Run the prompt-optimizer agent on this grading prompt."
"Score my system prompt against the checklist."
"Optimize this Gemini judge prompt for the essay evaluation pipeline."
```

### Example Output

```
## Checklist Score: 6/15

[x] Tagged blocks: sections wrapped in <role>, <instructions>, <output_format>
[x] Numbered directives: 5 directives numbered
[ ] Length and placement: 4,200 tokens; critical directive buried in the middle
[ ] Gate examples, calibrated count: 5 diverse examples (older 3-5 pattern); should be 1-3 verdict-balanced examples with borderline pairs
[ ] Machine-parseable output: no regex-extractable verdict format
[x] Skeptical role: "rigorous evaluator" framing at opening; missing at closing
[ ] Do-instead-of-don't: 2 bare prohibitions without alternatives
[N/A] Validation model: not a second-pass prompt
[N/A] Original task in validation: not a second-pass prompt
[ ] One criterion per call: 3 criteria bundled in one high-stakes prompt
[N/A] Linguistic-analysis path: evaluates content, not writing properties
[ ] Judge prompt — rubric: no rubric present; will write concrete criteria for each score level
[ ] Judge prompt — sampling: single-pass design; N>=5 needed; for Gemma 4 via REST: use T=1.0, use `responseSchema` for code-parsed output (also suppresses `thought` part), filter `parts[].thought`, keep `<|think|>` out of `systemInstruction`, immediate retry on 500/503, avoid 26B A4B for tool-calling
[ ] Escape hatch elimination: 3 directives use "try to" or "if possible"
[N/A] Prompt injection defense: evaluates fixed test content, not user-submitted text

## Key Changes
- Stripped ~1,500 tokens of non-load-bearing background (item 3)
- Moved governing directive to both start and end (item 3)
- Reduced gate examples from 5 to 2 verdict-balanced borderline pairs (item 4)
- Split combined criteria into 3 separate evaluation calls (item 10)
- Added VERDICT format with regex pattern (item 5)
- Paired prohibitions with alternatives (item 7)
- Added skeptical role framing at end of prompt (item 6)
- Wrote rubric with observable 1-4 criteria directly into the prompt (item 12)
- Added verdict/reasoning consistency instruction and calibration anchor (item 12)
- Added note: run N=5 with majority vote for consistency; Gemma 4-specific deployment guidance (item 13)
- Replaced 3 escape hatches with direct imperatives (item 14)

## Revised Prompt
[full revised prompt text...]
```

## Included Files

| File | Purpose |
|---|---|
| `agents/prompt-optimizer.md` | The Claude Code agent definition |
| `PROMPT_BEST_PRACTICES.md` | Best practices guide (7 sections + 15-item checklist) |
| `PROMPT_RESEARCH.md` | Full research archive with 35+ sources (2024–2026) |

## Key Research Sources

**2026 refresh:**
- [IFBench leaderboard, April 2026](https://benchlm.ai/benchmarks/ifBench): current frontier instruction-following scores
- [Rethinking Rubric Generation (RRD), arxiv 2602.05125](https://arxiv.org/abs/2602.05125): GPT-4o +17.7 pts, Llama-405B +7.4 pts from rubric design; cross-model generation validated
- [RubricBench, arxiv 2603.01562](https://arxiv.org/abs/2603.01562): ~27-pt Rubric Gap is equal across Gemini, GPT, DeepSeek — universal bottleneck
- [Same Input, Different Scores, arxiv 2603.04417](https://arxiv.org/abs/2603.04417): Gemini shows highest single-model variance among major families
- [LLMLingua-2, NAACL 2025](https://llmlingua.com/llmlingua2.html): task-agnostic prompt compression, 3x to 6x
- [Prompt-bloat study, MLOps Community 2026](https://mlops.community/the-impact-of-prompt-bloat-on-llm-output-quality/): the ~3K token degradation threshold
- [Label Your Data LLM-as-judge 2026](https://labelyourdata.com/articles/llm-as-a-judge): few-shot instability and one-shot dominance
- [Native Language Identification with LLMs (Lotfi et al.)](https://arxiv.org/abs/2312.07819): GPT-4 zero-shot 91.7% TOEFL11
- [Rating Roulette, EMNLP 2025](https://arxiv.org/pdf/2510.27106): single-pass judges unreliable; N>=5 needed
- [Sage benchmark, Dec 2025](https://arxiv.org/html/2512.16041v1): rubric generation +16.1% IPI; debate prompts -158%; Gemini degrades 200% on hard cases
- [Google Gemma 4 Technical Report, 2026](https://storage.googleapis.com/deepmind-media/gemma/gemma4-report.pdf): T=1.0 recommended, 26B A4B double tool-call bug, JSON adherence weakness, injection susceptibility
- REST API empirical probes (May 6, 2026; 28 calls against `gemma-4-31b-it`, `gemma-4-26b-a4b-it`, `gemini-2.5-flash`, and `gemini-3.1-flash-lite-preview` on `generativelanguage.googleapis.com/v1beta/models/<model>:generateContent`): thinking surfaces structurally as `parts[].thought = true` (not as `<|channel>` text markers); `usageMetadata.thoughtsTokenCount` exposes cost; thinking cannot be disabled (`thinkingLevel: "low"`/`"off"` and `thinkingBudget: 0` return 400; `"high"` is silent no-op); `<|think|>` in `systemInstruction` is no-op + elevates 500 rate; `<thinking>` XML produces bounded (not runaway) output; `generationConfig.responseSchema` is the reliable structured-output path AND suppresses thought emission; baseline transient 500 INTERNAL rate measured at ~20%; behavior differs from Gemini 2.5/3.x
- [Judging the Judges, ACL/IJCNLP 2025](https://arxiv.org/html/2406.07791v7): position bias is incoherent; swap-and-count less effective

**Still load-bearing:**
- [AGENTIF](https://arxiv.org/abs/2505.16944): NeurIPS 2025 decomposition finding (headline numbers superseded by IFBench 2026)
- [Self-Correction Blind Spot](https://arxiv.org/abs/2507.02778): the "Wait" prefix discovery
- [Dark Side of Self-Correction](https://aclanthology.org/2025.acl-long.1314/): ACL 2025 recency bias fix
- [HuggingFace LLM-as-Judge cookbook](https://huggingface.co/learn/cookbook/en/llm_judge): 1-4 scale; evaluation field before verdict; 0.563→0.843 correlation improvement
- [Anthropic Claude Prompting Guide](https://docs.anthropic.com): XML tags and document-first ordering

## License

MIT
