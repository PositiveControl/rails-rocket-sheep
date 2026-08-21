---
description: "Find the cause of a hard bug or a slow path, behind a tight loop"
argument-hint: "<the symptom, as it was reported>"
---

# Diagnose

Find the cause of `$ARGUMENTS` by building a loop that goes red on it, then fixing what the loop proves. For a suite that is already red the triage is `/test_fix`, and for a red CI run it is `/pr_fix_ci`; this is the bug with no failing test yet, or the path that got slow. Pass the symptom as reported: `/diagnose "checkout 500s when the cart has a deleted variant"`.

Skip a step only by saying which one and why.

## Instructions

### Step 1: Build a feedback loop

**This is the whole command.** With a signal that goes red on *this* bug, the cause is findable; without one, reading code produces theories nobody can test. Spend the effort here.

In roughly this order, cheapest first:

| Loop | Use it for |
|---|---|
| `bin/test <path>` at whatever seam reaches the bug | Anything already covered by a model, service, or integration test |
| `bin/rails runner` script over real data | Data-shaped bugs, and anything needing a record that fixtures do not have |
| `curl` against `bin/dev` | Wrong status, wrong redirect, wrong response body, Turbo behaviour |
| `bin/rails test:system` driving the UI headless | Anything the browser has to do: Stimulus, Turbo Frames, forms |
| Replay a captured payload through the code path | Webhooks, third-party callbacks, background job arguments |
| `bin/rails console --sandbox` | Probing state without writing to the database |
| Loop the trigger 50 or 100 times | Flaky and order-dependent failures |
| `git bisect run` over a script | Something that used to work, with a known-good commit |
| Two configs or two versions, same input, diff the output | Regressions after an upgrade |

Then **tighten** it: faster (narrow the scope, skip unrelated setup), sharper (assert the exact symptom, not "no exception"), more deterministic (freeze time, seed the RNG, pin the data). A 2-second deterministic loop is worth ten flaky 30-second ones.

**Do not proceed** until you can name one command you have already run, whose output you can show, which drives the real code path and asserts the reported symptom. Reading code to build a theory before that command exists is the exact failure this command prevents.

Genuinely cannot build one? Stop, list what you tried, and ask for the environment that reproduces it, a redacted artifact (log excerpt, payload, recording with timestamps), or permission to instrument. Do not hypothesise without a loop.

### Step 2: Reproduce, then minimise

Run the loop and watch it go red. Confirm it is the *reported* failure and not a nearby one — the wrong bug gets the wrong fix.

Then shrink the scenario one element at a time, re-running after each cut, until every remaining element is load-bearing: removing any one of them turns the loop green. A minimal repro is a smaller hypothesis space now and the regression test later.

### Step 3: Hypothesise, three to five, ranked

Write them all down before testing any, because a single hypothesis anchors on the first plausible story. Each must be falsifiable, stated as a prediction: "if X is the cause, then changing Y makes it disappear." No prediction means it is a vibe — sharpen it or drop it.

Show the ranked list to the user before probing. They often re-rank it in one line ("we deployed a change to #3 yesterday"). Do not block on the answer.

### Step 4: Instrument, one variable at a time

Each probe maps to one prediction from Step 3.

1. A breakpoint or `bin/rails console` inspection beats ten log lines.
2. Targeted logging at the boundary that separates two hypotheses.
3. Never "log everything and grep".

Tag every debug log with one unique prefix (`[DEBUG-a4f2]`), so cleanup is one `grep`. Untagged debug logs are the ones that ship.

**Slow rather than wrong?** Logs are the wrong tool. Measure first: get a baseline, then read the query log or `EXPLAIN ANALYZE` the query, then bisect the path. Start from `docs/rules/n-plus-one.md` and `docs/rules/caching.md` — the two causes worth ruling out before any other.

### Step 5: Fix, with the regression test first

Write the test before the fix, if there is a correct seam for it: one where the test exercises the real pattern as it occurs at the call site. A seam too shallow to reproduce the chain that caused the bug gives false confidence, and **the absence of a correct seam is itself a finding** — record it, because the architecture is what is stopping the bug from being locked down.

With a seam: turn the minimised repro into a failing test, watch it fail, apply the fix, watch it pass, then re-run the Step 1 loop against the original un-minimised scenario.

### Step 6: Clean up before claiming done

- [ ] The Step 1 loop no longer goes red
- [ ] The regression test passes, or the missing seam is written down
- [ ] Every `[DEBUG-...]` line is gone (`grep` the prefix)
- [ ] Throwaway scripts deleted
- [ ] The suite is green: `bin/test`

### Step 7: Report

The symptom, the loop that caught it, the hypothesis that survived and what killed the others, the fix, and what proves it. Put the surviving hypothesis in the commit message — it is what the next person debugging this area needs. Then name what runs next: `/run_lint` before committing, `/pr_submit` once green, `/test_fix` if the suite turned up unrelated failures.

## Reference
- **Redact before showing anything.** Command output, logs, and captured payloads carry credentials and personal data. Write `<REDACTED>` in place of a secret, drive loops from environment variables rather than pasted values, and quote only the lines carrying the signal. Redacted output insufficient to diagnose the bug → say so and ask.
- Runner: `bin/test`, one file `bin/test <path>`, system tests `bin/rails test:system`
- Testing conventions, fixtures, VCR, which layer tests what: `docs/rules/testing.md`
- Performance suspects, in order: `docs/rules/n-plus-one.md`, `docs/rules/caching.md`
- Slow tests over 500ms: `docs/sop/find-slow-tests.md`
- Where an exception should surface: `docs/rules/exception-boundary.md`
- Who changed a record, and when: `docs/rules/audit-trail.md`
- Scratch scripts and captures: `tmp/`, gitignored, deleted at Step 6 <!-- lint-docs:ignore -->
- A loop, then a repro, then a ranked theory, then a probe. A theory with no loop under it is not a diagnosis
