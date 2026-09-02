---
id: caching
title: Caching — Solid Cache, Russian-doll fragments, always key by user
applies_to: ["app/views/**/*.slim", "app/models/**/*.rb", "app/services/**/*.rb"]
triggers: ["cache", "Rails.cache", "Solid Cache", "fragment cache", "expires_in", "cache key", "stale", "touch: true", "russian doll"]
see_also: ["n-plus-one", "rate-limiting"]
modes: [ web, api ]
tokens: 480
current_state: matches
---

# Caching

Solid Cache is configured and database-backed. That makes reads cheap and makes
cache writes real writes — cache deliberately, not everywhere.

## Russian-doll fragment caching

```slim
/ app/views/orders/index.html.slim
- cache [current_user, @orders.maximum(:updated_at), @orders.size] do
  - @orders.each do |order|
    - cache order do
      = render OrderRowComponent.new(order:)
```

Touch the parent so an inner change busts the outer key:

```ruby
class OrderItem < ApplicationRecord
  belongs_to :order, touch: true
end
```

`cache order` keys on class, id, and `updated_at` — no manual expiry, no stale
fragments, no `Rails.cache.delete` calls to keep in sync.

## What to cache

| Cache | Don't cache |
|---|---|
| Rendered fragments of expensive collections | Anything containing another user's data |
| Aggregates that tolerate seconds of staleness | Authorization results |
| External API responses (`fetch` with `expires_in`) | Anything already fast |

```ruby
Rails.cache.fetch(["exchange_rate", currency], expires_in: 1.hour) do
  ExchangeRateApi.fetch(currency)
end
```

**Always include the user in the key** for anything user-scoped. A cache key
missing a tenant discriminator is a data leak, and it will not show up in tests.

**Measure before caching.** A cached slow query is still a slow query on every
cold key, plus a new class of staleness bug. Fix the query first —
see [n-plus-one](n-plus-one.md).
