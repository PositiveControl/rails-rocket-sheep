---
id: cursor-pagination
title: Pagination — cursor by default, offset by exception, never unbounded
applies_to: ["app/controllers/api/**/*.rb", "app/filters/**/*.rb"]
triggers: ["pagination", "cursor", "page", "per_page", "offset", "next page", "has_more", "unbounded", "index action", "all records"]
see_also: ["filtering-sorting", "serialization", "n-plus-one", "database-conventions"]
modes: [ api ]
tokens: 860
current_state: matches
---

# Pagination

Every endpoint that returns a collection paginates. No exceptions for admin, support,
or internal clients — those are where the forty thousand rows live.

Cursor is the default:

```ruby
PER_PAGE_MAX = 100

def index
  scope  = ItemFilter.new(current_user.items, params).apply
  page   = Cursor.page(scope, after: params[:cursor], limit: per_page)

  render json: ItemSerializer.collection(page.records).merge(
    next_cursor: page.next_cursor      # nil on the last page
  )
end

def per_page = params[:per_page].to_i.clamp(1, PER_PAGE_MAX)
```

**The scope comes in already narrowed to the caller.** `current_user.items`, not
`Item.all` with a filter — ownership is structural, and a filter object must never be
the thing that keeps one tenant's rows out of another's page
([policy-objects](policy-objects.md)).

**The cursor encodes the sort key and a unique tiebreak, and nothing else.** On
PostgreSQL the primary key is a `uuid`, which has no order, so the key is
`(created_at, id)` — `created_at` for the sort a client asked for and `id` to break
ties deterministically. `ApplicationRecord` already sets
`implicit_order_column = :created_at` for the same reason, and that setting covers
`first`/`last`, not this. See [database-conventions](database-conventions.md).

**A cursor is opaque.** Base64 the key, and say in the contract that its contents are
not a promise. A client that parses a cursor is a client you cannot change the sort
of.

**Without a unique tiebreak the page is silently wrong.** Two rows sharing a
`created_at` at a page boundary will be returned twice, or skipped — no error, no
failing test, a duplicate in someone's list.

**`per_page` is clamped, always.** It arrives from the internet. An unclamped
`per_page` is an unbounded query with extra steps.

**Offset is allowed, and it is named.** A screen with numbered pages needs a total
and a jump; cursor cannot give it one. Those endpoints take `page`/`per_page`,
return `total_count`, and say in the contract that deep pages are expensive and
results may shift under writes. That is a per-endpoint decision, written down, not
a default.

**Never paginate an array.** If the value being paginated is not a relation, the
whole set is already in memory and the pager is hiding it. This is where the
unbounded read actually lives: the audited app's helper branches on
`collection.is_a?(Array)` and falls back to `slice(offset, per_page)`, and a scan for
unbounded *renders* comes back clean while the response is unbounded anyway.

**Count the same scope you page.** A `total_count` computed off a different relation
than the page is the bug this pattern reliably produces.

`includes` goes on the scope before the limit, not after — [n-plus-one](n-plus-one.md).
Where the filtering and sorting that feed this live: [filtering-sorting](filtering-sorting.md).
