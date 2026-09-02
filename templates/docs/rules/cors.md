---
id: cors
title: CORS — named origins, and never a wildcard with credentials
applies_to: ["config/initializers/cors.rb", "config/routes.rb"]
triggers: ["CORS", "cross-origin", "preflight", "OPTIONS", "Access-Control-Allow-Origin", "browser blocked", "credentials"]
see_also: ["api-auth", "client-contract", "rate-limiting"]
modes: [ api ]
tokens: 580
current_state: matches
---

# CORS

The JS client is a separate origin, so CORS is load-bearing rather than incidental.
One initializer, origins from credentials, applied to the API namespace only.

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins Rails.application.credentials.dig(:api, :allowed_origins)
    resource "/api/*",
             headers: :any,
             methods: [ :get, :post, :patch, :delete, :options ],
             expose:  %w[Retry-After Deprecation Sunset],
             max_age: 600
  end
end
```

**Origins are named, and they come from credentials.** One list per environment, no
regex over your own domain, and no `origins "*"`. A wildcard is only ever safe on an
endpoint with no credentials and nothing worth reading, which is not an endpoint this
app has.

**A wildcard plus credentials is not a mistake the browser saves you from twice.**
`origins "*"` with `credentials: true` is rejected by browsers, and the usual fix —
reflecting the request's `Origin` back — is worse: it allows every site your users
visit to call this API as them. If a token is involved, the origin is on the list or
the request fails.

**Expose the headers the client actually reads.** A browser hides every response header
but a safelisted few, so `Retry-After` on a `429` and the deprecation headers are
invisible to the client unless they are named here —
[deprecation-policy](deprecation-policy.md).

**Preflights are cached, and they are still requests.** `max_age` keeps `OPTIONS`
traffic down; rate limiting still has to allow for it —
[rate-limiting](rate-limiting.md).

**CORS is not authorization.** It tells a browser which origins may read a response.
It stops nothing that is not a browser, so it is never the reason an endpoint is safe
— [api-auth](api-auth.md).
