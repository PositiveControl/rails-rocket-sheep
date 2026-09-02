---
id: api-versioning
title: Versioning — one number in the path, additive within it
applies_to: ["config/routes.rb", "app/controllers/api/**/*.rb", "app/serializers/**/*.rb"]
triggers: ["version", "v1", "v2", "breaking change", "deprecate a field", "API version", "namespace", "remove a field"]
see_also: ["deprecation-policy", "serialization", "openapi-contract", "client-contract"]
modes: [ api ]
tokens: 610
current_state: matches
---

# Versioning

One version number, in the path, on every route:

```ruby
namespace :api do
  namespace :v1 do
    resources :items, only: [ :index, :show, :create, :update ]
  end
end
```

`app/controllers/api/v1/`, `Api::V1::BaseController`. No unversioned route ever ships
— not for a health check, not for a webhook, not "just internally". The one that
escapes is the one an external client finds.

**Within a version, changes are additive only.** You may add a field, add an endpoint,
add an optional parameter, or widen what an input accepts. You may not remove a field,
rename one, change its type, narrow an input, or change what a status code means for
an existing call. A client written against `v1` on the first day keeps working on the
last.

**A breaking change is a new version, and a new version costs a serializer set.**
`v2` gets its own controllers and its own serializers; it does not get a flag inside
`v1`'s serializer. Conditionals on version inside one serializer are how both
versions end up broken by one edit.

**Two versions is a maximum, not a target.** The old one gets a sunset date the day
the new one ships — [deprecation-policy](deprecation-policy.md).

**Not header versioning, not per-endpoint versioning.** A version in a header is
invisible in a log, a browser, and a bug report, and it makes caching a per-header
problem. A version per endpoint means no client can state which API it speaks.

**The version number is not a changelog.** Additive changes are announced in the
contract, which is generated and diffable, not by bumping a number —
[openapi-contract](openapi-contract.md).

**The cost** is a client pinned to whatever shipped last. The audited app has no
version marker in a nine-hundred-line routes file, and its one API namespace serves a
hardware scanner in the field — the deployment where you least control when the client
updates.
