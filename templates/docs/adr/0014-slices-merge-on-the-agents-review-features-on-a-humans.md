# Slices Merge on the Agent's Review, Features on a Human's

**Applies to:** both modes. Any feature `/feature_plan` cuts into more than one
slice.

**Status:** Accepted

**Context:**
Every PR used to target `main`, and every merge waited on a human reading the diff.
With one developer and several agent sessions producing slices in parallel, that
reading became the bottleneck: work finished in hours sat for days, and the sizing
table's own evidence said so — the wait grew with the diff, not the risk.

Two answers were on the table. Stacked PRs keep every slice reviewed by a human and
change nothing about who reads; they only let the next slice start before the last
one lands. The queue is the same length, and the footer generator that kept the
stacks honest broke on the first fork. The other answer moves where the human
reads.

**Decision:**
A multi-slice feature lands on `feature/<slug>`. Each slice is a PR into that
branch, reviewed by `/pr_review` run from a **fresh session** — a context with no
memory of writing the code — once per pass, two passes at most: the second runs
only when the first's fixes need it, and reviews only those fixes. GitHub refuses
APPROVE on one's own PR, so each pass posts as COMMENT and stays on the PR as
evidence. The developer merges the slice from that session on the strength of
those passes, without reading the diff themselves.

The cap was five passes, until a pass came back clean. It is two because
until-clean loops feed on their own fixes: later passes found bugs inside earlier
passes' fixes, or undid them, and a fix test that passed with and without its fix
pinned nothing. So each fix now lands with a test shown to fail without it, and
what the second pass still finds goes to the developer rather than to a third.

The feature reaches `main` as one PR, and that review is a human's: an
acceptance-criteria walk over the design doc's slice list, reading the posted
passes, spot-checking where they disagree or fall silent. G4 is unchanged in kind
— review comments resolved, a human at the gate — and changes only in what the
comments are: on a slice, a fresh session's; on the feature PR, a person's.

`Closes #n` fires only on a merge to the default branch, so slice PRs carry none
and the feature PR body collects one per landed slice. Done means *in `main`* on
every tier, exactly as before.

**Consequences:**
- (+) Slices stop waiting on a reader. The per-slice human cost is two commands, not
  an afternoon
- (+) Every slice carries its review history on the PR. The feature-PR reviewer reads
  reviews, not 7,000 lines
- (+) `bin/pr-stack` and the stacking rules are gone; there is nothing to keep
  linear
- (-) Line-level review is now the agent's, and a fresh context is one opinion, not
  a second person. The independence is real but bounded; the cap of two passes is
  where that bound is admitted
- (-) The human reviews at feature scope and will catch fewer line-level faults than
  they would have per slice. That trade is the decision
- (-) A feature branch drifts from `main` for as long as the feature takes. Merging
  `origin/main` into it after every slice keeps the final merge small; skipping that
  step makes it large
- (-) Two agents on sibling slices collide in the feature branch, not on `main`.
  That is where the collision belongs, and it is still a collision

**Amended 2026-10-03: what the rounds found.** A tally over a 13-slice feature in
an adopting app (`docs/system/workflow-optimizations.md`, item 9, *Fewer review rounds*)
split each slice's four reviews into two kinds:
- **Whole-diff reviews.** The local round 1 and self-review pass 1 found 22 and 14
  real bugs. Pass 1 still found a new real bug, missed by both local rounds, in 9
  of the 13 slices.
- **Fix-only reviews.** Local round 2 and pass 2 found only bugs that the
  previous round's fixes had introduced, or gaps those fixes left.

Two changes follow:
- **One local round for a slice.** Pass 1 re-reads round 1's fixes as part of the
  whole diff. A PR into the default branch keeps two local rounds, because no
  agent pass follows it.
- **The "only when the first's fixes need it" rule is checked, not trusted.** Each
  pass's body carries a `**Findings:**` line, and pass 2 runs only when pass 1
  counted a blocker or suggestion. Under autopilot the driver reads that line
  (ADR 0016), so nitpick and log commits no longer trigger a second pass.
