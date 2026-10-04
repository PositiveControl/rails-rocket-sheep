# Template ADRs reserve 0001–0099; an app numbers its own from 0100

Amends [0008](0008-decisions-are-one-file-each.md).

## Context

ADR 0008 made a generated app's decisions one file each, `NNNN-<slug>.md`, numbered
in sequence. The template ships the first ones (0001–0015 at the time of writing),
and `/domain_model` writes the app's own at "next number".

That works until the template adds an ADR after an app has added its own. The first
adopter to hit it was the app autopilot was ported from: its own 0016 and 0017
already existed when the autopilot ADR, its 0018, came back to the template as the
template's next ADR, 0016. A three-way update would land a second `0016-*`. The
file names differ, so nothing conflicts, and the numbering silently breaks: two
decisions share a number, and "see ADR 0016" means two things.

This recurs with every template ADR an app has not seen yet.

## Decision

**The template's ADRs take 0001–0099. An app's own ADRs start at 0100.**

- `/domain_model` writes an app's decision at the next free number from 0100.
- The template's next ADR takes the next free number below 0100.
- An app that already has its own ADRs inside 0001–0099 renumbers them once, as
  part of its first update after this change. The shipped procedure is
  `templates/docs/sop/update-from-the-template.md`.

## Consequences

- One renumbering for each existing adopter, after which there are no collisions,
  in either direction.
- With this port the template holds 0001–0016, which leaves room for 83 more.
  Running out is a signal that decisions are not being superseded and folded, and
  is reason enough to revisit.
- A number tells you whose decision it is: below 0100 the template's, from 0100 the
  app's.

## Rejected

- **Renumber the app's ADRs on every collision.** This recurs forever, and a
  renumbering breaks every link to the old number in the app's docs and commits.
- **A prefix (`T-0016`) for template ADRs.** It breaks 0008's `NNNN-<slug>.md`
  shape, which `lint-docs` and the index rely on.
