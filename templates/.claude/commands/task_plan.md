---
description: "Plan one issue: task file, implementation plan, then a branch"
argument-hint: "<issue number>"
---

# Task Plan

Plan one issue's implementation: explore → task file → human approval → branch. Planning only — execution is `/implement`. Pass the issue number: `/task_plan 1613`.

## Instructions

### Step 1: Fetch issue details

```bash
gh issue view $ARGUMENTS --repo {{GITHUB_ORG}}/{{GITHUB_REPO}}
gh issue view $ARGUMENTS --repo {{GITHUB_ORG}}/{{GITHUB_REPO}} --json comments --jq '.comments[] | "[\(.createdAt)] \(.author.login): \(.body)"'
gh api graphql -f query='{ repository(owner: "{{GITHUB_ORG}}", name: "{{GITHUB_REPO}}") { issue(number: <ISSUE_NUMBER>) { parent { number title body } subIssues(first: 20) { nodes { number title state } } } } }'
```

**Shape check:** issue has no acceptance criteria, >5 acceptance bullets, size XL, or open sub-issues → stop, route to `/feature_plan $ARGUMENTS`. Oversized work never enters task planning.

### Step 2: Read the design doc

Issue has a parent (or links a design doc)? Read the matching `docs/plans/*-design.md` first — constraints, rejected alternatives, and slice boundaries are already decided there. Do not re-litigate them.

### Step 3: Explore the codebase

1. Search `docs/` for docs, patterns, gotchas in the affected area
2. Find relevant models, controllers, views, services, Stimulus controllers
3. Read key files — understand current behavior
4. Find existing tests for the affected area
5. Check for an existing `.llm/tasks/` file for this issue number (exists → consider `/implement $ARGUMENTS` instead)

Be thorough — understanding current code is critical for a good plan. Use a dedicated search pass (a subagent, if your tool has them) or plain glob/grep/read. Blocked on a decision the issue doesn't answer? Suggest `/segue <question>`.

### Step 4: Create the task file

Create `.llm/tasks/<issue_number>_<snake_case_slug>.md` from `.llm/tasks/task_template.md`:

- **Goal**: from issue body
- **Background/Context**: synthesized from issue, comments, design doc, exploration
- **Requirements & Acceptance Criteria**: from the issue (in scope AND out of scope explicit)
- **Next Actions**: concrete implementation steps — files to modify, approach, test strategy
- **References**: issue, parent, design doc, key source files

Conventions live in `CLAUDE.md` — the task file references it, never copies rules.

### Step 5: GATE — present the plan for approval

1. **Issue**: number, title, brief description
2. **Approach**: high-level fix/feature description
3. **Files to change**: each file + brief change description
4. **New tests**: coverage to add
5. **Size forecast**: estimated added lines vs the 100–600 target — over → propose a split now
6. **Risks/Questions**: anything needing clarification
7. **Flagged decisions**: architecture choices or new patterns (ALWAYS need user approval)

**Wait for approval** — approve, adjust, or answer questions before proceeding.

### Step 6: Set up for implementation

After approval:

**Clean working tree:** `git status` — uncommitted changes → ask user: stash or commit first.

**Feature branch:**

The `<ID>` segment is the tracker's identifier — a bare number under `github-projects` and `labels` (`1613`), or the bead ID under `beads` (`bd-a3f2dd`, from `tst-a3f2dd` with the prefix normalised to `bd-`). It is the thread ID that ties branch, task file, and PR together.

```bash
git branch --list "{{BRANCH_PREFIX}}/<ID>/*"
```
- Exists → `git checkout {{BRANCH_PREFIX}}/<ID>/<slug>`
- Not → `git checkout main && git pull && git checkout -b {{BRANCH_PREFIX}}/<ID>/<short-slug>`

**Mark In Progress** — tier `{{TRACKER}}`:

`github-projects`:
```bash
gh api graphql -f query='{ repository(owner: "{{GITHUB_ORG}}", name: "{{GITHUB_REPO}}") { issue(number: <ISSUE_NUMBER>) { projectItems(first: 5) { nodes { id project { title } } } } } }'
gh project item-edit --project-id {{PROJECT_ID}} --id <ITEM_ID> --field-id {{STATUS_FIELD_ID}} --single-select-option-id {{STATUS_IN_PROGRESS}}
```

`beads`:
```bash
bd update <ID> --claim
```
Atomic — sets assignee to you and status to `in_progress`, and **fails if someone else already claimed it**. A failure here is real information: stop and pick different work rather than forcing it.

`labels`:
```bash
gh issue edit <ISSUE_NUMBER> --add-label "status:in-progress" --remove-label "status:todo"
```

### Next step

```
Plan approved and branch ready. Run: /implement <ISSUE_NUMBER>
```

## Reference
- Repo: {{GITHUB_ORG}}/{{GITHUB_REPO}}
- Task template: .llm/tasks/task_template.md
- Branch convention: `{{BRANCH_PREFIX}}/<id>/<slug>` — `<id>` is a number, or `bd-<hash>` under tier `beads`
- Project ID: {{PROJECT_ID}} · Status field ID: {{STATUS_FIELD_ID}}
- Tracker tier: `{{TRACKER}}`
- Status option IDs (tier `github-projects`): Blocked={{STATUS_BLOCKED}}, Todo={{STATUS_TODO}}, In Progress={{STATUS_IN_PROGRESS}}, Up for Review={{STATUS_UP_FOR_REVIEW}}, Done={{STATUS_DONE}}
- Sizing: PR target 100–600 added lines / 5–15 files
