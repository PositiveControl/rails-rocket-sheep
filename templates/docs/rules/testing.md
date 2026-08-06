---
id: testing
title: Tests — Minitest, fixtures, VCR, which layer tests what
applies_to: ["test/**/*.rb", "test/fixtures/**/*.yml"]
triggers: ["fixture", "fixtures", "VCR", "cassette", "WebMock", "factory", "FactoryBot", "RSpec", "what should I test", "integration test", "system test", "assert_difference", "slow test", "TDD"]
see_also: ["components", "service-objects", "turbo-status", "jobs"]
tokens: 660
---

# Tests

**Minitest and fixtures.** The Rails 8 default, unchanged — no RSpec, no FactoryBot,
no `let`. A PR that adds a second test framework or a factory library is adding a
pattern; it goes through [pattern-budget](pattern-budget.md) first.

Tests come before the code they cover. `bin/test` green, every time, before anything
is claimed to work.

## Which layer tests what

| Code | Test | Lives in |
|---|---|---|
| Model methods, scopes, validations | Unit | `test/models/` |
| Service objects | Unit, through the `Result` | `test/services/` |
| Controller actions | Integration — real request, real status | `test/integration/` |
| ViewComponents | `render_inline` — see [components](components.md) | `test/components/` |
| Jobs | Unit for `perform`, `assert_enqueued_with` at the call site | `test/jobs/` |
| Turbo Stream / Stimulus interaction | System | `test/system/` |

`bin/test` runs everything **except** system tests — those are `bin/rails test:system`,
and they are the only optional layer here. Add one when a flow only breaks in a
browser: a Turbo Frame that never swaps, a Stimulus controller that never connects.
Which of them a given branch has to run is `/pr_submit`'s call, from the diff.

Every new public method and every controller action gets a test: the happy path
**and** the failure that matters (invalid input, unauthorized, missing record).
A method with only a happy-path test is untested for the case that will page you.

## Fixtures

The generator ships an **empty** fixture file per model, on purpose — stock Rails
emits two identical placeholder records and the second one violates the first unique
index it meets. Add fixtures deliberately:

```yaml
# test/fixtures/users.yml
alice:
  email: alice@example.com
  name: Alice
```

- **Name them for what they are** — `alice`, `overdue_invoice`, `admin`. Never
  `one` / `two`; a test that reads `users(:two)` tells the next reader nothing.
- **Values satisfy every unique index.** Distinct emails, slugs, external ids.
- **Build only what the assertion touches.** Records created in `setup` that no
  assertion reads are the usual reason a test crosses Slowpoke's 500ms line —
  [`../sop/find-slow-tests.md`](../sop/find-slow-tests.md). A new test that gets
  flagged needs a reason, not a raised threshold.

## External HTTP

WebMock blocks the network in tests. Every external call is recorded with VCR:

```ruby
vcr_cassette("stripe/create_customer") { Billing::CreateCustomer.call(user:) }
```

Cassettes are named `service/action` and live in `test/vcr_cassettes`. Secrets are
filtered in `test/support/vcr.rb` — add a `filter_sensitive_data` line there before
recording against a new API, and read the cassette before committing it.

## Assertions

Plain `assert_*`, plus the ones that state intent in one line: `assert_difference`,
`assert_raises`, `assert_redirected_to`, `assert_enqueued_with`, `assert_selector`.

- Services assert **both** branches — `success?` and `failure?` — and the `errors`
  on failure. See [service-objects](service-objects.md).
- A failed form submission asserts `assert_response :unprocessable_content`, not
  just the rendered template. A 200 here is the bug — [turbo-status](turbo-status.md).
- Tests are order-independent. No test may depend on another having run.
- No `skip` without a comment saying why and what unblocks it. A flaky test is
  fixed when it is found, not filed.
