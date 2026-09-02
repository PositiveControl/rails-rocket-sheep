---
id: caching
title: Caching — Solid Cache, Russian-doll fragments, always key by user
applies_to: ["app/views/**/*.slim", "app/models/**/*.rb", "app/services/**/*.rb", "app/controllers/**/*.rb", "app/serializers/**/*.rb"]
triggers: ["cache", "Rails.cache", "Solid Cache", "fragment cache", "expires_in", "cache key", "stale", "touch: true", "russian doll"]
see_also: ["n-plus-one", "rate-limiting"]
modes: [ web, api ]
tokens: 1080
current_state: matches
---

# Caching

Solid Cache is configured and database-backed. That makes reads cheap and makes
cache writes real writes — cache deliberately, not everywhere.

## Russian-doll fragment caching — server-rendered mode

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

## In API mode

There are no fragments to nest, so the first caching layer is HTTP. The cheapest
response an endpoint can send is `304 Not Modified`, and it costs one line:

```ruby
def show
  @item = current_user.items.find(params[:id])

  return unless stale?(etag: [ @item, "items.v1" ], last_modified: @item.updated_at)

  render json: ItemSerializer.one(@item)
end
```

**`ActionController::API` has `ConditionalGet` but not `EtagWithTemplateDigest`.**
In a server-rendered app the template's digest is folded into the ETag, so editing
a view invalidates it. Nothing does that here: change a serializer's field list and
every client holding an ETag keeps getting `304` with the old shape, indefinitely.
Which is why the etag above carries a literal that moves when the shape does. Bump
it in the same commit that changes the serializer — [serialization](serialization.md),
[api-versioning](api-versioning.md).

**`Cache-Control: private` for anything a token authenticated.** Rails does not set
it for you, and a token-scoped body sitting in a shared proxy cache is the same leak
as a cache key missing its tenant, with a larger blast radius:

```ruby
# Api::V1::BaseController
before_action { response.headers["Cache-Control"] = "private, no-store" }
```

Relax it per endpoint, never globally. `public` belongs only on a response that is
identical for an anonymous caller, and such a response also needs
`Vary: Authorization` so a cache cannot serve it to a client whose token would have
seen something else.

**An expensive serializer caches through `Rails.cache.fetch`, keyed on the record:**

```ruby
Rails.cache.fetch([ record, "items.v1" ]) { fields }
```

`cache_key_with_version` puts `updated_at` in the key, so there is no expiry to
maintain — the same property `cache order` has in a view. The literal is there for
the same reason as in the etag.

**Never key a collection response without its page.** A cursor, the filter params,
the `include` list and the fieldset all change the body. A key missing any of them
serves page one for page two, and it looks like a pagination bug for a week —
[cursor-pagination](cursor-pagination.md), [filtering-sorting](filtering-sorting.md).
