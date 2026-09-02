---
id: turbo-status
title: The Turbo status contract — render failures with 422
applies_to: ["app/controllers/**/*.rb", "test/controllers/**/*.rb", "test/integration/**/*.rb"]
triggers: ["form frozen", "form does nothing", "422", "unprocessable", "unprocessable_entity", "unprocessable_content", "render :new", "validation failure", "turbo discards", "resubmit"]
see_also: ["controllers", "form-objects"]
tokens: 440
current_state: matches
---

# The Turbo status contract

**This is the one that silently eats bug reports.** Turbo Drive discards a form
response with a 2xx status and no redirect — the page does not change, no error
appears, and the user re-submits forever.

| Outcome | Response |
|---|---|
| Success | `redirect_to`, any 3xx |
| Validation failure | `render :new, status: :unprocessable_content` |
| Not authorized | `redirect_to root_path, alert: …` or `head :forbidden` |
| Not found | `raise ActiveRecord::RecordNotFound` — let the boundary handle it |

```ruby
# BAD — Turbo ignores this. The form appears frozen.
render :new

# GOOD
render :new, status: :unprocessable_content
```

## On the status name

Rack 3.1 renamed 422 from `:unprocessable_entity` to `:unprocessable_content`,
matching the IANA registry; Rack 3.2 warns on the old name. Rails 8 accepts both
and maps between them. Use `:unprocessable_content` in new code. Expect
`:unprocessable_entity` in older gems' docs — it still works.

## Assert it

Every controller test that renders a form failure asserts the status:

```ruby
test "rejects invalid order" do
  post orders_path, params: { order: { total_cents: -1 } }
  assert_response :unprocessable_content
end
```
