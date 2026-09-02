---
id: deletes
title: Deletes are real by default; Discard is opt-in per table
applies_to: ["app/models/**/*.rb", "db/migrate/**/*.rb"]
triggers: ["soft delete", "Discard", "discarded_at", "kept", "undiscard", "destroy", "default_scope", "restore a record", "reify"]
see_also: ["audit-trail", "safe-migrations"]
modes: [ web, api ]
tokens: 500
current_state: matches
---

# Deletes: real by default

`destroy` is the default. Soft deletes are a per-table decision, not a house style.

Discard is installed for when you need it:

```ruby
class Post < ApplicationRecord
  include Discard::Model
end

post.discard    # sets discarded_at
Post.kept       # not discarded
```

**Add it to a model when** restoration is a product feature the user can reach, or
an audit obligation requires the row to survive, or foreign keys point at the row
from records that must stay valid. Those are real reasons and they apply to a
handful of tables, not all of them.

**The trap:** Discard adds no default scope, deliberately — default scopes are
notoriously hard to escape. `Post.all` still returns discarded rows. Every query,
every association, and every authorization check on a discardable model is a place
to forget `.kept`, and the failure is silent. That cost is permanent and it lands
on every future query against that table. Never `default_scope -> { kept }`.

**Before reaching for it,** check whether PaperTrail already answers the question.
It's installed, and it can restore a destroyed record:

```ruby
version = PaperTrail::Version.where(item_type: "Post", item_id: id, event: "destroy").last
post = version.reify
post.save!
```

That covers "an admin deleted the wrong thing" without taxing every query. It does
*not* restore associations or keep foreign keys valid in the meantime — when those
matter, use Discard.

Rationale and consequences: [ADR 0004](../adr/0004-real-deletes-by-default-discard-opt-in.md).
