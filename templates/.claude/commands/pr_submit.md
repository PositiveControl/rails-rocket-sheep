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
4. Confirm branch name follows convention `{{BRANCH_PREFIX}}/<issue>/<slug>` (e.g., `{{BRANCH_PREFIX}}/1613/fix-address-delete`). Mismatch → note, don't block.
5. Rebase or merge left conflicts in the tree → `/resolve_conflicts` first. Never push a half-resolved rebase.

### Step 2: Run local checks (pre-push)

Before push, run full CI suite locally. Catch issues early. Fix failures before proceeding.

**Lint** — use `/run_lint` command to lint changed files + auto-fix errors:
```bash
git fetch origin <BASE> && git diff-tree -r --no-commit-id --name-only origin/<BASE> HEAD | xargs ls -1 2>/dev/null | xargs bin/rubocop --force-exclusion
```
Lint errors found → correct them. Can't auto-correct → halt, suggest manual fixes.

**Static analysis** — security scan:
```bash
bin/brakeman -q --no-pager
```

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

```bash
gh pr create --base <BASE> --title "{{PR_TITLE_PREFIX}} | <ISSUE_NUMBER> | <Short description>" --body "$(cat <<'EOF'
## Summary
<1-3 bullet points describing the changes, drawn from the task file's goal and approach>

## Changes
<Brief description of each file or area changed, drawn from task file's Next Actions or commit messages>

<CLOSING_LINE>
<SLICE_LINE>

## Test plan
- [ ] CI pipeline passes
- [ ] <specific test scenarios from the task file's acceptance criteria>

EOF
)"
```

**`<BASE>` is a feature branch → omit `<CLOSING_LINE>` on every tier** and write `<SLICE_LINE>` as `Slice of \`feature/<slug>\` — feature PR #<n>`. GitHub closes issues only on a merge to the default branch, so a `Closes` here would do nothing; the feature PR body carries one per landed slice instead (`WORKFLOW.md`, *Feature branches*). Then find the feature PR (`gh pr list --head feature/<slug>`) and tick this slice in its **Slices** list.

**`<BASE>` is `main` → omit `<SLICE_LINE>`. PR title and `<CLOSING_LINE>` depend on the tracker tier `{{TRACKER}}`:**

| Tier | Title | `<CLOSING_LINE>` |
|---|---|---|
| `github-projects` | `{{PR_TITLE_PREFIX}} \| <number> \| <description>` | `Closes #<ISSUE_NUMBER>` |
| `beads` | `{{PR_TITLE_PREFIX}} \| bd-<hash> \| <description>` | *omit entirely* |
| `labels` | `{{PR_TITLE_PREFIX}} \| <number> \| <description>` | `Closes #<ISSUE_NUMBER>` |

Under `github-projects` and `labels`, the `Closes #` line is **required** — it is what closes the issue on merge, and under `github-projects` it also drives the board's "item closed → Done" workflow.

Under `beads` there is no GitHub issue to close, so emitting `Closes #` would either do nothing or close an unrelated issue that happens to share the number. Omit it. Reconciliation happens instead at the start of the next `/pick`, which finds beads sitting in `lifecycle:up_for_review` whose PR has merged and closes them. That is deliberate: no CI job, no webhook, and it self-heals if a session is skipped.

### Step 5: Mark Up for Review

Tier `{{TRACKER}}`. Follow only the matching branch.

**`beads`:**
```bash
bd set-state <ID> lifecycle=up_for_review
bd update <ID> --external-ref gh-<PR_NUMBER>
```
`set-state` records an event bead (the audit trail) *and* attaches a queryable `lifecycle:up_for_review` label. The `external-ref` is what the next `/pick` uses to find the PR and close the bead once it merges — **without it, reconciliation cannot work**, so do not skip it.

**`labels`:**
```bash
gh issue edit <ISSUE_NUMBER> --repo {{GITHUB_ORG}}/{{GITHUB_REPO}} --add-label "status:up-for-review" --remove-label "status:in-progress"
gh issue edit <ISSUE_NUMBER> --repo {{GITHUB_ORG}}/{{GITHUB_REPO}} --add-label "{{REVIEW_LABEL}}"
```

**`github-projects`** — move the issue to "Up for Review" on the board and add the label.

First get the project item ID:
```bash
gh api graphql -f query='{ repository(owner: "{{GITHUB_ORG}}", name: "{{GITHUB_REPO}}") { issue(number: <ISSUE_NUMBER>) { projectItems(first: 5) { nodes { id project { title } } } } } }'
```

Then update status to "Up for Review":
```bash
gh project item-edit --project-id {{PROJECT_ID}} --id <ITEM_ID> --field-id {{STATUS_FIELD_ID}} --single-select-option-id {{STATUS_UP_FOR_REVIEW}}
```

Add the "{{REVIEW_LABEL}}" label to the issue:
```bash
gh issue edit <ISSUE_NUMBER> --repo {{GITHUB_ORG}}/{{GITHUB_REPO}} --add-label "{{REVIEW_LABEL}}"
```

Replace `<ISSUE_NUMBER>` (or `<ID>`) with the value from `$ARGUMENTS`.

**Note:** If the project board update fails with a missing `project` scope error, inform the user they need to run `gh auth refresh -s project` and skip this step — do not block the PR workflow.

### Step 6: Wait for fast CI checks

Poll only the fast CI checks: the fast checks (scan_ruby, scan_js, lint). These complete in ~1-2 minutes. Do NOT wait for `test` — the full test suite was already run locally in Step 2.

**Important:** The `gh pr checks` command uses these JSON fields: `name`, `state`, `link`, `workflow`. It does NOT have a `conclusion` field — use `state` only (values: `PENDING`, `SUCCESS`, `FAILURE`, `SKIPPED`).

```bash
gh pr checks --json name,state,link --jq '.[] | select(["scan_ruby","scan_js","lint"] | index(.name)) | "\(.name): \(.state)"'
```

Polling loop:
1. Fetch check status for the fast checks (scan_ruby, scan_js, lint) only
2. If any of these is `PENDING` or `IN_PROGRESS`, wait 30 seconds and re-check
3. If all three are terminal (SUCCESS/FAILURE), proceed to triage
4. After 5 minutes of polling, proceed with whatever status is available

**If there are CI failures:**
1. Identify which job(s) failed: one of scan_ruby, scan_js, lint
2. For lint failures: run the linter locally, fix issues, commit, and push
3. For security-scan failures: investigate and fix the security issue
4. Ignore `CodeQL` / `Analyze` checks — these are informational and not blocking

After fixing CI failures, push and re-poll until fast checks pass (maximum **3 iterations**).

### Step 7: Fetch and address review comments

Once fast CI checks pass, run `/pr_comment_resolver <PR_NUMBER>` to fetch, address, and resolve any review comments on the PR.

### Step 8: Final report

When the PR is clean, present:

```
✓ PR #<NUMBER> is ready for review
  URL: <PR_URL>
  Branch: <BRANCH_NAME> → <BASE>
  Checks: Fast checks passing (scan_ruby, scan_js, lint)
  Test: Running in CI (already passed locally)
  Docs: placeholders resolved, index verified
  Reviews: <summary of any reviews>
```

If there are human reviewers who need to approve, mention that.

### Next step

`<BASE>` is a feature branch → this is a slice, and you review it yourself from a **new session**: `/pr_review <PR_NUMBER>`, repeated from a fresh session each time until a pass is clean, at most five. That session merges it and updates the feature PR (`/pr_review`, *Self-review of a slice*). Say so and stop here.

`<BASE>` is `main` → merge is human judgment — a reviewer approves and clicks merge. After merge, GitHub auto-deletes the branch under every tier. Under `github-projects` and `labels`, `Closes #N` closes the issue, and under `github-projects` the Projects "item closed" workflow then sets the board to Done. Under `beads` nothing happens at merge time by design — the next `/pick` reconciles the bead closed. No cleanup command in any tier.

After the PR is merged, suggest:

```
PR merged! Automation handles issue close, board → Done, and branch deletion.
  git checkout <BASE> && git pull
  → Run /pick for your next task
```

## Reference
- GitHub username: Use `gh api user --jq .login` to get the current user's GitHub username
- Repo: {{GITHUB_ORG}}/{{GITHUB_REPO}}
- PR title convention: `{{PR_TITLE_PREFIX}} | <issue_number> | <description>`
- Branch convention: `{{BRANCH_PREFIX}}/<issue_number>/<slug>`
- Base: the task file's `Base:` line — `main`, or `feature/<slug>` for a slice of a multi-slice feature; no `Closes` on a slice PR
- Tracker tier: `{{TRACKER}}`
- Fast CI checks (poll these): scan_ruby, scan_js, lint
- Slow CI checks (skip polling, ran locally): test
- Informational checks (ignore): CodeQL / Analyze
- CI check `state` values: PENDING, IN_PROGRESS, SUCCESS, FAILURE, SKIPPED (no `conclusion` field)
- Local pre-push checks: bin/gates, bin/rubocop --force-exclusion (changed files), bin/brakeman -q --no-pager, bin/test, bin/rails test:system
- Pre-existing test failures: system tests may have failures on main — only fix failures introduced by the branch
- Issue label for review: "{{REVIEW_LABEL}}"
- Project ID: {{PROJECT_ID}} · Status field ID: {{STATUS_FIELD_ID}}
- Status option IDs: Blocked={{STATUS_BLOCKED}}, Todo={{STATUS_TODO}}, In Progress={{STATUS_IN_PROGRESS}}, Up for Review={{STATUS_UP_FOR_REVIEW}}, Done={{STATUS_DONE}}
- If project board update fails with scope error: suggest `gh auth refresh -s project`, skip and continue
- Repo prerequisites for post-merge automation: "Automatically delete head branches" enabled (all tiers) · Projects workflow "item closed → Done" enabled and `Closes #N` in every PR body (tier `github-projects`) · `Closes #N` only (tier `labels`) · neither, reconciliation via `/pick` (tier `beads`)
