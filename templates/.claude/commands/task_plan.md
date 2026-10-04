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

**Autopilot** — this command has gates the policy answers, so check now whether autopilot is active (`docs/system/autopilot-steps.md`, *Activation*), with `<BASE>` from the issue body's `Feature branch:` line, since the task file does not exist yet. If it is, every *Autopilot* paragraph below replaces the question it follows, and each answer is appended to the autopilot log as one entry. A failed shape check under autopilot is a `halt`: re-cutting a slice is `/feature_plan`'s, and that gate is human.

### Step 2: Read the design doc

Issue has a parent (or links a design doc)? Read the matching `docs/plans/*-design.md` first — constraints, rejected alternatives, and slice boundaries are already decided there. Do not re-litigate them. Read what binds every slice (problem, decisions, constraints, rejected alternatives, the decomposition entry for this issue) and the approach sections this slice touches; skip the sections for other slices' areas. Earlier slices' decisions are in the autopilot log, when there is one, not in their task files: do not read other issues' task files.

### Step 3: Explore the codebase

1. Search `docs/` for docs, patterns, gotchas in the affected area
2. Find relevant models, controllers, views, services, Stimulus controllers
3. Read key files — understand current behavior
4. Find existing tests for the affected area
5. Check for an existing `.llm/tasks/` file for this issue number (exists → consider `/implement $ARGUMENTS` instead)

Be thorough — understanding current code is critical for a good plan. Use a dedicated search pass (a subagent, if your tool has them) or plain glob/grep/read. Blocked on a decision the issue doesn't answer? Suggest `/grill "<the decision>"` for something this session can settle with the user, or `/segue <question>` for something needing its own session.

**Autopilot:** nobody can be grilled. A decision the design doc answers is not open. One it leaves open is a `choice`: make it and log it with the alternative, unless it touches the halt list or is one the developer would expect to be asked, which is a `halt`.

### Step 4: Create the task file

Create `.llm/tasks/<issue_number>_<snake_case_slug>.md` from `.llm/tasks/task_template.md` (the template is the format; another issue's task file is not an example to copy):

- **Goal**: from issue body
- **Background/Context**: synthesized from issue, comments, design doc, exploration
- **Requirements & Acceptance Criteria**: from the issue (in scope AND out of scope explicit)
- **Base**: `main`, unless the issue body, its parent, or the design doc names a feature branch `feature/<slug>` — then that. Every later command diffs and opens the PR against this line
- **Next Actions**: concrete implementation steps — files to modify, approach, test strategy. **Last action is always the QA walkthrough** (`docs/system/qa_walkthrough.md`): which `step`s the change adds to `script/qa/<feature>.rb` (or a new script), or the one-line reason there is nothing to show (no user-facing change; API-only app). `/pr_submit` Step 3b checks this landed
- **References**: issue, parent, design doc, key source files

Conventions live in `CLAUDE.md` — the task file references it, never copies rules.

### Step 5: GATE — present the plan for approval

1. **Issue**: number, title, brief description
2. **Approach**: high-level fix/feature description
3. **Files to change**: each file + brief change description
4. **New tests**: coverage to add
5. **Size forecast**: estimated added lines and files vs the 200–1,500 / 25 target — over → propose a split now
5b. **Walkthrough**: the steps the change adds to the QA walkthrough, or why it has nothing to show — the developer can strike it here
6. **Risks/Questions**: anything needing clarification
7. **Flagged decisions**: architecture choices or new patterns (ALWAYS need user approval)

**Wait for approval** — approve, adjust, or answer questions before proceeding. More than a couple of flagged decisions, or risks nobody can price → `/grill "<the issue title>"` and come back to this gate.

**Autopilot (gate `G2`):** the policy approves or halts in place of the developer. Approve when the forecast is within the sizing bound, there are at most two flagged decisions, and nothing touches the halt list. Draft the plan as one `G2` entry and each flagged decision as a `choice` entry, but **hold them**: the log is a tracked file, and writing it now would dirty the tree Step 6 is about to check. Step 6 writes them once the slice branch exists. Then go on to Step 6. A forecast over the bound is a `split`. Anything else is a `halt`. Write the plan into the task file exactly as you would have presented it; it is what the developer reads afterwards.

### Step 6: Set up for implementation

After approval:

**Clean working tree:** `git status` — uncommitted changes → ask user: stash or commit first. **Autopilot:** `halt`. The driver starts every step on a clean tree, so changes here are a stranger's.

**Feature branch, if the task file's `Base:` names one and it is not on the remote yet** — this is the feature's first slice, so create it and open its draft PR:

```bash
git checkout main && git pull
git checkout -b feature/<slug> && git push -u origin feature/<slug>
gh pr create --draft --base main --head feature/<slug> --title "{{PR_TITLE_PREFIX}} | <PARENT> | <feature title>" --body-file tmp/feature-pr-body-<slug>.md
```

`tmp/feature-pr-body-<slug>.md`, written with the Write tool first (not a heredoc: an autopilot step's `dontAsk` denies one):

```markdown
## Feature
<one line, and a link to docs/plans/<design doc>>

## Slices
- [ ] #<sub-issue> — <slice title>
- [ ] …

Closes #<PARENT>
```

`<PARENT>` is the parent issue under `github-projects`. Under `labels` there is none — use the slug in the title and drop the `Closes` line. Under `beads` drop the `Closes` line too; the epic is reconciled by `/pick`. Slice PRs never carry `Closes`; this body collects them as slices land (`WORKFLOW.md`, *Feature branches*).

**Slice branch:**

The `<ID>` segment is the tracker's identifier — a bare number under `github-projects` and `labels` (`1613`), or the bead ID under `beads` (`bd-a3f2dd`, from `tst-a3f2dd` with the prefix normalised to `bd-`). It is the thread ID that ties branch, task file, and PR together. `<BASE>` is the task file's `Base:` line.

```bash
git branch --list "{{BRANCH_PREFIX}}/<ID>/*"
```
- Exists → `git checkout {{BRANCH_PREFIX}}/<ID>/<slug>`
- Not → `git fetch origin <BASE> && git checkout -b {{BRANCH_PREFIX}}/<ID>/<short-slug> origin/<BASE>`

**Autopilot:** now append the entries Step 5 held to the log, commit them on the slice branch, and push it (`git push -u origin HEAD`), so they reach GitHub even if a later step halts. On a rerun (the slice branch already existed), the first run may have logged them already: append only when the log has no entry for this issue yet (`grep -q '^#### D<ISSUE_NUMBER>-' <log>` fails). Otherwise a retry would add a second `G2` entry with the same ids.

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
- Feature branch: `feature/<slug>`, named in the design doc and sub-issue bodies; base for every slice of a multi-slice feature
- Project ID: {{PROJECT_ID}} · Status field ID: {{STATUS_FIELD_ID}}
- Tracker tier: `{{TRACKER}}`
- Status option IDs (tier `github-projects`): Blocked={{STATUS_BLOCKED}}, Todo={{STATUS_TODO}}, In Progress={{STATUS_IN_PROGRESS}}, Up for Review={{STATUS_UP_FOR_REVIEW}}, Done={{STATUS_DONE}}
- Sizing: PR target 200–1,500 added lines / ≤25 files
- Autopilot: `docs/system/autopilot-steps.md` — activation check, policy by gate id (`G2`, `split`, `choice`, `halt` here), log entry shape, halt protocol
