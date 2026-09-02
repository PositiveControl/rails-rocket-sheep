---
id: policy-objects
title: Policy objects — record-level authorization
applies_to: ["app/policies/**/*.rb", "app/controllers/**/*.rb", "app/views/**/*.slim", "test/policies/**/*.rb"]
triggers: ["authorization", "policy", "can this user", "Petergate", "access", "forbidden!", "permission check", "admin?", "owner?"]
see_also: ["exception-boundary", "controllers"]
tokens: 520
current_state: matches
---

# Policy objects

Petergate handles **role**-level access — "can admins reach this controller?" —
and that's where role rules stay:

```ruby
class OrdersController < ApplicationController
  access all: [:show, :index], user: { except: [:destroy] }, admin: :all
end
```

Petergate also gives you `forbidden!` for a hand-rolled guard in a `before_action`.

Petergate does not answer **record**-level questions — "can *this* user edit
*this* order?" Those go in a policy object, so the same rule is reachable from a
controller, a view, and a job.

```ruby
# app/policies/order_policy.rb
class OrderPolicy
  def initialize(user, order)
    @user  = user
    @order = order
  end

  def edit?    = owner? && @order.draft?
  def cancel?  = owner? && !@order.shipped?
  def refund?  = @user.admin? && @order.paid?

  private

  def owner? = @order.user_id == @user.id
end
```

```ruby
# controller — the boundary turns this into a redirect with a flash
raise Forbidden unless OrderPolicy.new(current_user, @order).cancel?
```

```slim
/ view — same rule, one source
- if OrderPolicy.new(current_user, @order).cancel?
  = button_to "Cancel", order_cancellation_path(@order), method: :post
```

**The anti-pattern it replaces:** `if current_user.admin? || order.user == current_user`
copy-pasted into a controller and two views, where one copy is eventually wrong
and it's the one in the view that hides the button but not the route.

**Every policy question gets a test.** They're pure functions of two objects —
the cheapest tests in the suite and the ones that matter most.
