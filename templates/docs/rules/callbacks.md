---
id: callbacks
title: Callbacks touch only their own record
applies_to: ["app/models/**/*.rb"]
triggers: ["callback", "after_create", "after_save", "after_commit", "before_save", "before_validation", "why did this row change", "side effect", "enqueue from model"]
see_also: ["service-objects", "jobs", "invariants"]
tokens: 400
---

# Callbacks: same record only

The single largest source of "why did this row change" bugs.

```ruby
# BAD — a save on Order silently writes two other tables and sends mail
class Order < ApplicationRecord
  after_create :charge_customer, :notify_warehouse, :update_inventory
end

# GOOD — the callback touches only its own record
class Order < ApplicationRecord
  before_validation :normalize_email
  before_save       :calculate_total_cents
end
```

| Allowed in a callback | Belongs in a service |
|---|---|
| Normalizing this record's attributes | Writing other models |
| Deriving a column from other columns on this record | Sending mail or notifications |
| Setting a default that validation needs | Calling an external API |
| | Enqueuing jobs (except trivially, via `after_commit`) |

If a job must be enqueued from a model, use `after_commit` — never `after_save`,
which fires inside the transaction and can enqueue work for a row that then rolls
back, giving the worker a record that does not exist. See [jobs](jobs.md).

Two framing traps, even when the callback is on its own record:

- **Creation means intent, not occurrence.** An `after_create` attaches a consequence
  to the moment a row appears, but the row often records that something *will* happen,
  not that it did — "this will ship" is written when the customer pays, days before the
  carton is packed. Attach a consequence about the real world to the signal that records
  it. Where no such event exists, use the nearest human-triggered signal and label it a
  proxy in a comment.
- **A guarded line beside an unguarded one is a bug or a comment.** When a method or
  loop conditions one write and not the next, one of them is wrong — and the unguarded
  half is usually the destructive one (the cleanup, the delete). State the condition
  once and apply it to every dependent write, or write the sentence saying why they
  differ.

The failure these prevent, end to end:
[`../system/invariant-drift.md`](../system/invariant-drift.md).
