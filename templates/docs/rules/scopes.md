---
id: scopes
title: Scopes, never class methods returning relations
applies_to: ["app/models/**/*.rb"]
triggers: ["scope", "class method", "def self.", "where", "returns nil", "chain broken", "relation"]
see_also: ["query-objects", "n-plus-one"]
modes: [ web, api ]
tokens: 280
current_state: matches
---

# Scopes, not class methods

```ruby
# BAD
def self.recent = where("created_at > ?", 1.week.ago)

# GOOD
scope :recent,    -> { where(created_at: 1.week.ago..) }
scope :unshipped, -> { where(shipped_at: nil) }
scope :for_user,  ->(user) { where(user:) }
```

Scopes always return a relation, even when they match nothing — a class method can
accidentally return `nil` and break the chain three calls later.

Once a query joins ≥2 models or needs more than three clauses, it stops being a
scope: see [query-objects](query-objects.md).

**The cost is measured.** An audited app has 65 `def self.` in its models, seven of
which return a relation and could have been scopes. None of the seven is broken
today; each is a place where a future `nil` breaks a chain somewhere else.
