---
id: service-objects
title: Service objects — ApplicationService and Result
applies_to: ["app/services/**/*.rb", "test/services/**/*.rb"]
triggers: ["service object", "ApplicationService", "business logic", "Result", "success?", "failure?", "transaction", "multi-step write", "coordination"]
see_also: ["controllers", "form-objects", "jobs", "policy-objects"]
tokens: 480
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
