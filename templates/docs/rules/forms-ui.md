---
id: forms-ui
title: Form markup — form_with, ErrorSummaryComponent, field errors
applies_to: ["app/views/**/*.slim", "app/components/**/*.slim"]
triggers: ["form_with", "form markup", "error display", "ErrorSummaryComponent", "field error", "full_messages_for", "label", "submit button"]
see_also: ["form-objects", "turbo-status", "components", "accessibility"]
tokens: 370
current_state: matches
---

# Form markup

`form_with` against a model or a [form object](form-objects.md). Error display is a
component so it looks the same everywhere.

```slim
= form_with model: @order do |f|
  = render ErrorSummaryComponent.new(record: @order)

  .mb-4
    = f.label :email, class: "block text-sm font-medium text-gray-700 mb-1"
    = f.email_field :email, class: "w-full border rounded px-3 py-2"
    - if @order.errors[:email].any?
      p.text-red-500.text-sm.mt-1 = @order.errors.full_messages_for(:email).first

  = f.submit "Save", class: "bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded"
```

A form object has no routes, so pass an explicit `url:`:

```slim
= form_with model: @form, url: signup_path do |f|
```

**The controller must render failures with a 422** or Turbo discards the response
and the form appears frozen — [turbo-status](turbo-status.md).

Every input needs a `label` with a matching `for`, not just a placeholder —
[accessibility](accessibility.md).
