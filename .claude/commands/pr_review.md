---
description: "Full-context PR review — someone else's, or your own slice from a fresh session"
argument-hint: "<PR number> | --local <base>"
---

# PR Code Review

Review a pull request and post feedback — another contributor's, or your own slice PR from a session that did not write it (see *Self-review of a slice*). Pass PR number as argument: `/pr_review 42`

## Instructions

### Local mode: `/pr_review --local <base>`

No PR yet — the pre-PR review `/implement` Step 5 runs in a fresh-context agent. Same review, different edges:

- **Diff** = `git diff <base>...HEAD` (and `--name-only`) in place of `gh pr diff`; base-side files via `git show <base>:<path>`. `<base>` is a remote branch (`git fetch` it first) or, in round 2, a SHA.
- **Skip** Step 1 (read the task file for the issue in the branch name instead), Step 4 (no comments exist), Steps 10–11.
- **Every blocker states a failure scenario**: this input or state → this wrong result, at `file:line`. Can't write one → it goes under **Questions for the author**, not **Blocking issues**. The calling agent checks each finding against the code before it commits a fix; a scenario is what it checks.
- The prompt may list settled findings — dropped, or changed on purpose in an earlier round. Leave them out unless you think the ruling or the change is wrong: then list it under **Questions for the author** with your reason.
- **Step 9** → its summary, minus *Existing feedback summary*, is your final message to the calling agent. Ask the user nothing and post nothing. Nothing to report → say so plainly: `No blockers, suggestions or nitpicks.`
- Read-only: no edits, commits or pushes. The calling agent owns the fixes.

### Step 1: Fetch PR context

Gather all PR context:

```bash
gh pr view $ARGUMENTS --repo PositiveControl/rails-rocket-sheep --json number,title,body,author,baseRefName,headRefName,additions,deletions,changedFiles,labels,reviews,comments
```

Show brief summary: PR title, author, base ← head, lines changed, file count.

Author is you and the base is a feature branch → this is a **self-review pass**. Read *Self-review of a slice* below before Step 2; the steps are the same, the ending differs.

A self-review pass checks whether autopilot is active, with `<BASE>` = `baseRefName` (`docs/system/autopilot-steps.md`, *Activation*). If it is, the *Autopilot* paragraphs below replace the questions they follow.

Base ref is not `main` → the PR is a slice of a feature branch (see `WORKFLOW.md`, *Feature branches*). Review the diff against its **own base**, not `main`, or you'll flag code an earlier slice already landed. The base is `baseRefName` from the query above; every `main` below means that base.

### Step 2: Fetch the diff

Get full diff:

```bash
gh pr diff $ARGUMENTS --repo PositiveControl/rails-rocket-sheep
```

Diff very large (50+ files or 2000+ lines)? Tell user, review most critical files first (models, controllers, services, migrations).

### Step 3: Identify changed files and read full context

List changed files:

```bash
gh pr diff $ARGUMENTS --repo PositiveControl/rails-rocket-sheep --name-only
```

Each non-trivial changed file: read full file, not just diff. Critical — diff without full-file context gives shallow feedback.

Read priority:
1. Database migrations, and the `db/queries.yml` hunk — every new entry is a query this PR added, with a review line CI could only check the shape of
2. Models (validations, associations, scopes, callbacks)
3. Controllers
4. Services / business logic
5. Views
6. Tests
7. Config / routes

Skip full context for trivial changes (whitespace, comment-only, auto-generated files like `schema.rb`).

**Important:** Read file context from the PR's base branch, not current working branch. Use `git show origin/<base>:<path>` to read files as they are on the base. Current branch may have unmerged changes absent from PR base — wrong review findings result.

### Step 4: Review existing feedback

Before own assessment, read all existing review comments. Avoids duplicating points, builds on conversation.

1. **Fetch all inline review comments** (human + bot):
   ```bash
   gh api repos/PositiveControl/rails-rocket-sheep/pulls/<PR_NUMBER>/comments
   ```

2. **Fetch issue-level comments** (general discussion, not tied to specific lines):
   ```bash
   gh api repos/PositiveControl/rails-rocket-sheep/issues/<PR_NUMBER>/comments
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

### Step 7: Check the change against what the issue asked

Standards are one axis; the other is whether this is the change that was
requested. A PR can follow every convention in `docs/rules/` and still not do the
job, and that finding never comes out of reading the diff alone.

1. Find the originating issue — `Closes #n` in the PR body, the `<issue>` segment
   of the branch name, or the `<issue> | …` title. A slice PR
   into a feature branch carries no `Closes` by design, so use the other two. None
   of the three present → that is itself a finding: nothing ties this work to a
   request.
2. Read its acceptance criteria, and the design doc in `docs/plans/` if it links
   one.
3. Walk the criteria one at a time. Per bullet: met, partially met, or not met,
   each with the file and line that meets it. A bullet you cannot point at is not
   met.
4. Then the other direction: work in the diff that no criterion asked for. Small
   and adjacent is fine — say so and move on. A second feature riding along is a
   **suggestion to split**, and past the 1,500-added-line guidance in `WORKFLOW.md`
   it is blocking.
5. A design doc whose rejected alternatives are being re-litigated in this diff is
   a blocking finding. The decision was made; reopening it belongs in a comment
   thread, not in code.

Under tier `labels` = `beads`, the issue is a bead: read it with
`bd show <id> --json` instead of `gh issue view`.

An unmet criterion is blocking when the PR claims to close the issue, and a
suggestion when the PR body already says which slice it covers.

### Step 8: Analyze and categorize findings

Review the code using the criteria from the language-specific review doc (Step 5). If no specific doc applies, use these general criteria. **Cross-reference with existing feedback from Step 4** — do not duplicate points already raised by other reviewers.

**Blocking (request changes):**
- Acceptance criteria the PR claims to close and does not meet (Step 7)
- Bugs or logic errors
- Security vulnerabilities (injection, XSS, mass assignment, etc.)
- Data integrity issues (missing validations, unsafe migrations, race conditions)
- Seeds left out of step: a new model, process, or dependency landed without a matching idempotent `db/seeds.rb` update (`docs/rules/seeds.md`)
- A `db/queries.yml` review line that is wrong: it names an index the query cannot use, or a `no index:` reason that does not hold for the table's size or growth (`docs/rules/query-ledger.md`). CI checked that the line exists, not that it is right
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

### Step 9: Present review to user before posting

Before posting anything to GitHub, present the full review to the user in this format:

```
## PR #<NUMBER> Review Summary

**Overall assessment:** <approve / request changes / comment only>
**Risk level:** <low / medium / high> — <one line explanation>
**Findings:** <n> blocking, <n> suggestions, <n> nitpicks

### Existing feedback summary
<Brief summary of what other reviewers have already flagged. Note any unresolved concerns.>

### Against the issue
<Per acceptance criterion: met / partial / not met, with file:line. Then anything in the diff nobody asked for.>

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
4. What review action to take: APPROVE, REQUEST_CHANGES, or COMMENT — always COMMENT on your own PR (*Self-review of a slice*)

**Autopilot (gate `post-review`):** ask nothing. Post the review exactly as written, as `COMMENT`, its body opening with `Self-review pass <N>`. `<N>` is one more than the number of reviews on the PR whose body already opens with `Self-review pass`. Count across every page, since GitHub returns 30 a page: `gh api --paginate repos/PositiveControl/rails-rocket-sheep/pulls/<PR_NUMBER>/reviews | jq -s '[add[] | select((.body // "") | startswith("Self-review pass"))] | length'`. The author must not soften its own review; the feature-PR reviewer reads it as written.

### Step 10: Post the review to GitHub

Once the user confirms, submit the review using the GitHub API.

**Important:** Pass raw JSON from a file: write it with the Write tool to `tmp/review-<PR_NUMBER>.json`, then `--input tmp/review-<PR_NUMBER>.json`. The `gh` CLI's `-f 'comments[0][path]=...'` syntax does NOT work for arrays — it creates a hash instead. Not a heredoc on standard input: permission rules don't match a heredoc, so an autopilot step's `dontAsk` denies it.

Use `line` (file line number) and `side` ("RIGHT" for additions, "LEFT" for deletions) to position comments.

**Review with inline comments:**

`tmp/review-<PR_NUMBER>.json`:

```json
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
```

```bash
gh api repos/PositiveControl/rails-rocket-sheep/pulls/<PR_NUMBER>/reviews -X POST --input tmp/review-<PR_NUMBER>.json
```

**Review without inline comments:**

The same file and command, with only `event` and `body`:

```json
{
  "event": "<APPROVE|REQUEST_CHANGES|COMMENT>",
  "body": "<overall review summary>"
}
```

### Step 11: Report result

After posting, display:

```
✓ Review posted on PR #<NUMBER>
  Action: <APPROVE / REQUEST_CHANGES / COMMENT>
  Inline comments: <count>
  URL: <review URL>
```

Then name what runs next. Someone else's PR → nothing; the author picks it up. Self-review pass 1 with blockers or suggestions → `/pr_comment_resolver <PR_NUMBER>` in the authoring session, then pass 2 from a new session. Pass 1 with none, or pass 2 done → land the slice, below.

## Self-review of a slice

A slice PR into a feature branch (`WORKFLOW.md`, *Feature branches*) is reviewed by its own author running this command from a **new session with no memory of writing the code**, once per pass. The context that wrote a diff shares its blind spots; a fresh one does not. Why the slice merges on this review and the feature on a human's is `docs/adr/0014-slices-merge-on-the-agents-review-features-on-a-humans.md`.

- **Two passes at most.** More feed on each other: a later pass finds bugs inside an earlier pass's fixes, or undoes them.
  - **Pass 1** reviews the slice. The authoring session verifies every finding against the code before fixing it — a reviewer is not the spec — and takes the ones it judges wrong to the developer (*Fix it* / *Drop it*); the developer's ruling is final. It addresses the rest with `/pr_comment_resolver`. Blocker and suggestion fixes land with a test that fails without them, as in `/implement` Step 5; nitpicks are fixed together or dropped, and never trigger pass 2.
  - **Pass 2** runs once, from another new session, and only when pass 1 left fixed blockers or suggestions. Under autopilot the driver decides from pass 1's `**Findings:**` line: zero blocking and zero suggestions → no pass 2, whatever the resolver pushed. It reviews only those fixes: the diff from the commit pass 1 reviewed (its review's `commit_id`) to `HEAD`, plus wherever the fixes reach — callers, shared state, tests they changed or deleted. Step 4 hands it pass 1 and the replies, so a dropped finding stays dropped. In place of Step 2's `gh pr diff`:

    ```bash
    gh api repos/PositiveControl/rails-rocket-sheep/pulls/<PR_NUMBER>/reviews --jq '[.[] | select(.body | startswith("Self-review pass 1"))][0].commit_id'
    gh pr checkout <PR_NUMBER> && git diff <SHA>..HEAD
    ```

    `<SHA>` is what the first command printed. Two commands, not a `SHA=$(…)` substitution, which an autopilot step's `dontAsk` denies.
  - **No pass 3.** Pass 2's confirmed blockers and suggestions go to the developer with the proposed fix (*Fix it* / *Drop it*), and fixes land under the same test rule. Then land the slice.
- **Post as COMMENT.** GitHub refuses APPROVE and REQUEST_CHANGES on your own PR. Open the review body with `Self-review pass <N>` so the feature-PR reviewer can count them.
- **Land it from this session.** A clean pass is what merges a slice — you run it, on the strength of the review rather than your own reading:

  ```bash
  gh pr checks <PR_NUMBER> --watch --fail-fast
  gh pr merge <PR_NUMBER> --squash --delete-branch
  ```

  The first command waits for CI on the head you are landing: `/pr_submit` skips that wait for a slice, so the review could start sooner. Red → do not merge: run `/pr_fix_ci` in the authoring session, and review its fix as you would a pass-1 fix. One exception: `--fail-fast` stops at the first red, and if every red check it lists is informational (`CodeQL` / `Analyze`, which `/pr_submit` and `/pr_fix_ci` also ignore), the rest may still be pending. Then wait again without it, and merge only when every other check is SUCCESS:

  ```bash
  gh pr checks <PR_NUMBER> --watch
  ```

  Then edit the feature PR body (`gh pr list --head feature/<slug>`, then `gh pr edit <FEATURE_PR> --body-file`): tick this slice under **Slices**, and add `Closes #<issue>` beneath the list (not under tier `beads`, which has no GitHub issue). This is the slice's only tick, now that it has merged. Then bring the feature branch up to date so the final merge stays small. `--no-ff`, because by now both branches have usually moved, and a `merge.ff=only` in the developer's git config refuses that merge without it:

  ```bash
  git checkout feature/<slug> && git pull && git merge --no-ff origin/main && git push
  ```

  Conflicts → `/resolve_conflicts`.
- **Last slice landed** → resolve every remaining `Status: Draft` placeholder on the feature branch, `gh pr ready <FEATURE_PR>`, and hand it to a human. That review is an acceptance-criteria walk over the design doc's slice list, reading the posted passes and spot-checking where they disagree or fall silent — not a re-read of the whole diff.
- **Autopilot.** This session posts its pass and stops. It does not merge, edit the feature PR, or ready it.
  - **Merge (gate `merge`) and the last slice belong to the driver.** It checks the PR's base before it merges, which a prompt cannot promise.
  - **Pass 1's and pass 2's rulings** are made by the authoring session, through `/pr_comment_resolver`, under gates `fix-drop` and `pass-2`. Nobody is asked.
  - **Telling the agent's comments from a person's.** The passes post from the developer's own account, so the author login cannot tell who wrote what. Read the comments with `docs/system/autopilot-steps.md`, *Whose comment is it*.

## Review principles

- **Be constructive.** Frame feedback as suggestions when possible, not demands. Use "Consider..." or "What do you think about..." for non-blocking items.
- **Explain the why.** Don't just say something is wrong — explain what could go wrong and suggest a fix.
- **Respect the author's approach.** If their solution works and is readable, don't rewrite it in your preferred style. Only push back on genuine issues.
- **Be specific.** Reference exact lines, show code examples for suggested changes, link to relevant docs or patterns in the codebase.
- **Assume good intent.** If something looks wrong, it may be intentional — ask before assuming it's a mistake.
- **Keep it proportional.** A 5-line bug fix doesn't need 20 comments. Scale review depth to PR size and risk.

## Reference
- GitHub username: Use `gh api user --jq .login` to get the current user's GitHub username
- Repo: PositiveControl/rails-rocket-sheep
- Use `gh api` for review submission (not `gh pr review` which has limited comment support)
- Diff position vs line number: prefer `line` + `side` over `position` for accuracy
- Review events: APPROVE, REQUEST_CHANGES, COMMENT
- PR title convention: `<issue_number> | <description>`
- Base for the diff: the PR's `baseRefName` — `main`, or a feature branch for a slice
- Autopilot: `docs/system/autopilot-steps.md` — activation check, policy by gate id (`post-review`, `merge` here), whose comment is whose
