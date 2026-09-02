---
id: controllers
title: Controller shape — seven actions, thin actions
applies_to: ["app/controllers/**/*.rb", "config/routes.rb"]
triggers: ["custom action", "member route", "collection route", "fat controller", "new verb", "RESTful", "archive", "duplicate"]
see_also: ["turbo-status", "exception-boundary", "pagination", "service-objects"]
modes: [ web, api ]
tokens: 630
current_state: matches
---

# Controller shape

**Seven actions per controller** — `index show new create edit update destroy`.
A new verb is a new resource with its own controller. Actions stay under ~10 lines.

## A new verb is a new resource

```ruby
# BAD — verbs pile up on one controller
resources :orders do
  member do
    patch :archive
    patch :unarchive
    post  :duplicate
    post  :send_receipt
  end
end

# GOOD — each verb is a resource with a standard action
resources :orders do
  resource  :archive,    only: [:create, :destroy]   # Orders::ArchivesController
  resources :duplicates, only: [:create]             # Orders::DuplicatesController
  resources :receipts,   only: [:create]             # Orders::ReceiptsController
end
```

```ruby
# app/controllers/orders/archives_controller.rb
module Orders
  class ArchivesController < ApplicationController
    def create
      order  = current_user.orders.find(params[:order_id])
      result = ArchiveOrderService.call(order:)

      if result.success?
        redirect_to order, notice: "Order archived"
      else
        redirect_to order, alert: result.errors.join(", ")
      end
    end
  end
end
```

Nested controllers go under a module named after the parent resource.

## Actions do four things

```ruby
def create
  result = CreateOrderService.call(user: current_user, items: order_params[:items])

  if result.success?
    redirect_to result.value, notice: "Order placed"
  else
    @order = result.value
    render :new, status: :unprocessable_content
  end
end
```

Find, delegate, branch, respond. Business logic in a controller is logic a job, a
console session, and a test can't reach — see [service-objects](service-objects.md).

## Why it pays

Every controller has the same shape, so routes are guessable, authorization hooks
land in predictable places, and the class stays readable in one screen.

## When not to

Genuinely stateless endpoints with no resource behind them — a webhook receiver, a
health check. Those get their own controller anyway.
