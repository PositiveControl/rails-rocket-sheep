# The generator repo tracks its own copy of the alignment layer

## Context

This repo has used its own workflow since the commands existed: `/pick`,
`/task_plan`, `/implement`, `/pr_submit`. The copies at the root were installed
from `templates/` and kept out of git through `.git/info/exclude`. The reasoning
was that the source is `templates/`, and a second tracked copy is a second fact.

Autopilot ended that arrangement. `bin/autopilot` runs a feature in a worktree
beside the developer's checkout, and a worktree has tracked files only. The driver
reads the design doc, the autopilot log, `.claude/workflow.config.md`, the
settings that wire its guard, the allowlist and `bin/gates` from there. It
commits the log under `docs/plans/`, which git refuses for an excluded path. Every
step runs the commands from the worktree's `.claude/commands/`. Excluded, none of
that exists, and preflight refuses to start.

The driver also assumes a Rails app. It spawns `bin/dev`, re-runs `bin/test` after
a conflict, and its commands call `bin/rubocop`, `bin/brakeman` and `bin/rails`.

## Decision

**The root copy of the alignment layer is tracked, and it is output.**

- These are committed at the root: `.claude/` (commands, settings, workflow
  config, allowlist), `.cursor/commands/`, `bin/gates`, `bin/hooks/`,
  `bin/autopilot`, `WORKFLOW.md`, `.llm/`, `docs/plans/`, `docs/qa/` and the PR
  template.
- `bin/dogfood-sync` renders them from `templates/` with the token values in
  `.claude/workflow.config.md`. Nobody edits a root copy. A change goes into
  `templates/`, and the sync's output is committed with it.
- Stand-ins fill the binstubs a Rails app would have:
  - `bin/test` runs this repo's real checks.
  - `bin/dev` waits to be stopped.
  - `bin/rubocop`, `bin/brakeman` and `bin/rails` report n/a.
- The worktree is made with `git worktree add`, because `--setup` would run
  `bundle install` and `db:prepare`.

## Consequences

- Autopilot runs here, so the template's driver is exercised on the template's
  own features before any buyer's.
- The root shows a second copy of the layer. A reader browsing the repo can
  mistake `.claude/commands/` for the source. The `CLAUDE.md` *Dogfood layer*
  section and this ADR say otherwise, and the sync keeps the two from drifting.
- A stale root copy cannot reach `main`. CI runs the sync on every PR into
  `main` and fails on any diff (`.github/workflows/dogfood.yml`, added in #72).
  PRs into `feature/*` are not checked, because an autopilot step cannot sync:
  a feature branch may run behind `templates/` until the developer syncs it
  after the run, and the feature PR is where a missed sync turns red.
- The hooks are live in every interactive session here, not only on autopilot.
  `SKIP_DRAFT_CHECK=1` in `.claude/settings.local.json` is the opt-out for the
  Stop hook while a feature's drafts sit on `main`.
- **A slice that changes the wiring's source can't run on autopilot.** The
  guard's wiring rule matches `bin/autopilot`, `bin/hooks/`,
  `.claude/settings*.json` and the allowlist anywhere in a path, so it also
  matches `templates/`. Such a slice is done by hand.
- The stand-ins mean a step's "rubocop clean" and "brakeman clean" say nothing
  here. Generation in CI (`bin/smoke-generate`) is still the check for anything a
  generated app runs.

## Rejected

- **Keep the layer excluded and copy it into each worktree.** The driver's log
  commits fail on an excluded path, and every run would start with a hand copy.
- **Teach `bin/autopilot` to run without Rails** (skip the bundle, the database
  and `bin/dev` when they are missing; read the suite command from the config).
  That is a product change made for one repo's sake, and stand-ins do the same at
  no cost to the product. Revisit if an adopter on another stack asks.
- **Track the layer on the feature branch only.** It would need a hand strip
  before every feature PR, for every feature.
- **Anchor the guard's wiring rule to the project root** so the wiring's source
  could be edited by a step. That loosens the wall, since `templates/../bin/…` and
  `cd`-relative paths become evasions to reason about. A slice by hand costs less.
