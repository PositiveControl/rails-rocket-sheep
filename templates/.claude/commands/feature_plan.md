# Feature Plan

Plan a feature: explore → design doc → human approval → sized sub-issues + doc placeholders. Pass a parent issue number or a problem statement: `/feature_plan 2212` or `/feature_plan "returns for auction items"`.

## Instructions

### Step 1: Gather context

If `$ARGUMENTS` is an issue number, fetch it with comments and parent/sub-issue context:

```bash
gh issue view $ARGUMENTS --repo {{GITHUB_ORG}}/{{GITHUB_REPO}}
gh issue view $ARGUMENTS --repo {{GITHUB_ORG}}/{{GITHUB_REPO}} --json comments --jq '.comments[] | "[\(.createdAt)] \(.author.login): \(.body)"'
```

Otherwise treat `$ARGUMENTS` as the problem statement.

### Step 2: Explore the codebase (high altitude)

1. Search `docs/` for existing design docs, system docs, and gotchas in the affected area
2. Identify the models, controllers, services, and flows the feature touches
3. Note existing patterns to reuse and constraints (schema, jobs, permissions)

Shape-level understanding, not line-level planning — that happens per-issue in `/task_plan`. Blocked on a genuine design question? Suggest `/segue <question>`.

### Step 3: Write the design doc

Create `docs/plans/YYYY-MM-DD-<slug>-design.md` with sections:

- **Problem** — what and for whom
- **Constraints** — technical, product, and prior decisions
- **Approach** — the chosen shape, at component level
- **Rejected alternatives** — and why (stops re-litigation later)
- **Open questions** — anything unresolved (settle before issues, or mark explicitly deferred)
- **Decomposition** — proposed vertical slices (model → service → UI → notifications → e2e → docs, as applicable)
- **Docs impact** — which `docs/sop/` and `docs/system/` files will need creating or updating

### Step 4: GATE — design approval

Present a short summary: problem, approach, slice list with size estimates, open questions. **Wait for explicit approval.** The design doc is a proposal; issues are commitment. Iterate until approved.

### Step 5: Create issues

After approval:

1. Single-slice feature → one issue, no parent
2. Multi-slice → parent issue + one sub-issue per slice

Each sub-issue must have:
- Goal (1-2 sentences) + link to the design doc
- Acceptance criteria — **≤5 testable bullets** (more → split the slice)
- Size forecast targeting **100–600 added lines** per PR
- Dependencies on sibling slices noted in the body

Tier `{{TRACKER}}`. Follow only the matching branch.

**`github-projects`** — create the issues, link them, and put them on the board:

```bash
gh issue create --repo {{GITHUB_ORG}}/{{GITHUB_REPO}} --title "<title>" --body "<body>"

# Link each sub-issue to the parent
gh api graphql -f query='mutation { addSubIssue(input: { issueId: "<PARENT_NODE_ID>", subIssueId: "<CHILD_NODE_ID>" }) { issue { number } } }'

# Add each issue to the board (status defaults to Todo)
gh project item-add {{PROJECT_NUMBER}} --owner {{GITHUB_ORG}} --url <ISSUE_URL>
```

**`beads`** — create an epic and hang the slices off it as real dependencies:

```bash
bd create "<epic title>" --type epic --description "<goal + link to docs/plans/...>"
bd create "<slice title>" --type task --description "<goal, acceptance criteria, size forecast>"

# Child depends on parent. Argument order is child first, then parent.
bd dep add <CHILD_ID> <EPIC_ID> --type parent-child

# Verify the tree
bd children <EPIC_ID>
```

Dependencies between sibling slices are first-class here — use `bd dep add <BLOCKED_ID> <BLOCKER_ID>` rather than only noting them in the body. `bd ready` then hides work whose blockers are still open, which is what makes `/pick` accurate under this tier.

Always pass `--description`; `bd create` warns on issues without one, and a bare title is useless to the next session.

**`labels`** — create the issues and mark them Todo. There is no parent/child model, so record slice dependencies in the issue body:

```bash
gh issue create --repo {{GITHUB_ORG}}/{{GITHUB_REPO}} --title "<title>" --body "<body>" --label "status:todo"
```

### Step 6: Create doc placeholders

Per the design doc's **Docs impact** section, create placeholder files in `docs/sop/` and/or `docs/system/` (`**Status:** Draft — created for #<issue>`), and add them to the `.llm/README.md` index. They are completed or deleted at `/pr_submit` time — never left as drafts after the feature ships.

### Next step

```
Ready to start? Run: /pick   (or /task_plan <first-sub-issue>)
```

## Reference
- Repo: {{GITHUB_ORG}}/{{GITHUB_REPO}}
- Project: #{{PROJECT_NUMBER}} "{{PROJECT_NAME}}" (owner: {{GITHUB_ORG}}), Project ID: {{PROJECT_ID}}
- Status field ID: {{STATUS_FIELD_ID}}; Todo option: {{STATUS_TODO}}
- Design docs: `docs/plans/YYYY-MM-DD-<slug>-design.md`
- Sizing: PR 100–600 added lines / 5–15 files; acceptance criteria ≤5 bullets per issue
- Issue node IDs: `gh issue view <n> --json id --jq .id`
