# Prompt Optimizer Agent

A Claude Code agent that scores and revises LLM prompts against a research-backed checklist.

**Topics:** `gemini` · `gemini-3.5` · `gemini-3.5-flash` · `gemini-3.x` · `interactions-api` · `gemma-4` · `gemma` · `claude` · `deepseek` · `deepseek-v4` · `response-schema` · `structured-output` · `rubric` · `llm-judge` · `prompt-engineering` · `prompts` · `agents` · `sycophancy` · `validation` · `compliance` · `best-practices`

**Primary focus: mitigating known failure modes on `Gemini 3.x` (including 3.5 Flash GA) via the Gemini Interactions API, `Gemma 4 31b` via the same API, and `DeepSeek V4` (V4-Pro, V4-Flash) via the DeepSeek API.** The agent also targets Claude. The 15-item checklist is model-agnostic; model-specific rules kick in when a `Target model:` is declared.

The two goals are: prompts the model actually executes instead of silently skipping over directives, and call mechanics that do not waste retry budget on failures the schema or parser already explains.

**Primary workflow:** Use this agent inside Claude Code to optimize prompts for any LLM. The optimizer runs on Claude; when it writes a rubric for a judge prompt, Claude is authoring the rubric and the target model applies it (cross-model rubric generation, which tends to equal or outperform same-model self-generation). Model-specific guidance is baked into the checklist and applied when a `Target model:` is declared.

## Failure modes the optimizer mitigates

### Gemini 3.x / 3.5 Flash (Interactions API)

Five rules the optimizer scans for. Full mechanics in [`GEMINI_3X_API_BEST_PRACTICES.md`](GEMINI_3X_API_BEST_PRACTICES.md).

- **Remove `temperature`, `top_p`, `top_k`.** The defaults are tuned; setting these on Gemini 3.x can cause looping or degraded performance. To force determinism, write the system instruction with explicit rules instead.
- **Replace `thinking_budget` (numeric) with `thinking_level` (`minimal` / `low` / `medium` / `high`).** 3.5 Flash defaults to `medium` (down from `high` on 3 Flash Preview). `thinking_level` and `thinking_budget` are mutually exclusive — passing both returns HTTP 400.
- **Long-context query placement.** Substantial context blocks come first; the user's specific query goes at the END, anchored with "Based on the preceding information...". Burying the query at the top is a defect on long-context prompts.
- **Critical-instructions placement.** Persona, behavioral constraints, and output format requirements live in the `system_instruction` parameter OR at the very beginning of the user prompt — not buried after long context or examples.
- **Consistent structure (XML XOR Markdown).** Use XML-style tags OR Markdown headings as section delimiters; do not mix both styles within the same prompt.

The optimizer also flags multimodal prompts that fail to reference each modality explicitly, and recommends porting Google's published 9-point agentic planning template into the system instruction when the prompt drives an agentic workflow.

### Gemma 4 31b (Interactions API)

Three highest-ROI fixes the optimizer scans for. Full mechanics and thresholds in [`GEMMA4_API_BEST_PRACTICES.md`](GEMMA4_API_BEST_PRACTICES.md).

- **Thinking is always on; only `response_format` suppresses it.** Without it, every call pays the always-on thinking cost (visible as `thought` steps in `interaction.steps[]`) and runs far slower with a non-zero `MALFORMED_RESPONSE` rate. The documented levers (`thinking_level: "off"`, `thinking_budget: 0`) return HTTP 400 on Gemma 4; setting `response_format` to a JSON schema is the only mechanism that works.
- **Property order in the schema controls emission order.** Gemma 4 emits an object's properties in the order they appear in the schema. Put `reasoning` before `verdict` to force reason-before-commit; the reverse lets the verdict lock first and inflates the justification. Narrow schemas only — with ≥4 mandatory nested objects, adding a top-level reasoning string crashes `31b`, so move the reasoning surface to prompt prose or a separate call.
- **Parse with `raw_decode`, not `json.loads`.** Even with `response_format`, Gemma 4 occasionally appends trailing text after valid JSON; `json.loads` raises on it, while `json.JSONDecoder().raw_decode()` returns the first valid object and ignores the rest.

### DeepSeek V4 (V4-Pro / V4-Flash)

Three rules the optimizer scans for. Full mechanics in [`DEEPSEEK_V4_API_BEST_PRACTICES.md`](DEEPSEEK_V4_API_BEST_PRACTICES.md).

- **JSON-mode "json"-keyword anchor and example block.** When the deployer uses `response_format={"type": "json_object"}`, the system or user message must contain the literal word "json" AND a concrete EXAMPLE INPUT + EXAMPLE JSON OUTPUT block. Absence causes the model to emit unbounded whitespace to `max_tokens`, presenting as a hang. V4 has no `responseSchema` analogue; the prompt is the only schema-enforcement surface.
- **Strict-ordering failure modes.** V4 emits multi-element sequences in alphabetical order regardless of lookup tables (alphabetical-default bias), copies concrete example values verbatim across distinct instances (example tyranny), and defaults to minimum-cost completion on length-bounded fields and closed-set whitelists. The optimizer surfaces these patterns and recommends the matching prose mitigation.
- **Schema-intervention anti-pattern.** V4 silently drops schema-level constraints (property order, required-field bindings, enum constraints). The optimizer refuses to recommend schema-restructure fixes on V4 targets and routes all behavioral steering through prose: directive text, EXAMPLE INPUT + EXAMPLE JSON OUTPUT, concrete rubric language.

### Migration-defect scanning (rule 13)

The agent flags appearances of retired Gemini wiring as migration defects: `client.models.generate_content(...)`, `:generateContent` / `:streamGenerateContent` endpoints, `generationConfig.responseSchema`, `contents: [{role, parts: [...]}]`, `systemInstruction.parts[].text`, `response.candidates[0].content.parts`, `parts[].thought` filtering, object-keyed tools arrays (`{googleSearchRetrieval: {}}`), and caller-managed history re-sends. Each defect is paired with its Interactions API equivalent in Key Changes.

## The Problem

Most LLM prompts are written by feel. Frontier models in 2026 do not refuse tasks, they silently omit them. Here's where it shows up:

- **Frontier models still drop a large share of multi-constraint directives** on novel out-of-domain instructions. Structural prompt design closes the gap.
- **Reasoning quality degrades past a few thousand tokens** even on models with 256K to 1M context windows. Focused prompts beat long ones regardless of available context.
- **Long-context query placement matters.** When the total context is long, put the user's query at the END after the data, anchored with "Based on the preceding information...".
- **Naive "check your work" validation flips most initially correct answers wrong.** Self-correction needs structure, not a blanket re-check.
- **One-shot often beats few-shot** for LLM-as-judge tasks. The old "3 to 5 diverse examples" rule is retired; use 1 to 3 verdict-balanced examples per criterion, all score levels for scale rubrics, PASS+FAIL for binary criteria, with borderline pairs preferred over obvious contrasts.
- **Naming the linguistic features to attend to sharply improves native-language identification.** Linguistic analysis prompts need their own playbook.
- **Meaningful sycophancy reduction is achievable through prompt structure alone**, no fine-tuning required.
- **A concrete rubric is the single highest-return change for judge prompts.** Self-generated rubrics leave a large, consistent gap to human-quality rubrics across Gemini, GPT, and DeepSeek.
- **All frontier judges are unreliable on a single pass.** High-stakes judge calls need N≥5 majority vote for consistency; the high-ROI accuracy levers are rubric quality and structured reasoning. Debate-style prompts are actively harmful. Multi-model consensus is the strongest deployment lever.
- **Three model families need their own playbooks:** Gemini 3.x via Interactions ([`GEMINI_3X_API_BEST_PRACTICES.md`](GEMINI_3X_API_BEST_PRACTICES.md)), Gemma 4 via Interactions ([`GEMMA4_API_BEST_PRACTICES.md`](GEMMA4_API_BEST_PRACTICES.md)), and DeepSeek V4 ([`DEEPSEEK_V4_API_BEST_PRACTICES.md`](DEEPSEEK_V4_API_BEST_PRACTICES.md)).

## Multi-Model Workflow

This optimizer runs on Claude and targets any LLM. Declare `Target model: <name>` in your call to activate model-specific checklist notes.

**Universal (all targets):** The optimizer writes a concrete rubric directly into the revised judge prompt (cross-model rubric generation: Claude authors, target applies), which tends to equal or outperform same-model self-generation. The `<rubric_generation>` instruction block is the fallback only when the criterion must adapt per-input at runtime.

**Gemini 3.x (`Target model: Gemini 3.5 Flash` / `Gemini 3.1 Pro` / `Gemini 3 Flash Preview` / `Gemini 3.x`).** Surface: Interactions API only; `:generateContent` is retired for the optimizer's recommendations. Strip `temperature` / `top_p` / `top_k`; use `thinking_level` instead of `thinking_budget`; place query at end of long context; pick XML XOR Markdown for section delimiters; place critical instructions in `system_instruction` or at the very beginning of the user prompt; reference each modality explicitly. 3.5 Flash is the recommended Computer Use model (3 Flash Preview is a supported preview alternative); image segmentation is not supported anywhere in 3.x (use Gemini 2.5 Flash with thinking off or Gemini Robotics-ER 1.6).

**Gemma 4 (`Target model: Gemma 4`).** Surface: Gemini Interactions API (`v1beta/interactions`, `client.interactions.create(...)`, `google-genai >= 2.3.0`). The checklist applies `response_format` as the deployment lever (suppresses always-on thinking, fixes JSON structure, ~30 to 40x speedup), property-ordered properties for reason-before-commit, `raw_decode` for parsing, retry classification, and the schema-padding / parent-child enum-order rules. Both `gemma-4-31b-it` and `gemma-4-26b-a4b-it` are covered; rule 2 isolates the multi-STRING failure mode unique to `26b-a4b`, and the tool-calling bug is captured for the same variant. Use `31b` when both are options. Gemma 4 still uses T=1.0, top_p=0.95, top_k=64 (NOT the Gemini 3.x parameter-removal rule).

**DeepSeek V4 (`Target model: DeepSeek V4`).** Default-on thinking mode; JSON-mode "json"-keyword and example-block requirement; strict-mode tool calling on the `/beta` endpoint; the Anthropic-compatible endpoint capability subset; the schema-intervention refusal list. All behavioral steering routes through prose, not schema.

**Claude (`Target model: Claude Sonnet 4.6` / `Claude Opus 4.7` / `Claude Opus 4.8`).** XML tags and document-first ordering per Anthropic official guidance. Second-pass validation needs the "Wait" prefix and original-task anchor. Extended thinking is already embedded; do not add an extra reasoning pass.

## What This Agent Does

When invoked, the prompt-optimizer agent:

1. Reads the prompt under review (caller-message shape enforced: `<prompt_under_review>` block first, scoring directive at the end anchored with "Based on the preceding prompt, ...")
2. Scores against the **15-item checklist** (embedded; the agent file is self-contained, no file I/O needed for scoring)
3. For each declared `Target model:`, loads the matching family reference: [`GEMINI_3X_API_BEST_PRACTICES.md`](GEMINI_3X_API_BEST_PRACTICES.md), [`GEMMA4_API_BEST_PRACTICES.md`](GEMMA4_API_BEST_PRACTICES.md), or [`DEEPSEEK_V4_API_BEST_PRACTICES.md`](DEEPSEEK_V4_API_BEST_PRACTICES.md). Bare reviews and Claude-targeted reviews load no family file.
4. Returns a **revised version** with every violation fixed and annotated

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

Beyond the checklist, the agent file carries universal numbered rules covering: count-vs-universal consistency, placeholder notation conventions, the Gemini Interactions migration-defect scan (legacy `generateContent` → Interactions equivalent), structured-output schema review, tie-break direction, and uncertainty deferral. Family-specific scans (Gemma 4 schema-shape and recall rules, DeepSeek V4 strict-ordering, Gemini 3.x parameter/structure rules) live in the loaded family files, not the agent file.

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
cp GEMMA4_API_BEST_PRACTICES.md ~/.claude/
cp GEMINI_3X_API_BEST_PRACTICES.md ~/.claude/
cp DEEPSEEK_V4_API_BEST_PRACTICES.md ~/.claude/
```

### Auto-Invocation (Optional)

Add an entry to your agent-invocation rules so Claude reaches for the optimizer automatically whenever prompt work comes up. On the common rules layout, add this under `## Immediate Agent Usage` in `~/.claude/rules/common/agents.md`, continuing the existing numbering:

```
5. Writing or revising an LLM prompt - Use **prompt-optimizer** agent
```

Adjust the path, heading, and number to match wherever your setup lists agent-invocation triggers.

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
| `agents/prompt-optimizer.md` | The Claude Code agent definition: universal 15-item checklist, scoring rubric, compaction rules |
| `GEMINI_3X_API_BEST_PRACTICES.md` | Gemini 3.x family on the Interactions API (3.5 Flash GA, 3.1 Pro, 3 Flash Preview) |
| `GEMMA4_API_BEST_PRACTICES.md` | Gemma 4 on the Gemini Interactions API (probe-verified May 2026, ported to Interactions wiring) |
| `DEEPSEEK_V4_API_BEST_PRACTICES.md` | DeepSeek V4 family API mechanics (V4-Pro, V4-Flash) |

## License

MIT
