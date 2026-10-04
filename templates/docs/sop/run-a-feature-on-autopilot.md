# Run a feature on autopilot

**Status:** Complete

How to run an approved multi-slice feature with nobody at the keyboard. What the
driver does and why: `docs/system/autopilot.md`. The decision:
[ADR 0016](../adr/0016-an-accepted-design-may-run-itself.md).

## Before the first run

1. **Consent.** The feature's design doc has `**Autopilot:** on — log: <path>`,
   and the log exists with *Policy accepted at G1*. `/feature_plan` writes both
   when you say yes at G1. For a design already past G1, ask `/feature_plan` for a
   **G1 amendment**. Either way the line has to reach `main` (fresh G1: a
   small PR with the design doc and log, merged before the first slice is
   planned) or `feature/<slug>` (amendment: `/feature_plan` commits and pushes it
   there) before a run.
2. **The feature branch and its draft PR exist.** `/task_plan` makes them for the
   first slice. If no slice has been planned yet, plan the first one by hand, or
   create the branch and draft PR as `/task_plan` Step 6 does.
3. **The guard is wired.** `.claude/settings.json` has
   `cd "$CLAUDE_PROJECT_DIR" && bin/hooks/autopilot_guard` under `PreToolUse`, or
   the bare `bin/hooks/autopilot_guard` of settings from before the `cd`. Either
   counts, but only the first survives a session that leaves the root. A
   generated app has it, and preflight refuses to start a run without it. An
   app that adopted the template gets it from `bin/rocket-sheep-update`. If its
   own `settings.json` had diverged, the update leaves conflict markers there to
   resolve.
4. **The workflow config is committed.** The driver reads the repo, branch
   prefix, tier and board IDs from `.claude/workflow.config.md`, which
   `/workflow_setup` writes. Commit it, so the worktree has it too; preflight
   names any value it is missing.
5. **The `autopilot` label exists** (tiers `labels` and `github-projects`). Splits
   and filed issues carry it, and `/workflow_setup` creates it. Check:

   ```bash
   gh label list --repo <org>/<repo> --search autopilot
   ```

   Nothing listed means the setup ran before it did that. Create it with
   `gh label create autopilot --repo <org>/<repo> --force`.

6. **`DB_SUFFIX` in `config/database.yml`.** A generated app has it. Adoption and
   updates install only the alignment layer and never touch `config/`, so an
   app that adopted the workflow adds it by hand: append `<%= ENV["DB_SUFFIX"] %>` to every
   development and test database name.

   ```yaml
   development:
     database: myapp_development<%= ENV["DB_SUFFIX"] %>
   test:
     database: myapp_test<%= ENV["DB_SUFFIX"] %>
   ```

   Unset, nothing changes. The driver sets `DB_SUFFIX=_autopilot`, so a run never
   touches your own databases.
7. **Set up the worktree, once per feature:**

   ```bash
   bin/autopilot <slug> --setup
   ```

   This makes `../<repo>-autopilot-<slug>` on `feature/<slug>`, runs
   `bundle install`, and prepares `*_autopilot` databases: development with its
   seeds (walkthroughs sign in as the seeded accounts), test with the schema only.
   Run it again any time; it only does what is missing.

   If `git worktree add` fails with *already checked out*, another worktree has
   `feature/<slug>` checked out. Switch that one to another branch first.

## Start a run

```bash
bin/autopilot <slug> --dry-run   # preflight, the next slice, the exact commands
bin/autopilot <slug>
```

`/pr_comment_resolver` runs in a new session that starts from a handoff file the
driver writes (`tmp/autopilot/handoff-<issue>.md`). `--resolver resume` (with either
line) resumes `/implement`'s session instead, at several times the cost. Use it if a
fresh resolver starts missing context the author had. `--usage` lists
`/pr_comment_resolver (fresh)` and `(resume)` separately. Judge by review pass 2 and
halts as well as cost: a cheaper resolver that misses fixes is not cheaper.

Preflight names every problem at once. Fix them and rerun:
- missing consent or log
- a dirty tree in the worktree
- no feature PR
- `gh auth status` signed out
- no `claude` on `PATH`
- red `bin/gates`
- the guard not wired in `.claude/settings.json`

A run goes until the feature is finished, or until something needs you. For each
slice it plans, implements, submits, reviews and lands it into `feature/<slug>`,
then picks the next. It starts `bin/dev` on port 3100 for walkthroughs (web mode) and stops
it when it ends.

Leave the Mac awake for a long run: `caffeinate -i bin/autopilot <slug>`.

## Watch it

- **The feature PR** gets a comment at every halt, pause, landed slice and the
  finish, plus a macOS notification. Its **Slices** list ticks as slices land.
- **The slice PR** carries the self-review passes as `Self-review pass <N>`
  reviews, and the resolver's replies.
- **The autopilot log** collects every decision the steps made, by gate id.
- `tmp/autopilot/<slug>.json` in the worktree holds the driver's own memory:
  authoring session, resolver done, pauses.

Don't comment on a slice PR while a run is going unless you mean to stop it. A
comment from a person halts the run (gate `comments`).

## After a halt

The run exits with status 2. The slice is Blocked on your tracker, and its HALT
entry is in the log, or on the issue (on the feature PR under `beads`).

1. Read the entry's **Needs** line, and answer it: decide, fix, or change the
   policy in the log.
2. Clear Blocked: remove `status:blocked` (`labels`), move the board Status off
   Blocked (`github-projects`), or `bd update <id> --status open` (`beads`).
   `docs/system/autopilot-steps.md`, *Tracker tiers*, has every operation.
3. Rerun `bin/autopilot <slug>`.

The rerun copies any HALT entries posted on issues into the log, gives the slice
its state back, skips every step that already finished, and carries on.

## After a pause

Nothing to do. When the subscription's usage limit stops a step, the driver
posts a notice, waits until the limit resets (or 30 minutes when it can't tell),
and reruns the step. After 12 pauses in a row it halts instead.

Each step's usage estimate is recorded. A slice is many full sessions, and they
come out of the same weekly allowance as your own work, so a run started at
night costs you the least.

`bin/autopilot <slug> --usage` summarises the state file per step: runs, cost,
average minutes, and the cache **hit** (cache reads over all input tokens). A low
hit on a step means it paid for a cold start. It only reads, so run it mid-run, after
a run, or before and after changing a step to compare. Rows from before token
capture count toward cost only.

## Abort

Press **Ctrl-C** once in the driver's terminal. The driver:
- stops the running step and everything it started (its whole process group)
- puts the worktree back on the branch it was on, if it was working on the
  feature branch
- stops `bin/dev`
- exits `130` with *Aborted*

It labels nothing and posts nothing.

What is left behind:
- **The slice's state** is as the step left it: usually In Progress, or Up for
  Review once its PR is open.
- **The worktree** may hold the step's uncommitted work. The next run's preflight
  refuses a dirty tree. Look at it with `git -C ../<repo>-autopilot-<slug> status`.
  Then commit it if it is sound, or `git stash` it if not.
- **The state file** has no row for the step you stopped. Its usage is not
  counted in the log's metrics.

Then pick one:
- **Carry on:** rerun `bin/autopilot <slug>`. Every step finished so far is
  skipped, and the step you stopped runs again from a new session.
- **Stop for good:** for each open slice, close its slice PR and put the slice
  back to Todo. Remove the worktree (`git worktree remove
  ../<repo>-autopilot-<slug>`) and drop the `*_autopilot` databases if you want
  the space. The feature PR, the merged slices and the log stay. The feature
  goes on by hand from there, with the log as its record.

Don't stop a run by killing `claude` processes one at a time. The driver reads
the dead step as a failure and retries it.

## When it finishes

The run exits `0` with *Finished: feature PR #<n> is ready for review*. By then:

- every slice is merged into `feature/<slug>` and ticked, with a `Closes` line
- `main` is merged into the feature branch
- the feature's Draft placeholders are completed or deleted
- the log is finished
- the feature PR is out of draft

Nothing has gone to `main`. That merge is yours.

1. **Read the log**, below, starting at *Read this first*.
2. **Walk the feature.** Use the log's *QA* section: the setup, the walkthrough
   scripts in order, the capture output, and every *Not checked by a human* item.
3. **Review the feature PR** as an acceptance-criteria walk over the design doc's
   slice list. Read the posted `Self-review pass` reviews, and spot-check where
   they disagree or say nothing. Re-reading the whole diff is not the job.
4. **Settle every `opinion` document** still marked `**Status:** Draft`. Confirm
   it or rewrite it; the feature PR must not merge it as a draft.
5. Merge to `main` when you are satisfied, or comment, fix, and land the fixes
   as you would any feature branch.

Rerunning a finished feature does nothing: it says so and exits `0`. The driver
reads "finished" from the feature PR being out of draft, so don't mark it ready
by hand while a run still has work to do. If you did, put it back with
`gh pr ready --undo <n>` and rerun.

## Reading the log

The log is `docs/plans/<date>-<slug>-autopilot.md`, named in the design doc's
`**Autopilot:**` line. Read it top down:

- ***Read this first*** is what you are most likely to want undone, hardest to
  undo first:
  - `one-way` entries and filed issues
  - `costly` entries
  - then dropped review findings, HALTs and `opinion` entries

  Each line names its entry (`D<issue>-<n>`), which you can search for.
- **`**Run:**`** is the span of the run and its total usage estimate.
- ***Policy accepted at G1*** is the policy this run answered under, whatever
  the system doc says today.
- ***Slices***, one section per slice in merge order. Each has a header row
  (lines added, files, review rounds, fixes, drops, wall time, usage) and then
  every decision the steps took, by gate id. Each entry gives the options, the
  choice and why, its trade-off, how reversible it is, and its evidence.
- ***Halts and pauses*** has every stop and what answered it.
- ***Metrics*** has one row per step: wall time, usage, retries, pauses. Rows
  for the driver's own waits sit beside them: the CI wait before each merge, and
  `bin/test` after a conflict. A step with retries is one where its expectation
  failed once. Each attempt is in the worktree's `tmp/autopilot/<slug>.json`
  under its issue's `usage`, with what was missing (`failure`) and its session
  id. `claude --resume <session id>` in the worktree opens the session to see
  why.

A decision you disagree with is a change like any other: an issue, or a fix on
the feature branch before you merge it.
