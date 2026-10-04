# Autopilot — what a step reads

**Status:** Complete

The part of [autopilot](autopilot.md) a command needs while it runs as a step:
whether autopilot is on, the policy that answers its gates, how it writes log
entries, whose comment is whose, and how it halts. The driver, the guard and the log
template are in [autopilot.md](autopilot.md); a step does not need them.

## Activation

Autopilot needs two keys, and both have to be present:

1. **Consent.** The feature's design doc carries, under its `**Feature branch:**`
   line:

   ```markdown
   **Autopilot:** on — log: docs/plans/<date>-<slug>-autopilot.md
   ```

   Only `/feature_plan` writes this line, at G1 or at a G1 amendment, and only
   after the developer says yes.
2. **Activation.** The environment has `AUTOPILOT=1`. Only `bin/autopilot` sets it.

The design doc is the one artifact every tracker tier shares, so consent is
visible to every session and reviewable in git. The environment variable means a
developer who opens `/task_plan` by hand on an autopilot feature gets the gates
as usual. Either key alone does nothing.

**The check.** A command decides whether autopilot is active with three plain
commands, run one at a time:

```bash
printenv AUTOPILOT
grep -l "^\*\*Feature branch:\*\* <BASE>\$" docs/plans/*-design.md
grep -lE '^\*\*Autopilot:\*\* on( —|$)' <the design doc the second command printed>
```

Autopilot is active when the first prints `1` and the third prints the design doc.
The second printing nothing means no design doc names the branch: autopilot is
off, and the third is not run. They are separate commands, not one line with a
`$(…)` substitution, because an autopilot step runs under `dontAsk`, and
permission rules can't match a substitution: it would be denied.

**Under the driver, the check is already done.** `bin/autopilot` runs the same
check in its preflight, and appends the result to every step's system prompt: the
feature branch, its design doc and its log. A step whose `<BASE>` is that branch
takes it as the result and skips the three commands. Any other `<BASE>` runs them.

`<BASE>` is the feature branch the work belongs to, taken from wherever the
command first knows it:

| Command | `<BASE>` from |
|---|---|
| `/task_plan` | The issue body's `Feature branch:` line, read at Step 1. The task file does not exist yet |
| `/implement`, `/pr_submit` | The task file's `Base:` line |
| `/pr_review`, `/pr_comment_resolver` | The PR's `baseRefName` |
| `/resolve_conflicts` | Its argument, which the driver passes (HEAD is detached). Run by hand with none, autopilot is off |

- **The anchor matters.** `on( —|$)` matches `on — log: …` and a bare `on`,
  but not `on hold until …` or `once …`, which an unanchored `on` would read as
  consent.

Work whose base is `main` is never on autopilot: there is no feature branch to
merge into, and the merge to `main` is human.

In the commands, an **Autopilot** paragraph applies only when the check passes.
Otherwise the command reads exactly as it would without the paragraph.

## Policy

Each human prompt in the commands has a **gate id**. The log names it on every
entry, so the developer can filter by kind of decision.

**These are the defaults, not the policy a feature runs under.** At G1,
`/feature_plan` copies this table and the halt list into the feature's log, under
*Policy accepted at G1*, with the developer's changes applied. From then on, **the
log's copy is that feature's policy.** A command looks up a gate id there, never
here. A feature branch merges `origin/main` after every slice, so a later edit
to this file would otherwise loosen a running feature's rules without anyone
having agreed to it at its G1.

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

## The autopilot log

One file per feature, `docs/plans/<date>-<slug>-autopilot.md`. `/feature_plan`
creates it from the template in [autopilot.md](autopilot.md#the-autopilot-log-template) when the developer says yes at G1. It stays in
`docs/plans/` after the feature merges, beside the design doc: it is the record of
why the code is the way it is.

**Who writes what, where.**

- A command running on autopilot appends its entries under `### #<issue>` in
  *Slices*, creating that heading if it is missing, and commits them on the slice
  branch: in the commit of the work they explain, or in a commit of their own when
  there is no such work. They reach the feature branch when the slice merges.
- After the merge, the driver completes the slice's section on the feature branch:
  - the heading, with the PR and the merge SHA
  - the header row
  - its rows under *Metrics* and its PAUSE entries

  It also moves any `#### D<issue>-` entry that landed elsewhere in the file under
  the slice's *Decisions*. Every write here can run twice and change nothing.
- At finalize, the driver regenerates *Read this first* and the `**Run:**` line,
  and puts the capture hook's output under *QA*.

**Entry shape.** Every decision is one entry, never batched:

```markdown
#### D<issue>-<n> · `<gate id>` · <the question, one line>
- **Options:** <A> · <B> [· <C>]
- **Chose:** <A>, because <reason>
- **Trade-off:** <what the choice costs>
- **Reversible:** cheap | costly | one-way
- **Evidence:** <commit SHA · file:line · probe command and output · PR or review link>
```

`<n>` counts from 1 within the issue. `Reversible` is what *Read this first* ranks
by, so set it honestly: `one-way` is a schema change, a public contract, a filed
issue, or a published doc; `costly` is anything another slice now builds on.

**HALT and PAUSE entries** use the same heading line with their own key:

```markdown
#### HALT · `<gate id>` · <reason, one line>
- **Where:** <command, step> on `<branch>` at <SHA>
- **Uncommitted:** <`git status --short` summary, or "clean">
- **Needs:** <the decision or fix the developer has to supply>
- **Comments:** <gate `comments` only: the `kind:id` of each person's comment that caused the halt>
- **Resume:** answer under **Needs**, clear Blocked on <slice id> (*Tracker tiers*), then `bin/autopilot <slug>` (the driver restores the slice's state when it picks the slice up again)

#### PAUSE · usage limit · <step>
- **At:** <time> · **Resumed:** <time> · **Step:** <command and argument>
```

## Whose comment is it

Self-review passes post from the developer's own GitHub account (ADR 0014), so on
a slice PR the author login says nothing about who wrote a comment. Under
autopilot, a comment is:

| Kind | How to tell |
|---|---|
| **The agent's** | A review whose body opens with `Self-review pass`; an inline comment whose `pull_request_review_id` is one of those reviews' ids; or any comment or review whose body contains the marker `<!-- autopilot -->` |
| **A bot's** | `user.type` is `Bot` (code-quality and review bots) |
| **A person's** | Everything else with a body, including the developer commenting from the same account, and a review body with no inline comments ("Request changes: wrong approach") |

**The marker is a contract.** Everything the agent posts under autopilot ends
with `<!-- autopilot -->`: replies (`/pr_comment_resolver`), HALT entries posted on
an issue, and the driver's halt, pause and finish notices. Anything posted
without it will be read as a person's on the next pass, and halt the run.

**Already handled.** When a person's comment halts the run, the HALT entry names
it on a `**Comments:**` line (`- **Comments:** inline:8, review:202`). On resume,
those ids are settled: the developer answered them under **Needs**. Without this,
the same comment would halt every resume. Settled means settled for good: if the
person later *edits* that comment, the run does not read it again. A new comment
is what reaches a running feature.

```bash
PR=<n>; R=repos/<org>/<repo>; LOG=<the feature's autopilot log>   # <org>/<repo> as in the commands
SEEN=$(grep '^- \*\*Comments:\*\*' "$LOG" | grep -oE '(inline|review|issue):[0-9]+' | jq -R . | jq -s .)
PASSES=$(gh api --paginate $R/pulls/$PR/reviews | jq -s '[add[] | select((.body // "") | startswith("Self-review pass")) | .id]')
{ gh api --paginate $R/pulls/$PR/reviews  | jq -s 'add | map(select((.body // "") != "") | . + {kind:"review"})'
  gh api --paginate $R/pulls/$PR/comments | jq -s 'add | map(. + {kind:"inline"})'
  gh api --paginate $R/issues/$PR/comments | jq -s 'add | map(. + {kind:"issue"})'
} | jq -rs --argjson passes "$PASSES" --argjson seen "$SEEN" '
  add[]
  | select(.user.type != "Bot")
  | select((.body // "") | contains("<!-- autopilot -->") | not)
  | select(.kind != "review" or ((.body | startswith("Self-review pass")) | not))
  | select(.kind != "inline" or ((.pull_request_review_id as $r | $passes | index($r)) | not))
  | "\(.kind):\(.id)"
  | select(. as $k | $seen | index($k) | not)'
```

Every `kind:id` printed is an unhandled comment from a person, and under
autopilot that is a `halt` (gate `comments`). List them on the HALT entry's
`**Comments:**` line.

- **Why `--paginate` and `jq -s`.** GitHub returns 30 items a page. A busy pass 1
  can push a person's comment onto page 2. `--paginate` emits one array per page,
  and `jq -s 'add'` joins them. The calls pipe to `jq` because `gh api --jq` takes
  an expression only, with no `--argjson`.
- **Reviews are read.** A person's review body with no inline comments appears in
  neither comments list, only under `reviews`. A review with an empty body is the
  container for inline comments, which are counted on their own.
- **Tested** against fixtures across two pages. The fixtures held a pass-1
  review, a person's "Request changes" review, an empty container review, a bot,
  marked replies and an already-handled id. Only the person's review, a page-2
  inline comment and an unmarked issue comment print. The earlier filter flagged
  the handled id again and never saw the review.

`pull_request_review_id` comes from GitHub's review-comment object. The driver's
tests pin it with a payload recorded from a real self-review pass.

## Tracker tiers

Autopilot moves a slice through the same lifecycle states as a person does
(`WORKFLOW.md`, *Gates*), on whichever tier `/workflow_setup` chose. Every
tracker operation a step or the driver performs is one of the rows below. The
rest of this doc and `autopilot.md` name the operation, such as "mark Blocked",
and this table says how it is done on each tier. Board IDs for
`github-projects` are the ones `/workflow_setup` recorded in
`.claude/workflow.config.md`, and filled into the commands.

| Operation | `labels` | `github-projects` | `beads` |
|---|---|---|---|
| A slice's id | `#<n>` | `#<n>` | `bd-<hash>` |
| Read its state | `gh issue view <n> --json labels`: its `status:*` label | its board Status (`gh issue view <n> --json projectItems`) | `bd show <id> --json`: `status`, and the `lifecycle:up_for_review` label |
| Set a state | add `status:<state>`, remove the other four `status:*` labels (removing a missing label is a no-op) | `gh project item-edit` on the issue's item, with that state's Status option ID | Todo `bd update <id> --status open`; In Progress `--status in_progress`; Blocked `--status blocked`; each of those three then `bd label remove <id> lifecycle:up_for_review`, so a slice reads as one state and `/pick` never closes a Blocked bead. Up for Review `bd set-state <id> lifecycle=up_for_review` |
| Is it Blocked? | label `status:blocked` | Status `Blocked` | `status` is `blocked` |
| Clear Blocked (the developer, to resume) | remove `status:blocked` | set Status to anything but `Blocked` | `bd update <id> --status open` |
| File a split or an `issue` entry | `gh issue create --label autopilot --label status:todo` | `gh issue create --label autopilot`, then add it to the board (Todo) | `bd create --label autopilot`, then `bd dep add` it under the epic |
| Post a HALT entry off the slice branch | a comment on the issue | a comment on the issue | a comment on the feature PR, naming `bd-<hash>`: there is no GitHub issue |

The label `autopilot` has to exist on GitHub for the first two tiers. The run
guide's setup creates it.

## Halt

A halt means the policy says a person is needed. It is not a failure. A command
that halts:

1. Commits finished units as usual. It does not commit half-done work: the HALT
   entry lists it under **Uncommitted**.
2. Marks the slice Blocked, replacing whichever state it had (*Tracker tiers*,
   "Set a state"). Under `labels`:
   `gh issue edit <n> --add-label "status:blocked" --remove-label "status:todo" --remove-label "status:in-progress" --remove-label "status:up-for-review"`
3. Records the HALT entry where the developer will see it. Decide by the branch
   that is checked out, not by step number: `/task_plan` Step 6 halts on a dirty
   tree *before* it creates the slice branch.

   ```bash
   case "$(git branch --show-current)" in
     <branch-prefix>/<issue>/*) echo slice-branch ;;   # the trailing slash keeps issue 480's branch out of issue 48's match
     *)            echo issue ;;
   esac
   ```

   - **`slice-branch`:** append the entry to the log, commit it alone, and **push**
     the branch (`git push -u origin HEAD`). An unpushed entry is invisible to the
     developer reading GitHub.
   - **`issue`** (typically `/task_plan` Steps 1–5, and Step 6 up to the slice
     branch checkout, while the driver's worktree is on `feature/<slug>`): commit
     nothing. A commit there would land on the feature branch, possibly mixed with
     the uncommitted changes that caused the halt. Post the entry as a comment
     instead (*Tracker tiers*, "Post a HALT entry"), ending with
     `<!-- autopilot -->`. The driver copies it into
     the log on the feature branch.
4. Ends its output with exactly one line, the **halt marker**, and stops:

   ```
   AUTOPILOT-HALT: <gate id> — <reason, one line>
   ```

The driver greps for the marker, notifies the developer, and exits. Resuming is
the HALT entry's **Resume** line: the developer answers, clears the label, and
reruns the driver. Every command is idempotent from tracker state, so the run
picks up at the halted step.

A **pause** is the driver's alone: a step stopped by the subscription's usage
limit is not a halt and uses no retry. The driver records the pause, posts a
notice, waits for the limit to reset, and reruns the same step. Pauses are kept in
the driver's state file until the slice lands, then written into the log as
PAUSE entries, with the slice's metrics.

