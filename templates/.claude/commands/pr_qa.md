---
description: "Guided manual QA pass over a PR, ending in a structured report"
argument-hint: "<PR number>"
---

# PR QA

Guide a manual QA pass over a pull request from start to finish, then write the
report into `docs/qa/`. This covers what automated tests do not: the clicking. The
suite and the lint run belong to `/pr_submit`. Pass the PR number: `/pr_qa 1760`.

## Instructions

### Step 1: Fetch the PR

```bash
gh pr view $ARGUMENTS --repo {{GITHUB_ORG}}/{{GITHUB_REPO}} --json number,title,body,author,headRefName,baseRefName,additions,deletions,changedFiles,files
gh pr diff $ARGUMENTS --repo {{GITHUB_ORG}}/{{GITHUB_REPO}}
```

Read the linked issue too if the body references one. Screenshots, videos, and
"known limitations" in the description all shape what is worth testing.

### Step 2: Separate what the author claims from what changed

List the author's claims, the acceptance criteria, and any stated limitation.
Then read the diff and classify every change:

| Class | Why it matters for QA |
|---|---|
| UI only | Visual and responsive checks, no data setup |
| Business logic | Needs specific records to exercise each branch |
| Database | Migration order, backfills, existing rows |
| Authorization | Needs more than one role to test |
| Background job | Needs the worker running; check the async path, not just the enqueue |
| External integration | Needs a sandbox account or a recorded cassette |
| Bug fix | Reproduce the original bug first, then confirm the fix |
| Refactor | Regression risk with no new behaviour to test |
| Test or internal only | Usually nothing to click |

Where the description and the diff disagree, say so before planning anything. A
mismatch is the highest-value finding in this whole pass.

### Step 3: Derive the scenarios

Per behaviour change, name the happy path, the edge cases, the failure cases, the
role and permission cases, the regressions worth re-checking, and any scenario
that depends on data state (empty, one record, many, soft-deleted).

Do not stop at the first obvious case. The point of a manual pass is the cases a
fixture would not have.

### Step 4: Build the plan

One block per test area, each with:

- **What changed** and why it needs a human
- **Where to test**: page, Rails path, direct URL, controller action if useful
- **Who to be**: the role, and whether more than one role needs testing
- **Setup**: records, seeds, feature flags, associations, a running worker, a
  device or viewport
- **Steps**: numbered, concrete, no vague wording
- **Expected result** after each meaningful action
- **Extra checks**: edge cases, validation errors, authorization, responsive

Unknown route? Infer it from the controllers, views, and routes rather than
guessing, and say what the inference rests on. Unknown role? Infer it from the
policies and the conditionals in the views.

### Step 5: Run the pass with the tester

Work one area at a time. As results come back, track each case as pass, fail,
partial, or blocked, ask the targeted follow-up when an answer is ambiguous, and
help separate a real bug from expected behaviour from an unclear requirement.

### Step 6: Write the report

Write it to `docs/qa/<pr-number>-<slug>.md`, which is the directory the doc canon
gives this command, and add a line for it in `.llm/README.md` between the `qa`
markers. Sections:

- Summary of the PR and what was in scope
- Cases executed, with pass, fail, partial, blocked
- Failures, each with steps to reproduce
- Blocked or unverifiable, and what was missing
- Risks, suspected regressions, and gaps in coverage
- Recommended follow-ups
- Final status: pass, pass with concerns, needs fixes, or blocked

Then report the same summary in the session, and name what runs next:
`/pr_comment_resolver` if the review left comments, `/pr_submit` if fixes landed.

## Reference
- Repo: {{GITHUB_ORG}}/{{GITHUB_REPO}}
- QA guides live in `docs/qa/`, indexed in `.llm/README.md` between the `qa` markers
- Testing conventions, and which layer covers what: `docs/rules/testing.md`
- A flow worth testing twice is a flow worth a system test; say so in the report
- Roles and record-level rules: `docs/rules/policy-objects.md`
- `gh` commands fail → suggest `gh auth status`
