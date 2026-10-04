---
description: "Address the review comments on a PR and resolve the threads"
argument-hint: "<PR number>"
---

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

**Autopilot (gate `comments`)** — active when the check in `docs/system/autopilot-steps.md` (*Activation*) passes with `<BASE>` = `baseRefName`:
- Ask nothing.
- Sort every comment by *Whose comment is it* in that doc, not by author login: the self-review passes post from the developer's own account.
- **Any comment from a person is a `halt`.** Someone is watching this slice and has something to say, and the run should not answer for them.
- Otherwise address every non-noise comment and log the skipped noise in one entry.
- For each self-review finding, verify it before fixing it, as `/implement` Step 5 items 3–5 do. A finding you would drop needs a probe (gate `fix-drop` on pass 1, `pass-2` on pass 2), and the drop is logged with it.

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

Co-Authored-By: <your agent's co-author line, if it has one>"
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

**Autopilot:** end every reply body with the marker `<!-- autopilot -->`. It is invisible on GitHub. A dropped finding gets a reply too: `Dropped — probe: <command and result>. <!-- autopilot -->`.

### Step 7: Verify fast CI checks

Poll fast CI checks — confirm fixes break nothing:

```bash
gh pr checks $ARGUMENTS --repo {{GITHUB_ORG}}/{{GITHUB_REPO}} --json name,state,link --jq '.[] | select([{{FAST_CI_CHECKS_JQ}}] | index(.name)) | "\(.name): \(.state)"'
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
- Fast CI checks: {{FAST_CI_CHECKS}}
- Bot reviewers: github-code-quality[bot], copilot-pull-request-reviewer
- Reply endpoint: `repos/{{GITHUB_ORG}}/{{GITHUB_REPO}}/pulls/<PR>/comments/<ID>/replies`
- Autopilot: `docs/system/autopilot-steps.md` — activation check, policy by gate id (`comments`, `fix-drop`, `pass-2`, `halt` here), whose comment is whose
- CI check `state` values: PENDING, IN_PROGRESS, SUCCESS, FAILURE, SKIPPED
