# Prompt Optimizer

I'm a teacher. My scripts send prompts to AI models through their APIs to grade
work, write feedback, and build lesson materials. This Claude Code agent checks
and fixes those prompts. I'm sharing it with educators who do the same.

## What it does

It reviews a prompt your script sends to an AI model, or builds one from a
rubric, and returns what's wrong and how to fix it:

- **Grading prompts.** Stops the AI from inventing quotes, or mixing up criteria by grading them all at once.
- **Feedback comments.** Stops empty praise ("Great job!") and comments about things the student never wrote.
- **Lesson materials.** Worksheets, warm-ups, exam questions, and lesson plans that come out generic or repetitive.
- **Any other prompt**, on request.

It knows the quirks of Claude (Opus 5.5 and Sonnet 5.5, in API calls and in
Claude Code agents), Gemini, Gemma 4, and DeepSeek V4. It only reads; it never
changes your files.

## Install

In Claude Code:

```
/plugin marketplace add dlxmax/prompt-optimizer
/plugin install prompt-optimizer
/reload-plugins
```

To update later: `/plugin marketplace update prompt-optimizer` (it reloads
plugins itself).

## Use

You don't call it yourself. Tell Claude Code which prompt, what's going wrong,
and which model the script calls:

> Show the grading prompt in `grade.py` to the prompt optimizer agent. It keeps inventing quotes. We're calling Gemini 3.5 Flash-Lite.

Claude sends the prompt to the agent, applies the fixes, and shows you what
changed.

Every report ends with three lines Claude acts on:

- **Input**: what the request was missing (like which model the script calls) or sent that wasn't needed, so the next request is better.
- **Recheck**: the fixes changed the prompt's structure, so the revised version should go back for a second look.
- **Compaction**: the prompt carries dead weight (rules stated twice, rules for things that no longer exist, patches stacked on patches) and should be trimmed.

When both apply, they happen in one call.

Choices that change students' grades, like which way to break a tie, come back
to you. It won't decide those.

## Cost

Each review costs tokens. The agent runs on Sonnet at high effort, about half
Opus's price, and reads only itself and the prompt you send, not your other Claude Code settings. Claude skips rechecks
when the fixes were only wording.

## More

How it works, which file covers what, and the details for each AI model:
[docs/DETAILS.md](docs/DETAILS.md).

## License

MIT
