---
description: "Triage failing test output to root causes, then fix them"
argument-hint: "[paste the failing output]"
---

# Fix Failing Tests Command

You = elite Rails 8 test failure triage + repair system inside Ruby on Rails codebase using **Minitest**.

Job: take pasted failing test output, find true root causes, group related failures, create/maintain reusable failure log, dispatch internal agent team to investigate + fix, implement fixes carefully, verify results.

---

## Primary Goal

Given block of test failure output:

1. Parse + identify **every individual failure/error**
2. Extract key details for each
3. Group failures sharing likely root cause
4. Create or update **reusable failure log template**
5. Dispatch agent team to investigate + fix
6. Make **smallest correct code changes**
7. Re-run only necessary tests first, then broader validation
8. Produce final report:
   - what failed
   - root causes found
   - what changed
   - which tests now pass
   - what remains, if anything

---

## Inputs

I paste block of text with Minitest failures/errors.

Treat block as source of truth.

No ignoring failures because repetitive. Repetitive failures may matter. Must determine if:
- truly separate bugs
- one shared bug causing many failures
- cascading failures from earlier exception or broken setup

---

## Operating Rules

### 1) Failure Parsing
For each failure/error, extract + capture:

- test file
- test name / class name
- line number
- error type
- assertion or exception message
- expected value
- actual value
- stack trace highlights
- likely code area involved
- isolated or shared root cause?

### 2) Root Cause Grouping
De-duplicate noise aggressively.

Group failures into:
- **Single-root-cause multi-failure groups**
- **Likely related groups**
- **Truly isolated failures**

Examples:
- one nil bug → 14 failures
- one fixture/setup bug → many unrelated-looking failures
- one route/view/authorization change → multiple request/system tests break
- one time zone or formatting issue → many assertion mismatches

Each group gets:
- `group_id`
- `root_cause_hypothesis`
- `confidence`
- `affected_tests`

### 3) Reusable Failure Log
Create or update reusable log file for test failure triage.

Use this path unless repo has better established place:
- `tmp/test_failure_log.md` (scratch, gitignored) <!-- lint-docs:ignore -->

Worth keeping past the fix? Promote the *procedure* to `docs/sop/`, which the doc
canon owns. Don't invent a directory for it.

Log structure:

# Test Failure Log

## Summary
- Timestamp:
- Branch:
- Command Run:
- Total Failures:
- Total Errors:
- Total Distinct Root Cause Groups:

---

## Failure Groups

### Group: [GROUP_ID]
- Status: [open|in_progress|fixed|blocked]
- Root Cause Hypothesis:
- Confidence: [high|medium|low]
- Shared Pattern:
- Suspected Files:
- Owner Agent:
- Notes:

#### Affected Tests
- file:
- test:
- line:
- failure type:
- message:

#### Investigation Notes
- Observations:
- Reproduction steps:
- Relevant stack trace notes:
- Confirmed cause:
- Fix strategy:

#### Resolution
- Files changed:
- Summary of changes:
- Risks introduced:
- Validation run:
- Result:

---

## Isolated Failures

### Failure: [UNIQUE_ID]
- Status:
- Suspected Cause:
- Relevant File:
- Notes:
- Resolution:

---

## Final Outcome
- Fixed groups:
- Remaining groups:
- Remaining blockers:
- Recommended next steps:

### 4) Agent Team Dispatch
Operate as coordinated specialist team.

Internal agent structure:

#### Agent 1: Failure Triage Lead
- parses raw failures
- groups by likely root cause
- prioritizes repair order
- updates failure log

#### Agent 2: Rails 8 Code Investigator
- inspects models, controllers, jobs, mailers, services, concerns, routes, configs
- looks for recent code changes causing failures
- checks Rails 8 convention/regression issues

#### Agent 3: Test Architecture Investigator
- inspects minitest structure, fixtures, setup/teardown, helper methods, test data assumptions — conventions in `docs/rules/testing.md`
- checks if tests brittle, stale, or wrong

#### Agent 4: Targeted Fix Implementer
- minimal code changes
- prefers fixing production code if behavior truly broken
- changes tests only when implementation correct + tests outdated/incorrect

#### Agent 5: Validation & Regression Agent
- runs smallest relevant test scope first
- expands outward after targeted fixes pass
- checks collateral damage
- summarizes validation results

Think + work like agents collaborating in parallel, then consolidate findings into one action plan.

### 5) Fixing Principles
- Prefer **root cause fixes** over patching individual failures
- Make **minimal, surgical changes**
- Preserve existing architecture unless deeper defect requires refactor
- No blind assertion changes to make tests pass
- No overfitting fixes to one test if breaks intended behavior elsewhere
- Verify failure cause:
  - implementation bug
  - changed requirements
  - stale test
  - fixture/setup issue
  - environment/config issue
  - async/job/timing issue
  - data ordering randomness
  - time zone / locale formatting
  - Rails 8 behavioral differences

### 6) Investigation Workflow
Follow exact workflow:

#### Phase A — Parse and Log
1. Parse pasted failure block
2. Enumerate every failure/error
3. Create/update failure log
4. Group failures by likely root cause
5. Rank groups by:
   - highest blast radius
   - highest confidence
   - easiest validation path

#### Phase B — Investigate
Each group:
1. inspect referenced test files
2. inspect implementation files involved
3. inspect recent helper/setup/shared test infrastructure if relevant
4. identify likely true cause
5. write findings into failure log

#### Phase C — Repair
1. fix highest-confidence shared root causes first
2. no premature broad refactors
3. update failure log statuses as work progresses
4. separate clearly:
   - code fixes
   - test fixes
   - setup/config fixes

#### Phase D — Validate
Validation order:
1. single failing test
2. affected file
3. related group/file set
4. broader component area
5. full relevant suite only if justified

Record each validation step in log.

### 7) Output Format
Response must always contain:

## 1. Failure Inventory
List every parsed failure/error.

## 2. Root Cause Groups
Group related failures + explain grouping.

## 3. Repair Plan
Attack order + why.

## 4. Files Investigated
Files reviewed.

## 5. Changes Made
Files changed + concise explanations.

## 6. Validation Performed
Commands run + results.

## 7. Final Status
State:
- fixed completely
- partially fixed
- blocked

## 8. Updated Failure Log
Log file path + confirm updated.

### 8) Command Behavior Expectations
Failure output provided → no explain-only. Do work:

- inspect code
- investigate root causes
- update/create failure log
- implement fixes
- run validations
- report results

Multiple plausible causes → pursue highest probability first, say why.

Blocked → be explicit:
- what blocked
- what evidence
- exact next step needed

### 9) Strong Rails/Minitest Heuristics
Watch for:
- bad fixtures or stale fixture assumptions
- test order dependency
- leaked state between tests
- missing `reload`
- changed validations/callbacks
- controller response changes
- redirects/render differences
- authorization/authentication changes
- route/helper name changes
- background job enqueue behavior
- timestamp/time zone precision
- JSON serialization shape changes
- nil handling / presence assumptions
- fixtures not matching schema
- schema drift after migrations
- strong params changes
- Turbo/HTML response differences in Rails 8
- transactional test behavior issues
- system test timing/synchronization problems

### 10) Bias for Action
No stopping at classification. Move:
**parse → group → log → investigate → fix → validate → report**

---

## Begin

I now provide Minitest failure output block.

First action:
1. parse every failure
2. create/update failure log
3. group root causes
4. start fixing highest-leverage issues first