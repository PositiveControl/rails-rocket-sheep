# What building a kanban API on a generated app found

A second API-mode generation, done to exercise the deterministic gates end to end:
`rails new rocket_sheep_api --api --database=postgresql`, template commit `0df114e`,
Rails 8.1.3.1, PostgreSQL 15. Then a Trello-like board with fixed columns — one
`tasks` resource, all seven-action-shaped, built only from the rule corpus — with
request tests for every status, the OpenAPI contract generated from them, and a
vanilla-JS client that logs in with the OAuth password grant and drags cards between
columns over CORS.

**Result: the gates work, and the app works.** Every layer in
[`deterministic-gates.md`](deterministic-gates.md) §1 was fired in both directions:

| Gate | Clean | Violated |
|---|---|---|
| `bin/gates` / `bin/gates --strict` | exit 0 | — |
| `bin/hooks/pre-push` | push accepted | push refused; `SimpleDelegator` and `app/widgets/` both named, with the rule and the fix |
| unindexed-foreign-key check | passes on `(user_id, status, position)` | `tasks.user_id has a foreign key but leads no index` once the index line was removed from `db/schema.rb` |
| `bin/hooks/post_edit` | exit 0 on a clean file | exit 2 with the RuboCop output on `Style/RedundantReturn` |
| `bin/hooks/session_end` | exit 0 | exit 2 naming `docs/plans/probe.md` for `Status: Draft` |
| `bin/rails api:contract:check` | `openapi.yaml is current` | (refuses to write when a request test fails — observed while a test was red) |
| `bin/rubocop`, `bin/brakeman` | clean at the end | — |

Twenty-four tests, all green. What follows is what had to be fixed or worked around
to get there, in the order it would bite the next person.

---

## Template defects

### 1. A fresh app fails `bin/rubocop` — and therefore the CI `lint` job

`template.rb:876` writes the idempotency migration with two spaces after `t.string`:

```
db/migrate/..._create_idempotent_requests.rb:4:15: C: Layout/SpaceBeforeFirstArg
      t.string  :key,         null: false
```

The generated app's own hooks would have caught it had an agent written the file;
the generator did, so nothing looked. Every API-mode app ships red on its first
push. **Fix:** single space in the heredoc, and run `bin/rubocop` in the generation
probe (`CLAUDE.md` › Testing a change already asks for it).

### 2. A contract's numericality check validates the *cast* value

[`request-contracts.md`](../templates/docs/rules/request-contracts.md) promises:
*"`ActiveModel` casts `"abc"` to `0` for an integer attribute, silently. A declared
type without a `numericality` check turns a client's typo into a free item."* The
implied claim is that `numericality` catches it. It does not, when `0` is in range:

```ruby
Tasks::CreateContract.new("title" => "x", "position" => "abc").valid?   # => true, position 0
```

`NumericalityValidator` reads `#{attr}_before_type_cast` when the record responds
to it. ActiveRecord models do; `ActiveModel::Attributes` keeps the raw value in its
`AttributeSet` but defines no reader, so the validator sees `0` and passes it. The
rule's own example survives only because it uses `greater_than: 0`. A request test
for `position: "abc"` answered `201` with the card at the top of the column.

**Fix, three lines in `ApplicationContract`,** which restores the ActiveRecord
behaviour:

```ruby
attribute_method_suffix "_before_type_cast", parameters: false

def attribute_before_type_cast(name)
  @attributes[name].value_before_type_cast
end
```

With that in place the same request is a `422` naming `position`. Ship it in
`templates/app/contracts/application_contract.rb`, and reword the rule's trap
paragraph so it does not imply the range check alone is enough.

### 3. A contract cannot express a partial update

`ApplicationContract#to_h` returns every declared attribute, `nil` for the ones the
client did not send. `request-contracts.md` prescribes `Items::UpdateContract` for
updates — "required on create, optional on update" — but a `PATCH { status: "done" }`
through such a contract yields `{ title: nil, description: nil, status: "done",
position: nil }`, and a service that splats it blanks the title. There is no way,
from the contract's public surface, to tell *omitted* from *null*.

**Fix,** also in the base class: remember the keys the client sent and slice `to_h`
to them.

```ruby
def initialize(params = {})
  @provided = params.keys.map(&:to_sym)
  super
end

def to_h
  attributes.symbolize_keys.slice(*@provided)
end
```

Conditional validations can then use it (`if: -> { @provided.include?(:title) }`),
which is exactly the "required on create, optional on update" the rule describes.

### 4. CORS does not cover the token endpoint, so a browser client cannot log in

[`cors.md`](../templates/docs/rules/cors.md) applies the policy to `/api/*` only.
Doorkeeper mounts `/oauth/token` via `use_doorkeeper`, outside that prefix. A
separate-origin JS client — the premise of API mode — gets its preflight to
`/oauth/token` refused and never obtains a token. The same route is also the one
that escapes [`api-versioning.md`](../templates/docs/rules/api-versioning.md)'s "no
exceptions"; the rule file and `routes.rb` disagree with each other on the line
above `namespace :api`.

**Fix:** a second `resource` in `cors.rb.tt`:

```ruby
resource "/oauth/token", headers: :any, methods: %i[post options], max_age: 600
```

(`/oauth/revoke` too, if logout is meant to revoke.) And a sentence in
`api-versioning.md` or `api-auth.md` acknowledging that the OAuth endpoints are the
one un-versioned surface, and why.

### 5. There is no first-token story for a browser client

The shipped `doorkeeper.rb` configures `resource_owner_authenticator` through
Warden — the authorization-code flow, which needs a server-rendered login page an
API-only app does not have — and sets no `grant_flows`. Getting a token for the
client meant enabling the password grant by hand and seeding a public
`Doorkeeper::Application`:

```ruby
grant_flows %w[password]
resource_owner_from_credentials do |_routes|
  user = User.find_by(email: params[:username])
  user if user&.valid_password?(params[:password])
end
```

```ruby
Doorkeeper::Application.find_or_create_by!(uid: "kanban-client") do |app|
  app.name = "Kanban client"; app.confidential = false
  app.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"; app.scopes = "read write"
end
```

Neither is in a rule, a doc, or `seeds.rb`. **Suggest:** a commented block in the
initializer, a seed for the first client application, and a paragraph in
`api-auth.md` on which grant a first-party SPA uses and why the client is public.
(The token endpoint answers its errors in RFC 6749 shape — `error`,
`error_description` — not as a problem document. That is what the OAuth spec
requires; the client-contract rule could say so, since it is the one place a client
meets a second error format.)

### 6. The contract builder emits an invalid media type for `204`

A `204 No Content` has no `media_type`, and `Api::ContractBuilder#response_object`
keys `content` by it anyway:

```yaml
'204':
  description: observed in a request test
  content:
    ! '': {}
```

An empty-string media type is not valid OpenAPI 3.1. **Fix:** omit `content` when
`observation["media_type"]` is nil.

## Documentation drift

7. **`CLAUDE.md.tt` in API mode carries the web-mode SEO section** — robots.txt,
   `/sitemap.xml`, `StructuredDataHelper#jsonld_tag`, `test/integration/seo_test.rb`,
   the Lighthouse workflow. None exist in the generated app. Guard the section on
   `API`.
8. **`api-testing.md` opens with "Minitest and FactoryBot, as everywhere else."**
   `testing.md`, which it defers to, says "no RSpec, no FactoryBot". Fixtures is the
   convention; the API rule contradicts it in its first sentence.
9. **Rate limiting is routed and declared `matches`, but does not exist.** `INDEX.md`
   routes `config/initializers/rack_attack.rb` to `rate-limiting.md`, whose
   frontmatter says `current_state: matches`. The Gemfile has no `rack-attack` and
   no initializer ships. Either ship it or mark the rule `diverges` with a *Where
   this app is* section, as [ADR 0011](../.agents/adr/0011-a-rule-declares-how-far-the-app-has-drifted-from-it.md)
   requires.
10. **`docs/system/models.md` describes a `User` that is not the one generated** —
    `has_many :sessions`, a `role` column, an `active` scope. `rails g devise User`
    produces none of them. Either generate the section from the model or ship it as
    an obvious placeholder.
11. **A `db:create` failure mid-generation is unrecoverable from the docs.** The
    template aborts, correctly, and leaves an app with no git repository, no hooks
    path, and no commit. `getting-started.md` says "delete the half-generated
    directory and run the generator again", but when the cause is the server's
    `template1` (below) the re-run fails identically. Finishing by hand meant reading
    `template.rb` for the four remaining steps: `db:migrate`, `git init`,
    `git config core.hooksPath bin/hooks`, `git add` + commit. Document them, or make
    `bin/setup` idempotent enough to be the resume path.

## Environment, not template

Recorded so the next person does not chase them. All three were already noted in
[`first-generation-findings.md`](first-generation-findings.md); this run adds what
they cost the second time.

- **PostgreSQL's `template1` is `SQL_ASCII` in this container**, so `db:create`
  with `encoding: unicode` fails. Pre-creating the eight databases from `template0`
  does **not** get past it — PostgreSQL checks encoding compatibility before it
  checks for a name collision, so `db:create` still errors rather than seeing
  "already exists". And it recurs: Rails' `maintain_test_schema` *purges* the test
  database (drop + create) on every schema change, so the test database vanished on
  the first `bin/test`. Fixing `template1` itself needs `DROP DATABASE template1`,
  which the sandbox refused. What worked, and is worth considering as a default in
  `database.yml.tt` for PostgreSQL: `template: template0` under `default:`.
  `template0` is compatible with every encoding, so `db:create` and the test purge
  stop depending on the server's locale.
- **`ENV["USER"]` is unset and `localhost` resolves to IPv6** — `DB_USERNAME=node
  DB_HOST=/tmp` (a socket directory works as `host`) for every `bin/rails` call.
- **Port 3000 was already held by another Ruby process.** Puma exited with
  `EADDRINUSE`, but `curl localhost:3000/up` answered `200` from the other app, and
  the first end-to-end run hit that app for several minutes before the mismatch was
  obvious. `-p 3001` for the API; the client's `API` constant follows.
- `ruby -run -e httpd` needs `webrick`, which Ruby 3.4 no longer bundles; the client
  is served with `python3 -m http.server 8080`.

## What the app looks like

`rocket_sheep_api/` beside this repo. `GET/POST /api/v1/tasks`,
`GET/PATCH/DELETE /api/v1/tasks/:id`; `TaskFilter` on `status` with `position`
sort; `PlaceTaskService` keeps each column's positions dense on create and move;
`client/index.html` is the board. Run it:

```bash
DB_HOST=/tmp DB_USERNAME=node SEED_ADMIN_PASSWORD=… bin/rails db:seed
DB_HOST=/tmp DB_USERNAME=node bin/rails server -p 3001
(cd client && python3 -m http.server 8080)   # http://localhost:8080, log in as admin@example.com
```
