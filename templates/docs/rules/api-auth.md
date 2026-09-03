---
id: api-auth
title: API authentication — Doorkeeper, coarse scopes, server-side revocation
applies_to: ["app/controllers/api/**/*.rb", "config/initializers/doorkeeper.rb", "config/routes.rb"]
triggers: ["authentication", "bearer token", "OAuth", "Doorkeeper", "scope", "revoke", "401", "access token", "refresh token", "current_user in api"]
see_also: ["policy-objects", "error-envelope", "status-codes", "rate-limiting"]
modes: [ api ]
tokens: 1160
current_state: matches
---

# API authentication

Doorkeeper. Bearer tokens, OAuth 2, and one line per controller:

```ruby
class Api::V1::ItemsController < Api::V1::BaseController
  before_action -> { doorkeeper_authorize! :read },  only: [ :index, :show ]
  before_action -> { doorkeeper_authorize! :write }, only: [ :create, :update, :destroy ]
end
```

`current_user` comes from the token's resource owner and is already defined on
`Api::V1::BaseController`. There is no session to read it from, so an action that
reaches for one is in the wrong base class.

**Scopes are coarse and about capability, not identity.** `read`, `write`, and one
per resource family where a client genuinely needs less than all of it. A scope per
endpoint is a permission system pretending to be a scope list, and it ends up
disagreeing with the real one.

**Scopes answer "may this client", policies answer "may this record".** Doorkeeper
gates the action; ownership is still a scoped lookup and record-level questions still
go to `app/policies/` — [policy-objects](policy-objects.md). A token with `write`
scope is not permission to write *someone else's* row.

**Revocation is server-side and must stay that way.** It is the reason Doorkeeper is
here rather than a self-signed JWT: a token has to be killable before it expires,
from support, without a deploy. Anything that makes revocation advisory — a long TTL,
a cached authorization decision, a stateless verify path added for speed — takes away
the thing this was chosen for.

**A token never travels in a URL.** `Authorization: Bearer` only. Query strings land
in access logs, browser history, and referrer headers.

**Failures use the standard shapes.** No credentials or bad credentials is `401`;
valid credentials with insufficient scope is `403`; both carry a problem document —
[status-codes](status-codes.md), [error-envelope](error-envelope.md).

That is not Doorkeeper's default. `handle_auth_errors :raise` in the initializer is
what sends its failures through this app's boundary; left as `:render`, Doorkeeper
answers in its own shape and the app has two error formats — one of them
undocumented, and both reaching the same client.

**Authentication endpoints are rate-limited by identifier, not only by IP** —
[rate-limiting](rate-limiting.md).

**The OAuth endpoints are the one un-versioned surface.** `use_doorkeeper` mounts
`/oauth/token` and `/oauth/revoke` above `namespace :api` in `routes.rb`, and that
is deliberate: every OAuth client library assumes those paths, and a token endpoint
does not change shape between `v1` and `v2` of the resources behind it. They are
the exception [api-versioning](api-versioning.md) otherwise refuses, and CORS names
them by hand — [cors](cors.md). Their errors are RFC 6749 shape (`error`,
`error_description`), not a problem document — [error-envelope](error-envelope.md).

**A first-party browser client uses the password grant, as a public client.** The
shipped initializer configures the authorization-code flow, which needs a login page
an API-only app does not have. The initializer carries a commented block that
enables `grant_flows %w[password]` and resolves the resource owner from Devise
credentials; `db/seeds.rb` creates one public `Doorkeeper::Application` for the
client to name. It is public (`confidential = false`) because a secret shipped in
JavaScript is not a secret. Third-party clients still get the authorization-code
flow, and enabling one grant does not disable the other.

**Why this weight is justified.** The audited app, with no rule about any of it,
hand-built bearer tokens, signed verification, digest-keyed revocation and
per-user invalidation timestamps — Doorkeeper's feature list, arrived at because the
requirements are real ones that show up after launch. The library costs a migration set
now; reaching it late costs a rewrite of every client.

Rationale and consequences: [ADR 0011](../adr/0011-oauth-2-via-doorkeeper.md).
