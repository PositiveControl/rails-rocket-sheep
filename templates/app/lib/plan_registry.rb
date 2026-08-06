# frozen_string_literal: true

# The canonical registry shape. Copy this file when you need another one.
#
# A registry is the single source of truth for a fixed set of variants that each
# carry attributes: plans, tiers, roles, product types, difficulty levels. Values
# that are code — referenced in conditionals, changed with deploys, greppable.
#
# Three rules make it work:
#
#   1. The entries are `Data` objects, not hashes. A typo raises NoMethodError
#      instead of returning nil three layers away in a view, and behaviour
#      (`free?`, `has_feature?`) lives with the data instead of in the caller.
#   2. Lookup is `fetch`. An unknown key raises KeyError rather than producing a
#      nil that fails somewhere else. Use `.find` when a miss is legitimate.
#   3. Callers query capabilities, never identities.
#
#        PlanRegistry[:pro].has_feature?(:api_access)   # survives a new plan
#        plan == "pro" || plan == "enterprise"          # silently excludes it
#
# `Data.define` requires every member at construction, so a new attribute can't
# be added to one variant and forgotten on the others.
#
# Move a registry into a database table when non-developers must edit it, or
# when values must change without a deploy. Not before: a table turns every
# feature check into a query and every typo into a runtime nil.
#
# See docs/system/design-patterns.md for when to reach for this.
module PlanRegistry
  # Nested under the module on purpose — Zeitwerk expects plan_registry.rb to
  # define PlanRegistry and anything inside it. A top-level `Plan` here would
  # blow up on eager load in production.
  Plan = Data.define(:key, :name, :price_cents, :interval, :features, :limits) do
    def free? = price_cents.zero?

    def has_feature?(feature) = features.include?(feature.to_sym)

    # @return [Object, nil] nil when the limit isn't defined for this plan
    def limit(name) = limits[name.to_sym]

    def unlimited?(name) = limit(name) == :unlimited
  end

  ITEMS = {
    free: Plan.new(
      key: :free,
      name: "Free",
      price_cents: 0,
      interval: :month,
      features: %i[basic_access],
      limits: { projects: 3, storage_mb: 100 }
    ),
    starter: Plan.new(
      key: :starter,
      name: "Starter",
      price_cents: 900,
      interval: :month,
      features: %i[basic_access api_access],
      limits: { projects: 10, storage_mb: 1_000 }
    ),
    pro: Plan.new(
      key: :pro,
      name: "Pro",
      price_cents: 2_900,
      interval: :month,
      features: %i[basic_access api_access priority_support webhooks],
      limits: { projects: 100, storage_mb: 10_000 }
    )
  }.freeze

  class << self
    # @raise [KeyError] on an unknown key
    def [](key) = ITEMS.fetch(key.to_sym)

    # @return [Plan, nil] for when a miss is legitimate
    def find(key) = ITEMS[key.to_sym]

    def all = ITEMS.values
    def keys = ITEMS.keys
    def exists?(key) = ITEMS.key?(key.to_sym)

    def paid = all.reject(&:free?)
    def with_feature(feature) = all.select { |plan| plan.has_feature?(feature) }
  end
end
