# Autopilot

**Status:** Complete

Autopilot runs an approved multi-slice feature from its first open slice to a
ready feature PR with nobody at the keyboard. It does not remove the gates. Each
point where a command would ask the developer gets a written answer, the
[policy](autopilot-steps.md#policy). The command follows that answer and records it in the feature's **autopilot
log**, which the developer reads at the feature PR in place of the questions they
were not asked.

What stays human: **G1** (approving the design, which is also where autopilot is
switched on) and **the merge of the feature PR into `main`**. Why the line sits
there: [ADR 0016](../adr/0016-an-accepted-design-may-run-itself.md).
Design: [Autopilot](../plans/2026-10-02-autopilot-design.md).

**Split in two.** What a command reads while it runs as a step (activation, the
policy by gate id, log entries, whose comment is whose, halting) is in
[autopilot-steps.md](autopilot-steps.md), so a step loads half the text. This
doc has the log template, the driver and the guard.

## The autopilot log template

Where the log lives, who writes what, and the entry shapes are in
[autopilot-steps.md](autopilot-steps.md#the-autopilot-log).

**Template.** `/feature_plan` copies this, filling the header and the policy
section:

````markdown
# <Feature> — autopilot log

**Design:** [<design doc>](<date>-<slug>-design.md) · **Feature PR:** #<n>
**Run:** <started> → <finished> · **Usage:** <driver total>

## Read this first

<!-- Regenerated at finalize. Every `costly` and `one-way` entry, every drop,
every issue filed, every `opinion`, every HALT, ranked by how hard each is to
reverse. -->

## Policy accepted at G1

<!-- The table and halt list from docs/system/autopilot-steps.md (*Policy*), copied
whole at G1 with the developer's changes applied in place. This copy is the
policy for this feature; later edits to the system doc do not reach it. -->

**Changes from the defaults:** <each change, or "none">

<the gate-id table, as approved>

**Halt list:** <as approved, including any exception scoped to one slice>

## Slices

<!-- One section per slice, in merge order:

### #<issue> — <title> (PR #<n>, merged <SHA>)

| Added | Files | Review rounds | Fixed | Dropped | Wall time | Usage |
|---|---|---|---|---|---|---|

#### Decisions
<entries>

#### Bugs found and fixed
- <symptom> → <cause> → <fix commit>, test `<name>` (failed before the fix).
  Found by <review pass / suite / walkthrough>. On `main` before this feature: yes | no

#### Dropped review findings
- <claim> — probe: <command and output> — `file:line`

#### Issues filed
- #<n> <title> — <why it is out of scope>

#### Not checked by a human
- <behaviour> — how to check it: <steps>
-->

## QA — how to check the whole feature

<!-- Setup (accounts, servers, clients) · walkthrough scripts in order · capture
output · every "Not checked by a human" item, collected -->

## Open questions for the developer

## Halts and pauses

## Metrics

| Slice | Step | Wall time | Usage | Retries | Pauses |
|---|---|---|---|---|---|
````

## The driver

`bin/autopilot <slug>` takes a feature from its next open slice to a ready feature
PR. For each slice, in the order of the feature PR's **Slices** list, it runs the
steps below, lands the slice, and moves on to the next. When none is left, it
finishes the feature.

```
bin/autopilot <slug> --setup     once: worktree, bundle, the _autopilot databases
bin/autopilot <slug> --dry-run   preflight, the next slice, the exact commands
bin/autopilot <slug> --usage     cost and cache use per step, from the state file
bin/autopilot <slug>             run it
```

Exit status:
- `0`: finished, or nothing to do
- `1`: not ready to run (preflight names every problem)
- `2`: halted, blocked, stopped, or no open slice can start

**Where it runs.** In `../<repo>-autopilot-<slug>`, beside the main checkout, so
the developer's checkout and databases are never touched:

- `DB_SUFFIX=_autopilot` gives it its own development and test databases
  (`config/database.yml`).
- `bin/dev` runs on port 3100 (`QA_HOST`) for walkthroughs (`docs/system/qa_walkthrough.md`; an API-mode app has none, ADR 0009). It is started at the
  beginning of a run and stopped on every way out, and its pid is kept in the
  worktree's `tmp/autopilot/`.

**A step** is `claude -p "/<command> <arg>"`, a fresh process each time:

- `--permission-mode dontAsk --permission-prompts none`: nothing prompts, and
  anything unlisted is denied.
- `--allowedTools` from `.claude/autopilot-allowed-tools.txt`. A rule matches
  by prefix and a compound command needs every part listed, so a step passes
  values as arguments, never as a `VAR=` prefix (`bin/flay origin/<BASE>`).
- `--append-system-prompt` with the driver's standing rules (`Step::STEP_RULES`):
  run everything in the foreground, since a `-p` session ends with its turn and a
  background task's notification never arrives; read a denial as that
  command's alone, splitting it into listed parts; and never read the guard's
  wiring. The allowlist itself is appended to the rules, so no step has to look
  it up (the guard denies naming those files, reads included).
- `AUTOPILOT=1`, `DB_SUFFIX` and `QA_HOST` set.
- A 90-minute timeout that kills the step's whole process group.
- A new session id for every step. The resolver starts from
  `tmp/autopilot/handoff-<issue>.md`, which the driver writes: the task file's path,
  `/implement`'s closing summary, earlier resolver passes' summaries, and how to see the
  diff. `--resolver resume` instead resumes `/implement`'s session, the original
  design. Fresh became the default on 2026-10-03: over its first two slices it averaged $0.98 per
  run against $7.81 resumed (the resumed session re-read ~226k cached tokens per call),
  and review pass 2 found every pass-1 finding addressed. Each resolver row in the state
  file carries `variant: fresh|resume`, and `--usage` lists the two separately.
- Under `caffeinate -i` if you start the driver that way (the run guide says how).

Its JSON result is one of:

| Kind | Read from | The driver |
|---|---|---|
| `ok` | `subtype: success` | Checks the step's expectation |
| `halt` | an `AUTOPILOT-HALT:` line in `result` | Stops at once; the step followed the protocol |
| `usage_limit` | `is_error` and (HTTP 429, or limit wording), not `error_max_budget_usd` | Pauses until the stated reset (an epoch, or "resets 3pm"), or 30 min; reruns the same attempt; halts after 12 |
| `error` | anything else, including output that isn't JSON | Treats it as a failed expectation |
| `timeout` | 90 minutes | Treats it as a failed expectation |

The subscription limit's response is not documented, so the detector is
deliberately narrow. A wrong guess costs a halt, never an endless wait.

**The slice's steps and their expectations.** A step whose expectation already
holds is skipped, which is how a rerun picks up after a halt. A failed
expectation gets one retry, its note saying what was missing. A second failure
halts.

Each read through `gh` that fails (`pr view`, `pr list`, `issue view`, `api`
without a write flag) is tried twice more, 5s and then 15s later, before the
driver treats the state as unreadable. A single network blip once ended a run
between review passes. Writes go once, since a failed write may still have
landed. `gh pr checks` is not retried either: it exits non-zero when checks are
pending or red, and that is an answer.

| Step | Expectation (read from real state) |
|---|---|
| `/task_plan <n>` | Task file `.llm/tasks/<n>_*.md`, branch `<branch-prefix>/<n>/…`, the slice In Progress (`autopilot-steps.md`, *Tracker tiers*) |
| `/implement <n>` | `Pre-PR review:` in the progress log, clean tree |
| `/pr_submit <n>` | Open PR from the slice branch with base `feature/<slug>`. No CI wait: pass 1 starts while CI runs, and the merge gate waits for every check on the head that lands |
| `/pr_review <PR>` | A `Self-review pass 1` review on the PR |
| `/pr_comment_resolver <PR>` | Clean tree, `HEAD` pushed (once after pass 1) |
| `/pr_review <PR>` | `Self-review pass 2`, only if pass 1's `**Findings:**` line counts a blocker or suggestion and the resolver moved `HEAD` past pass 1's `commit_id`. A pass with no such line (posted before it existed) counts as having some |
| `/pr_comment_resolver <PR>` | The same, once after pass 2, for its rulings (gate `pass-2`) |

**Landing** (gate `merge`) is the driver's, never a step's:

1. **Check.**
   - The PR's base must be `feature/<slug>`.
   - Its head must be the one the review cycle ended on, so nothing pushed after
     the last review rides in.
   - Every check must finish green, `test` included (`gh pr checks --watch
     --fail-fast`, 45 minutes at most).

   A red check first gets one rerun of its run's failed jobs (`gh run rerun
   --failed`, after the run finishes), so a flaky test does not stop the
   feature; the driver notifies and logs a `CI rerun` row. A wrong base, a
   moved head, or a check still red after that rerun is a `halt`. Checks
   still running at 45 minutes stop the run.
2. **Merge.** `gh pr merge --squash --delete-branch --match-head-commit <head>`,
   with `--repo`, so gh leaves the worktree's branches alone.
3. **Bring the feature branch up to date**, detached on `origin/feature/<slug>`
   and pushed back as `HEAD:feature/<slug>`, so a feature branch checked out in
   the developer's own checkout is no obstacle:
   - `origin/main` is merged in.
   - On a conflict, a `/resolve_conflicts feature/<slug>` step runs. It is
     expected to finish the merge cleanly. Then the driver runs `bin/test` itself,
     and red is a `halt`. A halt here leaves the merge commit unpushed; the HALT
     entry's **Where** names its SHA.
   - A clean merge is pushed without a local suite run. The feature PR's CI runs
     on it, and the developer reads that CI at the feature PR.
   - The slice is written into the log (*The autopilot log*, *Who writes what*).

   One push carries both.
4. **Tick** the slice in the feature PR's **Slices** list, naming its PR, and add
   `Closes #<n>` after the last one.

The tick goes last. A halt in step 3 leaves the slice open and blocked, so the
rerun comes back to it. If it were ticked, the rerun would skip it, with
`main` still unmerged.

A rerun finds a slice's PR already merged and does only steps 3 and 4. A slice
that is still open after it landed stops the run rather than looping on it.

**Finishing**, once every slice is ticked, on the feature branch the same way:

1. **Placeholders.** One `/update_docs <files>` step for the feature's Draft
   placeholders: the files under `docs/` whose status line reads
   `Draft — created for #<a slice of this feature>`. It is expected to leave none
   of them still in that state, and a clean tree. An `opinion` document's plain
   `**Status:** Draft` is not a placeholder: it stays, for the developer to
   confirm at the feature PR.
2. **The log.** *Read this first* is regenerated:
   - every `one-way` entry and every filed issue, first
   - then every `costly` entry
   - then drops, HALTs and `opinion` entries, in log order

   The `**Run:**` line gets the first step's start, the finish time and the
   total usage estimate.
3. **Capture.** `script/qa/<slug>-capture` runs if it is executable, and its last
   lines go under *QA*. A failure there is recorded, not halted on.
4. **Ready.** The push, then `gh pr ready`, then a notice naming the log.

The feature PR's merge into `main` stays the developer's.

**Halts the driver finds itself** follow [*Halt*](autopilot-steps.md#halt). It labels the issue
blocked and posts the HALT entry on the issue, with the marker. It doesn't
commit, because the branch checked out isn't necessarily one the entry belongs
on.

**Resuming.** Every run starts the same way:

1. It copies HALT entries posted off the slice branch (on issues, or on the
   feature PR under `beads`) into the log on the feature branch, skipping any
   already there, then commits and pushes.
2. It stops at a slice still Blocked. Once every slice is
   ticked, that is the last one: a halt while finishing is filed there, and the
   finish waits on it too.
3. It gives a cleared slice its state back, on the app's tier
   (`autopilot-steps.md`, *Tracker tiers*):
   - Up for Review if its branch has an open PR (a halt in a review step), or
     its PR has already merged (a halt while landing)
   - In Progress if only the branch is on the remote
   - Todo otherwise

   If `gh` can't list the PRs, it stops with a notice rather than guess.

**State the tracker can't hold:**
- the authoring session id
- which resolver runs are done
- every step attempt: when it started, how long it ran, how it ended, and its
  metrics (cost, API time, turns, tokens by kind, ending context, per-model usage,
  subagents, permission denials: `docs/system/workflow-usage.md`, *Autopilot step rows*)
- the pauses taken

It lives in `tmp/autopilot/<slug>.json` in the worktree, local like the sessions
themselves. The log's metrics are written from it. Losing it costs a resolver run
in a new session and the lost slice's metrics, nothing more.

**Not a wall on its own.** The allowlist matches by prefix, and several entries
the steps genuinely need run arbitrary code:

- `ruby`, `bundle exec` and `bin/rails runner`
- `find -exec`
- `git checkout -- .`, which discards work
- `gh api`, which can reach the merge endpoint

A step that means to merge or force-push can, through any of them. The allowlist
keeps an honest step from wandering. It is not a defence against a step gone
wrong. That is the guard's job.

## Guard

Three layers stand between a step and what only a person or the driver may do:

1. **The allowlist**, `--allowedTools`: what a step may run without asking.
   Anything unlisted is refused, since nothing can prompt. It matches by prefix,
   so it is not a wall (above).
2. **The policy**, by gate id: what the step is told to do at each question.
3. **The guard**, `bin/hooks/autopilot_guard`: a `PreToolUse` hook on `Bash`,
   `Edit`, `Write`, `MultiEdit` and `NotebookEdit`, wired in
   `.claude/settings.json`. It is the only layer a step cannot argue with.

The guard does nothing unless `AUTOPILOT=1`, so interactive sessions never meet
it. Under it, it denies:

| What | Why |
|---|---|
| `gh pr merge`, the `pulls/<n>/merge` endpoint, the `mergePullRequest` mutation | Only the driver merges, after checking the base (gate `merge`) |
| A push to `main` (`main`, `HEAD:main`, `refs/heads/main`). Checking out `main` (or `worktree add` of it), and a plain `git push` from a checked-out `main`. The main ref named anywhere. Any `gh api` write that targets `main`: a `branches/main` path, or a `branch`, `base`, `head` or `ref` field set to it (a contents PUT with `branch=main`, say). `main` named in a write's text, such as a PR reply, passes | `main` is the developer's, and it has no branch protection to fall back on |
| The branch-merge endpoint (`repos/…/merges`) and the GraphQL `mergeBranch`, `createCommitOnBranch`, `updateRef(s)` and `deleteRef` | Branches move by push, and only forward |
| A force push: `--force`, `--force-with-lease`, `-f` in any flag group, a `+refspec`. A forced ref update (`force=true`) | History on the remote is never rewritten |
| Deleting a remote branch: `git push --delete` or `-d`, a `:branch` refspec, a `DELETE` on `git/refs` | Deleting the feature branch would close the feature PR |
| A push from another checkout: `git -C <dir> push`, or a `cd` before it, into any directory outside this worktree, or one the guard can't place | The developer's own checkout sits beside the worktree |
| A git alias, `remote.*.push` or `push.default` | A renamed or redirected push escapes the push rules |
| `gh pr ready`, `markPullRequestReadyForReview` | The driver readies the feature PR when every slice has landed |
| `gh issue close`, a `state=closed` field | Issues close when the feature merges to `main` |
| `gh pr edit --base` or `-B`, a `base=` PATCH | A slice PR targets the feature branch |
| Any edit under `config/credentials*` or `.github/workflows/`, and any command naming them | The halt list. Reads go through the Read tool; the settings' deny list covers the keys |
| A migration that removes, drops or renames a column, table or reference: written by an edit, written by a command, or generated (`rails g migration Remove…`) | The halt list |
| Edits to the guard's own wiring (`.claude/settings*.json`, `bin/hooks/`, the allowlist, `bin/autopilot`), and any command naming them | A step that can unwire the guard, or the driver's merge check, has no guard |

**It matches the whole command, never its prefix.** `ruby -e 'system("gh pr merge 70")'`
is denied like `gh pr merge 70`. A push counts only when `push` is git's
subcommand, so a commit message that mentions pushing to `main` passes.
Elsewhere it errs toward denying: a commit message that names `gh pr merge` is
refused too. On autopilot that costs a halt, never a merge.

**A denial is a halt.** The hook exits 2, and its message tells the step to stop
and follow [*Halt*](autopilot-steps.md#halt). Under `AUTOPILOT=1`, a tool call the hook cannot read is
denied: a guard that fails open is no guard.

**What it cannot stop.**
- A step that writes a script to a file and runs it later is caught only if the
  command that runs it names something guarded.
- The guard reads text. It does not interpret the shell, so a string built at
  run time (`"ma" + "in"`) is not seen.

Branch protection on `main` would be the backstop it lacks. Setting it is the
developer's call; `/workflow_setup` recommends it.

The driver's own merges, edits and comments run outside any step and never meet
the hook. Preflight refuses to start a run whose settings don't wire it.

**The other hooks under autopilot.** The settings also wire `post_edit`
(RuboCop and Slim checks on every edit) and `session_end` (the Draft-placeholder
check at Stop).
- `session_end` says nothing under `AUTOPILOT=1`, on a detached HEAD, or on a
  `feature/<slug>` branch, whose drafts the feature PR completes. A Stop
  hook that exits 2 keeps a `claude -p` step going. A slice's own placeholder is
  Draft until its `/pr_submit`, so `/task_plan` and `/implement` would loop on it:
  a live probe ran 29 turns before this was fixed.
- `/pr_submit` resolves the slice's own placeholders, and the driver checks the
  feature's at finish.
