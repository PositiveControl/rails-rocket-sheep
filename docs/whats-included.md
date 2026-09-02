# What's Included

Every gem and file the template adds, and the reason it's there. Nothing here is a dependency you can't remove — it's all plain Rails files you own.

---

## Gems added

Rails 8 already ships Solid Queue, Solid Cache, Solid Cable, Kamal, and Thruster, so the template doesn't re-add them. It removes `sqlite3` (PostgreSQL or MySQL — SQLite is refused) and adds:

Two gems are added only in `--api` mode, and five are skipped there — an API has no
templates, no components, and no Pagy:

| Gem | Group | Why |
|---|---|---|
| `doorkeeper` | — | **API mode.** OAuth 2 with server-side revocation |
| `rack-cors` | — | **API mode.** The client is a separate origin |
| `tailwindcss-rails` | — | Styling, no bundler needed. *Server-rendered only* |
| `devise` | — | Authentication, pre-configured for Turbo |
| `petergate` | — | Role-based authorization on top of Devise |
| `discard` | — | Soft deletes for the tables that need them; not applied by default |
| `paper_trail` | — | Audit trail, installed `--with-changes` |
| `pagy` | — | Pagination; far lighter than Kaminari. *Server-rendered only — API mode paginates by cursor* |
| `slim-rails` | — | Terser templates, enforced indentation. *Server-rendered only* |
| `view_component` | — | UI components with a real interface and unit tests. *Server-rendered only* |
| `resend` | — | Transactional email API client |
| `letter_opener_web` | development | Preview mail at `/letter_opener` |
| `pry`, `pry-rails` | dev, test | `binding.pry` debugging |
| `bullet` | dev, test | N+1 query detection |
| `rubocop-rails-omakase` | dev, test | Linting, DHH's config |
| `brakeman` | dev, test | Security static analysis |
| `vcr`, `webmock` | test | Record and replay HTTP in tests |
| `slowpoke-rb` | test | Reports tests slower than a threshold after each run; zero dependencies |

---

## Files the template writes

### Configuration

| File | Purpose |
|---|---|
| `config/database.yml` | Multi-database setup — primary, queue, cable, cache — with per-environment names and `migrations_paths` |
| `config/queue.yml` | Solid Queue dispatchers and workers; production tuned separately |
| `config/cache.yml` | Solid Cache retention and size caps; connects to the `cache` database in production |
| `config/cable.yml` | Solid Cable in development *and* production, so behaviour matches |
| `config/recurring.yml` | Recurring job schedule scaffold |
| `config/deploy.yml` | Kamal 2 with a database accessory matching your `--database=` — `postgres:16`, `mysql:8.4`, or `mariadb:11` |
| `config/routes.rb` | Health check, sitemap, letter_opener mount, root |
| `.rubocop.yml` | Rails Omakase base |

`config/application.rb` is modified to autoload `app/lib`, generate ViewComponents with a sidecar directory, and — on PostgreSQL — set UUID primary keys on the generators.

> **Note:** the four Solid Stack configs are written twice — once during the main pass, and again in `after_bundle`. Rails 8 runs its own `solid_*:install` generators after bundling, and those overwrite anything already there. The second write is what actually survives.

### Application code

| File | Purpose |
|---|---|
| `app/services/application_service.rb` | Service object base class with a `Result` struct |
| `app/forms/application_form.rb` | Form object base class — `ActiveModel`, `save`/`save!`, `promote_errors` |
| `app/components/application_component.rb` | ViewComponent base class with `class_names` |
| `app/components/alert_component.rb` | Inline message, four variants, renders nothing when empty |
| `app/components/flash_component.rb` | Renders the Rails flash as a stack of alerts; wired into the layout |
| `app/components/error_summary_component.rb` | Validation errors for a model or form object |
| `app/components/empty_state_component.rb` | Empty-collection state with an action slot |
| `app/lib/plan_registry.rb` | Canonical registry — `Data` entries, `fetch` lookup, capability queries |
| `app/lib/app_config.rb` | App-wide frozen constants: branding, feature flags, limits, timing |
| `app/models/application_record.rb` | `implicit_order_column` on PostgreSQL, where UUID keys have no natural order |
| `app/helpers/structured_data_helper.rb` | `jsonld_tag` and `iso8601_duration` |
| `app/helpers/progress_bar_helper.rb` | Progress bar markup helper |
| `app/javascript/controllers/toggle_controller.js` | Generic show/hide Stimulus controller |
| `app/javascript/controllers/modal_controller.js` | Generic modal Stimulus controller |
| `app/controllers/home_controller.rb` | Landing page plus a dynamic `sitemap.xml` |
| `app/views/home/index.html.slim` | Placeholder home page |

`app/controllers/application_controller.rb` gets `include Pagy::Method`, so pagination works without further wiring. The layout renders `FlashComponent`.

Everything above is server-rendered mode. In `--api` mode the components, the form
object, the Stimulus controllers, the SEO helper and the home page are not written at
all, and these are:

| File | Purpose |
|---|---|
| `app/controllers/api/v1/base_controller.rb` | `ActionController::API` plus the three things every endpoint shares: the RFC 9457 `problem` helper, one exception boundary, `current_user` from the token, and `per_page` clamped once |
| `app/serializers/application_serializer.rb` | Explicit fields, `optional` and `includable` declarations, and `preload` so the caller cannot forget an association's preloads |
| `app/contracts/application_contract.rb` | `ActiveModel` attributes plus `error_details` in the shape a problem document's `errors` extension wants |
| `app/filters/application_filter.rb` | `filter` / `sortable` / `default_sort` as declarations, and a sort that always ends in a unique tiebreak |
| `app/lib/cursor.rb` | Keyset pagination on `(sort column, id)`, because a UUID key has no order |
| `app/models/idempotent_request.rb` | Replays a stored response for a repeated `Idempotency-Key`; unique index on `(user_id, key, endpoint)` |
| `config/initializers/cors.rb` | Named origins from credentials, and the response headers a browser client has to be able to read |
| `lib/tasks/api_contract.rake` | `api:contract` and `api:contract:check` |
| `test/support/api_contract.rb` | Records what the request tests exercise; inert unless `OPENAPI_OUT` is set |
| `test/support/api_helpers.rb` | `assert_problem` and a token-per-scope helper |
| `.github/workflows/api-contract.yml` | Runs the drift check with a service container matching your database |

Doorkeeper's install and migration run too, with its `resource_owner_id` typed to match
your primary keys and `handle_auth_errors :raise` set so its own failures go through the
app's problem envelope rather than answering in a second format.

### Deployment

| File | Purpose |
|---|---|
| `Dockerfile` | Multi-stage production build |
| `bin/docker-entrypoint` | Runs migrations before boot |
| `.kamal/secrets` | Secret scaffold, gitignored |

### Testing and CI

| File | Purpose |
|---|---|
| `bin/test` | Test runner; forces a single worker on macOS where Minitest forking is flaky |
| `test/support/vcr.rb` | VCR configuration, required from `test_helper.rb` |
| `test/support/slowpoke.rb` | Slow-test reporting, required from `test_helper.rb`; tuned by `SLOWPOKE_*` env vars |
| `test/integration/seo_test.rb` | Asserts meta description, canonical URL, JSON-LD, sitemap, robots.txt |
| `test/components/*_test.rb` | Unit tests for the four shipped components |
| `.github/workflows/lighthouse.yml` | Weekly Lighthouse CI audit |
| `.github/lighthouse-budget.json` | Performance budget |

### SEO

| File | Purpose |
|---|---|
| `public/robots.txt` | Crawl rules and sitemap pointer |
| `HomeController#sitemap` | Dynamic XML sitemap at `/sitemap.xml` |
| Layout injections | `<meta name="description">`, `<link rel="canonical">`, `yield :head`, `WebSite` JSON-LD |

### Documentation

| File | Purpose |
|---|---|
| `CLAUDE.md` | Conventions, patterns, anti-patterns, Slim pitfalls — the file your AI agent reads |
| `docs/adr/` (13 files) | One decision per file, numbered — pre-seeded with the template's own thirteen. Five are API-only and five carry an **Applies to:** line naming the mode they hold in |
| `docs/rules/` (38 files + `INDEX.md`) | One convention per file — controllers, services, forms, queries, policies, jobs, caching — routed by path, symptom, or id |
| `docs/system/models.md` | Model documentation stub |
| `docs/system/vocabulary.md` | What each workflow and doc term means, and the near-synonyms to avoid |
| `CLAUDE.md` (first lines) | The template commit and date this app was generated from |
| `docs/sop/add-seo-to-a-page.md` | Adding SEO to a new page |
| `docs/sop/find-slow-tests.md` | Reading the Slowpoke report and fixing what it flags |
| `docs/sop/harden-a-kamal-server.md` | Server hardening after `kamal setup` |
| `docs/sop/extract-database-and-storage.md` | Moving the database off the app server |

`docs/rules/` holds the conventions, one per file, with `INDEX.md` routing by path, symptom, or rule id. Empty `docs/plans/` and `docs/qa/` directories complete the canon (`rules`, `plans`, `adr`, `system`, `sop`, `qa`). The names are load-bearing — the workflow commands read and write those exact paths.

### Agent workflow

| File | Purpose |
|---|---|
| `.claude/commands/*.md` | 24 slash commands driving `/pick` → `/feature_plan` → `/task_plan` → `/implement` → `/pr_submit` → merge |
| `WORKFLOW.md` | Lifecycle spec: diagrams, the four gates, sizing rules, contract slots |
| `.llm/README.md` | Index of committed docs, so agents find existing docs before writing duplicates |
| `.llm/tasks/task_template.md` | Resumable task file format — the artifact that makes `/implement` idempotent |
| `bin/pr-stack` | Stacked-PR footer generator, called by `/pr_submit` |
| `bin/doc-tokens` | Regenerates the `tokens:` figure in each `docs/rules/*.md`; `--check` fails on drift |
| `.github/PULL_REQUEST_TEMPLATE.md` | Tier-neutral PR body + checklist, for PRs opened by hand |
| `.github/ISSUE_TEMPLATE/` | Issue forms carrying the ≤5-acceptance-criteria sizing rule |

Stack tokens (test, lint, scan commands, default branch, CI job names) arrive pre-filled. Run `/workflow_setup` once to fill in GitHub org, repo, and board IDs. See [The Agent Workflow](workflow.md).

---

## What the template changes about default Rails

Worth knowing, because these are the surprises:

1. **SQLite is removed.** PostgreSQL, MySQL, or MariaDB, chosen with `--database=` at generation.
2. **Four databases, not one.** Queue, cable, and cache each get their own, in every environment.
3. **Primary keys follow the database.** On PostgreSQL, `rails g model` produces UUID PKs and foreign keys must be declared `t.uuid :parent_id`. On MySQL, keys are Rails' default bigint and `t.references :parent, foreign_key: true` is correct.
4. **Slim, not ERB.** The layout stays ERB (Devise and Rails generators expect it), but application views are Slim.
5. **Six pattern directories, not seven.** `services`, `forms`, `queries`, `policies`, `lib`, `components` — each with a stated trigger. A new one needs an ADR. Recorded as ADR-007.
6. **Devise is installed but no `User` exists.** You run `rails g devise User` yourself.
7. **`app/lib` is autoloaded.** Registries live there.
8. **Pagy is pre-wired.** `Pagy::Method` in `ApplicationController`; nav helpers live on the `@pagy` object.
9. **Development mail is captured**, not sent. `letter_opener_web` at `/letter_opener`.
10. **Development uses Solid Cable, not `:async`**, so WebSocket behaviour matches production.

---

## Removing things you don't want

Everything is a plain file. To drop a piece:

- **PaperTrail** — remove the gem, delete the versions migration, remove `has_paper_trail` calls
- **Petergate** — remove the gem and the `petergate` line from your User model
- **Slim** — remove `slim-rails`; existing `.slim` views need converting
- **ViewComponent** — remove `view_component`, delete `app/components/` and `test/components/`, and drop the `FlashComponent` line from the layout
- **SEO** — delete `structured_data_helper.rb`, `seo_test.rb`, the sitemap route and action, and the layout injections
- **VCR** — remove the gems and the `require_relative "support/vcr"` line in `test_helper.rb`

Nothing is coupled to anything else. `app_config.rb` and `plan_registry.rb` are independent files — delete either without touching the other.
