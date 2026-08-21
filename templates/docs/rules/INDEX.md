# Rule index

Every convention in this repo is one file in `docs/rules/`. **Read this index, then
read only the rules you need.** Do not read a rule file you were not routed to.

Each rule file starts with YAML frontmatter:

```yaml
---
id: turbo-status                      # filename without .md
title: ...                            # one line
applies_to: ["app/controllers/**"]    # globs — if you are editing a match, the rule applies
triggers: ["form frozen", "422"]      # grep these when routing by symptom
see_also: ["controllers"]             # other rule ids
tokens: 340                           # approximate read cost
---
```

Three ways to route. Use whichever fits what you know:

1. **By file you are about to edit** → the `applies_to` table below.
2. **By symptom or keyword** → `grep -l "<keyword>" docs/rules/*.md`, or the trigger table below.
3. **By rule id** → the file is always `docs/rules/<id>.md`.

---

## Route by path

Editing a file that matches → read these rules.

| Path | Rules |
|---|---|
| `config/routes.rb` | [controllers](controllers.md) |
| `app/controllers/**` | [controllers](controllers.md) · [turbo-status](turbo-status.md) · [pagination](pagination.md) · [exception-boundary](exception-boundary.md) · [rate-limiting](rate-limiting.md) · [policy-objects](policy-objects.md) · [turbo-frames](turbo-frames.md) · [current-attributes](current-attributes.md) |
| `app/services/**` | [service-objects](service-objects.md) · [jobs](jobs.md) |
| `app/forms/**` | [form-objects](form-objects.md) |
| `app/queries/**` | [query-objects](query-objects.md) · [n-plus-one](n-plus-one.md) |
| `app/policies/**` | [policy-objects](policy-objects.md) |
| `app/lib/**` | [registries](registries.md) |
| `app/models/**` | [scopes](scopes.md) · [callbacks](callbacks.md) · [n-plus-one](n-plus-one.md) · [deletes](deletes.md) · [audit-trail](audit-trail.md) · [seeds](seeds.md) · [current-attributes](current-attributes.md) |
| `app/models/concerns/**` | [optional-patterns](optional-patterns.md) |
| `app/jobs/**`, `config/queue.yml` | [jobs](jobs.md) · [current-attributes](current-attributes.md) |
| `app/views/**/*.slim` | [slim-gotchas](slim-gotchas.md) · [partials](partials.md) · [tailwind](tailwind.md) · [tailwind-build](tailwind-build.md) · [empty-states](empty-states.md) · [forms-ui](forms-ui.md) · [accessibility](accessibility.md) · [n-plus-one](n-plus-one.md) · [caching](caching.md) · [turbo-frames](turbo-frames.md) |
| `app/components/**` | [components](components.md) · [view-code-placement](view-code-placement.md) · [tailwind](tailwind.md) · [tailwind-build](tailwind-build.md) · [accessibility](accessibility.md) · [turbo-frames](turbo-frames.md) |
| `app/helpers/**` | [view-code-placement](view-code-placement.md) |
| `app/javascript/controllers/**` | [stimulus](stimulus.md) · [tailwind-build](tailwind-build.md) |
| `app/views/**/*.turbo_stream.slim` | [turbo-streams](turbo-streams.md) |
| `db/migrate/**` | [safe-migrations](safe-migrations.md) · [database-conventions](database-conventions.md) · [seeds](seeds.md) |
| `db/seeds.rb`, `db/seeds/**` | [seeds](seeds.md) |
| `test/**` | [testing](testing.md) |
| `test/components/**` | [testing](testing.md) · [components](components.md) |
| Anything under `app/`, when you are unsure which layer calls which | [write-path](write-path.md) |
| Adding a new directory under `app/` | [pattern-budget](pattern-budget.md) · [rejected-patterns](rejected-patterns.md) |

## Route by symptom

| You are dealing with | Rule |
|---|---|
| A form that submits and nothing happens | [turbo-status](turbo-status.md) |
| Wanting a custom controller action / member route | [controllers](controllers.md) |
| An index or list page | [pagination](pagination.md) |
| Sign-in, password reset, contact form, anything that mails | [rate-limiting](rate-limiting.md) |
| `Order.find` and a 500 for a foreign id | [exception-boundary](exception-boundary.md) |
| Business logic longer than a controller action allows | [service-objects](service-objects.md) |
| One submit writing two models | [form-objects](form-objects.md) |
| `accepts_nested_attributes_for` | [rejected-patterns](rejected-patterns.md) → [form-objects](form-objects.md) |
| A query with joins that no longer reads as a scope | [query-objects](query-objects.md) |
| "Can *this* user do *this* to *this* record?" | [policy-objects](policy-objects.md) |
| Plans, tiers, product types, a fixed set of variants | [registries](registries.md) |
| `def self.something` returning a relation | [scopes](scopes.md) |
| A save that mysteriously writes another table | [callbacks](callbacks.md) |
| Slow page, Bullet warning, a query per row | [n-plus-one](n-plus-one.md) |
| Soft deletes, `discarded_at`, restoring a record | [deletes](deletes.md) |
| Change history, who changed what | [audit-trail](audit-trail.md) |
| Background work, retries, `perform_later` | [jobs](jobs.md) |
| `Rails.cache`, fragment caching, staleness | [caching](caching.md) |
| A migration against a table with real rows | [safe-migrations](safe-migrations.md) |
| Primary keys, foreign keys, indexes | [database-conventions](database-conventions.md) |
| A new model, process, or dependency that dev data should mirror | [seeds](seeds.md) |
| `db:seed` duplicating rows or failing on a rerun | [seeds](seeds.md) |
| Money, enums/state machines, a fat model | [optional-patterns](optional-patterns.md) |
| `Current.user` | [current-attributes](current-attributes.md) |
| Writing a test, a fixture, or a VCR cassette | [testing](testing.md) |
| A test over 500ms, or one that fails only in some orders | [testing](testing.md) |
| "Where does this code go?" | [pattern-budget](pattern-budget.md) |
| The same code written a third time | [pattern-budget](pattern-budget.md) |
| Proposing repository / CQRS / hexagonal / interactors | [rejected-patterns](rejected-patterns.md) |
| Understanding how the layers fit together | [write-path](write-path.md) |
| A Slim template rendering wrong, or `div.max-h-[85vh]` | [slim-gotchas](slim-gotchas.md) |
| A Tailwind class that has no effect | [tailwind-build](tailwind-build.md) |
| "Should this be a component or a partial?" | [view-code-placement](view-code-placement.md) |
| Building or testing a ViewComponent | [components](components.md) |
| A partial rendering blank, or reading `@ivars` | [partials](partials.md) |
| A Turbo frame that logs "content missing" | [turbo-frames](turbo-frames.md) |
| Live updates, `broadcasts_to`, real-time push | [turbo-streams](turbo-streams.md) |
| A Stimulus controller, or JS reaching into the DOM | [stimulus](stimulus.md) |
| Colors, dark mode, breakpoints | [tailwind](tailwind.md) |
| Form markup and error display | [forms-ui](forms-ui.md) |
| A list that renders nothing when empty | [empty-states](empty-states.md) |
| Keyboard, contrast, aria, screen readers | [accessibility](accessibility.md) |

---

## Full list

| Rule | Tokens | Covers |
|---|---|---|
| [controllers](controllers.md) | 630 | Seven actions, new verb = new resource, thin actions |
| [turbo-status](turbo-status.md) | 430 | 422 on validation failure, the frozen-form bug |
| [pagination](pagination.md) | 350 | Pagy, every index paginates |
| [rate-limiting](rate-limiting.md) | 320 | Rails 8 `rate_limit`, what to apply it to |
| [exception-boundary](exception-boundary.md) | 400 | `rescue_from` once, scoped lookups |
| [service-objects](service-objects.md) | 610 | `ApplicationService`, Result, transactions |
| [form-objects](form-objects.md) | 680 | `ApplicationForm`, never nested attributes |
| [query-objects](query-objects.md) | 440 | Joins ≥2 models, always return a relation |
| [policy-objects](policy-objects.md) | 510 | Record-level auth vs Petergate roles |
| [registries](registries.md) | 770 | `Data` objects, `fetch`, capabilities not identities |
| [scopes](scopes.md) | 210 | Scopes, never class methods |
| [callbacks](callbacks.md) | 360 | Same record only, `after_commit` for jobs |
| [n-plus-one](n-plus-one.md) | 350 | `includes`, `counter_cache`, aggregate in SQL |
| [deletes](deletes.md) | 490 | `destroy` by default, Discard opt-in, the `.kept` tax |
| [audit-trail](audit-trail.md) | 290 | PaperTrail, scoped with `only:` |
| [jobs](jobs.md) | 510 | Thin wrapper, IDs not records, idempotent, after commit |
| [caching](caching.md) | 470 | Solid Cache, russian-doll, always key by user |
| [safe-migrations](safe-migrations.md) | 370 | Concurrent indexes, two-deploy column removal |
| [database-conventions](database-conventions.md) | 550 | Primary keys per database (UUID on PostgreSQL, bigint on MySQL), foreign keys, composite indexes |
| [seeds](seeds.md) | 400 | Idempotent seeds, kept in step with models and processes |
| [optional-patterns](optional-patterns.md) | 630 | Value objects, status columns, concerns |
| [current-attributes](current-attributes.md) | 230 | Two acceptable uses, and why |
| [pattern-budget](pattern-budget.md) | 680 | Six directories, DRY triggers, ADR for a seventh |
| [rejected-patterns](rejected-patterns.md) | 460 | Repository, CQRS, hexagonal, interactors, DI, decorators |
| [write-path](write-path.md) | 310 | Layer order end to end |
| [slim-gotchas](slim-gotchas.md) | 620 | Brackets, pipes, `ruby:` blocks, strict-locals syntax |
| [tailwind-build](tailwind-build.md) | 330 | Interpolated classes are purged; no class strings in JS |
| [view-code-placement](view-code-placement.md) | 430 | Component vs partial vs helper vs inline |
| [components](components.md) | 1110 | ViewComponent shape, slots, variants, tests |
| [partials](partials.md) | 450 | Strict locals, no instance variables, collections |
| [turbo-frames](turbo-frames.md) | 380 | Stable ids, matching responses, lazy, morphing |
| [turbo-streams](turbo-streams.md) | 560 | Controller streams; model broadcasts are the footgun |
| [stimulus](stimulus.md) | 610 | Targets/values/classes, idempotent `connect()` |
| [tailwind](tailwind.md) | 470 | Semantic colors, dark mode, breakpoints |
| [forms-ui](forms-ui.md) | 360 | `form_with`, error summary, field errors |
| [empty-states](empty-states.md) | 250 | The state everyone forgets |
| [accessibility](accessibility.md) | 290 | Semantic HTML, contrast, keyboard, focus |
| [testing](testing.md) | 1010 | Minitest + fixtures, which layer tests what, VCR |

**Total corpus:** ~18,320 tokens across 38 rules. Typical read: this index (~3000)
plus one or two rules (210–1110). Reading the whole corpus is a bug, not thoroughness.

These figures are generated from the files by `bin/doc-tokens`, not typed by hand —
a hand-typed one is stale the next time a rule is edited, and a budget nobody can
trust is worse than no budget. Run `bin/doc-tokens` after editing a rule, or
`bin/doc-tokens --check` to fail a doc pass that forgot.

---

## Maintaining this

- **One fact, one file.** If a rule appears in two files, one of them is a link.
- Adding a rule: create `docs/rules/<id>.md` with full frontmatter, then add rows
  to *route by path*, *route by symptom*, and *full list*.
- The `id` and the filename must match. Other files reference rules by id.
- Architecture *decisions* (why the rule exists, consequences accepted) stay as
  ADRs in [`../adr/`](../adr/), one file per decision. Rules say what to do; ADRs
  say why it was chosen. Don't merge them.
- Backend and view rules live side by side here. There is no separate view doc —
  `applies_to` globs are what separate them, and an agent editing a `.slim` file
  never sees a controller rule.
