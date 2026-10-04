# An Accepted Design May Run Itself

**Applies to:** both modes. Any multi-slice feature whose design doc carries
`**Autopilot:** on`. Extends ADR 0014.

**Status:** Accepted

**Context:**
ADR 0014 moved line-level review of a slice from a person to a fresh agent
session, and kept the person at the feature PR. The person still stood at every
other point in a slice: approving its plan at G2, ruling *Fix it* / *Drop it* on
each finding the authoring agent disputed, clicking merge from the review session,
and typing the next command, since a command cannot invoke a command. On the first
feature an adopting app measured (three slices) that was a full day at the
keyboard. Most of those touches were approvals of things the design already
settled.

A few were not. In the third slice the developer watched the app run and saw the
layout overflow a 1280×720 window, then asked for one more review cycle, which
found a stale-read blocker. No policy notices things. The question was whether the
approvals could be delegated without losing what the noticing caught.

**Decision:**
A multi-slice feature may run on **autopilot**: from its first open slice to a
ready feature PR, with no person between G1 and the feature PR's review.

- **Consent is given once, at G1,** as part of approving the design. The developer
  approves a written policy along with it: an answer for each question a command
  would otherwise ask, by gate id. The design doc records the consent
  (`**Autopilot:** on`); the policy and every answer given under it go to the
  feature's **autopilot log**, a committed file the feature-PR reviewer reads.
- **Two keys.** Commands follow their *Autopilot* paragraphs only when the doc says
  so **and** `AUTOPILOT=1` is set, which only the driver does. A person running a
  command by hand is still asked.
- **A driver, not a session, sequences the work.** `bin/autopilot` runs each step as
  a fresh agent process and checks tracker, git and PR state after it, so a step
  that reports success without achieving it is caught. Review passes are new
  processes, which makes ADR 0014's fresh context literal.
- **The driver merges, never a step.** The merge is the most consequential act, and
  a script can check the PR's base deterministically where a prompt cannot.
- **Doubt stops the run.** Halting is the policy working, not failing. A
  destructive migration, auth or credentials, payments, a red suite after a retry,
  a third split, a comment from a person, or a question the developer would expect
  to be asked all halt, with the issue marked Blocked and the log saying what is
  needed.
- **Dropping a finding needs a probe.** With nobody to rule, a disputed review
  finding is dropped only when a command or test shows its failure scenario does
  not happen. Otherwise it is fixed.
- **Review passes, per kind.** `/implement`'s local pre-PR rounds and the posted
  `/pr_review` passes both run. ADR 0014's caps apply to each kind separately: one
  local round for a slice (its 2026-10-03 amendment) and two posted passes, so a
  slice sees at most three. The local round catches what CI would. The posted
  passes are the evidence the feature-PR reviewer reads, and in practice they had
  been skipped.

The merge to `main` stays a person's, and so does G1. Single-slice features never
run on autopilot: their PR targets `main`, where the merge is human anyway.

**Consequences:**
- (+) The developer's time per feature moves to two places: G1, which now includes
  the policy, and the feature PR, which now includes the log. A feature can run
  overnight.
- (+) Every decision is written down with its alternative and how reversible it
  is. An interactive session leaves the same decisions in a gitignored task file
  and the developer's memory.
- (+) The posted self-review passes ADR 0014 asked for now happen every time.
- (-) No one *notices* during the run. The log's *Not checked by a human* list and
  the walkthrough's screenshots are the substitute. Both are weaker than a person
  at the window, and the feature-PR review has to make up the difference.
- (-) A wrong policy answer compounds across slices before anyone reads it. The
  halt list and the per-feature policy are where that risk is priced. They should
  start strict.
- (-) The run draws on the developer's subscription usage, shared with their own
  work, and up to three review passes per slice make it heavier than a hand run.
- (-) The driver and its guard hook are harness-specific (Claude Code first). The
  commands' *Autopilot* paragraphs are plain markdown and work in any harness. The
  driver that invokes them does not, which is the routing/enforcement line the
  template draws for its whole alignment layer.
