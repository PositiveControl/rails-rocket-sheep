# Round trip: adopter fixes and the backport tool

**Status:** Approved at G1 (2026-10-04)

**Feature branch:** feature/round-trip
**Autopilot:** on — log: docs/plans/2026-10-04-round-trip-autopilot.md

Issues: #67 (slice 0), #57, #56, #72, #58, #68, #69. #59 is the parent of #68 and #69. Deferred: #70.

## Problem

Apps adopted from the template meet three classes of defect. All three were found
downstream (dopeempire, markevans), and every adopter will hit them:

- **Hooks that stop running or never stop** (#56, #57). The Stop hook loops a
  session on drafts it doesn't own. Hooks registered as relative paths fail without
  a sound once the session cwd leaves the app root, so the draft check and the
  RuboCop/Slim check stop running.
- **Updates that leave the app red** (#58). `bin/rocket-sheep-update` writes a
  command that is new upstream to `.claude/commands/` but not to its
  `.cursor/commands/` mirror, so the app's next `bin/gates` fails.
- **No way back up** (#59). A fix proven in an app reaches the template only by a
  hand port: diff, re-tokenise, swap `master` → `main`, check the round trip. #55
  did this by hand (#63), and every adopter would repeat it with the same mistakes
  available.

This feature is the first one this repo runs on autopilot. Making that possible is
slice 0.

## Constraints

- **Most of #56 already shipped in #63.** Already done: the `feature/*`, detached
  HEAD, `AUTOPILOT=1` and `SKIP_DRAFT_CHECK` exits in `session_end`, with tests;
  `bin/flay <base>`; the `echo`/`printenv`/`git merge-tree` allowlist entries;
  `STEP_RULES` (foreground only, a denial covers one command, heredoc and `$(…)`
  guidance, the allowlist inline); `Feature#tick` reloading;
  `MERGE_MAIN --no-ff`; `/pr_submit`'s "Autopilot: do not tick"; the guard's
  `MAIN_TARGET`; file-based bodies in every command; the SOP's `gh label create
  autopilot`. What is left is in slice B.
- **The guard can't tell product source from live wiring.**
  `autopilot_guard`'s `WIRING` regex matches `.claude/settings*.json`,
  `bin/hooks/`, the allowlist and `bin/autopilot` *anywhere* in a path or
  command. In this repo that includes `templates/bin/autopilot`,
  `templates/bin/hooks/*` and `templates/.claude/settings.json`. An autopilot step
  is denied any edit to them, and any command that names them. **A slice that
  changes the wiring's source can't run on autopilot here.**
- **The driver's preflight compares the guard command exactly.**
  `guard_wired?` checks `hook["command"] == "bin/hooks/autopilot_guard"`. #57's
  `cd "$CLAUDE_PROJECT_DIR" && …` form would make preflight refuse every run.
- **The worktree sees only tracked files.** The driver reads the design doc, the
  log, `.claude/workflow.config.md`, `.claude/settings.json`, the allowlist, the
  guard and `bin/gates` from `../rails-rocket-sheep-autopilot-<slug>`. It commits
  the log there, and steps run `/task_plan` and the rest from the worktree's
  `.claude/commands/`. Today all of these are git-excluded local copies.
- **The driver assumes a Rails app.** `--setup` runs `bundle install` and
  `bin/rails db:prepare`. `Server#start` spawns `bin/dev` (it raises if that is
  missing), and a conflict re-runs `bin/test`. The commands call `bin/test`,
  `bin/rubocop`, `bin/brakeman` and `bin/rails`.
- **Template scripts are single files in `bin/`.** `bin/flay` fails on Ruby the
  branch copies, so the backport can't duplicate `rocket-sheep-update`'s helpers.
  `test/bin/autopilot_test.rb` already `load`s an executable to reuse its code.
- ADRs that bind this work: 0005 (an update is a three-way merge from the stamp),
  0006 (adoption installs the alignment layer only), 0004 (the origin stamp),
  0014/0016 (an accepted design may run itself).

## Approach

### Slice 0: dogfood the layer, tracked (by hand, PR to `main`)

The local alignment layer stops being git-excluded and is committed at the root.
That covers `.claude/` (settings, workflow config, commands, allowlist),
`.cursor/commands/`, `bin/gates`, `bin/hooks/*`, `bin/autopilot`, `WORKFLOW.md`,
`.llm/`, `docs/plans/`, `docs/qa/` and `.github/PULL_REQUEST_TEMPLATE.md`.

Shims stand in for a Rails app's binstubs:

- **`bin/test`** runs the real verification: `ruby -c` over the entry scripts,
  `doc-tokens --check`, `templates/bin/lint-docs`, and every
  `templates/test/bin/*_test.rb`.
- **`bin/dev`** sleeps until it is signalled.
- **`bin/rubocop`, `bin/brakeman` and `bin/rails`** print "n/a in the template
  repo" and exit 0.

The allowlist gains the template's own checks. The path redirects in
`CLAUDE.local.md` move into a tracked *Dogfood layer* section of root `CLAUDE.md`,
because a worktree session never sees a private file.

A small `bin/dogfood-sync` re-renders the layer from `templates/` with the tokens
in `.claude/workflow.config.md`. That keeps "re-copy it here" from becoming
drift.

The worktree is created by hand with `git worktree add`, which skips `--setup`'s
bundle and database steps. A generator ADR (`.agents/adr/0016-…`) records the
reversal of "never commit them" and its cost: a root that shows a second copy of
the layer, kept in step by the sync script.

This PR also carries this design doc, its autopilot log, and the `.llm/README.md`
lines, which is the G1 PR Step 6b requires.

### Slice A: hooks run from the project root (#57, by hand)

All three hook commands in `templates/.claude/settings.json` become
`cd "$CLAUDE_PROJECT_DIR" && bin/hooks/<hook>`. `guard_wired?` accepts either form:
it matches on the command *ending* in the guard path, and still checks that the
file is executable. A test over the shipped settings fails on a bare relative hook
command (`autopilot_guard_test.rb` already reads the settings).

This touches the wiring, so it is by hand.

### Slice B: what #56 left (by hand)

- `/pr_review` *Land it* merges with `git merge --no-ff origin/main`.
- `/pr_submit` stops ticking at submit time in the interactive flow too, so there
  is one tick, `/pr_review`'s, after the merge.
- The driver no longer trusts a tick alone. A ticked slice with no log section is
  "merged, finish landing", the path a rerun already takes, so an early tick
  costs a re-land rather than a skipped one.
- `/workflow_setup` creates the `autopilot` label on tiers `labels` and
  `github-projects`. The SOP's step 5 becomes a check.

This touches `bin/autopilot`, so it is by hand.

### Slice F: CI fails a stale dogfood layer (#72, by hand)

Added 2026-10-04, after G1. A CI job on PRs into `main` runs `bin/dogfood-sync`
and fails on any diff, naming the stale files; PRs into `feature/*` are exempt,
since autopilot steps cannot sync. Scope and criteria are #72's.

The guard denies a step any edit to a CI workflow, and the last criterion is a
throwaway PR into `main`, so it is by hand. It depends only on slice 0, and the
feature PR is the first PR into `main` it checks.

### Slice C: the update writes a new command's mirror (#58, autopilot)

`destinations` also returns the `.cursor/` mirror when the `.claude/` file is new
to the app and the app has a `.cursor/commands/` directory. A merge still needs an
existing mirror, so an app that deleted its Cursor copy doesn't get it back.

The first test for `rocket-sheep-update`, `templates/test/bin/rocket_sheep_update_test.rb`,
builds a template repo with two commits and an app stamped at the first, in a
tmpdir. `adopt.rb` installs the test alongside the script, as it does the
autopilot tests.

### Slices D and E: `bin/rocket-sheep-backport` (#59, autopilot)

`templates/bin/rocket-sheep-backport` is installed by `adopt.rb`. It reuses
`rocket-sheep-update`'s stamp, template-resolution, manifest and blob helpers by
`load`ing that script, whose main body moves under
`if __FILE__ == $PROGRAM_NAME`. Nothing is copied, so flay stays green.

- **D: `--check`.**
  - **Scope:** the template's `adopt.rb` manifest, read from the checkout. Changes
    outside it are listed as app-only.
  - **Range:** the stamp, or `--since`. `--paths` narrows it.
  - **De-tokenise:** values come from `.claude/workflow.config.md`'s token table
    and the default branch, replaced longest-first on word boundaries. A value that
    is too short or too common is flagged with its line, never replaced.
  - **Rendered files** (`CLAUDE.md` from `CLAUDE.md.tt`) are flagged "port by
    hand".
  - Writes nothing.
- **E: write.**
  - Apply the de-tokenised patch to the template at the stamp, then merge it
    three-way onto the current ref. Real conflicts come out as markers.
  - **Round-trip proof:** re-tokenise the result with the app's values and diff it
    against the app's files. Any difference is reported and nothing is written.
  - Output is a branch in the template checkout, plus a summary of what was
    ported, flagged and app-only. No PR is opened.
  - A new SOP, `docs/sop/backport-to-the-template.md`, sits beside
    update-from-the-template.

## Rejected alternatives

- **Keep the layer excluded and copy it into the worktree.** The driver commits
  the log under `docs/plans/`, which `git add` refuses for an excluded path, and
  every run would need a hand copy.
- **Teach `bin/autopilot` to run without Rails** (skip bundle, database and
  `bin/dev` when they're missing, read the suite command from config). It's a real
  product change for one repo's sake, and shims do the same at zero product
  cost. Revisit if an adopter on a non-Rails stack asks.
- **Commit the layer only on `feature/<slug>`.** That needs a hand strip before
  every feature PR, repeated every feature.
- **Anchor the guard's `WIRING` to the project root** so slices A and B could run on
  autopilot. That loosens the wall: `templates/../bin/autopilot` and
  `cd`-relative paths become evasions to reason about. Two small slices by hand
  cost less than a weaker guard.
- **#56's narrower `main` skip** (ignore drafts whose `created for #<n>` names an
  open `feature/*` issue). `SKIP_DRAFT_CHECK=1` already covers it locally, and the
  narrow version needs a network call in a Stop hook. Not built.
- **Backport as a mode of `rocket-sheep-update`.** Rejected because #59 asks for its
  own command, and `load` gives the code reuse without making one script do both
  directions.

## Open questions

- **Settled:** the round trip doesn't run the template's `lint-docs` or a scratch
  app's `bin/gates`. Template CI does that on the backport's PR (#59, question 1).
- **Settled:** a token without a config-table row, and every `.tt`-rendered file,
  is flagged and never written (#59, question 2).
- **Settled:** #55 was done by hand in #63. #59's last acceptance criterion
  ("#55 is done with it") becomes a fixture round trip in slice E's tests. Close
  #55.
- **Deferred to #70:** the guard (`MAIN`, `MAIN_TARGET`) and the driver
  (`MERGE_MAIN`) hard-code `main`. An adopted app whose default branch is `master`
  (dopeempire) gets no main-branch protection from the shipped guard. A new
  issue, outside this feature.
- **Not checked by a human:** #59's "`--check` on dopeempire reports the autopilot
  hunks" needs a private repo, so it goes to the log's QA section.

## Decomposition

| Slice | Issue | Mode | Forecast (added) | Depends on |
|---|---|---|---|---|
| 0 — dogfood layer tracked, G1 PR | #67 (PR to `main`) | by hand | large, mechanical copy; ~300 written | — |
| A — hooks from `$CLAUDE_PROJECT_DIR` | #57 | by hand | ~120 | 0 |
| B — what #56 left | #56 | by hand | ~250 | 0 |
| C — update writes the new command's mirror | #58 | autopilot | ~350 | 0 |
| D — `rocket-sheep-backport --check` | #68 | autopilot | ~700 | C (shares the test harness) |
| E — backport write, round trip, SOP | #69 | autopilot | ~800 | D |
| F — CI fails a stale dogfood layer (added after G1) | #72 | by hand | small | 0 |

Slices A, B and F land on `feature/round-trip` by hand before the run. They're
ticked, and the driver finishes landing them (merge `main`, log section). The run
then takes C, D and E.

## Docs impact

- Root: `CLAUDE.md` gets the *Dogfood layer* section, `.agents/adr/0016-…`,
  `docs/inventory.md` (slice 0)
- `templates/docs/system/autopilot.md`: the driver's tick check (B)
- `templates/docs/sop/run-a-feature-on-autopilot.md`: the label step (B), the
  guard command form (A)
- `templates/docs/sop/update-from-the-template.md`: the mirror note (C), a link to
  the backport (E)
- `templates/docs/sop/backport-to-the-template.md`: new (E)

**No placeholder files.** A Draft placeholder under `templates/` would ship to
generated apps and trip their Stop hook, and `lint-docs` requires every doc there
to be copied. Slice E writes the new SOP whole.
