---
id: partials
title: Partials — strict locals, no instance variables
applies_to: ["app/views/**/_*.slim", "app/views/**/*.slim"]
triggers: ["partial", "strict locals", "locals:", "render partial", "collection rendering", "instance variable in partial", "renders blank", "undeclared local", "as: :order"]
see_also: ["components", "view-code-placement", "slim-gotchas"]
tokens: 450
---

# Partials

Still the right tool for markup reused within one resource. Two rules make them safe.

## Strict locals, always

Without them, a partial silently reads instance variables from whatever rendered
it, and a typo'd local is `nil` instead of an error.

In Slim, the magic comment must be the first line and must be written exactly this
way — Rails matches it with a regex, so spacing matters:

```slim
/# locals: (order:, compact: false)
.rounded.border.p-4
  = order.reference
  - unless compact
    p.text-sm.text-gray-600 = order.placed_at.to_fs(:long)
```

```slim
= render "orders/order", order: @order, compact: true
```

An undeclared local now raises at render time instead of rendering blank.

**Note:** strict locals apply to partials only — files whose names start with `_`.

## No instance variables in partials

```slim
/ BAD — partial is now welded to one controller
h2 = @order.reference

/ GOOD — everything arrives as a declared local
/# locals: (order:)
h2 = order.reference
```

## Collection rendering

```slim
= render partial: "orders/order", collection: @orders, as: :order
```

One template compile for the whole collection, and each iteration gets
`order_counter` and `order_iteration` for free.

Once a partial grows logic or variants, it is a [component](components.md).
