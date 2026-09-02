---
id: service-objects
title: Service objects — ApplicationService and Result
applies_to: ["app/services/**/*.rb", "test/services/**/*.rb"]
triggers: ["service object", "ApplicationService", "business logic", "Result", "success?", "failure?", "transaction", "multi-step write", "coordination"]
see_also: ["controllers", "form-objects", "jobs", "policy-objects"]
modes: [ web, api ]
tokens: 880
current_state: matches
---

# Service objects

Coordination with a failure path. Full reference: the class comment in
`app/services/application_service.rb`.

```ruby
class CreateOrderService < ApplicationService
  def initialize(user:, items:)
    @user  = user
    @items = items
  end

  def call
    return failure("Items can't be empty") if @items.empty?

    order = Order.new(user: @user, items: @items)

    if order.save
      log_info("Order created", order_id: order.id)
      success(order)
    else
      failure(order.errors.full_messages)
    end
  end
end
```

`self.call(...)` forwards to `new(...).call`. `Result` carries `success?`,
`failure?`, `value` (aliased `record`), and `errors` — always an array.
`log_info` / `log_error` tag output with the service class name.

## When

| Use a service when | Don't when |
|---|---|
| The operation touches >1 model | It's single-model validation → model concern |
| It has a failure mode the caller must handle | It's one query → scope |
| It's called from >1 place (controller + job) | It's formatting → helper or component |
| The action would push a controller past ~10 lines | It wraps a single `create!` → just call `create!` |

The failure mode of this pattern is a service for everything: forty single-method
classes each wrapping one line.

## Failures vs exceptions

Return `failure()` for expected outcomes — validation, business rules, a declined
card. `raise` for broken invariants, and define the error class on the service.

Rule of thumb: if the controller should render the form again, it's a `failure`.

## Transactions live here

Not in the controller, not in a callback.

```ruby
def call
  ApplicationRecord.transaction do
    order.update!(status: :paid)
    Ledger.record!(order)
    order
  end
  success(order)
rescue ActiveRecord::RecordInvalid => e
  failure(e.record.errors.full_messages)
end
```

A service never knows a [form object](form-objects.md) exists; a form may call a service.

## In API mode

Unchanged, with one addition that matters: a write can come back needing
confirmation. `needs_confirmation(**details)` returns a `Result` that is neither a
success nor a failure, and `confirm` carries what the client has to see.

```ruby
return needs_confirmation(changes: price_changes) if price_changes.any?
```

`success?`, `failure?` and `needs_confirmation?` are mutually exclusive, so a caller
written for two states treats the third as a failure — safe, and wrong enough to
notice. The controller maps it to `409` with its own problem type; the service never
knows a status exists — [status-codes](status-codes.md).

A service is also where a network call belongs, and it belongs *outside* the
transaction. Take the locks, write, commit, then call the provider. Holding a database
transaction open across a payment API call is how a slow gateway becomes a table-wide
stall.

Rationale and consequences: [ADR 0003](../adr/0003-service-object-pattern.md).
