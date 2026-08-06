# Workflow Setup (wizard)

One-time interactive setup for the agent workflow. Collects this repo's GitHub and board parameters, fills the remaining `{{TOKEN}}`s in `.claude/commands/*.md`, and verifies repo automation. Run once from the repo root.

**Stack tokens are already filled.** This app was generated from Rails Rocket Sheep, so the test, lint, and security-scan commands and the default branch are pre-set. This wizard only collects what is repo-specific: org, repo, board, naming conventions, and CI check names.

## Instructions

Ask questions **in small groups, one group at a time**. Always propose a detected default so the user can just confirm. Record every answer — Step 5 writes them all.

### Step 1: Detect before asking

Silently gather:

1. **Git remote** → propose org/repo: `git remote get-url origin`
2. **Default branch**: `git remote show origin | grep "HEAD branch"` (the commands assume `main`; if this repo differs, note it — Step 5 must fix the pre-filled value)
3. **CI checks**: `.github/workflows/*.yml` — list job names
4. **GitHub Projects boards**: `gh project list --owner <org>` (may need `gh auth refresh -s project`)

No remote yet → stop and tell the user to create the GitHub repo and push first. Everything downstream needs it.

### Step 2: Ask — repository & board

Group 1:
- GitHub org / repo (default: from remote)
- Project board: existing number, or offer to create one (`gh project create --owner <org> --title "<repo> Board"`)

Then resolve board internals yourself (don't ask the user for IDs):

```bash
gh project list --owner <ORG>
gh api graphql -f query='{ organization(login: "<ORG>") { projectV2(number: <N>) { id fields(first: 20) { nodes { ... on ProjectV2SingleSelectField { id name options { id name } } } } } } }'
```

Needed: project ID, Status field ID, and option IDs for **Todo, In Progress, Up for Review, Done, Blocked**. Missing statuses → tell the user to add them to the board's Status field (UI), then re-fetch. A missing "Up for Review" or "Blocked" option is the most common gap.

Personal (non-org) repos use `user(login: "<USER>")` instead of `organization(login: ...)` in every GraphQL query above and in the commands. Note this when filling tokens.

### Step 3: Ask — conventions

Group 2:
- Branch prefix (default: user's initials, e.g. `jd` → `jd/<issue>/<slug>`)
- PR title prefix (default: same initials uppercase → `JD | 123 | Fix thing`)
- Review-ready label (default: `ready for review`; create if missing: `gh label create "<label>"`)
- LLM persona for the task template (default: `Staff Rails Engineer, TDD advocate`) → write into `.llm/tasks/task_template.md`
- Iteration/sprint filter in `/pick`: on or off (default: off unless the board has an iteration field)

### Step 4: Confirm — tools & CI

These are pre-filled for this stack. Show them and ask only whether anything differs:

| Slot | Value |
|---|---|
| Lint (changed files) | `bin/rubocop --force-exclusion` |
| Lint auto-fix | `bin/rubocop -a` |
| Tests | `bin/test` |
| System tests | `bin/rails test:system` |
| Security scan | `bin/brakeman -q --no-pager` |

No system test suite in this app yet → that's fine; `/pr_submit` already treats system tests as optional and selects them from the diff.

CI checks (from detected workflow jobs): which are **fast** (lint/scan — poll after push) vs **slow** (full test suite — skip polling, it ran locally)? A fresh app may have only the Lighthouse workflow, which is neither — in that case set fast checks to an empty list and note that `/pr_submit` will skip CI polling.

### Step 5: Fill the tokens

Replace every remaining `{{TOKEN}}` across `.claude/commands/*.md`:

`{{GITHUB_ORG}}`, `{{GITHUB_REPO}}`, `{{PROJECT_NUMBER}}`, `{{PROJECT_NAME}}`, `{{PROJECT_ID}}`, `{{STATUS_FIELD_ID}}`, `{{STATUS_TODO}}`, `{{STATUS_IN_PROGRESS}}`, `{{STATUS_UP_FOR_REVIEW}}`, `{{STATUS_DONE}}`, `{{STATUS_BLOCKED}}`, `{{BRANCH_PREFIX}}`, `{{PR_TITLE_PREFIX}}`, `{{REVIEW_LABEL}}`, `{{FAST_CI_CHECKS}}`, `{{FAST_CI_CHECKS_JQ}}` (quoted comma list, e.g. `"lint","scan"`), `{{SLOW_CI_CHECKS}}`

And `{{PERSONA}}` in `.llm/tasks/task_template.md`.

Already filled by the template — change these only if Step 1 found a mismatch: default branch (`main`), lint, test, system-test, and security-scan commands.

Then verify, and note that the audit must cover the task template too:

```bash
grep -rn "{{" .claude/commands/ .llm/tasks/ --exclude=workflow_setup.md
```

Must return nothing. Leftovers → fill them.

Write the record to `.claude/workflow.config.md` — a table of every token and its value, plus the date. Re-running this wizard reads that file as the starting defaults.

`bin/pr-stack` has no tokens (it reads repo and default branch from `gh`) and the template already set its executable bit. Confirm with `bin/pr-stack --check`.

### Step 6: Conventions file

`CLAUDE.md` already exists — it ships with this app. **Append** a `## Workflow` section; do not rewrite the rest.

The section must include:
- Chain: `/pick` (entry) → `/feature_plan` → `/task_plan` → `/implement` → `/pr_submit` → human merge + automation
- Sizing: PR target 100–600 added lines / 5–15 files; issue acceptance criteria ≤5 bullets; scope-escape rule
- Docs: 4-dir canon (`docs/plans`, `docs/system`, `docs/sop`, `docs/qa`)
- Single-source rule: conventions live in `CLAUDE.md`; task files reference them rather than restating

`.gitignore` entries for `.llm/tasks/` and `.llm/threads/` are already written by the template — verify, don't duplicate.

### Step 7: Repo automation prerequisites

Apply/verify (each needs repo or org admin — if a call fails, list it for a human):

1. Auto-delete merged branches: `gh api -X PATCH repos/<ORG>/<REPO> -f delete_branch_on_merge=true`
2. Board built-in workflow **"Item closed" → status Done**: check `gh api graphql -f query='{ organization(login: "<ORG>") { projectV2(number: <N>) { workflows(first: 20) { nodes { name enabled } } } } }'`. The target status isn't exposed by the API — ask the user to eyeball it in the board's Workflows UI.
3. Branch protection on the default branch with required CI checks (turns the suite/review gates hard) — recommend, don't force.
4. Remind: every PR body must contain `Closes #<issue>` — `/pr_submit` does this automatically.

### Step 8: Finish

Summarize what was written (config file, filled commands, `CLAUDE.md` section, automation settings, and anything left for a human). Then print exactly:

```
Setup complete. Reload commands in your agent tool, then run:

  /pick
```

## Reference
- `WORKFLOW.md` (repo root) — full lifecycle spec and diagrams
- Token audit: `grep -rn "{{" .claude/commands/ .llm/tasks/ --exclude=workflow_setup.md` must be empty when done
- Board statuses required: Todo, In Progress, Up for Review, Done, Blocked
- `gh` project commands may need: `gh auth refresh -s project`
