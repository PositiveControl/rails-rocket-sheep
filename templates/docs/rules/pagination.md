---
id: pagination
title: Every index paginates (Pagy)
applies_to: ["app/controllers/**/*.rb", "app/views/**/index.html.slim"]
triggers: ["index action", "pagy", "pagination", "series_nav", "unbounded query", "all records", "list page"]
see_also: ["controllers", "query-objects", "n-plus-one"]
modes: [ web ]
tokens: 360
current_state: matches
---

# Every index paginates

Pagy is installed and wired in. An index action with no limit is a production
incident with a delay fuse — it works for months, then a customer has 40,000 rows.

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pagy::Method
end

# app/controllers/orders_controller.rb
def index
  @pagy, @orders = pagy(current_user.orders.kept.includes(:items).recent, limit: 25)
end
```

```slim
/ app/views/orders/index.html.slim
= render OrdersTableComponent.new(orders: @orders)
== @pagy.series_nav
== @pagy.info_tag
```

The nav and info helpers are methods on the `Pagy` object, not view helpers — there
is nothing to include in `ApplicationHelper`. They return a plain `String`, so render
them with `==` (unescaped) in Slim.

**The rule:** if a collection can grow with usage, it paginates. No exceptions for
admin screens — admin screens are where the 40,000 rows live.

Pass a relation, never an array — see [query-objects](query-objects.md).
