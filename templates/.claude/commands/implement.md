# Implement

Execute an approved task plan. Idempotent — first run after `/task_plan` approval and tenth resume after a lost session are the same command. Pass the issue number, or omit to infer from the current branch: `/implement 1613` or `/implement`.

## Instructions

### Step 1: Resolve the issue

1. `$ARGUMENTS` given → use it
2. Otherwise parse from the current branch name (`{{BRANCH_PREFIX}}/<issue>/<slug>`)
3. Neither works → ask, or suggest `/pick`

### Step 2: Load state

1. Read `.llm/tasks/<issue>_*.md` — goal, acceptance criteria, Next Actions, progress log. **No task file → stop, run `/task_plan <issue>` first.** Never implement without an approved plan.
2. Verify the branch: on `{{BRANCH_PREFIX}}/<issue>/*`? If not, check it out. `git status` + `git log origin/main..HEAD --oneline` — what's already committed.
3. Cross-check progress log vs actual commits — the log can lag reality; commits are truth.

### Step 3: Orient

Report 3 lines before touching code: what's done, what's in flight, what's next. Discrepancy between plan and code found → say so and resolve before continuing.

### Step 4: Work loop

Work through Next Actions in order. Per logical unit:

1. Implement per the plan
2. Write tests for new functionality — framework, fixtures, and HTTP-recording conventions per CLAUDE.md
3. Run the affected tests — green before moving on
4. Commit — one logical unit, message explains *why* (e.g., "Add scroll-to-bottom after Turbo Stream add", not "Update controller")
5. Append one dated bullet to the task file's progress log

Rules in force:

- **Conventions**: CLAUDE.md is the single source — do not restate rules in the task file
- **Scope escape**: forecast passes ~600 added lines, or new acceptance criteria surface → STOP. Split a sub-issue (`gh issue create`, link to parent), note it in the task file, land the current slice clean
- **Segue valve**: rabbit hole, plan contradiction, or theory-war debugging → suggest `/segue <question>` instead of burning the session
- Remove all debugging code before finishing

### Step 5: Done check

All acceptance criteria met, tests green, working tree committed:

```
All acceptance criteria met. Run: /pr_submit <ISSUE_NUMBER>
```

Criteria remain → keep looping or report the blocker.

## Reference
- Repo: {{GITHUB_ORG}}/{{GITHUB_REPO}}
- Task files: `.llm/tasks/<issue>_<slug>.md`
- Branch convention: `{{BRANCH_PREFIX}}/<issue>/<slug>`
- Test runner: `bin/test` (specific file: `bin/test <path-to-test-file>`), system: `bin/rails test:system`
- Sizing: PR target 100–600 added lines / 5–15 files
