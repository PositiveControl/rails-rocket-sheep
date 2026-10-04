---
description: "Execute an approved task plan; resumable and idempotent"
argument-hint: "[issue number, defaults to the branch]"
---

# Implement

Execute an approved task plan. Idempotent — first run after `/task_plan` approval and tenth resume after a lost session are the same command. Pass the issue number, or omit to infer from the current branch: `/implement 1613` or `/implement`.

## Instructions

### Step 1: Resolve the issue

1. `$ARGUMENTS` given → use it
2. Otherwise parse from the current branch name (`{{BRANCH_PREFIX}}/<id>/<slug>`). The `<id>` segment is
   either a bare number (`1613`) or a bead ID (`bd-a3f2dd`) depending on the tracker tier — accept both.
3. Neither works → ask, or suggest `/pick`

### Step 2: Load state

1. Read `.llm/tasks/<id>_*.md` — goal, acceptance criteria, `Base:` (the branch this slice's PR targets: `main` or `feature/<slug>`), Next Actions, progress log. **No task file → stop, run `/task_plan <issue>` first.** Never implement without an approved plan. The task file carries what this slice needs from the design doc; open the design doc only for a question the task file does not answer, and then only the section that answers it.
2. Verify the branch: on `{{BRANCH_PREFIX}}/<id>/*`? If not, check it out. `git status` + `git log origin/<BASE>..HEAD --oneline` — what's already committed.
3. Cross-check progress log vs actual commits — the log can lag reality; commits are truth.
4. Check whether autopilot is active, with `<BASE>` from step 1 (`docs/system/autopilot-steps.md`, *Activation*). If it is, every *Autopilot* paragraph below replaces the question it follows, and each answer is appended to the autopilot log as one entry.

### Step 3: Orient

Report 3 lines before touching code: what's done, what's in flight, what's next. Discrepancy between plan and code found → say so and resolve before continuing.

**Autopilot:** the three lines go to the task file's progress log; nobody is reading the screen. A discrepancy the code settles (the commits are truth) is a `choice`. One that means the plan is wrong is a `halt`.

### Step 4: Work loop

Work through Next Actions in order. Per logical unit:

1. Implement per the plan
2. Write tests for new functionality — framework, fixtures, layering, and HTTP recording per `docs/rules/testing.md`
3. Added or changed a model, a process, or a dependency? Update `db/seeds.rb` in the same unit so dev data stays in step — idempotently, per `docs/rules/seeds.md`
4. Run the affected tests — green before moving on
5. Commit — one logical unit, message explains *why* (e.g., "Add scroll-to-bottom after Turbo Stream add", not "Update controller")
6. Append one dated bullet to the task file's progress log

Rules in force:

- **Conventions**: `docs/rules/` is the single source, routed by `docs/rules/INDEX.md` — do not restate rules in the task file
- **Scope escape**: forecast passes ~1,500 added lines or 25 files, or new acceptance criteria surface → STOP. Split a sub-issue (`gh issue create`, link to parent), note it in the task file, land the current slice clean
- **Segue valve**: rabbit hole, plan contradiction, or theory-war debugging → suggest `/segue <question>` instead of burning the session
- Remove all debugging code before finishing

**Autopilot:**
- A scope escape is a `split`: create the sub-issue as above, add it to the feature PR's **Slices** list, and land this slice clean. The policy caps splits per feature; past the cap, `halt`.
- No segue opens. Theory-war debugging goes to `/diagnose`, which needs nobody. A plan contradiction is a `halt`.
- A fix outside this slice's acceptance criteria is an `out-of-slice` entry, within the policy's limits.
- Work found but not done here is an `issue` entry.
- Any choice you would have mentioned to the developer is a `choice` entry.

### Step 5: Fresh-eyes review

Acceptance criteria met and tests green → before the PR, a second agent that has seen none of this session reviews the branch, and this session addresses what it finds. The agent that wrote the code is the worst reviewer of it: it reads what it meant, not what it wrote.

How many rounds depends on what reviews the PR next:
- **`<BASE>` is a feature branch** (a slice): **one round.** Self-review pass 1 on the PR re-reads the whole diff, round 1's fixes included, from another fresh context. A second local round over only those fixes finds what pass 1 would. Measured over 13 slices, it added no independent bug (`docs/adr/0014-slices-merge-on-the-agents-review-features-on-a-humans.md`, *Amended*).
- **`<BASE>` is `main`:** **two rounds at most.** No agent review follows, so round 2 is the only check on round 1's fixes. More rounds feed on each other: a later pass finds bugs inside an earlier pass's fixes, or undoes them.

1. **Commit everything.** The reviewer reads `HEAD`, not your working tree.
2. **Spawn a new reviewer with an empty context** — in Claude Code the Agent tool with `subagent_type: "general-purpose"`, never `fork` (a fork inherits this context, which defeats the point), and never round 1's reviewer resumed. Prompt, and nothing more — no summary of the change, no hints at what to look for:
   - **Round 1** reviews the branch, with `<base>` = `origin/<BASE>` from the task file's `Base:` line:
     ```
     Working directory: <this worktree's absolute path>. Run /pr_review --local <base>.
     Read-only: no edits, commits, pushes or GitHub posts. Return the review summary as your final message.
     ```
   - **Round 2** (only when `<BASE>` is `main`) reviews only round 1's fixes: `<base>` = the SHA `HEAD` was at when round 1 reviewed it. Add to the prompt: `These commits fix an earlier review. Also read wherever they touch the rest of the code — callers, shared state, tests they changed or deleted.` plus the settled list (item 6).
3. **Verify every finding before touching code.** A reviewer is not the spec. For each one: read the cited code, check the claim holds (the failure scenario reproduces, the convention exists in `docs/rules/` or the codebase, the missing test really is missing), and decide *legitimate* or *not*.
4. **Surface disagreements.** Findings you judge not legitimate go to the developer in one question — per finding, the claim, your evidence against it (`file:line`), and the options *Fix it* / *Drop it*. Never drop a finding silently. The developer's ruling is final.
   **Autopilot (gate `fix-drop`):** nobody rules, so the bar for dropping rises. Drop a finding only with a **probe**: a command or test whose output shows the failure scenario does not happen, or the rule it contradicts, cited. No probe → fix it. Each drop is one entry carrying its probe, so the developer can overturn it at the feature PR. Drops also go into the settled list (item 6), as `Dropped: <finding> — probe: <…>`.
5. **Fix what is legitimate.**
   - **Blockers and suggestions** — one logical unit per commit, as in Step 4. Each lands with a test that fails without it: revert the fix, run the test, see it fail, restore. A test that passes both ways pins nothing. No such test is possible → say why in the commit message.
   - **Nitpicks** — list them, then fix them together in one commit or drop them. They never trigger another round.
6. **Settled list** — for round 2's prompt: `Dropped: <finding> — <developer's reason>` and `Changed on purpose in round 1: <what, where>`, so a fresh reviewer neither raises a dropped finding again nor asks for a fix to be undone.
7. **When to stop.** A slice → done after round 1's fixes. Otherwise: round 1 has no confirmed blockers or suggestions → done; if it has, round 2 runs once, over the fixes. Its confirmed blockers and suggestions go to the developer with your proposed fix (*Fix it* / *Drop it*); fixes land under item 5's test rule. There is no round 3.
   **Autopilot (gate `pass-2`):** fix round 2's confirmed blockers and suggestions under item 5's test rule, one entry each. A fix with no possible failing test is a `halt`, because only the developer can accept an unpinned fix.

Done → append one dated line to the progress log: `Pre-PR review: <n> rounds — <n> fixed, <n> dropped by developer`.

No way to spawn an agent with an empty context → ask the developer to run `/pr_review --local <base>` in a new session and paste its summary back. Never review your own work in its place. **Autopilot:** `halt`. There is no one to ask, and a self-review is not a review.

### Step 6: Done check

All acceptance criteria met, tests green, pre-PR review done, working tree committed:

```
All acceptance criteria met. Run: /pr_submit <ISSUE_NUMBER>
```

Criteria remain → keep looping or report the blocker.

## Reference
- Repo: {{GITHUB_ORG}}/{{GITHUB_REPO}}
- Task files: `.llm/tasks/<id>_<slug>.md`
- Branch convention: `{{BRANCH_PREFIX}}/<id>/<slug>` — `<id>` is a number or `bd-<hash>`
- Test runner: `bin/test` (specific file: `bin/test <path-to-test-file>`), system: `bin/rails test:system`
- Sizing: PR target 200–1,500 added lines / ≤25 files
- Pre-PR review: `/pr_review --local <base>` in a new-context agent: one round for a slice, two at most into `main` (Step 5)
- Autopilot: `docs/system/autopilot-steps.md` — activation check, policy by gate id (`split`, `fix-drop`, `pass-2`, `out-of-slice`, `issue`, `choice`, `halt` here), log entry shape, halt protocol
