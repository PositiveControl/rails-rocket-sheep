---
id: write-path
title: The write path end to end — which layer calls which
applies_to: ["app/**"]
triggers: ["layering", "which layer", "order of operations", "architecture overview", "jumps a layer", "view calls service", "model sends mail", "how do these fit together"]
see_also: ["pattern-budget", "controllers", "service-objects"]
modes: [ web, api ]
tokens: 580
current_state: matches
---

# The write path, end to end

The patterns compose in one predictable order:

```
Request
  → Controller       parse params, delegate, branch on Result, set status
    → Policy         may this user do this to this record?
    → Form           validate user input, shape it
      → Service      coordinate the write, own the transaction
        → Registry   look up configuration
        → Model      validate, persist, normalize its own attributes
        → Job        enqueue follow-up work after commit
  → View             components + partials render the result
```

Reads take the shorter path: controller → scope or query object → paginate → view.

**Anything that jumps a layer is the thing to flag in review** — a view calling a
service, a model enqueuing mail, a controller writing three models.

## In API mode

No view layer, and two objects on the way in that the HTML path does not have:

```
Request
  → Controller    authenticate, authorize, validate the contract, delegate, map Result to status
    → Filter      untrusted query string → relation                      (reads)
    → Contract    untrusted request body → validated object              (writes)
      → Service   owns the transaction; network calls happen outside it
        → Model   validates and persists; a save is never a side effect of a logger
        → Job     enqueued after commit
  → Serializer    the response shape, defined once per resource
```

Two clauses there are not decoration. **Network calls outside the transaction**: a
provider call inside one holds a lock for as long as the provider takes. **A save is
never a side effect**: a status that reaches the database because an unrelated logging
method happened to call `save!` is a write nobody can find, and the response will
report it whether it persisted or not.
