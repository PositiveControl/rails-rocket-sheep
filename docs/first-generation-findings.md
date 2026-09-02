# What generating an API app for the first time found

`docs/inventory.md` and [ADR 0007](../.agents/adr/0007-database-family-is-chosen-at-generation.md)
both record the same debt: no generated app in this repo's history had ever been run.
API mode shipped with that debt and one more — the rules named base classes, a helper
and a rake task that were written from the rules rather than against a running app.

So one was generated: `rails new sheepapi --api --database=postgresql`, PostgreSQL 15,
Rails 8.1.3. Then one endpoint was built using only the rule corpus, request tests
written for every status it can return, the contract generated from those tests, and a
JavaScript client pointed at the committed contract.

**Nine defects. Eight of them could not have been found by reading.**

## The one that would have shipped silently, in both modes

`inject_into_file "test/test_helper.rb", before: /^class ActiveSupport::TestCase/`
matches nothing on Rails 8.1, which generates `module ActiveSupport` with a nested
`class TestCase`. Thor prints `File unchanged!` and generation continues at exit 0.

The effect in **web mode, today**: `test/support/vcr.rb` and `test/support/slowpoke.rb`
ship and are never required. VCR configures nothing, WebMock blocks nothing, and
`docs/rules/testing.md` says "WebMock blocks the network in tests" — of an app where
it does not. Every generated app has been in that state.

Both injections now anchor on `require "rails/test_help"`, which is stable across
versions.

## The one that made authorization pass with no user

Doorkeeper's migration writes `t.references :resource_owner` with no type, which emits
`bigint`. On PostgreSQL this app's keys are `uuid`, so a uuid resource owner id casts
to a meaningless integer — a token created for user `95c7…` stored `95`.
`doorkeeper_authorize!` succeeded, `User.find_by(id: 95)` returned nil, and
`current_user` was nil inside an authorized action.

`docs/rules/database-conventions.md` warns about exactly this: "Never
`t.references :parent` without a type — it silently emits a bigint that will not match
the parent's key." A generator this template does not own did it anyway, and nothing
was watching. The migration is now patched to `type: :uuid` on PostgreSQL.

## The rest

| Defect | Effect |
|---|---|
| `config.view_component.generate.sidecar` written in API mode | The gem is absent, so the app could not boot at all — generation died on the first `rails` invocation |
| Idempotency migration timestamp computed as `Time.now + 1s` | Collided with Doorkeeper's migration, which had just been generated in the same second. `DuplicateMigrationVersionError` on first migrate. Now derived from the highest version present |
| Doorkeeper's `resource_owner_authenticator` rewrite | The regex assumed `end` followed the `raise`; Doorkeeper puts explanatory comments between them, so the raise stayed and nothing said so. Now replaces the raise line alone |
| `api_headers` created an access token with no application | `application_id` is NOT NULL in Doorkeeper's migration. Every authenticated test errored. The helper now creates one client per suite |
| `relation.preload(*[])` | Raises when nothing is included, so an endpoint worked with `?include=` and broke without it. This was in an example the rule itself shipped. The guard moved into `ApplicationSerializer.preload` where a caller cannot forget it |
| `optional :description` produced `nil` | The field was declared optional but `#fields` did not return it, and nothing said so. Design flaw, not usage: optional fields are now self-sourcing, from a serializer method or the record |
| Doorkeeper rendered its own 401 and 403 | In HTML, bypassing the problem envelope — a second, undocumented error format in an app whose premise is having one. The generated contract is what exposed it: two responses came back `content: text/html`. `handle_auth_errors :raise` plus two rescues route them through the boundary |

## What the contract generator did

It worked, and it earned its place by finding the defect above. Running the eleven
request tests produced an OpenAPI 3.1 document naming three paths, six statuses, and
five problem types — all observed, none typed by hand. `api:contract:check` exits 1 on
a hand edit and 0 when current, so the CI gate is real.

## What the client confirmed

A JavaScript client that reads the committed contract and holds the server to it:
17 checks, all passing. Keys `snake_case`; money as minor units with a currency; times
ISO 8601; a cursor issued only when rows remain and pages that do not overlap; `403`
for a read-only token writing and `401` for a bad one, each with its own stable
problem `type`; every problem carrying `title` and `status` to fall back on; CORS
allowing the named origin, refusing an unnamed one, and exposing the headers a client
has to act on.

## Environment notes, not template defects

Recorded so the next person does not chase them. This container's PostgreSQL
`template1` is `SQL_ASCII`, so `db:create` cannot clone a UTF8 database — the
databases were created with `-T template0`. `DB_HOST` defaults to `localhost`, which
resolved to IPv6 where the server was not listening. `ENV["USER"]` is unset in a
container, and `config/database.yml` uses it for the PostgreSQL username.

## What is still unverified

Kamal deploy, MySQL in API mode, and the `adopt.rb` path into an existing API app.
The mode-detection branch in `adopt.rb` was exercised only through generation, where
`rails new --api` had already written `config.api_only`.
