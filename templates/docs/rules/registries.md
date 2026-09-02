---
id: registries
title: Registries — fixed variant sets as Data objects
applies_to: ["app/lib/**/*.rb"]
triggers: ["registry", "plans", "tiers", "product types", "Data.define", "fixed set", "frozen hash", "PlanRegistry", "has_feature?", "fetch", "constants", "app_config"]
see_also: ["pattern-budget", "optional-patterns"]
modes: [ web, api ]
tokens: 780
current_state: matches
---

# Registries

For fixed variant sets carrying attributes — plans, tiers, roles, product types.
Values that are code, change with deploys, and need to be greppable.

`app/lib/plan_registry.rb` ships as the canonical shape. Copy it.

```ruby
module PlanRegistry
  # Nested under the module — Zeitwerk expects plan_registry.rb to define
  # PlanRegistry and anything inside it. A top-level `Plan` breaks eager load.
  Plan = Data.define(:key, :name, :price_cents, :features, :limits) do
    def free?                 = price_cents.zero?
    def has_feature?(feature) = features.include?(feature.to_sym)
    def limit(name)           = limits[name.to_sym]
  end

  ITEMS = {
    free: Plan.new(key: :free, name: "Free", price_cents: 0,
                   features: %i[basic_access], limits: { projects: 3 }),
    pro:  Plan.new(key: :pro, name: "Pro", price_cents: 2_900,
                   features: %i[basic_access api_access], limits: { projects: 100 })
  }.freeze

  class << self
    def [](key)   = ITEMS.fetch(key.to_sym)   # unknown key raises KeyError
    def find(key) = ITEMS[key.to_sym]         # when a miss is legitimate
    def all       = ITEMS.values
    def paid      = all.reject(&:free?)
  end
end
```

```ruby
PlanRegistry[:pro].price_cents                  # => 2900
PlanRegistry[user.plan].has_feature?(:api_access)
PlanRegistry.paid.map(&:name)                   # => ["Pro"]
```

## Three rules

1. **Entries are `Data` objects, not hashes.** A typo raises `NoMethodError` at
   the call site instead of returning `nil` three layers away in a view, and
   behaviour lives with the data instead of being reimplemented by each caller.
   `Data.define` requires every member at construction, so an attribute added to
   one variant can't be forgotten on the others.
2. **Lookup is `fetch`.** An unknown key raises. `find` exists for the cases where
   a miss is legitimate — say a key arriving from params.
3. **Query capabilities, not identities.** `has_feature?(:api_access)` keeps
   working when a plan is added; `plan == "pro" || plan == "enterprise"` silently
   excludes it. This is the half that actually matters.

## Boundaries

**Move it to a table when** non-developers must edit it, or values must change
without a deploy. Not before — a table turns every feature check into a query and
every typo into a runtime `nil`.

**Not a registry:** constants with no variants. Branding strings, upload limits,
timeouts. Those are frozen constants — see `app/lib/app_config.rb`.

There is no base class, deliberately. See
[ADR 0008](../adr/0008-registries-as-data-objects.md).
