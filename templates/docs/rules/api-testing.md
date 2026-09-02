---
id: api-testing
title: Tests — request tests are the layer that matters, and they are the contract
applies_to: ["test/**/*.rb"]
triggers: ["what should I test", "request test", "integration test", "system test", "test the API", "assert_response", "contract test", "VCR", "factory"]
see_also: ["openapi-contract", "status-codes", "error-envelope", "api-auth", "testing"]
modes: [ api ]
tokens: 750
current_state: matches
---

# Testing an API

Minitest and FactoryBot, as everywhere else — [testing](testing.md) covers the parts
that do not change. What changes on an API is which layer carries the weight.

**Request tests are the primary layer**, not a supplement to unit tests. They are the
only place the whole boundary appears at once: authentication, scope, contract
validation, status, and body shape. They are also the source of the generated contract
([openapi-contract](openapi-contract.md)), so an endpoint without one is undocumented.

| Layer | Tests | Where |
|---|---|---|
| Endpoints | Request — real request, real status, real body | `test/integration/api/` |
| Serializers | Unit, no request needed | `test/serializers/` |
| Contracts | Unit — valid, invalid, and the coercion traps | `test/contracts/` |
| Filters | Unit, asserting the relation's contents | `test/filters/` |
| Services | Unit, through the `Result`, both branches and the third | `test/services/` |
| Jobs | Unit for `perform`, `assert_enqueued_with` at the call site | `test/jobs/` |

**No system tests.** There is no browser. The suite is `bin/test`, and
`bin/system-test` has nothing to run.

**Every status in [status-codes](status-codes.md) that an endpoint can return gets a
test.** Not the happy path plus one failure — each status, because each one is a
separate promise to a client and they are the cheapest tests in the suite.

**Assert the envelope, not just the status.** A `422` with the wrong body shape passes
a status assertion and breaks every client. A shared assertion keeps it to one line:

```ruby
assert_problem "validation-failed", status: :unprocessable_content, field: :title
```

**Assert the serializer's keys, not a whole fixture blob.** A test comparing the entire
response body to a literal fails on every additive change, which
[versioning](api-versioning.md) explicitly permits — so it trains people to update
fixtures rather than read failures. Assert the keys that matter and their types.

**Authorization is tested per scope, and the negative case is the point.** For every
endpoint: no token is `401`, wrong scope is `403`, another user's record is `404`. The
last one is the enumeration defence, and it is the assertion most often missing
([api-auth](api-auth.md)).

**External calls are recorded with VCR and their secrets filtered before the cassette
is committed** — the filter goes in the same PR as the first recording, not after.
