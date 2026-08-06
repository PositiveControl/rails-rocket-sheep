# Agent Instructions

**The conventions for this repository live in [`CLAUDE.md`](CLAUDE.md). Read it before making any change.**

This file exists so tools that look for `AGENTS.md` find their way there. It is a
pointer, not a second source — conventions are single-sourced in `CLAUDE.md`, and
anything restated here would drift.

## Orientation

| What | Where |
|---|---|
| Coding conventions, patterns, anti-patterns | `CLAUDE.md` |
| Development lifecycle, gates, sizing rules | `WORKFLOW.md` |
| Workflow commands | `.claude/commands/` (mirrored to `.cursor/commands/`) |
| Index of committed documentation | `.llm/README.md` |
| Design docs · architecture · procedures · QA guides | `docs/plans` · `docs/system` · `docs/sop` · `docs/qa` |

## Commands

These are markdown instruction files, not executables. Tools with a slash-command
concept (Claude Code, Cursor) surface them as `/name`. **If yours doesn't, read
and follow the file directly** — e.g. "follow `.claude/commands/pr_submit.md`".

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
- Slim templates, never ERB, in application views
- Tests come first; fix flaky tests immediately rather than skipping them
- Update `docs/` when behaviour changes, and `grep` for an existing doc first

The full reasoning behind each of these, with worked examples of the right and
wrong version, is in `CLAUDE.md`.
