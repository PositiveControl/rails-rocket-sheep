---
id: n-plus-one
title: N+1 queries — includes, counter_cache, aggregate in the database
applies_to: ["app/models/**/*.rb", "app/controllers/**/*.rb", "app/views/**/*.slim", "app/queries/**/*.rb"]
triggers: ["N+1", "n plus one", "Bullet", "includes", "preload", "eager load", "counter_cache", "count", "size", "sort_by", "slow page", "query per row"]
see_also: ["query-objects", "scopes", "caching"]
tokens: 360
current_state: matches
---

# N+1 queries

Bullet is installed in development and will tell you. Don't wait for it.

```ruby
# BAD — one query per row
@orders = Order.recent
@orders.each { |o| o.customer.name }

# GOOD
@orders = Order.recent.includes(:customer)
```

```ruby
# BAD — a COUNT per row
users.each { |u| u.orders.count }

# GOOD — counter cache column, no query at all
class Order < ApplicationRecord
  belongs_to :user, counter_cache: true
end
users.each { |u| u.orders_count }
```

`includes` when you read the association. `counter_cache` when you only need the
number. `size` over `count` on a loaded association — `count` always hits the
database, `size` uses what's already there.

**Sort and aggregate in the database, not in Ruby:**

```ruby
# BAD
users.to_a.sort_by { |u| u.orders.count }

# GOOD
User.left_joins(:orders).group(:id).order("COUNT(orders.id) DESC")
```

Caching a slow query is not the fix — see [caching](caching.md).
