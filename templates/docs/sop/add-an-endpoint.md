# How To: Add an Endpoint

API mode. The order below is the order the layers depend on each other, and every
step links to the rule that governs it rather than restating it. The rules are the
authority; this page is only the sequence.

## Steps

### 1. Route it, under the version

In `config/routes.rb`, inside `namespace :api` › `namespace :v1`:

```ruby
resources :tasks, only: [ :index, :show, :create, :update, :destroy ]
```

Seven actions only. A new verb is a new resource, not a custom action —
[controllers](../rules/controllers.md). Nothing lives outside the version prefix —
[api-versioning](../rules/api-versioning.md).

### 2. Write the request test first

`test/integration/api/tasks_test.rb`. One test per status the endpoint can answer:
the success, `401` with no token, `403` with the wrong scope, `404` for another
user's record, `422` for an invalid body. Assert the status and the problem
document's `type`, never its `detail` —
[api-testing](../rules/api-testing.md), [status-codes](../rules/status-codes.md),
[error-envelope](../rules/error-envelope.md).

The request tests are the source of `openapi.yaml`. An endpoint without one is
undocumented — [openapi-contract](../rules/openapi-contract.md).

### 3. Validate the body with a contract

`app/contracts/tasks/create_contract.rb` and, if update differs, `update_contract.rb`.
Declare the type, then the range; on update, validate only what was provided —
[request-contracts](../rules/request-contracts.md).

### 4. Validate the query string with a filter

Only for `index`. `app/filters/task_filter.rb` allowlists the filter and sort
parameters and returns a relation — [filtering-sorting](../rules/filtering-sorting.md).
Every list paginates by cursor, never by page number —
[cursor-pagination](../rules/cursor-pagination.md).

### 5. Decide who may, and scope the lookup

Scopes answer "may this client"; a policy answers "may this record" —
[api-auth](../rules/api-auth.md), [policy-objects](../rules/policy-objects.md). Load
through the owner (`current_user.tasks.find(...)`) and let the miss raise: the base
controller turns it into a `404` problem document —
[exception-boundary](../rules/exception-boundary.md).

### 6. Put the write in a service

`app/services/create_task_service.rb`, returning a `Result`. The transaction lives
here, not in the controller — [service-objects](../rules/service-objects.md),
[write-path](../rules/write-path.md). If the call costs money or reaches a provider,
it is idempotent — [idempotency](../rules/idempotency.md). If it outlives the request,
answer `202` and enqueue — [async-202](../rules/async-202.md).

### 7. Shape the response with a serializer

`app/serializers/task_serializer.rb`. Every body goes through one; nothing renders a
model — [serialization](../rules/serialization.md). Exposing an association means
preloading it — [n-plus-one](../rules/n-plus-one.md),
[sparse-fieldsets-includes](../rules/sparse-fieldsets-includes.md).

### 8. Write the controller last

`app/controllers/api/v1/tasks_controller.rb`, inheriting `Api::V1::BaseController`.
`doorkeeper_authorize!` per action, the contract, the service, then map the `Result`
to a status and hand the serializer the value — [controllers](../rules/controllers.md).
An endpoint a stranger can reach is rate-limited —
[rate-limiting](../rules/rate-limiting.md).

### 9. Regenerate what the tests describe, in the same PR

```bash
bin/test
bin/rails api:contract    # openapi.yaml from the request tests
bin/rails db:queries      # db/queries.yml gains the new SQL shapes; review them
bin/rubocop
```

Commit `openapi.yaml` and `db/queries.yml` with the endpoint. CI fails on either
drifting — [openapi-contract](../rules/openapi-contract.md),
[query-ledger](../rules/query-ledger.md).

## Done when

- Every status the endpoint can answer has a request test, and the suite is green.
- `bin/rails api:contract:check` and `bin/rails db:queries:check` both pass.
- Nothing in the diff lives outside `app/controllers/api/v1/`, `app/contracts/`,
  `app/filters/`, `app/policies/`, `app/services/`, `app/serializers/`, `test/`,
  `config/routes.rb`, `openapi.yaml` and `db/queries.yml`. Anything else is a new
  pattern, and needs an ADR — [pattern-budget](../rules/pattern-budget.md).
