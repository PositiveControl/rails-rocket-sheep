---
id: design-docs
title: Design docs — tables owned by the subject, not the flow
applies_to: ["docs/plans/**"]
triggers: ["design doc", "plan doc", "status table", "table owned by", "per model", "per flow", "feature_plan"]
see_also: ["invariants"]
tokens: 140
---

# Design docs — tables owned by the subject

A design-doc table keyed by **flow** — one row per step, columns for the records it
touches — makes every reader re-derive, per row, which subject carries which state.
Re-derived logic gets re-derived wrong, and the doc is where the next author learns the
wrong version.

- **Key the table by the subject** — the model or record — and list what each flow does
  to it. One row per thing that has state; the flows are the columns.
- The shipped [`../system/models.md`](../system/models.md) is the living example: one
  section per model, its associations and fields under it, never a cross-model matrix
  keyed by process.

Why this matters — one real thing described in two places drifts:
[`../system/invariant-drift.md`](../system/invariant-drift.md).
