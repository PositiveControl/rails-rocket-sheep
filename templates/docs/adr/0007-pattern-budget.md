# Pattern Budget

**Status:** Accepted

**Context:**
Pattern catalogues sprawl. The failure mode is eight directories under `app/`, each
holding two classes nobody can tell apart, and a codebase where finding the code that
runs takes four hops.

**Decision:**
Six pattern directories are sanctioned: `services`, `forms`, `queries`, `policies`,
`lib` (registries), `components`. Each has a stated trigger in
`docs/rules/pattern-budget.md`. A seventh top-level directory under `app/` requires
an ADR. Explicitly rejected: repository pattern, CQRS/event sourcing, hexagonal
architecture, interactor chains, DI containers, `accepts_nested_attributes_for`.

**Consequences:**
- (+) A reader can predict where any piece of logic lives
- (+) New patterns arrive by decision, not by drift
- (-) Occasionally the sanctioned six are a slightly awkward fit
- (-) Requires enforcement in review; the rule is only as good as the reviewer
