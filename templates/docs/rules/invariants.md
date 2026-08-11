---
id: invariants
title: Invariants — one writer, one chokepoint, not one copy per call site
applies_to: ["app/models/**/*.rb", "app/services/**/*.rb"]
triggers: ["join table", "state table", "only writer", "invariant", "status write", "who else writes", "same state in two services", "awaiting_shipment", "chokepoint", "source_id", "predecessor", "gate on status"]
see_also: ["write-path", "callbacks", "optional-patterns", "testing", "registries"]
tokens: 260
---

# Invariants — one owner, not one copy per call site

A rule that must hold whenever a record is created or transitioned belongs on that
record's life cycle, not restated in each service that writes it. Spread across call
sites, it holds only on the paths whose authors knew about it.

- **Before you write a state into a join or state table, find the other writers.**
  `git grep` the state. Is this the only writer? If not, do the others do the same
  thing? Make them agree, or route them all through **one chokepoint**:
  - a single service every path calls — see [write-path](write-path.md);
  - a validated transition on the model (`transition_to!` + a registry) — see
    [optional-patterns](optional-patterns.md);
  - a DB constraint, where the rule is genuinely structural;
  - an `after_create` on the join model — but only one that touches **its own**
    record. Writing *other* tables from a callback is still forbidden:
    [callbacks](callbacks.md). Then delete the duplicates.

- **When one real thing becomes two rows, name the mapping on day one.** Ownership
  transfer, versioning, soft-delete-and-recreate, STI copies — each duplication makes
  every later feature re-derive which row carries the status and which the system
  points at. The tell is a repeated `where(source_x_id: …)` in more than one file. The
  fix is one named method on the model that every consumer calls — written when you
  introduce the duplication, not when the fifth consumer appears.

- **Gate on the fact you mean, not on something that correlates with it.** A condition
  written against a `status` usually means something else — "is this the buyer's copy",
  "do we still hold this", "has this been paid for". Status correlates today and stops
  the moment a new flow produces a different one. Test the fact directly: ownership,
  association presence, a timestamp. Keep the status check only when status is the thing
  you actually mean.

Prove the invariant holds on **every** path with one enumerated test —
[testing](testing.md), "Invariant tests".

Rationale and the failure life cycle: the shipment post-mortem in
[`../system/invariant-drift.md`](../system/invariant-drift.md).
