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

Be thorough — understanding current code is critical for a good plan. Use the Explore agent or Glob/Grep/Read. Blocked on a decision the issue doesn't answer? Suggest `/segue <question>`.

### Step 4: Create the task file

Create `.llm/tasks/<issue_number>_<snake_case_slug>.md` from `.llm/tasks/task_template.llm.md`:

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
```bash
git branch --list "{{BRANCH_PREFIX}}/<ISSUE_NUMBER>/*"
```
- Exists → `git checkout {{BRANCH_PREFIX}}/<ISSUE_NUMBER>/<slug>`
- Not → `git checkout main && git pull && git checkout -b {{BRANCH_PREFIX}}/<ISSUE_NUMBER>/<short-slug>`

**Board → In Progress:**
```bash
gh api graphql -f query='{ repository(owner: "{{GITHUB_ORG}}", name: "{{GITHUB_REPO}}") { issue(number: <ISSUE_NUMBER>) { projectItems(first: 5) { nodes { id project { title } } } } } }'
gh project item-edit --project-id {{PROJECT_ID}} --id <ITEM_ID> --field-id {{STATUS_FIELD_ID}} --single-select-option-id {{STATUS_IN_PROGRESS}}
```

### Next step

```
Plan approved and branch ready. Run: /implement <ISSUE_NUMBER>
```

## Reference
- Repo: {{GITHUB_ORG}}/{{GITHUB_REPO}}
- Task template: .llm/tasks/task_template.llm.md
- Branch convention: `{{BRANCH_PREFIX}}/<issue>/<slug>`
- Project ID: {{PROJECT_ID}} · Status field ID: {{STATUS_FIELD_ID}}
- Status option IDs: Blocked={{STATUS_BLOCKED}}, Todo={{STATUS_TODO}}, In Progress={{STATUS_IN_PROGRESS}}, Up for Review={{STATUS_UP_FOR_REVIEW}}, Done={{STATUS_DONE}}
- Sizing: PR target 100–600 added lines / 5–15 files
