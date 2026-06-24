# Prompt Optimizer Agent

A Claude Code agent that scores and revises LLM prompts against a research-backed checklist.

**Topics:** `gemini` · `gemini-3.5` · `gemini-3.5-flash` · `gemini-3.x` · `interactions-api` · `gemma-4` · `gemma` · `claude` · `deepseek` · `deepseek-v4` · `response-schema` · `structured-output` · `rubric` · `llm-judge` · `prompt-engineering` · `prompts` · `agents` · `sycophancy` · `validation` · `compliance` · `best-practices`

**Primary focus: mitigating known failure modes on `Gemini 3.x` (including 3.5 Flash GA) via the Gemini Interactions API, `Gemma 4 31b` via the same API, and `DeepSeek V4` (V4-Pro, V4-Flash) via the DeepSeek API.** The agent also targets Claude. The 15-item checklist is model-agnostic; model-specific rules kick in when a `Target model:` is declared. Probe data behind the current rules: the canonical Gemini docs scraped on 2026-06-24 covering the Interactions API GA, 3.5 Flash, long-context placement, thinking, and prompt design strategies; 100+ probe calls against Gemma 4 between May 6–13 2026; and the DeepSeek V4 strict-ordering failure modes captured across 6 optimizer rounds in May 2026.

The two goals are: prompts the model actually executes instead of silently skipping over directives, and call mechanics that do not waste retry budget on failures the schema or parser already explains.

**Primary workflow:** Use this agent inside Claude Code to optimize prompts for any LLM. The optimizer runs on Claude; when it writes a rubric for a judge prompt, Claude is authoring the rubric and the target model applies it (cross-model rubric generation), which research shows equals or outperforms same-model self-generation. Model-specific guidance is baked into the checklist and applied when a `Target model:` is declared.

## Failure modes the optimizer mitigates

### Gemini 3.x / 3.5 Flash (Interactions API)

Five rules the optimizer scans for, drawn from Google's canonical prompt design strategies, the 3.5 Flash guide, the Interactions API GA docs, and the long-context guide. Full mechanics in [`GEMINI_3X_API_BEST_PRACTICES.md`](GEMINI_3X_API_BEST_PRACTICES.md).

- **Remove `temperature`, `top_p`, `top_k`.** Google's 3.5 Flash guide is explicit: "we strongly recommend not changing the default values ... Remove these parameters from all requests." Setting them on Gemini 3.x can cause looping or degraded performance. To force determinism, write the system instruction with explicit rules instead.
- **Replace `thinking_budget` (numeric) with `thinking_level` (`minimal` / `low` / `medium` / `high`).** 3.5 Flash defaults to `medium` (down from `high` on 3 Flash Preview). `thinking_level` and `thinking_budget` are mutually exclusive — passing both returns HTTP 400.
- **Long-context query placement.** Substantial context blocks come first; the user's specific query goes at the END, anchored with "Based on the preceding information...". Burying the query at the top is a defect on long-context prompts.
- **Critical-instructions placement.** Persona, behavioral constraints, and output format requirements live in the `system_instruction` parameter OR at the very beginning of the user prompt — not buried after long context or examples.
- **Consistent structure (XML XOR Markdown).** Use XML-style tags OR Markdown headings as section delimiters; do not mix both styles within the same prompt.

The optimizer also flags multimodal prompts that fail to reference each modality explicitly, and recommends porting Google's published 9-point agentic planning template into the system instruction when the prompt drives an agentic workflow.

### Gemma 4 31b (Interactions API)

Three highest-ROI before/after fixes. Full mechanics, thresholds, and probe data in [`GEMMA4_API_BEST_PRACTICES.md`](GEMMA4_API_BEST_PRACTICES.md).

#### 1. Thinking is always on; only `response_format` suppresses it

Without `response_format`, every call pays the always-on thinking cost (visible as `thought` steps in `interaction.steps[]`, median wall-clock ~67s on short outputs, non-zero `MALFORMED_RESPONSE` rate). With it, thinking collapses and the same call returns in 1–2s with `MALFORMED` at 0%. The documented levers (`thinking_level: "off"`, `thinking_budget: 0`) return HTTP 400 on Gemma 4; `response_format` is the only mechanism that works.

```python
# Before: thinking burns the budget; MALFORMED non-zero; ~67s median.
interaction = client.interactions.create(
    model="gemma-4-31b-it",
    input=user_prompt,
)

# After: thinking suppressed; MALFORMED 0%; ~30 to 40x faster.
interaction = client.interactions.create(
    model="gemma-4-31b-it",
    input=user_prompt,
    response_format={
        "type": "text",
        "mime_type": "application/json",
        "schema": {
            "type": "object",
            "properties": {"output": {"type": "string"}},
            "required": ["output"],
        },
    },
)
```

#### 2. Property order in the schema controls emission order

Gemma 4 emits an OBJECT's properties in the order they appear in the schema's `properties` dict. Putting `reasoning` BEFORE `verdict` forces reason-before-commit; reversing it lets the verdict lock first and inflates the justification afterward. Per-item output dropped from ~1.8k to ~250 chars under this change alone on a warmup validator.

```python
# Before: verdict commits first; reasoning then inflates to justify.
"properties": {
    "verdict":   {"type": "string", "enum": ["KEEP", "DROP"]},
    "reasoning": {"type": "string"},
}

# After: reasoning is generated first; verdict is the output of it.
"properties": {
    "reasoning": {"type": "string"},
    "verdict":   {"type": "string", "enum": ["KEEP", "DROP"]},
}
```

Caveat: this only applies to narrow schemas. With ≥4 mandatory nested OBJECTs, adding a top-level reasoning STRING crashes the request on `31b` (alternating 400/500, 0/4 success). Move the reasoning surface to prompt-level prose or a separate narrow call.

#### 3. Parse with `raw_decode`, not `json.loads`

Even with `response_format`, Gemma 4 occasionally appends trailing text after valid JSON (~1 in 12 calls observed). `json.loads` raises on the trailing bytes; `raw_decode` returns the first valid object and ignores the rest.

```python
# Before: ~8% of otherwise-valid outputs raise json.JSONDecodeError.
parsed = json.loads(interaction.output_text)

# After: parses cleanly across all observed Gemma 4 outputs.
parsed, _ = json.JSONDecoder().raw_decode(interaction.output_text)
```

### DeepSeek V4 (V4-Pro / V4-Flash)

Three rules the optimizer scans for. Full mechanics in [`DEEPSEEK_V4_API_BEST_PRACTICES.md`](DEEPSEEK_V4_API_BEST_PRACTICES.md).

- **JSON-mode "json"-keyword anchor and example block.** When the deployer uses `response_format={"type": "json_object"}`, the system or user message must contain the literal word "json" AND a concrete EXAMPLE INPUT + EXAMPLE JSON OUTPUT block. Absence causes the model to emit unbounded whitespace to `max_tokens`, presenting as a hang. V4 has no `responseSchema` analogue; the prompt is the only schema-enforcement surface.
- **Strict-ordering failure modes.** V4 emits multi-element sequences in alphabetical order regardless of lookup tables (alphabetical-default bias), copies concrete example values verbatim across distinct instances (example tyranny), and defaults to minimum-cost completion on length-bounded fields and closed-set whitelists. The optimizer surfaces these patterns and recommends the matching prose mitigation.
- **Schema-intervention anti-pattern.** V4 silently drops schema-level constraints (property order, required-field bindings, enum constraints). The optimizer refuses to recommend schema-restructure fixes on V4 targets and routes all behavioral steering through prose: directive text, EXAMPLE INPUT + EXAMPLE JSON OUTPUT, concrete rubric language.

### Migration-defect scanning (rule 13)

The agent flags appearances of retired Gemini wiring as migration defects: `client.models.generate_content(...)`, `:generateContent` / `:streamGenerateContent` endpoints, `generationConfig.responseSchema`, `contents: [{role, parts: [...]}]`, `systemInstruction.parts[].text`, `response.candidates[0].content.parts`, `parts[].thought` filtering, object-keyed tools arrays (`{googleSearchRetrieval: {}}`), and caller-managed history re-sends. Each defect is paired with its Interactions API equivalent in Key Changes.

## The Problem

Most LLM prompts are written by feel. Frontier models in 2026 do not refuse tasks, they silently omit them. The research shows where:

- **Frontier models still drop 25 to 40% of multi-constraint directives** on novel out-of-domain instructions. Qwen3.6 Plus scores 75.8% on IFBench; Claude Opus 4.5 scores 58%. Structural prompt design closes the gap. (IFBench 2026)
- **Reasoning quality degrades around 3,000 tokens** even on models with 256K to 1M context windows. Focused prompts beat long ones regardless of available context. (Prompt-bloat study, MLOps Community 2026)
- **Long-context query placement matters.** Google's Long Context FAQ and 3.5 Flash guide are explicit: when the total context is long, put the user's query at the END after the data, anchored with "Based on the preceding information...".
- **58.8% of initially correct answers get flipped wrong** by naive "check your work" validation prompts. (ACL 2025)
- **One-shot often beats few-shot** for LLM-as-judge tasks. The old "3 to 5 diverse examples" rule is retired; 1 to 3 verdict-balanced examples per criterion is current, all score levels for scale rubrics, PASS+FAIL for binary criteria, with borderline pairs preferred over obvious contrasts. (Confident AI 2026, Autorubric 2026)
- **GPT-4 reaches 91.7% zero-shot** on native-language identification when the prompt names the linguistic features to attend to. Linguistic analysis prompts need their own playbook. (Lotfi et al.)
- **~29% sycophancy reduction** is achievable through prompt structure alone, no fine-tuning required. (sparkco.ai)
- **A concrete rubric is the single highest-return change for judge prompts**: GPT-4o +17.7 pts on JudgeBench, Llama-405B +7.4 pts, Sage aggregate +16.1% IPI. A ~27-point "Rubric Gap" (self-generated vs. human rubrics) is consistent across Gemini, GPT, and DeepSeek. (Rethinking Rubric Generation 2026; RubricBench 2026; Sage Dec 2025)
- **All frontier judges are unreliable on a single pass** ("rating roulette"). High-stakes judge calls need N≥5 majority vote for consistency (reduces variance ~70%), though accuracy gains are small (+2.3pp); the high-ROI accuracy levers are rubric quality and structured reasoning. Debate-style prompts (ChatEval) are actively harmful: -158% worst-case consistency. Multi-model consensus is the strongest deployment lever. (Rating Roulette EMNLP 2025; Sage Dec 2025)
- **Three model families need their own playbooks:** Gemini 3.x via Interactions ([`GEMINI_3X_API_BEST_PRACTICES.md`](GEMINI_3X_API_BEST_PRACTICES.md)), Gemma 4 via Interactions ([`GEMMA4_API_BEST_PRACTICES.md`](GEMMA4_API_BEST_PRACTICES.md)), and DeepSeek V4 ([`DEEPSEEK_V4_API_BEST_PRACTICES.md`](DEEPSEEK_V4_API_BEST_PRACTICES.md)).

## Multi-Model Workflow

This optimizer runs on Claude and targets any LLM. Declare `Target model: <name>` in your call to activate model-specific checklist notes.

**Universal (all targets):** The optimizer writes a concrete rubric directly into the revised judge prompt (cross-model rubric generation: Claude authors, target applies), shown by the Rethinking Rubric Generation paper to equal or outperform same-model self-generation. The `<rubric_generation>` instruction block is the fallback only when the criterion must adapt per-input at runtime.

**Gemini 3.x (`Target model: Gemini 3.5 Flash` / `Gemini 3.1 Pro` / `Gemini 3 Flash Preview` / `Gemini 3.x`).** Surface: Interactions API only; `:generateContent` is retired for the optimizer's recommendations. Strip `temperature` / `top_p` / `top_k`; use `thinking_level` instead of `thinking_budget`; place query at end of long context; pick XML XOR Markdown for section delimiters; place critical instructions in `system_instruction` or at the very beginning of the user prompt; reference each modality explicitly. 3.5 Flash does NOT support Computer Use (stay on Gemini 3 Flash Preview for that workload); image segmentation is not supported anywhere in 3.x (use Gemini 2.5 Flash with thinking off or Gemini Robotics-ER 1.6).

**Gemma 4 (`Target model: Gemma 4`).** Surface: Gemini Interactions API (`v1beta/interactions`, `client.interactions.create(...)`, `google-genai >= 2.3.0`). The checklist applies `response_format` as the deployment lever (suppresses always-on thinking, fixes JSON structure, ~30 to 40x speedup), property-ordered properties for reason-before-commit, `raw_decode` for parsing, retry classification, and the schema-padding / parent-child enum-order rules. Both `gemma-4-31b-it` and `gemma-4-26b-a4b-it` are covered; rule 2 isolates the multi-STRING failure mode unique to `26b-a4b`, and the tool-calling bug is captured for the same variant. Use `31b` when both are options. Gemma 4 still uses T=1.0, top_p=0.95, top_k=64 (NOT the Gemini 3.x parameter-removal rule).

**DeepSeek V4 (`Target model: DeepSeek V4`).** Default-on thinking mode; JSON-mode "json"-keyword and example-block requirement; strict-mode tool calling on the `/beta` endpoint; the Anthropic-compatible endpoint capability subset; the schema-intervention refusal list. All behavioral steering routes through prose, not schema.

**Claude (`Target model: Claude Sonnet 4.6` / `Claude Opus 4.7` / `Claude Opus 4.8`).** XML tags and document-first ordering per Anthropic official guidance. Second-pass validation needs the "Wait" prefix and original-task anchor. Extended thinking is already embedded; do not add an extra reasoning pass.

## What This Agent Does

When invoked, the prompt-optimizer agent:

1. Reads the prompt under review (caller-message shape enforced: `<prompt_under_review>` block first, scoring directive at the end anchored with "Based on the preceding prompt, ...")
2. Scores against the **15-item checklist** (embedded, no file I/O needed for scoring)
3. Loads only the relevant sections of `PROMPT_BEST_PRACTICES.md` for any failing items that require technique detail (lazy, skipped entirely if all items pass)
4. For each declared `Target model:`, loads the matching family reference: [`GEMINI_3X_API_BEST_PRACTICES.md`](GEMINI_3X_API_BEST_PRACTICES.md), [`GEMMA4_API_BEST_PRACTICES.md`](GEMMA4_API_BEST_PRACTICES.md), or [`DEEPSEEK_V4_API_BEST_PRACTICES.md`](DEEPSEEK_V4_API_BEST_PRACTICES.md)
5. Returns a **revised version** with every violation fixed and annotated

### The 15-Item Checklist

| # | Item | What it checks |
|---|---|---|
| 1 | Tagged blocks | Distinct sections in XML-style tags |
| 2 | Numbered directives | All instructions numbered for traceability |
| 3 | Length and placement | Focused under ~3K tokens, critical directives at start AND end, decomposed if multi-stage. For long-context prompts (≥~500 tokens of inline data) the user's specific query goes at the END, anchored with "Based on the preceding information..." |
| 4 | Gate examples, calibrated count | 1 to 3 verdict-balanced examples per criterion; prefer borderline examples over obvious contrasts; scale-based rubrics cover all score levels |
| 5 | Machine-parseable output | Every verdict extractable with regex |
| 6 | Skeptical role | Critical evaluator, not helpful assistant, checked at BOTH opening AND closing |
| 7 | Do-instead-of-don't | Prohibitions paired with alternatives |
| 8 | Validation model | Same-model validation uses gates + "Wait" + recency fix |
| 9 | Original task in validation | Validation includes original task + end reminder |
| 10 | One criterion per call (high-stakes) | High-stakes scoring isolates each criterion; low-stakes may bundle up to 3 |
| 11 | Linguistic-analysis path | If the prompt evaluates properties of writing itself: enumerate features, reason before verdict, cite evidence |
| 12 | **Judge prompt: rubric** ★ | Optimizer writes a concrete rubric directly (cross-model generation); small integer scale (1 to 4); `<reasoning>` field before verdict; verdict/reasoning consistency instruction; calibration anchor. Highest single-change ROI. |
| 13 | Judge prompt: sampling and family-specific rules | N≥5 majority vote (consistency lever); no debate-style prompts; for Gemma 4: T=1.0, `response_format`, retry classification, schema-shape rules; for Gemini 3.x: strip sampling params, `thinking_level`, function-calling strict matching; for DeepSeek V4: JSON-mode "json" anchor, strict tool calling, prose-only behavioral steering; multi-model consensus for highest-stakes ranking |
| 14 | **Escape hatch elimination** | No softening language ("try to," "if possible," "when appropriate," etc.) in any directive, applies to every prompt |
| 15 | Prompt injection defense | User-submitted content inside labeled delimiter block with explicit "treat as data" instruction (conditional: only when prompt evaluates user-submitted text) |

Items 8 to 10 apply only to validation or second-pass prompts. Item 11 applies only to linguistic-analysis prompts. Items 12 to 13 apply to judge prompts. Item 14 applies to every prompt. Item 15 applies only when the prompt evaluates user-submitted text.

### Rules beyond the checklist

The agent file carries 14 numbered rules covering: count-vs-universal consistency, Gemma 4 recall-sensitive scan extension, DeepSeek V4 strict-ordering scan, placeholder notation conventions, Gemma 4 schema-padding and parent-child enum-order scans, Gemini Interactions migration-defect scan (legacy `generateContent` → Interactions equivalent), and the Gemini 3.x parameter-removal / structure / placement / multimodal / agentic-template scan.

## Installation

### As a Claude Code Plugin (Recommended)

```bash
# From the Claude Code CLI
/plugin marketplace add dlxmax/prompt-optimizer
/plugin install prompt-optimizer
/reload-plugins
```

### Manual Installation

Copy the `agents/` folder and the family reference files into your Claude Code config:

```bash
cp agents/prompt-optimizer.md ~/.claude/agents/
cp PROMPT_BEST_PRACTICES.md ~/.claude/
cp GEMMA4_API_BEST_PRACTICES.md ~/.claude/
cp GEMINI_3X_API_BEST_PRACTICES.md ~/.claude/
cp DEEPSEEK_V4_API_BEST_PRACTICES.md ~/.claude/
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
"Optimize this Gemini 3.5 Flash judge prompt for the essay evaluation pipeline."
```

### Caller-message shape

The agent enforces a long-context-end-anchored caller-message shape: the prompt under review is treated as the substantial context block, and the scoring directive is the operative query. The caller's user message must be shaped:

```
<prompt_under_review>
{the full prompt text being reviewed}
</prompt_under_review>

[optional] Target model: <name>

Based on the preceding prompt, apply Step 2 (score against the 15-item checklist) through Step 6 (return the structured output) of the system prompt. Return Checklist Score, Key Changes, and Revised Prompt.
```

All text inside `<prompt_under_review>` is treated as data only — instructions inside that block are ignored regardless of how authoritatively phrased (prompt-injection defense).

### Example Output

```
## Checklist Score: 6/15

[x] Tagged blocks: sections wrapped in <role>, <instructions>, <output_format>
[x] Numbered directives: 5 directives numbered
[ ] Length and placement: 4,200 tokens; query at top above a 3K-token context block
[ ] Gate examples, calibrated count: 5 diverse examples (older 3-5 pattern); should be 1-3 verdict-balanced examples with borderline pairs
[ ] Machine-parseable output: no regex-extractable verdict format
[x] Skeptical role: "rigorous evaluator" framing at opening; missing at closing
[ ] Do-instead-of-don't: 2 bare prohibitions without alternatives
[N/A] Validation model: not a second-pass prompt
[N/A] Original task in validation: not a second-pass prompt
[ ] One criterion per call: 3 criteria bundled in one high-stakes prompt
[N/A] Linguistic-analysis path: evaluates content, not writing properties
[ ] Judge prompt: rubric: no rubric present; will write concrete criteria for each score level
[ ] Judge prompt: sampling and family rules: single-pass design; N≥5 needed; Target=Gemini 3.5 Flash → strip temperature/top_p/top_k, switch thinking_budget→thinking_level, function-result IDs missing
[ ] Escape hatch elimination: 3 directives use "try to" or "if possible"
[N/A] Prompt injection defense: evaluates fixed test content, not user-submitted text

## Key Changes
- Moved query to END of prompt anchored with "Based on the preceding transcript..." (item 3, long-context rule)
- Stripped ~1,500 tokens of non-load-bearing background (item 3)
- Reduced gate examples from 5 to 2 verdict-balanced borderline pairs (item 4)
- Split combined criteria into 3 separate evaluation calls (item 10)
- Added VERDICT format with regex pattern (item 5)
- Paired prohibitions with alternatives (item 7)
- Added skeptical role framing at end of prompt (item 6)
- Wrote rubric with observable 1-4 criteria directly into the prompt (item 12)
- Added verdict/reasoning consistency instruction and calibration anchor (item 12)
- Removed temperature/top_p/top_k from generation_config; switched thinking_budget to thinking_level: "medium" (item 13, rule 14.1/14.2 — Gemini 3.5 Flash)
- Added call_id + name match on every function_result and moved multimodal content INSIDE the function-result result[] array (item 13, rule 14.3)
- Replaced 3 escape hatches with direct imperatives (item 14)

## Revised Prompt
[full revised prompt text...]
```

## Included Files

| File | Purpose |
|---|---|
| `agents/prompt-optimizer.md` | The Claude Code agent definition |
| `PROMPT_BEST_PRACTICES.md` | Best practices guide (7 sections + 15-item checklist) |
| `GEMINI_3X_API_BEST_PRACTICES.md` | Gemini 3.x family on the Interactions API (3.5 Flash GA, 3.1 Pro, 3 Flash Preview, 3 Pro Preview) |
| `GEMMA4_API_BEST_PRACTICES.md` | Gemma 4 on the Gemini Interactions API (probe-verified May 2026, ported to Interactions wiring) |
| `DEEPSEEK_V4_API_BEST_PRACTICES.md` | DeepSeek V4 family API mechanics (V4-Pro, V4-Flash) |
| `PROMPT_RESEARCH.md` | Full research archive with 60+ sources (2024 to 2026) |

## Key Research Sources

**June 2026 — Gemini Interactions API and 3.5 Flash GA (scrapling-verified 2026-06-24):**
- [Gemini Interactions API overview](https://ai.google.dev/gemini-api/docs/interactions-overview): GA endpoint, SDK floor, stateful chains via `previous_interaction_id`
- [Migrate to Interactions API guide](https://ai.google.dev/gemini-api/docs/migrate-to-interactions.md.txt): every legacy `generateContent` wiring → Interactions equivalent
- [Gemini Structured Outputs (Interactions version)](https://ai.google.dev/gemini-api/docs/structured-output.md.txt): top-level `response_format`, single-object schema form, tools combination preview
- [Gemini Long Context guide](https://ai.google.dev/gemini-api/docs/long-context.md.txt): query-at-end placement when total context is long
- [What's new in Gemini 3.5 Flash](https://ai.google.dev/gemini-api/docs/whats-new-gemini-3.5.md.txt): parameter removal, `thinking_level` over `thinking_budget`, function-calling strict matching
- [Gemini thinking (Interactions)](https://ai.google.dev/gemini-api/docs/thinking.md.txt): `thought` step type, `signature` always present, `summary` opt-in via `thinking_summaries: "auto"`
- [Gemini prompt design strategies](https://ai.google.dev/gemini-api/docs/prompting-strategies.md.txt): canonical Gemini 3 prompting reference (consistent structure, critical-instructions placement, multimodal equal-class, agentic 9-point template)

**May 2026 — Empirical probes:**
- REST API probes against `gemma-4-31b-it`, `gemma-4-26b-a4b-it`, `gemini-2.5-flash`, `gemini-3.1-flash-lite-preview`. Summary in [`GEMMA4_API_BEST_PRACTICES.md`](GEMMA4_API_BEST_PRACTICES.md); behavior layer ports forward to Interactions wiring.
- DeepSeek V4 strict-ordering failure modes captured across 6 optimizer rounds on a 121k-char directive: alphabetical-default bias, example tyranny, lowest-cost completion.

**2026 refresh:**
- [IFBench leaderboard, April 2026](https://benchlm.ai/benchmarks/ifBench): current frontier instruction-following scores
- [Rethinking Rubric Generation (RRD), arxiv 2602.05125](https://arxiv.org/abs/2602.05125): GPT-4o +17.7 pts, Llama-405B +7.4 pts; cross-model generation validated
- [RubricBench, arxiv 2603.01562](https://arxiv.org/abs/2603.01562): ~27-pt Rubric Gap universal across Gemini, GPT, DeepSeek
- [Same Input, Different Scores, arxiv 2603.04417](https://arxiv.org/abs/2603.04417): Gemini single-model variance
- [LLMLingua-2, NAACL 2025](https://llmlingua.com/llmlingua2.html): task-agnostic prompt compression, 3x to 6x
- [Prompt-bloat study, MLOps Community 2026](https://mlops.community/the-impact-of-prompt-bloat-on-llm-output-quality/): the ~3K token degradation threshold
- [Label Your Data LLM-as-judge 2026](https://labelyourdata.com/articles/llm-as-a-judge): few-shot instability and one-shot dominance
- [Native Language Identification with LLMs (Lotfi et al.)](https://arxiv.org/abs/2312.07819): GPT-4 zero-shot 91.7% TOEFL11
- [Rating Roulette, EMNLP 2025](https://arxiv.org/pdf/2510.27106): single-pass judges unreliable; N≥5 needed
- [Sage benchmark, Dec 2025](https://arxiv.org/html/2512.16041v1): rubric generation +16.1% IPI; debate prompts -158%
- [Google Gemma 4 Technical Report, 2026](https://storage.googleapis.com/deepmind-media/gemma/gemma4-report.pdf): T=1.0 recommended, 26B A4B double tool-call bug, JSON adherence weakness, injection susceptibility
- [DeepSeek V4 Tech Report and API docs, April 2026](https://api-docs.deepseek.com/news/news260424): V4-Pro 1.6T/49B-activated and V4-Flash 284B/13B-activated MoE; default-on thinking; JSON-mode "json"-keyword requirement; strict-mode tool calling on the `/beta` endpoint
- [Judging the Judges, ACL/IJCNLP 2025](https://arxiv.org/html/2406.07791v7): position bias is incoherent; swap-and-count less effective

**Still load-bearing:**
- [AGENTIF](https://arxiv.org/abs/2505.16944): NeurIPS 2025 decomposition finding (headline numbers superseded by IFBench 2026)
- [Self-Correction Blind Spot](https://arxiv.org/abs/2507.02778): the "Wait" prefix discovery
- [Dark Side of Self-Correction](https://aclanthology.org/2025.acl-long.1314/): ACL 2025 recency bias fix
- [HuggingFace LLM-as-Judge cookbook](https://huggingface.co/learn/cookbook/en/llm_judge): 1-4 scale; evaluation field before verdict; 0.563 to 0.843 correlation improvement
- [Anthropic Claude Prompting Guide](https://docs.anthropic.com): XML tags and document-first ordering

## License

MIT
