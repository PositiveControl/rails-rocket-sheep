# Rule lookup — by symptom, and the full list

Read this **only when [`INDEX.md`](INDEX.md) did not answer you** — when you know the
problem but not which file you are editing, or you want to see the whole corpus at
once. Routing by path is cheaper and lands in the same place; start there.

## Route by symptom

| You are dealing with | Rule |
|---|---|
| An error body a client cannot parse without a type check | [error-envelope](error-envelope.md) |
| Choosing between 400 and 422, or 401 and 403 | [status-codes](status-codes.md) |
| A response shape built in the action | [serialization](serialization.md) |
| Bearer tokens, scopes, revoking a token | [api-auth](api-auth.md) |
| Removing, renaming or retyping a field | [api-versioning](api-versioning.md) · [deprecation-policy](deprecation-policy.md) |
| A list endpoint, a next page, or an unbounded response | [cursor-pagination](cursor-pagination.md) |
| Untrusted JSON in a request body | [request-contracts](request-contracts.md) |
| `where(params[...])`, or an arbitrary sort column | [filtering-sorting](filtering-sorting.md) |
| A browser request blocked before it reaches Rails | [cors](cors.md) |
| A client retry that charged the card twice | [idempotency](idempotency.md) |
| Work too slow to finish inside the request | [async-202](async-202.md) |
| A client wanting fewer fields, or a nested resource | [sparse-fieldsets-includes](sparse-fieldsets-includes.md) |
| One call that has to touch many records | [bulk-endpoints](bulk-endpoints.md) |
| An API document that disagrees with the code | [openapi-contract](openapi-contract.md) |
| What to test, and at which layer | [api-testing](api-testing.md) · [testing](testing.md) |
| What the frontend may rely on | [client-contract](client-contract.md) |
| Wanting a custom controller action | [controllers](controllers.md) |
| A 500 for an id that belongs to someone else | [exception-boundary](exception-boundary.md) |
| Business logic longer than a controller action allows | [service-objects](service-objects.md) |
| One write that touches two models | [service-objects](service-objects.md) |
| A query with joins that no longer reads as a scope | [query-objects](query-objects.md) |
| "Can *this* user do *this* to *this* record?" | [policy-objects](policy-objects.md) |
| Sign-in, a public endpoint, anything that costs money per call | [rate-limiting](rate-limiting.md) |
| `def self.something` returning a relation | [scopes](scopes.md) |
| A save that mysteriously writes another table | [callbacks](callbacks.md) |
| Slow endpoint, Bullet warning, a query per row | [n-plus-one](n-plus-one.md) |
| Soft deletes, restoring a record | [deletes](deletes.md) |
| Change history, who changed what | [audit-trail](audit-trail.md) |
| Background work, retries, `perform_later` | [jobs](jobs.md) |
| `Rails.cache`, staleness, a conditional GET | [caching](caching.md) |
| A migration against a table with real rows | [safe-migrations](safe-migrations.md) |
| Primary keys, foreign keys, indexes | [database-conventions](database-conventions.md) |
| A new model or process that dev data should mirror | [seeds](seeds.md) |
| `db:seed` duplicating rows or failing on a rerun | [seeds](seeds.md) |
| Money, enums/state machines, a fat model | [optional-patterns](optional-patterns.md) |
| Plans, tiers, a fixed set of variants | [registries](registries.md) |
| `Current.user` | [current-attributes](current-attributes.md) |
| "Where does this code go?" | [pattern-budget](pattern-budget.md) |
| The same code written a third time | [pattern-budget](pattern-budget.md) |
| Proposing repository / CQRS / hexagonal / interactors | [rejected-patterns](rejected-patterns.md) |
| Understanding how the layers fit together | [write-path](write-path.md) |

## Full list

| Rule | Tokens | Covers |
|---|---|---|
| [api-auth](api-auth.md) | 830 | Doorkeeper, coarse scopes, server-side revocation |
| [api-testing](api-testing.md) | 750 | Request tests are the layer that matters |
| [api-versioning](api-versioning.md) | 610 | One number in the path, additive within it |
| [async-202](async-202.md) | 610 | 202, a `Location`, and a real status resource |
| [audit-trail](audit-trail.md) | 300 | PaperTrail, scoped with `only:` |
| [bulk-endpoints](bulk-endpoints.md) | 690 | Capped, per-item results, never the first answer |
| [caching](caching.md) | 490 | Solid Cache, russian-doll, always key by user |
| [callbacks](callbacks.md) | 370 | Same record only, `after_commit` for jobs |
| [client-contract](client-contract.md) | 750 | What the client may rely on, and what it must not |
| [controllers](controllers.md) | 950 | Seven actions, new verb = new resource, thin actions |
| [cors](cors.md) | 590 | Named origins, and never a wildcard with credentials |
| [current-attributes](current-attributes.md) | 240 | Two acceptable uses, and why |
| [cursor-pagination](cursor-pagination.md) | 900 | Cursor first, `(created_at, id)`, never an array |
| [database-conventions](database-conventions.md) | 560 | Primary keys per database (UUID on PostgreSQL, bigint on MySQL), foreign keys, composite indexes |
| [deletes](deletes.md) | 500 | `destroy` by default, Discard opt-in, the `.kept` tax |
| [deprecation-policy](deprecation-policy.md) | 630 | `Deprecation` and `Sunset`, a date, and evidence |
| [error-envelope](error-envelope.md) | 840 | RFC 9457 problem documents, and a machine-readable `type` |
| [exception-boundary](exception-boundary.md) | 610 | `rescue_from` once, scoped lookups |
| [filtering-sorting](filtering-sorting.md) | 730 | An allowlist that is data, not control flow |
| [idempotency](idempotency.md) | 800 | A key on every write that costs money |
| [jobs](jobs.md) | 520 | Thin wrapper, IDs not records, idempotent, after commit |
| [n-plus-one](n-plus-one.md) | 370 | `includes`, `counter_cache`, aggregate in SQL |
| [openapi-contract](openapi-contract.md) | 700 | Generated from the request tests; CI fails on drift |
| [optional-patterns](optional-patterns.md) | 640 | Value objects, status columns, concerns |
| [pattern-budget](pattern-budget.md) | 970 | Six directories, DRY triggers, ADR for a seventh |
| [policy-objects](policy-objects.md) | 750 | Record-level auth vs Petergate roles |
| [query-objects](query-objects.md) | 450 | Joins ≥2 models, always return a relation |
| [rate-limiting](rate-limiting.md) | 580 | Rails 8 `rate_limit`, what to apply it to |
| [registries](registries.md) | 790 | `Data` objects, `fetch`, capabilities not identities |
| [rejected-patterns](rejected-patterns.md) | 510 | Repository, CQRS, hexagonal, interactors, DI, decorators |
| [request-contracts](request-contracts.md) | 820 | Validate the body before a model sees it |
| [safe-migrations](safe-migrations.md) | 380 | Concurrent indexes, two-deploy column removal |
| [scopes](scopes.md) | 220 | Scopes, never class methods |
| [seeds](seeds.md) | 420 | Idempotent seeds, kept in step with models and processes |
| [serialization](serialization.md) | 770 | One plain object per resource, explicit fields, nothing else |
| [service-objects](service-objects.md) | 860 | `ApplicationService`, Result, transactions |
| [sparse-fieldsets-includes](sparse-fieldsets-includes.md) | 700 | `fields` and `include`, allowlisted, one level deep |
| [status-codes](status-codes.md) | 920 | Which status, and the outcome that is neither success nor failure |
| [testing](testing.md) | 1150 | Minitest + fixtures, which layer tests what, VCR |
| [write-path](write-path.md) | 590 | Layer order end to end |

**Total corpus:** ~25,860 tokens across 40 rules — but nobody reads it whole.
A typical lookup is [`INDEX.md`](INDEX.md) plus one or two rules.

These figures are generated from the files by `bin/doc-tokens`, not typed by hand — a
hand-typed one is stale the next time a rule is edited, and a budget nobody can trust
is worse than no budget. Run `bin/doc-tokens` after editing a rule, or
`bin/doc-tokens --check` to fail a doc pass that forgot.

---

## Maintaining this

- **One fact, one file.** If a rule appears in two files, one of them is a link.
- Adding a rule: create `docs/rules/<id>.md` with full frontmatter — including `modes`,
  which decides the index it belongs in — then add a row to *route by path* (or a
  conditional table) in [`INDEX.md`](INDEX.md), and rows to *route by symptom* and
  *full list* here. `bin/lint-docs` checks all three, per mode.
- The `id` and the filename must match. Other files reference rules by id.
- Routing is two-tier on purpose: [`INDEX.md`](INDEX.md) is the entry point and stays
  small, this file is the fallback. Moving a symptom row into the index re-creates the
  fan-out the split removed.
- Architecture *decisions* (why the rule exists, consequences accepted) stay as ADRs in
  [`../adr/`](../adr/), one file per decision. Rules say what to do; ADRs say why it was
  chosen. Don't merge them.
