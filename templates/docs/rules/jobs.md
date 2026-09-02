---
id: jobs
title: Jobs are thin wrappers over services, idempotent, ID-only
applies_to: ["app/jobs/**/*.rb", "config/queue.yml", "test/jobs/**/*.rb"]
triggers: ["job", "ApplicationJob", "perform_later", "Solid Queue", "retry", "DeserializationError", "GlobalID", "queue_as", "background work", "idempotent"]
see_also: ["service-objects", "callbacks"]
modes: [ web, api ]
tokens: 600
current_state: matches
---

# Jobs

```ruby
# BAD — logic lives in the job, unreachable from the console or a controller
class ChargeOrderJob < ApplicationJob
  def perform(order)
    # 40 lines of payment logic
  end
end

# GOOD
class ChargeOrderJob < ApplicationJob
  queue_as :default
  retry_on Stripe::RateLimitError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError

  def perform(order_id)
    order = Order.find_by(id: order_id)
    return unless order            # deleted between enqueue and run
    return if order.paid?          # idempotent: already done

    result = ChargeOrderService.call(order:)
    raise result.errors.join(", ") unless result.success?
  end
end
```

**Pass IDs, not records.** GlobalID serialization of a deleted record raises
`DeserializationError` on every retry. An ID lets the job decide what a missing
row means.

**Assume it runs twice.** Solid Queue retries, and a retry after a partial success
is the normal case, not the edge case. Every `perform` starts with a guard that
makes a second run a no-op.

**Enqueue after commit,** never mid-transaction:

```ruby
# BAD — worker may pick this up before the row is committed
order.save!
ChargeOrderJob.perform_later(order.id)   # inside a surrounding transaction

# GOOD
ApplicationRecord.transaction do
  order.save!
end
ChargeOrderJob.perform_later(order.id)
```

**Queue names are a capacity decision.** `:default` for user-facing work, `:low`
for backfills and reports. Configure the split in `config/queue.yml` before you
need it, not during the incident.

**The cost is measured.** In an audited app with no rule here, 12 of the 37 jobs
taking a positional argument took a record rather than an id — `batch` four times,
`bulk_upload` and `form` twice each. Every one of them retries into
`DeserializationError` if the row goes away, and the queue is exactly where rows go
away.
