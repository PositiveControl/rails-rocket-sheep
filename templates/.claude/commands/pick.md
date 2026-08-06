# Pick

Entry door to the workflow. Show **my** prioritized ready work, then route the selected item to the right next command based on its shape and state.

**Tracker tier: `{{TRACKER}}`** — one of `github-projects`, `beads`, `labels`. Resolved once by `/workflow_setup`; follow only the branch matching that literal.

## Instructions

### Step 0: Reconcile finished work (tiers `beads` and `labels` only)

Skip entirely under `github-projects` — its board automation already closes issues on merge.

The other tiers have no `Closes #n` equivalent, so reconcile lazily here instead of via CI or a webhook. Self-healing: if a session is skipped, the next one catches up.

**`beads`:**
```bash
bd list --label lifecycle:up_for_review --json
```
For each result, take its `external_ref` (`gh-<n>`, written by `/pr_submit`) and check whether that PR merged:
```bash
gh pr list --state merged --search "<n>" --json number,title --limit 5
```
Merged → `bd close <id>`. Report what was reconciled in one line; say nothing when there is nothing to close.

**`labels`:** same shape, using `gh issue list --label "status:up-for-review"` and closing merged ones with `gh issue close <n>`.

### Step 1: Fetch my open issues

```bash
gh issue list --assignee $(gh api user --jq .login) --repo {{GITHUB_ORG}}/{{GITHUB_REPO}} --state open --json number,title,labels --limit 100
```

Under `beads`, use the bead list as the source of work instead:
```bash
bd ready                          # open, no active blockers
bd list --status in_progress      # already claimed — NOT returned by bd ready
bd blocked                        # blocked, with blockers named
```

Run all three. `bd ready` applies blocker-aware semantics and **excludes anything already in progress**, so the second call is required for a complete picture — and `bd ready --assignee <name>` filters ready work down to items already assigned, which is usually empty. Don't substitute it for the pair.

### Step 2: Enrich with state

**Tier `github-projects`** — per issue, fetch project fields (status, priority, size, iteration, story points) + parent/sibling context via a single batched GraphQL query. One alias per issue; an alias must not start with a digit, so prefix `i` (e.g. `i1606: issue(number: 1606)`):

```graphql
{
  repository(owner: "{{GITHUB_ORG}}", name: "{{GITHUB_REPO}}") {
    i<NUMBER>: issue(number: <NUMBER>) {
      number
      title
      body
      projectItems(first: 5) {
        nodes {
          fieldValues(first: 10) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue { name field { ... on ProjectV2SingleSelectField { name } } }
              ... on ProjectV2ItemFieldIterationValue { title startDate duration field { ... on ProjectV2IterationField { name } } }
              ... on ProjectV2ItemFieldNumberValue { number field { ... on ProjectV2Field { name } } }
            }
          }
        }
      }
      parent { number title subIssues(first: 20) { nodes { number title state } } }
      subIssues(first: 20) { nodes { number title state } }
    }
  }
}
```

**Tier `beads`** — `bd ready` / `bd list` / `bd blocked` already carry status, priority, type, and assignee. For dependency context on a selected item:

```bash
bd show <id> --json      # full record, including external_ref
bd children <id>         # epic → child tree
bd dep tree <id>         # blockers and blocked-by
```

`bd` models dependencies natively, so the parent/sibling tree comes free rather than being reconstructed from sub-issue edges.

**Tier `labels`** — status comes from the `status:*` label already on each issue in Step 1. Parent/sibling context is unavailable; skip the tree. This tier trades context for having no setup.

### Step 3: Filter (optional iteration window)

If the team is running sprints and issues carry an active iteration, filter to items whose iteration contains today. Otherwise show all open assigned work. No matches → say so, offer the wider list.

### Step 4: Present prioritized summary

Sort: Priority (P0→P2→unset) → Status (Blocked→Todo→In Progress→Up for Review) → Size (XS→XL).

Markdown table: Priority, Status, Issue, Title, Size, Points, Labels. Below it, show a context tree for any item with a parent or sub-issues:

```
#930 [Bug]: Deleting Address Associated w/Shipment Error
  └─ Parent: #XXX Feature Name
     ├─ #YYY Sibling task (OPEN)
     ├─ #930 ← you are here (In Progress)
     └─ #ZZZ Another sibling (CLOSED) ✓
```

### Step 5: User selects → route

Fetch full details of the selection (`gh issue view <n>`), then route by shape + board state:

| Selected item | Route |
|---|---|
| Parent/epic with open sub-issues, OR no acceptance criteria, OR >5 acceptance bullets, OR size XL | `/feature_plan <n>` — decompose before any planning |
| Todo — sized leaf issue with acceptance criteria | `/task_plan <n>` |
| In Progress — task file exists in `.llm/tasks/` | `/implement <n>` |
| In Progress — no task file | `/task_plan <n>` (plan was never made or is lost) |
| Blocked | Show the blocker (dependency, question, PR); no route until cleared |
| Up for Review | Show PR status; suggest `/pr_fix_ci` or `/pr_comment_resolver` if red/commented |

State the route explicitly: "This is a sized Todo issue → run `/task_plan 1606`". Sizing is enforced here, at the door — an oversized or unshaped issue never goes straight to task planning.

## Reference
- Tracker tier: `{{TRACKER}}`
- GitHub username: `gh api user --jq .login`
- Repo: {{GITHUB_ORG}}/{{GITHUB_REPO}}
- Project (tier `github-projects`): #{{PROJECT_NUMBER}} "{{PROJECT_NAME}}" (owner: {{GITHUB_ORG}})
- Lifecycle states, and how each tier stores them:

  | State | `github-projects` | `beads` | `labels` |
  |---|---|---|---|
  | Todo | board status Todo | `status: open` | `status:todo` |
  | In Progress | board status In Progress | `status: in_progress` | `status:in-progress` |
  | Up for Review | board status Up for Review | `lifecycle=up_for_review` (label + event) | `status:up-for-review` |
  | Done | board status Done | `status: closed` | issue closed |
  | Blocked | board status Blocked | `status: blocked` / `bd blocked` | `status:blocked` |

  `beads` has no native "Up for Review" status — `bd set-state <id> lifecycle=up_for_review` records an event bead *and* attaches a queryable `lifecycle:up_for_review` label, which is what Step 0 reconciles against.
- Priority: P0, P1, P2 · Size: XS, S, M, L, XL
- Task files: `.llm/tasks/<issue>_<slug>.md`
- `gh` commands fail → suggest `gh auth status`
- `bd` commands fail with "no beads database found" → beads needs a running `dolt sql-server`. Suggest starting it, then `bd init`. See `docs/sop/beads-setup.md`
