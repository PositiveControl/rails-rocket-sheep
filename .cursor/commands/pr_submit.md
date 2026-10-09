---
description: "Push for review: suite, docs, PR, then comments until green"
argument-hint: "[issue number, defaults to the branch]"
---

# PR Submit

Push current branch for review. Iterate until pipeline green + all review comments addressed. Pass issue number as argument: `/pr_submit 1613`

## Instructions

### Step 1: Pre-flight checks

Verify branch ready to push:

1. Read `Base:` from the task file (`.llm/tasks/<id>_*.md`): `main`, or the feature branch `feature/<slug>` this slice targets. No task file → `main`. Every `<BASE>` below is that value.
2. Run `git status` for uncommitted changes. Unstaged changes → ask user what to do.
3. Run `git log origin/<BASE>..HEAD --oneline` to confirm commits exist to push.
4. Confirm branch name follows convention `feat/<issue>/<slug>` (e.g., `feat/1613/fix-address-delete`). Mismatch → note, don't block.
5. Rebase or merge left conflicts in the tree → `/resolve_conflicts` first. Never push a half-resolved rebase.
6. No `Pre-PR review:` line in the task file's progress log → run `/implement` Step 5 (the fresh-context review) now, then come back.
7. Check whether autopilot is active, with `<BASE>` from item 1 (`docs/system/autopilot-steps.md`, *Activation*). If it is, every *Autopilot* paragraph below replaces the question it follows, and each answer is appended to the autopilot log as one entry. Item 2's unstaged changes under autopilot are a `halt`, and so is a lint error that will not auto-correct (Step 2).

### Step 2: Run local checks (pre-push)

Before push, run full CI suite locally. Catch issues early. Fix failures before proceeding.

**Lint** — use `/run_lint` command to lint changed files + auto-fix errors:
```bash
git fetch origin <BASE> && git diff-tree -r --no-commit-id --name-only origin/<BASE> HEAD | xargs ls -1 2>/dev/null | xargs bin/rubocop --force-exclusion
```
Lint errors found → correct them. Can't auto-correct → halt, suggest manual fixes.

**Duplication** — fails on Ruby the branch copies that `<BASE>` lacks (skip when there is no `bin/flay`):
```bash
bin/flay origin/<BASE>
```
Copied → call the existing copy or extract it. Similar shape → a warning; reuse it if it is the same idea.

**Static analysis** — security scan:
```bash
bin/brakeman -q --no-pager
```

**Nothing the Rails app loads changed → skip Tests and Query ledger below.** That is, every file the branch changes matches this app's skip-suite paths (`^$`). This command prints nothing then:
```bash
git diff --name-only origin/<BASE>...HEAD | grep -vE '^$'
```
The suite cannot see those files, so it would pass as it did on `<BASE>`. CI still runs the full suite before the merge. Say in the PR's test plan that the Rails suite was skipped and why. Lint, flay, brakeman and `bin/gates` above still run. A Slim, JS, config or YAML file is never on that list: each one affects the suite.

**Tests** — full unit suite, plus only the system tests this branch could break:
```bash
bin/test
bin/rails test:system TEST=test/system/<relevant>_test.rb   # only relevant files, may be none
```

Pick relevant system tests from the branch diff (`git diff --name-only origin/<BASE>..HEAD`):
- Changed `test/system/**` files → run those
- Changed views, Stimulus controllers, routes, or controllers → run system tests covering those flows (grep `test/system/` for the feature name)
- Model/service/job-only changes, docs, config → skip system tests entirely

The full system suite runs in CI. Local system runs are single-worker and slow — don't run the whole suite before push.

**Query ledger** — every SQL shape the suite emits has a reviewed line (`docs/rules/query-ledger.md`):
```bash
bin/rails db:queries                                          # merges new shapes into db/queries.yml
grep -q "review: ''" db/queries.yml && bin/rails db:queries:explain  # plan + indexes for each unreviewed one
```
An unreviewed entry → read its plan and the indexes printed beneath, write the `review:` line (an index name from `db/schema.rb`, or `no index:` and why), and commit `db/queries.yml` with the code that emits the query. CI runs `db:queries:check` and fails on an empty or unknown one.

Lint + static analysis run parallel (independent). Then tests.

Check fails:
- **Lint errors**: fix automatically, commit (same as `/run_lint`)
- **Security-scan warnings**: investigate, fix security issue, commit
- **Test failures**: diagnose + fix only failures **introduced by this branch**. Check branch-changed files (`git diff --name-only origin/<BASE>..HEAD`). Failing tests in files branch didn't touch, or same tests fail on `<BASE>` → pre-existing. Note, don't block PR.
- Re-run failing check to confirm fix before moving on

### Step 3: Resolve documentation

Docs ship with the PR — reviewers review them with the code.

1. Check `docs/sop/` and `docs/system/` for **placeholder docs** referencing this issue (or its parent feature):
   - Task added new procedures or architecture → **complete** the placeholder with real content
   - Bug fix / small change, no doc needed → **delete** the placeholder
   - `<BASE>` is `main` → never push a PR leaving a `Status: Draft` placeholder behind for this issue
   - `<BASE>` is a feature branch → the placeholders belong to the feature. Complete the ones this slice's work fills in and leave the rest as Draft; do not delete a placeholder because *this* slice needed no doc. The feature PR is where the rule bites
2. Task changed system behavior documented in `docs/system/` → update the affected doc
3. Update the `.llm/README.md` index: add links for completed docs, remove links for deleted placeholders
4. **Verify the index**: check for duplicate entries and links to files that don't exist; fix any found
5. Commit doc changes as their own commit

### Step 3b: QA walkthrough — every branch, unless the developer skips it

Reviewers get a guided walkthrough with the code (`docs/system/qa_walkthrough.md`). This step runs on every PR; the only way past it is the developer's explicit skip. An API-only app has no pages to walk: skip with the one-line reason.

1. **Does the branch already carry it?** `git diff --name-only origin/<BASE>..HEAD | grep '^script/qa/'` — the plan's walkthrough step landed during `/implement` → run it once unattended (`QA_AUTO=1 QA_HEADLESS=1 bin/qa-walkthrough <name>`, no `✗`) and move on.
2. **Otherwise decide what it would show.** List the user-facing surfaces the diff touches: `git diff --name-only origin/<BASE>..HEAD | grep -E '^app/(views|components|controllers|javascript|helpers)/'`. Nothing user-facing (model, service, job, rake, docs only) → the default is skip, and say so in one line in the PR body ("No walkthrough: no user-facing change").
3. **Something user-facing → ask the developer, one round, with create as the recommended default:**
   - *Create the walkthrough now (recommended)* — run `/qa_walkthrough <issue>` (it extends the parent feature's script when one exists, otherwise starts one for this branch), then return here
   - *Skip: covered by an existing walkthrough* — name the script; add the branch's steps to it only if they are missing
   - *Skip: not worth a walkthrough* — the developer's call; one line in the PR body says so
   No answer possible (a non-interactive run) → create; never skip silently.
   **Autopilot (gate `walkthrough`):** create, and log it. Anything the walkthrough cannot show (a native client, a timing, a feel) goes into the log's *Not checked by a human* for this slice, with how to check it.
4. The walkthrough commit rides with the PR. Mention `bin/qa-walkthrough <name>` in the Test plan.

### Step 4: Push and create/update PR

Push branch:
```bash
git push -u origin HEAD
```

Check if PR already exists for branch:
```bash
gh pr view --json number,url 2>/dev/null
```

No PR → create one. First gather context for PR description:

1. Read task file for issue (if exists):
   ```bash
   ls .llm/tasks/<ISSUE_NUMBER>_*.md
   ```
   Extract the **Goal**, **Approach** (from Next Actions), and **Requirements & Acceptance Criteria** to write a meaningful summary.

2. Read the commit log for this branch:
   ```bash
   git log origin/<BASE>..HEAD --oneline
   ```

3. Create the PR using the task file context (preferred) or commit messages (fallback):

Write the body with the Write tool to `tmp/pr-body-<ISSUE_NUMBER>.md` (a file, not a heredoc: permission rules don't match a heredoc, so an autopilot step's `dontAsk` denies it):

```markdown
## Summary
<1-3 bullet points describing the changes, drawn from the task file's goal and approach>

## Changes
<Brief description of each file or area changed, drawn from task file's Next Actions or commit messages>

<CLOSING_LINE>
<SLICE_LINE>

## Test plan
- [ ] CI pipeline passes
- [ ] <specific test scenarios from the task file's acceptance criteria>
- [ ] `bin/qa-walkthrough <name>` walks the change (or: No walkthrough — <reason from Step 3b>)
```

```bash
gh pr create --base <BASE> --title "<ISSUE_NUMBER> | <Short description>" --body-file tmp/pr-body-<ISSUE_NUMBER>.md
```

**`<BASE>` is a feature branch → omit `<CLOSING_LINE>` on every tier** and write `<SLICE_LINE>` as `Slice of \`feature/<slug>\` — feature PR #<n>`, with `<n>` from `gh pr list --head feature/<slug>`. GitHub closes issues only on a merge to the default branch, so a `Closes` here would do nothing; the feature PR body carries one per landed slice instead (`WORKFLOW.md`, *Feature branches*). **Do not tick the slice** in the feature PR's **Slices** list: a tick means the slice has merged. `/pr_review` *Land it* ticks it after the merge, and under autopilot the driver does, once it has also merged `origin/main` into the feature branch and written the slice's log section.

**`<BASE>` is `main` → omit `<SLICE_LINE>`. PR title and `<CLOSING_LINE>` depend on the tracker tier `labels`:**

| Tier | Title | `<CLOSING_LINE>` |
|---|---|---|
| `github-projects` | `<number> \| <description>` | `Closes #<ISSUE_NUMBER>` |
| `beads` | `bd-<hash> \| <description>` | *omit entirely* |
| `labels` | `<number> \| <description>` | `Closes #<ISSUE_NUMBER>` |

Under `github-projects` and `labels`, the `Closes #` line is **required** — it is what closes the issue on merge, and under `github-projects` it also drives the board's "item closed → Done" workflow.

Under `beads` there is no GitHub issue to close, so emitting `Closes #` would either do nothing or close an unrelated issue that happens to share the number. Omit it. Reconciliation happens instead at the start of the next `/pick`, which finds beads sitting in `lifecycle:up_for_review` whose PR has merged and closes them. That is deliberate: no CI job, no webhook, and it self-heals if a session is skipped.

### Step 5: Mark Up for Review

Tier `labels`. Follow only the matching branch.

**`beads`:**
```bash
bd set-state <ID> lifecycle=up_for_review
bd update <ID> --external-ref gh-<PR_NUMBER>
```
`set-state` records an event bead (the audit trail) *and* attaches a queryable `lifecycle:up_for_review` label. The `external-ref` is what the next `/pick` uses to find the PR and close the bead once it merges — **without it, reconciliation cannot work**, so do not skip it.

**`labels`:**
```bash
gh issue edit <ISSUE_NUMBER> --repo PositiveControl/rails-rocket-sheep --add-label "status:up-for-review" --remove-label "status:in-progress"
gh issue edit <ISSUE_NUMBER> --repo PositiveControl/rails-rocket-sheep --add-label "ready for review"
```

**`github-projects`** — move the issue to "Up for Review" on the board and add the label.

First get the project item ID:
```bash
gh api graphql -f query='{ repository(owner: "PositiveControl", name: "rails-rocket-sheep") { issue(number: <ISSUE_NUMBER>) { projectItems(first: 5) { nodes { id project { title } } } } } }'
```

Then update status to "Up for Review":
```bash
gh project item-edit --project-id n/a --id <ITEM_ID> --field-id n/a --single-select-option-id n/a
```

Add the "ready for review" label to the issue:
```bash
gh issue edit <ISSUE_NUMBER> --repo PositiveControl/rails-rocket-sheep --add-label "ready for review"
```

Replace `<ISSUE_NUMBER>` (or `<ID>`) with the value from `$ARGUMENTS`.

**Note:** If the project board update fails with a missing `project` scope error, inform the user they need to run `gh auth refresh -s project` and skip this step — do not block the PR workflow.

### Step 6: Wait for fast CI checks

**`<BASE>` is a feature branch → skip Steps 6 and 7** and go to Step 8. Step 2 already ran every check CI runs, so self-review pass 1 can start while CI does; waiting for it here only delays the review. CI is checked on the head that lands, before the merge: by you when you land the slice (`/pr_review`, *Land it*), or by the driver's merge gate under autopilot. Measured over 14 slices, every one pushed once: the remote fast checks never caught what Step 2 had missed.

`<BASE>` is `main` → poll only the fast CI checks: the fast checks (docs, generate (web), generate (api)). These complete in ~1-2 minutes. Do NOT wait for the slow checks () — the full test suite was already run locally in Step 2.

**Important:** The `gh pr checks` command uses these JSON fields: `name`, `state`, `link`, `workflow`. It does NOT have a `conclusion` field — use `state` only (values: `PENDING`, `SUCCESS`, `FAILURE`, `SKIPPED`).

```bash
gh pr checks --json name,state,link --jq '.[] | select(.name as $n | ["docs","generate (web)","generate (api)"] | index($n)) | "\(.name): \(.state)"'
```

Polling loop:
1. Fetch check status for the fast checks (docs, generate (web), generate (api)) only
2. If any of these is `PENDING` or `IN_PROGRESS`, wait 30 seconds and re-check
3. If all of them are terminal (SUCCESS/FAILURE), proceed to triage
4. After 5 minutes of polling, proceed with whatever status is available

**If there are CI failures:**
1. Identify which job(s) failed: one of docs, generate (web), generate (api)
2. For lint or flay failures: run `/run_lint` locally, fix issues, commit, and push
3. For security-scan failures: investigate and fix the security issue
4. Ignore `CodeQL` / `Analyze` checks — these are informational and not blocking

After fixing CI failures, push and re-poll until fast checks pass (maximum **3 iterations**). **Autopilot:** still red after the third → `halt`.

### Step 7: Fetch and address review comments

Once fast CI checks pass, run `/pr_comment_resolver <PR_NUMBER>` to fetch, address, and resolve any review comments on the PR.

### Step 8: Final report

When the PR is clean, present:

```
✓ PR #<NUMBER> is ready for review
  URL: <PR_URL>
  Branch: <BRANCH_NAME> → <BASE>
  Checks: Fast checks passing (docs, generate (web), generate (api))
  Test: Running in CI (already passed locally)
  Docs: placeholders resolved, index verified
  Walkthrough: bin/qa-walkthrough <name> (<n> steps) | skipped: <reason>
  Reviews: <summary of any reviews>
```

If there are human reviewers who need to approve, mention that.

### Next step

`<BASE>` is a feature branch → this is a slice, and you review it yourself from a **new session**: `/pr_review <PR_NUMBER>` — two passes at most, each from a fresh session, the second over only the first's fixes. That session merges it and updates the feature PR (`/pr_review`, *Self-review of a slice*). Say so and stop here.

**Autopilot:** stop here too. The driver runs the review passes, each in a new process, and does the merge. Make sure this slice's log entries are committed and pushed with the PR, so the reviewer reads them with the code.

`<BASE>` is `main` → merge is human judgment — a reviewer approves and clicks merge. After merge, GitHub auto-deletes the branch under every tier. Under `github-projects` and `labels`, `Closes #N` closes the issue, and under `github-projects` the Projects "item closed" workflow then sets the board to Done. Under `beads` nothing happens at merge time by design — the next `/pick` reconciles the bead closed. No cleanup command in any tier.

After the PR is merged, suggest:

```
PR merged! Automation handles issue close, board → Done, and branch deletion.
  git checkout <BASE> && git pull
  → Run /pick for your next task
```

## Reference
- GitHub username: Use `gh api user --jq .login` to get the current user's GitHub username
- Repo: PositiveControl/rails-rocket-sheep
- PR title convention: `<issue_number> | <description>`
- Branch convention: `feat/<issue_number>/<slug>`
- Base: the task file's `Base:` line — `main`, or `feature/<slug>` for a slice of a multi-slice feature; no `Closes` on a slice PR
- Tracker tier: `labels`
- Autopilot: `docs/system/autopilot-steps.md` — activation check, policy by gate id (`walkthrough`, `halt` here), log entry shape, halt protocol
- Fast CI checks (poll these): docs, generate (web), generate (api)
- Slow CI checks (skip polling, ran locally): 
- Informational checks (ignore): CodeQL / Analyze
- CI check `state` values: PENDING, IN_PROGRESS, SUCCESS, FAILURE, SKIPPED (no `conclusion` field)
- Local pre-push checks: bin/gates, bin/rubocop --force-exclusion (changed files), bin/flay (copied code vs `<BASE>`), bin/brakeman -q --no-pager, bin/test, bin/rails test:system, bin/rails db:queries
- Pre-existing test failures: system tests may have failures on main — only fix failures introduced by the branch
- Issue label for review: "ready for review"
- Project ID: n/a · Status field ID: n/a
- Status option IDs: Blocked=n/a, Todo=n/a, In Progress=n/a, Up for Review=n/a, Done=n/a
- If project board update fails with scope error: suggest `gh auth refresh -s project`, skip and continue
- Repo prerequisites for post-merge automation: "Automatically delete head branches" enabled (all tiers) · Projects workflow "item closed → Done" enabled and `Closes #N` in every PR body (tier `github-projects`) · `Closes #N` only (tier `labels`) · neither, reconciliation via `/pick` (tier `beads`)
