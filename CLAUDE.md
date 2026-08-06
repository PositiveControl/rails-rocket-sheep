# <%= app_name.titleize %>

Rails 8 application built with the Solid Stack architecture.

## Quick Start

```bash
bin/dev              # Start development server with Tailwind watcher
bin/test             # Run tests (single worker on macOS)
bin/rails console    # Rails console
bin/rails db:migrate # Run migrations
bin/rubocop          # Run linter
bin/brakeman         # Security analysis
```

## Tech Stack

- **Backend:** Rails 8 + PostgreSQL
- **Frontend:** Hotwire (Turbo + Stimulus), Tailwind CSS
- **Templates:** Slim (not ERB)
- **Components:** ViewComponent (`app/components`, `ApplicationComponent`)
- **Pagination:** Pagy (wired into `ApplicationController`)
- **Background Jobs:** Solid Queue (database-backed)
- **Caching:** Solid Cache (database-backed)
- **WebSockets:** Solid Cable (database-backed)
- **Auth:** Devise + Petergate
- **Deployment:** Kamal 2 with Docker
- **Linting:** RuboCop with Rails Omakase config
- **Security:** Brakeman static analysis

## Conventions

### Development Workflow

- **Planning:** Create plan file in `docs/plans/` for non-trivial features before coding
- **Collaborative:** Explain findings and reasoning; stop often for feedback
- **TDD:** Write tests before code. Commit in functional chunks when tests are green.
- **Flaky Tests:** Fix immediately; do not ignore or skip, even when unrelated to your changes
- **Slow Tests:** Slowpoke flags tests over 500ms after each run. Fix the cause or state why it's inherent — don't let the report become noise
- **TDD Pairing:** Stop when tests fail to present context and discuss next steps
- **Commits:** Small, focused commits with clear messages
- **Documentation:** Update `docs/` when implementing features, `grep` for existing docs first 

### Code Style

- **DRY:** Don't Repeat Yourself. If you see duplicated code, centralize it. Extract helpers, concerns, or services when patterns repeat 2-3 times.
- **Service objects:** Use `ApplicationService` base class with Result pattern
- **Form objects:** Use `ApplicationForm` for multi-model or non-AR forms
- **Registry pattern:** Fixed variant sets as `Data` objects in `app/lib/` — see `plan_registry.rb`
- **Deletes:** `destroy` by default. Discard (`include Discard::Model`) only when a table earns it
- **Audit trail:** Use PaperTrail gem (`has_paper_trail`)
- **Scopes over class methods:** For all queries
- **RESTful controllers:** Seven actions; a new verb gets its own controller

### Database

- **IDs:** UUIDs for all tables (auto-configured)
- **Foreign keys:** Use `t.uuid :parent_id` with `add_foreign_key`
- **Indexing:** Add composite indexes for frequently filtered columns

### Frontend

- **Slim only:** No ERB templates
- **Tailwind:** Utility classes inline
- **Components:** `bin/rails g component Name` — class, Slim sidecar template, and test
- **Partials:** Declare strict locals (`/# locals: (order:)`), never read instance variables
- **Stimulus:** `thing_controller.js` naming convention
- **Generic controllers:** Use `toggle_controller.js` and `modal_controller.js` for common patterns

## Architecture Principles

Short form below. The reasoning, the "when not to", and the rejected patterns live in
`docs/system/design-patterns.md` (backend) and `docs/system/ui-patterns.md` (views).
Read those before introducing a pattern that isn't listed here.

### Where code goes

| Directory | Holds | Add a file when |
|-----------|-------|-----------------|
| `app/services/` | Multi-step writes with a failure path | An operation touches >1 model, or runs from >1 caller |
| `app/forms/` | Form objects (`ApplicationForm`) | One submit writes ≥2 models, or a field isn't a column |
| `app/queries/` | Reads that join ≥2 models | A scope would need a join and 3+ clauses |
| `app/policies/` | Record-level authorization | The answer depends on the record, not just the role |
| `app/lib/` | Registries — frozen hashes of `Data` objects | A fixed set of variants each carry the same attributes |
| `app/components/` | UI units (`ApplicationComponent`) | Markup has logic or variants, or is reused |

Six directories. A new top-level directory under `app/` is an architecture decision —
record an ADR in `docs/system/architecture.md` or don't create it. The default answer
for any given piece of code is still a model method, a scope, or a controller action.

### Non-negotiables

**Controllers**
- Seven actions only — `index show new create edit update destroy`. A new verb is a new resource with its own controller.
- Actions stay under ~10 lines: find, delegate, branch, respond.
- Form failures render with `status: :unprocessable_content`. Without it Turbo discards the response and the form silently freezes.
- Every index paginates. Pagy is wired into `ApplicationController`; use `@pagy, @records = pagy(scope)`.
- Scope every lookup — `current_user.orders.find(params[:id])` — and let a miss raise. `rescue_from` handles it once in `ApplicationController`.
- `rate_limit` (Rails 8, backed by Solid Cache) on sign-in, password reset, signup, and anything that sends mail.

**Business logic**
- `ApplicationService` for coordination. `failure()` for expected outcomes, `raise` for broken invariants. Transactions live here, never in controllers or callbacks.
- `ApplicationForm` for multi-model or non-AR forms. Never `accepts_nested_attributes_for`.
- Query objects for joins across ≥2 models. Always return a relation, never an array.
- Policy objects for record-level authorization; Petergate `access` for role-level.
- Registries for fixed variant sets: a frozen hash of `Data` objects, `fetch` for lookup. Query capabilities (`PlanRegistry[key].has_feature?(:api)`), never identities (`plan == "pro"`).

**Models**
- Scopes, never class methods returning relations.
- Callbacks touch only their own record. Writing other models, sending mail, and calling APIs belong in a service. Enqueue jobs from `after_commit`, never `after_save`.
- `includes` when you read an association, `counter_cache` when you only need the number. Sort and aggregate in the database.
- Deletes are real by default. Add Discard only when restoration is a user-facing feature, an audit obligation requires the row, or foreign keys must stay valid — then `.kept` is on you in every query, and never `default_scope`.

**Jobs**
- Thin wrapper over a service. Takes IDs, not records. Guards at the top so a retry is a no-op. Enqueued after the transaction commits.

**Views**
- Component > partial > helper > inline. Partials declare strict locals and read no instance variables.
- Turbo streams from the controller by default; model `broadcasts_to` only for genuine multi-user push.
- Stimulus uses targets, values, and classes — never `document.querySelector`, never Tailwind class strings in JS.

### DRY

Same code 2–3 times is the trigger. Where it goes depends on what repeats: a role
across models is a concern, coordination is a service, markup is a component,
formatting is a helper, a query is a scope. Extracting into the wrong one costs more
than the duplication did.

### Slim pitfalls

```slim
/ Tailwind brackets conflict with Slim - use class=""
div class="max-h-[85vh]"

/ Text starting with ( needs a pipe or interpolation
span.count = "(#{count})"

/ Multi-line Ruby needs a ruby: block
ruby:
  config = { foo: { label: "Foo" } }

/ Interpolation in attributes needs a local first
- path = "/items/#{item.id}"
a href=path

/ Strict locals in a partial — exact syntax, first line
/# locals: (order:, compact: false)
```

Full list, plus Tailwind, ViewComponent, Turbo, and Stimulus conventions: `docs/system/ui-patterns.md`.

## SEO

The template includes an SEO foundation out of the box:

- **robots.txt** — Sensible crawl rules in `public/robots.txt`
- **Dynamic sitemap** — `/sitemap.xml` served from `HomeController#sitemap`
- **Meta descriptions** — `<meta name="description">` with per-page `content_for(:meta_description)` overrides
- **Canonical URLs** — `<link rel="canonical">` with per-page `content_for(:canonical_url)` overrides
- **Structured data** — `StructuredDataHelper#jsonld_tag` for JSON-LD, WebSite schema on all pages
- **SEO tests** — `test/integration/seo_test.rb` verifies meta tags, canonical URLs, JSON-LD, sitemap, robots.txt
- **Lighthouse CI** — Weekly audit workflow in `.github/workflows/lighthouse.yml`

See `docs/sop/add-seo-to-a-page.md` for step-by-step instructions.

## Testing

### Running Tests

```bash
bin/test                    # All tests
bin/test test/models/       # Directory
bin/test test/models/user_test.rb:42  # Specific line
```

### Slow tests

Slowpoke reports any test over 500ms after the run — it prints nothing when the
suite is clean. Tune per run with environment variables:

```bash
SLOWPOKE_THRESHOLD=2.0 bin/test                 # only flag tests over 2s
SLOWPOKE_MAX_RESULTS=10 bin/test                # just the worst ten
SLOWPOKE_HISTORY=tmp/slowpoke.json bin/test     # write the run to JSON
SLOWPOKE_CI=true bin/test                       # exit 1 if anything is slow
```

Project defaults live in `test/support/slowpoke.rb`. A slow test is usually a
test creating records its assertion never touches. See `docs/sop/find-slow-tests.md`.

### Test Patterns

```ruby
# Service test
class CreateOrderServiceTest < ActiveSupport::TestCase
  test "creates order with valid items" do
    user = users(:one)
    items = [{ product_id: products(:widget).id, quantity: 2 }]

    result = CreateOrderService.call(user: user, items: items)

    assert result.success?
    assert_equal user, result.value.user
  end

  test "fails with empty items" do
    result = CreateOrderService.call(user: users(:one), items: [])

    assert result.failure?
    assert_includes result.errors, "Items can't be empty"
  end
end

# VCR for external API calls
class ExternalApiTest < ActiveSupport::TestCase
  test "fetches data from external API" do
    vcr_cassette("external_api/fetch_data") do
      result = ExternalApi.fetch_data

      assert result.present?
    end
  end
end
```

### Debugging

```ruby
# In any file
binding.pry  # Drops into debugger

# Common pry commands
# next          - Step over
# step          - Step into
# continue      - Continue execution
# whereami      - Show current location
# ls            - List available methods/variables
```

## Deployment

### Kamal Setup

1. Configure `config/deploy.yml` with your server details
2. Set up secrets in `.kamal/secrets`
3. Run `kamal setup` to provision server
4. Run `kamal deploy` to deploy

### Environment Variables

Required for production:
- `RAILS_MASTER_KEY` - Rails credentials key
- `DATABASE_URL` - PostgreSQL connection string
- `POSTGRES_PASSWORD` - Database password

## Key Documentation

Docs follow a four-directory canon. The workflow commands in `.claude/commands/`
read and write these exact paths — don't rename them.

| Directory | Holds | Written by |
|-----------|-------|------------|
| `docs/plans/` | Design docs for features | `/feature_plan` |
| `docs/system/` | Architecture state — how things currently work | `/pr_submit`, `/update_docs` |
| `docs/sop/` | Procedures someone will repeat | `/pr_submit`, `/update_docs` |
| `docs/qa/` | Manual test guides | `/pr_qa` |

| Topic | File |
|-------|------|
| Models | `docs/system/models.md` |
| Design Patterns (backend) | `docs/system/design-patterns.md` |
| UI Patterns (views) | `docs/system/ui-patterns.md` |
| Architecture Decisions | `docs/system/architecture.md` |
| Procedures | `docs/sop/` |

## Workflow

Command-driven lifecycle. Full spec and diagrams in `WORKFLOW.md`.

```
/pick (entry, routes by state) → /feature_plan → /task_plan → /implement → /pr_submit → human merge → automation
```

- `/pick` is the entry door for every session — it surfaces ready work and routes it
- Four gates: design approved (G1), plan approved (G2), suite green (G3), comments resolved (G4)
- Sizing: 100–600 added lines per PR; issue acceptance criteria ≤5 bullets. Forecast passes 600 lines mid-implementation → stop, split, land the current slice
- `/segue` is the escape valve — isolate a tangent, merge findings back without polluting the workstream
- Conventions are single-sourced **here**. Task files in `.llm/tasks/` reference this file; they never restate it

Run `/workflow_setup` once before first use — it fills in GitHub org, repo, and board IDs.

## Project Structure

```
app/
├── lib/                    # Registries and config modules
├── models/                 # ActiveRecord models
├── services/               # Service objects (inherit ApplicationService)
├── forms/                  # Form objects (inherit ApplicationForm)
├── components/             # ViewComponents (inherit ApplicationComponent)
├── controllers/            # RESTful controllers
├── jobs/                   # Background jobs (Solid Queue)
├── helpers/                # View helpers
├── views/                  # Slim templates
└── javascript/controllers/ # Stimulus controllers

# Created on first use, not shipped empty:
#   app/queries/   Query objects — reads joining ≥2 models
#   app/policies/  Record-level authorization

docs/                       # 4-dir canon — names are load-bearing
├── plans/                  # Design docs (/feature_plan)
├── system/                 # Architecture state
│   ├── architecture.md     #   Architecture Decision Records
│   ├── design-patterns.md  #   Backend patterns
│   ├── ui-patterns.md      #   View patterns
│   └── models.md           #   Model documentation
├── sop/                    # Procedures / how-tos
└── qa/                     # Manual test guides

.claude/commands/           # 19 workflow slash commands (tracked, shared)
.llm/
├── tasks/                  # Task files — local scratch, gitignored
└── threads/                # Segue threads — local scratch, gitignored
bin/pr-stack                # Stacked-PR footer generator (used by /pr_submit)
WORKFLOW.md                 # Lifecycle spec + diagrams
```
