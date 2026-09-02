---
id: bulk-endpoints
title: Bulk endpoints — capped, per-item results, never the first answer
applies_to: ["app/controllers/api/**/*.rb", "config/routes.rb"]
triggers: ["bulk", "batch", "multiple records", "array of items", "mass update", "import", "N requests"]
see_also: ["idempotency", "status-codes", "error-envelope", "async-202"]
modes: [ api ]
tokens: 690
current_state: matches
---

# Bulk endpoints

A bulk endpoint is a concession, not a convenience. Add one when a client
demonstrably cannot make N requests — a mobile client on a slow link, an import of
thousands of rows — and not because N requests felt inelegant.

```ruby
# POST /v1/items/bulk
MAX_BATCH = 100

def bulk
  return problem(type: "batch-too-large", title: "Batch too large",
                 status: :unprocessable_content,
                 detail: "At most #{MAX_BATCH} items per request") if entries.size > MAX_BATCH

  results = entries.map { |entry| apply_one(entry) }
  render json: { results: results }, status: :ok
end
```

**The request succeeded even when items failed.** The response is `200` with a
`results` array, one entry per input, each carrying its own status and — on failure —
its own problem object in the standard shape
([error-envelope](error-envelope.md)). A `422` for the whole request when item 40 of
100 was invalid tells the client nothing about the other 99.

**Order is preserved, and every input gets exactly one result.** A client correlates by
position, so a results array shorter than the input is unusable. Include an
identifier per entry when the input has one.

**The batch is capped, and the cap is in the contract.** An uncapped bulk endpoint is
an unbounded request — the write-side twin of an unpaginated index.

**Not a transaction, unless the whole point is atomicity.** Per-item results and
all-or-nothing are different products. If the caller needs all-or-nothing, say so on
that endpoint, wrap it, and return one status for the whole request instead of a
results array. Do not offer both on one route.

**An idempotency key covers the whole batch**, not each item —
[idempotency](idempotency.md). A retry replays the stored response, which is what makes
a partially-applied batch safe to retry at all.

**Over a few hundred, it is async.** A bulk endpoint that runs for thirty seconds is a
timeout waiting to happen; accept the work and return `202`
([async-202](async-202.md)).

**One bulk route per resource, at most.** `POST /items/bulk` doing creates, updates and
deletes by a `_action` key inside each entry is a second API with no contract. If
deletes need bulk, that is `DELETE /items/bulk` with ids.
