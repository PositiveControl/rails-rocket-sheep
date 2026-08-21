# Agent Instructions

**Start with [`CLAUDE.md`](CLAUDE.md) — the stack, the non-negotiables, and how to
find the rule that applies. Read it before making any change.**

Individual conventions are one rule per file in
[`docs/rules/`](docs/rules/INDEX.md). `CLAUDE.md` names each rule in a line and
links to it; the rule file carries the reasoning, the worked example, and the
"when not to."

This file exists so tools that look for `AGENTS.md` find their way there. It is a
pointer, not a second source — anything restated here would drift.

## Orientation

| What | Where |
|---|---|
| Coding conventions, patterns, anti-patterns | `CLAUDE.md` |
| Individual rules, one per file — **read the index, then only what applies** | `docs/rules/INDEX.md` |
| Development lifecycle, gates, sizing rules | `WORKFLOW.md` |
| Workflow commands | `.claude/commands/` (mirrored to `.cursor/commands/`) |
| Index of committed documentation | `.llm/README.md` |
| Design docs · architecture · procedures · QA guides | `docs/plans` · `docs/system` · `docs/sop` · `docs/qa` |

## Commands

These are markdown instruction files, not executables. Tools with a slash-command
concept (Claude Code, Cursor) surface them as `/name`. **If yours doesn't, read
and follow the file directly** — e.g. "follow `.claude/commands/pr_submit.md`".

Each one opens with frontmatter carrying a one-line `description`, and an
`argument-hint` if it takes an argument. That is enough to choose a command
without opening it, whether a picker renders it for you or you `head` the file.

The chain is self-navigating: each command ends by naming the next.

```
/pick (entry) → /feature_plan → /task_plan → /implement → /pr_submit → human merge
```

| Command | Job |
|---|---|
| `pick` | Entry door. Surfaces ready work and routes it by shape and state |
| `feature_plan` | Explore → design doc → sized sub-issues + doc placeholders |
| `task_plan` | Design doc → task file + implementation plan → branch |
| `implement` | Idempotent resume: load task file, execute, commit per logical unit |
| `pr_submit` | Local suite → docs resolved → PR → review comments |
| `pr_review` | Reviewer side: full-context diff review |
| `pr_qa` | Guided manual QA pass, structured report |
| `rails_code_review` | Rails-specific review against this stack's conventions |
| `update_docs` | Deep doc pass; keeps the index honest |
| `segue`, `segue_resume`, `segue_close`, `segue_merge`, `segue_kill` | Isolated discussion thread with findings-only merge-back |
| `pr_comment_resolver` | Work through review comments |
| `pr_fix_ci` | Diagnose and fix a failing CI run |
| `test_fix` | Fix failing tests |
| `run_lint` | Lint and auto-fix |
| `workflow_setup` | One-time wizard: repo, board, naming, CI checks |

Run `workflow_setup` once before first use.

## The short version

- Run `bin/test` before you claim anything works
- `bin/rubocop` and `bin/brakeman` must be clean
- Business logic goes in service objects (`ApplicationService`), not controllers
- Multi-model forms go in form objects (`ApplicationForm`), never `accepts_nested_attributes_for`
- Markup with logic or variants goes in a ViewComponent with a test; partials declare strict locals
- Controllers stay RESTful — seven actions, a new verb gets a new controller
- Validation failures render with `status: :unprocessable_content`, or Turbo silently drops the response
- Slim templates, never ERB, in application views
- Tests come first; fix flaky tests immediately rather than skipping them
- Update `docs/` when behaviour changes, and `grep` for an existing doc first

The full reasoning behind each of these, with worked examples of the right and
wrong version, is in the matching `docs/rules/` file.

## Finding a rule without reading everything

`docs/rules/` holds one convention per file. `docs/rules/INDEX.md` routes three ways:
by the path you are editing, by symptom, or by rule id (`docs/rules/<id>.md`). Each
rule file carries `applies_to` globs and `triggers` keywords in its frontmatter, so
`grep -l "<keyword>" docs/rules/*.md` also works.

**Read the index, then only the rules it points you to.** Reading the whole
directory is a mistake, not diligence.
