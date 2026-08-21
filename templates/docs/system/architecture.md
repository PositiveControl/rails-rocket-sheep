# Architecture Decision Records

This document tracks important architectural decisions for the project.

## ADR-001: Rails 8 Solid Stack

**Status:** Accepted

**Context:**
Needed to choose infrastructure for background jobs, caching, and WebSockets.

**Decision:**
Use Rails 8 Solid Stack (Solid Queue, Solid Cache, Solid Cable) - all database-backed.

**Consequences:**
- (+) No Redis dependency - simpler infrastructure
- (+) Built into Rails 8 - well supported
- (+) Database-backed - reliable, transactional
- (-) Slightly higher database load
- (-) May need separate databases at scale

---

## ADR-002: Primary Keys Follow the Database

**Status:** Accepted

**Context:**
Needed to choose a primary key strategy. The answer is not the same on both
databases this app could have been generated for: PostgreSQL has a native `uuid`
type and `gen_random_uuid()`, MySQL has neither.

**Decision:**
UUID primary keys on PostgreSQL, using the built-in `gen_random_uuid()` — no
`pgcrypto` extension is needed on PostgreSQL 13+. Rails' default bigint primary
keys on MySQL and MariaDB.

Which one this app has is on the Tech Stack line of `CLAUDE.md`, and the working
conventions for each are in
[`../rules/database-conventions.md`](../rules/database-conventions.md).

**Consequences:**
- (+) On PostgreSQL: no ID guessing or enumeration, safe for distributed systems,
  IDs can be generated client-side
- (+) On MySQL: no type shim to own, smaller indexes, and `t.references` behaves
  the way every Rails guide says it does
- (-) On PostgreSQL: larger storage (16 bytes vs 4-8) and no natural ordering,
  mitigated with `implicit_order_column`
- (-) On MySQL: sequential IDs enumerate, so a public URL needs a slug or a
  random token rather than the key
- (-) The two flavours differ in a convention, not just in configuration, so the
  rule file has two halves and a migration between databases is not a config
  change

---

## ADR-003: Service Object Pattern

**Status:** Accepted

**Context:**
Controllers were getting fat with business logic.

**Decision:**
Use `ApplicationService` base class with Result pattern for all business logic.

**Consequences:**
- (+) Testable business logic
- (+) Consistent return values (Result object)
- (+) Single responsibility
- (-) More files to manage
- (-) Learning curve for new developers

---

## ADR-004: Real Deletes by Default, Discard Opt-In

**Status:** Accepted

**Context:**
Soft deletion as a house style means every query, association, and authorization
check against a discardable model must remember `.kept`, and forgetting is silent.
PaperTrail — already installed — can reify a destroyed record, which covers the
common "an admin deleted the wrong thing" case without that tax.

**Decision:**
`destroy` is the default. Discard is installed and added to a model only when
restoration is a user-facing feature, an audit obligation requires the row to
survive, or foreign keys point at it from records that must stay valid. Never
`default_scope -> { kept }` — an escapable scope is the whole reason Discard omits
one.

**Consequences:**
- (+) Most queries carry no soft-delete tax
- (+) The models that do use it did so for a stated reason
- (+) PaperTrail reify covers accidental deletion without a schema change
- (-) Restoring a hard-deleted record is console surgery and won't restore associations
- (-) Requires judgement per table rather than a blanket rule

---

## ADR-005: Slim Templates

**Status:** Accepted

**Context:**
Needed to choose a templating language.

**Decision:**
Use Slim instead of ERB for all views.

**Consequences:**
- (+) Cleaner, more readable templates
- (+) Enforces proper indentation
- (+) Less visual noise than ERB
- (-) Learning curve for ERB developers
- (-) Some Tailwind syntax requires workarounds (see docs/rules/slim-gotchas.md)

---

## ADR-006: ViewComponent for UI Units

**Status:** Accepted

**Context:**
Partials carry no interface, can't be unit tested in isolation, and silently read
whatever instance variables the rendering context happens to hold. Markup with
variants and conditionals ends up as a stack of `- if` lines nobody can test.

**Decision:**
Use ViewComponent for UI units that carry logic or variants or are reused. Components
live in `app/components`, inherit `ApplicationComponent`, and ship with a unit test.
Sidecar directories are on, so a component's class, Slim template, and any
component-scoped Stimulus controller sit together. Partials remain the right tool for
logic-free markup reused within one resource, and must declare strict locals.

**Consequences:**
- (+) View code is unit tested without a request, routing, or fixtures
- (+) Explicit constructor interface — no ambient instance variables
- (+) Variants live in one frozen hash instead of scattered conditionals
- (-) One more dependency, and a second place view code can live
- (-) Over-application produces a component per div; the partial/component line is in docs/rules/view-code-placement.md

---

## ADR-007: Pattern Budget

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

---

## ADR-008: Registries as `Data` Objects

**Status:** Accepted (supersedes the `RegistryBase` approach)

**Context:**
Fixed variant sets — plans, tiers, roles, product types — need one source of truth.
The template previously shipped a `RegistryBase` module with a
`get(type, attribute, level)` accessor: 113 lines of bespoke API that every reader
had to learn, where a mistyped attribute returned `nil` rather than raising.

**Decision:**
Registries are plain modules holding a frozen hash of `Data` objects, with `fetch`
for lookup and `find` where a miss is legitimate. `app/lib/plan_registry.rb` is the
canonical shape. No base class. Callers query capabilities (`has_feature?`), never
identities (`plan == "pro"`).

**Consequences:**
- (+) A mistyped attribute raises `NoMethodError` at the call site; an unknown key raises `KeyError`
- (+) `Data.define` requires every member, so a new attribute can't be half-migrated across variants
- (+) Behaviour lives with the data, and entries render directly in views and components
- (+) Idiomatic Ruby 3.2+ — nothing template-specific to learn
- (-) No enforced uniformity from a shared base class; the canonical file is the only guide
- (-) `Data` is immutable and requires all members, which is awkward if variants genuinely differ in shape (usually a smell)

---

## Template: New ADR

```markdown
## ADR-XXX: [Title]

**Status:** Proposed | Accepted | Deprecated | Superseded

**Context:**
What is the issue we're addressing?

**Decision:**
What is the change we're proposing?

**Consequences:**
- (+) Positive consequence
- (-) Negative consequence
```
