---
id: idempotency
title: Idempotency — a key on every write that costs money
applies_to: ["app/controllers/api/**/*.rb", "app/models/idempotent_request.rb"]
triggers: ["idempotency", "Idempotency-Key", "double charge", "retry", "duplicate request", "replay", "exactly once"]
see_also: ["status-codes", "error-envelope", "async-202", "bulk-endpoints"]
tokens: 740
current_state: matches
---

# Idempotency

A client that times out does not know whether the write happened, so it retries. On a
write that moves money or ships something, the retry must not do the work twice.

Unsafe requests with an external side effect require an `Idempotency-Key` header:

```ruby
before_action :require_idempotency_key, only: [ :create ]

def create
  replayed = IdempotentRequest.replay(key: idempotency_key, user: current_user,
                                      fingerprint: request.raw_post)
  return render(json: replayed.body, status: replayed.status) if replayed

  result = ChargeService.new(current_user, contract).call
  IdempotentRequest.record!(key: idempotency_key, user: current_user,
                            fingerprint: request.raw_post,
                            status: 201, body: serialized)
  ...
end
```

**The stored response is replayed; the work is not repeated.** A key that has been seen
returns the original status and body, byte for byte. A client cannot tell a replay from
the first call, which is the point — it does not have to.

**Records live in a table, not the cache.** The guarantee has to survive an eviction
and a deploy. Unique index on `(user_id, key)`, so a concurrent retry loses the insert
rather than racing the work.

**Same key, different body is a client bug and gets `422`.** Reusing a key for
different content means the client's key generation is broken, and silently replaying
the old response would hide it. Problem type `idempotency-key-reused`.

**Keys expire, and the window is in the contract.** Twenty-four hours is long enough
for every retry a client will make and short enough that the table stays small. After
that a replay is a new request.

**Required where the side effect is external, optional elsewhere.** Payments, refunds,
label purchases, anything that calls a provider that charges per call. A plain
`create` on an owned resource does not need it — a duplicate row is recoverable and a
duplicate charge is not. Endpoints that require it are marked in the contract, and a
missing key is `400`, not a silent pass.

**A `PUT`-shaped update needs no key.** Setting a resource to a stated value is already
idempotent. `POST` is where this rule applies, plus any `PATCH` that increments rather
than sets.

Long-running work returns `202` and its own status resource; the key still applies to
the request that started it — [async-202](async-202.md).
