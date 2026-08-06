# Pick

Entry door to the workflow. Show **my** prioritized ready work from GitHub Projects, then route the selected item to the right next command based on its shape and board state.

## Instructions

### Step 1: Fetch my open issues

```bash
gh issue list --assignee $(gh api user --jq .login) --repo {{GITHUB_ORG}}/{{GITHUB_REPO}} --state open --json number,title,labels --limit 100
```

### Step 2: Enrich with project board data

Per issue: fetch project fields (status, priority, size, iteration, story points) + parent/sibling context via a single batched GraphQL query — one alias per issue (alias must not start with a digit; prefix `i`, e.g. `i1606: issue(number: 1606)`):

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
- GitHub username: `gh api user --jq .login`
- Repo: {{GITHUB_ORG}}/{{GITHUB_REPO}}
- Project: #{{PROJECT_NUMBER}} "{{PROJECT_NAME}}" (owner: {{GITHUB_ORG}})
- Board statuses: Blocked, Todo, In Progress, Up for Review, Done
- Priority: P0, P1, P2 · Size: XS, S, M, L, XL
- Task files: `.llm/tasks/<issue>_<slug>.md`
- `gh` commands fail → suggest `gh auth status`
