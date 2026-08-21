---
id: current-attributes
title: CurrentAttributes is a trap — two acceptable uses
applies_to: ["app/models/current.rb", "app/models/**/*.rb", "app/controllers/**/*.rb", "app/jobs/**/*.rb"]
triggers: ["Current.user", "CurrentAttributes", "ActiveSupport::CurrentAttributes", "ambient state", "thread local", "global user", "tests pass in isolation"]
see_also: ["audit-trail", "service-objects"]
tokens: 230
---

# `CurrentAttributes` — a trap, documented

`Current.user` reads beautifully and turns every model into something that behaves
differently depending on invisible request state. Tests pass in isolation and fail
in sequence; jobs get a `nil` where the web process had a user.

Acceptable for exactly two things:

1. Request ID for logging
2. PaperTrail's whodunnit — see [audit-trail](audit-trail.md)

Pass the user as an argument everywhere else.
