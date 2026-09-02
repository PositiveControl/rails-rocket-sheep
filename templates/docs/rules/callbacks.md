---
id: callbacks
title: Callbacks touch only their own record
applies_to: ["app/models/**/*.rb"]
triggers: ["callback", "after_create", "after_save", "after_commit", "before_save", "before_validation", "why did this row change", "side effect", "enqueue from model"]
see_also: ["service-objects", "jobs"]
modes: [ web, api ]
tokens: 360
current_state: matches
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
