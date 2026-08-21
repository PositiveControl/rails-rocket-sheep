---
id: empty-states
title: Every collection view has three states
applies_to: ["app/views/**/index.html.slim", "app/views/**/*.slim"]
triggers: ["empty state", "EmptyStateComponent", "no records", "blank page", "empty list", "nothing to show"]
see_also: ["pagination", "components"]
tokens: 250
---

# Empty states

Every collection view has three states — loading, empty, populated — and the
second one is the one people forget. A list that renders nothing when empty reads
as a broken page.

```slim
- if @orders.any?
  = render partial: "orders/order", collection: @orders, as: :order
  == @pagy.series_nav
- else
  = render EmptyStateComponent.new(
      title: "No orders yet",
      description: "Orders appear here once a customer checks out.",
      action: link_to("New order", new_order_path, class: "..."))
```

`EmptyStateComponent` ships with the app and takes an action slot. The populated
branch always paginates — [pagination](pagination.md).
