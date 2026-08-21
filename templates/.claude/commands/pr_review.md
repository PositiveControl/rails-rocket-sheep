---
description: "Reviewer side: full-context review of someone else's PR"
argument-hint: "<PR number>"
---

# PR Code Review

Review another contributor's pull request, post feedback. Pass PR number as argument: `/pr_review 42`

## Instructions

### Step 1: Fetch PR context

Gather all PR context:

```bash
gh pr view $ARGUMENTS --repo {{GITHUB_ORG}}/{{GITHUB_REPO}} --json number,title,body,author,baseRefName,headRefName,additions,deletions,changedFiles,labels,reviews,comments
```

Show brief summary: PR title, author, base ← head, lines changed, file count.

Base ref is not `main` → the PR sits in a stack, so check its footer list is current:

```bash
bin/pr-stack --check $ARGUMENTS
```

Exit 1 means one or more members' bodies still show a stale order — something landed on top since they were written. Don't rewrite the author's PR bodies mid-review: note it under **Nitpicks** ("stack footer stale — run `bin/pr-stack`") and trust the chain the script prints over anything the bodies claim. Prints `not stacked` and exits 0 for a `main`-based PR.

The printed chain also tells you what's below this PR — review the diff against its **own base**, not `main`, or you'll flag code that a lower PR in the stack already introduced.

### Step 2: Fetch the diff

Get full diff:

```bash
gh pr diff $ARGUMENTS --repo {{GITHUB_ORG}}/{{GITHUB_REPO}}
```

Diff very large (50+ files or 2000+ lines)? Tell user, review most critical files first (models, controllers, services, migrations).

### Step 3: Identify changed files and read full context

List changed files:

```bash
gh pr diff $ARGUMENTS --repo {{GITHUB_ORG}}/{{GITHUB_REPO}} --name-only
```

Each non-trivial changed file: read full file, not just diff. Critical — diff without full-file context gives shallow feedback.

Read priority:
1. Database migrations
2. Models (validations, associations, scopes, callbacks)
3. Controllers
4. Services / business logic
5. Views
6. Tests
7. Config / routes

Skip full context for trivial changes (whitespace, comment-only, auto-generated files like `schema.rb`).

**Important:** Read file context from PR's base branch (usually `main`), not current working branch. Use `git show main:<path>` to read files as on main. Current branch may have unmerged changes absent from PR base — wrong review findings result.

### Step 4: Review existing feedback

Before own assessment, read all existing review comments. Avoids duplicating points, builds on conversation.

1. **Fetch all inline review comments** (human + bot):
   ```bash
   gh api repos/{{GITHUB_ORG}}/{{GITHUB_REPO}}/pulls/<PR_NUMBER>/comments
   ```

2. **Fetch issue-level comments** (general discussion, not tied to specific lines):
   ```bash
   gh api repos/{{GITHUB_ORG}}/{{GITHUB_REPO}}/issues/<PR_NUMBER>/comments
   ```

3. **Parse and categorize the feedback:**
   - Separate human reviewer comments from bot comments (Copilot, etc.)
   - Note which comments have reply threads (check `in_reply_to_id` field)
   - Identify unresolved concerns vs. acknowledged/addressed ones
   - Pay attention to the PR's existing review states (from Step 1's `reviews` field): who approved, who requested changes, who left comments

4. **Build a mental summary** of the existing feedback landscape before proceeding:
   - What points have already been raised by other reviewers?
   - Has the author responded to or addressed any of them?
   - Are there open threads or unresolved concerns?

**When writing your review:**
- **Do NOT re-raise points** that another reviewer has already flagged, unless you have something substantive to add. Instead, reference their comment (e.g., "+1 to @elorest's concern about X — additionally, Y").
- **Do explicitly agree** with existing comments when relevant — this signals consensus and helps the author prioritize.
- **Do flag if an existing concern appears unaddressed** — "I notice @reviewer flagged X and it doesn't appear to be resolved yet."

### Step 5: Load review standards

Read `CLAUDE.md` for the non-negotiables, then use `docs/rules/INDEX.md` to pull the rules matching the changed files. Those are the primary review criteria for Step 6, alongside the general criteria below.

### Step 6: Read relevant project documentation

Before reviewing, check for relevant docs that establish conventions:

1. Read `CLAUDE.md` for project conventions (already in context)
2. Check if the PR relates to a task file:
   ```bash
   ls .llm/tasks/ | grep -i "<keywords from PR title>"
   ```
3. Read any relevant `.llm/` documentation for the area being changed

### Step 7: Analyze and categorize findings

Review the code using the criteria from the language-specific review doc (Step 5). If no specific doc applies, use these general criteria. **Cross-reference with existing feedback from Step 4** — do not duplicate points already raised by other reviewers.

**Blocking (request changes):**
- Bugs or logic errors
- Security vulnerabilities (injection, XSS, mass assignment, etc.)
- Data integrity issues (missing validations, unsafe migrations, race conditions)
- Seeds left out of step: a new model, process, or dependency landed without a matching idempotent `db/seeds.rb` update (`docs/rules/seeds.md`)
- Missing or broken tests for new behavior
- Significant performance issues

**Suggestions (non-blocking comments):**
- Code clarity and naming
- Missing edge case handling
- Opportunities to follow existing project conventions
- Test coverage gaps for edge cases
- Consistency with existing codebase patterns

**Nitpicks (prefix with "nit:"):**
- Style issues not caught by linters
- Minor naming preferences
- Documentation suggestions

**Positive feedback:**
- Call out well-designed code, clever solutions, or good test coverage — reviews should not be exclusively negative

### Step 8: Present review to user before posting

Before posting anything to GitHub, present the full review to the user in this format:

```
## PR #<NUMBER> Review Summary

**Overall assessment:** <approve / request changes / comment only>
**Risk level:** <low / medium / high> — <one line explanation>

### Existing feedback summary
<Brief summary of what other reviewers have already flagged. Note any unresolved concerns.>

### Blocking issues
- [ ] <file:line> — <description>

### Suggestions
- <file:line> — <description>

### Nitpicks
- <file:line> — nit: <description>

### Positive notes
- <description>

### Questions for the author
- <any ambiguities or design questions>
```

Ask the user:
1. Whether to post the review as-is
2. Whether to adjust severity on any items (e.g., downgrade a blocker to a suggestion)
3. Whether to add or remove any comments
4. What review action to take: APPROVE, REQUEST_CHANGES, or COMMENT

### Step 9: Post the review to GitHub

Once the user confirms, submit the review using the GitHub API.

**Important:** Use `--input -` with a heredoc to pass raw JSON. The `gh` CLI's `-f 'comments[0][path]=...'` syntax does NOT work for arrays — it creates a hash instead. Always use raw JSON for reviews with inline comments.

Use `line` (file line number) and `side` ("RIGHT" for additions, "LEFT" for deletions) to position comments.

**Review with inline comments:**

```bash
gh api repos/{{GITHUB_ORG}}/{{GITHUB_REPO}}/pulls/<PR_NUMBER>/reviews -X POST \
  --input - <<'EOF'
{
  "event": "<APPROVE|REQUEST_CHANGES|COMMENT>",
  "body": "<overall review summary>",
  "comments": [
    {
      "path": "path/to/file.rb",
      "line": 42,
      "side": "RIGHT",
      "body": "Comment text here"
    },
    {
      "path": "path/to/other.rb",
      "line": 10,
      "side": "RIGHT",
      "body": "Another comment"
    }
  ]
}
EOF
```

**Review without inline comments:**

```bash
gh api repos/{{GITHUB_ORG}}/{{GITHUB_REPO}}/pulls/<PR_NUMBER>/reviews -X POST \
  --input - <<'EOF'
{
  "event": "<APPROVE|REQUEST_CHANGES|COMMENT>",
  "body": "<overall review summary>"
}
EOF
```

### Step 10: Report result

After posting, display:

```
✓ Review posted on PR #<NUMBER>
  Action: <APPROVE / REQUEST_CHANGES / COMMENT>
  Inline comments: <count>
  URL: <review URL>
```

## Review principles

- **Be constructive.** Frame feedback as suggestions when possible, not demands. Use "Consider..." or "What do you think about..." for non-blocking items.
- **Explain the why.** Don't just say something is wrong — explain what could go wrong and suggest a fix.
- **Respect the author's approach.** If their solution works and is readable, don't rewrite it in your preferred style. Only push back on genuine issues.
- **Be specific.** Reference exact lines, show code examples for suggested changes, link to relevant docs or patterns in the codebase.
- **Assume good intent.** If something looks wrong, it may be intentional — ask before assuming it's a mistake.
- **Keep it proportional.** A 5-line bug fix doesn't need 20 comments. Scale review depth to PR size and risk.

## Reference
- GitHub username: Use `gh api user --jq .login` to get the current user's GitHub username
- Repo: {{GITHUB_ORG}}/{{GITHUB_REPO}}
- Use `gh api` for review submission (not `gh pr review` which has limited comment support)
- Diff position vs line number: prefer `line` + `side` over `position` for accuracy
- Review events: APPROVE, REQUEST_CHANGES, COMMENT
- PR title convention: `{{PR_TITLE_PREFIX}} | <issue_number> | <description>`
- Stacked PRs: `bin/pr-stack --check <PR>` prints the chain and flags a stale footer (exit 1); review against the PR's own base, not `main`