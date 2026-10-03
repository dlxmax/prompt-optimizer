# Prompt Optimizer

I'm a teacher. I built this to check and fix the AI prompts I use for grading,
feedback, and lesson materials. It works inside Claude Code. I'm sharing it with
other educators who do the same.

## What it does

You give it a prompt you use with an AI model (or a rubric you want turned into
one). It tells you what's wrong and how to fix it.

It helps with:

- **Grading prompts.** Stops the AI from inventing quotes, or mixing up criteria by grading them all at once.
- **Feedback comments.** Stops empty praise ("Great job!") and comments about things the student never wrote.
- **Lesson materials.** Worksheets, warm-ups, exam questions, lesson plans that come out generic or repetitive.
- **Any other prompt**, on request.

It knows the quirks of Claude, Gemini, Gemma 4, and DeepSeek V4.

It's a strict reviewer, not a cheerleader. It only reads; it never changes your
files. You decide what to use.

## Install

In Claude Code:

```
/plugin marketplace add dlxmax/prompt-optimizer
/plugin install prompt-optimizer
/reload-plugins
```

To update later: `/plugin marketplace update prompt-optimizer`, then
`/reload-plugins`.

## Use

Ask Claude Code in plain words, for example:

- "Our essay-grading prompt invents quotes. Fix it."
- "Here's my rubric. Set up the grading prompts."
- "My feedback comments all sound the same. Check this prompt."
- "My warm-up question generator keeps giving generic questions. Review it."

Or call the agent yourself (`prompt-optimizer:prompt-optimizer`). Put the prompt
first and your question last:

```
<prompt_under_review>
(paste your prompt here)
</prompt_under_review>

Target model: Gemini 3.8 Flash

Based on the preceding prompt, find what's wrong and fix it.
```

The `Target model` line is optional, but it gets you advice for that model.

## What you get back

- What kind of job it thinks this is.
- A checklist: each item passes or fails, with the reason.
- Fixes for what failed, or a full set of prompts if you asked it to build from a rubric.
- Choices that change students' grades (like which way to break a tie) are left for you to make. It won't decide those for you.

## Keeping it cheap

- **Paste the prompt text** rather than pointing it at a file.
- **Follow-up questions within 5 minutes** are cheap. After that, or with a revised prompt, start a fresh request.

## More

How it works under the hood, which file covers what, and the details for each
AI model: [docs/DETAILS.md](docs/DETAILS.md).

## License

MIT
