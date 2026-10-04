---
description: "Explore a feature, write its design doc, cut sized sub-issues"
argument-hint: '<issue number | "problem statement">'
---

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

**Already designed?** If `$ARGUMENTS` names a feature whose design doc already says `Approved at G1`, and the developer is asking to put it on autopilot, this is a **G1 amendment**. Go straight to *Autopilot on an already-approved design* in Step 4b, and skip everything else. The design is settled, so do not explore or rewrite it.

### Step 2: Explore the codebase (high altitude)

1. Search `docs/` for existing design docs, system docs, and gotchas in the affected area
2. Identify the models, controllers, services, and flows the feature touches
3. Note existing patterns to reuse and constraints (schema, jobs, permissions)

Shape-level understanding, not line-level planning — that happens per-issue in `/task_plan`. Blocked on a genuine design question? Suggest `/segue <question>`. External fact missing (how a gem behaves, what an API returns)? Suggest `/research <question>`.

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

Open questions the user cannot answer off the top of their head, or an approach resting on assumptions nobody has tested → suggest `/grill "<the feature>"` before asking for approval again. Arriving at the gate with an empty frontier is the point; the approval is still theirs.

### Step 4b: Autopilot — multi-slice features only

Once the design is approved, ask one more question: **run this feature on autopilot?** The default is **no**. Autopilot takes the slices from here to a ready feature PR with nobody at the keyboard, answering each gate from the policy in `docs/system/autopilot-steps.md` and recording every answer in an autopilot log. G1 (this gate) and the merge to `main` stay human.

On **yes**, show the policy's defaults and the halt list, and ask for changes: an exception scoped to one slice's acceptance criteria, a stricter row, or none. Those changes are part of what was approved. Step 6b writes them down. A single-slice feature never runs on autopilot; its PR targets `main`, where the merge is human anyway.

**Autopilot on an already-approved design.** `$ARGUMENTS` names a feature whose design doc already says `Approved at G1`, and the developer asks to put it on autopilot: this is a **G1 amendment**, and it is the only step that runs. Show the policy for the slices still open (from the feature PR's **Slices** list), take the developer's changes, and on approval write the flag line and the log as in Step 6b, committed on `feature/<slug>` and pushed, since that branch is where the driver reads them. Skip Steps 5 and 6: the issues and placeholders exist.

### Step 5: Create issues

After approval:

1. Single-slice feature → one issue, no parent, PR straight to `main`
2. Multi-slice → parent issue + one sub-issue per slice, landing on a **feature branch** `feature/<slug>` (the design doc's slug). Write `**Feature branch:** feature/<slug>` at the top of the design doc and `Feature branch: feature/<slug>` in every sub-issue body — `/task_plan` reads it there and creates the branch when it plans the first slice. Spec: `WORKFLOW.md`, *Feature branches*.

Each sub-issue must have:
- Goal (1-2 sentences) + link to the design doc
- The feature branch line, when multi-slice
- Acceptance criteria — **≤5 testable bullets** (more → split the slice)
- Size forecast targeting **200–1,500 added lines** per PR
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

Per the design doc's **Docs impact** section, create placeholder files in `docs/sop/` and/or `docs/system/` (`**Status:** Draft — created for #<issue>`), and add them to the `.llm/README.md` index. A slice's `/pr_submit` completes the ones its work fills in; the feature PR to `main` is where the rest are completed or deleted — never left as drafts after the feature ships.

### Step 6b: Autopilot log — only on a yes at Step 4b

1. Under the design doc's `**Feature branch:**` line, write:
   ```markdown
   **Autopilot:** on — log: docs/plans/YYYY-MM-DD-<slug>-autopilot.md
   ```
2. Create that file from the template in `docs/system/autopilot.md` (*The autopilot log template*): the header, and *Policy accepted at G1*. Copy the whole policy table and halt list from `docs/system/autopilot-steps.md` (*Policy*) into it, apply the developer's changes from Step 4b in place, and list those changes (or "none"). The copy is this feature's policy from now on; later edits to the system doc do not reach it.
3. Index it in `.llm/README.md` beside the design doc.

It ships in the same commit as the design doc, and has to reach `main` before the first slice is planned: the feature branch is cut from `main`, and the activation check reads the design doc on the feature branch the slice is cut from. The run starts with `bin/autopilot <slug>`, not `/pick`.

### Next step

```
Ready to start? Run: /pick   (or /task_plan <first-sub-issue>)
```

On autopilot: `Ready to run. Start: bin/autopilot <slug>` (setup and resume: `docs/sop/run-a-feature-on-autopilot.md`).

## Reference
- Repo: {{GITHUB_ORG}}/{{GITHUB_REPO}}
- Project: #{{PROJECT_NUMBER}} "{{PROJECT_NAME}}" (owner: {{GITHUB_ORG}}), Project ID: {{PROJECT_ID}}
- Status field ID: {{STATUS_FIELD_ID}}; Todo option: {{STATUS_TODO}}
- Design docs: `docs/plans/YYYY-MM-DD-<slug>-design.md`
- Sizing: PR 200–1,500 added lines / ≤25 files; acceptance criteria ≤5 bullets per issue
- Issue node IDs: `gh issue view <n> --json id --jq .id`
- Autopilot: `docs/system/autopilot-steps.md` — activation, policy; `docs/system/autopilot.md` — log template. Asked at Step 4b, multi-slice only, default no
