# PR Comment Resolver

Fetch review comments on PR, address them, resolve conversations. Pass PR number as argument: `/pr_comment_resolver 1760`

## Instructions

### Step 1: Fetch PR context

Gather PR metadata, check out correct branch:

```bash
gh pr view $ARGUMENTS --repo {{GITHUB_ORG}}/{{GITHUB_REPO}} --json number,title,url,headRefName,baseRefName,author,additions,deletions,changedFiles
```

Show brief summary: PR title, branch, lines changed.

Verify on PR's branch. If not, check out:
```bash
git checkout <headRefName>
git pull
```

### Step 2: Fetch all review comments

Fetch both inline code comments and top-level reviews:

**Inline review comments (code-level):**
```bash
gh api repos/{{GITHUB_ORG}}/{{GITHUB_REPO}}/pulls/$ARGUMENTS/comments --jq '.[] | {id: .id, author: .user.login, path: .path, line: .line, body: .body, in_reply_to_id: .in_reply_to_id, created_at: .created_at}'
```

**Top-level reviews:**
```bash
gh pr view $ARGUMENTS --repo {{GITHUB_ORG}}/{{GITHUB_REPO}} --json reviews --jq '.reviews[] | "[\(.state)] \(.author.login): \(.body[:200])"'
```

**Issue-level comments (general discussion):**
```bash
gh api repos/{{GITHUB_ORG}}/{{GITHUB_REPO}}/issues/$ARGUMENTS/comments --jq '.[] | {id: .id, author: .user.login, body: .body[:300], created_at: .created_at}'
```

### Step 3: Categorize comments

Parse, categorize all comments:

1. **Filter out already-resolved threads** — comments with reply threads where PR author already responded with fix
2. **Separate by source:**
   - `github-code-quality[bot]` and `copilot-pull-request-reviewer` — automated reviewers
   - Human reviewers — need more careful consideration
3. **Prioritize by severity:**
   - **Blocking**: bugs, security issues, logic errors, missing tests
   - **Suggestions**: code clarity, naming, edge cases, pattern consistency
   - **Noise**: bot false positives (e.g., "database query in a loop" on test files, overly cautious warnings)

### Step 4: Present summary to user

Before any changes, present comment summary:

```
## PR #<NUMBER> Review Comments

### Unresolved comments: <count>

#### Automated (<bot_name>)
- [ ] <path>:<line> — <brief description> (id: <comment_id>)

#### Human (<reviewer_name>)
- [ ] <path>:<line> — <brief description> (id: <comment_id>)

#### Likely noise (recommend skipping)
- <path>:<line> — <brief description> — Reason: <why it's noise>
```

Ask user:
1. Which comments to address (default: all non-noise)
2. Whether any "noise" comments should be addressed anyway
3. Whether any human comments need discussion before fixing

### Step 5: Address comments

Per comment:

1. **Read full file** — context around flagged line
2. **Understand concern** — what reviewer asks for, specifically?
3. **Make fix** — edit file, address comment
4. **Verify fix** — no obvious breakage

Group related fixes into logical commits. After all fixes:

```bash
bin/rubocop --force-exclusion <changed_files>
```

Fix lint issues introduced by changes.

Commit with descriptive message:
```bash
git commit -m "Address PR review comments

- <brief description of each fix>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

### Step 6: Push and resolve conversations

Push fixes:
```bash
git push
```

Per addressed comment, reply to resolve conversation:
```bash
gh api repos/{{GITHUB_ORG}}/{{GITHUB_REPO}}/pulls/<PR_NUMBER>/comments/<COMMENT_ID>/replies -X POST -f body="Addressed — <brief description of fix>. See <COMMIT_SHA>."
```

### Step 7: Verify fast CI checks

Poll fast CI checks — confirm fixes break nothing:

```bash
gh pr checks $ARGUMENTS --repo {{GITHUB_ORG}}/{{GITHUB_REPO}} --json name,state,link --jq '.[] | select(["scan_ruby","scan_js","lint"] | index(.name)) | "\(.name): \(.state)"'
```

Fast check fails after push → diagnose, fix before reporting.

### Step 8: Report

Present final status:

```
PR #<NUMBER> comments addressed
  URL: <PR_URL>
  Comments resolved: <count>
  Comments skipped (noise): <count>
  Fast checks: <status>
  Commits: <commit SHAs>
```

Human comments deferred for discussion → remind user.

## Reference
- GitHub username: `gh api user --jq .login` gets current user's GitHub username
- Repo: {{GITHUB_ORG}}/{{GITHUB_REPO}}
- Fast CI checks: scan_ruby, scan_js, lint
- Bot reviewers: github-code-quality[bot], copilot-pull-request-reviewer
- Reply endpoint: `repos/{{GITHUB_ORG}}/{{GITHUB_REPO}}/pulls/<PR>/comments/<ID>/replies`
- CI check `state` values: PENDING, IN_PROGRESS, SUCCESS, FAILURE, SKIPPED