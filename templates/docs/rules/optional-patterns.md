---
id: optional-patterns
title: Optional patterns — value objects, status columns, concerns
applies_to: ["app/models/**/*.rb", "app/models/concerns/**/*.rb", "app/lib/**/*.rb"]
triggers: ["value object", "Money", "enum", "state machine", "status column", "transition", "concern", "ActiveSupport::Concern", "Publishable", "Sluggable", "fat model"]
see_also: ["registries", "current-attributes"]
tokens: 630
---

# Optional patterns

Reach for these when the situation actually arises. They don't ship as base classes.

## Value objects

For a pair of columns that always travel together and carry behavior:

```ruby
class Money
  include Comparable
  attr_reader :cents, :currency

  def initialize(cents, currency = "USD")
    @cents, @currency = cents, currency
  end

  def +(other)   = Money.new(cents + other.cents, currency)
  def to_s       = format("$%.2f", cents / 100.0)
  def <=>(other) = cents <=> other.cents
end

class Order < ApplicationRecord
  def total = Money.new(total_cents, currency)
end
```

Frozen, comparable, no persistence. Stops money formatting spreading into fifteen views.

## Status columns

Rails enum for the states, a [registry](registries.md) when each state carries attributes:

```ruby
class Order < ApplicationRecord
  enum :status, { draft: 0, paid: 1, shipped: 2, cancelled: 3 }, validate: true

  def transition_to!(next_status)
    raise ArgumentError, "#{status} → #{next_status} not allowed" unless
      OrderStatusRegistry.allowed?(status, next_status)
    update!(status: next_status)
  end
end
```

Add a state machine gem only when transitions need guards, callbacks, and an audit
of who moved what. Three states with one legal path do not need one.

## Concerns — and when they're a smell

A good concern is a **role**: `Discardable`, `Publishable`, `Sluggable`. It has its
own tests and could plausibly be a gem.

```ruby
module Publishable
  extend ActiveSupport::Concern

  included do
    scope :published, -> { where.not(published_at: nil) }
  end

  def publish!   = update!(published_at: Time.current)
  def published? = published_at.present?
end
```

A bad concern is a **filing cabinet**: `UserMethods`, `OrderHelpers`, `Callbacks` —
extracted only to make a fat model file shorter. The complexity is unchanged, just
harder to find. If a concern is used by exactly one class and isn't a role, it
belongs back in the class.
