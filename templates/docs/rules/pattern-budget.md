---
id: pattern-budget
title: Pattern budget — six directories, where code goes
applies_to: ["app/**"]
triggers: ["where does this go", "new directory", "app/services", "app/forms", "app/queries", "app/policies", "app/lib", "app/components", "seventh directory", "pattern sprawl", "DRY", "extract"]
see_also: ["rejected-patterns", "write-path", "service-objects", "form-objects", "query-objects", "policy-objects", "registries", "optional-patterns"]
modes: [ web, api ]
tokens: 990
current_state: matches
---

# Pattern budget

A pattern earns a place only if it clears three bars:

1. **It recurs.** Not once — most weeks.
2. **The wrong default is expensive.** Silent Turbo failures, N+1s, unbounded queries.
3. **A reviewer can check it in a diff.** If nobody can tell whether the rule was
   followed, it isn't a rule, it's a mood.

The failure mode of a pattern catalogue is sprawl: eight directories under `app/`
each holding two files nobody can tell apart.

| Directory | Holds | Add a file when | Rule |
|---|---|---|---|
| `app/services/` | Multi-step writes with a failure path | Touches >1 model, or called from >1 place | [service-objects](service-objects.md) |
| `app/forms/` | Form objects for multi-model or non-AR forms | One submit writes ≥2 models, or a field isn't a column | [form-objects](form-objects.md) |
| `app/queries/` | Reads that join ≥2 models | A scope would need a join and 3+ clauses | [query-objects](query-objects.md) |
| `app/policies/` | Record-level authorization | The answer depends on the record, not just the role | [policy-objects](policy-objects.md) |
| `app/lib/` | Registries — fixed variant sets | Values are code, not user data | [registries](registries.md) |
| `app/components/` | Rendered UI units | Markup has logic or variants, or is reused | [components](components.md) |

**Six. Not seven.** A new top-level directory under `app/` is an architecture
decision: record it as an ADR in [`../adr/`](../adr/), which `/domain_model`
writes, or don't create it.

The default for any given piece of code is still **a model method, a scope, or a
controller action**. Reach for a pattern when plain Rails has actually run out.

## DRY

Same code 2–3 times is the trigger. Where it goes depends on what repeats:

| What repeats | Where it goes |
|---|---|
| A role across models | Concern — see [optional-patterns](optional-patterns.md) |
| Coordination | Service |
| Markup | Component |
| Formatting | Helper |
| A query | Scope |

Extracting into the wrong one costs more than the duplication did.

Patterns that do **not** clear the three bars: [rejected-patterns](rejected-patterns.md).

## In API mode

Seven directories, not six. `app/forms/` and `app/components/` lose their basis — a
form object shapes a submit and a component renders markup — and three take their
place.

| Directory | Holds | Add a file when | Rule |
|---|---|---|---|
| `app/serializers/` | The response shape for a resource | An endpoint returns that resource | [serialization](serialization.md) |
| `app/contracts/` | Validation of an untrusted request body | An endpoint accepts a body | [request-contracts](request-contracts.md) |
| `app/filters/` | Query-string filtering and sorting | An endpoint returns a collection | [filtering-sorting](filtering-sorting.md) |

`services`, `queries`, `policies` and `lib` carry over unchanged.

**Seven. Not eight.** `contracts` and `filters` are the pair most often confused,
because both allowlist untrusted input at the same boundary. The split is by return
type: a contract yields a validated object, a filter yields a relation. Two return
types under one name is how a directory becomes a junk drawer.

Rationale and consequences: [ADR 0007](../adr/0007-pattern-budget.md).
