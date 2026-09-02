---
id: deprecation-policy
title: Deprecation — a header, a date, and proof nobody is still calling it
applies_to: ["app/controllers/api/**/*.rb", "config/routes.rb", "app/serializers/**/*.rb"]
triggers: ["deprecate", "sunset", "remove an endpoint", "remove a field", "breaking change", "Deprecation header", "Sunset header", "retire"]
see_also: ["api-versioning", "openapi-contract", "client-contract"]
modes: [ api ]
tokens: 630
current_state: matches
---

# Deprecation

Nothing is removed from a live version. Removal happens by deprecating, waiting, and
proving the traffic stopped.

```ruby
before_action :deprecate!, only: [ :legacy_search ]

def deprecate!
  response.headers["Deprecation"] = "true"
  response.headers["Sunset"]      = "Sat, 01 Aug 2026 00:00:00 GMT"
  response.headers["Link"]        = %(<#{api_v1_items_url}>; rel="successor-version")
end
```

**A deprecation without a date is a note nobody acts on.** `Sunset`
([RFC 8594](https://www.rfc-editor.org/rfc/rfc8594)) carries the date the endpoint
stops answering, set when the deprecation ships, not when someone gets around to it.

**Ninety days minimum, and longer for a client you do not deploy.** A browser client
updates when its users reload. A mobile app updates when its users choose to, and a
device in a warehouse updates when someone walks over to it — those get a longer window
and a named owner, not a shorter one.

**The successor is named in the response.** A client that discovers a deprecation from
a header should not have to search for what to use instead.

**Both headers have to reach the browser.** They are not safelisted, so CORS must
expose them or the client never sees either — [cors](cors.md).

**The contract marks it, because that is where clients look.** A deprecated endpoint or
field is flagged in the generated document, with its sunset date
([openapi-contract](openapi-contract.md)).

**Sunset needs evidence, not a calendar.** Before the route is deleted, the logs have
to show the traffic has actually stopped, by client. A date that passes while a client
is still calling is a decision to break that client, and it should be made
deliberately rather than by a diary reminder.

**Removing a field is the same procedure as removing an endpoint.** It is the change
most often taken for a small one, and it is the one that breaks a client that was
reading it — [api-versioning](api-versioning.md).
