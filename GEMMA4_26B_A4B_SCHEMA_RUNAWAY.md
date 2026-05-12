# Gemma 4 26b-a4b: runaway STRING fields under `responseSchema`

Companion note to `GEMMA4_FIXES.md`. Verified 2026-05-12 against the same
Generative Language REST API endpoint with `responseMimeType:
"application/json"` and `responseSchema` set.

## Failure mode

`gemma-4-26b-a4b-it` enters a deterministic token loop inside unbounded
free-text STRING fields when a `responseSchema` is attached. The structural
fields render correctly: `INTEGER`s are valid, `STRING`s with `enum`
constraints emit only declared values, MM:SS-shaped strings hold their
format. The model breaks the moment it enters a STRING field that has no
`enum` or length constraint AND that the prompt does not externally bound
("notes is one sentence in normal English").

The loop reuses a small bigram or trigram from the late preceding context
(in our segmentation probe: `-style-transition-style-transition-...`) and
fills the entire `maxOutputTokens` budget. `finishReason` returns
`MAX_TOKENS`, never `STOP`.

The same prompt without `responseSchema` does not exhibit this loop on the
same model. The loop is schema-coupled.

## Empirical data

Probe scripts:
- `/tmp/probe_segmentation_schema.py` — original STRING-shape baseline
- `/tmp/probe_segmentation_array_notes.py` — option (b) stage 1, ARRAY on `notes` only
- `/tmp/probe_segmentation_array_all.py` — option (b) stage 2, ARRAY on all three unbounded STRINGs

Diagnostic dumps:
- `/tmp/probe_26ba4b_raw.txt`
- `/tmp/probe_array_notes_result.txt`
- `/tmp/probe_array_all_result.txt`

Segmentation schema: top-level `ARRAY[OBJECT]` with 8 required fields per
OBJECT (1 INTEGER, 2 MM:SS-bounded STRINGs, 2 enum-bounded STRINGs, 3
unbounded free-text STRINGs in the original shape).

| Model | Schema shape | Cap | Wall | Output chars | finishReason | Schema-valid |
|---|---|---|---|---|---|---|
| gemma-4-31b-it | STRING notes | 2048 | 9.2 s | 1,061 | STOP | yes |
| gemma-4-26b-a4b-it | STRING notes | 2048 | 44.6 s | 6,084 | MAX_TOKENS | no, truncated mid-string |
| gemma-4-26b-a4b-it | STRING notes | 8192 | 174.3 s | 34,562 | MAX_TOKENS | no, runaway token loop in `notes` field |
| gemma-4-26b-a4b-it | STRING notes (re-probe) | 2048 | 21.2 s | 7 | STOP | no, degenerate `" [] ```"` |
| gemma-4-26b-a4b-it | ARRAY[STRING] notes #1 | 2048 | 52.1 s | 14,788 | MAX_TOKENS | no, `-classification-classification-...` loop in another STRING field |
| gemma-4-26b-a4b-it | ARRAY[STRING] notes #2 | 2048 | 68.5 s | 2,346 | MAX_TOKENS | no, `0.0.0.0.0...` loop in another STRING field |
| gemma-4-31b-it | ARRAY[STRING] notes (control) | 2048 | 10.0 s | 1,115 | STOP | yes |
| gemma-4-26b-a4b-it | ALL-ARRAY[STRING] #1 | 2048 | 0.9 s | — | — | no, HTTP 500 INTERNAL |
| gemma-4-26b-a4b-it | ALL-ARRAY[STRING] #2 | 2048 | 19.7 s | 7 | STOP | no, degenerate `" [] ```"` |
| gemma-4-31b-it | ALL-ARRAY[STRING] (control) | 2048 | 10.1 s | 1,126 | STOP | yes |

The original STRING-shape baseline produced both runaway-loop and
degenerate-empty failure modes on 26b-a4b across the 2026-05-12 probe set,
so the failure mode is not deterministic in shape but is deterministic in
outcome: no schema-valid output. Wrapping the long STRING field as
`ARRAY[STRING]` moved the loop into a sibling unbounded STRING field;
wrapping all three failed differently (500 / empty array). 31b passed
every shape tested.

## Implications for prompt design on Gemma 4

When targeting 26b-a4b alongside 31b in a single fallback chain:

1. **Do not attach `responseSchema` to calls that route to 26b-a4b.** The
   caller must either skip the schema on this model or remove 26b-a4b
   from the route. In `make_materials.py:_call_gemini`, the schema is
   dropped on a model-name match for `26b-a4b` (commit 4c7a...). Other
   call sites that bypass `_call_gemini` need the same guard.

2. **Schema-attached prompts that target 26b-a4b directly must bound
   every free-text STRING.** Empirically verified workarounds on this
   model:
   - **(a) Prompt-level bounding plus a worked stop-example.** Bound
     each unbounded STRING field in the prompt ("one short sentence")
     and show the stop point with an inline example. This is what the
     31b path uses for `notes`; 31b self-terminates without the bound,
     26b-a4b does not.
   - **(c) Caller-side schema-skip on 26b-a4b.** Drop `responseSchema`
     and `responseMimeType` on the request when the model name matches
     `26b-a4b`. The model then emits free-form JSON inside the prompt's
     own format scaffold, which it terminates correctly.
   - **(b) ARRAY-of-STRING wrap on the long STRING field — DOES NOT
     RESCUE THIS SHAPE.** Probed 2026-05-12 in two stages. Stage 1:
     converting `notes` alone from STRING to `ARRAY[STRING]` with
     `minItems=1, maxItems=2` did not help; the runaway loop simply
     migrated to whichever unbounded STRING the model reached first
     (`instructor_cue` or `discussion_prompt`), filling 2,346 and
     14,788 chars before `MAX_TOKENS`. Stage 2: converting ALL THREE
     unbounded STRING fields to `ARRAY[STRING]` with `minItems=1,
     maxItems=1` also failed (one HTTP 500, one degenerate `" [] ```"`
     output). 31b control passed both arms cleanly. Schemas with
     multiple unbounded STRING properties per OBJECT cannot be rescued
     by per-field ARRAY wrapping on 26b-a4b.

3. **Validation prompts that emit `audit` arrays with a single `reason`
   STRING field have not exhibited this loop on 26b-a4b in production**
   despite sharing the unbounded-STRING shape. The operative
   distinction, given the stage-1/stage-2 results above, appears to be
   **the number of unbounded STRINGs per OBJECT**, not whether STRINGs
   sit inside ARRAY wrappers. One unbounded STRING per OBJECT inside a
   top-level ARRAY[OBJECT] container is the only ARRAY-shaped pattern
   that has survived on 26b-a4b. The five validation prompts at
   `/home/ubuntu/courses/ISE-1/make_materials.py:1251` onward fit this
   shape and have not regressed under the schema description-string
   upgrade applied 2026-05-12.

4. **For the prompt-optimizer agent specifically**: when reviewing a
   Gemma-facing prompt that targets the 31b+26b-a4b fallback chain AND
   that exposes any free-text STRING field:
   - If the OBJECT has **more than one** unbounded STRING property, do
     not recommend ARRAY-wrapping as the fix. Require option (a) or
     option (c).
   - If the OBJECT has **exactly one** unbounded STRING property inside
     a top-level ARRAY[OBJECT] container, that shape has held in
     production; still recommend option (a) prompt-level bounding as
     defense in depth.
   - Do not assume parity with 31b on STRING-heavy schemas. STRING-heavy
     means two or more unbounded STRING properties per OBJECT.

## Implications for the API layer

`_call_gemini` at `/home/ubuntu/courses/ISE-1/make_materials.py:783`
already returns `MalformedResponseError` on `finishReason != STOP`,
which catches this case. The current retry loop in `_call_llm`
steps temperature down 1.0 → 0.85 → 0.75 on MALFORMED. Probe shows
the loop is deterministic and not temperature-driven; temp step-down
does not break the loop on 26b-a4b. The schema-skip guard at call time
is the only fix that works; the retry policy is a defense-in-depth
backstop for genuine partial outputs on 31b (which the probe never
produced).

## Probe to reproduce

```
/usr/bin/python3 /tmp/probe_segmentation_schema.py
```

Reads `~/.../make_handout/yt_ZBtMbBPzqHY.timestamped.txt`, posts a
2-segment request against both 31b and 26b-a4b with the segmentation
`responseSchema`, prints status / finishReason / wall / parse / field
checks per model.
