# Registries as `Data` Objects

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
