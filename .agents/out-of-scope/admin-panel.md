# An admin panel is out of scope

No Avo, no Administrate, no ActiveAdmin.

## Why this is out of scope

Every admin gem brings its own conventions: its own controllers, its own view
layer, its own way of declaring fields and permissions. Those conventions do not
route through the six sanctioned directories under `app/`
(`docs/rules/pattern-budget.md`), do not use `ApplicationService` or
`ApplicationForm`, and do not render through ViewComponent. An app with one of them
installed has two architectures, and the rule corpus only describes one.

Admin requirements are also unusually app-specific. What a buyer needs is rarely
"CRUD for every table"; it is a handful of operational screens for the three models
that matter, which the existing conventions build faster than a gem's DSL can be
bent into shape.

## What to do instead

Build the screens you actually need as ordinary controllers, policies, and
components. Role gating is Petergate; record-level checks are policy objects
(`docs/rules/policy-objects.md`).

## What would change our mind

An admin gem that renders through ViewComponent and delegates authorization to
policy objects, or a buyer report that operational screens are consistently the
slow part of the first week.
