---
id: audit-trail
title: Audit trail — PaperTrail, scoped to models where history has value
applies_to: ["app/models/**/*.rb", "app/controllers/application_controller.rb"]
triggers: ["PaperTrail", "has_paper_trail", "audit", "versions", "changeset", "whodunnit", "history", "who changed"]
see_also: ["deletes", "current-attributes"]
modes: [ web, api ]
tokens: 560
current_state: matches
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

In API mode that is the wrong controller. `ApplicationController` in an API-only app
has no session and no `current_user` — `current_user` is defined on
`Api::V1::BaseController`, from the token's resource owner — so
`set_paper_trail_whodunnit` there records `nil` on every version, silently. Put it on
the API base controller instead:

```ruby
# app/controllers/api/v1/base_controller.rb
before_action { PaperTrail.request.whodunnit = current_user&.id }
```

See [api-auth](api-auth.md) for where `current_user` comes from.

**The cost:** a `versions` row per create, update, and destroy. Track models where
history has value — orders, permissions, financial records — and scope the noisy
ones. There are two levers and they are not the same: `on:` picks which *events* are
recorded, `only:` picks which *attributes* count as a change.

```ruby
has_paper_trail on: [ :update, :destroy ]        # skip the create row entirely
has_paper_trail only: [ :status, :total_cents ]  # ignore edits to anything else
```

`on:` is the one that usually pays — in an audited app, 16 of the 18 tracked models
use it, and the creates it drops are the rows nobody ever queries.

PaperTrail also covers accidental deletion via `reify` — see [deletes](deletes.md).
