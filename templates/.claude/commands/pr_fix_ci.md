# Fix CI

Diagnose and fix CI/CD pipeline failures on current branch's PR. Pass PR number as argument: `/fix_ci 2038`

## Instructions

### Step 1: Identify the PR and failed checks

Fetch PR metadata and CI check results:

```bash
gh pr view $ARGUMENTS --repo {{GITHUB_ORG}}/{{GITHUB_REPO}} --json number,title,url,headRefName,baseRefName,additions,deletions,changedFiles
```

```bash
gh pr checks $ARGUMENTS --repo {{GITHUB_ORG}}/{{GITHUB_REPO}} --json name,state,link,workflow
```

Show brief summary: PR title, branch, table of all checks with status.

Verify on PR's branch. If not, check out:
```bash
git checkout <headRefName>
git pull
```

### Step 2: Classify failures

Split failures into categories:

1. **Code failures** — caused by code on branch (lint, tests, security scans)
2. **Infrastructure failures** — caused by CI environment (package install errors, network timeouts, service unavailability, Docker issues)
3. **Flaky/pre-existing failures** — also fail on main, or non-deterministic

For each failed check, fetch failure logs:
```bash
gh run view <RUN_ID> --job <JOB_ID> --log-failed
```

Extract run ID and job ID from check URL. URL format:
`https://github.com/<org>/<repo>/actions/runs/<RUN_ID>/job/<JOB_ID>`

If `--log-failed` output too big or unclear, fetch full job log, grep error patterns:
```bash
gh run view <RUN_ID> --job <JOB_ID> --log 2>&1 | grep -i "error\|fail\|FAILED\|Error:" | tail -30
```

### Step 3: Present diagnosis to user

Before any change, show findings:

```
## PR #<NUMBER> CI Diagnosis

### Failed checks: <count>

#### Code failures (fixable)
- <check_name> — <root cause summary>
  Fix: <proposed fix>

#### Infrastructure failures (retry)
- <check_name> — <root cause summary>
  Action: Re-run job (not a code issue)

#### Flaky / pre-existing (ignore)
- <check_name> — <root cause summary>
  Evidence: <why this isn't caused by the branch>

### Passing checks
- <check_name>: ✓
```

Ask user:
1. Proceed with proposed fixes for code failures?
2. Re-run infrastructure failures?
3. Any items need different handling?

### Step 4: Fix code failures

Fix each code failure by category:

**`db_drifts`** — Schema out of sync with migrations:
1. Run `bin/rails db:migrate` to regenerate schema.rb
2. Check `git diff db/schema.rb` — verify changes make sense
3. Stage and commit regenerated schema

**lint** — linter violations:
1. Run the linter on changed files:
   ```bash
   git diff-tree -r --no-commit-id --name-only origin/main HEAD | xargs ls -1 2>/dev/null | xargs bin/rubocop --force-exclusion
   ```
2. If auto-fix doesn't resolve all issues, manually fix remaining violations
3. Commit the fixes

**`test`** — Test failures:
1. Read the failure output carefully to identify failing test(s) and error messages
2. Determine if the failure is **branch-introduced** or **pre-existing**:
   - Check if the failing test file was modified on this branch: `git diff --name-only origin/main..HEAD`
   - Check if the failing test relates to code changed on this branch
   - If uncertain, check if the same test fails on main:
     ```bash
     git stash && git checkout main && bin/test <failing_test_file> && git checkout - && git stash pop
     ```
3. For branch-introduced failures: diagnose and fix the root cause
4. For pre-existing failures: note them in the report but do not block

**security scans** — scan failures:
1. Read the security scanner output
2. Fix the identified vulnerability
3. If it's a false positive, add an appropriate ignore annotation with a comment explaining why

**`db_drifts` common patterns:**
- After rebase: schema.rb may contain tables/columns from conflict resolution that don't have corresponding migrations on the branch. Regenerate from migrations.
- Missing migration: a migration file may have been lost during rebase. Check `git log --diff-filter=D -- db/migrate/` for deleted migrations.
- Version mismatch: schema version header doesn't match the latest migration timestamp. Regenerate.

### Step 5: Commit and push fixes

Group related fixes into logical commits:

```bash
git add <files>
git commit -m "<descriptive message>

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

Push:
```bash
git push
```

### Step 6: Re-run infrastructure failures

If there were infrastructure failures that aren't code-related, re-run them:

```bash
gh run rerun <RUN_ID> --failed
```

If the re-run option isn't available (e.g., a new run was triggered by the push), note that CI will re-run automatically.

### Step 7: Poll CI results

Poll all checks to confirm fixes resolved the failures:

```bash
gh pr checks $ARGUMENTS --repo {{GITHUB_ORG}}/{{GITHUB_REPO}} --json name,state,link --jq '.[] | "\(.name): \(.state)"'
```

Polling loop:
1. Fetch all check statuses
2. If any are `PENDING` or `IN_PROGRESS`, wait 30 seconds and re-check
3. After all checks are terminal (SUCCESS/FAILURE/SKIPPED), proceed to report
4. After 10 minutes of polling, proceed with whatever status is available
5. Ignore `CodeQL` / `Analyze` checks — these are informational and not blocking

If any code failure persists after the fix:
1. Fetch the new failure logs
2. Diagnose the new error
3. Fix and push again
4. Maximum **3 fix iterations** before escalating to the user

### Step 8: Final report

```
## PR #<NUMBER> CI Resolution

### Status: <all green / partially resolved / needs attention>

### Resolved
- <check_name>: <what was wrong> → <what was fixed> (<commit SHA>)

### Re-run (infrastructure)
- <check_name>: <status after re-run>

### Pre-existing / ignored
- <check_name>: <reason for ignoring>

### Still failing (if any)
- <check_name>: <what was tried> — needs manual investigation

### Commits
- <SHA> — <message>

PR URL: <URL>
```

## Reference
- GitHub username: Use `gh api user --jq .login` to get the current user's GitHub username
- Repo: {{GITHUB_ORG}}/{{GITHUB_REPO}}
- CI checks: scan_ruby, scan_js, lint (fast), test (slow)
- Informational checks (non-blocking): CodeQL / Analyze
- CI check `state` values: PENDING, IN_PROGRESS, SUCCESS, FAILURE, SKIPPED
- CI check URL format: `https://github.com/<org>/<repo>/actions/runs/<RUN_ID>/job/<JOB_ID>`
- Failure log command: `gh run view <RUN_ID> --job <JOB_ID> --log-failed`
- Re-run failed jobs: `gh run rerun <RUN_ID> --failed`
- Schema regeneration: `bin/rails db:migrate` (dumps fresh schema.rb)
- Lint auto-fix: bin/rubocop -a
- Security scan: `bin/brakeman -q --no-pager`
- Max fix iterations: 3 before escalating to user
- Pre-existing test failures: check if same test fails on main before fixing