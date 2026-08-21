# Writing a workflow command

The 19 files in `templates/.claude/commands/` are the product's moving parts. Each
one is read by an agent working in somebody else's repository, with no author
present to clarify it. This page is the shape they share, and the bar a new one
clears before it ships.

It governs `templates/.claude/commands/` only. Conventions for generated *app
code* are one rule per file in `templates/docs/rules/`; this is about the commands
themselves. `bin/lint-docs` checks the mechanical half of what follows, so run it
before you commit.

## What a command is

A markdown instruction file, not an executable. Claude Code and Cursor surface it
as `/name`; a tool with no slash-command concept reads and follows the file
directly. That fallback is the constraint behind most of the rules here: the file
has to make sense to an agent that was simply handed it, and to a human with
`grep`.

The mirror to `.cursor/commands/` happens at generation time from these same
files. There is one source. Never edit a copy.

## Frontmatter

```yaml
---
description: "Plan one issue: task file, implementation plan, then a branch"
argument-hint: "<issue number>"
---
```

- **`description` is required.** It is what a human reads in a picker while
  deciding whether to run the command, so it states the job in one line, under 80
  characters. No trigger phrasing ("use when the user wants…"): that is written
  for a model choosing autonomously, and these commands are typed by a person.
- **`argument-hint` is required wherever the body reads `$ARGUMENTS`**, and is
  worth adding whenever an argument is meaningful. Say what to pass and whether
  it is optional: `"<PR number>"`, `"[issue number, defaults to the branch]"`.
- **Quote both values.** `description: Entry door: prioritized work` parses as a
  map, and `argument-hint: [issue number, optional]` parses as a list. Either way
  the value reaches the tool as the wrong type.

## Shape

Two shapes are sanctioned. Pick by size, not by taste.

| Shape | When | Sections |
|---|---|---|
| **Long-form** | Anything with more than a couple of steps (over ~60 lines) | `# Title`, job line, `## Instructions` with `### Step N`, `## Reference` |
| **Short-form** | A single action, or a thread the numbered list carries on its own (the `segue` set, `run_lint`) | `# Title`, job line, a numbered list or one fenced command |

### The job line

The line under the H1, before any heading. One sentence naming the job, then how
to invoke it:

> Plan one issue's implementation: explore, task file, human approval, branch.
> Planning only, execution is `/implement`. Pass the issue number:
> `/task_plan 1613`.

Three things earn their place there: what it does, what it is *not* (the sibling
command that does the adjacent thing), and the invocation with a real argument.
The invocation has to name **this** command; two commands once documented
themselves under names nobody could type, and `bin/lint-docs` checks for it now.

### `### Step N`

Numbered, in execution order, imperative. A step that needs a shell command shows
the command in a fenced block rather than describing it. A step with a branch
gives the branch as a table or a list, never a paragraph the agent has to parse
for its own case.

### `## Reference`

The closing block of facts the steps referred to: repo tokens, path conventions,
sizing budgets, what to suggest when a tool fails. It exists so the steps stay
readable and the constants live in one place.

## Conventions

- **Address the agent, not a character.** "Take the pasted failure output, find
  the root cause, fix it" beats "You = elite Rails 8 test failure triage system".
  A persona line spends tokens on flattery and moves behaviour less than naming
  the actual job, the actual files, and the actual checks. Where a genuine stance
  is load-bearing ("review as the person who will be paged at 3am"), state it in
  the step that needs it.
- **One fact, one file.** A command never restates a convention from
  `docs/rules/`. It links the rule (`docs/rules/testing.md`) and moves on. Two
  copies of a convention drift, and the copy inside a command is the one nobody
  re-reads.
- **Only the doc canon.** Commands read and write `docs/rules/`, `docs/plans/`,
  `docs/system/`, `docs/sop/`, `docs/qa/`, and `.llm/`. Do not invent a
  directory; the names are load-bearing because other commands read them.
- **Every path resolves.** A path that names a real shipped file must be correct
  to the character. A path the command *creates* carries a placeholder
  (`<id>`, `YYYY-MM-DD`) or, if it is a literal, a `<!-- lint-docs:ignore -->`
  marker on the line, so the checker can tell the two apart.
- **Only tokens the wizard fills.** Every `{{TOKEN}}` in a command must be one
  `/workflow_setup` collects. An unfilled token ships to a generated app as
  literal braces.
- **Name the next command, and know the ceiling.** A command ends by naming what
  runs next, in backticks, so the chain self-navigates. It is the *human* who
  types it: a command cannot invoke another command. Write "next: `/pr_submit`",
  never phrasing that implies the command will do it for you.
- **Plain markdown only.** No harness-specific loading, no feature only one tool
  supports. The routing has to work in Claude Code, Cursor, Codex, and a `grep`.
- **Keep the tracker tiers straight.** A command that touches the tracker follows
  only the branch matching the literal `{{TRACKER}}` value, and says so where the
  behaviour splits.

## Done when

Machine-checked by `bin/lint-docs`:

- Frontmatter parses, and every value is a string.
- `description` exists, is under 80 characters, and opens with the job rather than
  trigger phrasing.
- `argument-hint` is present if the body reads `$ARGUMENTS`.
- The file opens with an H1.
- A file over 60 lines carries `## Instructions` and `## Reference`.
- Every backticked `/name` in the file is a real command.
- Every path-shaped `.md` reference resolves under `templates/`, or is marked.
- Every `{{TOKEN}}` used is one `/workflow_setup` fills.
- The command appears in `templates/AGENTS.md` and `templates/WORKFLOW.md`.

Checked by reading, because no script can:

- The job line says what the command does, what it is not, and how to invoke it,
  with this command's own name.
- Steps are in execution order, and a step that runs something shows the command.
- No persona preamble.
- No convention restated that `docs/rules/` already owns.
- Branches are tables or lists, not paragraphs.
- The command names what runs next, without implying it invokes it.
- `## Reference` holds the constants, and nothing the steps needed inline.
