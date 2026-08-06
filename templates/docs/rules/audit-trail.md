---
id: audit-trail
title: Audit trail — PaperTrail, scoped to models where history has value
applies_to: ["app/models/**/*.rb", "app/controllers/application_controller.rb"]
triggers: ["PaperTrail", "has_paper_trail", "audit", "versions", "changeset", "whodunnit", "history", "who changed"]
see_also: ["deletes", "current-attributes"]
tokens: 220
---

# Audit trail

Installed with `--with-changes`, so diffs are queryable rather than serialized blobs.

```ruby
class Order < ApplicationRecord
  has_paper_trail only: [:status, :total_cents]
end

order.versions                  # every change
order.versions.last.changeset   # what changed, as a hash
order.paper_trail.previous_version
```

To record who made the change:

```ruby
# app/controllers/application_controller.rb
before_action :set_paper_trail_whodunnit
```

**The cost:** a `versions` row per create, update, and destroy. Track models where
history has value — orders, permissions, financial records — and scope with `only:`
on noisy ones. Not every model you own.

PaperTrail also covers accidental deletion via `reify` — see [deletes](deletes.md).
