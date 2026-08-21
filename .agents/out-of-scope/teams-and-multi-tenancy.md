# Teams and multi-tenancy are out of scope

A generated app is single-tenant. No `Team` model, no `acts_as_tenant`, no
tenant-scoped default scopes.

## Why this is out of scope

Tenancy is an architectural choice, not a feature. Row-level (a `tenant_id` on
every table), schema-per-tenant, and database-per-tenant have different
consequences for every migration, every query, every policy, and every backup, and
the right one depends on tenant count, data isolation requirements, and the
regulatory story.

Shipping one of the three would silently make that decision for every buyer, and
it is the hardest of all of them to reverse: undoing a default scope that every
query has relied on is a rewrite. Shipping none leaves the retrofit cost with the
buyer, which is real but bounded, and only paid by the buyers who need it.

The single-tenant default also keeps the authorization rules honest. `Scope every
lookup` (`docs/rules/exception-boundary.md`) and record-level policies
(`docs/rules/policy-objects.md`) are the same discipline tenancy needs, so an app
built on them is in a better position to add tenancy later than one that inherited
a `default_scope` it never thought about.

## What to do instead

- Building an app that is fundamentally about teams with granular roles? Bullet
  Train is built around exactly that.
- Adding tenancy here: pick the model deliberately, write it as an ADR in
  `docs/system/architecture.md`, and put the scoping in policies and query objects
  rather than a `default_scope`. `docs/rules/deletes.md` explains why an implicit
  default scope is the pattern that bites.

## What would change our mind

A `docs/sop/` procedure for adding row-level tenancy to these conventions. That is
documentation, not a shipped model, and it does not choose for anyone.
