# Pattern Budget

**Applies to:** both modes, with a different membership. Server-rendered mode gets
six directories; API mode gets seven — `forms` and `components` lose their basis,
and `serializers`, `contracts` and `filters` take their place. The budget is the
decision; the list is per mode. See `docs/rules/pattern-budget.md`.

**Status:** Accepted

**Context:**
Pattern catalogues sprawl. The failure mode is eight directories under `app/`, each
holding two classes nobody can tell apart, and a codebase where finding the code that
runs takes four hops.

**Decision:**
A fixed set of pattern directories is sanctioned, and it is per mode. Server-rendered
mode gets six: `services`, `forms`, `queries`, `policies`, `lib` (registries),
`components`. API mode gets seven: `services`, `queries`, `policies`, `lib`,
`serializers`, `contracts`, `filters` — `forms` and `components` have no basis
without a view layer, and the three that replace them each clear the bars the rule
states. Each directory has a stated trigger in `docs/rules/pattern-budget.md`. A
directory beyond this app's set requires an ADR.

`contracts` and `filters` are adjacent and split by return type: a request body
becomes a validated value object, a query string becomes a relation. That one line is
the whole test, and without it the seventh directory becomes the sixth by drift. Explicitly rejected: repository pattern, CQRS/event sourcing, hexagonal
architecture, interactor chains, DI containers, `accepts_nested_attributes_for`.

**Consequences:**
- (+) A reader can predict where any piece of logic lives
- (+) New patterns arrive by decision, not by drift
- (-) Occasionally the sanctioned six are a slightly awkward fit
- (-) Requires enforcement in review; the rule is only as good as the reviewer
