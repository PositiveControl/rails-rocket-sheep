---
id: exception-boundary
title: One exception boundary, scoped lookups
applies_to: ["app/controllers/**/*.rb"]
triggers: ["rescue_from", "RecordNotFound", "404", "403", "forbidden", "rescue", "not found", "leaks existence", "authorization redirect"]
see_also: ["controllers", "policy-objects", "turbo-status"]
modes: [ web, api ]
tokens: 400
current_state: matches
---

# One exception boundary, not fifty rescues

```ruby
class ApplicationController < ActionController::Base
  class Forbidden < StandardError; end

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from Forbidden,                    with: :access_denied

  private

  def not_found
    respond_to do |format|
      format.html { render "errors/not_found", status: :not_found }
      format.any  { head :not_found }
    end
  end

  def access_denied
    redirect_back fallback_location: root_path, alert: "You don't have access to that."
  end
end
```

## Scope every lookup and let the miss raise

```ruby
# BAD — leaks existence, and 500s in production
@order = Order.find(params[:id])
redirect_to root_path if @order.user != current_user

# GOOD — a foreign id is indistinguishable from a deleted one: 404
@order = current_user.orders.find(params[:id])
```

Never `rescue Exception`, never `rescue => e` around a whole action. A rescue that
can't say what it's recovering from is hiding the bug, not handling it.

Record-level questions ("may *this* user do *this*?") go to a
[policy object](policy-objects.md), which raises `Forbidden` for this boundary to catch.
