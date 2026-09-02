---
id: sparse-fieldsets-includes
title: Sparse fieldsets and includes — bounded, allowlisted, one level deep
applies_to: ["app/serializers/**/*.rb", "app/controllers/api/**/*.rb"]
triggers: ["fields param", "include param", "sparse fieldset", "embed", "sideload", "nested resource", "over-fetching", "graph"]
see_also: ["serialization", "n-plus-one", "cursor-pagination", "openapi-contract"]
modes: [ api ]
tokens: 700
current_state: matches
---

# Sparse fieldsets and includes

A client that needs less than the whole resource asks for less; a client that needs a
related resource asks for it. Both are allowlisted by the serializer, and both are
bounded.

```ruby
class ItemSerializer < ApplicationSerializer
  optional :description, :provenance          # omitted unless requested
  includable :category, preload: :category
  includable :grade,    preload: { item_grade: :factors }
end
```

```
GET /v1/items?fields=id,title,price&include=category
```

**A second serializer is the wrong answer to "this endpoint needs fewer fields".** Two
serializers for one resource drift, and the second one is always the stale one
([serialization](serialization.md)). `optional` and `includable` keep one definition
of what a resource is.

**`include` is one level deep.** No `include=category.parent.parent`. A client that
needs a graph makes a second request; the alternative is an endpoint whose cost no one
can predict from its URL, and a query planner nobody profiles.

**Every includable declares its preloads, and the controller applies them.** An
include that triggers a query per row is the [n-plus-one](n-plus-one.md) this rule
would otherwise cause on purpose, and it lands in a response builder where nobody
looks.

**Unknown values in `fields` or `include` are ignored, not rejected**, for the same
reason a contract ignores unknown keys — a newer client asking for a field this build
does not have should get the resource, not a `422`
([request-contracts](request-contracts.md)).

**Nothing required becomes optional.** `id` and the fields that identify a resource
are always present, whatever `fields` says, because a response a client cannot
correlate is not a smaller response, it is a broken one.

**Includes and pagination compound.** An `include` on a hundred-row page is a hundred
rows of related objects too. Cap the page harder when includes are present, or cap the
includes — either, stated in the contract
([cursor-pagination](cursor-pagination.md)).

**The allowlists generate the contract.** `optional` and `includable` lines are the
source for the documented parameters, which is why they are declarations
([openapi-contract](openapi-contract.md)).
