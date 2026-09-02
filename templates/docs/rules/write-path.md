---
id: write-path
title: The write path end to end — which layer calls which
applies_to: ["app/**"]
triggers: ["layering", "which layer", "order of operations", "architecture overview", "jumps a layer", "view calls service", "model sends mail", "how do these fit together"]
see_also: ["pattern-budget", "controllers", "service-objects", "form-objects"]
modes: [ web, api ]
tokens: 320
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
