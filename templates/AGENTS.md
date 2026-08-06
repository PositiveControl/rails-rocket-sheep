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
| Slash commands driving the workflow | `.claude/commands/` |
| Index of committed documentation | `.llm/README.md` |
| Design docs · architecture · procedures · QA guides | `docs/plans` · `docs/system` · `docs/sop` · `docs/qa` |

## The short version

- Run `bin/test` before you claim anything works
- `bin/rubocop` and `bin/brakeman` must be clean
- Business logic goes in service objects (`ApplicationService`), not controllers
- Slim templates, never ERB, in application views
- Tests come first; fix flaky tests immediately rather than skipping them
- Update `docs/` when behaviour changes, and `grep` for an existing doc first

The full reasoning behind each of these, with worked examples of the right and
wrong version, is in `CLAUDE.md`.
