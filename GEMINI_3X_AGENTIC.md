# Gemini 3.x tools and agentic prompts

<role>
Reference for prompt-optimizer, loaded by `GEMINI_3X_API_BEST_PRACTICES.md` for a prompt with tools, a multi-step agent, or a planning block. Rule numbers continue that file; rules 1 and 8 live there. Apply every numbered rule.
</role>

## 5. Reduce tool-call overuse, two levers in order

5.1. **Lower the thinking level** (mechanics: rule 1). Higher levels encourage tool use for exploration and verification. The floor is per-model and not always available: confirm the target's allowed set before naming `minimal` or any level outside low/medium/high (those three are valid on every 3.x model, never flagged) (`GEMINI_MIGRATION.md` 4). A config shared across models (fallback chain, router) sets the level per leg or uses one valid on every leg: a bottom level valid on the primary can 400 the fallback exactly when it is needed.
5.2. **System instruction bounding tool calls**: "You have a limited action budget of {tool_call_budget} tool calls. Use them efficiently." Substitute the real number before emitting; never emit the literal `{tool_call_budget}`. Pair the cap with an under-budget path: budget exhausted and the answer still unsupported -> report the gap, never fall back to parametric memory. A cap with no stated way out converts a grounding task into a guessing task at the boundary.

Rule 6's persistence dimension pulls against both levers; 6c arbitrates.

## 6. Agentic workflows: the 9-point planning template, added sparingly

Prompt drives an agentic workflow (model reasons, plans, executes across tool
calls) → 9-point system-instruction template: (1) logical dependencies and
constraints, (2) risk assessment, (3) abductive reasoning and hypothesis
exploration, (4) outcome evaluation and adaptability, (5) information
availability, (6) precision and grounding, (7) completeness, (8) persistence
and patience, (9) inhibit-response gate.

**Default: port none of it.** Scaffolding is a cost paid on every call
(`GENERIC_REVIEW.md` rule 12). A nine-directive planning block bought a
capability older models lacked. Vendor-stated for all 3.x: prompt engineering
built for older models drives over-analysis (rule 3). Vendor-stated for
`gemini-3.8-flash` only: it by design takes smaller reasoning steps, calls tools
iteratively, and verifies its own work, so a ported block duplicates that
behavior outright. Earlier 3.x strings carry no such statement; there the
default rests on rule 3 and the triangulation below.
Order of moves on a failing agentic run: run an 8.3 bench and keep the winning level
(mechanics: rule 1); still failing → port by the split below.
A run failing by token burn or verification loops rather than wrong actions is
rule 5's lever, never a ported block.
Inhibit-response gate (9) last whenever any dimension is ported.

**One prompt, several generations** (fallback chain, router, staged rollout):
the port decision is per target string. A dimension ported against a failure
named on one model reaches another only after that failure reproduces there.
Shared text carries no ported dimension; a per-model addition carries it.

**Managed-agent target** (a prebuilt agent harness rather than a bare model):
the harness already plans and executes, and the deployer's system instruction
and the environment's instruction file are additive, both applied. Port none by
default. Any ported policy lives in exactly one of the two; stated in both, it
applies twice.

**Port policy, never reasoning.** A dimension carrying external policy the model
cannot infer from the task earns its tokens. A dimension describing how to reason
duplicates native thinking and competes with it.

6.1. Port: (2) risk assessment, which tool calls mutate state versus read; (5) information availability, what counts as unknown rather than inferable; (9) inhibit-response gate, when to stop and ask. Add (6) precision and grounding where exact-string or type fidelity matters, and (8) persistence only to set a retry limit.
6.2. Omit: (1) logical dependencies, (3) abductive reasoning, (4) outcome evaluation, (7) completeness. Written into the prompt they buy verbosity, not planning.

Triangulated, not probed: the vendor scopes the template's evaluation to
complex-rulebook plus user-interaction agents, which is the policy class. That
is not a benchmark. Re-test before trusting the omit list on a new deployment.

**Hurt case, named.** Read-only exploratory agents (codebase search, database
triage): risk assessment plus the inhibit gate reclassify benign reads as
permission-worthy and the agent stops to ask instead of paging, while
completeness has no end-state to satisfy on an open-ended search and drives
keyword-variation loops. Read-only high-throughput work → port none.

**The dimensions govern reasoning, not output.** The block is completed in the
model's thinking. Emit it only where a human or a log consumes the plan, and
then by 6e's ladder, never as a tagged block.

**Adapt, never paste.** Vendor frames it as an example to fit to the use case,
tuning a stated cost-versus-accuracy trade-off. Four dimensions invert when
ported as a bare label:

6a. (6) is a quote-grounding directive, not a tone word: verify each claim by
quoting the exact applicable source or policy. Emit the clause, never the label.
6b. (7) scopes to the PLAN, every requirement and constraint exhaustively
incorporated into it. Ported as output exhaustiveness it becomes a quota and
manufactures findings (`GENERIC_REVIEW.md` item 5).
6c. (8) "do not give up until the reasoning is exhausted" costs tokens and risks
loops, vendor-stated, and pulls against rule 5. Say which governs this
deployment; never emit both unarbitrated. Persistence binds the reasoning, never
the abstention path: reasoning exhausted with no support found is a completed
task, not a failure to push through.
6d. (5) resolves missing information by consulting the user. No user in a batch
or scoring pipeline -> substitute the fixed abstention literal, else the model
assumes instead of asking.

6e. **No structured text immediately before a tool call.** A directive to emit a
tagged or serialized block (`<UPDATE>`, a JSON or YAML object) as the turn's
first output and then call a tool intermittently corrupts the call into a
malformed-function-call error. The 9-point block is the common source: it is
completed BEFORE any tool call. Three fixes in order: move the notes into a
declared `update` function the model calls first, so the notes call and the real
call leave in one step; demote the block to Markdown headers (`# PLAN`); drop the
pre-tool text requirement. Markdown headers here override rule 3's
single-delimiter choice, for these note blocks only. Vendor-stated for the whole
Gemini 3 series. The failure is intermittent: a clean dry run does not clear a
prompt of it.

## Verify after changes

1. No planning block ported without a named failure and a `thinking_level` step-up tried first; none on a managed-agent target by default, and no ported policy duplicated across system instruction and instruction file; no ported dimension in text shared across model strings; ported dimensions are policy-carrying (2, 5, 9), never reasoning-describing (1, 3, 4, 7); each emitted as a clause rather than a label and arbitrated against rule 5 (6, 6a-6d).
2. No tagged or serialized block is required immediately before a tool call; pre-tool notes route to a declared `update` call or to Markdown headers (6e).
