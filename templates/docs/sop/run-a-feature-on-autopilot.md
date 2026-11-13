# Run a feature on autopilot

**Status:** Complete

How to run an approved multi-slice feature with nobody at the keyboard. What the
driver does and why: `docs/system/autopilot.md`. The decision:
[ADR 0016](../adr/0016-an-accepted-design-may-run-itself.md).

## Before the first run

1. **Consent.** The feature's design doc has `**Autopilot:** on — log: <path>`,
   and the log exists with *Policy accepted at G1*. `/feature_plan` writes both
   when you say yes at G1. For a design already past G1, ask `/feature_plan` for a
   **G1 amendment**. Either way the line lands on `feature/<slug>`: a fresh G1
   commits the design doc and log there in `/feature_plan` Step 7, and an
   amendment commits and pushes the line there. Nothing has to reach `main`
   before a run; the driver reads consent in its worktree on that branch.
2. **The feature branch and its draft PR exist.** `/feature_plan` Step 7 makes
   them at G1. For a feature approved before that step existed, `/task_plan`
   makes them for the first slice, or create the branch and draft PR by hand as
   its Step 6 fallback does.
3. **The guard is wired.** `.claude/settings.json` has
   `bin/hooks/autopilot_guard` under `PreToolUse`. A generated app has it, and
   preflight refuses to start a run without it. An app that adopted the template
   gets it from `bin/rocket-sheep-update`. If its own `settings.json` had
   diverged, the update leaves conflict markers there to resolve.
4. **The workflow config is committed.** The driver reads the repo, branch
   prefix, tier and board IDs from `.claude/workflow.config.md`, which
   `/workflow_setup` writes. Commit it, so the worktree has it too; preflight
   names any value it is missing. An app whose default branch is not `main`
   adds a `DEFAULT_BRANCH` row; without one the driver merges `origin/main`.
5. **The `autopilot` label exists** (tiers `labels` and `github-projects`). Splits
   and filed issues carry it:

   ```bash
   gh label create autopilot --repo <org>/<repo> --force
   ```

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

   This makes `../<repo>-autopilot-<slug>` on `autopilot/<slug>/worktree`, a branch of the
   driver's own cut from `origin/feature/<slug>` and never pushed, runs
   `bundle install`, and prepares `*_autopilot` databases: development with its
   seeds (walkthroughs sign in as the seeded accounts), test with the schema only.
   The run's server starts with `SOLID_QUEUE_SKIP_RECURRING=true`, so a
   development schedule that calls outside services never runs. A fetch that
   fails stops setup, and git and ssh never wait on the terminal for a login:
   they fail instead. If you set your own ssh for git (`GIT_SSH_COMMAND`,
   `GIT_SSH` or `core.sshCommand`), the driver leaves it as it is, and it may
   still ask. Run it again any time; it only does what is missing. From a terminal it ends by opening a shell in
   the worktree; `exit` returns you to the old one.

   `feature/<slug>` can stay checked out wherever you have it: the driver never
   checks out the local branch, and changes the feature branch only detached on
   its remote copy. The finish deletes `autopilot/<slug>/worktree` with the worktree.

   **Seeds that cannot build a usable database** (they need data git does not
   carry) can be replaced by a copy of yours: define a `db:autopilot:clone` task
   in `lib/tasks/autopilot.rake` that copies your development database into
   `<name>_development_autopilot` and empties its job queue (in development the
   queue lives in the same database, so your pending and failed jobs would come
   with it). When that file exists and the run's development database does not,
   `--setup` runs the task, without `DB_SUFFIX`, before `db:prepare`, which then
   only migrates it. Run the task yourself to refresh the copy. If setup then
   leaves `db/schema.rb` modified in the worktree, your database's schema
   differs from `main`'s (tables from branches whose migrations you ran); run
   `git checkout -- db/schema.rb` in the worktree, since preflight refuses a
   dirty tree.
8. **Your model and effort, optional, once per developer.** A step loads the
   repo's settings only, so your effort and attribution settings don't reach it.
   Its model is the one you last picked with `/model`, in any session, so
   switching it during a run changes the run's model. The team's defaults, if it
   has set any, are in the committed `.claude/autopilot.json` (`model`, `effort`,
   `steps`; it ships empty). To pin your own over them, put
   `.claude/autopilot.local.json` in your main checkout (git-ignored; any checkout
   or worktree of the repo reads it from there):

   ```json
   {
     "model": "sonnet",
     "effort": "medium",
     "steps": {
       "task_plan": { "model": "opus", "effort": "high" },
       "pr_review": { "model": "opus", "effort": "high" }
     }
   }
   ```

   The top-level `model` and `effort` are every step's default; `steps` gives
   any command the driver runs as a step its own (`task_plan`, `implement`,
   `pr_review` and the rest; preflight lists them if a name is wrong), here the
   plan and the review on Opus and the rest on Sonnet. Each step is a new
   session, so its model is set once, when it starts. Every key is optional; a
   missing one is the team file's, then Claude Code's default. Yours wins over the
   team's a key at a time, inside a command's entry too: your `effort` for
   `task_plan` keeps the team's `model` for it. `--model` and `--effort` win over
   both files for one run. The dry run prints the default and each command that
   differs from it, and every step's model and effort.
   With `--resolver resume`, the resolver continues `implement`'s session, so it
   runs on `implement`'s model and effort; its own entry applies when it starts
   fresh.
   The attribution setting covers what Claude Code adds itself; the footer
   `/pr_submit`'s PR template writes stays.
   An optional `env` holds environment variables (names to text) the driver sets
   for every command it runs, its own and every step's, from setup on.

## Start a run

```bash
bin/autopilot <slug> --dry-run   # each open slice's steps in run order, then the command to start
bin/autopilot <slug>
```

Each prints a line per command or step as it starts and its time when it ends.
Add `--verbose` to see every command's output as it runs, and the dry run's full
commands.

Run it from any checkout of the repo, the worktree setup opened included: the
driver finds the main checkout and the worktree itself.

To choose the model and effort the steps run on, see step 8 of *Before the first run*.

`/pr_comment_resolver` runs in a new session that starts from a handoff file the
driver writes (`tmp/autopilot/handoff-<issue>.md`). `--resolver resume` (with either
line) resumes `/implement`'s session instead, at several times the cost. Use it if a
fresh resolver starts missing context the author had. `--usage` lists
`/pr_comment_resolver (fresh)` and `(resume)` separately. Judge by review pass 2 and
halts as well as cost: a cheaper resolver that misses fixes is not cheaper.

Preflight names every problem at once. Fix them and rerun:
- missing consent or log
- a dirty tree in the worktree, unless it is on the next slice's branch
- no feature PR
- `gh auth status` signed out, or, on the board tier, a token without the
  `project` scope (`gh auth refresh -h github.com -s project`)
- a `.claude/autopilot.local.json` or `.claude/autopilot.json` that is not
  JSON, has a key or a command it does not take, or holds a model, effort or
  attribution a step cannot use (the team's file takes `model`, `effort` and
  `steps` only)
- no `claude` on `PATH`
- red `bin/gates`
- the guard not wired in `.claude/settings.json`

A run goes until the feature is finished, or until something needs you. For each
slice it plans, implements, submits, reviews and lands it into `feature/<slug>`,
then picks the next. It starts `bin/dev` on port 3100 for walkthroughs (web mode) and stops
it when it ends. Each step is told the server is up, with `QA_AUTO` and `QA_HEADLESS`
set, so a step runs its walkthrough instead of leaving it for you.

Leave the Mac awake for a long run: `caffeinate -i bin/autopilot <slug>`.

## Watch it

- **`bin/autopilot-tail [slug]`** follows the run live: each step's
  session as it starts, and its subagents, one line per tool call, result and
  message, labelled by step (`/implement 48`). A step prints nothing to the
  driver until it ends; this reads the transcripts Claude Code writes as it goes.
  `--all` replays the run so far.
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
capture count toward cost only. It ends with the run's summary: usage and tokens
in total and per 1,000 added lines and per 1,000 SLOC (added lines less blanks,
comments and prose), time in steps, in waits and elapsed, and each
model's usage, tokens and cost per million tokens. To compare two features'
runs, or one feature on two models, compare these.

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
- **The worktree** may hold the step's uncommitted work. On the next slice's
  branch, the next run keeps it: `/implement` starts from `git status` and
  carries on from there. Don't want it? Discard it with
  `git -C ../<repo>-autopilot-<slug> checkout -- .` before you rerun. A dirty
  tree on any other branch is refused.
- **The state file** has no row for the step you stopped. Its usage is not
  counted in the log's metrics.

Then pick one:
- **Carry on:** rerun `bin/autopilot <slug>`. Every step finished so far is
  skipped, and the step you stopped runs again from a new session.
- **Stop for good:** for each open slice, close its slice PR and put the slice
  back to Todo. Remove the worktree (`git worktree remove
  ../<repo>-autopilot-<slug>`) and its branch (`git branch -D
  autopilot/<slug>/worktree`, never pushed), and drop the `*_autopilot`
  databases if you want the space. The feature PR, the merged slices and the log stay. The feature
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
- the worktree is removed (`git worktree remove`; one git refuses, with
  modified or untracked files, is left and named), and the `*_autopilot`
  databases are dropped unless another `../<repo>-autopilot-*` worktree still
  uses them: every feature shares them. The next feature's setup
  prepares them again.

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

Rerunning a finished feature does nothing: with its worktree gone, preflight
says to run `--setup`, and after that the run says it is finished and exits `0`. The driver
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
- ***QA — how to check the whole feature*** is your checklist: every
  walkthrough the feature touched, in order, as the finish ran them together
  (each slice ran only its own), then every slice's *Not checked by a human*
  items in one list. A failed walkthrough is also in *Read this first*.
- ***Policy accepted at G1*** is the policy this run answered under, whatever
  the system doc says today.
- ***Slices***, one section per slice in merge order. Each has a header row
  (lines added, files, review rounds, fixes, drops, wall time, usage) and then
  every decision the steps took, by gate id. Each entry gives the options, the
  choice and why, its trade-off, how reversible it is, and its evidence.
- ***Halts and pauses*** has every stop and what answered it.
- ***Metrics*** opens with the run's summary, then one row per step: wall time,
  usage, retries, pauses, and the model and effort it ran on. Rows
  for the driver's own waits sit beside them: the CI wait before each merge, and
  `bin/test` after a conflict. A step with retries is one where its expectation
  failed once. Each attempt is in the worktree's `tmp/autopilot/<slug>.json`
  under its issue's `usage`, with what was missing (`failure`) and its session
  id. `claude --resume <session id>` in the worktree opens the session to see
  why.

A decision you disagree with is a change like any other: an issue, or a fix on
the feature branch before you merge it.
