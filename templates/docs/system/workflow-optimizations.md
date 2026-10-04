# Workflow optimizations

This doc records the changes, measured in the app autopilot was ported from, that
cut context, tokens, cost and wall time in the agent workflow, and that let
autopilot runs survive interruptions. Each change has its own entry: the problem,
the mechanism, where it lives, and how to see its effect. It covers both
workflows: manual sessions running the commands by hand, and `bin/autopilot`
running them as `claude -p` steps.

To measure your own first autopilot feature the same way, fill in
[`autopilot-report-template.md`](../qa/autopilot-report-template.md).

## The order of the work

| # | Change | Lever |
|---|---|---|
| 1 | Steps write bodies to files | accuracy (fewer denied tool calls) |
| 2 | The driver records each step's tokens; `--usage` | measurement |
| 4 | Main-conversation cache TTL pinned to 1h | cost |
| 5 | Fresh resolver from a handoff file, now the default | context, cost |
| 6 | Leaner steps: split spec, activation stated once, narrower reads | context, cost |
| 7 | Full run metrics (time, turns, context, subagents, per model) | measurement |
| 8 | Retry failed `gh` reads; rerun a red CI run's failed jobs once | reliability |
| 9 | One local review round for a slice; pass 2 only on blockers or suggestions | cost, time |
| 10 | Pass 1 starts while CI runs | time |
| 11 | No local Rails suite when nothing the app loads changed | time |

Item 3 in the source app was a transcript reader for manual runs. It is not part
of the template, so the numbering skips it.

Measurement came first, so each later change could be judged by numbers rather
than by feel.

## 1. Bodies go through files, not heredocs

**Problem.** Autopilot steps run under `--permission-mode dontAsk` with an
allowlist. A `gh pr comment --body "$(cat <<EOF …)"` command does not match any
allowlist entry, so it is denied. The step then spends turns finding another way,
or ends without posting.

**Change.** Commands write a PR or comment body to a file and pass
`--body-file`. The step rules say so.

**Where.** `.claude/commands/*` (and the `.cursor/` mirror), and the driver's step
rules in `bin/autopilot`.

**Seen in.** The `denied` column of `bin/autopilot <slug> --usage`. Rows earlier
than item 7 did not record denials.

## 2. Measure first

**Problem.** There were no numbers per command, so a change to a command could not
be judged.

**Change.**
- **Driver state rows.** Each step's row in `tmp/autopilot/<slug>.json` records
  its dollars, seconds and tokens (input, output, cache read, and cache writes at
  5m and 1h).
- **`bin/autopilot <slug> --usage`** prints those rows grouped by step.

**Where.** `bin/autopilot` (`UsageReport`), and
[`workflow-usage.md`](workflow-usage.md).

## 4. Cache TTL pinned to 1h

**Problem.** A cache write expires after 5 minutes by default. Autopilot steps
often wait longer than that between calls: on `bin/gates`, on CI, on a long test
run. Every call after such a gap writes the whole context again.

**Change.** `"promptCacheTtl": "1h"` in `.claude/settings.json`. A 1h write costs
more per token than a 5m write, but an expired cache costs a full rewrite. On a
subscription within plan usage the main conversation already defaults to 1h, so
the setting makes that explicit and keeps it when usage credits apply.
Subagents stay at 5m.

**Where.** `.claude/settings.json`, and the *Cache TTL* section of
[`workflow-usage.md`](workflow-usage.md).

**Seen in.** `write 5m` is 0 on every step row since the change, and every write
lands in `write 1h`.

## 5. Fresh resolver from a handoff file

**Problem.** `/pr_comment_resolver` used `--resume` on `/implement`'s session. That
session's context was about 226k cached tokens, so every resolver call re-read it,
even to fix a one-line nitpick. On a 13-slice feature the resolver was 57% of each
slice's cost, and on average cost more than `/implement` itself.

**Change.** The resolver now starts a new session. The driver writes
`tmp/autopilot/handoff-<issue>.md` for it, holding:
- the slice, its PR and its base;
- the task file's path;
- how to see what changed (`git log`, `gh pr diff`);
- `/implement`'s closing summary;
- earlier resolver passes' summaries.

The new session reads only what a finding needs. `--resolver resume` keeps the old
behaviour, for comparison or as a fallback.

**Where.** `Run#resolve` and `Run#handoff` in `bin/autopilot`, and the *Driver*
section of [`autopilot.md`](autopilot.md).

**Seen in.** The `(fresh)` row of `--usage`, and the `variant` field on each
resolver row.

**Manual workflow.** The same split applies by hand. Run `/pr_comment_resolver` in
a new session rather than continuing the long `/implement` conversation; the PR,
the task file and the diff hold what it needs.

## 6. Leaner steps

**Problem.** A review of three slices' runs found three sources of repeated
context:
1. Every step read the whole autopilot spec, the largest tool result in
   `/task_plan` and `/implement`. Every later turn then re-read it from cache.
2. Every step ran the three-command activation check the driver had already done
   in preflight.
3. `/task_plan` read the whole design doc and the previous slice's task file.

**Change.**
1. **The spec is split in two.**
   [`autopilot-steps.md`](autopilot-steps.md) holds what a command needs while it
   runs as a step: *Activation*, *Policy*, the log, *Whose comment is it* and
   *Halt*. [`autopilot.md`](autopilot.md) keeps the driver, the guard and the log
   template. A step now loads about half the text.
2. **The driver states activation once.** `Step` appends the feature branch,
   design doc and log to every step's rules. The text is identical across a
   feature's steps, so it stays in the cached prefix. A step whose `<BASE>` is
   that branch skips the check.
3. **Narrower reads.** `/task_plan` reads the design doc's binding sections and
   the approach sections its slice touches, and does not read other issues' task
   files. `/implement` opens the design doc only for a question the task file
   does not answer.

**Where.** `bin/autopilot` (`Step#step_rules`), and `.claude/commands/task_plan.md`
and `implement.md` with their `.cursor/` mirrors. Items 1 and 3 also apply to
manual runs.

## 7. Full run metrics

**Problem.** Dollars and tokens alone did not show why a step was expensive.

**Change.** Each driver state row now also records:
- `api_seconds`;
- `turns`;
- `context_end`, the context at the last call (from the final `usage.iterations`
  entry);
- `subagents` and `denials`;
- `models`: per-model dollars and tokens, subagents included. `usage` covers the
  main conversation only, about 8% short on one measured `/implement`.

**Where.** `Step.metrics` and `UsageReport` in `bin/autopilot`, and *Autopilot
step rows* in [`workflow-usage.md`](workflow-usage.md).

## 8. Interruptions a run survives

| Interruption | Behaviour |
|---|---|
| Session limit reached | The driver records a pause, sleeps until the reset time printed in the message (30 minutes if it gives none), then runs the step again. The timer does not count time the Mac is asleep. |
| One failed `gh` read | Tried twice more, 5s then 15s later, before the driver treats it as unreadable. Writes go once. `gh pr checks` is not retried, since its non-zero exit for pending or red checks is an answer. |
| A red check at the merge gate | The driver waits for that Actions run to finish, reruns its failed jobs once (`gh run rerun --failed`), notifies, and logs a `CI rerun` row. Only a check still red after the rerun halts, so a flaky test does not stop the feature. |
| Ctrl-C, or a restart | Each step's expectation is checked against real state, so a rerun skips what already holds. For example, a restart after an interrupted `/task_plan` that had already written its task file goes straight to `/implement`. |

## 9. Fewer review rounds, where the evidence says so

**Problem.** Each slice ran four reviews: two local rounds inside `/implement` and
two passes on the PR. A tally over 13 slices showed two things. The second local round only re-found what pass 1 would catch, since pass
1 reads the whole diff. And the driver ran pass 2 whenever the resolver pushed
anything, although the rules already said nitpicks never trigger it.

**Change.**
- **`/implement` Step 5 runs one round when `<BASE>` is a feature branch.** A PR
  into `main` keeps two, because no agent pass follows it.
- **`/pr_review`'s summary carries a `**Findings:** <n> blocking, <n> suggestions,
  <n> nitpicks` line.** The driver (`Expect#findings`) skips pass 2 when pass 1
  counted none. A pass posted without the line counts as having some.

**Where.** `.claude/commands/implement.md` and `pr_review.md` (with their
`.cursor/` mirrors), `Run#review` in `bin/autopilot`, and the amendment to ADR
0014.

**Manual workflow.** The same rule holds by hand: one local round before a slice
PR, and no pass 2 after a pass 1 that found only nitpicks.

## 10. Review while CI runs

**Problem.** `/pr_submit` runs every CI check locally (Step 2), pushes, then waited
for the remote fast checks, and the driver started pass 1 only once they were
green. Over three slices that wait took 2–5 minutes each. On two of them the
agent's `--watch` also waited for the full `test` job. The remote checks never
caught anything: 14 of 14 slices pushed once.

**Change.**
- **For a slice, `/pr_submit` skips its CI wait (Steps 6–7).** The driver's
  `submitted` expectation no longer reads checks, so pass 1 starts as soon as the
  PR exists.
- **CI is still checked before merging.** The driver's merge gate already waits
  for every check on the head it lands, and halts on red. The manual landing step
  in `/pr_review` now runs `gh pr checks --watch --fail-fast` before
  `gh pr merge`.

**Where.** `Expect#submitted` in `bin/autopilot`, and `.claude/commands/pr_submit.md`
and `pr_review.md` with their mirrors.

**Trade.** A red check that `/pr_submit` used to fix by itself now halts at the
merge gate, after the reviews. There were none in this history.

## 11. No local Rails suite when nothing the app loads changed

**Problem.** `/pr_submit` Step 2 ran `bin/test` on every branch. On a slice that
changed only files the Rails app never loads (docs, or a native client in its own
directory) that is about 3 minutes, and it cannot fail.

**Change.** When every changed file matches the app's skip-suite paths, Step 2
skips the unit and system tests and the query ledger. `/workflow_setup` fills those
paths in (the `SUITE_SKIP_PATHS` token), by default `docs/`, `.llm/` and any `.md` file.
Lint, flay, brakeman and `bin/gates` still run. CI runs the full suite before the
merge either way. The rule goes by path rather than by `.rb`: Slim, JS, config and
YAML all affect the suite, so a change to any of them still runs it.

**Where.** `.claude/commands/pr_submit.md` Step 2, with its mirror.

## Looked at, not changed

- **`bin/gates` runs inside steps.** They are cheap.
- **Pre-PR review subagents.** The ADR requires them.
- **Cache hit rate.** It is already 96–97%. The cost is the size of what hits,
  not how often.
- **A cheaper model for Explore subagents.** They run on the main model. This is
  open, not rejected.
