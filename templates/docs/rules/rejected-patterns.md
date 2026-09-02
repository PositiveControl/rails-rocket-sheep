---
id: rejected-patterns
title: Rejected patterns — deliberately excluded, ADR required
applies_to: ["app/**"]
triggers: ["repository pattern", "CQRS", "event sourcing", "hexagonal", "ports and adapters", "interactor", "organizer", "dry-rb", "DI container", "dependency injection", "serializer", "decorator", "SimpleDelegator", "accepts_nested_attributes_for"]
see_also: ["pattern-budget", "form-objects"]
modes: [ web, api ]
tokens: 520
current_state: matches
---

# Rejected patterns

Not neutral omissions — deliberately excluded. If a PR introduces one, it needs an
ADR in [`../adr/`](../adr/) explaining what changed.

| Pattern | Why not |
|---|---|
| Repository pattern | Fights ActiveRecord. You lose scopes, `includes`, and pagination to gain a swap you will never perform. |
| CQRS / event sourcing | Solves a scale and audit problem this app doesn't have. PaperTrail gives the audit trail for 1% of the cost. |
| Hexagonal / ports & adapters | Rails is already the adapter layer. A second one doubles the file count and halves the greppability. |
| Interactor / organizer chains | Twelve one-method classes to express what one service reads better. Control flow becomes invisible. |
| DI containers | Ruby has `require` and constants. Injection is `def initialize(client: StripeClient.new)`. |
| Serializers for HTML responses | In server-rendered mode this app renders HTML; add serializers when a JSON API exists, not before. In API mode `app/serializers/` is where every response body comes from — see [serialization](serialization.md). |
| `accepts_nested_attributes_for` | Use a form object in server-rendered mode, a request contract in API mode. Nested attributes hide writes in the assignment path and produce error keys nobody can render. |
| Decorators for everything | A component or a helper covers it. `SimpleDelegator` chains defeat `method_missing` debugging. |

The catalogue that *is* sanctioned: [pattern-budget](pattern-budget.md).
