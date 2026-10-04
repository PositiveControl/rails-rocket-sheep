# Round trip — autopilot log

**Design:** [2026-10-04-round-trip-design.md](2026-10-04-round-trip-design.md) · **Feature PR:** #<n>
**Run:** <started> → <finished> · **Usage:** <driver total>

## Read this first

<!-- Regenerated at finalize. Every `costly` and `one-way` entry, every drop,
every issue filed, every `opinion`, every HALT, ranked by how hard each is to
reverse. -->

## Policy accepted at G1

Accepted 2026-10-04, copied whole from `templates/docs/system/autopilot-steps.md` (*Policy*).
This copy is the policy for this feature; later edits to the system doc do not reach it.

**Changes from the defaults:** none

**Scope note (from the design, not a policy change):** slices A (#57) and B (#56) land by
hand before the run. The guard denies any edit to the wiring's source under `templates/`,
so they cannot run as steps. The run takes C, D and E.

| Gate id | Where it comes up | Answer |
|---|---|---|
| `G2` | `/task_plan` Step 5 | Self-approve when the forecast is ≤1,500 added lines and ≤25 files, there are ≤2 flagged decisions, and nothing in the plan touches the *halt list*. Each flagged decision is logged as its own `choice` entry. Otherwise `halt` |
| `split` | `/task_plan` Step 5 (forecast over the bound), `/implement` Step 4 (scope escape) | Split: create the sub-issue (`Feature branch:` line, dependencies, label `autopilot`; *Tracker tiers*), add it to the feature PR's **Slices** list, carry on with the reduced slice. At most 2 splits per feature, then `halt` |
| `fix-drop` | `/implement` Step 5.4, `/pr_review` self-review pass 1 | Drop a finding only with a **probe**: a command or test whose output shows the failure scenario does not happen, or a cited rule it contradicts. Otherwise fix it under the failing-test rule. Every drop is logged with its probe |
| `pass-2` | `/implement` Step 5.7 (a PR into `main` only), `/pr_review` self-review pass 2 | Fix confirmed blockers and suggestions under the failing-test rule. A fix with no possible failing test → `halt` |
| `comments` | `/pr_comment_resolver` Step 4 | Address every non-noise comment. Skip noise and log what was skipped. **A comment from a person** on a slice PR mid-run → `halt`: someone is watching and has something to say |
| `post-review` | `/pr_review` Step 9 | Post the review unedited as `COMMENT`, its body opening with `Self-review pass <N>` |
| `merge` | `/pr_review` *Land it from this session* | Never inside a command. The driver merges after checking the PR's base. The command stops once the review is posted |
| `walkthrough` | `/pr_submit` Step 3b | Create it (already the rule for a non-interactive run) |
| `out-of-slice` | Anywhere: a fix outside the slice's acceptance criteria | Allowed at ≤~100 added lines, with a failing test first and no migration. Bigger → file an `issue` and work around it, or `halt` if blocked |
| `issue` | Anywhere: an API gap, a bug, follow-up work | File it with label `autopilot` (*Tracker tiers*), never work on it in the same run. Every one appears under *Read this first* |
| `opinion` | A deliverable that is the developer's call (a recommendation, a scorecard verdict) | Write it under a heading **Draft — the agent's view, for the developer to confirm**, and mark the doc `**Status:** Draft` so the feature PR cannot merge it silently |
| `choice` | Any design or implementation choice an interactive session would have put to the developer: a constant tuned, a library picked, an approach chosen between two | Make it, and log it with the alternative. This is the default gate id for a decision no other row covers |
| `halt` | Every prompt not answered above, and the halt list | Halt (below) |

**The halt list.** Halt whenever the work would:

- add a migration that drops or renames a column or table, or rewrites data
- touch authentication, authorization, token handling, `config/credentials*`, or
  `.github/workflows/`, beyond what the slice's acceptance criteria name
- touch payments, billing, or anything else that moves money
- leave the suite red after `/test_fix` plus one retry
- leave fast CI red after three iterations (`/pr_submit` Step 6, a PR into `main` only; a slice's CI is checked at the merge gate, where a red check halts only after one rerun of its failed jobs)
- need a third split, or grow one slice past 2,000 added lines
- hit a merge conflict `/resolve_conflicts` cannot prove green
- rest on a decision the design doc does not answer and no `choice` can settle
  safely — a question the developer would expect to be asked

A feature's G1 may scope an exception to one slice's acceptance criteria, written
into the log's *Policy accepted at G1* (example: "auth: bearer-token auth exactly as
#<n>'s acceptance criteria").

**The failing-test rule** is `/implement` Step 5.5's, unchanged: revert the fix,
see the test fail, restore it.

## Slices

## QA — how to check the whole feature

- Not checked by a human (from G1): `bin/rocket-sheep-backport --check` run against
  dopeempire reports #55's autopilot hunks with every app value tokenised or flagged. That
  needs the private repo, so a person runs it.

## Open questions for the developer

## Halts and pauses

## Metrics

| Slice | Step | Wall time | Usage | Retries | Pauses |
|---|---|---|---|---|---|
