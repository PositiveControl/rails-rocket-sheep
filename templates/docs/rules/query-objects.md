---
id: query-objects
title: Query objects — joins across models, always a relation
applies_to: ["app/queries/**/*.rb", "app/models/**/*.rb", "test/queries/**/*.rb"]
triggers: ["query object", "joins", "left_joins", "complex query", "to_a", "select in Ruby", "scope too long", "app/queries"]
see_also: ["scopes", "pagination", "n-plus-one"]
tokens: 450
current_state: matches
---

# Query objects

Scopes are the default. A query object starts where scopes stop being readable.

```ruby
# app/queries/stale_orders_query.rb
class StaleOrdersQuery
  def initialize(relation = Order.kept)
    @relation = relation
  end

  def call(older_than: 30.days.ago, minimum_cents: 0)
    @relation
      .joins(:customer)
      .left_joins(:shipments)
      .where(shipments: { id: nil })
      .where(orders: { created_at: ...older_than })
      .where(orders: { total_cents: minimum_cents.. })
      .group("orders.id")
      .order("orders.created_at ASC")
  end
end

# Usage — still a relation, so it chains and paginates
@pagy, @orders = pagy(StaleOrdersQuery.new.call(older_than: 60.days.ago))
```

| Where it goes | Rule |
|---|---|
| Scope | Single model, one or two clauses |
| Scope composition | Single model, several named scopes chained at the call site |
| Query object | Joins ≥2 models, or >3 clauses, or takes arguments that change its shape |

**Always return a relation, never an array.** `.to_a` kills chaining, kills
[pagination](pagination.md), and forces the whole result set into memory.

**Never `to_a` early to filter in Ruby:**

```ruby
# BAD — loads every active user to find the admins
User.where(active: true).to_a.select(&:admin?)

# GOOD
User.where(active: true).where(role: :admin)
```
