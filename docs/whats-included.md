# What's Included

Every gem and file the template adds, and the reason it's there. Nothing here is a dependency you can't remove — it's all plain Rails files you own.

---

## Gems added

Rails 8 already ships Solid Queue, Solid Cache, Solid Cable, Kamal, and Thruster, so the template doesn't re-add them. It removes `sqlite3` (this is a PostgreSQL template) and adds:

| Gem | Group | Why |
|---|---|---|
| `tailwindcss-rails` | — | Styling, no bundler needed |
| `devise` | — | Authentication, pre-configured for Turbo |
| `petergate` | — | Role-based authorization on top of Devise |
| `discard` | — | Soft deletes for the tables that need them; not applied by default |
| `paper_trail` | — | Audit trail, installed `--with-changes` |
| `pagy` | — | Pagination; far lighter than Kaminari |
| `slim-rails` | — | Terser templates, enforced indentation |
| `view_component` | — | UI components with a real interface and unit tests |
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
| `config/deploy.yml` | Kamal 2 with a PostgreSQL accessory |
| `config/routes.rb` | Health check, sitemap, letter_opener mount, root |
| `.rubocop.yml` | Rails Omakase base |

`config/application.rb` is modified to set UUID primary keys on the generators, autoload `app/lib`, and generate ViewComponents with a sidecar directory.

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
| `app/models/application_record.rb` | UUID primary keys, `implicit_order_column` |
| `app/helpers/structured_data_helper.rb` | `jsonld_tag` and `iso8601_duration` |
| `app/helpers/progress_bar_helper.rb` | Progress bar markup helper |
| `app/javascript/controllers/toggle_controller.js` | Generic show/hide Stimulus controller |
| `app/javascript/controllers/modal_controller.js` | Generic modal Stimulus controller |
| `app/controllers/home_controller.rb` | Landing page plus a dynamic `sitemap.xml` |
| `app/views/home/index.html.slim` | Placeholder home page |

`app/controllers/application_controller.rb` gets `include Pagy::Method`, so pagination works without further wiring. The layout renders `FlashComponent`.

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
| `docs/system/architecture.md` | Architecture Decision Records, pre-seeded with the template's own five decisions |
| `docs/rules/` (26 files + `INDEX.md`) | One convention per file — controllers, services, forms, queries, policies, jobs, caching — routed by path, symptom, or id |
| `docs/system/models.md` | Model documentation stub |
| `docs/system/vocabulary.md` | What each workflow and doc term means, and the near-synonyms to avoid |
| `CLAUDE.md` (first lines) | The template commit and date this app was generated from |
| `docs/sop/add-seo-to-a-page.md` | Adding SEO to a new page |
| `docs/sop/find-slow-tests.md` | Reading the Slowpoke report and fixing what it flags |
| `docs/sop/harden-a-kamal-server.md` | Server hardening after `kamal setup` |
| `docs/sop/extract-database-and-storage.md` | Moving Postgres off the app server |

`docs/rules/` holds the conventions, one per file, with `INDEX.md` routing by path, symptom, or rule id. It is the rule corpus: hand-maintained, and read by the commands rather than written by them. Empty `docs/plans/` and `docs/qa/` directories complete the four-directory doc canon (`plans`, `system`, `sop`, `qa`), which is what the commands write into. All five names are load-bearing — the workflow commands route by those exact paths.

### Agent workflow

| File | Purpose |
|---|---|
| `.claude/commands/*.md` | 19 slash commands driving `/pick` → `/feature_plan` → `/task_plan` → `/implement` → `/pr_submit` → merge |
| `WORKFLOW.md` | Lifecycle spec: diagrams, the four gates, sizing rules, contract slots |
| `.llm/README.md` | Index of committed docs, so agents find existing docs before writing duplicates |
| `.llm/tasks/task_template.md` | Resumable task file format — the artifact that makes `/implement` idempotent |
| `bin/pr-stack` | Stacked-PR footer generator, called by `/pr_submit` |
| `.github/PULL_REQUEST_TEMPLATE.md` | Tier-neutral PR body + checklist, for PRs opened by hand |
| `.github/ISSUE_TEMPLATE/` | Issue forms carrying the ≤5-acceptance-criteria sizing rule |

Stack tokens (test, lint, scan commands, default branch, CI job names) arrive pre-filled. Run `/workflow_setup` once to fill in GitHub org, repo, and board IDs. See [The Agent Workflow](workflow.md).

---

## What the template changes about default Rails

Worth knowing, because these are the surprises:

1. **SQLite is removed.** PostgreSQL only.
2. **Four databases, not one.** Queue, cable, and cache each get their own, in every environment.
3. **UUID primary keys everywhere.** `rails g model` produces UUID PKs automatically. Foreign keys must be declared `t.uuid :parent_id`.
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
