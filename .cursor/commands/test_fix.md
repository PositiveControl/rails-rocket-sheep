---
description: "Triage failing test output to root causes, then fix them"
argument-hint: "[paste the failing output]"
---

# Fix Failing Tests

Take failing Minitest output, find the causes rather than the symptoms, fix them,
and verify outward. Paste the output as the argument, or run it bare and this
command runs `bin/test` first: `/test_fix`.

Repetitive failures are the normal case, not noise. Fourteen failures are usually
one bug.

Nothing is failing yet, or the complaint is "slow" rather than "wrong"? That is
`/diagnose`, which builds the loop this command assumes you already have.

## Instructions

### Step 1: Get the failure set

`$ARGUMENTS` holds pasted output → treat it as the source of truth. Otherwise:

```bash
bin/test
```

### Step 2: Parse every failure

Enumerate them all. Per failure, capture the test file, the test and class name,
the line, the error type, the assertion or exception message, expected and actual,
the useful part of the stack trace, and the implementation file it points at.

### Step 3: Group by cause

De-duplicate aggressively into single-cause groups, likely-related groups, and
genuinely isolated failures. One nil guard, one stale fixture, one changed route,
or one time-zone assumption each produce a spray of unrelated-looking failures.

Each group gets an id, a root-cause hypothesis, a confidence level, and its
affected tests. Rank groups by blast radius first, then confidence, then how
cheaply the fix can be validated.

### Step 4: Log it

Write the triage to `tmp/test_failure_log.md` (scratch, gitignored) <!-- lint-docs:ignore -->
so a resumed session picks up where this one stopped. Per group: status, root-cause
hypothesis, confidence, suspected files, affected tests, investigation notes,
confirmed cause, fix strategy, then the resolution and what validated it. Keep a
final section for what remains.

Worth keeping past the fix? Promote the *procedure* to `docs/sop/`, which the doc
canon owns. Don't invent a directory for it.

### Step 5: Investigate each group along five lines

Cover all five before concluding; they catch different things.

| Line of inquiry | What it looks at |
|---|---|
| The failure itself | What the assertion actually says, and whether the test is testing what its name claims |
| Application code | Models, controllers, services, jobs, mailers, routes, config, and what changed recently |
| Test architecture | Fixtures, setup and teardown, helpers, shared state, data assumptions. Conventions: `docs/rules/testing.md` |
| The fix | The smallest correct change, and whether it belongs in the app or the test |
| Validation | The narrowest run that proves it, and what else the change could break |

### Step 6: Fix the cause

Highest-confidence shared cause first. Smallest surgical change. Fix the
application when the behaviour is genuinely wrong, and the test only when the
implementation is right and the test is stale. Never adjust an assertion to make
a run green, and never overfit a fix to one test at the cost of behaviour
elsewhere.

Before deciding, rule out the alternatives: changed requirements, stale test,
fixture or setup problem, environment or config, async or timing, ordering
randomness, time zone or locale formatting, or a Rails 8 behavioural difference.

### Step 7: Validate outward

Single test, then its file, then the group, then the surrounding area, then the
wider suite only where the change earns it. Record each step in the log.

### Step 8: Report

What failed, the groups and their causes, what changed and why, what now passes,
what remains, and where the log is. Blocked → say what blocked it, what the
evidence was, and the exact next step needed. Then name what runs next:
`/run_lint` before committing, `/pr_submit` once green.

## Reference
- Test runner: `bin/test` (one file: `bin/test <path>`), system tests: `bin/rails test:system`
- Testing conventions, fixtures, VCR, which layer tests what: `docs/rules/testing.md`
- Slow tests over 500ms: `docs/sop/find-slow-tests.md`
- Triage log: `tmp/test_failure_log.md`, scratch and gitignored <!-- lint-docs:ignore -->
- Minitest failure patterns worth suspecting early: stale fixture assumptions,
  test order dependency, state leaking between tests, a missing `reload`, changed
  validations or callbacks, a different controller response or redirect, an
  authorization change, a renamed route or helper, job enqueue behaviour,
  timestamp precision, JSON shape changes, nil handling, fixtures that no longer
  match the schema, schema drift after a migration, strong params, Turbo versus
  HTML responses, transactional test behaviour, and system-test synchronisation
- Parse, group, log, investigate, fix, validate, report. Classification alone is not the job
