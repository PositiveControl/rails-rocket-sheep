---
id: filtering-sorting
title: Filtering and sorting — an allowlist that is data, not control flow
applies_to: ["app/filters/**/*.rb", "app/controllers/api/**/*.rb"]
triggers: ["filter", "sort", "order", "query string", "params filter", "where params", "sort column", "allowlist", "search params"]
see_also: ["cursor-pagination", "request-contracts", "query-objects", "openapi-contract", "n-plus-one"]
tokens: 730
current_state: matches
---

# Filtering and sorting

Query-string filtering and sorting live in a filter object in `app/filters/`. It takes
a relation and the params, and returns a relation.

```ruby
class ItemFilter < ApplicationFilter
  filter :status,      :string,  in: Item::STATUSES
  filter :category_id, :string
  filter :min_price,   :integer, scope: ->(r, v) { r.where(price_cents: v..) }

  sortable :created_at, :price_cents
  default_sort :created_at, :desc
end
```

```ruby
scope = ItemFilter.new(current_user.items, params).apply
```

**The allowlist is a declaration, not a branch.** That is the whole point of the
object: `filter` and `sortable` lines are readable as data, so the generated contract
can list the query parameters an endpoint accepts without anyone maintaining a second
copy ([openapi-contract](openapi-contract.md)). A filter written as `if params[:x]`
branches works and generates nothing.

**Never build a condition from a key you did not name.** `where(params[:filter])` is
arbitrary column access from the internet, and `order(params[:sort])` is arbitrary SQL
in the sort position. A param not declared here does not reach the query.

**Sorting always ends in a unique tiebreak.** `sortable` orders by the named column and
then by `id`, because a non-unique sort makes cursor pages skip and repeat rows with no
error — [cursor-pagination](cursor-pagination.md). The default sort is declared, so an
endpoint never returns rows in whatever order the database felt like.

**A filter narrows; it never widens and it never authorizes.** It receives a relation
that is already scoped to the caller and can only add conditions to it. If a filter
value can expose another user's rows, the scoping is wrong upstream, not here —
[policy-objects](policy-objects.md).

**A filter object, not a controller concern.** The audited app built exactly this as
three mixins, and the mixin form is why its filter grew to 214 lines that also compute
filter counts and build breadcrumbs: a concern can reach `params` and set `@ivars`, so
unrelated work drifts in. An object with a relation in and a relation out cannot.

**Joins belong to a [query object](query-objects.md).** A filter adds `where` and
`order` to a relation someone else shaped. When filtering needs a join, the join is the
query object's and the filter takes its relation.
